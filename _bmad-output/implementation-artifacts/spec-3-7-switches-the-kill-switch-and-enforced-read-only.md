---
title: 'Story 3.7: Switches — the kill switch and enforced read-only'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: '3289663e154071428e25e69c50a30fe5d8be2f64'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A hold whose user no longer resolves renders `faultAbsentEntity`, whose second half names a
      list the Switches screen does not have.
    evidence: |-
      `faultAbsentEntity` is the one published sentence for AD-37, and it ends "Return to the list
      to see what is there now." The Switches screen is a form-page with no list. Inventing an
      inline marker would be unpublished copy, which `strings.test.mjs` refuses; the copy call is
      the owner's.
    location: >-
      ui/src/app/areas/agent/switches.page.ts absentSentence
    severity: low
  - summary: >-
      AC1's caller half is not implemented: no write path in the tree calls
      `Kernel/Restraint.Verdict`, so nothing is gated yet.
    evidence: |-
      `Verdict`'s only non-test caller is `Restraint.Resolved`, reached from `GET /agent/restraint`
      alone -- a display read. `src/OcuPilot/Screen/Tool/` holds no class whose `KIND` is `write`.
      The turn loop is Epic 4's and the confirm transition Epic 5's, which the spec's Design Notes
      state; what is not recorded anywhere a gate reads is that AC1 is therefore half-open.
    location: >-
      src/OcuPilot/Kernel/Restraint.cls Verdict
    severity: medium
  - summary: >-
      Two administrators saving the Switches screen concurrently silently lose one write.
    evidence: |-
      `Switch.SetGuarded` is read-modify-write with no concurrency control: the later save merges
      over a snapshot taken before the earlier one. It follows `Kernel/State/Egress.SetGuarded`
      exactly -- the shipped singleton pattern the spec names as the one to copy -- which has the
      same shape, so the fix is project-wide rather than this story's. Nothing demonstrates two
      writers today.
    location: >-
      src/OcuPilot/Kernel/State/Switch.cls SetGuarded
    severity: medium
  - summary: >-
      Switches declares `create` and `delete` actions its page registers no handler for, so the
      command bar and box draw a permanently disabled row action on a screen with no rows.
    evidence: |-
      `command-bar.ts`'s `resolved()` maps every declared `rowActions` entry with
      `ariaDisabled: 'true'` and no handler check, and `command-box.ts` offers it with "Select a
      row first"; `hasPrimaryAction` gates on a registered handler, so `create` draws nowhere.
      `AgentDefinitionForm`, the sibling form-page, declares `primaryAction: {id: ""}` and
      `rowActions: []`. The smallest fix contradicts the spec's Code Map ("its own `rowActions`")
      and AC7; the fuller fix registers handlers the spec did not scope.
    location: >-
      src/OcuPilot/Screen/Descriptor/AgentSwitches.cls rowActions
    severity: medium
  - summary: >-
      `Restraint.Verdict`'s fail-closed answer on an unreadable store has no test.
    evidence: |-
      The class states "a read that fails blocks" and initialises `blocked` 1, but every method of
      `Test/Restraint.cls` arranges a readable store. `Verdict` reaches its three stores by hard
      `##class(...)` name, so no seam exists for the probe-subclass idiom used elsewhere
      (`Test/EgressProbe`, `SmokeReadFault`). The only shipped consumer, `HandleRestraint`, checks
      `$$$ISERR` and renders 500, so the exposure begins with Epic 4's callers; the seam is better
      added beside the first real caller.
    location: >-
      src/OcuPilot/Kernel/Restraint.cls Verdict
    severity: medium
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

### 2026-09-16 — Review pass

- verdicts: 49 findings — high 0, medium 24, low 22, false 3, maybe-false 0
- findings:
  - `[medium]` `[defer]` Concurrent `PUT /agent/switches` is read-modify-write, so the later save reverts the earlier — `Switch.SetGuarded` copies `Kernel/State/Egress.SetGuarded`, the shipped singleton pattern the spec names; the same shape, so the fix is project-wide. Deferred with evidence.
  - `[low]` `[patch]` A `killSwitchReason` over 512 characters passed validation while the switch was off and failed at the column as a 500 — the length rule now applies whichever way the switch is set (`SwitchRules.ValidateSwitches`), and `SwitchesWire` pins both directions.
  - `[low]` `[reject]` An over-length reason is reported under `AGENT.SWITCH.REASONREQUIRED`, whose sentence says "give a reason" — real, but a separate length code is a new entry in the published vocabulary plus its sentence and two pinned roster counts, which is more than a direct correction; an operator meeting a 512-character reason is not everyday use.
  - `[low]` `[reject]` Two concurrent hold creates for one user make the loser a 500 rather than the duplicate violation — a microsecond race; the documented contract says the rule answers first, not that the index never fires, so no claim is contradicted. The fix adds an error-code branch.
  - `[medium]` `[patch]` `LogChange` walked the raw arrays, so `updatedAt` — restamped on every write — made a no-op `PUT` record a change; it is now skipped, and `SwitchState` pins an empty change set for a write that moved nothing. The "no id on a hold row" half is `low` and rejected: `userName` identifies the row.
  - `[medium]` `[patch]` Adding or removing a hold absorbed the whole response body, discarding an unsaved switch edit while `FormDirty` still claimed there were edits — `reload()` now refreshes the hold rows alone, pinned in `switches.page.spec.ts`.
  - `[low]` `[reject]` `focusField` builds `ocu-switches-<field>`, which misses the three checkbox ids — unreachable: `ValidateSwitches` emits on `killSwitchReason` alone and `ValidateHold` on `userName`/`reason`, all of which match. A lookup table for ids no violation names is complexity against a state never shown reachable.
  - `[low]` `[reject]` `UserExists` answers "absent" for a `<PROTECT>` as well as for a missing user, so an OcuPilot administrator lacking `%Admin_Secure` sees every hold marked no longer present — advisory only; the row, its reason and its action are unaffected. Distinguishing the two needs a third `present` state and published copy, which is the owner's call.
  - `[medium]` `[defer]` The descriptor declares `create`/`delete` but the page registers no handler, so the bar draws a permanently disabled row action on a screen with no rows — the smallest fix contradicts the spec's Code Map and AC7. Deferred with both candidate fixes.
  - `[false]` `[reject]` "The containment rule will refuse the caller `ReasonForRestraint` was written for" — it does not: `Verdict` already returns `reason`, so Epic 4's write tool renders the verdict rather than resolving a sentence. The rule steers that caller to the verdict, which is its purpose.
  - `[medium]` `[patch]` Three places claimed the containment rule keeps "exactly one enforcement point" falsifiable; it bans a second producer of a restraint *code*, which a caller reading the two stores directly would evade — corrected at all three origins (`Kernel/Restraint.cls`, `Test/Restraint.cls`, the checker's own comment) and stated in the rule roster.
  - `[low]` `[patch]` The checker's module docstring enumerated rules 1–17 while `CHECKS` ran 18 — the 18th is now in the roster. The `CLAUDE.md` half is an agent-context file and is deferred.
  - `[low]` `[reject]` Two wire tests assert `blocked = 0` without controlling the resolved definition — a confusing red, never a false green, in a state the suite does not produce; adding preconditions to two classes is more than a direct correction.
  - `[medium]` `[patch]` `Hold.GuardedForUser`'s case-insensitivity claim was documented and unpinned, and a lookup folding case differently from the unique index would let a held user act under another spelling — `SwitchState` now pins the lookup, the id lookup and the index together.
  - `[low]` `[patch]` The browser spec's `restoreSwitches` ignored its own status and its header claimed the throwaway is left as found — it now asserts 200, restores the fourth field, and the header says what actually survives.
  - `[low]` `[patch]` `AGENT_DEFINITION_SCOPE` now carries two entity types while its comment named one — comment corrected at its origin.
  - `[medium]` `[patch]` Every hold's remove button had the same accessible name — `aria-labelledby` now composes it from the button's own label and the row's user-name element, so no sentence is written that EXPERIENCE.md has not published; pinned in `switches.page.spec.ts`.
  - `[medium]` `[defer]` AC1's caller half is neither met nor recorded — recorded in `deferred:` with the evidence that `Verdict`'s only non-test caller is a display read.
  - `[low]` `[patch]` (= the length finding above) An over-length reason reaches `%Save` — same root cause, same fix.
  - `[low]` `[reject]` A definition deleted between `GuardedExistsId` and `GuardedOpenId` makes `Verdict` answer an error — confirmed: `Base.GuardedOpenId` errors on a missing id. A microsecond race whose outcome is fail-closed on a display read, so the panel is briefly absent; adding a branch guards a state never shown reachable.
  - `[low]` `[reject]` (= the duplicate-hold race above) Same root cause, same reason.
  - `[low]` `[patch]` A `killSwitchReason` sent as a JSON number or boolean reached the published banner as the operator's reason — `MergeBody` now requires a JSON string for a string field, the strictness `StringMember` already applies on the hold routes; pinned in `SwitchesWire`.
  - `[low]` `[reject]` (= `UserExists` above) Same root cause, same reason.
  - `[medium]` `[defer]` (= the concurrent `PUT` above) Same root cause, deferred.
  - `[medium]` `[patch]` `LogChange` wrote through `##class(OcuPilot.Api.Definitions).LogInfo` by hard class name — the very thing that method's own comment says no test can intercept — and the class header named `Definitions.LogChange`, which the code never calls. A local `LogInfo` wrapper restores the seam, the header states what the code does, and `Test/SwitchesProbe` plus a `SwitchState` method read the emitted line back.
  - `[medium]` `[patch]` (= the hold-write buffer clobber above) Same root cause, same fix.
  - `[medium]` `[defer]` (= the declared-actions finding above) Same root cause, deferred.
  - `[low]` `[reject]` (= `focusField` above) Same root cause, same reason.
  - `[medium]` `[defer]` (= AC1's caller half above) Same root cause, deferred.
  - `[medium]` `[patch]` The `agent-switch` change record was emitted and nothing observed it, while its sibling is pinned in `AgentWire` — closed with the probe and the test above; the mutation (delete the `..LogInfo` call) is recorded under Verification.
  - `[medium]` `[patch]` `MergeBody`'s quoted-flag guard — fail-open on the kill switch — had no test, while the definition route's equivalent is pinned — `SwitchesWire.TestABadlyTypedFieldIsIgnoredRatherThanCoerced` now covers both directions.
  - `[medium]` `[patch]` DW-370 was pinned as a function and never resolved through either surface that draws it; both specs use a stub descriptor with no entry, so they passed with or without the scoping — `command-bar.spec.ts` now builds the `AgentSwitches` descriptor and asserts the drawn label.
  - `[medium]` `[patch]` AC5's only pinning test deletes the switch row in its own setup, so it cannot tell an install that wrote none from one that wrote a row — `Install.Smoke.CheckAgentSwitches` now asks it of a genuinely fresh instance, and CI and a local run ask the same question.
  - `[medium]` `[defer]` `Verdict`'s fail-closed answer on an unreadable store is unpinned and has no store seam to pin it with — deferred with the evidence and the reason it belongs beside Epic 4's first real caller.
  - `[medium]` `[patch]` (= the `updatedAt` finding above) Same root cause, same fix.
  - `[low]` `[patch]` (= the length rule above) Same root cause, same fix.
  - `[low]` `[patch]` `panel.spec.ts`'s closing leg mounted a second fixture and claimed to test a re-read, with a trailing `detectChanges()` on a destroyed TestBed that asserted nothing — the leg now clears the verdict on the same `AgentStatus` and re-reads.
  - `[medium]` `[patch]` No acceptance criterion had a `mutation:` line in `## Verification`, against the repo convention every Epic 3 spec follows — one was written beside each of the nine pinning tests in this pass, each applied and observed red. (Code review, below: the write that closed this spec dropped `## Verification` along with them.)

### 2026-09-16 — Code review (full, four layers)

- verdicts: 2 high, 6 medium, 12 low, 3 false. Every high and medium was patched in this pass; two
  new root causes were routed (DW-394, DW-395); DW-387 to DW-393 were re-sighted, not re-filed.
- `[high]` `[patch]` `Install.Smoke.CheckAgentSwitches` failed the run on **any** switch row or
  hold, and `Switch.SetGuarded` writes the row on the first accepted `PUT` — so the first
  administrator to save the Switches screen turned `scripts/smoke.sh` red forever, on the
  long-lived instance and in CI, with a message blaming the installer; no route deletes the row.
  It now reports `skipped` there and `pass` only on an instance that is still fresh, so AC5's
  assertion still runs where it can be true. The same method read the protected tables with raw
  SQL, against the Boundary that they are reached only through `Kernel/State/Base`'s guarded
  methods; it now uses `Switch.Resolve`'s `updatedAt` and `Hold.GuardedList`. Demonstrated on the
  throwaway: `pass` fresh, `skipped` with `executed=18 passed=18 failed=0` after one save.
- `[high]` `[patch]` The write that closed this spec deleted `## Design Notes` and `## Verification`
  and swallowed `## Auto Run Result` into an unterminated inline-code span in a list item — so
  Rule 2's `Consumes`/`Consumed-by`, the governing-AD list, and the nine `mutation:` lines this
  spec's own triage claims to have recorded were all absent, while the claim stood. All three
  sections are restored and the claim corrected. The gate that should have caught it is DW-395.
- `[medium]` `[patch]` FR-29's change record was deletable from all three handlers with the suite
  green: the only observer called `LogChange` itself, which is the insufficiency
  `AgentWire.TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler`'s own comment names.
  `SwitchesWire` now drives the three verbs over HTTP and reads the console log, matching on a
  per-run marker so an earlier run's line cannot satisfy it.
- `[medium]` `[patch]` A hold's `userName` was stored untrimmed, so a name pasted with a space
  produced a hold that never matched `$Username` — a kill switch that silently did nothing, and a
  second hold for the same user got past the unique index. Stripped at the API boundary; the
  mutation showed both failures.
- `[medium]` `[patch]` `SwitchRules.ValidateHold`'s two length rules had no test at any tier; the
  mutation answers 500 at the column where every other bad field answers 422.
- `[medium]` `[patch]` DW-370 was resolved at both surfaces and pinned at one — `command-box.spec.ts`
  used the stub descriptor, so the box's two call sites could be reverted green.
- `[medium]` `[patch]` AC3's "and every screen still loads" had no test. The browser spec now
  navigates through the shell's own side bar with the switch on (never a second `page.goto`, which
  re-fires the first-login gate) and asserts the next screen's own component mounted. The first
  attempt asserted `app-screen-outlet` child count, which is never zero — caught by mutating the
  outlet to blank the page, which the fixed assertion reddens.
- `[medium]` `[patch]` AC2's by-the-definition footer leg arranged a pair the server cannot answer
  (unconfigured plus a resolved read-only definition); it now uses the reachable one.
- `[low]` `[patch]` Three places said the containment rule holds that nothing "in the tree"
  produces a restraint code; it reads ObjectScript source only and skips comments and XData.
  Corrected at all three origins; the gap itself is DW-394.
- `[low]` `[patch]` The browser spec's `after` restored the switches before the `browser` null
  check, so a failed `before` threw its own error over the original.
- `[low]` `[patch]` The `deferred:` block and the residual-risk list still carried the `CLAUDE.md`
  17-rules item that this same diff corrects and DW-392 marks resolved. Dropped; five, not six.
- `[low]` `[reject]` A stale `KillSwitchReason` is republished when the switch is turned on with a
  one-key body — the shipped form round-trips the stored value, so the operator saving it sees
  exactly what will be published; `SwitchState` pins the leave-alone behavior deliberately.
- `[low]` `[reject]` `LogChange`'s bare `Catch` swallows a log failure — correct for this story: a
  log write must not fail an accepted write. Story 3.8's audit row needs its own disposition.
- `[low]` `[reject]` `Restraint.Resolved` discards `Verdict`'s status on the `ResolveDefault` error
  path — the verdict is forced `blocked` and the real cause is the status returned.
- `[low]` `[reject]` The hold-add fields are outside the unsaved-changes guard; `shareContextByDefault`
  has no reader until Story 4.3; `reload()` swallows a failed re-read; `DESCRIPTOR_PAGES` and
  `DESCRIPTOR_ACTION_LABELS` are keyed by unchecked strings; a hold deleted mid-request records an
  empty change set. Each is real and each fix is larger than the state it guards.
- `[false]` `[reject]` "The four new `Api/Error` reason sentences are unpublished copy" — server
  violation sentences live in `Api/Error.cls` by established convention (31 of them do);
  `EXPERIENCE.md`'s Fixed strings table governs the client's literals, which this story renders by
  key throughout.
- `[false]` `[reject]` "`Verdict` contradicts AC8's stated order by testing the hold before enforced
  read-only" — two axes, not one: the kill switch chooses the `code`, the read-only sources choose
  the `footerKey`, and both orders are as documented. (QA's commit message names the middle rung
  as the hold rather than Story 10.4's per-user read-only; the test itself is right, and the
  `## Verification` line above states the chain correctly.)
- `[false]` `[reject]` "AC2's always-shown footer line is absent on a configured, unrestrained
  instance" — true, and spec-bound: "No unconditional panel: Story 4.3 owns that."

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

- `cd ui && npm run build` — the six `prebuild` checkers pass, including `screen-mirror --check`
  against the regenerated mirror.
- `cd ui && npm test` — the tool tests and the Angular component runner, 0 failures, including the
  three `strings.test.mjs` tests that are red at dispatch.
- `cd ui && npm run test:browser` — against an armed throwaway; anything about geometry or a real
  route belongs here, not in jsdom.
- `uv run scripts/check-objectscript.py` — 18 rules clean over the whole tree.
- `uv run scripts/test_check_objectscript.py` — the checker's own harness.
- `bash scripts/lint-docs.sh` — clean.
- `mcp__iris-dev__iris_doc_load` with `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`,
  `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` — the whole tree compiles.
- `bash scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` — non-zero executed
  checks, none failing.

**Manual checks:**

- `%UnitTest_Result` SQL probe confirms the per-class totals before any suite is called green.

**Mutations (Rule 19).** One per acceptance criterion, transcribed from the `Mutation:` line each
pinning test carries in its own source, which is where the implement pass recorded what it applied.
The four marked *(applied at code review)* were re-applied and observed red in the review pass, then
reverted with the tree confirmed byte-identical.

- AC1 — `scripts/check-objectscript.py` rule 18 `check_restraint_containment`, harnessed by
  `scripts/test_check_objectscript.py`'s `TestRestraintContainment`.
  mutation: name a restraint code in a shipped class outside `Api/Error.cls` and
  `Kernel/Restraint.cls` → the checker reports that file and line *(applied at code review, both
  forms: the `#AGENTKILLSWITCHGLOBAL` parameter in `Api/Definitions.cls` and the literal
  `"AGENT.READONLY.ENFORCED"` with `ReasonForRestraint` in `Api/Switches.cls`)*.
- AC2 — `panel.spec.ts` "the footer line reads the off key … and the definition key".
  mutation: compose the line from `enforcedReadOnly` in the panel rather than rendering `footerKey`
  → the by-the-definition case goes red, because no flag on the wire distinguishes it.
- AC3 — `panel.spec.ts` "the kill switch raises its published banner", and
  `switches.browser-spec.mjs`'s kill-switch test for the every-screen clause.
  mutation: drop `killSwitchReason` from the banner → the reason assertion goes red.
- AC4 — `rail.spec.ts` "the dot lights on the kill switch".
  mutation: drop the kill-switch arm from `attentionReason` → the dot and its name go red.
- AC5 — `Install.Smoke.CheckAgentSwitches`, asked of a genuinely fresh instance.
  mutation: seed `Kernel/State/Switch.DEFAULTKILLSWITCH` to 1 → the verdict reads the agent switched
  off on an instance with no row and the check reports `fail`.
- AC6 — `Test/AgentWireSecurity`, on a throwaway armed with `OCUPILOT_ALLOW_PRINCIPALS`.
  mutation: delete the `IsAdministrator()` arm from any handler in `Api/Switches.cls` → the sweep
  goes red on that route.
- AC7 — `screen-outlet.spec.ts` for DW-369, `command-bar.spec.ts` and `command-box.spec.ts` for
  DW-370, and the browser spec end to end.
  mutation: change `actionLabel(screen.descriptor, action.id)` to `actionLabel('', action.id)` →
  the surface draws the bare id *(applied at code review, at the command box, which is the surface
  the implement pass left unpinned)*.
- AC8 — `ui/tools/strings.test.mjs`, the band and the key count; the precedence the footer line
  renders is pinned by `Test/Restraint`.
  mutation: put `strings.test.mjs`'s upper bound back to 240 → the band goes red naming the live
  count. For the precedence itself: move the `killSwitchAudience = AUDIENCEYOU` arm below the
  `tByDefinition` arm in `Kernel/Restraint.Verdict` → `Test/Restraint`'s
  `TestAPerUserHoldOutranksTheDefinitionsReadOnlyFlag` goes red alone *(applied at code review)*.
- AC9 — `panel.spec.ts`'s closing leg, against the rendered DOM.
  mutation: give `Panel` its own `ApiService` read → it has none to inject and the leg goes red.

Two tests this review added carry their own lines in source: `SwitchesWire`'s
`TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler` (delete a `LogChange` line from any of the
three handlers → red naming that verb) and `TestAnOverLongHoldFieldIsRefusedOnItsFieldRatherThanAtTheColumn`
(drop either length test from `SwitchRules.ValidateHold` → 500 where 422 is expected)
*(both applied at code review)*.

## Auto Run Result

Status: done

**What shipped.** One store for the instance switches (`Kernel/State/Switch.cls`, named `Switch`
because `…State.Switches` is 30 characters against the 29 cap) and one for per-user holds
(`Kernel/State/Hold.cls`, the user a weak reference per AD-37); one verdict,
`Kernel/Restraint.cls`, which reads all three sources on every call, returns values and holds no
object across the return; nine new codes with written sentences in `Api/Error.cls`;
`Api/Switches.cls` behind five router routes — the four administrator-gated switch routes and the
ungated `GET /agent/restraint` the panel reads; the `agent-switch` entity type; and
`Screen/Descriptor/AgentSwitches.cls` at `sideBarPosition` 2. On the client: the ten published
literals and the band, the restraint fact on `AgentStatus` settled in the same load as the
enablement fact, the panel's two banners and its always-shown footer line, the rail's dot and
tooltip, DW-369's descriptor-keyed page map, DW-370's descriptor-scoped action labels, and the
Switches form page.

**Files changed.** 47 files: `Kernel/{Restraint,SwitchRules}.cls` and `Kernel/State/{Switch,Hold}.cls`
(AC1, AC2, AC3); `Api/{Switches,Error,Router}.cls` and `Kernel/EntityType.cls` (AC6, the wire);
`Screen/Descriptor/AgentSwitches.cls` (AC7); `Install/Smoke.cls` (AC5);
`scripts/check-objectscript.py` + its harness (AC1's falsifiable half, an 18th rule);
`Test/{Restraint,SwitchState,SwitchesWire,SwitchFixture,SwitchesProbe}.cls` plus amendments to
`Test/{AgentWireSecurity,AgentViolation,Descriptor,Wire}.cls`; on the client
`core/{strings,agent-status,screen-actions,screens.generated}.ts`,
`shell/{panel,rail,screen-outlet,command-bar,command-box}.ts`,
`areas/agent/switches.{page,store}.ts`, `styles/_components.scss`, `testing/agent-status.ts`, and the
matching specs, `tools/{strings,agent-status,screen-actions,navigation}.test.mjs`, and
`browser/{switches,definitions}.browser-spec.mjs`.

**Review.** Four layers reported 49 findings: 0 high, 24 medium, 22 low, 3 false. Sixteen patches
applied (8 medium, 8 low), six items deferred, and the remainder rejected with reasons recorded row
by row in `## Review Triage Log`. The patches, in short: the log seam `LogChange` wrote through by
hard class name, plus the class header that named a method the code never called and the `updatedAt`
stamp that made a no-op write look like a change; a hold write that discarded the operator's unsaved
switch edits; an over-length reason that reached `%Save` as a 500; a `killSwitchReason` that was not
a JSON string reaching the published banner; four unpinned claims (the log line, the quoted-flag
guard, the case-folding lookup, a fresh install's switch state); DW-370 never resolved through
either surface that draws it; three overclaims about what the containment rule enforces; identical
accessible names on every hold's remove button; a stale rule roster; a `panel.spec.ts` leg that did
not test what it claimed; and one settle race this run found itself (below).

**One defect the verification found, not a reviewer.** `definitions.browser-spec.mjs`'s
`screensOffered` took its stability reads back to back, so two `$$eval` calls could both observe a
pending state and a stale list read as settled. It was latent until the Agent co-pilot area listed a
second screen; it then failed once, reporting the four screens whose labels share a letter with an
early keystroke. The loop now yields a rendered frame between reads and requires three consecutive
equal ones. Confirmed over three further repeats of that file plus a full browser run.

**Verification performed** — every command in `## Verification`, plus the mutation campaign above.

| Gate | Result |
|---|---|
| `uv run scripts/check-objectscript.py` | 279 files, 18 rules, 0 problems |
| `uv run scripts/test_check_objectscript.py` | 88 tests, OK |
| `bash scripts/lint-docs.sh` | 19 files, 0 issues; check-prose 0 problems |
| `iris_doc_load` whole tree, `flags: cku`, `server: ocupilot-iris` | 279 loaded, 0 failed, compiled |
| `cd ui && npm run build` | six prebuild checkers clean |
| `cd ui && npm test` | 783 tool tests + 378 component tests, 0 failures |
| `cd ui && npm run test:browser` (throwaway) | 77 pass, 0 fail |
| ObjectScript suite, armed throwaway, `ci-runner.mjs` one class at a time | 80 classes, 778 tests, 0 failed, 0 probe leftovers, 0 overlaps |
| `%UnitTest_Result` SQL probe, read independently | TOTAL 778, PASSED 778, FAILED 0 |
| `bash scripts/smoke.sh --container ocupilot` | executed 18, passed 18, failed 0 |
| `bash scripts/smoke.sh --container ocupilot-ci` | executed 19, passed 19, failed 0 |

`strings.test.mjs` is green: `strings.ts` holds 261 keys against 246 table literals + 12 extracted
from prose + 3 named extras, the band reads `<= 260`, and its message names 246 rather than
"roughly 230". Every row of the I/O & Edge-Case Matrix is covered by a test that ran and passed;
the non-administrator row is `AgentWireSecurity` (4 declared methods, 4 executed), which runs only
where `OCUPILOT_ALLOW_PRINCIPALS` arms it — so it was exercised on the throwaway, not on the
development instance.

**Follow-up review recommended: true.** Eight medium entries were patched, which is the threshold;
the specific residual risks are two behavior changes made late, each verified by the suite but not
by a consumer that exists yet. First, `MergeBody` now ignores a `killSwitchReason` that is not a
JSON string: the shipped client always sends a string, so a future caller that does not would have
its reason dropped silently rather than refused. Second, `reload()` no longer absorbs switch state
after a hold write, so a switch another administrator changed in that window is not picked up until
the screen is reopened — the trade taken deliberately against discarding the operator's unsaved
edits.

**Residual risks** — all five recorded in frontmatter `deferred:`: AC1's caller half is not
implemented (no write path calls `Verdict` before Epic 4); concurrent switch writes lose one update,
as the shipped `Egress` singleton pattern also does; the descriptor's declared row action draws a
permanently disabled control the page registers no handler for; `Verdict`'s fail-closed path has no
store seam to pin it with; and the published absent-entity sentence names a list this screen lacks.

**Container state left behind.** The `ocupilot` container is untouched but for the sanctioned
whole-tree compile and two smoke runs: 0 switch rows, 0 holds, 0 agent definitions, the same state
it started in. `ocupilot-slot-b` and `iris-community-edition` were never addressed. Every
`ocupilot-ci` throwaway this run started was torn down with `sh scripts/ci-throwaway.sh down`; none
survives.
