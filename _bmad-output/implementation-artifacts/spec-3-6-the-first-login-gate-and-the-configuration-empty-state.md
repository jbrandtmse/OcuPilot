---
title: 'Story 3.6: The first-login gate and the configuration-empty state'
type: 'feature'
created: '2026-09-15'
status: 'done'
baseline_revision: 'c2373d3472f223ab942f0c41d512eedadd252d33'
review_loop_iteration: 0
followup_review_recommended: true
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
  - summary: >-
      The panel is `{spacing.panel-default}` on every route; DESIGN.md gives it
      `{spacing.panel-home}` on Home over a 120ms width transition, and `--ocu-panel-home` is
      declared with no consumer.
    evidence: |-
      DESIGN.md `:891`, `:898` and `:1112` all state the Home width; `_metrics.scss:39` already
      computes the token. The panel's width, its resize handle and its transitions are assigned to
      Story 4.3 by this spec's own Design Notes ("adds width, resize, full-screen"), so a
      route-aware width rule is that story's, not a gap in this one.
    location: >-
      ui/src/styles/_components.scss .ocu-panel
    severity: medium
  - summary: >-
      The administrator reminder banner carries no link, which EXPERIENCE.md publishes for it.
    evidence: |-
      EXPERIENCE.md:612 - "it carries a link, cannot be dismissed, and goes the moment the
      condition clears". No link label exists in the Fixed strings table, and this story's Always
      clause forbids a literal that is not published, so building it needs a UX amendment (the
      label, and whether the link is the route or the side-bar entry). `panel.spec.ts`'s banner
      assertion was narrowed from "nothing focusable" to "no dismiss control" so the published link
      is no longer pinned out by a test.
    location: >-
      ui/src/app/shell/panel.ts
    severity: medium
  - summary: >-
      The "Gate declines" and "Non-administrator" matrix rows are exercised in jsdom only - every
      browser assertion in this story runs as `_SYSTEM`.
    evidence: |-
      `panel.spec.ts`, `rail.spec.ts` and `app.spec.ts` hand-set the verdict to
      `{allowed: false, failedPair: 'OcuPilotAdmin:USE'}`; `gate.browser-spec.mjs` signs in only as
      `config.username`. The suite has precedent for a second principal
      (`users.browser-spec.mjs`'s SECURE_USER, `error-log.browser-spec.mjs`'s SERVED_USER) and the
      throwaway arms `OCUPILOT_ALLOW_PRINCIPALS`, so the leg is buildable; it is a new fixture
      rather than an assertion, which is why it is not in this pass.
    location: >-
      ui/browser/gate.browser-spec.mjs
    severity: medium
  - summary: >-
      `refusedValues` is snapshotted when a refusal arrives, not when the body was sent, so a field
      edited while a save is in flight keeps a violation that no longer describes it.
    evidence: |-
      `rememberRefusal` calls `snapshotValues()` in `absorbRefusal`, which runs on the response.
      Edit field X during the request and the server's violation on X arrives against the OLD value
      while `refusedValues[X]` holds the NEW one, so `dropStaleViolation` sees no change and the
      refusal stands over a value the reader already replaced. The fix is to capture the snapshot
      beside the request body; it changes the `save`/`test` signatures, which is why it is not in
      this pass. Settled by: refuse a save, and edit a field before the response lands.
    location: >-
      ui/src/app/areas/agent/definition-form.store.ts rememberRefusal
    severity: medium
  - summary: >-
      A status or map read that fails during sign-in spends the one-shot, so the first-login gate
      cannot fire later for that authentication even once the parked read succeeds.
    evidence: |-
      `App.runFirstLoginGate` consumes `consumeFreshSignIn()` before awaiting - deliberately, so
      two change-detection passes cannot both claim one sign-in - and then returns on
      `!answered()` or `!loaded()`. The degradation is bounded: the parked reads now recover, so
      the reminder banner and the attention dot appear and point at the same screen the redirect
      would have opened. Fixing it means a one-shot that can be returned unspent, which is a design
      choice rather than a patch.
    location: >-
      ui/src/app/app.ts runFirstLoginGate
    severity: medium
  - summary: >-
      Nothing exercises the rail tooltip's rendered reveal, which is why an adjacent-sibling
      combinator broke it silently.
    evidence: |-
      A `grep` for `ocu-rail-tooltip` over `ui/browser/` and `ui/src/app/` returns the template and
      the stylesheet only. The source pin added in `design-tokens.test.mjs` refuses a combinator a
      sibling can break, which catches this exact class; it does not assert that a focused item
      actually shows its tooltip, and jsdom computes no styles, so that assertion belongs in the
      browser suite.
    location: >-
      ui/browser/shell.browser-spec.mjs
    severity: medium
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

### 2026-09-15 — Review pass

- verdicts: 59 findings — high 1, medium 20, low 17, false 4, maybe-false 0; 17 rejected on the
  rows below.
- findings:
  - `[high]` `[patch]` `session.ts` counts a recovery re-probe as a fresh sign-in — verified:
    `probeAndSettle` sets `probing` before `adopt()`, so the failed-refresh retry, the
    install-backoff probe and a reload that renews an expired pair all raised the one-shot and
    would have moved a reader off their screen mid-session. Fixed: `adopt(pair, authenticating)`,
    answered by each call site; four new `session.test.mjs` cases; mutation recorded.
  - `[medium]` `[patch]` the audience is chosen from a map read that may have failed — verified:
    `NavigationService.answered()` is documented true "with a map **or with a failure**", and a
    failed read leaves every verdict `UNGATED`, so the panel, the dot, the gate and the form banner
    would all have addressed a non-administrator as an administrator on any map outage. Fixed: all
    four read `loaded()`; four new assertions; one mutation, four reds.
  - `[medium]` `[patch]` the attention dot breaks the rail tooltip's focus reveal — verified:
    `.ocu-rail-item:focus-visible + .ocu-rail-tooltip` is adjacent-sibling and the dot renders
    between them. Fixed: `~`, plus a source pin in `design-tokens.test.mjs` that reads the rule out
    of `_components.scss` and refuses a combinator a sibling can break.
  - `[medium]` `[patch]` `.ocu-rail-dot` steals the button's pointer events — verified: an absolute
    span over the 48x48 item with no `pointer-events`. Fixed: `pointer-events: none`.
  - `[medium]` `[patch]` `app-panel { flex: 0 0 auto }` inverts DESIGN.md's yield order — verified
    against DESIGN.md `:900`: the panel could never shrink to `panel-min`, so the content column
    absorbed every narrowing. Fixed: `flex: 0 1 auto`.
  - `[medium]` `[patch]` the gated composer announces itself inert and accepts typing — verified:
    no `readonly`, against this form's own precedent (`definition-form.page.ts` retention field).
    Fixed: `readonly` beside `aria-disabled`, pinned in `panel.spec.ts`.
  - `[medium]` `[patch]` a refused Test connection raised the **save**'s denied-action sentence —
    verified: `absorbTestRefusal` called `rememberRefusal`, and the page composes "change this
    definition" over the code and pair. Fixed: `rememberRefusedValues` keeps the values and not the
    code; new test; mutation recorded.
  - `[medium]` `[patch]` AC8's rule is unreachable for the two fields the cascade rewrites and no
    control renders — verified: `applyProviderDefaults` rewrites `credentialName`/`envVarName`, the
    template renders neither, the server refuses on both by name. Fixed: `setProvider` clears them;
    new test; mutation recorded.
  - `[medium]` `[patch]` `AgentStatus.load()` lets an overtaken read settle the answer — verified:
    `generation` only moves on `reset()`, and both `App` and the bus issue loads. Fixed: a request
    sequence; new test.
  - `[medium]` `[patch]` a failed first status read removed the whole FR-28 surface for the tab —
    verified: no `retryWhenReachable`, unlike every sibling read, and on an unconfigured instance no
    bus event can arrive. Fixed: the read is parked; two new tests; `main.ts` wired.
  - `[medium]` `[patch]` `leaveFirstLoginGate` swallowed its own timeout — verified: a gate slower
    than the 5 s window returned silently and the caller failed on a missing selector. Fixed: the
    no-fire path asserts the browser is on the requested route.
  - `[medium]` `[patch]` `gate.browser-spec.mjs` never checked its deletes and never asserted a
    clean teardown — verified: an enabled row would survive into the seven files that sort after it.
    Fixed: every delete checked, `enabledCount() === 0` asserted in `after()`.
  - `[medium]` `[patch]` `definitions()` answered `[]` on a bad read, so the suite's own premise
    passed against an unreachable API — fixed: the read is asserted.
  - `[medium]` `[patch]` the command box's filtered result was read unsettled — verified by
    observing it: one full-suite run reported all nine screens. Fixed: `screensOffered` requires the
    whole filter text, a narrowed group and a settled count (DW-374's shape).
  - `[medium]` `[defer]` the panel is `panel-default` on every route; `--ocu-panel-home` is declared
    and unused — Design Notes assign width to Story 4.3.
  - `[medium]` `[defer]` the administrator reminder banner carries no link, which `EXPERIENCE.md`
    `:612` publishes — no label exists in the Fixed strings table, so building one needs a UX
    amendment. The over-strict test that pinned the link out was narrowed to AC2's own words.
  - `[medium]` `[defer]` "Gate declines" and "Non-administrator" are exercised in jsdom only —
    every browser assertion runs as `_SYSTEM`.
  - `[medium]` `[defer]` `refusedValues` is snapshotted when the refusal arrives, not when the body
    was sent, so a field edited during an in-flight save keeps a violation it no longer matches.
  - `[medium]` `[defer]` a status or map read that fails during sign-in spends the one-shot, so the
    gate cannot fire later for that authentication.
  - `[medium]` `[defer]` nothing tested the rail tooltip's reveal, which is why the regression above
    shipped silently; the source pin added here does not cover the rendered behavior.
  - `[low]` `[patch]` the `dropStaleViolation` comment named a gap the code could not close and said
    "five" over a list of six — fixed with the cascade change.
  - `[low]` `[patch]` `removeProbeDefinitions`' comment described a disable step it never performed
    — the sentence is deleted.
  - `[low]` `[patch]` `gate.browser-spec.mjs` kept a second copy of the gate path — fixed: it
    imports `GATE_PATH`.
  - `[low]` `[patch]` `markVerified` interpolated an id into an ObjectScript command line — fixed:
    the id's shape is asserted first.
  - `[low]` `[patch]` `app.spec.ts`'s new import broke the file's own ordering — fixed.
  - `[false]` `[reject]` the panel's reminder banner renders on the Definition form beside the
    landing banner — `EXPERIENCE.md:612` says the banner "stays in the panel on every screen", and
    the form is a screen. Published behavior, not a defect.
  - `[false]` `[reject]` a refused GET of a definition shows the envelope reason rather than the
    composed sentence — correct: "change this definition" is a save's action phrase and would be
    wrong over a read.
  - `[false]` `[reject]` the spec says "await, then consume" while the code consumes first — the
    ordering is deliberate and documented at the site (two change-detection passes must not both
    claim one sign-in); the fix would be a spec edit.
  - `[false]` `[reject]` the gate can land after the user has navigated — `EXPERIENCE.md:612`
    specifies the redirect on a fresh sign-in and says "They may leave"; re-checking the route
    across the awaits would also race Angular's own initial navigation and could decline AC1.
  - `[low]` `[reject]` `push` rather than `replaceUrl` diverges from the matrix's word "replaced" —
    AC1 asks only that the URL become the form's, `EXPERIENCE.md:80` calls the gate bypassable, and
    the choice is argued at the site. Surfaced to the lead rather than changed.
  - `[low]` `[reject]` `--ocu-rail-dot`'s 12px offsets are magic numbers — the comment names the
    derivation from the rail width and the glyph box; a `calc` would add complexity for no
    observable change.
  - `[low]` `[reject]` `agentComposerCaption` advertises Enter, Shift+Enter and Ctrl+I, none of
    which exists — the caption is published copy this story is required to render, and the
    behaviors belong to the panel that can act.
  - `[low]` `[reject]` the card renders "0 unchanged fields" when there is nothing to disclose —
    the only card this story renders has 38; the fix adds a branch for a state Story 5.2 owns.
  - `[low]` `[reject]` `formatUnchangedCaption` splits on a bare `N` — the published literal
    contains exactly one, and anchoring it would add complexity to a one-row pattern.
  - `[low]` `[reject]` `@for (row of changedRows; track row.field)` throws on duplicate labels —
    field names are unique within one entity's payload; identity tracking is the better code.
  - `[low]` `[reject]` `openSideBar` polls a toggle with a fixed sleep — it fails loudly through
    `assert.fail`, never silently.
  - `[low]` `[reject]` AC1b's fixed 1500 ms wait — proving a redirect did **not** happen needs a
    bounded wait; there is no event to await.
  - `[low]` `[reject]` `screensOffered`'s settle loop reads back to back — the `waitForFunction`
    above it requires the whole filter text and a narrowed group, which is the substantive guard.
  - `[low]` `[reject]` a composed refusal banner outlives the edits after it — the same lifetime
    `envelopeReason` already had; unchanged by this story.

### 2026-09-15 — Code review (full)

- verdicts: 13 rows — high 1, medium 6, low 6. Patched 7 rows; routed 2 to the ledger
  (DW-382, DW-383); rejected 4, each with its reason on the row.
- findings:
  - `[high]` `[patch]` the gate awaits a definitions read that a second pass overtakes —
    verified against the throwaway in a real browser: an accepted form login notifies twice
    (`adopt()` sets `signed-in`; `runSubmit()` notifies again), so `App` issues **two**
    `/agent/definitions` reads, and the one the gate awaits is discarded by the `request`
    sequence guard with `answered()` still false. Measured: reads at 68 ms and 68 ms, responses
    at 71 ms and 73 ms, the navigation map at 76 ms — AC1 fired on a 3 ms margin and would have
    declined silently had the map answered first. Fixed: `AgentStatus.load()`'s promise now means
    "the answer is in" — an overtaken read resolves on the newest one. New test, mutation run.
  - `[medium]` `[patch]` the install-backoff probe classed a cold tab's FIRST pair as a recovery
    — verified: `start()` with no stored pair meets `INSTALL.INSTALLING`, `enterInstalling()`
    backs off, and its probe adopted with `authenticating: false`, so the gate could never fire
    on the first login of a container that was still installing — the one instance FR-28 is
    written for. Fixed: `probeAndSettle(!this.everAdopted)`; two new tests, mutation run.
  - `[medium]` `[patch]` this spec's `## Design Notes` and `## Verification` were overwritten by
    the implement pass and the last triage row was truncated mid-sentence, swallowing the
    `## Auto Run Result` heading. Both sections are restored from `c2373d3` with the panel's
    `loaded()` correction and the mutation ledger; the truncated row's subject is not
    recoverable. Nothing lints `implementation-artifacts/`, which is why it was silent.
  - `[medium]` `[patch]` `## Auto Run Result` reported **762** node and **352** component tests
    under a heading reading *Verification*; the run was 763 and 353. Corrected.
  - `[medium]` `[patch]` `DESIGN.md`'s `attention-dot` still named three conditions after DW-356
    settled two in `EXPERIENCE.md` — the wrong claim was left standing at a second origin, where
    Story 3.7 would have read it. Corrected in place.
  - `[medium]` `[route]` DESIGN.md's Yield order steps (1) and (3) are unbuilt: nothing collapses
    the side bar and `.ocu-shell-content` carries `min-width: 0`, so the content column shrinks
    past `content-min-width` while the panel holds its floor — DW-382, routed to 4.3, which owns
    the panel's width.
  - `[medium]` `[route]` the attention dot's reason reaches its accessible name but not the rail
    tooltip, which `EXPERIENCE.md`'s row also requires; the tooltip's literal is published copy,
    so closing it needs a UX amendment — DW-383, routed to 3.7, which amends that row anyway.
  - `[low]` `[patch]` five assertions that could not fail, each now pinned with its mutation run:
    `main.ts`'s `connectivity` on `AgentStatus`, `.ocu-rail-dot`'s `pointer-events: none`, AC8's
    `::after` asterisk glyph, the gate's deep-link guard, and the card's two projection slots.
  - `[low]` `[patch]` `rail.ts` attributed "Tooltip and accessible name state the reason" to
    `DESIGN.md`; it is `EXPERIENCE.md`'s row.
  - `[low]` `[reject]` the three trust sentences render for both audiences — Task 5 and AC3 are
    what the code follows, and narrowing them is a spec change, not a defect.
  - `[low]` `[reject]` the example band renders above the card rather than inside it — Task 5's
    own words ("`<app-proposal-card>` under the example band"); AC3 holds either way.
  - `[low]` `[reject]` `Session.silentProbe()` has no caller — pre-existing (it is in `c2373d3`),
    and deleting a public method is not this story's footprint.
  - `[low]` `[reject]` the I/O matrix still says "replaced" where the gate pushes — the lead
    accepted the deviation and `## Auto Run Result` records it; the matrix is frozen intent.

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
`start()` without `adopt()`, so a reload is not a login and the requested route survives. The state that
decides whether the gate fires is **the instance's own definition rows** — nothing is stored in the
browser, so "never afterwards" is a consequence of the condition, not of a remembered decision. The
one-shot `consumeFreshSignIn()` records that an authentication happened, never that the gate was shown;
it lives in memory for the tab's lifetime and cannot survive the condition clearing. Which call sites
answer `true` is the call site's own question, not the session state's: the cold silent probe, an
accepted form login, and the install-backoff probe of a tab that has never held a pair.

**Why the panel learns the audience from the navigation map.** The map is the existing answer to
"may this caller edit definitions", recomputed on the instance per call and re-read on any 403
(`navigation.ts noteForbidden`). Reading `screenVerdict('agent/definitions').allowed` adds no second
source and no cache. A map read that **failed** also completes, leaving every verdict *allowed*
(`UNGATED`) — which is the right default for gating and the wrong one for deciding whose job this is —
so all four audience consumers (the panel, the rail's dot, the gate and the form's landing banner) read
`navigation.loaded()`, not `answered()`, beside `agentStatus.answered()`.

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
`ui/tools/example-proposal.test.mjs` re-derives every value from `EXPERIENCE.md`'s UJ-3 step 3. The
card's *chrome* (the title pattern, the direction words, the two headings, `Reverse:`, the unchanged
caption, the example band) is copy and comes from the table.

**Required published copy — settled.** The five rows landed in `EXPERIENCE.md`'s *Fixed strings* table at
**:336-340** (commit `184c8ac`), carrying the eight literals Task 13 adds to `strings.ts`, and the two
*Where*-cell amendments that let the dot name its reason are on the administrator-reminder and
configuration-empty rows. Every other literal the panel, the card and the form render is an existing key:
the panel's own name is `navAreaAgent` (the Landmarks line names the panel `complementary`
"Agent co-pilot"), and `proposalRationaleHeading`, `proposalExpectedImpactHeading`, `proposalReverseLabel`,
`proposalUnchangedFieldsDisclosure`, `proposalExampleCardTitle`, `agentComposerLabel`, `actionSend`,
`agentComposerCaption`, `agentGateReminderBanner`, `agentGateLandingBanner`, `agentGateEmptyState` and
`privilegeDeniedAction` are all present today.

**DW-356 — settled: the dot has two conditions.** The attention-dot row now states the decision and its
reasoning; the dot is shown when the agent is unconfigured (this story) or the kill switch is on
(Story 3.7), and a failed Test connection is deliberately not a third condition. `Kernel/State/Agent.cls`
stores no failure record, which is why the row could not have been implemented as written.

**DW-372 — addressed.** The published action phrase `"change this definition"` plus the
`error-log.page.ts` composition shape: the store keeps the refusal's `code` and `detail.failedPair`, the
page composes with `formatDeniedAction`.

**DW-373 — half addressed, half declined.** The asterisk and its legend ship here (the asterisk is a CSS
`::after` glyph, so `aria-required` remains the semantics and no key is needed for `*`). "Inline on blur
for every field but the key" is declined and recorded in frontmatter `deferred:`: every field-level
sentence is authored once on the server (AD-39), the key field validates on blur only because
`GET /agent/providers` ships its rule *and* its server-written reason, and no other rule's reason reaches
the client before a save. What does ship is the honest part — a refusal that no longer describes a
field's value is dropped on that field's blur rather than left pointing at it.

**Blast radius worth naming.** The panel narrows the content region at the browser suite's 1440x900
viewport, on a throwaway that holds no enabled definition — so every existing browser spec now renders
with the panel present, and eleven of them import `browser/shell-entry.mjs`. Any spec touched keeps
DW-368/DW-374 discipline (a filter leg measured against the whole list, never another leg's survivors; a
substring asserted to isolate a row naming that row alone; `filterToSubset` requiring the whole filter
text and a settled count).

## Verification

**Commands** (code review, 2026-09-15, macOS, Node 26.8.1):

- `cd ui && npm run build` — clean; six prebuild checkers pass.
- `cd ui && npm test` — **768** node tests and **355** component tests, 0 failures.
- `sh scripts/ci-throwaway.sh up`, `npm run build`, `docker cp dist/ocupilot-ui/browser/.
  ocupilot-ci:/durable/iris/csp/ocupilot/`, then `cd ui && npm run test:browser` — **74/74**.
  **The bundle must be redeployed first**: a browser spec runs against what is served, not the
  working tree (`.claude/rules/objectscript-testing.md`). Throwaway torn down afterwards.
- `bash scripts/lint-docs.sh` — clean. No ObjectScript changed, so nothing was loaded or compiled.

**Mutations (Rule 19) — one per AC.** Lines marked `(run 2026-09-15)` were applied, observed red,
reverted and confirmed byte-identical in the code-review pass; the rest are the implement pass's,
recorded beside their own tests.

- AC1 → delete the `router.navigateByUrl` in `App.runFirstLoginGate` → `app.spec.ts`'s AC1 leg and
  its second-authentication leg both go red (run 2026-09-15).
- AC1 (the overtaken read) → make an overtaken read in `AgentStatus.read()` `return` instead of
  awaiting `newest` → `agent-status.test.mjs`'s overtaken-read test goes red (run 2026-09-15).
- AC1 (which adopt is a sign-in) → pass a literal `false` from `enterInstalling()`'s scheduled
  `probeAndSettle` → `session.test.mjs`'s cold-tab backoff test goes red (run 2026-09-15).
- AC1 (the deep-link guard) → delete the `startsWith(form.route)` guard → `app.spec.ts`'s deep-link
  leg goes red (run 2026-09-15).
- AC1b → make `start()`'s resume branch call `adopt()` → `gate.browser-spec.mjs`'s reload leg and
  `session.test.mjs`'s reloaded-tab leg go red.
- AC2 → give the reminder banner a dismiss control → `panel.spec.ts`'s no-dismiss assertion goes red.
- AC3 → render the unchanged caption as a `<button>` → the focusable-selector assertion goes red.
- AC3 (the slots) → rename `select="[card-countdown]"` → `proposal-card.spec.ts`'s projection leg
  goes red (run 2026-09-15).
- AC4 → swap `aria-disabled` for `disabled` on the composer → `panel.spec.ts` goes red.
- AC5 → require a second condition beside `configured()` → the clear-on-Enable assertion goes red.
- AC6 → move the dot inside the rail button → `rail.spec.ts`'s accessible-name assertion goes red.
- AC7 → return `envelopeReason` for `AUTH.NOPRIVILEGE` → `definition-form.page.spec.ts` goes red.
- AC8 → drop the legend render → the same spec goes red; and delete the
  `.ocu-field-label-required::after` rule → `design-tokens.test.mjs`'s glyph pin goes red
  (run 2026-09-15), which is the half the component spec cannot see.
- Integration AC → drop the `ChangeBus` subscription in `AgentStatus`'s constructor →
  `agent-status.test.mjs`'s `changed` test goes red (run 2026-09-15). The browser leg
  (`gate.browser-spec.mjs`'s dot-clears wait) would then never resolve; that half is reasoned from
  the same subscription, not run.

## Auto Run Result

Status: done

**What shipped.** The two facts and the three surfaces that turn on them, client-only: `AgentStatus`
reads the ungated definitions list and re-reads on the change bus; `Session.consumeFreshSignIn()`
answers once per authentication; `App` gates the first login and mounts the panel; `Panel`,
`ProposalCard`, `example-proposal` and the rail's attention dot render the audience's own empty
state; and DW-372's composed denied-action sentence, DW-373's legend, asterisks and stale-violation
drop land on the Definition form. `strings.ts` is at **251 keys = 236 + 12 + 3**, the eight new
literals pointing at `EXPERIENCE.md:336-340`; the `150-240` band is untouched at 236.

**Files.** New: `core/agent-status.ts`, `shell/panel.ts`, `shell/proposal-card.ts`,
`shell/example-proposal.ts`, `testing/agent-status.ts`, `tools/agent-status.test.mjs`,
`tools/example-proposal.test.mjs`, `browser/gate.browser-spec.mjs`, `browser/shell-entry.mjs`, and
`panel.spec.ts` / `proposal-card.spec.ts`. Changed: `app.ts` (gate, panel mount, ninth sign-out
reset), `session.ts` (the one-shot, and `adopt(pair, authenticating)`), `rail.ts` (the dot),
`definition-form.page.ts` / `.store.ts` (DW-372, DW-373), `strings.ts`, `main.ts`,
`_components.scss`, and eleven browser specs reconciled for the gate's redirect.

**Review.** 59 findings over four layers; 1 high, 20 medium, 17 low, 4 false, 17 rejected on the
triage rows. Patched: 25 entries, including the high (a recovery re-probe read as a fresh sign-in
and moved the reader mid-session) and the audience-from-a-failed-map-read defect that contradicted
this spec's own Design Note. Deferred: six, in frontmatter. Every rejection carries its reason in
the triage log.

**Verification.** `npm run build` clean over six prebuild checkers; `npm test` **763** node and
**352** component tests at `dev_complete`, 0 failures; `npm run test:browser` **74/74** against a
throwaway (`ocupilot-ci`, 52776/1975), torn down after; `lint-docs.sh` and `check-objectscript.py`
clean. No ObjectScript changed, so nothing was loaded or compiled. Every mutation was applied,
observed red, reverted and confirmed byte-identical; `## Verification` is the list.

**Two things worth the lead's eye.** The gate navigates with an **ordinary history entry, not
`replaceUrl`**: the matrix's word is "replaced", AC1 asks only that the URL become the form's, and
because the silent probe counts as an authentication a deep link would otherwise be erased from
history. It is argued at the site, and it is what made eleven browser specs need
`leaveFirstLoginGate`. Separately, **a browser spec runs against the bundle deployed at
`ci-throwaway.sh up`, not the working tree** — two mutations read green before the bundle was copied
into `/durable/iris/csp/ocupilot`; the recipe is in `## Verification`.

**Follow-up review recommended: true.** A `high` was patched. The named unverified risk is the one
below — `adopt(pair, authenticating)` re-classifies every authentication path in the client, and no
browser leg exercises a failed refresh or an expired-pair reload against a real instance.

**Residual risks.** `adopt(pair, authenticating)` touches every authentication path and is pinned by
`session.test.mjs` alone: the install-backoff and `install-unreadable` classifications are reasoned
from the call sites, not observed against a real instance. The spec predicted a layout ripple from
the narrower content region and none appeared; the ripple it did not predict was the redirect.
