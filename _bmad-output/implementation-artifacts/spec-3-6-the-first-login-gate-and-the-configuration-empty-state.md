---
title: 'Story 3.6: The first-login gate and the configuration-empty state'
type: 'feature'
created: '2026-09-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred:
  - summary: >-
      DW-373's second half — "inline on blur for every field but the key" — is unreachable without a
      validate-only endpoint, because every field-level sentence is authored once on the server
      (AD-39) and the only mechanism that hands the client one is a refusal from an actual save.
    evidence: |-
      The key field validates on blur only because `GET /agent/providers` ships `keyShapeReason`
      with the rule (`definition-form.store.ts:438` `checkKeyShape`). No other rule's reason reaches
      the client before a save: `Kernel/AgentRules.Validate` and `Api/Error.cls` hold all 17, and
      `Api/Router.cls:66-83` carries no validate route. A client-authored sentence would be a second
      copy source, which AD-39 exists to prevent.
---

<intent-contract>

## Intent

**Problem:** A fresh install has no enabled agent definition, and nothing in the client says so.
An administrator is not taken to the one screen that must be filled in, a non-administrator is
never told who can fill it in, and the panel — the surface both messages belong on — does not
exist yet.

**Approach:** Read the two facts the instance already answers (is any definition enabled; may this
caller edit definitions), and render the three surfaces that turn on them: a first-login redirect to
the Definition form, a docked panel carrying the audience's own empty state with a static example
proposal card, and the rail's attention dot. No new server route, no stored client flag: both facts
are re-read, never remembered.

## Boundaries & Constraints

**Always:**

- The unconfigured condition is `GET /api/ocupilot/agent/definitions` holding no row with
  `enabled: true` — the ungated selection projection, readable by any caller who cleared the router
  (`Api/Definitions.cls:125 HandleList`, six keys including `enabled`).
- The privilege half is the navigation map's verdict for route `agent/definitions`
  (`Api/Navigation.cls`, recomputed per call, AD-8). The panel reads `NavigationService.screenVerdict`
  and mints no second privilege source.
- Every user-facing literal already exists in `EXPERIENCE.md`'s *Fixed strings* table, or in the five
  rows this story requires (Design Notes → *Required published copy*). The example card's **content**
  is data, re-derived from `EXPERIENCE.md:705` by its own test.
- Gated controls stay focusable with `aria-disabled` and never take the `disabled` attribute.
- Anything that changes a definition already publishes `changed` on the `ChangeBus`
  (`definition-actions.ts:155`, `definition-form.store.ts:593`) — that is the only clearing mechanism.

**Never:**

- Never store "the gate has fired" anywhere — no `localStorage`, no `sessionStorage`, no cookie, no
  server row. A flag that outlives the condition is the defect this AC names.
- Never build Story 4.3's panel: no resize handle, no full-screen toggle, no transcript, no context
  chip, no `New conversation`, no panel header controls. Never build Story 3.7's read-only footer
  line or any switch.
- Never add a route, a descriptor, a property or an audit event on the server. This story is
  client-only.
- Never give the example card a timer, a button, or any focusable node.
- Never cache the privilege verdict beside the navigation map's own copy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Gate fires | fresh authentication in this tab; no enabled definition; verdict for `agent/definitions` allowed | route replaced with the Definition form; the form shows the gate landing banner | none expected |
| Gate declines | same, but the caller is not allowed | no redirect; the requested route stands | none expected |
| Reload | tab resumes a stored pair (`session.ts:513-526`, no `adopt()`) | no redirect; the requested URL is preserved | none expected |
| Administrator leaves | gate declined by navigating away, still unconfigured | panel banner on every route, non-dismissible; example card beneath | none expected |
| Non-administrator | unconfigured, verdict denied | panel shows the configuration-empty sentence, example card, three trust sentences | none expected |
| Condition clears | `Enable` on the Definitions list | `changed` on the bus → re-read → banner, example card, dot and gate all clear | a failed re-read leaves the previous answer and retries on the next event |
| Both facts unanswered | sign-in in flight | panel renders nothing (no banner, no empty state) | never guess an audience |
| 403 on a Definition form call | `AUTH.NOPRIVILEGE` with `detail.failedPair` | the form names the resource and the action, not the generic reason | any other code keeps today's rendering |

</intent-contract>

## Code Map

**Read; do not re-derive.**

- `src/OcuPilot/Api/Definitions.cls` **:125** `HandleList` — the one ungated route; `SelectionProjection`
  **:1011** → `Kernel/State/Agent.cls:314 ScreenRow`, six keys `id name provider model enabled default`.
  Every other agent route gates on `IsAdministrator()` **:816** → `Screen/Gate.HoldsPrivilege` **:143**.
- `src/OcuPilot/Api/Navigation.cls` — `allowed` / `failedPair` per area and per built screen, recomputed
  per call (class header, AD-8). `agent` area declares `privileges: []`; both agent screens declare
  `OcuPilotAdmin:USE`.
- `src/OcuPilot/Kernel/State/Agent.cls` **:94 Enabled**, **:99 ConnectionVerified** — and **no** stored
  record of a failed test anywhere in the class. This is the fact DW-356 turns on.

**Client — the seams this story extends.**

- `ui/src/app/app.ts` **:116-147** template; `.ocu-shell` **:129-139** is flex with rail, side bar and
  `.ocu-shell-content`; **no panel region exists**. `verifyWhenSignedIn()` **:305-348** — the not-signed-in
  branch calls eight `reset()`s (**:313-337**); the signed-in branch (**:340-347**) runs `instance.verify()`,
  `navigation.load()`, `scope.load()`. `App` does **not** inject `Router` today (**:150-168**).
- `ui/src/app/core/session.ts` **:513-548** `start()` — a tab resuming a stored pair reaches `signed-in`
  **without** `adopt()`; **:805-815** `adopt()` is the only path a genuine authentication takes (silent
  probe and form login both). This asymmetry is what "every login" keys off.
- `ui/src/app/core/navigation.ts` **:39** `Verdict`, **:45** `UNGATED` (the pre-answer default is
  *allowed*), **:348** `loaded()`, **:358** `answered()`, **:413** `screenVerdict()`, **:237**
  `formatDeniedAction`, **:259** `withQuery` (carries only `ns`), **:175** `editorScreenFor`, **:182**
  `screenForRoute`.
- `ui/src/app/shell/rail.ts` **:75-97** template, **:113-138** the `RailItem` computed, **:17-30** the
  interface, **:77** `.ocu-rail-slot` wraps each button. **:60-62** says the attention dot belongs to the
  agent's own stories — this one. The slot is the mount point: a dot inside the button would be silenced
  by the button's own `aria-label`.
- `ui/src/app/core/change-bus.ts` **:67** `ChangeBus`; publishers already exist at
  `ui/src/app/areas/agent/definition-actions.ts` **:155** and
  `ui/src/app/areas/agent/definition-form.store.ts` **:593**, both with type `agent-definition`.
- `ui/src/app/areas/agent/definition-form.store.ts` **:703-707** `absorbRefusal` — sets `envelopeReason`
  from `result.reason` and keeps no code and no `detail`; **:258** `reason()`; **:625-631**
  `instanceHoldsNoDefinition` (the existing ungated read, scoped to a create-form open).
- `ui/src/app/areas/agent/definition-form.page.ts` **:104-106** renders `reason()`; **:118-147** the two
  `aria-required` fields; **:210** the only `(blur)` in the client.
- `ui/src/app/areas/logs/error-log.page.ts` **:297-308** — the pattern DW-372 copies: the store exposes
  `code` and `failedPair`, the **page** composes with `formatDeniedAction`.
- `ui/src/app/core/api.ts` **:107-120** `JsonResult` — the `error` arm carries `code`, `reason` and `detail`.
- `ui/src/styles/_metrics.scss` **:35-42** `--ocu-panel-default: 400px`, `--ocu-panel-min: 320px`,
  `--ocu-panel-header-height`, `--ocu-panel-home` — declared, no consumer.
- `ui/src/styles/_tokens.scss` **:110-130** `--ocu-agent-accent-dark`, `--ocu-agent-container`,
  `--ocu-restrained*`; `ui/tools/design-tokens.test.mjs` **:76** refuses any custom property that is not
  already a declared role, so this story adds **no** token.
- `ui/tools/client-lint.mjs` **:215** — a literal text node or a literal `aria-label`/`title`/`placeholder`
  in any `src/app` template fails the build; a non-`STRINGS` interpolation is a data binding and passes.
- `ui/tools/strings.test.mjs` **:339-353** — `strings.ts` may hold only the table's literals, the twelve
  literals seven named extractors pull from prose (**:180-188** `EXTRACTED_FROM_PROSE`) and exactly three
  named extras, and the key count must equal that sum. It reads **236 + 12 + 3 = 251, found 243** today:
  the table's eight new literals are in `EXPERIENCE.md` **:336-340** and not yet in `strings.ts`, which is
  Task 13. **:297-313** the band `150-240` is a tripwire on table literals, not keys, so 236 fits unwidened;
  **:497** every `/** EXPERIENCE.md:n */` must resolve to a line carrying its value — `strings.ts`'s highest
  reference is `:335`, so the append shifted none of them.
- `ui/browser/list-spec.mjs` `filterToSubset` — clears to the whole list, requires the field to hold the
  **whole** text and a count that has settled over ten reads (DW-374).

## Tasks & Acceptance

**Execution:**

1. `ui/src/app/core/agent-status.ts` — new. `AgentStatus`: `load()` reads the ungated definitions list and
   sets `configured` to whether any row has `enabled === true`; `answered()`, `configured()`,
   `subscribe()`, `reset()`. Subscribes to `ChangeBus` for type `agent-definition` and re-reads. A
   `generation` counter drops a late answer, as `error-log.store.ts:122` does. Framework-free enough for
   `node --test`.
2. `ui/tools/agent-status.test.mjs` — new. Pure-logic coverage: zero rows, rows all disabled, one enabled,
   a late answer dropped, a bus event re-reading, `reset()` clearing.
3. `ui/src/app/core/session.ts` — add a one-shot `consumeFreshSignIn(): boolean`, set **only** in
   `adopt()` (**:805-815**) and returning true exactly once. Nothing is written to storage.
4. `ui/src/app/app.ts` — inject `Router`; in the signed-in branch await `navigation.load()` and
   `agentStatus.load()`, then, if `consumeFreshSignIn()`, the agent is unconfigured, the verdict for
   `agent/definitions` is allowed and the current route is not already the form, navigate to the form via
   `editorScreenFor`/`withQuery`. Add `agentStatus.reset()` to the sign-out teardown. Mount `<app-panel />`
   after `.ocu-shell-content`, inside `.ocu-shell`.
5. `ui/src/app/shell/panel.ts` — new. `<aside class="ocu-panel" [attr.aria-label]="panelName">` (the
   published area name). Renders nothing until both `navigation.answered()` and `agentStatus.answered()`;
   renders nothing when configured. Body: the administrator reminder banner **or** the configuration-empty
   sentence by verdict, then `<app-proposal-card>` under the example band, then the three trust sentences.
   Footer: the composer (published label), `Send`, the published caption — both controls focusable,
   `aria-disabled="true"`, `aria-describedby` naming the same published sentence, never `disabled`; no
   context chip.
6. `ui/src/app/shell/proposal-card.ts` — new. Renders a `ProposalCardView` (entity type, name, changed
   rows, unchanged count, rationale, expected impact, reverse) as bar, header title (the published pattern
   with its two placeholders resolved), diff rows with the published direction words visually hidden and
   the arrow `aria-hidden`, the collapsed unchanged caption, the two agent-tint blocks, the Reverse line.
   Two empty `<ng-content select="[card-countdown]">` / `[card-footer]` slots that Story 5.2 fills. **No
   interactive node of any kind.**
7. `ui/src/app/shell/example-proposal.ts` — new. The UJ-3 fixture as a `const` view model.
8. `ui/tools/example-proposal.test.mjs` — new. Re-derives every fixture value from `EXPERIENCE.md:710`
   (UJ-3 step 3; the intent contract's `:705` predates the five-row append, which moved it down by five)
   and asserts the composed title equals the quoted `"Proposal · Web application /csp/myapp"` there.
9. `ui/src/app/shell/rail.ts` — add `attention` to `RailItem`, computed from `AgentStatus` for the `agent`
   area only; render a sibling `<span class="ocu-rail-dot" role="img" [attr.aria-label]="item.attention">`
   inside `.ocu-rail-slot`, outside the button, so the button keeps its `aria-label` (the rail row's rule)
   and the dot still carries its own name (the attention-dot row's rule). The reason is the same published
   sentence the panel shows that audience.
10. `ui/src/styles/_components.scss` — `.ocu-panel`, `.ocu-proposal-card` (bar, header, diff rows, agent
    tint, example band), `.ocu-rail-dot` (8px, `agent-accent-dark`, 1.5px `shell` ring, icon top-right
    offset 2px), `.ocu-field-label-required::after { content: '*'; }` and the legend. Existing tokens only.
11. `ui/src/app/areas/agent/definition-form.store.ts` — keep the refusal's `code` and
    `detail.failedPair` beside `envelopeReason`; expose `refusalCode()` / `refusalPair()`. On blur of any
    field whose value changed since the refusal, drop that field's stale violation.
12. `ui/src/app/areas/agent/definition-form.page.ts` — compose the denied-action sentence in the page
    (the `error-log.page.ts:297-308` shape); render the gate landing banner above the form while the agent
    is unconfigured and the caller is allowed; mark `name` and `provider` with the asterisk and render the
    published legend once above the fields; wire `(blur)` on every field to the store's stale-violation drop.
13. `ui/src/app/core/strings.ts` — **this task owns the key count**: add the eight literals now standing in
    `EXPERIENCE.md` **:336-340** — `"Proposal · <entity type> <name>"`, `"was"`, `"now"`, the three trust
    sentences, `"change this definition"`, `"Required fields are marked with an asterisk."` — each with its
    `/** EXPERIENCE.md:n */` reference pointing at the row that carries it, taking `strings.ts` from 243 to
    **251 keys = 236 + 12 + 3**. Nothing else may be added, and the `150-240` band must **not** be widened:
    it pins table literals, which are 236.
14. Component specs — `panel.spec.ts`, `proposal-card.spec.ts`, `rail.spec.ts` (extend),
    `app.spec.ts` (extend), `definition-form.page.spec.ts` (extend).
15. `ui/browser/gate.browser-spec.mjs` — new; and reconcile every existing browser spec for the narrower
    content region the panel introduces on a throwaway that holds no enabled definition.

**Acceptance Criteria:**

- **AC1** Given a throwaway instance with no enabled definition and a caller allowed on
  `agent/definitions`, when they sign in through the form, then the browser's own URL becomes the
  Definition form route and the gate landing banner is rendered above the form.
- **AC1b** Given the same instance, when the tab is reloaded while already holding a pair, then no
  redirect occurs and the requested URL is unchanged — the gate keys off `adopt()`, not `signed-in`.
- **AC2** Given the gate was declined by navigating away and nothing is enabled, when any route renders,
  then the panel carries the administrator reminder banner with no dismiss control, and the banner is
  gone on the first render after `Enable` succeeds.
- **AC3** Given the verdict for `agent/definitions` is denied and nothing is enabled, when the panel
  renders, then it shows the configuration-empty sentence, an example card labeled with the published
  example band, and the three trust sentences; and the card's subtree contains **no** element matching
  `a[href], button, input, select, textarea, [tabindex], [contenteditable]` and no countdown node.
- **AC4** Given either empty state, when the composer renders, then the composer and Send carry
  `aria-disabled="true"`, neither carries the `disabled` attribute, both are reachable by Tab in the
  browser, and no context chip is present in the panel.
- **AC5** Given the unconfigured state, when it is compared to a switch, then its only exit is a
  definition being enabled: the panel offers no control that clears it, and the same `Enable` clears the
  banner, the example card and the dot together.
- **AC6** Given nothing is enabled, when the rail renders, then the Agent co-pilot slot carries a dot
  whose accessible name is the published sentence for that caller's audience, and the dot is absent on
  the first render after `Enable` succeeds.
- **AC7 (DW-372)** Given a Definition form call refused with `AUTH.NOPRIVILEGE` and a `failedPair`, when
  the form renders the refusal, then it reads `You need <resource> to <action>.` with both slots resolved,
  not the envelope's generic reason.
- **AC8 (DW-373)** Given the Definition form, when it renders, then `name` and `provider` carry an
  asterisk and the published legend appears once above the fields; and a field whose value changed since a
  refusal drops its stale violation on blur.
- **Integration AC (Rule 1)** Consumer `rail.ts` reads `AgentStatus` and produces the observable effect
  that the dot disappears within one change-bus tick of the Definitions list's `Enable`, asserted in the
  browser spec against the real instance.

## Spec Change Log

- **2026-09-15 — `EXPERIENCE.md` amended by the lead (commit `184c8ac`), spec re-planned.** The five
  *Fixed strings* rows this plan halted on were appended at `:336-340`, and the two *Where* cells at
  `:283`/`:285` gained the attention dot's audience. The attention-dot row (`:350`) was amended from
  "unconfigured, the kill switch is on, or a definition needs attention (Test connection failed since the
  last save)" to "unconfigured or the kill switch is on", with the reason in the row — DW-356 decided. The
  append moved every line below `:336` down by five, so the intent contract's `EXPERIENCE.md:705` (frozen,
  left verbatim) is read as `:710`; `strings.ts`'s own references stop at `:335` and did not move, and the
  document's internal `(:nnn)` back-references are DW-375's, routed to the burn-down, not this story's.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-8 (privilege is the process's, checked at call time, never cached), AD-11 rule 4
(nothing rendered issues a request to any host — the example card is inert markup), AD-12/AD-39 (one
envelope, two renderings; the denied-action sentence is composed from published copy over the envelope's
`code` and `detail`), AD-14 (a change publishes one event; consumers re-fetch), AD-19 (signals, stores,
never component fields), AD-28 (per-tab tokens — why `adopt()` is the login), AD-46 (OcuPilot's own rows
are visible in OcuPilot's own screens, which is why the definitions list is ungated).

**Consumes:** Story 3.1 (`Kernel/State/Agent`), 3.4 (`ConnectionVerified`), 3.5 (the Definition form, the
Definitions list, `ChangeBus` publishers, `screens.generated.ts`). **Consumed-by:** Story 3.7 (the panel's
banner stack and the second `form-page`'s asterisk/legend), Story 4.3 (the docked panel — adds width,
resize, full-screen, transcript, context chip, header controls, and makes it unconditional), Story 5.2
(the same `proposal-card`, filling the two slots and turning the unchanged caption into a disclosure).

**What "every login" keys off.** `Session.adopt()` — the one path a genuine authentication takes, from
both the silent probe and an accepted form login. A tab resuming a stored pair reaches `signed-in` through
`start()` without `adopt()` (`session.ts:513-526`), so a reload is not a login and the requested route
survives, as `app.ts:79-82` promises. The state that decides whether the gate fires is **the instance's
own definition rows** — nothing is stored in the browser, so "never afterwards" is a consequence of the
condition, not of a remembered decision. The one-shot `consumeFreshSignIn()` records that an
authentication happened, never that the gate was shown; it lives in memory for the tab's lifetime and
cannot survive the condition clearing.

**Why the panel learns the audience from the navigation map.** The map is the existing answer to
"may this caller edit definitions", recomputed on the instance per call and re-read on any 403
(`navigation.ts:440 noteForbidden`). Reading `screenVerdict('agent/definitions').allowed` adds no second
source and no cache. Before the map answers, every verdict defaults to *allowed* (`UNGATED`), which would
show an administrator's banner to a non-administrator — so the panel renders nothing until
`navigation.answered()` and `agentStatus.answered()` are both true.

**Written once, for here and Story 5.2.** `proposal-card.ts` renders only what its view model describes
and owns no interactive node. Everything live-only is a projected slot — `[card-countdown]` and
`[card-footer]` — which the static example leaves empty, so the static form has no countdown and no
buttons *by construction* rather than by a disabled flag. The one anatomy element that is interactive in
a live card, the unchanged-fields disclosure, ships here as its published caption with an `aria-hidden`
chevron; Story 5.2 makes that same element a button when it adds interactivity. The card ships with no
unexercised branch. AC3's pinning test queries the card's subtree for the full focusable selector, which
is what proves "nothing focusable" rather than counting buttons.

**The example card's content is data, not copy.** In a live card the entity type, name, field names,
values, rationale, impact and reverse text come from the instance and the model; none of them can be
string-table keys. The static example is the same shape with UJ-3's values, so it lives in a fixture and
`ui/tools/example-proposal.test.mjs` re-derives every value from `EXPERIENCE.md:710` — the technique
`strings.test.mjs:399-414` already uses for the version-mismatch sentence. The card's *chrome* (the title
pattern, the direction words, the two headings, `Reverse:`, the unchanged caption, the example band) is
copy and comes from the table.

**Required published copy — settled.** The five rows landed in `EXPERIENCE.md`'s *Fixed strings* table at
**:336-340** (commit `184c8ac`), carrying the eight literals Task 13 adds to `strings.ts`, and the two
*Where*-cell amendments that let the dot name its reason are on the administrator-reminder (`:283`) and
configuration-empty (`:285`) rows. Every other literal the panel, the card and the form render is an
existing key: the panel's own name is `navAreaAgent` (the Landmarks line names the panel `complementary`
"Agent co-pilot"), and `proposalRationaleHeading`, `proposalExpectedImpactHeading`, `proposalReverseLabel`,
`proposalUnchangedFieldsDisclosure`, `proposalExampleCardTitle`, `agentComposerLabel`, `actionSend`,
`agentComposerCaption`, `agentGateReminderBanner`, `agentGateLandingBanner`, `agentGateEmptyState` and
`privilegeDeniedAction` are all present today.

**DW-356 — settled: the dot has two conditions.** The attention-dot row (`:350`) now states the decision
and its reasoning; the dot is shown when the agent is unconfigured (this story) or the kill switch is on
(Story 3.7), and a failed Test connection is deliberately not a third condition. `Kernel/State/Agent.cls`
stores no failure record, which is why the row could not have been implemented as written.

**DW-372 — addressed.** The published action phrase `"change this definition"` (`:339`) plus the
`error-log.page.ts:297-308` composition shape: the store keeps the refusal's `code` and
`detail.failedPair`, the page composes with `formatDeniedAction`.

**DW-373 — half addressed, half declined.** The asterisk and its legend ship here (`:340`; the asterisk is
a CSS `::after` glyph, so `aria-required` remains the semantics and no key is needed for `*`). "Inline on
blur for every field but the key" is declined and recorded in frontmatter `deferred:`: every field-level
sentence is authored once on the server (AD-39), the key field validates on blur only because
`GET /agent/providers` ships its rule *and* its server-written reason, and no other rule's reason reaches
the client before a save. What does ship is the honest part — a refusal that no longer describes a field's
value is dropped on that field's blur rather than left pointing at it.

**Blast radius worth naming.** The panel narrows the content region to about 744px at the browser suite's
1440×900 viewport, on a throwaway that holds no enabled definition — so every existing browser spec now
renders with the panel present. Task 15 runs the whole suite and reconciles; any spec touched keeps
DW-368/DW-374 discipline (a filter leg measured against the whole list, never another leg's survivors; a
substring asserted to isolate a row naming that row alone; `filterToSubset` requiring the whole filter text
and a settled count).

## Verification

**Commands:**

- `cd ui && npm run build` — expected: the six prebuild checkers pass; `client-lint` reports no literal
  text node in the two new templates.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including
  `agent-status.test.mjs`, `example-proposal.test.mjs` and `strings.test.mjs` at **251 keys = 236 + 12 + 3**;
  then the component runner green.
- `sh scripts/ci-throwaway.sh up && cd ui && npm run test:browser` — expected: green, including
  `gate.browser-spec.mjs`; tear the throwaway down afterwards.
- `bash scripts/lint-docs.sh` — expected: clean.
- No ObjectScript changes, so no load, compile or `iris_execute_tests` call is part of this story.

**Mutations (Rule 19) — one per AC, each reverted byte-identical:**

- AC1 → move the gate check out of `consumeFreshSignIn()` so it runs on every `signed-in` →
  `gate.browser-spec.mjs`'s reload leg goes red.
- AC1b → make `start()`'s resume branch call `adopt()` → the same leg goes red.
- AC2 → give the reminder banner a dismiss control → `panel.spec.ts`'s no-dismiss assertion goes red.
- AC3 → render the unchanged caption as a `<button>` → the focusable-selector assertion goes red.
- AC4 → swap `aria-disabled` for `disabled` on the composer → `panel.spec.ts` goes red.
- AC5 → require a second condition beside `configured()` → the clear-on-Enable assertion goes red.
- AC6 → move the dot inside the rail button → `rail.spec.ts`'s accessible-name assertion goes red.
- AC7 → return `envelopeReason` for `AUTH.NOPRIVILEGE` → `definition-form.page.spec.ts` goes red.
- AC8 → drop the legend render → the same spec goes red.

## Auto Run Result

Status: ready-for-dev

The one blocking condition is met. `node --test tools/strings.test.mjs` now fails with *expected 236 table
literals + 12 extracted from prose + 3 named extras, found 243 keys*, and names as missing exactly the
eight literals this story renders — the amendment standing ahead of the implementation, which Task 13
closes. The band sanity check passes at 236 inside `150-240`, so it is not widened; the line-reference test
passes, because `strings.ts` references stop at `:335`. Those two assertions are the only red across
`node --test tools/*.test.mjs`, so no other checker reads a line the append moved. `bash scripts/lint-docs.sh`
is clean.

This pass replaced the *Required published copy* table and the DW-356 argument with the settled statements
and corrected the Code Map's `strings.test.mjs` anchors and counts; the Spec Change Log carries the rest.
The ACs, the I/O matrix and the fifteen tasks are unchanged, and everything they turn on was settled on the
first pass.
