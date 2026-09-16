---
title: 'Story 3.7: Switches — the kill switch and enforced read-only'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** An administrator has no way to restrain or silence the agent. `Kernel/State/Agent.ReadOnly`
is stored and read by nothing, no kill switch exists in any form, and there is no instance-wide switch
state, no Switches screen and no gate that a write path could consult.

**Approach:** One store for instance switch state and one for per-user holds, one kernel verdict that
every point of effect calls and nothing else duplicates, one `form-page` screen over them reached from
the Agent co-pilot side bar, and the panel's published banners and footer read-only line driven from
the same verdict.

## Boundaries & Constraints

**Always:**

- **One enforcement point.** Exactly one class answers "may this write happen, and why not" —
  `Kernel/Restraint.cls`. The write-tool boundary, the turn loop's step check and the confirm
  transition all call it; none re-derives the verdict (AD-30, AD-40). Story 10.4 adds a per-user
  read-only source *inside* this verdict, never a second caller-side check.
- The verdict reads the store on every call and returns **values, never an OREF** — no memo, no
  process-private cache, no held object (AD-30's "never cached for the length of a turn"; a held OREF
  makes `%OpenId` return the stale copy, `.claude/rules/objectscript-basics.md`).
- Switch state lives in the protected database, reached only through `Kernel/State/Base`'s guarded
  methods, inside a `New $ROLES` frame that spawns nothing and re-enters nothing (AD-9).
- Every user-facing literal is already published in `EXPERIENCE.md`'s Fixed strings table.
- Persistent class names, package dots included, are **29 characters or fewer** (Conventions).
- Per-user holds reference a user by scoped identity as data, never a foreign key (AD-37).

**Never:**

- No second gate. No client-side refusal that stands in for the server's, no cached verdict, no
  read-only check inside a tool body.
- No turn loop, no transcript, no tool dispatch, no per-user *read-only* toggle, no turn limits —
  Epic 4, Story 4.3 and Story 10.4 respectively.
- No unconditional panel: Story 4.3 owns that.
- No new `read` source kind, no `Screen/Read.cls` change, no hand-written Storage.
- No real outbound provider call.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh instance | no switch row written | verdict = allowed; kill switch off; `GET /agent/switches` answers the defaults | No error expected |
| Enforced read-only on | instance row `EnforcedReadOnly` 1 | verdict = blocked, code `AGENT.READONLY.ENFORCED`, published reason; footer key `statusReadOnlyEnforced` | No error expected |
| Definition read-only | instance row off, resolved definition `ReadOnly` 1 | verdict = blocked, code `AGENT.READONLY.DEFINITION`; footer key `statusReadOnlyByDefinition` | No error expected |
| Both read-only sources on | enforced 1 and definition 1 | verdict blocked once; the **enforced** code and footer key win (precedence below) | No error expected |
| Kill switch, global | instance row `KillSwitch` 1 with a reason | verdict = blocked, code `AGENT.KILLSWITCH.GLOBAL`, reason carried to the banner | No error expected |
| Kill switch, one user | a hold row for `$USERNAME` | verdict = blocked for that user only, code `AGENT.KILLSWITCH.USER` | Another user's verdict unchanged |
| Hold on a deleted user | hold row naming a user no longer present | row renders "no longer present"; the screen does not fail (AD-37) | No error expected |
| Switch flipped mid-read | store changed between two verdict calls in one process | the second call answers the new state | Falsifies the no-cache claim if it does not |
| Save by a non-administrator | caller holds no `OcuPilotAdmin:USE` | 403, `AUTH.NOPRIVILEGE`, `detail.failedPair` | Rendered by `Api.Error.Render` |
| Kill switch on with no reason | `KillSwitch` 1, `Reason` empty | 422, one `VALIDATION.FAILED` envelope with `detail.violations[]` `{field, code, reason}` | AD-39 |

</intent-contract>

## Code Map

Server — all under `src/OcuPilot/`:

- `Kernel/State/Base.cls` — the only escalation point. `Parameter APPLICATION = "OcuPilotState"`,
  `#ADMINRESOURCE = "OcuPilotAdmin"`; public `GuardedSave`, `GuardedOpenId`, `GuardedExistsId`; private
  `GuardedOpenOneWhere*`, `GuardedIdsWhere*` (call-site literal SQL only). Every new store extends this.
- `Kernel/State/Egress.cls` — **the singleton pattern to copy**: `Resolve(Output pSettings)`,
  `SetGuarded(ByRef pValues)`, private `GuardedCurrent()` = `SELECT TOP 1 ID … ORDER BY ID`, defaults as
  `Parameter`s so a clean instance needs no row. `Resolve` returns a subscripted array, not an object.
- `Kernel/State/Agent.cls:85` — `Property ReadOnly As %Boolean [ InitialExpression = 1 ]`, stored by
  Story 3.1 and read by nothing; `ResolveDefault(Output pId)` (`:431`) answers `""` when the marked
  definition is disabled. AC8's second source.
- `Kernel/Egress.cls` — the policy class beside the `Kernel/State/` store. The layout `Kernel/Restraint.cls`
  follows.
- `Api/Router.cls:63` `XData UrlMap` — longest-path-first; `/agent/definitions/*` and `/agent/providers`.
  New `/agent/switches` routes go beside `/agent/providers` (Conventions › REST route ordering).
- `Api/Definitions.cls` — `IsAdministrator()` (`:816`), `RenderForbidden()`, `RenderViolations(ByRef pViolations, pReason)`
  (`:882`), `LogChange`/`ChangeSet`, `SelectionProjection` (`:1011`). Reuse, do not re-author.
- `Kernel/AgentRules.cls` — `Validate(ByRef pValues, pExistingId, Output pViolations)` accumulates
  `$ListBuild(field, code, reason)`; `ViolationsJson`. The shape a switches validator follows.
- `Api/Error.cls:339-480` — the `Parameter AGENT*` code vocabulary; new codes land here.
- `Screen/Descriptor/AgentDefinitionForm.cls` — **the exact descriptor shape to copy**: `sideBarPosition` 0,
  `archetype "form-page"`, no `read`, no `table`, `labelKey`, `privileges [{OcuPilotAdmin, USE}]`,
  `classicPage ""`. Switches differs only in `sideBarPosition` (2, after Definitions' 1), `route`,
  `labelKey`, `entityType`, `toolIdentifier` and its own `rowActions`.
- `Screen/Registry.cls:378` `SideBarPositionProblem` (0 is the declared sentinel, absence is refused);
  `ReadProblem` (`:665-676`) refuses `rowGet` and `criteria` on a state source and always ends in
  `TableProblem` (`:746`) — so a descriptor that declares `read` must also declare `table`.
- `Screen/Read.cls:43` `Parameter READTYPE = "LIST"`, `:84` `STATEROWSMETHOD = "GuardedScreenRows"`,
  `:93` `StateClass`. Read-only evidence for the DW-369/AD-36 decision below; unchanged by this story.
- `Kernel/EntityType.cls` — closed enum (AD-14); add the switches entity type here or the build fails.
- Tests: `Test/State.cls` (AD-9 escalation and denial), `Test/AgentState.cls`, `Test/Descriptor.cls:526`
  (the closed declaration-key set), `Test/ScreenRegistry.cls`, `Test/AgentWire.cls`, `Test/Envelope.cls`.

Client — all under `ui/src/app/`:

- `core/strings.ts` — flat frozen `STRINGS`, 251 keys; the ten this story adds take it to 261.
  **Already holds and nothing yet renders:**
  `agentReadOnlyEnforcedBanner` (`:189`), `agentKillSwitchBanner` (`:191`), `statusReadOnlyOff` (`:193`),
  `statusReadOnlyEnforced` (`:195`), `statusReadOnlyForYou` (`:197`), `statusReadOnlyByDefinition` (`:199`),
  `agentWriteBlockedByReadOnly` (`:59`), `proposalStatusAgentSwitchedOff` (`:161`).
- `core/agent-status.ts` — models exactly one fact (any definition enabled), `AGENT_DEFINITIONS_PATH` (`:30`),
  no timer; reloaded by `app.ts:365`, by its own `onChange` on the `agent-definition` change event
  (`:208`) and by `retryWhenReachable` (`:176`). Carries nothing about read-only or the kill switch — this
  story adds the restraint fact here or in a sibling with the same lifecycle.
- `shell/panel.ts` — `shown` (`:144`) is `navigation.loaded() && agentStatus.answered() && !configured()`;
  one banner, an if/else on `administrator`; footer composer and Send `aria-disabled` with hard-coded
  literals, both `aria-describedby` = `REASON_ID` (`:13`). No footer read-only line exists.
- `shell/rail.ts` — per item: button (`aria-label` = area name, `aria-describedby` = `item.tipId`), the dot
  (`:107-109`, `role="img"`, `aria-label` = `item.attention`), the tooltip span (`:110`, `{{ item.tooltip }}`).
  `item.tooltip` (`:143-145`) is `formatArea(STRINGS.navRailItemTooltip, label)` or the Requires sentence;
  `attentionReason()` (`:183-189`) returns only the two unconfigured sentences. **DW-383 is exactly this
  wiring.**
- `shell/screen-outlet.ts:46-52` `ARCHETYPE_PAGES` keyed by archetype, `'form-page': DefinitionFormPage`;
  resolved at `:221-228` where `screen.descriptor` is already in hand. **DW-369.**
- `core/screen-actions.ts:52-58` `ACTION_LABELS` keyed by bare action id; `actionLabel(actionId)` (`:39-41`)
  falls back to the id. Call sites `shell/command-bar.ts:295,390,455` and `shell/command-box.ts:451,455`,
  both of which already hold `screen.descriptor`. **DW-370.**
- `core/navigation.ts:123` `isListedScreen` = `sideBarPosition > 0`; `:106` `builtScreens()` feeds
  `app.routes.ts:53`, which adds `canDeactivate: [leaveFormGuard]` for `form-page`.
- `ui/tools/strings.test.mjs:310` — the `expectedLiterals.length >= 150 && <= 240` band, `:311` its stale
  "roughly 230" message, `:298-308` the comment block each widening documents itself in, and `:349-353` the
  count equality, whose own failure text states the arithmetic. `ui/tools/screen-mirror.mjs` regenerates
  `core/screens.generated.ts` and `--check` refuses drift; a `built: true` archetype with no client page
  fails `ng build`.

Baseline: `npm test` is **red at dispatch, by design** — the gate commit published the three `EXPERIENCE.md`
rows before any key exists, exactly as Story 3.6's gate commit did. `node --test tools/*.test.mjs` reports 768
tests, 765 passing, **3 failing, all in `strings.test.mjs`**: the band (246 against `<= 240`), the ten literals
absent from `strings.ts`, and 251 keys against an expected 261. The first client task below is what turns them
green; no other suite is touched, and the 357 component tests are unchanged.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Switch.cls` — new singleton store (`Switch`, not `Switches`: `OcuPilot.Kernel.State.Switches`
  is 30 characters and the 29-character cap refuses it) holding `KillSwitch`, `KillSwitchReason`,
  `EnforcedReadOnly`, `ShareContextByDefault`, `UpdatedAt`; `Resolve(Output pValues)` and `SetGuarded(ByRef pValues)`
  on the `Kernel/State/Egress.cls` pattern — defaults as parameters, no row on a clean instance.
- `src/OcuPilot/Kernel/State/Hold.cls` — new per-user kill-switch rows: `UserName` (unique index),
  `Reason`, `CreatedAt`; `GuardedForUser`, `GuardedList`, `GuardedCreate`, `GuardedDeleteId`,
  `GuardedScreenRows`. Weak reference to the user (AD-37).
- `src/OcuPilot/Kernel/Restraint.cls` — **the enforcement point.** `Verdict(pUserName, pDefinitionId, Output pVerdict)`
  reads both stores plus the resolved definition's `ReadOnly`, returns `blocked`, `code`, `reason` and
  `footerKey` as values. Reads on every call; holds no object across the return.
- `src/OcuPilot/Api/Error.cls` — add the `AGENT.READONLY.*` and `AGENT.KILLSWITCH.*` codes and their
  written reasons.
- `src/OcuPilot/Api/Switches.cls` — `GET`/`PUT /agent/switches` and the per-user hold routes, reusing
  `Api/Definitions.cls`'s gate, envelope and violation renderer. `GET` is administrator-gated; the panel
  reads its restraint through the same ungated shape `HandleList` already uses for enablement.
- `src/OcuPilot/Api/Router.cls` — add the routes above `/agent/definitions`, preserving the three
  `UrlMap` ordering invariants.
- `src/OcuPilot/Kernel/EntityType.cls` — add the switches entity type (AD-14).
- `src/OcuPilot/Screen/Descriptor/AgentSwitches.cls` — the second `form-page` descriptor, `sideBarPosition` 2.
- **Task — the ten keys and the band, one commit.** `ui/src/app/core/strings.ts` and
  `ui/tools/strings.test.mjs` change together or the tree stays red. Add the ten keys for `EXPERIENCE.md`'s
  three new rows, taking `strings.ts` to **261** = 246 table literals + 12 extracted from prose + 3 named
  extras; widen `:310`'s upper bound from 240 to **260**; replace `:311`'s "roughly 230" with the live
  figure; and append Story 3.7's entry to the `:298-308` comment block in the style of the 2.10, 2.12 and
  3.5 entries there — the ten literals, and why 260: the band is a tripwire against unbounded string growth
  rather than a cap on one screen, it has held because every widening was deliberate and documented, and 260
  leaves headroom for 3.8 and the burn-down without making the next widening automatic. (Story 3.6 added
  rows but no entry — at 236 it still fit the band.) This task runs first: every client task below renders
  one of these keys.
- `ui/src/app/core/screens.generated.ts` — regenerate with `screen-mirror.mjs`; never hand-edit.
- `ui/src/app/shell/screen-outlet.ts` — key `ARCHETYPE_PAGES` by `screen.descriptor` with the archetype map
  as the fallback, keeping the exhaustiveness guarantee (**DW-369**).
- `ui/src/app/core/screen-actions.ts` — give `actionLabel` a descriptor argument and scope the map by
  descriptor, falling back to the shared entry (**DW-370**); update both call sites.
- `ui/src/app/core/agent-status.ts` — add the restraint fact beside `configured()`, refreshed on the same
  three triggers.
- `ui/src/app/shell/rail.ts` — render the attention reason inside the tooltip element alongside the area
  tooltip, so `aria-describedby` reaches it (**DW-383**); light the dot on the kill switch as well.
- `ui/src/app/shell/panel.ts` — widen `shown` to `unconfigured || restrained`; add the enforced-read-only
  and kill-switch banners in `EXPERIENCE.md`'s declared order; add the always-shown footer read-only line;
  bind the composer and Send reason to whichever banner applies.
- `ui/src/app/areas/agent/switches.page.ts` — the Switches form page.
- Tests — ObjectScript: one class per concern, run **one `iris_execute_tests` call per message**; client:
  `ui/tools/*.test.mjs` for `core/`, `*.spec.ts` for the panel, rail, outlet and page.

**Acceptance Criteria:**

- Given a write path, the turn loop and the confirm transition, when each asks whether a write may
  happen, then each calls `Kernel/Restraint.Verdict` and a test asserts no second place in the tree
  computes the verdict.
- Given enforced read-only on, when any user's panel renders, then it carries the published enforced
  banner and the footer line reads the `statusReadOnlyEnforced` value; when it is off, the line reads
  `statusReadOnlyOff`.
- Given the kill switch on for everyone or for that user, when their panel renders, then it carries the
  published kill-switch banner with the stored reason, the composer and Send stay focusable and
  `aria-disabled` described by that banner, and every screen still loads.
- Given the kill switch on, when the rail renders, then the dot lights and its reason reaches both the
  dot's accessible name and the rail item's tooltip.
- Given a fresh install, when install completes, then the kill switch is off and no switch row exists.
- Given a non-administrator, when they call any switches route, then it is refused server-side with the
  failed pair named.
- Given the Switches screen, when an administrator opens it, then it renders as its own `form-page` and
  the Definition form still renders as its own (DW-369), and its row actions carry its own labels (DW-370).
- Given `EXPERIENCE.md`'s three new rows, when `node --test tools/strings.test.mjs` runs, then the three
  tests red at dispatch pass, `strings.ts` holds 261 keys, the band reads `<= 260`, and its message names
  the live count rather than "roughly 230".
- Integration AC — given `core/agent-status.ts` carries the restraint fact, when `ui/src/app/shell/panel.ts`
  renders, then it reads that fact rather than issuing a second server call, and the published footer line
  appears in the DOM — asserted in `panel.spec.ts` against the rendered DOM, not against the store.

## Spec Change Log

**2026-09-15 — `EXPERIENCE.md` amended (Rule 5, lead).** The halt's blocking condition was that the Fixed
strings table carried no copy for the Switches screen. The lead appended three rows — commit
`8874e504711f4add25927548ee68b1917e6af210` — carrying the ten proposed literals verbatim; no existing row
changed. Table literals 236 → **246**. The band question the halt referred upward is decided: this story
widens `strings.test.mjs`'s upper bound to **260**, in the named task above. KEEP: these ten literals and
their two sibling rows are the authorized copy — the client renders the keys and composes no sentence of
its own.

## Review Triage Log

## Design Notes

**Consumes:** Story 3.1's `Kernel/State/Agent.ReadOnly` and `ResolveDefault`; Story 3.5's form-page shell,
`ARCHETYPE_PAGES` and `ACTION_LABELS`; Story 3.6's `agent-status.ts`, rail attention dot and panel.

**Consumed-by:** Epic 4's turn loop (calls `Restraint.Verdict` between steps, AD-30); Epic 5's confirm
path (calls it inside AD-34's transition); Story 10.4 (adds a per-user read-only source inside the same
verdict); Story 4.3 (inherits the panel footer line).

**Governing ADs:** AD-30 (one enforcement point, evaluated at the point of effect, never cached), AD-40
(the gate is on the write, inside AD-34's transition), AD-9 (protected state, `New $ROLES`, no spawn and
no re-entry), AD-8 (privilege at call time), AD-7 (the job writes OcuPilot's own state, never the
instance), AD-37 (weak references), AD-39 (`{field, code, reason}`), AD-5 and AD-36 (descriptor and read
contract), AD-14 (closed entity-type enum), AD-44 (no classic equivalent), AD-12 and AD-21.

**Where the gate lives, and why 10.4 sits over it.** `Kernel/Restraint.cls` sits beside `Kernel/Egress.cls`,
the shipped layout of a policy class over a `Kernel/State/` store; `Kernel/Governance/` is AD-22's
polish-week folder and is deliberately left empty. The verdict takes the acting user and the resolved
definition as arguments and returns a value. Story 10.4's per-user toggle becomes a fourth source read
*inside* `Verdict` — one more `If` and one more footer key (`statusReadOnlyForYou`, already published) —
so the three call sites never change and no second check is possible. A test that enumerates every caller
of the restraint codes is what keeps that true.

**The step-boundary half (AC4 and AC6).** The turn job does not exist; Epic 4 builds it. What this story
can build and pin now is the verdict itself and its no-cache property: a test that flips the store between
two `Verdict` calls in one process and asserts the second answers differently. What is necessarily Epic 4's
is the loop that calls it between steps and abandons the turn. The seam that stops a second enforcement
point is that `Verdict` is the only producer of the restraint codes: Epic 4 consumes a verdict, it does not
compute one, and the caller-enumeration test fails if it tries.

**AC8's two read-only sources compose one line.** Precedence is broadest scope first — enforced, then
per-user (10.4), then the definition's flag — which is the order `EXPERIENCE.md`'s own published footer row
lists them in. `Verdict` returns exactly one `footerKey`; the client renders that key and never composes a
sentence of its own, so the line cannot say two things at once *(inference: the published row's ordering is
the only evidence that selects a precedence; no document states one outright)*.

**Why Switches is not a declared `state` read (DW-369 and AD-36).** The existing machinery serves it, but
through the form-page grammar, not the read grammar. `Screen/Read.cls` pins `READTYPE = "LIST"` and
`Screen/Registry.cls`'s `ReadProblem` always ends in `TableProblem`, so a descriptor that declares a `read`
must also declare a `table` — a form cannot borrow the read without declaring columns it does not render.
`AgentDefinitionForm` therefore declares neither and loads its own endpoint, and its class comment says why.
Switches follows it exactly. Extending `Read.cls` to serve a single row would be the bespoke move here, not
the declared one.

**Ledger inbox.** DW-369: addressed — `ARCHETYPE_PAGES` keyed by descriptor. DW-370: addressed —
`ACTION_LABELS` scoped by descriptor. DW-383: addressed — the tooltip element renders the attention reason
beside the area tooltip, which the button's existing `aria-describedby` already points at, so no new
published literal is needed for the fix itself; the kill switch's reason sentence is the published
kill-switch banner, and the `attention-dot` component row (`EXPERIENCE.md:353`) already authorizes both
surfaces — "Shown when the agent is unconfigured or the kill switch is on … Tooltip and accessible name
state the reason."

## Verification

**Commands:**

- `cd ui && npm run build` — expected: the six `prebuild` checkers pass, including `screen-mirror --check`
  against the regenerated mirror.
- `cd ui && npm test` — expected: 768+ tool tests and 357+ component tests, 0 failures — including the
  three `strings.test.mjs` tests that are red at dispatch.
- `cd ui && npm run test:browser` — expected: green; anything about geometry belongs here, not jsdom.
- `uv run scripts/check-objectscript.py` — expected: 17 rules clean on the changed paths.
- `bash scripts/lint-docs.sh` — expected: clean.
- `mcp__iris-dev__iris_doc_load` with `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`,
  `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` — expected: whole tree compiles.
- `bash scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` — expected: non-zero executed
  checks, all passing.

**Manual checks:**

- `%UnitTest_Result` SQL probe confirms the per-class totals before any suite is called green.

## Auto Run Result

Status: ready-for-dev

**Precondition met.** `EXPERIENCE.md`'s Fixed strings table now carries the Switches screen's own copy: three
rows at `:341-343` holding the ten literals verbatim. Re-derived with the test's own extractor rather than by
grep — the table is 90 rows at `:254-343` and yields **246** literals, no duplicates — and confirmed by the
count assertion's own failure text, `expected 246 table literals + 12 extracted from prose + 3 named extras,
found 251 keys`. That is the arithmetic behind 261.

**Every literal the Code Map needs is authorized.** The ten new ones; the eight panel and footer keys already
published and still unrendered; and, for the form itself, `actionSave`, `actionCancel`, `formSaved`,
`formLeaveWithoutSaving` and `formRequiredFieldsLegend` from the `form-page` contract plus `processColumnUser`
for the user field — each checked against the table and against `strings.ts`, not recalled.

**One documentation asymmetry, carrying no literal and blocking nothing.** The kill-switch banner row's
**Where** cell (`:287`) still reads only "kill-switch banner", while the two unconfigured rows (`:283`, `:285`)
name the attention dot. The `attention-dot` component row (`:353`) independently states "Shown when the agent
is unconfigured or the kill switch is on … Tooltip and accessible name state the reason", which is the
authority AC4 and DW-383 rest on, and no test reads that Where cell.

Planning is otherwise unchanged: every Code Map path and line anchor was re-verified against this tree, and
the standing decisions stand.
