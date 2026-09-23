---
title: 'Story 7.1: Enable, disable and delete a web application'
type: 'feature'
created: '2026-09-22'
status: 'done'
baseline_revision: 'ed1b4c4cf150a5ee14e703823b9a558b737840e5'
baseline_commit: 'ed1b4c4cf150a5ee14e703823b9a558b737840e5'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A screen action takes no per-target lock, so a row action and a confirm of a live proposal
      against the same application are serialized only by the vendor endpoint.
    evidence: |-
      AD-34's lock is the proposal store's atomic claim; a screen action claims nothing, so
      OcuPilot.Api.ScreenAction gates and writes with nothing in between and no lock around it.
      Reproduce by confirming a proposal against /csp/x while pressing its row's Disable: both
      reach Security.Applications.Modify, the later write wins, and the confirm's fingerprint
      re-read ran before the row action's. Bounded: every gate still runs on both callers and the
      last write is a complete body over a fresh read (AD-4), so neither can erase a field the
      other set from a stale read of its own - what is unordered is which of two reviewed writes
      lands last.
  - summary: >-
      The client explains the serving-path refusal for the three roster applications only, while
      the instance also protects the ones install recorded (a probe profile's).
    evidence: |-
      ui/src/app/core/self-protection.ts mirrors Install.Roster's three paths and is pinned to them
      by ui/tools/self-protection.test.mjs; Prohibited.ServesOcuPilot reads the roster AND
      Kernel.State.WebApp's records. On a throwaway carrying a probe profile the row menu offers
      the action and the route refuses it after the click, with the same published sentence. The
      client cannot read that table (AD-9), so closing it needs the instance to publish the set.
---

<intent-contract>

## Intent

**Problem:** The Web applications list offers no actions at all — `WebAppList.cls` declares
`primaryAction {"id": ""}` and `rowActions []` — while Story 5.8 already gave the agent
`webapp.list.update`, whose `PERMITTEDFIELDS` include `Enabled`. So the agent can already enable
and disable an application and a person cannot, nothing on either side can delete one, and the
prohibited-set arm that is supposed to protect OcuPilot's own applications refuses only a *change*:
`Prohibited.WebApplication` gates `SERVINGPATH` on `If pServes && +$Get(pChanged)`, and a bodyless
delete carries no changed fields, so it would pass straight through.

**Approach:** One operation, two callers. The executed write is lifted out of
`Kernel/Proposal/Confirm.Transition` into an operation both callers reach, and a user-originated
`POST /screens/:screen/action` is added beside the shipped `GET /screens/:screen/read`; the agent
path (mint → card → confirm) is unchanged and keeps the proposal, the fingerprint, the ledger row
and the agent marker. `WebAppList.cls` declares `enable`, `disable` and `delete` as row actions
with their self-protection rules; `OcuPilot.Screen.Tool.WebAppDelete` ships as an AD-51
action-style write; `AdminPort` gains `WebApp.App/DELETE`; the shell gains the typed-name confirm
dialog EXPERIENCE.md `:427` specifies; and every surface stops drawing a row action no handler is
registered for.

## Boundaries & Constraints

**Always:** The prohibited set stays in `Kernel/Proposal/Prohibited.cls` and is evaluated at the
write inside AD-34's single transition, whatever the caller (AD-10, AD-40) — the screen's row menu
*explains* the refusal and never enforces it. The delete tool declares `WRITETYPE = "DELETE"`,
`SENDSBODY = 0`, `CHANGEACTION = "deleted"`, `DESTRUCTIVE = 1` and a non-empty `FINGERPRINTSUBJECT`
drawn from fields `WebApp.App`'s `GET` actually answers, with identity excluded (AD-51 as amended
2026-09-22). Both callers publish exactly one AD-14 change event on the closed entity-type enum and
the screen re-fetches in place — no surface patches a row from a write's own answer. Enable and
disable reuse the shipped `webapp.list.update`; no second code path writes `Enabled`. Every write's
privilege pair set is `WebAppList`'s own declared set — `%Admin_Secure:USE` plus
`%DB_IRISSYS:READ` — never `:WRITE` (AD-8 as amended by DW-1208). A web application's reference key
is built through the identity layer's canonical form for the type — case-insensitive name, trailing
slash normalized (AD-13, DW-1359) — at mint, at confirm, at the row action and at the change event.

**Never:** No second predicate that decides what may be deleted lives in a screen, a descriptor or
the new route. No inert control: an action is declared only in the same pass that registers its
handler. No new user-facing string is authored in `ui/src/app/core/strings.ts` — every value there
must already be published by EXPERIENCE.md's Fixed strings table. No file under
`ui/src/app/areas/web-applications/**` is created or edited (Epic 8's exclusive footprint); the row
actions' handler is generic and lives in the shell. No entry in `src/OcuPilot/Port/AdminPort.cls`
that this story did not add is reordered, renamed or rewritten (shared-append). The agent marker is
emitted only on the agent path; a person's own row action is not an agent write (AD-15, AD-49's
converse) and carries no OcuPilot marker beside the vendor's own `%Security` event.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Row enable | `/csp/myapp` disabled, row selected, user holds `%Admin_Secure:USE` | `POST /screens/webapp.list/action` runs `enable`; one `(web-application, instance, /csp/myapp)` `updated` event; the list re-fetches in place preserving sort, filter, selection and scroll and highlights the row | No error expected |
| Row disable | same, application enabled | symmetric; no dialog, no proposal | No error expected |
| Row delete | `/csp/myapp`, user types `/csp/myapp` exactly in the typed-name field | the destructive button leaves `aria-disabled`; the write runs; one `deleted` event; the row disappears and focus moves to the next row | No error expected |
| Typed name mismatch | `/csp/MYAPP` typed, field blurred | `STRINGS.formTypedNameMismatch` shown, `aria-invalid` set, Enter does not submit, the destructive button stays `aria-disabled` | Client-side only; no request issued |
| Delete of an OcuPilot application, screen | `/api/ocupilot` selected | the row-menu and command-bar entries stay listed and arrow-reachable as non-selectable rows carrying the refusal reason inline after the label — never `disabled` items | The route refuses identically if called anyway: `PROHIBITED.SERVINGPATH`, one AD-12 envelope |
| Delete of an OcuPilot application, agent | `webapp.list.delete` against `/API/OcuPilot/` | refused at the write inside the transition; the canonical form is what `ServesOcuPilot` is asked about, so neither case nor a trailing slash evades it | `PROHIBITED.SERVINGPATH` with its written reason (AD-39) |
| Delete against a target removed since the proposal | proposal minted, application deleted by someone else | confirm's fresh re-read finds nothing; the fingerprint cannot match | Refused with the proposal's terminal state; nothing is written |
| Delete confirmed twice | two confirms of one proposal race | exactly one wins the atomic claim (AD-34) | The loser is refused with the terminal state, never retried |
| Row action with no registered handler | a descriptor declares an action the client registers nothing for | neither the command bar, the command box nor the row menu draws it | DW-389: no permanently disabled control is drawn |
| Removal rows on a non-error card | a `web-application` delete proposal renders | the residue sentence is absent; it appears only for `application-error` | DW-1480: gated on the write's entity type, not on row shape |

</intent-contract>

## Code Map

### Server — this story's own

- `src/OcuPilot/Screen/Tool/WebAppDelete.cls` — NEW. The AD-51 action-style delete tool,
  `TOOLNAME = "webapp.list.delete"`. Model it on `src/OcuPilot/Screen/Tool/ErrorDelete.cls`, which
  is the only shipped delete: `PORTCLASS` `:32`, `READTYPE` `:37`, `WRITETYPE = "DELETE"` `:40`,
  `SENDSBODY = 0` `:44`, `CHANGEACTION = "deleted"` `:49`, `DESTRUCTIVE = 1` `:53`,
  `PRECONDITIONFIELD` `:63`, `FINGERPRINTSUBJECT` `:69`, and the `Endpoint`/`IdArgument`/`IdParam`/
  `SettableFields`/`InputSchema`/`PrivilegePairs`/`StateDiff` overrides at `:73`–`:195`. Unlike
  `ErrorDelete` this tool keeps the base `PORTCLASS` (`AdminPort`) and its `Endpoint()` answers
  `"WebApp.App"`.
- `src/OcuPilot/Screen/Tool/Write.cls` — the base every parameter above is defaulted on: `KIND`
  `:30`, `DESTRUCTIVE` `:52`, `READTYPE` `:57`, `WRITETYPE` `:62`, `SENDSBODY` `:67`,
  `FINGERPRINTSUBJECT` `:97`, `PRECONDITIONFIELD` `:105`, `PORTCLASS` `:114`, `CHANGEACTION` `:124`,
  `READANSWERS` `:137`; `FieldRows` at `:343-392`; the accessors `ReadType`/`WriteType`/`PortClass`/
  `ChangeAction` at `:150-176`. Read-only here except as the new tool subclasses it.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` — Story 5.8's merge write, `TOOLNAME` `:34`,
  `PERMITTEDFIELDS` `:51` (already carries `Enabled`), `PrivilegePairs` `:100-107`. **Reused
  unchanged** as the operation behind row enable and disable.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` — `COVEREDTYPES` `:121` already names
  `web-application`; `Codes()` `:196-199`; the written reasons `:204-220` with `SERVINGPATH`'s at
  `:210`; `PermittedChangeFields` `:269`; the predicate `WebApplication(...)` `:439` whose first arm
  is `If pServes && +$Get(pChanged)` at `:447-450` — **the hole**; `ApplicationError` `:615-618` is
  the precedent for a bodyless-delete arm; `ServesOcuPilot` `:1338` reads `Install.Roster.Keys()`
  and falls back to `Kernel.State.WebApp`. `Prohibits()` `:334` is the one entry point.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` — `Confirm()` `:144`; `Transition` `:238-476` with the
  gate order that must be preserved: privilege pairs `:301`, prohibited set `:301-318`,
  `Restraint.Verdict` `:320-335`, `GuardedClaimAndClose` `:382-399` (AD-34), port call `:431`; the
  per-tool reads `PortClassOf` `:70-80`, `ToolReadType` `:697-707`, `ToolWriteType` `:709-721`,
  `ToolPortQuery` `:731-740`, `ToolChangeAction` `:746-755`, `ToolSendsBody` `:759-768`. **The
  operation to extract is this method's tail, from the prohibited check to the change event.**
- `src/OcuPilot/Kernel/Proposal/Mint.cls` — `Mint()` `:112`; `PortClassOf` `:61-71`; `ReadTypeOf`
  `:437-447`; `FingerprintSubjectOf` `:456-467`; the action-write branch `:169-192`. Read-only.
- `src/OcuPilot/Kernel/Proposal/Write.cls` — the claim gate, the `PROPOSAL.*` code roster,
  `ReasonFor` `:93-96`, `ProhibitedClass()` `:207-210`.
- `src/OcuPilot/Kernel/Restraint.cls` — `Verdict` `:~46`, the kill-switch / enforced-read-only
  verdict. This story's exclusive footprint. See Design Notes for whether the screen caller consults
  it.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` — `XData Declaration` `:39-87`: `archetype`
  `:45`, `sideBarPosition` `:45-46`, `privileges` `:50`, `entityType`/`scope` `:51,:54`, `id` `:56`,
  `primaryAction`/`rowActions` `:57-58` (**both empty — this story fills `rowActions`**),
  `fingerprintExcludes` `:61`, `classicPage` `:64`, `read` `:66-72`, `table` `:73-84`,
  `toolIdentifier` `:85` (`"webapp.list"`).
- `src/OcuPilot/Screen/Descriptor/AgentDefinitionList.cls` `:62-66` and
  `src/OcuPilot/Screen/Descriptor/AgentSwitches.cls` `:49-50` — the only two descriptors that
  already declare actions, and the grammar to copy. Every shipped `selfProtection` is `""`; this
  story is the first to carry a rule in one.
- `src/OcuPilot/Screen/Registry.cls` — `DECLARATIONKEYS` `:368` lists `primaryAction,rowActions`;
  `IsWriteCapable` `:1907-1919`; the exclusion/subject validator at `:2005`. **`selfProtection` has
  no validator and no consumer anywhere today.**
- `src/OcuPilot/Port/AdminPort.cls` — SHARED-APPEND. `TYPESUFFIXES` `:118`, `MUTATINGTYPES` `:166`
  (has `WebApp.App/PUT`, **no** `WebApp.App/DELETE`), `BODYLESSTYPES` `:182`, the `QUERYPAIRS`
  table `:~170-200`. The `:159-163` note that `DELETE` is "deliberately absent" is scoped to
  `Process`, not to `WebApp.App`.
- `src/OcuPilot/Install/Roster.cls` — `XData Manifest` `:105-150` (the three applications),
  `Keys()` `:200`, `Application()` `:223`. Read-only.
- `src/OcuPilot/Api/Router.cls` — `XData UrlMap` `:~90-140`; `GET /screens/:screen/read` at `:94`.
  The new action route goes beside it, under the REST route-ordering convention
  (`scripts/check-objectscript.py` enforces it structurally).
- `src/OcuPilot/Api/ScreenRead.cls` — the thin `Call=` target to mirror for the new handler.
- `src/OcuPilot/Install/Smoke.cls` — this story's exclusive footprint. `Run()` `:223`, `Note()`
  `:300`, `Render()` `:1467`, `WEBAPPLISTTOOL` `:43`, `WEBAPPUPDATETOOL` `:48`, `CheckAgentWrite`
  `:1224` and `RestoreWriteTarget` `:1397` — the existing `webapp.list.update` mint-and-confirm
  against `OcuPilot.Install.Fixture.#APPPATH`.

### Client

- `ui/src/app/shell/data-table.ts` — the row-overflow menu already exists: `menuGlyph` `:390`,
  `menuItems` `:622-624` built from `screen.rowActions`, dispatch `this.actions.run(...)`
  `:858-859`; `announceChanged()` `:975-997` with the DW-1423 call site at `:996`.
- `ui/src/app/shell/command-bar.ts` — `rowActions` getter `:504`, template loop `:168`. **Maps every
  declared entry with `ariaDisabled` and no handler check — DW-389's first surface.**
- `ui/src/app/core/screen-actions.ts` — `register`/`run`/`has`, `REFRESH_ACTION_ID` `:29`,
  `actionLabel(descriptor, actionId)` `:~47` over `DESCRIPTOR_ACTION_LABELS` and `ACTION_LABELS`.
  Its own header states the invariant this story must extend from the primary action to row
  actions: "The command bar and the command box offer a primary action only while `has` answers
  `true` … so neither draws a control nothing can act on."
- `ui/src/app/areas/agent/definition-actions.ts` — the handler-registration precedent
  (`register(...)` `:68-71`), and the reason a *generic* handler is right here: it is an area file,
  and this story may not create one.
- `ui/src/app/shell/dialog.ts` — the shell's one `role="dialog"`: focus trap, overlay stack,
  `dialogAction` slot. The typed-name dialog is built on it.
- `ui/src/app/shell/proposal-card.ts` — `removedCount` / `residueVisible` `:505-519` (DW-1480's
  gate), `residueCaption` `:522-524`, the render at `:140-141`, `destructive` `:559-568` whose
  comment records that the typed-name field was deferred.
- `ui/src/app/core/proposal-view.ts` — the card's view model; where `entityType` already travels.
- `ui/src/app/core/change-bus.ts` `:33-43` — `ChangeAction` and `CHANGE_ACTIONS`; `publish`
  `:133-158` refuses an unknown action.
- `ui/src/app/core/toasts.ts` — `changeSentenceTemplate` `:83-87` (the per-action selection that
  `announceChanged` does not do), `formatChangeAnnouncement` `:109-111`.
- `ui/src/app/core/strings.ts` — flat `STRINGS` object `:53`. Already present and reusable:
  `actionCancel` `:105`, `actionDelete` `:115`, `privilegeRequiresResource` `:230`,
  `privilegeSelectRowFirst` `:232`, `formTypedNameConfirm` `:240`, `formTypedNameMismatch` `:242`,
  `agentDefinitionEnable` `:498`, `agentDefinitionDisable` `:500`, `tableChangeCreated/Updated/
  Deleted` `:1276-1280`, `tableChangeAnnouncement` `:1286`, `proposalResidue` `:1314`.
- `ui/src/app/shell/list-page.ts` — the generic `ListPage`; the Web applications list has no area
  page of its own.

### Tests

- `src/OcuPilot/Test/ProhibitedRoute.cls` `:530`
  `TestNoDeleteVerbIsAdvertisedForAWebApplication` — **a deliberate tripwire this story trips.** It
  asserts over the wire that no write tool other than `webapp.list.update` is registered under
  `webapp.list`. Per `.claude/rules/objectscript-testing.md` it is replaced by the positive
  assertion in the same pass that ships the tool, not deleted.
- `src/OcuPilot/Test/SurfaceCoverage.cls` `:52`, `:106`, `:278` — the write-tool roster; the new
  tool needs its row, with the canonical name read from the instance rather than recalled.
- `src/OcuPilot/Test/Descriptor.cls` `:63`, `:92` — the `WebAppList` descriptor assertions; `:63` is
  where DW-1099's sweep belongs.
- `src/OcuPilot/Test/Prohibited.cls` `:24-26`, `ProhibitedByEffect.cls` `:30-32`,
  `ProhibitedFixture.cls` `:21` — the prohibited-set suites, all already seeded with
  `webapp.list.update`.
- `src/OcuPilot/Test/ProposalConfirm.cls` `:16`, `:83`; `ProposalRace`, `ProposalClose`,
  `ConfirmRoute`, `ToolWrite` `:17-19`, `ToolRoundTrip` `:30`, `AuditMarker` `:28`,
  `WriteExclusion` — the write-path suites.
- `ui/browser/web-applications.browser-spec.mjs` — read-only coverage today (AC1, AC3, AC5, AC6).
- `ui/browser/proposal-confirm.browser-spec.mjs` and `ui/browser/error-log-delete.browser-spec.mjs`
  — the two nearest write/delete browser precedents.
- `ui/tools/strings.test.mjs` — the Fixed-strings extractor `:44-66`, the completeness test, the
  **converse** test ("the string source holds nothing the documents do not authorize") and its exact
  key-count assertion, and the `/** EXPERIENCE.md:n */` line-anchor test `:719-764`.
- `ui/tools/citations.test.mjs` `:63-65` — bans a bare `EXPERIENCE.md:<n>` citation anywhere but
  `strings.ts`'s gated form.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- extract the executed write (prohibited set →
  restraint verdict → atomic claim → port call → change event) into one operation both callers
  reach, leaving `Transition` as the agent caller that adds the proposal, the fingerprint re-match,
  the ledger row and the agent marker -- so the two paths are two callers of one operation rather
  than two implementations.
- `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Api/ScreenAction.cls` (new) -- add
  `POST /screens/:screen/action` beside `GET /screens/:screen/read`, resolving the descriptor by
  `toolIdentifier`, the action by its declared id, and the target by the canonical form of the
  supplied id -- the screen's own path to the same operation, user-originated by construction.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- give `WebApplication` an arm that refuses a
  delete of a serving path independently of `pChanged`, keeping `SERVINGPATH` and its written
  reason -- `:447-450`'s `pServes && +$Get(pChanged)` cannot fire for a bodyless delete, which is
  the AD-10 hole this story opens if it is not closed first.
- `src/OcuPilot/Screen/Tool/WebAppDelete.cls` -- new AD-51 action-style write tool
  `webapp.list.delete` over `WebApp.App`, with a non-empty `FINGERPRINTSUBJECT` measured against the
  live `GET`'s answered keys and identity excluded -- so a delete is a narrower body, never a
  lighter path.
- `src/OcuPilot/Port/AdminPort.cls` -- APPEND `WebApp.App/DELETE` to `MUTATINGTYPES` and to
  `BODYLESSTYPES`; touch no entry this story did not add.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` -- declare `rowActions` `enable`, `disable`,
  `delete`, each with its `selfProtection` rule, in command-bar order with the destructive one last.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` -- validate `selfProtection`
  against a closed vocabulary in both, identically, so a rule neither side understands is refused at
  build rather than rendered as a word.
- `ui/src/app/shell/typed-name-dialog.ts` (new) -- the `typed-name-field` confirm dialog on
  `dialog.ts`: title verb + target, initial focus on the field, exact case-sensitive match,
  `STRINGS.formTypedNameMismatch` on blur with `aria-invalid`, Enter submitting only on a match, the
  destructive button `aria-disabled` until then, Escape and Cancel returning focus to the opener.
- `ui/src/app/shell/screen-action-handler.ts` (new) -- the generic descriptor-driven handler that
  registers every declared row action of every write-capable descriptor against
  `POST /screens/:screen/action`, opening the typed-name dialog first for a destructive one. It is
  generic rather than per-area because `ui/src/app/areas/web-applications/**` is Epic 8's exclusive
  footprint and because every later story in this epic needs the same mechanism.
- `ui/src/app/shell/command-bar.ts`, the command box, `ui/src/app/shell/data-table.ts` -- offer a
  row action only while `ScreenActions.has(descriptor, actionId)` answers true, exactly as the
  primary action already resolves (DW-389).
- DW-1423 is **not this story's work.** Its fix changes published copy against a stated rationale,
  which is the user's call, so it goes to the epic-close decision sheet and `announceChanged()` is
  left as it is. Do not touch it.
- `ui/src/app/shell/proposal-card.ts` -- gate `residueVisible` on the write's entity type rather
  than on `removedCount > 0` (DW-1480).
- `src/OcuPilot/Test/ProhibitedRoute.cls` -- replace
  `TestNoDeleteVerbIsAdvertisedForAWebApplication`'s negation with the positive roster assertion,
  reading the new tool's canonical name from the instance; prove the row load-bearing by removing it
  and watching that test redden alone.
- `src/OcuPilot/Test/Descriptor.cls` -- add one sweep over `Registry.Descriptors()` comparing every
  shipped descriptor's `read.filter`, `read.sort.fields` and per-column `kind` against a committed
  table (DW-1099). Equality with `read.fields` is NOT the invariant -- measured on this build,
  `DatabaseVolumeList` filters on two of its six fields, `ServiceList` filters on four and sorts on
  two, and `LogMessageViewer` sorts on two of the three it filters on. (`SystemUsage` filters on
  all eighteen; it is not the case.)
- `src/OcuPilot/Test/SurfaceCoverage.cls` -- add the `webapp.list.delete` roster row.
- `src/OcuPilot/Install/Smoke.cls` -- extend `CheckAgentWrite`, or add a sibling check, so the smoke
  exercises the row-action path against the demo fixture and restores it, as `RestoreWriteTarget`
  already does for the update.
- `ui/browser/web-applications-actions.browser-spec.mjs` (new) -- the story's own browser spec:
  enable and disable from the row menu and the command bar with the row updating in place, the
  typed-name delete, the mismatch message, and the OcuPilot-application refusal listed and
  arrow-reachable rather than `disabled`.

**Acceptance Criteria:**

- Given a web application the user may change, when `enable` or `disable` is run from the row menu
  or the command bar, then the write runs without a dialog and without a proposal, one AD-14
  `updated` event is published, and the list re-fetches in place preserving sort, filter, selection
  and scroll.
- Given a delete from either surface, when the dialog opens, then focus is on the typed-name field,
  the destructive button is `aria-disabled` and labeled with the verb and the target, a mismatched
  name on blur reads `STRINGS.formTypedNameMismatch` with `aria-invalid`, and only an exact,
  case-sensitive match releases the button and lets Enter submit.
- Given the target is one of the three applications `Install.Roster` declares, when a delete or a
  disable is attempted from the row menu, the command bar, the command box or
  `POST /screens/:screen/action`, then the instance refuses it with `PROHIBITED.SERVINGPATH` inside
  the atomic transition, and the surfaces list the action as a non-selectable row carrying the
  reason inline after the label rather than as a Material-disabled item.
- Given the same target named as `/API/OcuPilot/`, when the agent proposes `webapp.list.delete`,
  then the canonical form is what `ServesOcuPilot` is asked about and the refusal is identical
  (AD-13's per-type rule).
- Given a descriptor declares an action for which no handler is registered, when any of the three
  surfaces renders, then none of them draws that action (DW-389).
- Given a `web-application` delete proposal card, when it renders, then no residue sentence appears;
  given an `application-error` delete proposal card, the sentence appears unchanged (DW-1480).
- Integration AC (Rule 1): the agent, given `webapp.list.delete` against the demo fixture, mints a
  proposal whose card is destructive; a user confirm removes the application and
  `OcuPilot.Install.Smoke`'s check observes it gone and restores the fixture -- the consumer's own
  tier, not the tool's internal state.

**Open items on re-dispatch (2026-09-23, lead):**

- [x] [CI] `browser`, run 35802812010 on 1fd99da: `ui/browser/data-table.browser-spec.mjs` `not ok 42`
  (AC2, `:170`), `not ok 43` (AC3, `:286`) and `not ok 48` (row menu on the last visible row,
  `:553`) each throw `Cannot read properties of null (reading 'getBoundingClientRect')` -- in
  `:170`'s evaluate the null is the row's `.ocu-data-table-trigger` (inference: the harness declares
  row actions and registers no handler, so DW-389's rule now draws no trigger). Fix the cause, never
  the assertion; the three specs pin shipped Story 2.4 behavior.
- [x] [CI] `browser`, same run: `ui/browser/gate.browser-spec.mjs` `not ok 71` (`:411`), "the row
  menu offers "enable"", `false !== true` at `:446`. Confirm or refute that it shares the cause
  above, and fix it at the source.
- [x] [CI] Run the four regressed spec files plus the story's own browser specs locally against a
  **rebuilt and redeployed** bundle on `ocupilot-ci` before `dev_complete`, and record the result.
- [x] [CI] `instance`, same run: `OcuPilot.Test.Installer.TestASecondInstallGrantsNothingAndWritesNoSecondMarker`
  failed three asserts on the single grant marker (not attributed: this story does not touch
  `Installer.cls`). Run the class once in the full sweep; if it recurs, diagnose it; if it does not,
  record the non-recurrence in `## Auto Run Result`. Never call it a flake without evidence.
- [x] Finish the halted pass: run the two review layers, triage, finalize.

## Spec Change Log

- 2026-09-22, lead spec gate: the plan stage's three intent gaps resolved and `status` set
  `ready-for-dev`. (1) The self-protection refusal and the delete dialog's consequence body are
  now published rows in EXPERIENCE.md's Fixed strings table, added under Rule 5 tier-1 because
  FR-32 and `:131` already promise the explanation and only its wording was missing. Both
  `strings.ts` keys (`webAppServesOcuPilotRefusal`, `webAppDeleteConsequence`) are **already
  appended and green** -- consume them, do not re-author them. (2) DW-1423 routed to the epic-close decision sheet, removed from
  Tasks. (3) The seam is **AD-53**, written into the spine at the moment of decision: one
  operation, two callers; the screen caller mints no proposal and emits no agent marker; and
  `Restraint.Verdict` does **not** gate a person's own row action, which is published in FR-20
  ("All screens continue to work with the agent disabled") rather than newly decided here.

- 2026-09-23, lead re-open after the implement HALT: the empty-state invitation is ratified by the
  orchestrator as "create a web application for a REST API" (the value Epic 8's Story 8.1 gives the
  same `webAppListEmptyAgent` key), applied by the lead to `EXPERIENCE.md:397` and `strings.ts:1332`;
  `status` reset to `in-progress`. CI run 35802812010 was red; its items are appended above.

## Review Triage Log

### 2026-09-22 — Review pass

- verdicts: 26 findings — high 1, medium 9, low 7, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` P1 DW-389's "no handler, not drawn" has no negative test on any surface (every fixture registers its actions) — fixed: one negative case per surface spec, each beside a registered action on the same screen.
  - `[high]` `[patch]` P2 AC7 unmet: nothing mints and confirms `webapp.list.delete`; `Smoke` drives only the screen's enable/disable — fixed: `Smoke.CheckAgentDelete` (`agentdelete`) mints through the tool, checks the card row destructive, confirms, observes the fixture gone and restores it through `Fixture.Create`; smoke 49/49 twice on `ocupilot-ci`.
  - `[medium]` `[patch]` P3 the command bar's self-protection reason on a protected selected row is untested — fixed: the mirror case, both a protected and an ordinary row.
  - `[medium]` `[patch]` P4 the screen route's `AUTH.NOPRIVILEGE` refusal (with `failedPair`) is untested — fixed: `TestAnAccountShortOfTheScreenPairIsRefusedTheRowActionNamingIt`; it exposed that `ScreenAction.Run` read before checking pairs (403 `PORT.ACCESSDENIED`, no pair named), so the pair check now precedes the fresh read, as at a confirm.
  - `[medium]` `[patch]` P5 `TestTheAgentsDeleteOfOcuPilotsOwnApplicationIsRefusedOverTheWire` skips both legs silently when `SeedDelete` answers `""` — fixed: the key is asserted non-empty.
  - `[low]` `[patch]` P6 `RefusalCopy`'s documented mutation changes both sides of its comparison and cannot redden it — fixed: the doc names `ReasonFor` returning a literal, observed red.
  - `[medium]` `[patch]` P7 the instance-side `Registry.ActionProblem` has no test once the fixtures conform — fixed: `TestTheActionValidatorRefusesWhatNoSurfaceCanRun`.
  - `[low]` `[patch]` P8 AC1, AC2, AC3's three surfaces, AC4's canonical spelling, AC5 and AC7 carry no `mutation:` line in `## Verification` — fixed: lines recorded in `## Verification`.
  - `[medium]` `[patch]` P9 AC1's sort preservation and row highlight are asserted nowhere (only filter and selection) — fixed: AC1 sets a descending sort and asserts it survives both writes, and asserts the row's changed mark; scroll not asserted (one row).
  - `[low]` `[patch]` P10 `Smoke.CheckScreenAction` was inserted between `CheckAgentWrite`'s doc comment and its method — fixed.
  - `[low]` `[patch]` P11 a doc line in `ProhibitedRoute.cls` is duplicated and glued onto itself ("...DW-1208/// <p>Story 5.8's residual...") — fixed.
  - `[low]` `[reject]` the spec's Verification says "three fixture descriptors" and lists four — the fix edits this build's spec.
  - `[false]` `[reject]` the DW-1099 sweep in `Test/Descriptor.cls` is unrelated scope — it is a Tasks item of this spec.
  - `[false]` `[reject]` the client's `selfProtectionReason` is a second predicate deciding what may be deleted — it decides only what a surface draws as non-selectable (the matrix's own word); its paths are pinned to the install roster, a subset of what `ServesOcuPilot` protects, and the route refuses identically.
  - `[low]` `[patch]` P12 `ScreenAction.Handle`'s comment says the canonical key "takes one lock"; no lock is taken — fixed.
  - `[false]` `[reject]` the screen caller runs no AD-34 transition — the Always constraint's content is that the set is evaluated at the write whatever the caller, which `Run` does with nothing between gate and write; a screen action has no token to claim, and the residual race is frontmatter `deferred` item 1.
  - `[false]` `[reject]` `webAppListEmptyAgent` and its EXPERIENCE.md row are new copy — ratified by the orchestrator (Spec Change Log, 2026-09-23).
  - `[false]` `[reject]` `AdminPort` changes beyond the two roster appends (`ImplementsRead`'s `$Case`, a count in a comment) — forced on the story's own path (501 without it); Epic 8's pushed `AdminPort` touches neither line; listed under `footprint_extensions`.
  - `[false]` `[reject]` the shared `delete` label relabels other screens — it replaces a raw id with published copy; Switches keeps its own words (`screen-actions.test.mjs`).
  - `[false]` `[reject]` fixture descriptors lost their prose `selfProtection` — required by the closed vocabulary; test fixtures only.
  - `[false]` `[reject]` `ProhibitedByEffect`'s serving-path case moved 409 to 403 — the consequence AD-53's arm states.
  - `[medium]` `[patch]` P13 matrix row 3: nothing moves focus to the next row after a delete (the dialog returns focus to an opener that is gone) — fixed: `ListPage` hands focus to the grid before a confirmed delete closes the dialog, and `dialog.ts` leaves focus where its parent placed it; pinned in `list-page.spec.ts` and the browser AC2 (the filtered view empties, so focus lands on the filter field by the table's own rule).
  - `[medium]` `[patch]` P14 matrix row 7: no test confirms a delete whose target was removed after the proposal — fixed: `TestADeleteWhoseTargetWasRemovedIsRefusedAndWritesNothing`.
  - `[false]` `[reject]` matrix row 8 relies on generic tests — `GuardedClaimAndClose` reads no tool, so `ProposalRace` is the covering test for every tool's double confirm.
  - `[low]` `[patch]` duplicate of P11 (intent layer) — fixed with P11.
  - `[medium]` `[patch]` P15 AC4's "canonical form at mint" is not exercised: the agent legs seed a row rather than mint one — fixed: `TestTheAgentsDeleteMintedUnderAnotherSpellingIsStoredCanonicalAndRefused`.

## Design Notes

**Governing ADs (Rule 6).** AD-5 (the descriptor declares row actions and their self-protection
rules; a descriptor is write-capable when it declares one), AD-6 (server-minted, fingerprinted,
single-use proposal; closed confirm channel), AD-8 (privilege pairs; an administrative resource at
`USE`, never `WRITE` -- applied, not re-derived), AD-10 (the prohibited set has one home, is defined
by effect, and refuses whatever the caller), AD-12/AD-39 (one envelope, two renderings; the refusal
reason is server-authored), AD-13 (scoped identity; the web-application canonical form already
exists), AD-14 (one change event; screens re-fetch, never patch), AD-15 (the agent marker, on the
agent path only), AD-29 (the port's own gate), AD-34 (one atomic transition), AD-36 (one declared
read shared by screen and tool), AD-40 (confirm is user-originated; every gate is on the write),
AD-43 (the proposal-open/closed pause; `WebAppList` declares `refreshes: false`, so this screen has
no chip and this story gives it none), AD-51 (action-style write: declared request type, no body,
declared fingerprint subject, identity excluded), AD-52 (the tool declares its port; this one keeps
`AdminPort`). AD-3 governs the delete tool's field list, which is empty by derivation.

**Consumes:** Story 5.1 (mint), 5.2 (the proposal card), 5.3 (confirm and the single atomic
transition), 5.5 (the prohibited set), 5.6 (the agent marker), 5.7 (the change-event bus and the
data table's announcement), 5.8 (`webapp.list.update`, reused unchanged for enable and disable),
2.4 (`ListPage`), 3.7 (`ScreenActions`), 6.x (the shipped descriptors DW-1099's sweep covers).

**Consumed-by:** Stories 7.2, 7.3, 7.4, 7.5, 7.6, 7.8, 7.10 and 7.11 all reuse the screen-action
route, the generic row-action handler, the typed-name dialog and the `selfProtection` vocabulary
this story introduces; Epic 8's create forms and Epic 9's editors reuse the screen-write seam for
their Saves; Epic 12's five OAuth editors reuse it for their deletes.

**Why the handler is generic and lives in the shell.** `ui/src/app/areas/web-applications/**` is
Epic 8's exclusive footprint, and the Web applications list has no area page of its own -- it is
served entirely by `ListPage` over the descriptor. A per-area `webapp-actions.ts` on the
`definition-actions.ts` model would therefore have to be created in another epic's tree, and Epic
8's create flow would create the same file. A generic handler avoids the collision and is the
better design anyway: AD-5 makes a row action a declaration, so the thing that runs it should be
declaration-driven too, and eight later stories in this epic need exactly it.

**Coordination risk (Rule 11, named rather than assumed).** Four files this story must edit are
shared-create with Epic 8, which runs concurrently and whose worktree this stage cannot read. As of
this branch's HEAD none was last touched by Epic 8 -- `WebAppList.cls` by Story 5.2 (`a8be036`),
`command-bar.ts` by Story 6.11 (`52c14c8`), `data-table.ts` by a 5.7 review fix (`fee1508`),
`screen-actions.ts` by Story 3.7 (`545ce13`) -- but Epic 8's create flow will want `WebAppList`'s
`primaryAction` and the same three client files. `AdminPort.cls` and `strings.ts` are
shared-append and are treated as such. If any of these has moved under Epic 8 by the time this story
implements, that is a clarification to the lead, not an edit.

**Ledger inbox (Rule 17).**

- DW-389 -- addressed: all three surfaces gate a row action on a registered handler, as the primary
  action already does. Covered by the fifth AC and by the new browser spec.
- DW-1099 -- addressed: one sweep over `Registry.Descriptors()` against a committed table in
  `Test/Descriptor.cls`, with `DatabaseVolumeList`, `ServiceList` and `LogMessageViewer` as the
  measured cases that prove equality with `read.fields` is not the invariant.
- DW-1480 -- addressed: `residueVisible` is gated on the write's entity type. This story is the
  first that would otherwise render "Removes exactly the 1 errors listed here" about a web
  application.
- DW-1423 -- **raised, not chosen.** See the intent gap below; the code half is written and blocked
  on the copy.
- Declined DW-1001: the fix is a per-criterion description mechanism for *derived read* tools, and
  this story ships no read tool and adds no read criterion -- it belongs with the first later story
  that amends a derived read's criteria.
- Declined DW-1013: same mechanism and same reason as DW-1001; the two were routed as one cluster
  and should move together.
- Declined DW-1136: the fix is inside `AdminPort.ForgetTask`'s body, and `AdminPort.cls` is
  shared-append for this epic -- rewriting a method this story did not add is a contended-path
  clarification, not an append.
- Declined DW-1137: same file and same reason, and its own trailer records fix-risk `high` because
  resolving the resource at call time adds a `%SYS` switch to the async path.

**Risks the implement stage must settle with a measurement, not a recollection.** The delete tool's
`FINGERPRINTSUBJECT` must name fields `WebApp.App`'s `GET` actually answers -- read them from the
instance, never from the `LIST` field set or from this spec -- and AD-51 refuses an empty subject
while the builder refuses a name neither the write tool nor the read declares. Whether
`Restraint.Verdict` (the kill switch and enforced read-only) gates the *screen's* caller is part of
the seam decision below: AD-30 binds the turn job, every write tool and the confirm path, which are
the agent's, and FR-19/FR-20 are agent switches -- so the recommendation is that a person's own row
action is not gated by them, and that recommendation is the lead's to ratify, not the implementer's
to assume.

## Verification

**Mutations applied and observed (Rule 19).** Each was applied, the named run went red, the
mutation was reverted and the run went green again; the tree is byte-identical to before.

- AD-53's arm (`Prohibited.WebApplication`): restoring `pServes && +$Get(pChanged)` reddened three
  of `OcuPilot.Test.ProhibitedRoute`'s seventeen -- the screen's refusal leg, the agent's, and the
  row-action leg whose delete then reached the vendor. Applied, run 6478 red; reverted, run 6479
  green; the container was asked what it had compiled on both sides of the revert, and the file is
  byte-identical to before.
- DW-389 (all three surfaces): the change itself falsified the old behavior -- requiring a
  registered handler reddened 16 existing assertions in `command-bar.spec.ts`,
  `command-box.spec.ts` and `data-table.spec.ts`, each of which drew an action nothing could run.
- DW-1480 (`residueVisible`): drop the `targetType` test -> `proposal-card.spec.ts`'s new
  web-application leg goes red, the card reading "Removes exactly the 4 errors listed here" about a
  web application.
- The `selfProtection` vocabulary: three fixture descriptors (`Screen/Composite`, `Screen/Gated`,
  `Screen/Refreshing`, `Screen/Multi`) declared free text and were refused at registration by
  `Registry.ActionProblem` the moment it shipped, which is the validator answering over real
  declarations rather than over a case written for it.
- mutation: table harness registers no handler for its declared `disable` -> `data-table.browser-spec.mjs`
  AC2, AC3 and the last-visible-row menu test go red on the rebuilt harness (the CI failures,
  reproduced locally); registering it -> 9 of 9 green.
- mutation: `definition-actions.ts` stops registering `enable` -> `gate.browser-spec.mjs` AC6 red on a
  rebuilt and redeployed bundle ("the row menu offers "Enable""); reverted, file hash identical,
  rebuilt and redeployed -> 5 of 5 green.
- mutation (AC1): drop `markChanged` from `RefreshService.onBusEvent`, rebuilt and redeployed ->
  `web-applications-actions.browser-spec.mjs` AC1 red ("the written row is marked changed").
- mutation (AC2): `TypedNameDialog.matches` compares through `toLowerCase()` ->
  `typed-name-dialog.spec.ts` "keeps the destructive button aria-disabled ... until the name
  matches exactly" red. Focus after the delete: drop `(focusFilter)` from `ListPage`'s template,
  rebuilt and redeployed -> browser AC2 red; drop `focusGrid()` from `onConfirmDestructive` ->
  `list-page.spec.ts` "a confirmed delete leaves focus on the row that took its place" red.
- mutation (AC3, row menu): `DataTable.menuItems`' reason forced to `''` -> `data-table.spec.ts`
  "AD-53: a self-protected row's menu entry stays listed ..." red. Command bar: its
  `selfProtectionReason(...)` answers `''` -> `command-bar.spec.ts` "AD-53: with a self-protected
  row selected ..." red. Route, short a pair: delete the pair check ahead of the fresh read in
  `ScreenAction.Run` -> `ProhibitedRoute.TestAnAccountShortOfTheScreenPairIsRefusedTheRowActionNamingIt` red.
- mutation (AC4): `Mint.Mint` concatenates the supplied id instead of calling `EntityRef.Key` ->
  `ProhibitedRoute.TestTheAgentsDeleteMintedUnderAnotherSpellingIsStoredCanonicalAndRefused` red
  on the stored-ref asserts.
- mutation (AC5): drop the `actions.has(...)` filter on each surface in turn -> the matching
  "DW-389: a declared row action with no registered handler ..." case in `command-bar.spec.ts`,
  `command-box.spec.ts` and `data-table.spec.ts` red, one each.
- mutation (AC7): `WebAppDelete.DESTRUCTIVE` = 0 -> smoke `agentdelete` fail; drop the
  `Fixture.Create` restore -> smoke `agentdelete` fail ("/csp/myapp was not put back").
- mutation (matrix row 7): `Confirm.FingerprintMatches` matches on a failed re-read ->
  `ProhibitedRoute.TestADeleteWhoseTargetWasRemovedIsRefusedAndWritesNothing` red.
- mutation (the instance validator): drop `ActionProblem`'s duplicate-id refusal ->
  `Descriptor.TestTheActionValidatorRefusesWhatNoSurfaceCanRun` red; `Prohibited.ReasonFor`
  returns a literal for `SERVINGPATH` -> `RefusalCopy` red.
- `WebApp.App/DELETE`: the port answered 501 `PORT.NOTIMPLEMENTED` until
  `AdminPort.ImplementsRead` learnt the vendor's `RunDelete` -- observed red on the wire, not
  reasoned about.

**Targeted, inside the implement loop (loop):**

- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ProhibitedRoute` --
  expected: green, one class at a time, never two runner calls in one message.
- the same, one call each and one at a time, for `OcuPilot.Test.Prohibited`,
  `OcuPilot.Test.ProhibitedByEffect`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.SurfaceCoverage`,
  `OcuPilot.Test.ProposalConfirm`, `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.ToolRoundTrip`.
- `cd ui && npm run test:tools` -- expected: green, including `strings.test.mjs`,
  `citations.test.mjs` and `screen-mirror`'s checker.
- `cd ui && npm run test:components` -- expected: green, including `command-bar.spec.ts`,
  `data-table.spec.ts`, `list-page.spec.ts` and the new dialog's spec.
- `cd ui && npm run build` then
  `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/web-applications-actions.browser-spec.mjs browser/web-applications.browser-spec.mjs browser/proposal-confirm.browser-spec.mjs`
  -- expected: green. The bundle must be rebuilt and redeployed before any browser result is read.
- `uv run scripts/check-objectscript.py` on the changed paths -- expected: clean, including the
  REST route-ordering rules over the new `UrlMap` entry.
- Rule 19: one recorded `mutation:` line per AC, next to its pinning test.

**Once, before `dev_complete`:**

- the full ObjectScript sweep, per class, one call at a time, totals verified against
  `%UnitTest_Result` with the numeric-run-index probe -- expected: green.
- `bash scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` -- expected: every
  check executed and passing; zero executed checks is a failure.
- The full browser suite is **not** run locally (Rule 29): CI runs it on a fresh throwaway, and the
  local suite is non-idempotent on a reused container (DW-1447).

## Auto Run Result

Status: done
Blocking condition: none

This pass (re-dispatch after the phrase HALT): closed the CI items, ran the two review layers over
the whole story (`ed1b4c4..` plus the tree), and patched every finding it kept.

- CI `browser`: `data-table` 42/43/48 were the table harness declaring a row action with no
  registered handler (the inference held); the harness now registers one. `gate` 71 had another
  cause: the row menu now shows the published label ("Enable"), not the id; the spec derives it via
  `actionLabel`. Assertions unchanged.
- CI `instance`: `OcuPilot.Test.Installer` did not recur: 27/0 alone (run 6660) and 27/0 inside the
  full sweep (run 6739), both on the reused `ocupilot-ci`, not a fresh throwaway. Not diagnosed
  further.
- Review: 26 findings (high 1, medium 9, low 7, false 9); 16 patched, 1 rejected low, 9 false, 0
  deferred; rows in `## Review Triage Log`. Patched by verdict: high 1 (AC7's agent delete was
  never minted or confirmed; `Smoke.CheckAgentDelete` now does), medium 9, low 6. One patch changed
  behavior: `ScreenAction.Run` now checks the declared pairs before its fresh read, so an account
  short of `%Admin_Secure:USE` gets `AUTH.NOPRIVILEGE` with `failedPair`, not `PORT.ACCESSDENIED`
  (AD-8). The other code patch: after a confirmed delete, focus goes to the grid (`ListPage`, `dialog.ts`,
  `DataTable.focusGrid`).
- Files this pass: `Api/ScreenAction.cls`, `Install/Smoke.cls`, `Test/ProhibitedRoute.cls` (four
  methods, a header count), `Test/Descriptor.cls`, `Test/RefusalCopy.cls`; `shell/{list-page,dialog,
  data-table}.ts` and specs for command bar, command box, data table and list page;
  `browser/web-applications-actions.browser-spec.mjs`, `browser/gate.browser-spec.mjs`,
  `testing/table-harness/main.ts`.
- Tiers run: `npm run test:tools` 1,322/0; `npm run test:components` 839/0 (56 files); browser
  (rebuilt and redeployed on `ocupilot-ci`): `web-applications-actions`, `web-applications`,
  `proposal-confirm`, `gate`, `data-table` 23/0; full browser suite NOT run (Rule 29, CI's);
  full ObjectScript sweep on `ocupilot-ci` 179 classes, 1,606 tests, 0 failed, 0 overlaps, with
  `AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume` refused in `OnBeforeAllTests`
  (the container predates their arming variables; CI's fresh throwaway arms them);
  `smoke.sh` 49/49 twice on `ocupilot-ci`, 41/41 on `ocupilot` (demo checks skip);
  `check-objectscript` 0 problems over 616 files; `lint-docs` clean.
- footprint_extensions: `src/OcuPilot/Test/ProhibitedRoute.cls` (contended) -- new methods after
  `SeedDelete`, one line in a 7.1 method, a duplicated doc line removed, the header's method count;
  Epic 8's `REVIEWEDWRITES` and its rewrite of `TestNoDeleteVerbIsAdvertisedForAWebApplication`
  untouched, but 7.1 replaced that same method with
  `TestTheWebApplicationWriteVerbsAreTheTwoThisScreenDeclares`, and Epic 8's version asserts no
  delete verb exists: the merge gate must reconcile them (a three-verb roster). Earlier in the story,
  before the contended ruling: `Kernel/Proposal/{Confirm,Prohibited}.cls` and the new
  `Operation.cls`, `Screen/Tool/Write.cls`, `Screen/Descriptor/WebAppList.cls`, `Api/Router.cls`,
  `Test/{SurfaceCoverage,EndpointCoverage,ToolRoundTrip,ReadTool,Prohibited}.cls`, and
  `Port/AdminPort.cls` beyond its two appends (`ImplementsRead`'s `$Case`, a doc count); Epic 8's
  pushed `AdminPort` changes neither line.
- Follow-up review recommended: true. A high was patched and the patch has had no review: the
  `agentdelete` smoke leg deletes and recreates the demo fixture through `Fixture.Create`, which
  also seeds one application-error entry per smoke run.
- Residual risks: the two frontmatter `deferred` items (no per-target lock on a screen action; the
  client names three protected paths while the instance also protects install-recorded ones).
