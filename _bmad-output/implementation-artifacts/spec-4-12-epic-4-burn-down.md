---
title: 'Epic 4 burn-down'
type: 'bugfix'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 4's own gates filed fourteen entries the epic must not ship with: four gates that
cannot fail (a stylesheet rule nothing pins, a truncation assertion that depends on the instance's
age, two browser legs that fail opaquely or leak state), a bundle gate with 1.63 kB of headroom, two
refusals that do not happen or name the wrong thing, a schema that declares a type it does not emit,
a bound duplicated beside its parameter, an over-long pair set that loses the whole row, a 400 that
carries vendor exception text, and a rule count a contributor reads that the checker disagrees with.

**Approach:** Close all fourteen in one story: fix twelve with a demonstrated mutation, and make two
terminal with the reason recorded — DW-398 declined on a measurement taken here, DW-1154 closed
against the leg that already carries it if that leg is on the branch. Every fix is small and local;
nothing here introduces a class, a route, a string or a dependency.

## Boundaries & Constraints

**Always:** Reuse existing vocabulary where it is correct — DW-1096 refuses with the 409
`STATE.CONFLICT` the route already answers and DW-1125 withholds through the `rowsWithheld` count
the ledger already reports, so no new machine code enters `Api/Error.cls`'s rosters. AD-39: a
normalized written sentence reaches the caller and the raw vendor text reaches the log only. AD-46:
the ledger's cross-user gate stays with the ledger and fails closed. AD-24: a bound that cuts says
it cut. Rule 19: every changed or added pinning test carries its `mutation:` line here. One test
class per `ci-runner` invocation, one invocation per message. Every ObjectScript run goes to
`ocupilot-ci`, never to `ocupilot`.

**Never:** No new `%Persistent` class, route, `core/strings.ts` entry, package, or dependency. No
edit to `ARCHITECTURE-SPINE.md` or `EXPERIENCE.md` — this story needs neither (see Design Notes) and
the lead owns both. No change to the credential backstop's matching rule (DW-398 declines it). No
threading of `ReadRequestBody`'s `.tStage` through Definitions' and Switches' twelve call sites. No
`git add -A`, no commit, no push. No `docker compose up`/`down` against `ocupilot` or any
`ocupilot-slot-*` container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Malformed JSON body to a definitions or switches write | `{"name":` | 400, `code` `AGENT.BADBODY`, `reason` exactly `Api.Error.#REASONAGENTBADBODY` | Raw `%Status` text goes to the log only, never the wire |
| Cross-user ledger read without the row's pairs | administrator reads another user's rows | 403, `code` `AUTH.NOPRIVILEGE`, `reason` names the request, not a tool call | `detail.failedPair` unchanged |
| A dropped `LedgerRead` audit emission | `Security.Events` entry absent | Log line says the read was answered and no audit row was written | The read still answers; nothing propagates (AD-15) |
| Settle for a turn that has already ended | `POST /turn/{id}/navigation` on a `completed` turn | 409, `code` `STATE.CONFLICT`, Nav row untouched | Owner check still answers 404 for a turn the caller does not own |
| Navigate settle with no row and an `opened` outcome | `entityId` absent, outcome `opened` | Result object omits `entityId` and `code`; every emitted key matches a declared `ResultSchema` type | — |
| `RequiredPairs` longer than 512 characters | ~40 declared pairs on one tool call | Row is written, pairs cut at a whole-pair boundary, `requiredPairsTruncated` 1 | A cross-user read withholds that row and counts it in `rowsWithheld` |
| `LEDGERROWMAXLENGTH` raised above the `Arguments` column | probe `Limits` subclass at 8192 | The bound-versus-column test reddens | No silent cut: the cap at the call site is read from the seam |
| Error-log read at a context cap of 1 against a stub source reporting three untruncated rows | `ErrorReadStub.ArmUntruncated()` | One row, `truncated` 1 from `View`'s own cap branch | Independent of the instance's error-log contents |
| `navigate.browser-spec.mjs` run while a previous turn holds the slot | `^OcuPilotTurnSlot("_SYSTEM")` held | The before-hook abandons and waits, then fails naming the slot, the pid and `TURN.BUSY` | Never a bare 30 s puppeteer timeout |
| The sign-out leg throws before its `try` | `signedInAt` lapses | The probe definition is removed and the file's own postcondition asserts zero enabled definitions | The leak fails the file that caused it, not nine tests in the next run |

</intent-contract>

## Code Map

Server:

- `src/OcuPilot/Api/Definitions.cls:1204-1212` — `RenderBadBody`, the `GetErrorText` concatenation
  (line 1211). Callers at `:309,313,374,378,560,564,715,719`; `NotAnObject()` at `:1233-1236`.
- `src/OcuPilot/Api/Switches.cls:440-443` — delegates to it; callers `:112,116,187,191`.
  `src/OcuPilot/Api/Context.cls:46-51` is the one stage-aware caller.
- `src/OcuPilot/Api/Turn.cls:481-486` — the landed 4.1 shape to copy (`RenderBadBody` renders
  `#REASONTURNBADBODY` alone). `:267-308` `HandleNavigation` (`.tValues` filled `:272`, never read);
  `:241-252` `HandleStop`'s terminal gate; `:299-302` the 409 mapping.
- `src/OcuPilot/Api/Error.cls` — `#AUTHNOPRIVILEGE` `:111`, `#REASONAUTHNOPRIVILEGE` `:115`
  ("…the privilege that tool call requires."), `#AGENTBADBODY` `:368` (no reason parameter exists),
  `TurnCodes()` `:914`, `LedgerCodes()` `:877`, `ReasonForLedger()` `:~885`, `RenderInternal`/
  `LogError` `:1239-1245`.
- `src/OcuPilot/Kernel/Audit/Ledger.cls:298-301` — the only 403, built with
  `#REASONAUTHNOPRIVILEGE`; `PairsToString` `:219-241`; `RecordToolCall` `:125-130`;
  `ViewForUser`'s withhold branch `:349-374`; `LogFailure` `:444-447`; `:438` the `LedgerRead`
  emission.
- `src/OcuPilot/Kernel/Audit/Event.cls:152-194` — `Record` (`:172` the `Log.Redact` passthrough,
  `:177` the `LogFailure` call) and `LogFailure`'s hardcoded configuration-change message.
- `src/OcuPilot/Kernel/State/Ledger.cls` — `Route` MAXLEN 512 `:69`, `Arguments` MAXLEN 4096 `:78`,
  `ArgumentsTruncated` `:81`, `RequiredPairs` MAXLEN 512 + its doc `:93-101`, `Dropped` `:104`,
  `GuardedAppend` `:125-158` (`..Cut(pRoute,512)` `:149`/`:195`, `..Cut(pArguments,4096)` `:151`,
  `:157` the uncut pairs), projection `:285-291`, `Cut` `:331-334`.
- `src/OcuPilot/Kernel/State/Turn.cls` — `ContextRoute` MAXLEN 512 `:92`, `Cap` `:134-139`,
  `IsTerminal` `:127-130`, `GuardedBegin`'s dead `.tRouteCut` `:267`, `GuardedForOwner` `:406-421`.
- `src/OcuPilot/Kernel/Agent/Limits.cls:80` — `LEDGERROWMAXLENGTH` 4096; the class is parameters
  only and is read as `$Parameter(pLimitsClass, …)` (precedent: `State/Ledger.cls:134`).
- `src/OcuPilot/Kernel/Agent/Dispatch.cls:556-573` — `SettleClient`; `:561-566` the `entityId` null,
  `:567-571` the `code` null. `RedactedArguments` `:628-642` is where the U+2026 and the flag are set.
- `src/OcuPilot/Screen/Tool/Navigate.cls:96-113` — `ResultSchema`; `:107-108` the two `"string"`
  declarations; `:110` `required` holds only `navigated` and `route`.
- `src/OcuPilot/Screen/Tool/Registry.cls:50,53` — `SCHEMAKEYWORDS`/`SCHEMATYPES`; `SchemaProblem`
  `:616-674`, `ValueProblem` `:710-722`. Read-only evidence: nullability is not expressible and
  nothing validates a client-fulfilled result at runtime (`ValidateArguments` call sites are input
  schemas only; `Test/ToolRoundTrip.cls:20` lists navigate in `REFUSEEMPTY`).
- `src/OcuPilot/Kernel/Audit/Log.cls:42-63,117-146,172-197` — the backstop. Read-only for this story.
- Tests: `Test/AgentWire.cls:507-522`, `Test/Ledger.cls:447-501,594-600,647`,
  `Test/LedgerLimits.cls:8`, `Test/AuditEvent.cls:355,470`, `Test/EventProbe.cls:18`,
  `Test/TurnNavigate.cls:173,370-411,541-565`, `Test/ToolNavigate.cls:141-202`,
  `Test/ReadTool.cls:971-1040`, `Test/ErrorReadStub.cls:9-53`, `Test/TurnStore.cls:243`,
  `Test/AgentViolation.cls:71-77`, `Test/Log.cls:246-260`, `Test/TurnFixture.cls:96-103`.

Client and scripts:

- `ui/angular.json:51-57` — the one budget entry, `maximumWarning "780kB"`.
  `ui/tools/angular-json.test.mjs:360-370` — the pinned literal (`:365`).
  `ui/tools/build-output.test.mjs:55-63,168-201` — builds and measures the real `dist/`, parsing the
  budget out of `angular.json` (no second copy of the number). No third source anywhere in the repo.
- `ui/src/app/core/suggested-view.ts:37` `ERROR_LOG_DATES_PATH`, used `:329`;
  `ui/src/app/areas/logs/error-log.store.ts:59` `ERROR_LOG_PATH_PREFIX`, used `:365`.
  `core/api.ts:147-156` is the precedent doc for this duplication class. `error-log.store.ts` imports
  `@angular/core`, so `node --test` cannot import it; `core/` is importable from `areas/`, not the
  reverse. Literal pins already exist at `ui/src/app/shell/panel.spec.ts:2306,2324` and
  `ui/src/app/areas/logs/error-log.page.spec.ts:211-215`.
- `ui/src/styles/_components.scss:3171-3206` — the five `.ocu-panel-*` blocks (`overflow-y: auto`
  `:3179`; `ocu-focus-ring` + `outline-offset: -2px` `:3181-3185`; `.ocu-panel-empty` typographic
  only `:3187-3192`; `flex-wrap: wrap` `:3196`; `height: auto; padding: 0 var(--ocu-space-2)`
  `:3203-3206`).
- `ui/browser/panel.browser-spec.mjs:33,45-50,64-98,238-239,375-426,431-432` — prefix, `after`,
  fixture helpers, the three legs whose setup sits outside their `try`, and the two composer waits
  (`:381`, `:412`). `ui/browser/gate.browser-spec.mjs:81-95,118` — the pre/postcondition pattern to
  copy, and the stale "only one that enables a definition" claim at `:118`.
- `ui/browser/navigate.browser-spec.mjs:50-58,117,130-137,164-200` — the before-hook and the AC4 leg.
  `ui/browser/turn.browser-spec.mjs:236-242` — the slot reasoning that exists (exit only).
  `ui/browser/audit.browser-spec.mjs:252,277` — the named-timeout wrapper to copy.
  `ui/browser/turnprobe-spec.mjs:52,67,171-179` — `runIris`, `markerValue`, probe arming.
  `ui/browser.config.mjs:66-83` — `navigationTimeoutMs` 30000, `LIVE_CONTAINER`.
- `scripts/check-objectscript.py:1805-1827` (`CHECKS`, 21 entries), `:1845-1850` (the derived print).
  `scripts/test_check_objectscript.py` references `co.CHECKS` only as an iteration target (`:1106`,
  `:1181`) and asserts no count. `CLAUDE.md:133` states `18 rules` — the only stale count in a live
  file (`README.md`, `.githooks/pre-commit` and the spine state none).

## Tasks & Acceptance

**Execution** — in this order, so the source edits land before the single compile-and-test sweep and
the build-and-deploy sweep:

Group 1 — client and scripts, no instance:

- `ui/angular.json` + `ui/tools/angular-json.test.mjs` — raise `maximumWarning` from `780kB` to
  `820kB` in both, in one commit whose message states the `Initial total` this story's own
  `npm run build` printed. `maximumError` stays `1MB`. (DW-1153.)
- `ui/src/app/core/log-paths.ts` (new, framework-free) — declare `ERROR_LOG_PATH_PREFIX` once and
  `ERROR_LOG_DATES_PATH = ERROR_LOG_PATH_PREFIX + 'dates'`. `core/suggested-view.ts` re-exports
  `ERROR_LOG_DATES_PATH` from it (`export { … } from './log-paths.ts';` — the `.ts` extension is what
  `node --test`'s resolver needs) so `ui/tools/suggested-view.test.mjs`'s existing import is
  unchanged; `areas/logs/error-log.store.ts` imports the prefix and deletes its own literal.
  (DW-1149.)
- `scripts/test_check_objectscript.py` — add one test that extracts the integer from `CLAUDE.md`'s
  `check-objectscript.py` bullet and asserts it equals `len(co.CHECKS)`. (DW-1129 pin.)
- `CLAUDE.md:133` — change `18 rules` to `21 rules`. **This is the story's one edit to the project's
  agent-instruction file and the only line of it that changes**; report it as a footprint extension.
  (DW-1129.)

Group 2 — ObjectScript, no behavior change on a reachable path:

- `src/OcuPilot/Api/Error.cls` — add `Parameter REASONAGENTBADBODY` beside `#AGENTBADBODY` (`:368`)
  with one written sentence naming what could not be read and what to do; and **replace**
  `#REASONAUTHNOPRIVILEGE`'s sentence with one that names the request rather than a tool call,
  correcting its doc comment in the same edit. No code enters any roster. (DW-447, DW-1127.)
- `src/OcuPilot/Api/Definitions.cls:1209-1212` — render `#REASONAGENTBADBODY` alone and pass the raw
  `%Status` to the existing `Api.Error` logger, per AD-39's "raw text kept for the log". Signature and
  callers unchanged, so `Api/Switches.cls` and `Api/Context.cls` need no edit. (DW-447.)
- `src/OcuPilot/Kernel/State/Base.cls` — add `Parameter ROUTEMAXLENGTH As %Integer = 512;`, used at
  `State/Ledger.cls:149,195` and `State/Turn.cls:267`. (DW-1124.)
- `src/OcuPilot/Kernel/State/Ledger.cls:151` — read the cap from the seam:
  `..Cut(pArguments, +$Parameter(pLimitsClass, "LEDGERROWMAXLENGTH"))`. (DW-1124.)
- `src/OcuPilot/Kernel/State/Turn.cls:267` — drop the dead `.tRouteCut` byref (no
  `contextRouteTruncated` column exists and the route is a closed enum from `Loop.ContextRoute()`).
  (DW-1124.)
- `src/OcuPilot/Kernel/Agent/Dispatch.cls:561-571` — omit `entityId` when no row was requested and
  omit `code` on an `opened` outcome, rather than emitting JSON null. Both are outside
  `ResultSchema`'s `required`, and the declarations at `Navigate.cls:107-108` already say "present
  only when…", so absence is the documented intent and the schema becomes true with no grammar
  change. (DW-1095.)

Group 3 — ObjectScript behavior changes:

- `src/OcuPilot/Api/Turn.cls` — in `HandleNavigation`, after the `'tFound` branch (`:281`) and before
  the body read, refuse a settle whose `tValues("state")` is `..IsTerminal` with the 409
  `STATE.CONFLICT` / `#REASONSTATECONFLICT` the route already answers at `:299-302`; update the
  method's doc comment so the 409 is no longer described as the claim's alone. (DW-1096.)
- `src/OcuPilot/Kernel/Audit/Ledger.cls` — bound `PairsToString` at **whole-pair** granularity
  against a new `Parameter PAIRSMAXLENGTH As %Integer = 512;` on `State/Ledger.cls` beside the
  column, reporting truncation by reference (no U+2026: a pair set is
  not display text and a mark would read as a bogus pair); thread the flag through `RecordToolCall`
  and `GuardedAppend` into a new `RequiredPairsTruncated` boolean on `State/Ledger.cls` beside
  `ArgumentsTruncated`; project it (`State/Ledger.cls:285-291`, wire `:414`); and in `ViewForUser`
  treat a truncated pair set on a **cross-user** read as unreadable, incrementing the existing
  `tWithheld` exactly as an unparseable string already does (`:355-360`). A self-read keeps the row.
  Delete the property's "fails the row's write" doc paragraph (`:97-100`) and write the one correct
  sentence in its place. (DW-1125.)
- `src/OcuPilot/Kernel/Audit/Event.cls` — give `LogFailure` a trailing `pMessage` argument defaulting
  to today's configuration-change sentence, and have `Record` (`:177`) pass a read-shaped sentence
  when the emission is `..#EVENTLEDGERREAD`. `src/OcuPilot/Test/EventProbe.cls:18` takes the same
  signature and captures the message so it is pinnable. One production call site changes.
  (DW-1127.)

Group 4 — tests and specs:

- `src/OcuPilot/Test/AgentWire.cls:507-522` — assert the malformed-body `reason` **equals**
  `Api.Error.#REASONAGENTBADBODY` and contains neither `<THROW>` nor `%Library`, replacing the
  `[ "JSON"` substring assertion that passes today only on the vendor text. (DW-447.)
- `src/OcuPilot/Test/Ledger.cls` — (a) the cross-user leg (`:594-600`) asserts the 403 `reason`
  equals `#REASONAUTHNOPRIVILEGE` and does not contain `tool call`; (b) a new method asserts
  `LEDGERROWMAXLENGTH <= MAXLEN(Arguments)`, `ROUTEMAXLENGTH = MAXLEN(Route)` and
  `= MAXLEN(ContextRoute)`, and `PAIRSMAXLENGTH = MAXLEN(RequiredPairs)`, reading each MAXLEN from
  `%Dictionary.CompiledProperty` — a declared bound and its column cannot be one literal in
  ObjectScript, so the invariant is asserted rather than eliminated; (c) a new method
  builds over 512 characters of synthetic pairs and asserts the row is stored, cut at a pair
  boundary, `requiredPairsTruncated` 1, and withheld from a cross-user `ViewForUser` with
  `rowsWithheld` 1 and `rowsSent` 0. (DW-1127, DW-1124, DW-1125.)
- `src/OcuPilot/Test/AuditEvent.cls` — a leg asserting the captured `LogFailure` message for a
  dropped `LedgerRead` emission says a read was answered, not that a configuration change was made.
  (DW-1127.)
- `src/OcuPilot/Test/TurnNavigate.cls` — add a leg to `TestAC10WireStatusCodes` (`:541`) that drives
  the turn terminal with its Nav row unsettled, posts a settle and expects 409; and change
  `TestAC9SuccessfulCallNeverInvokesView`'s `:411` assertion from `%GetTypeOf("code") = "null"` to
  the key being absent. (DW-1096, DW-1095.)
- `src/OcuPilot/Test/ToolNavigate.cls` — a new method calling `Dispatch.SettleClient` for an
  `opened`, no-row outcome and asserting every emitted key is declared in `Navigate.ResultSchema`
  with a matching JSON type. (DW-1095.)
- `src/OcuPilot/Test/ErrorReadStub.cls` — add `ArmUntruncated()` beside `ArmFault` (`:21`) and read
  the flag where `Errors` hardcodes `truncated: true` (`:49`), **defaulting to true** so
  `Test/ToolDispatch.cls:427` and `Test/ToolEmit.cls:295` are untouched. (DW-1091.)
- `src/OcuPilot/Test/ReadTool.cls:1018-1026` — replace the instance-dependent leg with a
  stub-driven one: `ErrorReadStub.ArmUntruncated()`, `View(…, 1, …)` against the stub's three rows,
  assert one row and `truncated` 1, `Clear()` after. Correct the now-wrong comment at `:1024-1026`
  (`BoundedMaxRows` makes the context cap the port cap, so the old leg was reading the port's flag).
  Keep the live-instance legs at `:984-1016` and `:1032-1039` exactly as they are. (DW-1091.)
- `ui/browser/navigate.browser-spec.mjs` — in `before`, after the readiness assertion and before
  `armProbeDefinition`: `POST /api/ocupilot/turn/abandon` with the Basic header, then poll
  `TurnFixture.SlotOwner("_SYSTEM")` through `runIris`/`markerValue` until it is empty, bounded at
  15 s, throwing a message that names `^OcuPilotTurnSlot("_SYSTEM")`, the holding pid, how many turns
  were abandoned and `TURN.BUSY`. Wrap the AC4 announcement wait (`:174`) in an
  `audit.browser-spec.mjs:252`-shaped helper whose catch reports whether
  `[data-slot="lock"] .ocu-banner[role="status"]` is present and how many
  `.ocu-panel-message-user` nodes there are. Abandon in `after` too. (DW-1092.)
- `ui/browser/panel.browser-spec.mjs` — move `enabledProbeDefinition()` and `signedInAt(...)` inside
  the `try` (or hoist the context and clean in `finally`) for the three legs at `:238`, `:378` and
  `:431`; in `after`, remove the probe definitions **before** closing the browser and assert zero
  enabled definitions afterwards, with the matching precondition in `before` (the
  `gate.browser-spec.mjs:81-95` shape); replace both composer waits (`:381`, `:412`) with one named
  helper whose catch reports which surface is on screen (`app-sign-in` / `app-instance-notice` /
  `app-panel`, the composer's state, and the path) and which waits for the panel **and** a composer
  without `aria-disabled` — the surface the leg goes on to read. Correct
  `gate.browser-spec.mjs:118`'s claim that it is the only spec enabling a definition. (DW-1048.)
- `ui/browser/suggested-view.browser-spec.mjs` — **verify before writing.** If the branch already
  carries a `DW-1154:` leg asserting the transcript's computed `overflowY`, its `:focus-visible`
  outline width and offset, and the banner's `flexWrap` and link padding, add nothing and record
  DW-1154 as closed by the story whose commit carries it. If it does not, write that leg on
  `HOME_URL` at 1440×900 with no probe armed, following the computed-style pattern at
  `suggested-view.browser-spec.mjs:243-258`. Either way record why `.ocu-panel-empty` needs no leg:
  its declarations are typographic only, and the class's presence is already awaited at
  `panel-principal.browser-spec.mjs:101`. (DW-1154.)

**Acceptance Criteria:**

- Given all fourteen chartered entries, when the story completes, then each has a disposition
  recorded in `## Ledger Dispositions` below with the trailer line the lead is to write, and none is
  left `routed`.
- Given `CLAUDE.md` and `scripts/check-objectscript.py`, when a 22nd rule is added to `CHECKS`
  without editing `CLAUDE.md`, then `scripts/test_check_objectscript.py` fails naming both numbers.
- Given the client bundle, when `npm test` runs, then `ui/tools/build-output.test.mjs` measures the
  real `dist/` against `angular.json`'s raised budget and the commit message states that measurement.
- Given a cross-user ledger read of a row whose pair set was truncated, when `ViewForUser` answers,
  then the row is absent and `rowsWithheld` counts it — the gate fails closed, with the ledger
  (AD-46).
- Given the full browser suite run twice in succession against the throwaway, when it finishes, then
  no spec leaves an enabled probe definition behind and no leg reports a bare puppeteer timeout for
  a taken turn slot or an unrendered composer.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-39 (DW-447, DW-1127: one written sentence on the wire, raw text to the
log only), AD-12 (one response writer; the new reason goes through `Error.Render`), AD-24 (DW-1124,
DW-1125, DW-1091: a bound that cuts says it cut), AD-41 (DW-1125: the ledger is a bounded resource
and overflow is recorded, not a failed row), AD-46 (DW-1125: the cross-user gate lives with the
ledger and fails closed), AD-9 (DW-1125: the new column is protected state on the same guarded save),
AD-31 and AD-41 (DW-1092: one concurrent turn per user is what the slot enforces), AD-11 amended
(DW-1095, DW-1096: a client-fulfilled tool result is an ordinary bounded tool result), AD-35 and the
Secrets convention row (DW-398), AD-3's generator refusal (DW-398's declined alternative).

**Integration ACs (Rule 1).** This story introduces no service, module or shared component. The one
new file, `ui/src/app/core/log-paths.ts`, is a constant module with two consumers named in the same
task (`core/suggested-view.ts` and `areas/logs/error-log.store.ts`), and its integration AC is that
changing the prefix reddens the literal assertions in `shell/panel.spec.ts` and
`areas/logs/error-log.page.spec.ts` together. **Consumes:** every entry's own subject, listed in the
Code Map. **Consumed-by:** none — Epic 14's ledger screen is the first consumer of the ledger's 403
sentence and of `requiredPairsTruncated`.

**DW-1153 — raise, and the number is 820 kB.** Trimming is not a burn-down-scale change: the app has
no lazy route at all (`grep loadChildren|loadComponent` over `ui/src` is empty and
`build-output.test.mjs`'s tripwire says so), `marked`, `lowlight` and `dompurify` are reached from
`shell/reply.ts`, which `shell/panel.ts:31` pulls in eagerly on every route, and deferring them would
create a chunk the unmeasured-file tripwire (`build-output.test.mjs:186-192`) rejects until
classified. So raise both literals together, as Story 4.6 did once before (`7a64ee8` took 500 → 780
in one commit that also added the pinned literal). Story 4.6's stated formula — the measured total
rounded up to the next whole 20 kB — is degenerate at 778.37 kB, since it returns the gate itself;
820 kB is the ledger's own routed recommendation and leaves about 40 kB for Epic 5. **The 778.37 kB
figure is a record from Story 4.10's run, not a measurement taken here (inference);** the implement
stage measures its own `Initial total` and states that number in the commit. If that measurement
exceeds 820 kB, the number is the measurement rounded up to the next whole 20 kB and the commit says
so.

**DW-1154 — the cheapest honest pin is a browser leg, and it may already exist.** jsdom computes no
layout and `shell/panel.spec.ts` never loads the global SCSS, so it can assert the class names
(`:257`, `:318`) and nothing about `overflowY`, `outlineWidth`, `outlineOffset` or `:focus-visible`.
None of the six `prebuild` checkers cross-checks selectors used in TS or HTML against selectors
defined in SCSS — `client-lint.mjs` scans `.scss` only for color literals — and a selector-existence
checker would not catch a declaration lost inside a surviving block, which is half of what 4.10 lost.
**At plan time this worktree carries uncommitted changes to `ui/browser/suggested-view.browser-spec.mjs`
and `ui/tools/suggested-view.test.mjs` from a concurrently running stage, and the browser-spec change
already adds exactly this leg.** The implement stage must therefore verify before writing, must not
edit either file while another stage holds it, and closes DW-1154 against whichever story's commit
carries the leg.

**DW-398 — declined, on a measurement.** `Log.IsCredentialName` (`:172-197`) is suffix-or-exact
because DW-329 made it so, to stop `maxTokens` being masked. Measured over the whole shipped key set
— the three shipped `Screen.Tool` classes' argument schemas, `Definitions.Fields()` and
`Switches.Fields()`, all twelve descriptors' context fields, and all 451 rows of
`Screen/Tool/FieldLists.cls` — a word-boundary match on the full list newly masks 21 keys, every one
a false positive (`KeyDirectory`, `PublicKey`, `JWTAccessTokenTimeout`, `PasswordNeverExpires`, …),
and reddens two existing pins (`Test/Log.cls:255` via `tokenCount`, `ui/tools/field-lists.test.mjs:236`
via `Secret64Hint`). The narrowest variant that catches `passwordHash` — prefix-plus-boundary on
`password`, `passwd`, `pwd`, `secret`, `apikey`, `credential` — newly masks exactly one shipped key,
`PasswordNeverExpires` (`FieldLists.cls:385`, a `%Boolean`), which is a security-relevant field whose
value would be lost from the audit trail. No shipped key has the `passwordHash` shape today, which
the entry itself records. And the pattern is held equal across three sources by
`ui/tools/credential-lists.test.mjs` — the server redactor, the client pattern and the spine's Secrets
row — so changing it is a Conventions-row amendment the lead owns (Rule 20), not burn-down work. A
build tripwire refusing a *new* non-finally-secret key was considered and declined for the same
reason: it extends AD-3's generator-refusal Rule and so is a spine change. Recorded terminal with the
measurement and an observable `reopen_if`.

**DW-1095 — omit the member rather than change the schema grammar.** `Registry.SCHEMATYPES` has no
`null`, `SCHEMAKEYWORDS` has no `nullable`, and `type` must be a JSON string, so `["string","null"]`
is rejected; expressing nullability means editing the type vocabulary and `ValueProblem` for every
tool. Omitting the member instead makes the emitted payload conform exactly, needs no grammar change,
and matches what the declarations already say.

**DW-1096 — the ledger's evidence is partly wrong, and the fix is still small.** A terminal settle
answers 409 only where the loop settled the Nav row (`Loop.cls:638,654,665`); a turn that went
terminal without that code running — `TURN.ABANDONED.JOBLOST`, or a killed job — leaves the row
unsettled and the settle answers **200** `{"settled":true}`. `HandleStop` answers a terminal stop
with 200 `{"stopRequested": false}` and no code at all, so it is not the shape to copy here: a
settle for a dead turn is a claim on a row nothing will read, which is what `STATE.CONFLICT` means.

**Why no `EXPERIENCE.md` amendment and no `Api.Error` roster entry.** Neither changed sentence is a
UI string. `REASONAGENTBADBODY` is an envelope `reason` for a malformed body, reachable only from a
broken client; its sibling `REASONTURNBADBODY` has no Fixed-strings row either. The ledger's 403
sentence has no client surface at all — `ui/src/app/areas/` holds `agent`, `home` and `logs`, nothing
reads `GET /agent/ledger`, and a screen would render the client's own
`privilegeDeniedAction` pattern rather than the server reason. And because DW-1096 reuses
`STATE.CONFLICT` and DW-1125 reuses `rowsWithheld`, no code enters `TurnCodes()` or `LedgerCodes()`.
`OcuPilot.Test.TurnStore` and `OcuPilot.Test.AgentViolation` are still in the final run because
`Api/Error.cls` is edited: `TurnStore:243` sweeps `TURN*` parameters and `AgentViolation:71` sweeps
`AGENT*`, and a new `REASONAGENTBADBODY` must not disturb either.

**DW-1149 — the ledger overstates the silence.** `shell/panel.spec.ts:2306` holds the dates path as a
literal, so a change to `ERROR_LOG_DATES_PATH` alone already reddens. What nothing pins is the
*relationship*, which one source of truth removes rather than asserts; an equality assertion against
one constant would be structurally unfalsifiable (Rule 19) and is deliberately not added.

**Out of scope, recorded rather than fixed.** `Definitions`/`Switches` do not ask
`ReadRequestBody` for its stage, so a server-side read fault still renders a 400 where
`Api/Turn.cls:41-47` and `Api/Context.cls:46-51` render an internal error. DW-447 is about vendor
text in the reason and the minimal fix closes it; threading `.tStage` through twelve call sites in two
files would change status codes on paths nothing tests. Named here for the lead to ledger if it wants
it; this story does not create the entry.

## Ledger Dispositions

The implement stage records the outcome here; **the lead writes the trailer lines** (Rule 15(a): this
workflow never writes the ledger). One row per chartered entry.

| Entry | Disposition | Trailer line the lead writes |
|---|---|---|
| DW-398 | declined, measured | `status=wontfix-accepted owner=burndown by=burndown note=boundary match masks 21 shipped keys, all false positives; narrowest prefix form masks PasswordNeverExpires, a %Boolean; the pattern is a spine Conventions row. reopen_if=a shipped key carries a secret word non-finally` |
| DW-447 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=REASONAGENTBADBODY rendered alone, raw status to the log (AD-39)` |
| DW-1048 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=setup inside the try, cleanup before browser close with an asserted postcondition, named composer wait` |
| DW-1091 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=cap leg driven through ErrorReadStub, instance-dependent assertion removed` |
| DW-1092 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=before-hook abandons and waits for a free slot, failing with the pid and TURN.BUSY named` |
| DW-1095 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=SettleClient omits absent members; no schema-grammar change needed` |
| DW-1096 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=terminal settle refused 409 STATE.CONFLICT; the 200 was reachable on the joblost path` |
| DW-1124 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=cap read from LEDGERROWMAXLENGTH, ROUTEMAXLENGTH on State.Base, bound-versus-column pinned` |
| DW-1125 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=pairs cut at a pair boundary with requiredPairsTruncated; cross-user read withholds the row` |
| DW-1127 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=REASONAUTHNOPRIVILEGE names the request; LogFailure takes the message and Record passes a read-shaped one` |
| DW-1129 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=CLAUDE.md reads 21; test_check_objectscript.py now pins the stated count to len(CHECKS)` |
| DW-1149 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=one prefix in core/log-paths.ts; both literal specs redden together` |
| DW-1153 | fixed | `status=resolved-by:4-12-epic-4-burn-down by=adjudication note=maximumWarning and the pinned literal raised together; measured total in the commit message` |
| DW-1154 | fixed; owner resolved at implement time | `status=resolved-by:` plus the key of whichever story's commit carries the leg (this story if it wrote it, Story 4.10 if its own pass did), `by=adjudication note=browser leg asserts the transcript's computed overflow and focus ring and the banner's wrap and link padding`. The implement stage names that key in `## Auto Run Result`. |

## Verification

**Commands** — in this order. Never against `ocupilot`; the throwaway is `ocupilot-ci` on 52776.

- `uv run scripts/check-objectscript.py` — expected: 0 problems, and the footer now reads the same
  rule count `CLAUDE.md` states.
- `uv run scripts/test_check_objectscript.py` — expected: green, including the new count pin.
- `rsync -a --delete src/ /tmp/ocupilot-ci/src/` then
  `$System.OBJ.LoadDir("/opt/ocupilot/src", "ck", …)` inside `ocupilot-ci` — expected: clean compile.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>`, **one class per message**,
  each confirmed in `%UnitTest_Result` before the next, for: `OcuPilot.Test.AgentWire`,
  `OcuPilot.Test.Ledger`, `OcuPilot.Test.LedgerLimits`, `OcuPilot.Test.AuditEvent`,
  `OcuPilot.Test.TurnNavigate`, `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.ReadTool`,
  `OcuPilot.Test.ToolDispatch`, `OcuPilot.Test.ToolEmit`, `OcuPilot.Test.TurnStore`,
  `OcuPilot.Test.AgentViolation`, `OcuPilot.Test.Log`, `OcuPilot.Test.LedgerWire`.
- `cd ui && npm test` — expected: green; `build-output.test.mjs` measures the real `dist/` against the
  raised budget, and `angular-json.test.mjs` pins the new literal.
- `cd ui && npm run build` — expected: the six prebuild checkers pass; record the printed
  `Initial total` and put it in the commit message.
- `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` then
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  — expected: the whole suite green, run **twice in succession** so DW-1048's leak and DW-1092's slot
  both get the second-run condition they failed under.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: non-zero
  executed checks, all passing.
- `bash scripts/lint-docs.sh` — expected: clean.

**Mutations (Rule 19)** — apply, observe red, revert, confirm `git status --short` and
`git diff --stat` unchanged, and record each as `mutation: <change> → <test>` here:

- re-append `_ $System.Status.GetErrorText(pStatus)` at `Definitions.cls:1211` → `AgentWire`'s
  equality/no-vendor-text assertion.
- restore `#REASONAUTHNOPRIVILEGE`'s "that tool call" wording → `Ledger`'s cross-user 403 assertion.
- drop the message argument at `Event.cls:177` → `AuditEvent`'s dropped-`LedgerRead` message leg.
- delete the `IsTerminal` guard in `HandleNavigation` → `TurnNavigate`'s terminal-settle 409 leg.
- re-emit `%Set("code", "", "null")` in `SettleClient` → `ToolNavigate`'s declared-types leg.
- set a probe `Limits` subclass's `LEDGERROWMAXLENGTH` to 8192 → `Ledger`'s bound-versus-column leg.
- restore `Set tRow.RequiredPairs = pRequiredPairs` uncut → `Ledger`'s over-long-pairs leg (the row
  vanishes); and separately drop the `requiredPairsTruncated` branch from `ViewForUser` → the same
  leg's `rowsWithheld` assertion.
- delete `Set tTruncated = 1` from `ErrorRead.cls:171`'s cap branch → `ReadTool`'s rewritten cap leg.
- change `ERROR_LOG_PATH_PREFIX` in `core/log-paths.ts` → `shell/panel.spec.ts` and
  `areas/logs/error-log.page.spec.ts` both.
- append a 22nd entry to `CHECKS` without editing `CLAUDE.md` → the new
  `test_check_objectscript.py` count pin.
- lower `maximumWarning` 1 kB below the measured total → `build-output.test.mjs`; edit
  `ui/angular.json` alone → `angular-json.test.mjs:365`.
- delete `overflow-y: auto` from `.ocu-panel-transcript` → the DW-1154 browser leg's `overflowY`
  assertion (rebuild and redeploy the bundle first, or the old bundle answers).
- delete `this.panel.endSession()` from `App.verifyWhenSignedIn` → `panel.browser-spec.mjs`'s
  sign-out draft and full-screen assertions, proving the rewritten wait did not make the leg vacuous.
- drop the `router.navigate` call from `AgentNavigator`'s directive branch →
  `navigate.browser-spec.mjs` AC4's URL assertion, proving the slot precondition did not make it
  vacuous.

**Manual checks:** confirm no ledger file was hand-edited (`git diff -- _bmad-output/implementation-artifacts/deferred-work.md` is empty) and that `## Ledger Dispositions` carries fourteen rows.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan stage only; nothing was implemented and no command touched a container, a build, a test run or
IRIS, because another stage's browser suite was in flight against the slot-A throwaway. Commands
run: `git rev-parse`/`git branch`/`git add --refresh`/`git status`, `git log`/`git show` (read-only),
`ledger.sh show` for the fourteen chartered entries, file reads and greps, and
`bash scripts/lint-docs.sh` (0 issues, 0 prose problems).

Version-control sanity: the worktree was **not** clean at spawn — `ui/browser/suggested-view.browser-spec.mjs`
and `ui/tools/suggested-view.test.mjs` carry uncommitted changes from the concurrently running stage
the spawn prompt named, not from a missed bookkeeping commit. The plan stage writes only this spec,
so the condition the clean-tree check protects (a finalize commit containing only reviewed files) is
unaffected; recorded here rather than halted on. The same two files are why DW-1154's task is
verify-then-write.

Ledger: no entry was written and no entry was created. The dispositions and the exact trailer lines
are in `## Ledger Dispositions` for the lead to write at adjudication (Rule 15(a)).
