---
title: 'Story 1.14: The auto-refresh framework'
type: 'feature'
created: '2026-09-12'
baseline_revision: '004ea46a1431cea7cc3da5cb36fe712b7f1b241f'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A tick that meets a fault kind the banner has no published copy for suspends auto-refresh
      for the rest of the session while the chip goes on reading its rate.
    evidence: |-
      `isBannerFault` (fault.ts:101) covers `unreachable` and `server-fault` only, and
      `connectivity.note()` arms a probe for `unreachable` alone, so a `refused` (403), `absent`
      (404), `rejected` or `not-installed` tick parks a re-arm with no probe and no Retry behind
      it. The behaviour is what the matrix prescribes ("any FaultKind ... the park is the only
      trigger left") and is AD-8-correct for a 403; what is missing is any way for the user to
      see it, and DW-126 publishes no fourth chip literal to say so.
    location: >-
      ui/src/app/core/refresh.ts (tick fault branch) + ui/src/app/core/fault.ts:101
    severity: medium
  - summary: >-
      The paused chip literal is a 55-character sentence in a `nowrap` flex item with no
      max-width, so it cannot fit a narrow command bar and reflows the row when it appears.
    evidence: |-
      `.ocu-command-bar-refresh` is `flex: 0 0 auto; white-space: nowrap` and the chip jumps from
      ~17 to ~55 characters on `proposal-open`. No published design covers the narrow case, and
      no publisher exists until Epic 5, so nothing is invented here.
    location: >-
      ui/src/styles/_components.scss (.ocu-command-bar-refresh)
    severity: medium
  - summary: >-
      A `ScreenDeclaration` fixture is hand-built in eight spec files, so each new descriptor
      field is eight edits.
    evidence: |-
      This story's two fields required edits to the `screen()` builders in home.page.spec.ts,
      command-bar.spec.ts, command-box.spec.ts, fault-banner.spec.ts, locator-bar.spec.ts and
      side-bar.spec.ts plus full literals in app.spec.ts, status-bar.spec.ts and
      refresh.test.mjs; `memoryStorage()` is now copied into three specs as well.
    location: >-
      ui/src/app/**/*.spec.ts
    severity: medium
  - summary: >-
      The spine's AD-43 counts ten auto-refreshing screens; EXPERIENCE.md `:561` names six.
    evidence: |-
      AD-43's `Binds:` line reads "the ten auto-refreshing screens"; EXPERIENCE.md `:561` lists
      "Processes, Databases, Database details, Task schedule, Task details, System usage". This
      story's comments no longer assert either count, so nothing here depends on the answer, but
      Epic 2 sizes its slices from it.
    location: >-
      ARCHITECTURE-SPINE.md AD-43 vs EXPERIENCE.md :561
    severity: medium
  - summary: >-
      The "no area screen carries a timer of its own" scan ranges over one screen, so it pins
      nothing this change could have broken.
    evidence: |-
      `ui/src/app/areas/` holds `home/home.page.ts` and its spec, and this story adds no file
      there. The assertion is a forward guard for Epic 2's screens and its `[]` is its only
      reachable value today; AC 1's other pin (one arm across bind, rate change and unbind) is
      the half that carries the demonstrated mutation.
    location: >-
      ui/tools/refresh.test.mjs (no area screen carries a timer of its own)
    severity: low
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

**Decision (overnight) — while paused, the one arm serves the proposal's expiry deadline.** The
matrix's `proposal-open` row wants "zero pending arms" and its expiry row wants the seam driven
past `expiresAt`; with nothing armed, nothing sweeps and an unclosed proposal strands the screen.
`armedFor()` returns `'none' | 'tick' | 'expiry'`, so a paused screen holds zero **tick** arms —
the invariant — and still has a deadline. It is the one arm, not a second timer.

**Decision (overnight) — the live ObjectScript target is `OcuPilot.Test.Descriptor` alone.**
`OcuPilot.Test.ScreenRegistry`, which this section named as a second test class, is a fixture
registry extending `OcuPilot.Screen.Registry`; a run against it records no methods. The accessors
and every refusal are pinned in `OcuPilot.Test.Descriptor`, over the new
`OcuPilot.Test.RefreshRegistry` roster. The Verification command now names it.

**Decision (overnight) — the refresh tick answers join-versus-queue with its own arm, not with
`single-flight`.** The Approach names both consumers; only `NavigationService` imports the
primitive. A map read has several callers racing one entry point, which is what the primitive is
for; a tick has exactly one caller — its own arm — so there is nobody to join. What the tick
needed was the other half of the same rule, and it has it: one arm, a generation guard, and (from
this pass) a read that an later read has overtaken cannot write the store. Wiring the primitive in
as well would put the flight's dirty mark and the generation counter in charge of the same re-arm,
which is the two-mechanisms shape Story 1.13 spent three findings on.

**Decision (overnight) — `hasStamp` becomes true when the bind's first read lands, not at the
bind call.** The matrix's binding row lists `hasStamp` true among a bound screen's states. At the
moment `bind()` returns there is no last-update time, so a stamp then would name a freshness the
screen has not got. The row is satisfied by the bound screen once its first tick lands, which is
what `status-bar.spec.ts` pins.

**Decision (overnight) — only `rate` is written to `PreferenceStore`.** The Execution task asks
for "one new allow-list key holding a descriptor→rate map"; sort, filter and max rows have no
control a user can reach until Story 2.4, and a key written for a control nobody can reach is an
allow-list entry with no subject (AD-47). All four live in the store, so they survive navigation
within a tab.

## Review Triage Log

### 2026-09-13 — Review pass
- verdicts: 53 findings — high 0, medium 25, low 24, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` blind-hunter: `bind()` keeps a stale read when re-bound to the same descriptor — reproduced against the real module (re-bind with read B, tick called A); the guard now compares the read too.
  - `[medium]` `[patch]` blind-hunter: a read overtaken by a later one writes stale rows under a newer stamp — reproduced (two reads in flight, older landed last, `Last update` moved forward over earlier rows); `tick()` now drops an overtaken read.
  - `[medium]` `[patch]` blind-hunter: a registered read that rejects kills auto-refresh silently — `await bound.read(...)` was unguarded behind `void this.tick(...)`; it now takes the failure path.
  - `[medium]` `[defer]` blind-hunter: every fault kind is parked, including ones AD-8 never retries — the matrix prescribes "any FaultKind" and AD-8 makes permanent suspension right for a 403; the user-visible half needs copy DW-126 has not published. Deferred entry 1.
  - `[medium]` `[defer]` blind-hunter: a non-banner fault leaves the chip claiming a live readout — same root cause as the row above; deferred with it.
  - `[medium]` `[patch]` blind-hunter: `chipLabel()` reports paused for a screen whose rate is off — reproduced; the rate is now read before the pause.
  - `[medium]` `[patch]` blind-hunter: no expiry is armed while the rate is off, so that pause never lifts — reproduced (an hour of injected clock, zero arms); closed by the same reordering.
  - `[medium]` `[defer]` blind-hunter: the paused literal cannot fit the chip — real, and no published design covers the narrow case. Deferred entry 2.
  - `[low]` `[reject]` blind-hunter: nothing unbinds on navigation — true, and unreachable: no route binds until Story 2.3, which wires binding and its teardown together.
  - `[low]` `[reject]` blind-hunter: `ScreenStores.for()` ignores `rates` for an existing store — by design (a descriptor's rates do not change); refusing a mismatch adds a branch for a case nothing produces.
  - `[low]` `[reject]` blind-hunter: `setRefreshRate` read-modify-write clobbers across tabs — real, loses a remembered rate only; a storage-event listener is more than the defect is worth.
  - `[medium]` `[patch]` blind-hunter: `Base.RefreshRates()` reads a JSON object as a rate list — confirmed (`%GetIterator` over a `%DynamicObject` yields values); it now reads only a `%DynamicArray`, and the mirror refuses the shape at build.
  - `[medium]` `[patch]` blind-hunter: `buildMirror` refuses an unpublished rate but not a malformed pair — added `refreshProblem()`, the five rules `Registry.RefreshProblem` applies, with eleven fixture-driven refusals.
  - `[low]` `[reject]` blind-hunter: `check-objectscript.py` was not extended — the mirror patch above now fails the build on the same shapes, which is the gate that keeps a bad descriptor out of the container start hook.
  - `[false]` `[reject]` blind-hunter: `publishedRefreshRates` has no caller — `refresh.test.mjs` imports it as the client half of the two-readers check; that is the caller.
  - `[low]` `[patch]` blind-hunter: the "publishing the copy costs no code change" claim is falsified by three `[10]` assertions — the claim is corrected in place: the mechanism does not change, the pins do, and that is the review they exist to force.
  - `[low]` `[reject]` blind-hunter: the two-readers drift test compares pattern text, not behaviour — the pattern is the only thing that can drift between six-line twins; transpiling TypeScript in a tool test costs more than it catches.
  - `[low]` `[patch]` blind-hunter: `app.ts`'s new comment says "not before it" above a line that is before it — the block moved after `connectivity.reset()`, and the numbering now reads in order.
  - `[low]` `[patch]` blind-hunter: the areas timer scan would fire on a spec's `setTimeout(resolve, 0)` — the walk now skips `.spec.ts`.
  - `[low]` `[reject]` blind-hunter: `PROPOSAL_EXPIRY_MS` has no drift check — there is no server-side constant to check it against; AD-6 is prose until Epic 5 ships the lifecycle.
  - `[low]` `[reject]` blind-hunter: `onBusEvent` drops proposals while the namespace is unresolved — true for the window before the list answers, and no publisher exists in it.
  - `[medium]` `[defer]` blind-hunter: `ScreenDeclaration` fixtures duplicated across eight specs — real maintenance cost, out of this story's footprint. Deferred entry 3.
  - `[low]` `[reject]` blind-hunter: `REFRESH_PARK_KEY` breaks the path-keyed park convention — the framework's park has no API path of its own to be keyed by.
  - `[false]` `[reject]` blind-hunter: the result section reports a check Verification does not name — the fix edits this build's spec, and this pass rewrote both sections anyway.
  - `[medium]` `[patch]` edge-case: a rejecting read leaves an unhandled rejection — same root cause as the third row; patched with it.
  - `[medium]` `[defer]` edge-case: a non-banner fault's park never runs — same root cause as the fourth row; deferred with it.
  - `[medium]` `[patch]` edge-case: a `NaN` or out-of-range `expiresAt` live-locks the tab — reproduced (`delayMs: NaN`, 6 drives produced 8 arms, pause never lifted); the bus now replaces any expiry that is not a moment within AD-6's ten minutes.
  - `[medium]` `[patch]` edge-case: a proposal opening against an off screen claims a pause — same root cause as the sixth row; patched with it.
  - `[medium]` `[patch]` edge-case: `advanceRate()` cycles under an unchanging paused literal — the reordering gives the off step its own literal, so the control reports again.
  - `[medium]` `[patch]` edge-case: same descriptor re-bound with a different read — same root cause as the first row; patched with it.
  - `[medium]` `[patch]` edge-case: a namespace switch between a proposal's open and its close strands the pause — reproduced (close dropped as out-of-scope); `noteScopeChanged()` drops the live proposals with the rows.
  - `[low]` `[patch]` edge-case: a bus kind that is neither `changed` nor `proposal-open` ends a pause it was never about — the close branch is now named rather than assumed.
  - `[medium]` `[patch]` edge-case: `refreshRates` declared as an object installs as a sound rate list — same root cause as the `Base.RefreshRates()` row; patched with it.
  - `[medium]` `[patch]` edge-case: the mirror lets a duplicate or non-ascending list through to the install — same root cause as the `buildMirror` row; patched with it.
  - `[low]` `[reject]` edge-case: the matrix's bind row says `hasStamp` true while the stamp waits for a read — the shipped behaviour is the only non-lying one; recorded as a decision in the change log rather than changed.
  - `[medium]` `[patch]` verification-gap: the framework is not on the `onScopeChange` channel — demonstrated against the real module (rows and stamp survived a namespace move); `main.ts` now calls `noteScopeChanged()` beside the map re-read, pinned in `refresh.test.mjs` and in the `main.ts` source pin.
  - `[medium]` `[patch]` verification-gap: the fault path is verified only for banner kinds — a `refused` (403) row now pins that the module reads no kind at all.
  - `[medium]` `[patch]` verification-gap: no test constructs a live proposal with the rate off — that row now exists, and the behaviour it would have found is patched.
  - `[low]` `[defer]` verification-gap: the areas timer scan cannot fail for this change — true; it is a forward guard for Epic 2's screens. Deferred entry 5.
  - `[low]` `[patch]` verification-gap: the shipped-roster rate check asserts `[] === []` — still true of that row, and the eleven fixture-driven refusals added beside it are not vacuous.
  - `[medium]` `[patch]` verification-gap (other): a same-descriptor re-bind keeps the previous read — same root cause as the first row; patched with it.
  - `[low]` `[reject]` verification-gap (other): the matrix's bind row contradicts the shipped stamp — same as the edge-case row above; decision recorded.
  - `[low]` `[patch]` verification-gap (other): the composed AD-44 row no longer mirrors `main.ts` — the fixture now passes `namespace`, so it exercises the pinned-key path the shell runs.
  - `[false]` `[reject]` verification-gap (other): live ObjectScript half confirmed at run 978 — a confirmation, not a defect.
  - `[low]` `[defer]` verification-gap (other): AC 1's second half carries no demonstrated mutation — same entry as the areas-scan row; deferred with it.
  - `[false]` `[reject]` intent-alignment: nothing calls `bind()` in production — forced by the intent's own Not-in-scope line (Story 2.3 owns the read, and binding without one is refused).
  - `[medium]` `[reject]` intent-alignment: `single-flight` is consumed by `navigation.ts` only, not by the refresh tick — the effect it would have prevented (two reads in flight) is real and is now guarded; wiring the tick through the primitive would put the generation guard and the flight's dirty mark in charge of the same re-arm. Decision recorded in the change log.
  - `[low]` `[reject]` intent-alignment: the build refusal is pinned at `buildMirror()`, not at the CLI — `buildMirror` throws before `writeFileSync` is reached, so "no partial mirror" is structural.
  - `[low]` `[defer]` intent-alignment: three "never" claims are pinned lexically — the areas scan is the one whose population is empty; deferred entry 5.
  - `[low]` `[reject]` intent-alignment: the spec asks for four persisted slots and one is persisted — the Execution task asks for a descriptor-to-rate map, and three of the four have no control a user can reach until Story 2.4. Decision recorded.
  - `[low]` `[reject]` intent-alignment: the matrix names `REFRESH_KEY`, the code exports `REFRESH_PARK_KEY` — a name, not a behaviour.
  - `[low]` `[reject]` intent-alignment: the matrix names five preserved slots, the test compares six — a superset of the claim.
  - `[low]` `[patch]` intent-alignment: `refresh.ts` counts ten auto-refreshing screens where `Home.cls` counts six — the spine and EXPERIENCE.md disagree; `refresh.ts` now asserts no count, and the discrepancy is deferred entry 4.

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
- IRIS: load and compile `src/OcuPilot/` with the `iris-dev` MCP tools, **always `server: "ocupilot-iris"`**. Then `iris_execute_tests` — **one test class per tool call, per message, awaited; never two in one message and never a re-submit on a client-side timeout** (`.claude/rules/objectscript-testing.md`). Run `OcuPilot.Test.Descriptor`, which is where the accessors and the refusals are pinned. Confirm totals with the numeric-run-index SQL probe before reporting green. Never `docker compose up`/`down`/`restart`.
- `bash scripts/lint-docs.sh` — expected: clean.

**Pinning tests (Rule 19).** One mutation per AC, each applied, observed red, and reverted here.
- One framework, one timer, no per-screen timer → `ui/tools/refresh.test.mjs` "one arm at a time across bind, rate change and unbind" + "no area screen carries a timer of its own". mutation: dropped `this.arm = 'none'` from `transition()` → the post-unbind read is `tick`, not `none`, and "reset drops the bound screen, its stores and its timer" goes red with it.
- No stale generation re-arms → `ui/tools/refresh.test.mjs` "a rate change orphans the previous generation". mutation: deleted the `generation !== this.generation` compare inside the tick arm's callback → the orphaned 10 s arm issued a read and the zero-read assertion went red.
- Sign-out drops the framework in the same gesture as connectivity → `ui/src/app/app.spec.ts` "AD-8: leaving the signed-in state drops this principal's namespace list". mutation: deleted `this.refresh.reset()` from `App.verifyWhenSignedIn` → the probe screen is still bound after the session leaves signed-in.
- A tick is silent and preserves the five untouched slots → `ui/tools/refresh.test.mjs` "a tick replaces data, truncated and lastUpdate and nothing else". mutation: had `ScreenStore.applyTick` also clear `selected` → the before/after comparison went red on the selection slot.
- No live region on chip or stamp → `status-bar.spec.ts` "the stamp follows the tick, and is never announced" + `command-bar.spec.ts` "the chip and the ticks are outside every live region". mutation: gave the stamp span `role="status"` → the ancestor walk found it.
- **DW-157** join vs. queue → `ui/tools/navigation.test.mjs` "a scope change mid-flight re-runs the map read once against the new namespace", plus the unchanged-key and DW-9 rows. mutation: removed the `keyOf() !== currentKey` compare from `single-flight.ts` so every request joins → the re-run row went red at one call instead of two.
- Chip and stamp render from the service → `command-bar.spec.ts` "Integration AC: the chip renders the literal the framework reports" / `status-bar.spec.ts` "Integration AC: a tick that lands makes the band read the published stamp". mutation: replaced the command bar's `refresh.subscribe` with a no-op → the Integration AC and three sibling chip rows went red with no chip in the DOM.
- Refresh suspends on a fault and resumes only from the park → `ui/tools/refresh.test.mjs` "a fault suspends and parks exactly one re-arm". mutation: dropped `this.suspended = true` from `suspend()`, keeping the park → the timer re-armed (`tick`, not `none`) and "an expiry sweep still requires no fault" went red with it.
- Two opens, one close, stays paused → `ui/tools/refresh.test.mjs` "the live-proposal set is not a boolean". mutation: made a `proposal-closed` clear the whole live set → the row read unpaused after one close.
- An unclosed proposal expires at the seam → `ui/tools/refresh.test.mjs` "a close that never arrives does not strand the pause". mutation: returned from `transition()` before the expiry arm → `armedFor()` read `none` and the pause never lifted.
- Per-screen rate persists, and an unpermitted stored rate falls back → `ui/tools/refresh.test.mjs` "the rate persists per screen" / "a stored rate the descriptor no longer permits". mutation: dropped the `permitted.includes(stored)` guard in `PreferenceStore.refreshRate` → the fallback row read 30, a rate no chip literal names.
- An unpublished rate fails the build → `ui/tools/screen-mirror.test.mjs` "the generator refuses a declared rate the string table publishes no chip literal for". mutation: emptied `buildMirror`'s declared-rate loop → no exception was thrown and the row went red.
- Descriptor fields and registry refusals → `OcuPilot.Test.Descriptor` (live). mutation: dropped the ascending compare from `Registry.RefreshProblem`, loaded and compiled on `ocupilot-iris` → `TestARefreshDeclarationOutsideThePermittedShapesIsRefused` went red on the repeat and the descent (run 977); restored, 15/15 at run 978.
- Binding without a registered read is refused → `ui/tools/refresh.test.mjs` "AD-36: binding a refreshing screen that registered no read is refused". mutation: removed `bind()`'s missing-read throw → the refusal row went red with no exception raised.

**Ledger (`owned_ledger=DW-157`).** Addressed by the `single-flight.ts` task, the `navigation.ts` task, two I/O matrix rows and the first Integration AC.

## Auto Run Result

Status: done
Blocking condition: none

**What was built.** The one auto-refresh framework AD-43 requires: `refreshes` / `refreshRates`
declared in the descriptor and carried to the client by `screen-mirror.mjs`; a `RefreshService`
with one generation-guarded arm behind an injected `schedule` seam, a three-condition resume
predicate, a fault suspension that parks exactly one re-arm with connectivity, and a proposal
pause held by a set of ids with its own expiry deadline; a per-descriptor signal store whose rate
persists; one client change/proposal bus; and a shared `single-flight` primitive that joins an
unchanged key and re-runs once on a changed one, which `NavigationService` now runs its map read
on — **DW-157 closed**, with the DW-9 stub verified to join rather than loop.

**Files changed.** New: `ui/src/app/core/{single-flight,change-bus,screen-store,refresh}.ts`,
`ui/tools/{single-flight,change-bus,refresh}.test.mjs`, `src/OcuPilot/Test/Screen/Refreshing.cls`,
`src/OcuPilot/Test/Refresh/Bad.cls`, `src/OcuPilot/Test/RefreshRegistry.cls`. Changed:
`Screen/Descriptor/Base.cls` (the two accessors), `Home.cls` (`refreshes: false`), `Registry.cls`
(`RefreshProblem` + `Validate`), `Test/Descriptor.cls` (two methods); `navigation.ts` (onto the
primitive), `preferences.ts` (one new allow-list key), `screens.generated.ts` (regenerated),
`command-bar.ts` (the chip), `status-bar.ts` (the stamp), `main.ts` / `app.ts` (providers, the
sign-out teardown, the scope-change subscriber), `_components.scss`, `screen-mirror.mjs` /
`strings.mjs` (both fields plus the build refusals), and the specs and tool suites that cover them.

**Review findings.** 53 findings across four layers: 0 high, 25 medium, 24 low, 4 false. Grouped
by root cause, **9 medium and 5 low entries were patched**, 5 entries deferred, the rest rejected
on their refutations — every row is in the triage log above. The patches, in short: a re-bind with
a new read now takes effect; an overtaken read can no longer write stale rows under a newer stamp;
a read that throws takes the failure path instead of dying as an unhandled rejection; an off screen
never reads "paused"; a `NaN` or out-of-range proposal expiry can no longer become a re-arm loop; a
namespace switch drops the bound screen's rows, stamp and live proposals (AD-44); the mirror
refuses a malformed refresh pair at build time, not only an unpublished rate; and
`Base.RefreshRates()` reads only a JSON array.

**Follow-up review recommended: true.** Not for a high — there was none — but because nine medium
entries were patched in one pass, and because the risk they all share is unverified in the only
way that would settle it: **nothing calls `bind()` in the shipped shell**. Story 2.3 registers the
first descriptor-declared read, and until it does, every behaviour above is exercised through tests
and through the two chrome components, never through a screen a user can open.

**Verification.** `npm run test:tools` 448 pass / 0 fail; `npm run test:components` 178 pass / 0
fail; `npm run build` clean through `prebuild` (version-guard, client-lint, `screen-mirror
--check`); `node tools/screen-mirror.mjs` regenerates the mirror with both fields;
`OcuPilot.Test.Descriptor` 15/15 live on `ocupilot-iris` at run 979, confirmed by the numeric
-run-index SQL probe over `%UnitTest_Result`; `bash scripts/lint-docs.sh` and `uv run
scripts/check-objectscript.py` clean. Twenty mutations were applied, observed red and reverted —
the thirteen AC pinning mutations above, the `app.ts` teardown pin, and six over the review
patches; the tree was byte-identical after each. Five claims were reproduced against the real
modules before being patched, not taken on a reviewer's report. No `docker compose up`/`down`/
`restart`; no namespace, database or account touched.

**Residual risks.** No production consumer (above). The chip's paused literal has no narrow-width
treatment and no published design for one. A tick meeting a fault kind the banner has no copy for
suspends until an unrelated call succeeds, which is what the matrix asks for and what DW-126 leaves
unsayable to the user. Both are deferred entries.
