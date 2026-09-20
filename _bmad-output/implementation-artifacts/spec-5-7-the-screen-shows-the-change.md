---
title: 'Story 5.7: The screen shows the change'
type: 'feature'
created: '2026-09-20'
status: 'ready-for-dev'
baseline_revision: '91e63ad4db0bb0718f4e4bed912a1d18403820b2'
baseline_commit: '91e63ad'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A confirmed write ends in a claim, not in evidence. Nothing publishes a `changed`
event for it -- `ChangeBus` carries the kind and `RefreshService` already routes it, but the only
three publishers in the tree are OcuPilot's own agent screens, so the agent write path reaches no
screen. The client's key builder does not normalize (DW-1364), so the first server-built id to
travel would key a highlight onto nothing. `ChangeEvent` carries no **action**, which AD-14 and the
story's first acceptance criterion both name. And there is no toast: no host, no store, no styles,
one orphan published string.

**Approach:** Make the confirmed write a publisher on the existing bus, carrying the proposal's
canonical triple plus a closed-set action; make the client's key equal the server's by mirroring the
kernel's per-type id rule the way the entity-type enum is already mirrored; and build the one
unbuilt surface -- an off-screen toast with its stack, timers, dismiss and "Open in <screen>". The
re-fetch, the row and field highlight, the scroll-into-view, the selection clear on delete and the
auto-refresh pause are already built and are pinned here, not rebuilt.

## Boundaries & Constraints

**Always:** The event carries AD-13's canonical triple -- the spelling `Propose.TargetRef` stored,
never the one the agent typed -- plus one action from a closed set (`created` | `updated` |
`deleted`). The client's `entityRefKey` and the kernel's `EntityRef.Key` produce the same string for
the same triple, and the per-type rule that makes that true is **declared once in the kernel and
mirrored**, never hand-copied: an id rule the client cannot implement fails the build, exactly as an
unknown entity type already does. A screen re-fetches in place through its declared read (AD-36) and
mutates no row from a write response (AD-14). "Does the open screen show this entity" is answered by
**one** predicate that both the re-fetch filter and the toast gate call. Every user-visible string
comes from `core/strings.ts` and is present in EXPERIENCE.md's Fixed-strings table; non-ASCII is
authored as `\uXXXX` escapes (Rule 14). `core/` imports no `@angular/core` (AD-19). Every IRIS MCP
call carries `server: "ocupilot-slot-a"`; the throwaway is `ocupilot-ci` on 52776/1975.

**Never:** No new route, no new tool, no `SCHEMAVERSION` move, so no `EndpointCoverage` or
`SurfaceCoverage` roster row. No server-to-client push channel: the publisher is the client, at the
moment the confirm answers. No edit to `ui/src/styles/**` or to
`ui/src/app/shell/{header,account-menu,side-bar,command-box,panel-resize-handle}*` -- Epic 15 holds
them and is live (see Design Notes, *Where the toast's styles live*). No toast for an error (those
are banners) and none for a change on the screen the user is looking at. No cross-tab broadcast
(AD-47). No second entity-type vocabulary and no free string on a descriptor. Do not write
`deferred-work.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| **DW-1364.** The two key builders agree | `('web-application', 'instance', '/API/OcuPilot/')` built on the client and `EntityRef.Key` on the instance | Byte-identical keys: the id folds to lower case and loses every trailing slash on both sides. Every other type is unchanged on both sides | None |
| An id rule the client cannot implement | `EntityRef.IDRULES` names a rule the mirror's roster does not hold, or names a type outside `TYPES` | `screen-mirror.mjs` throws naming the rule and the file; `npm run build` fails in `prebuild` | Build failure, never a silent identity rule |
| A confirmed write publishes | The user confirms a live `webapp.list.update` proposal; the confirm answers 200 `state: confirmed` | Exactly one `changed` event on the bus carrying the proposal's canonical `type`/`scope`/`id` and `action: 'updated'`, published after that proposal's `proposal-closed` | None |
| A refused confirm publishes nothing | Confirm answers 403 `PROHIBITED.*` or the restraint verdict; the row stays `live` | Zero `changed` events; the card renders the refusal (Story 5.6) and the pause stays on | Rendered, never published |
| The open screen re-fetches and highlights | A list bound to that entity type and scope is open | One read through the declared read; sort, filter, selection, scroll and max-rows unchanged; the row carries the change-highlight background, the 3px agent bar and the "Changed" tag, and is scrolled into view | A failed re-fetch is the refresh framework's existing banner fault |
| The two-second budget | The confirm's terminal status line appears in the panel while the list is open in the same tab | The row carries `.ocu-data-table-row-changed` within **2,000 ms** of that instant, measured by the node harness (Design Notes, *How the two seconds is measured*) | The wait is armed well beyond the budget so a miss is an assertion, not a timeout |
| A detail screen highlights the field | A detail page open on that entity | The changed field takes the highlight and the "Changed" tag through the existing `DetailHighlights` path | None |
| A deleted row | A `changed` event with `action: 'deleted'` whose re-fetch returns a row set without that key | The row leaves; if it was selected, the selection clears and the locator's entity segment clears | None |
| A created row | `action: 'created'` and a re-fetch that returns the new key | The row appears highlighted and selected | None |
| The affected screen is not open | A `changed` event whose type or scope the open screen does not show | One toast naming the change, carrying "Open in <screen>", which navigates to that screen with the entity selected | A type no built screen shows raises a toast with no action, which lives ten seconds |
| The affected screen **is** open | The same event while the open screen shows that type and scope | Zero toasts -- the row highlight is the confirmation | None |
| Toast stack and timers | Four toasts raised in order | At most three are rendered, newest on top, the oldest dropped; one without an action lives 10 s, one with an action 30 s | None |
| The timer pauses | A pointer hovers or focus enters any toast in the stack | Every toast's countdown stops and resumes on leave/blur, so a toast being read cannot expire | None |
| Dismiss | The dismiss control is pressed | That toast leaves; the others keep their remaining time | None |
| Toasts are never errors | Any fault -- a read fault, a 403, a refused confirm | Zero toasts; the existing banner renders it | The banner path is unchanged |
| The bus does not cross tabs | The list open in a second tab while the write is confirmed in the first | The second tab's row carries no change highlight and no toast appears there | None |
| The auto-refresh pause (already built) | A proposal open against a screen's entity type | The chip reads `Auto-refresh paused — a proposal is awaiting confirmation` and the timer is suspended; it resumes on confirm, cancel or expiry | Pinned at the tools tier -- no shipped write tool targets an auto-refreshing screen's entity type (Design Notes) |
| The change survives the toast | The toast expires | The panel's reply for that turn names the same change in its own published sentence | None |

</intent-contract>

## Code Map

- `ui/src/app/core/change-bus.ts:30` `ChangeEventKind` (`changed` | `proposal-open` | `proposal-closed`
  -- all three already exist); `:36-50` `ChangeEvent` (`kind, type, scope, id, key, proposalId,
  expiresAt` -- **no `action`; that is this story's addition**); `:53-60` `ChangeEventInput`;
  `:105-124` `publish`, whose **`:106`** first statement is `entityRefKey(...)` and whose `:107`
  drops the event when that is `null` -- the line DW-1364 names; `:69` the untyped listener `Set`
  (every subscriber sees every event and filters itself); `:15` a **stale** header paragraph saying
  nothing publishes yet -- correct it at its origin, do not append to it.
- `ui/src/app/core/entity-ref.ts:26`/`:33` the two scopes, `:39` `REF_SEPARATOR`, the U+0002 join character (one code point above `entity-id.ts`'s composite separator),
  **`:59-63` `entityRefKey`, a plain join with no normalization -- DW-1364's footprint**, `:69-78`
  `parseEntityRefKey` (must stay non-normalizing, mirroring the server's `Parse`), `:89-93`
  `scopeFor`, `:19` the `ENTITY_TYPES` import from the generated mirror.
- `src/OcuPilot/Kernel/EntityRef.cls:42` `REFSEPARATOR`, `:46` `TYPEWEBAPPLICATION`, `:55-70` `Key`
  (normalize, then validate, then join), `:75-102` `Parse` (does **not** normalize), `:115-131`
  `Wire` (`{type, scope, id}`), **`:163-171` `NormalizedId` -- the rule hard-coded as an `If` on one
  type; this is what becomes a declared table**, `:181-192` `Canonical`, `:196-208` `Validate`
  (`[ Private ]`).
- `src/OcuPilot/Kernel/EntityType.cls:28` `Parameter TYPES` (28 members), `:34` `IsKnown`, `:41`
  `List`, `:54` `Count` -- the closed enum the id-rule table is keyed against.
- `ui/tools/screen-mirror.mjs:50` `ENTITY_TYPE_SOURCE`, `:60` `TYPES_PARAM_RE`, `:135-143`
  `parseEntityTypes` (returns `null`, never `[]`, when the parameter is missing -- copy that shape),
  `:192-201` `entityTypesIn`, `:226-228` `readSources`, **`:1905-1912` the throw that fails the build
  on an unknown entity type -- the precedent the id-rule check follows**, `:2040` the
  `EntityTypeKey` union emission, `:2393` the `ENTITY_TYPES` emission, `:2444-2447` `--check`.
- `ui/src/app/core/screens.generated.ts:13` `EntityTypeKey`, `:325-366` `ScreenDeclaration`
  (`entityType` `:338`, `entityLabelKey` `:340`, `secondaryEntityTypes` `:341`, `scope` `:342`),
  `:390-419` `ENTITY_TYPES`, `:568` `SCREENS`.
- `ui/src/app/core/turn.ts:236-257` `ProposalOutcome` (`state, closedReason, confirmedAt,
  auditMarked`), `:392-409` where `TurnProposal.target` is parsed off the wire, `:897` `confirmProposal`,
  **`:906-953` `decideProposal` -- its success branch is where `changed` is published**, `:967-986`
  `recordProposalState`, `:1182-1215` `publishProposals` (the `proposal-open` `:1195` /
  `proposal-closed` `:1207` publisher, called from the poll `:1160`, from `recordProposalState`
  `:985`, from `restore` `:768`, `newConversation` `:1014`, `endSession` `:1028`).
- `ui/src/app/core/refresh.ts:227-248` `bind` (`:236-238` builds `entityTypes` from primary plus
  secondaries; `:245` subscribes), **`:608-633` `onBusEvent` -- `:611-612` the type-and-scope filter
  that becomes the shared predicate, `:614-618` `markChanged` plus `readNow`**, `:184` `liveProposals`,
  `:312` `paused`, `:341-347` `chipLabel`, `:464-496` `transition`, `:498-512` expiry sweep.
- `ui/src/app/core/navigation.ts:327` `screenForDescriptor`, `:343` `screenForEntityType`, `:370`
  `routeEntityType`, `:305-314` the parent-scoped criteria read off the route segment -- the home for
  the shared `screenShowsEntity` predicate and for the toast's route/label lookup.
- `ui/src/app/core/screen-store.ts:155` `applyTick` (writes four slots, which is what makes a
  re-fetch silent), `:171-182` `clearAnswers`, `:186-204` selection and active, `:207-223`
  `changed`/`markChanged`/`clearChanged`, `:334` `ScreenStores.for`.
- `ui/src/app/core/table-model.ts:213-226` `reconcile` -- **a selected key absent from the new row
  set already clears the selection**; driven from `shell/data-table.ts:888-921`, written back `:915`.
- `ui/src/app/shell/data-table.ts:140` the table, `:233`/`:277`/`:437`/`:471` the changed row and its
  tag, `:925-937` `scrollChangedIntoView`, `:939-947` `select` (clears the mark on interaction).
- `ui/src/app/shell/list-page.ts:68-131` the one list base -- `:96` the store, `:102`
  `createScreenRead` plus `bind` plus `readNow`, `:124` the `OnPush` generation bump, `:125-130`
  `unbind`.
- `ui/src/app/core/detail-highlights.ts:33` `DetailHighlights` (`update` `:44`, `changed` `:53`,
  `reset` `:58`); call sites `areas/tasks/details.page.ts:149,154,169,177-181,241`,
  `areas/os-management/process-details.page.ts:126,131,231`,
  `areas/os-management/database-details.page.ts:212,217,349`.
- `ui/src/app/app.ts` -- the shell template (fault banner, instance notice, header, rail, side bar,
  locator bar, command bar, `router-outlet`, panel, status bar). **No toast slot; one is added after
  the panel** (EXPERIENCE.md:662's focus order). Outside both live epics' `paths_hint`, so it is a
  reportable footprint extension (Rule 11 (b)).
- `ui/src/app/core/overlay-stack.ts` -- the existing z-order service the toast region checks against.
- `ui/src/app/core/strings.ts:216` `tableChangeToastLink: 'Open in <screen>'` (**declared, zero
  consumers -- this story's link**), `:218`/`:220`/`:222`/`:224` the auto-refresh chip and stamp
  strings, `:228` `tableChangedTag: 'Changed'`, `:38-42` the header's `\uXXXX`-escape rule, `:1-7`
  the `client-lint.mjs` rule that fails the build on an inline literal in a template.
- `ui/src/app/core/agent-status.ts:48,51,59` the agent entity/scope constants, `:450` its bus
  subscriber (hard-filters `kind !== 'changed'`); `ui/src/app/core/agent-context.ts:286` the other.
- The three existing `changed` publishers, all of which gain the new `action` argument:
  `ui/src/app/areas/agent/switches.store.ts:399-405`,
  `ui/src/app/areas/agent/definition-form.store.ts:700-708` (save `:563-591`, gate path `:625-638`),
  `ui/src/app/areas/agent/definition-actions.ts:152-159`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:198-390` `Transition` (port call `:345`, marker `:371`,
  ledger finalize `:373`, `RecordMarking` `:382`, `Answer` `:384`), `:631-649` `Answer` and its four
  keys plus `auditMarked` -- **no target on the confirm response, and none is added: the client
  already holds the canonical triple in `TurnProposal.target`**.
- `src/OcuPilot/Kernel/State/Propose.cls:76` the stored `targetRef` column, `:613-637` `WireRow`
  (the one place a proposal's wire shape is written, `target{type,scope,id}` included);
  `src/OcuPilot/Kernel/Proposal/Mint.cls:89` writes `targetRef` through `EntityRef.Key`, which is why
  the triple the client holds is canonical by construction.
- `ui/browser/proposal-confirm.browser-spec.mjs:195` the one end-to-end confirmed write
  (`:206-208` press and wait for `.ocu-proposal-card-status`, `:232` the instance read-back, `:235`
  **a fresh navigation to the list, which is why no highlight is observed today**), `:43`/`:46` the
  home and list URLs, `:66-74` `armProbeDefinition`/`requireFreeSlot`, `:60-64` the live-container
  refusal.
- `ui/browser/audit.browser-spec.mjs:82-90` `FIRST_ROW_BUDGET_MS` / `FIRST_ROW_WAIT_MS` and
  `:745-762` the bracketed `Date.now()` measurement -- **the budget pattern this story copies**;
  `ui/browser/data-table.browser-spec.mjs:527-545` the existing scroll-into-view plus
  `transitionDuration === '2s'` assertions; `ui/browser/panel-spec.mjs:60` `signedInAt`, `:91`
  `saveAndSettle`; `ui/browser.config.mjs:60-101` the config and its 30 s navigation timeout.
- `ui/tools/change-bus.test.mjs` (8 tests), `ui/tools/entity-ref.test.mjs` (7 tests, **`:75` the
  verbatim round-trip and `:116-120` the plain-join assertion both change**),
  `ui/tools/refresh.test.mjs:502-661` the pause suite and `:956` the changed-event read,
  `ui/tools/turn.test.mjs:1364,1400,1429` the proposal publisher, `ui/tools/screen-mirror.test.mjs:159`
  the unknown-type refusal, `ui/tools/navigation.test.mjs`, `ui/tools/detail-highlights.test.mjs`.
- `src/OcuPilot/Test/EntityRef.cls` -- the class covering `Kernel/EntityRef.cls`; the id-rule table
  is pinned here.
- `ui/src/styles/_tokens.scss:97-100` `--ocu-inverse-surface`/`--ocu-inverse-on-surface` (+ `-dark`),
  `:45` `--ocu-secondary-dark`, `:198` `--ocu-elevation-3`; `_metrics.scss:15-16` `--ocu-space-3/4`,
  `:22-25` the radius tokens, `:70` `--ocu-motion-change-highlight-duration: 2000ms` and `:85` its
  `0ms` under reduced motion. **Every token the toast needs already exists; read-only here.**
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:639-643` the
  authoritative live-data rows, `:414` the toast component row (`role="status"`, dismiss on every
  toast, reachable with Tab after the panel), `:524-525` the two State Patterns rows, `:661-672` the
  accessibility floor (landmarks, focus order, polite status messages, time limits, reduced motion),
  `:289-292` the Fixed-strings rows that already exist; `DESIGN.md:346-348` `row-background-changed`,
  `row-indicator-changed: '3px {colors.agent-accent}'`, `changed-tag`, `:497-508` the toast token
  block (`max-stack: 3`), `:1050-1054` the changed-row and paused-chip recipes, `:1209-1211` the
  toast recipe **and the sentence that toasts are never used for errors**.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/EntityRef.cls` -- replace `NormalizedId`'s hard-coded single-type `If` with a
  declared table: `Parameter IDRULES = "web-application:foldcase-striptrailingslash"` (comma-separated
  `type:rule` pairs) plus a `Parameter IDRULENAMES` listing the closed rule vocabulary. `NormalizedId`
  looks the type up in the table and applies the named rule; a type absent from it canonicalizes to
  itself, exactly as today. Behavior for `web-application` is unchanged -- this is a refactor to make
  the rule **data a generator can read**, and the class header says so. A later write-tool story adds
  one pair, not a branch. No `SCHEMAVERSION` move (nothing stored changes meaning); record that at the
  change.
- `ui/tools/screen-mirror.mjs` -- parse `IDRULES` and `IDRULENAMES` beside `TYPES` (same regex-plus-
  `null` shape as `parseEntityTypes`, `:135-143`), and emit `ENTITY_ID_RULES` into
  `screens.generated.ts` as a frozen `Record<EntityTypeKey, string>` holding only the types that
  declare a rule. Throw, in the style of `:1905-1912`, when a declared pair names a type outside
  `TYPES`, or names a rule the generator's own `IMPLEMENTED_ID_RULES` roster does not hold -- naming
  the rule, the file and AD-13. This is the build failure that stops a kernel rule reaching the client
  as a silent no-op.
- `ui/src/app/core/entity-ref.ts` -- add `normalizeEntityId(type, id)` applying the mirrored rule from
  a local map of rule name to implementation, and call it from `entityRefKey` **before** the validity
  gate, so a web-application id of `/` still refuses. `parseEntityRefKey` is untouched and its doc says
  why (the server's `Parse` does not normalize either). Export the implemented rule names so the test
  below can pin them against the generator's roster. (DW-1364)
- `ui/src/app/core/change-bus.ts` -- add `ChangeAction = 'created' | 'updated' | 'deleted'` and a
  required `action` on `ChangeEvent`/`ChangeEventInput` for `kind: 'changed'`; a `changed` input with
  an action outside the set, or a proposal-kind input carrying one, is refused by `publish` the way an
  unknown type already is. Correct the stale "nothing publishes yet" paragraph at `:15` -- replace the
  wrong sentence, do not append to it.
- `ui/src/app/core/navigation.ts` -- add `screenShowsEntity(declaration, event, namespace)`: the
  primary-plus-secondary type test and the `scopeFor` scope test, lifted verbatim from
  `refresh.ts:611-612` so there is one implementation of "is this entity mine". Add
  `screenForChange(event)` returning the built screen that shows that type (reusing
  `screenForEntityType`) and its route with the entity segment encoded, for the toast's action.
- `ui/src/app/core/refresh.ts` -- `onBusEvent` calls `screenShowsEntity` instead of its two inline
  tests; behavior unchanged, and the existing pause suite must stay green unaltered.
- `ui/src/app/core/toasts.ts` (new) -- the framework-free toast store (AD-19): at most three entries,
  newest first, a fourth dropping the oldest; each entry `{id, action, entityType, entityLabel,
  entityId, route, expiresAt}`; `publish`, `dismiss(id)`, `holdTimers()`/`releaseTimers()` for
  hover-or-focus, `subscribe`, and an injectable `now()`. Ten seconds without an action, thirty with.
  It subscribes to the bus, ignores every kind but `changed`, and raises nothing when
  `screenShowsEntity` answers true for the open screen. It never renders a fault.
- `ui/src/app/shell/toast-host.ts` + `toast-host.spec.ts` (new) -- `app-toast-host`, standalone,
  `OnPush`, the region `role="status"` with its label, the stack bottom-right above the status bar,
  each toast carrying the composed sentence, the `tableChangeToastLink` action where a screen exists,
  and a dismiss control. Hover and focus on any toast hold every timer. Styles are **component-scoped
  `styles:`** using existing `--ocu-*` tokens only (see Design Notes) -- no color literal, or
  `client-lint.mjs` fails the build.
- `ui/src/app/app.ts` -- mount `<app-toast-host>` after the panel so Tab reaches it last
  (EXPERIENCE.md:662). Report this file under `footprint_extensions:`.
- `ui/src/app/core/turn.ts` -- in `decideProposal`'s success branch, when the confirm answered 200
  with `state === 'confirmed'`, publish `proposal-closed` first (through the existing
  `publishProposals` path) and then one `changed` event built from that proposal's `target` triple
  with `action: 'updated'`. A refused or canceled confirm publishes no `changed`. The action is
  `'updated'` because every shipped write tool is a PUT against an existing object (Design Notes).
- `ui/src/app/shell/panel.ts` -- append one published sentence naming the change to the reply for a
  confirmed write, the way `replyWithConfirmSentence` (`:781-792`) already appends published copy, so
  the record outlives an expired toast.
- `ui/src/app/shell/data-table.ts` -- add a visually hidden polite `role="status"` span that announces
  the change once when a row is marked changed (EXPERIENCE.md:664). The refresh stamp and refresh
  ticks stay unannounced (`:642`).
- `ui/src/app/areas/agent/switches.store.ts`, `definition-form.store.ts`, `definition-actions.ts` --
  pass `action: 'updated'` at the three existing publish sites. Nothing else changes.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- append at the
  **tail** of the Fixed-strings table (epic-wide shared-append) one row per new string: the three
  change sentences, the toast region label, the toast dismiss name and the change announcement. Add
  nothing else.
- `ui/src/app/core/strings.ts` -- add `tableChangeCreated`/`tableChangeUpdated`/`tableChangeDeleted`
  (each carrying an `<entity>` span, the `statusAutoRefreshOn` + `formatAutoRefreshOn` precedent),
  `tableChangeToastRegion`, `tableChangeToastDismiss` and
  `tableChangeAnnouncement: 'Updated: <entity> <action>'`. Escapes only, never literal bytes.
- `src/OcuPilot/Test/EntityRef.cls` -- pin the declared table: the `web-application` pairs fold and
  strip, a type with no pair is verbatim, a key built from a non-canonical spelling equals one built
  from the canonical, and `IDRULES` names no type outside `TYPES` and no rule outside `IDRULENAMES`.
- `ui/tools/entity-ref.test.mjs` -- extend `:75` and `:116-120` rather than contradict them: the
  verbatim round-trip now holds for every type with no rule and the corpus gains a web-application
  leg; add the cross-language equality (the client key for three non-canonical spellings equals the
  literal the server produces) and the roster pin (the generator's `IMPLEMENTED_ID_RULES` equals the
  rule names `entity-ref.ts` implements, in both directions).
- `ui/tools/change-bus.test.mjs`, `ui/tools/toasts.test.mjs` (new), `ui/tools/navigation.test.mjs`,
  `ui/tools/turn.test.mjs`, `ui/tools/screen-mirror.test.mjs` -- the matrix rows at this tier: the
  action's closed set, the publish-on-confirm and no-publish-on-refusal legs, the stack depth and the
  two timers with a driven clock, the hover/focus hold, the dismiss, `screenShowsEntity`'s four
  outcomes, and the generator's refusal of an unknown rule name.
- `ui/src/app/shell/toast-host.spec.ts`, `ui/src/app/shell/data-table.spec.ts`,
  `ui/src/app/shell/list-page.spec.ts`, `ui/src/app/shell/panel.spec.ts` -- the DOM half: the region
  and its role, three toasts rendered from four raised, the dismiss control, no toast for an open
  screen and none for a fault, the announcement span, the deleted-row selection clear and the
  created-row selection, and the appended reply sentence.
- `ui/browser/change-highlight.browser-spec.mjs` (new) -- the geometry and timing legs, built on
  `panel-spec.mjs` and on `proposal-confirm.browser-spec.mjs`'s fixtures: confirm with the web
  applications list open in the same tab, bracket the budget as in `audit.browser-spec.mjs:745-762`,
  assert the row's highlight class inside 2,000 ms and its rect inside the viewport rect, and assert a
  second tab's row is untouched. It must not navigate away between the confirm and the assertion.

**Acceptance Criteria:**

- **DW-1364.** Given the id `/API/OcuPilot/` for `web-application`, when the client builds a reference
  key and the instance builds one through `EntityRef.Key`, then the two strings are equal, and equal
  to the key built from `/api/ocupilot`; and given a rule name the client does not implement, when
  `npm run build` runs, then `screen-mirror.mjs` fails it naming the rule.
- Given a confirmed write, when the confirm answers, then exactly one `changed` event carrying the
  proposal's canonical triple and one action from the closed set reaches the bus, and a refused
  confirm produces none.
- **Integration AC (Rule 1).** Given the web applications list open in the same tab, when the user
  confirms a write against a row of it, then that row carries the change-highlight class within
  2,000 ms of the confirm's terminal status line appearing and is scrolled into view, while the
  table's sort, filter and scroll position are what they were. Asserted by
  `ui/browser/change-highlight.browser-spec.mjs` against a real browser, not by reading store state.
- **Integration AC (Rule 1).** Given a `changed` event for an entity type the open screen does not
  show, when it reaches the toast store, then one toast renders with its sentence and its
  "Open in <screen>" action, and activating that action routes to that screen with the entity
  selected. Asserted by the Angular component runner against the DOM.
- Given four toasts raised in order, when the fourth arrives, then three are rendered newest first and
  the oldest is gone; given one without an action it expires after ten seconds and one with an action
  after thirty; given a hover or focus anywhere in the stack, no toast expires until it ends.
- Given a change on the entity type the open screen shows, when the event arrives, then no toast is
  raised; and given any fault, then no toast is raised.
- Given a re-fetch that no longer returns the selected key, when the list reconciles, then the row is
  gone and the selection and the locator's entity segment are clear; given a re-fetch that returns a
  new key with `action: 'created'`, then that row is highlighted and selected.
- Given the same list open in a second tab, when the write is confirmed in the first, then the second
  tab's row carries no change highlight and no toast appears there.
- Given a live proposal against a screen's entity type, when that screen's auto-refresh is on, then
  the chip reads the published paused string and the timer is suspended, resuming on confirm, cancel
  or expiry -- pinned at the tools tier, because no shipped write tool targets any auto-refreshing
  screen's entity type (Design Notes, *Why AC8 has no browser leg*).
- Given a confirmed write, when its toast expires or was never raised, then the turn's reply carries a
  published sentence naming the same change.
- Given `bash scripts/smoke.sh`, when it runs against a throwaway with OcuPilot installed, then it
  still passes and the executed-check count is non-zero.

## Spec Change Log

## Review Triage Log

## Design Notes

**Footprint, authorized by the lead at the spec gate.** `ui/src/app/app.ts` is outside both live
epics' `paths_hint` and no other epic writes it; it is authorized for the toast region's mount only,
and recorded as a `footprint_extensions:` entry at the commit. `ui/src/styles/**` is **contended** --
Epic 15 is live on Story 15.5 -- so the toast's rules stay component-scoped on
`ui/src/app/shell/toast-host.ts` and use only tokens that already exist; folding them into
`_components.scss` is a one-commit move after Epic 15 merges and is not this story's. `panel-resize-handle*`
is Epic 15's and is not touched. `EXPERIENCE.md`'s Fixed-strings table takes its new rows at the
**tail** (shared-append); the narrow in-place allowance the owner granted applies only to a line that
is itself the subject of a fix, which none of these are.

**NFR-1 verified by the lead, not taken from the plan.** `epics.md:194` reads "a confirmed write's
screen refresh completes within two seconds", so the two-second figure has a numeric authority and
this is not a Rule 5 tripwire. The spec's separation of that **latency deadline** from the 2,000 ms
CSS settle duration in `_metrics.scss` is the distinction that makes it measurable, and the browser
harness's `Date.now()` is the clock every other timing assertion in this project uses.


**Governing ADs (Rule 6).** **AD-14** is this story's own AD: one change event carrying the scoped
triple plus an action, screens re-fetch and never patch, the entity-type vocabulary is a single closed
kernel-owned enum whose unknown value fails the build, and the key comes from the descriptor so two
screens over one entity cannot disagree. **AD-13 as amended (DW-1359)** supplies the scoped triple and
the per-type canonical rule, which is what DW-1364 is about. **AD-43** owns the auto-refresh framework
and says the proposal-open/proposal-closed pause rides this same bus. Also in force: **AD-36** (the
re-fetch is the screen's one declared read, bounded), **AD-19** (`core/` is framework-free; screen
state is the store, and components mirror it into signals), **AD-5** (the descriptor is the single
source; the client mirror is generated, never a second source), **AD-44** (the namespace in the route
is data scope, and it is the scope half of every key), **AD-47** (per-tab storage, no cross-tab
broadcast -- which is why the bus not crossing tabs is an invariant rather than an omission),
**AD-6/AD-34/AD-40** (the proposal lifecycle whose open and close events already ride the bus),
**AD-15** and **AD-41** (Story 5.6's marker and ledger row, unchanged here), **AD-12/AD-39** (one
envelope; a fault is a banner, never a toast), **AD-11** (a toast renders data, never markup, and
issues no request). NFR-1 is the numeric authority (below).

**How the two seconds is measured, and by what.** NFR-1 (`prd.md:1068`) reads "a confirmed write's
screen refresh completes within two seconds", and scopes the budget to what "is within OcuPilot's
control". The clock is the **node harness's `Date.now()`**, bracketing a puppeteer wait, which is the
only clock this project's browser specs use (`audit.browser-spec.mjs:745-762`,
`data-table.browser-spec.mjs:141-151`, `turn.browser-spec.mjs:131-145`); there is no `performance.now`
or CDP tracing anywhere under `ui/browser/`. It **starts** when
`app-proposal-card .ocu-proposal-card-status` appears -- the earliest instant the browser can know the
write completed, and the instant the publisher fires -- and **stops** when the list row carries
`.ocu-data-table-row-changed`. The server-side write completes fractionally earlier, by the transport
of the confirm response, which is outside the client's control and so outside NFR-1's own scope; the
leg runs against the loopback throwaway, where that transport is milliseconds. The wait timeout is set
well above the budget (the `FIRST_ROW_WAIT_MS = BUDGET * 5` precedent) so a miss fails the assertion
rather than the wait -- `data-table.browser-spec.mjs:141-151` sets its timeout equal to its budget and
is the mistake not to copy. **This 2,000 ms is a latency deadline, not the 2,000 ms in
`_metrics.scss:70`**, which is the CSS transition duration the highlight settles over; the two share a
number and measure different things, and the spec asserts each with its own instrument.

**Why the client publishes, not the server.** There is no server-to-client push channel: proposals
reach the panel on the turn progress poll and the confirm answers its own request. The client already
holds the canonical triple -- `Mint.cls:89` writes `targetRef` through `EntityRef.Key`, and
`Propose.WireRow` (`:613-637`) hands it to the panel as `target{type,scope,id}` -- so publishing from
`decideProposal` uses the same string the marker and the ledger row recorded, with no new wire field
and no new route. That is only true once DW-1364 is fixed, which is why the two are one story.

**Why the id rule is mirrored rather than copied.** A hand-written copy of the kernel's rule in
`entity-ref.ts` is precisely the second source AD-5 exists to prevent, and it is what DW-1364 already
demonstrates happening. Declaring the rule as data in `EntityRef.cls` and mirroring it is the shape
the entity-type enum already uses, down to the generator throwing on an unknown value; it also makes
each later write-tool story's rule a one-line declaration rather than an edit in two languages. The
generator's roster of implementable rule names, pinned equal to the client's implementations by a
test, is the same device the Conventions' Secrets row uses for the credential pattern.

**One predicate, two callers.** `refresh.ts:611-612` currently answers "does this screen show this
entity" inline, and the toast needs the inverse answer. Two inline copies would be two answers, which
is the class of divergence AD-14's last sentence is about, so the test is lifted into
`navigation.ts` and both call it. The toast resolves the open screen from the router URL through
`navigation.ts`'s existing route lookup rather than from `RefreshService`'s bound screen, because a
screen that declares no auto-refresh still shows entities and `RefreshService` does not expose its
bound types.

**Where the toast's styles live, and why it is not `ui/src/styles/**`.** DESIGN.md's toast recipe
(`:497-508`, `:1209-1211`) is entirely unimplemented -- `ui/src/styles/` holds no toast class at all --
and `ui/src/styles/**` is in both Epic 5's and Epic 15's `paths_hint`, with Epic 15 live on Story 15.5,
so it is a contended path (Rule 11). The toast therefore carries **component-scoped `styles:`** on
`ui/src/app/shell/toast-host.ts`, which is Epic 5's own tree; the precedent in this repository is
`ui/src/app/testing/table-harness/main.ts:124`. No token is invented: every value DESIGN.md's recipe
names already exists (`--ocu-inverse-surface`, `--ocu-inverse-on-surface`, `--ocu-secondary-dark`,
`--ocu-elevation-3`, `--ocu-space-3/4`, `--ocu-radius-md`), and `client-lint.mjs`'s
`checkHardcodedColors` fails the build on any color literal outside `_tokens.scss`, so the constraint
is enforced rather than promised. Flag the deviation from the Consistency Conventions' "global
stylesheets live under `ui/src/styles/`" row to the lead: it is a concurrency accommodation, and
folding these rules into `_components.scss` is a one-commit move once Epic 15 merges.

**What is already built, and is pinned rather than rebuilt.** The bus and all three event kinds; the
proposal-open/proposal-closed publisher (`turn.ts:1195`/`:1207`) and the whole auto-refresh pause,
including its expiry arm; the type-and-scope routing and `markChanged` plus `readNow`; the row
highlight, the 3px agent bar, the "Changed" tag, the scroll-into-view (`data-table.ts:925-937`), the
settle transition and its reduced-motion zero; the field highlight on the three detail pages; the
selection clear on a vanished key (`table-model.ts:213-226`); and the preservation of sort, filter,
selection and scroll across a tick (`screen-store.ts:155`). 5.7's new code is the action, the
normalization, the confirmed-write publisher and the toast.

**Why AC8 has no browser leg.** The seven auto-refreshing screens declare `database`, `process`,
`task` and `''` -- checked on all seven descriptors, not one -- and the only registered write tool is
`webapp.list.update` over `web-application`. No live proposal reachable today can pause an
auto-refreshing screen, so an end-to-end browser leg for the pause cannot be written without a second
write tool. The behavior is pinned where it already lives, `refresh.test.mjs:502-661` (nine tests
including two-opens-one-close, an unopened close, and the expiry arm), and this story adds nothing
there beyond keeping it green through the `screenShowsEntity` refactor. Stories 5.11 and 5.12 are the
first that could raise it to the browser.

**Created and deleted have no shipped producer.** `webapp.list.update` is the only write tool,
`Confirm.WRITETYPE` is `"PUT"`, and `FingerprintMatches` requires the target to be readable now -- so
a confirmed write today is always `updated`. The created and deleted branches are therefore pinned by
publishing a synthetic event against a read whose row set changed, at the tools and component tiers,
and this spec says so rather than implying a confirmed write exercises them. The closed action set is
declared now because AD-14 names it and because 5.13's deletes are the first real producer.

**The reply sentence.** "The agent's reply names the same change" is not assertable against
model-authored prose, so it is met the way Story 5.6 met the same shape: one published sentence
appended by the panel to the confirmed write's reply, through the existing `replyWithConfirmSentence`
mechanism. What the AC promises -- that nothing is lost when a toast expires -- is then true by
construction and falsifiable.

**Integration ACs (Rule 1).** Two are named under Tasks & Acceptance, one at the browser tier and one
at the component tier, both against observable DOM.

**Consumes:** `Kernel.Proposal.Confirm`'s answer and `Kernel.State.Propose.WireRow`'s `target`
(Stories 5.1, 5.3); `Kernel.EntityRef` and `Kernel.EntityType`; `core/change-bus.ts`,
`core/refresh.ts`, `core/screen-store.ts`, `core/detail-highlights.ts`, `core/navigation.ts` and
`shell/data-table.ts` (Stories 1.14, 2.4, 6.x); the panel's reply and tool-call card (Stories 4.5,
5.6); `ui/tools/screen-mirror.mjs`'s mirror (Story 1.9).

**Consumed-by:** Stories 5.8-5.13 -- each area's first confirmed write is the first event of its own
entity type, and 5.11 and 5.13 are the first namespace-scoped ones and the first that could publish
`deleted`; Story 5.11, whose navigation target is the Task schedule list with the task selected, uses
this story's "Open in <screen>" route builder; Story 7.4 and every later screen editor, whose Save
publishes on the same bus; any later write-tool story, which adds its entity type's id rule as one
pair in `EntityRef.IDRULES`.

**Ledger inbox (Rule 17).** DW-1364 is addressed by the first matrix row, the first acceptance
criterion and four tasks (`EntityRef.cls`, `screen-mirror.mjs`, `entity-ref.ts`,
`ui/tools/entity-ref.test.mjs`). None declined.

**Footprint.** One file outside both live epics' `paths_hint`: `ui/src/app/app.ts`, to mount the toast
region. Report it under `footprint_extensions:`. `ui/src/styles/**` is contended and is not edited.

## Verification

**Targeted -- run these inside the implement loop (Rule 29).**

- `(loop)` `uv run scripts/check-objectscript.py src/OcuPilot/Kernel/EntityRef.cls` -- expected: clean.
- `(loop)` `cd ui && npm run test:tools` -- expected: green, including the new `toasts.test.mjs` and
  the extended `entity-ref.test.mjs`, `change-bus.test.mjs`, `navigation.test.mjs`, `turn.test.mjs`,
  `screen-mirror.test.mjs`, and `refresh.test.mjs` unchanged and still green.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `toast-host.spec.ts`,
  `data-table.spec.ts`, `list-page.spec.ts` and `panel.spec.ts`.
- `(loop)` `node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.EntityRef` -- from
  `ui/`, **one class per call, landed in `%UnitTest_Result` before the next**, never two test calls in
  one message.
- `(loop)` the browser leg, bundle redeployed first or the spec reads the old bundle:

  ```bash
  cd ui && npm run build \
    && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ \
    && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci \
       node --test --test-concurrency=1 browser/change-highlight.browser-spec.mjs \
                                        browser/proposal-confirm.browser-spec.mjs
  ```

  -- expected: green, the budget assertion reporting its measured elapsed time.

**Full -- run these once, at the end of the implement stage, before `dev_complete` (Rule 29).**

- `(once, before dev_complete)` `cd ui && npm run build && npm test` -- the six prebuild checkers and
  both client tiers.
- `(once, before dev_complete)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  -- the whole browser suite.
- `(once, before dev_complete)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci` -- the full
  ObjectScript sweep.
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`
  -- expected: passes, executed-check count non-zero; read the skip lines, not the number (DW-1402).

**Rule 19 mutations** -- one per acceptance criterion, each applied, observed red, reverted, with
`git status --short` and `git diff --stat` unchanged afterwards; the ObjectScript ones run on
`ocupilot-ci`, never the shared dev instance (DW-1185), and a client mutation is only meaningful after
the bundle is rebuilt and redeployed. Record each as `mutation: <change> -> <test that reddened>`
beside the test as it is written.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
