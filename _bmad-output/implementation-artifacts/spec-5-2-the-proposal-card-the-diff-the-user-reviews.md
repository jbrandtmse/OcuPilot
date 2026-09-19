---
title: 'Story 5.2: The proposal card - the diff the user reviews'
type: 'feature'
created: '2026-09-19'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 5.1 mints proposals on the instance and publishes them on the progress poll, but nothing renders one. `shell/proposal-card.ts` shows a static example with no countdown, no buttons, no terminal states and no masked field; `core/turn.ts` discards a restored turn's proposals outright, so a browser reload loses the card entirely (DW-1213).

**Approach:** Make the card the live surface the wire already feeds: map `TurnProposal` onto `ProposalCardView`, add the countdown, the unchanged-fields disclosure, the masked secret field, the footer with Confirm and Cancel, and every terminal status line; stack cards in the transcript with Send dropped to secondary; and carry a turn's proposals on the conversation read so a restored transcript renders them restrained and expired with Re-propose instead of dropping them.

## Boundaries & Constraints

**Always:**

- Every user-visible string comes from `core/strings.ts` and is present in EXPERIENCE.md's Fixed strings table, which is canonical over DESIGN.md and over every inline quotation (EXPERIENCE.md:250). Design tokens only; no hardcoded color.
- `core/` imports no `@angular/core`; the view mapper, the countdown formatter and the clock live there as plain functions with an injected `now`, and the component mirrors them into signals (AD-19).
- The instance owns the diff. The card renders `changed[]`, `unchangedCount`, `rationale`, `expectedImpact` and `reverse` exactly as the wire sends them, through `{{ }}` interpolation only, never markup, and the agent's two blocks carry their headings and the agent tint so the model's words are always marked as the model's (AD-11, AD-33).
- A restored card is shown expired, never live, and never arms the auto-refresh pause. Terminal state on restore is decided client-side from the restore path, never from the wire's `state`, which is `"live"` on every row until Story 5.3 (DW-1209).
- A terminal transition replaces the buttons with a status line that takes focus and is announced; buttons going away are `aria-disabled` for the transition, never removed while focused (EXPERIENCE.md:660).
- The restrained treatment is by role at full opacity, never opacity - `--ocu-restrained` / `--ocu-restrained-container` - so the diff stays readable at AA (DESIGN.md:857).
- The countdown is announced once, at 1:00, and is otherwise not a live region.
- One decision at a time: cards stack in order, each with its own Confirm and Cancel, and there is no "Confirm all".

**Never:**

- No confirm request, no cancel request, no atomic transition, no fingerprint re-read, no audit marker - all Story 5.3's and 5.6's. Confirm and Cancel are rendered with their full focus and transition contract; Cancel's transition is client-side and Confirm's request is the seam 5.3 fills. This is a staged affordance, not a defect.
- No screen highlight and no change event on confirm (Story 5.7). No change to `core/change-bus.ts` or `core/refresh.ts`: the AD-43 pause is already built and this story must leave it green.
- Never store a proposal's diff or payload in browser storage. The instance is the single source; a restored card reads the same `Propose.GuardedRowsForTurn` projection the poll reads.
- Never write a literal default for a proposal field in a shipped `.ts` - `ui/tools/proposal.test.mjs:336` scans for `before|after|unchangedCount|rationale|expectedImpact|reverse|fingerprint` followed by a literal and fails the gate. Map from fields only.
- Never touch a contended path: `ui/src/app/shell/context-chip.ts`, `ui/tools/strings.test.mjs`, `ui/browser/definitions.browser-spec.mjs`, `src/OcuPilot/Api/Error.cls`, `src/OcuPilot/Api/Definitions.cls`, `src/OcuPilot/Screen/Tool/Registry.cls`, `README.md`. No new error slug is available.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live card | a poll's `proposals[0]`, `state: "live"`, `expiresAt` 9m59s ahead | one `app-proposal-card`: title `Proposal · Web application /csp/myapp`, two diff rows, `38 unchanged fields` closed, both agent blocks, the Reverse line, `Expires in 9:59`, footer `Runs as _SYSTEM, with your privileges.` + Confirm + Cancel + `Confirm here; sending a message cancels this proposal` | No error expected |
| Countdown crosses 1:00 | `expiresAt` 60s ahead | the caption takes `--ocu-warning` and holds it to `0:00`; the announcement `One minute left to confirm` is emitted exactly once | No error expected |
| Countdown reaches 0:00 | `expiresAt` in the past | restrained card, buttons replaced by `Expired` which takes focus, `Re-propose` offered | No error expected |
| `expiresAt` is 0 | wire timestamp unparseable, `turn.ts:315` yields `0` | the countdown renders no time rather than 1970; the card stays live until the poll closes it | Treated as unknown, never as expired |
| Delete proposal | `changed[]` rows whose `after` is the removed marker | `field · value → (removed)`, spoken `<field>: <value>, removed`, and no Reverse line | No error expected |
| Secret field | the target screen's mirror record declares a non-empty `secretArguments` | one masked field per declared name, required before Confirm; its diff row reads the eight-bullet mask on both sides | Confirm is `aria-disabled` until every masked field is filled |
| Auditing-disabling proposal | the mint's kernel predicate set the audit warning | the warning `Agent writes will no longer be marked in the audit database.` inside the card, above the footer | No error expected |
| Several proposals | `proposals[]` of length 3 | three cards in wire order, each with its own Confirm and Cancel; no batch control anywhere in the panel | No error expected |
| A card is live | any live proposal in the current turn | Send renders `ocu-button-secondary`, so Confirm is the view's only filled button; the accompanying reply ends `Press Confirm on the card to apply it.` | No error expected |
| A typed message | the user sends while a card is live | every live card takes `Canceled — by your message`, restrained, focus moved from any button that held it | No error expected |
| New conversation / Stop | `newConversation()` / `stop()` | New conversation cancels every live card as `Canceled — by you`; Stop cancels nothing and leaves every card live | No error expected |
| Reload mid-window (DW-1213) | reload 1 minute after a mint; the row is unburned and unexpired on the instance | the conversation read carries the turn's proposals; each renders restrained with `Expired` and `Re-propose`, and **no** `proposal-open` is published, so auto-refresh is not paused | A proposal store that cannot be read degrades to no cards, never a failed conversation read |
| Reload after retention | reload more than `RETENTIONSECONDS` after the turn | no cards on the restored turn, and the transcript is otherwise intact | No error expected |
| Restrained card contrast | an expired or canceled card | title, labels and diff values in `--ocu-restrained`, body in `--ocu-on-surface-variant`, the agent blocks unchanged, opacity 1 everywhere | No error expected |

</intent-contract>

## Code Map

Client, the story's center:

- `ui/src/app/shell/proposal-card.ts` -- the component to grow. Today: `selector: 'app-proposal-card'`, one input `view = input.required<ProposalCardView>()` (:88), paren-free protected getters (:100-128, the `client-lint.mjs` `@if` quirk is documented at :33-35), and two `ng-content` slots -- `[card-countdown]` in the header (:43) and `[card-footer]` as `<article>`'s last child (:83). It renders no countdown, no control, no status line, no masked field; `proposal-card.spec.ts:133-143` asserts zero focusable nodes and no `Expires in` text, so those two assertions change with the story.
- `ui/src/app/shell/example-proposal.ts` -- `ProposalDiffRow` (:20-24), `ProposalCardView` (:27-41), `formatProposalTitle` (:54), `formatUnchangedCaption` (:66), `EXAMPLE_PROPOSAL` (:78-89, `entityType: 'Web application'`). `ui/tools/example-proposal.test.mjs:153` pins `Object.keys(EXAMPLE_PROPOSAL).sort()`, so the example's key set must not change; adding an optional field to the interface is free.
- `ui/src/app/core/turn.ts` -- `TurnProposal` (:139-150, the ten wire fields), `parseProposal` (:309-328, `expiresAt` via `Date.parse` to epoch ms, `0` when unparseable), `PROPOSAL_LIVE_STATE` (:114), `pollOnce`'s merge and publish (:851-858), `publishProposals` (:880-909, skips `state !== 'live'`), `TurnEntry.proposals` (:175-177 -- **the false-premise comment DW-1213 names**), `restore()` (:556-588) and `parseRestoredEntry` (:373-389, `proposals: []` at :386).
- `ui/src/app/shell/panel.ts` -- banner block (:166-202, the reserved `data-slot="not-marked"` at :179), transcript `role="log"` (:251), the unconfigured example arm (:252-265, the only current card call site), the configured turn loop (:266-310) and `PanelTurnView` (built :633-660) which carries no proposals yet, the composer (:331-354) and Send (:345-353, `sendLabel` :611-613, `sendAriaDisabled` :619-623 -- **Send has one variant today; the secondary variant is unbuilt**).
- `ui/src/app/shell/tool-call-card.ts` -- the disclosure idiom to copy: `manualExpanded` signal over a status default (:76, :105-110), `[attr.aria-expanded]`, and the no-button restrained arm for a stopped step (:31-34).
- `ui/src/app/core/strings.ts` -- **every proposal string already ships and thirteen are referenced by nothing**: `proposalCardTitle` (:528), `proposalDiffWas`/`Now` (:530-532), `proposalUnchangedFieldsDisclosure` (:163), `proposalRationaleHeading`/`ExpectedImpactHeading`/`ReverseLabel` (:133-137), `proposalCountdownLabel`/`Tooltip`/`Announcement` (:139-143), `proposalFooterRunsAs`/`ConfirmHint` (:145-147), `proposalConfirmSentence` (:149), the six `proposalStatus*` (:151-161), `proposalTargetChanged` (:67), `actionConfirm`/`Cancel`/`Repropose` (:101-121). Shared-append: add only, never reorder or reword.
- `ui/src/app/core/screens.generated.ts` -- `ScreenDeclaration` already carries `entityType` (:338) and `secretArguments` (:345), so the masked field needs no wire change; `labelKey` (:328) is the plural screen label, which is why the singular entity noun is a new declaration.
- `ui/src/styles/_components.scss` -- the card's section is `:4057-4191`, already headed "reused live by Story 5.2": `.ocu-proposal-card` (:4064, its 4px `--ocu-agent-accent` bar :4071), `-header` (:4077), `-title` (:4086), `.ocu-diff-*` (:4100-4145), `-unchanged` (:4147), `-agent` (:4159-4178), `-reverse` (:4180-4190). Nothing named countdown, footer or status exists. Restrained precedents: `.ocu-banner-restrained` (:375), `.ocu-tool-call-card-stopped` (:4044). Tokens in `ui/src/styles/_tokens.scss:110-115`.
- `ui/src/app/core/{change-bus,refresh}.ts` -- read-only here. `PROPOSAL_EXPIRY_MS` (`change-bus.ts:33`), `publish`'s `proposalId` refusal (:105-109), `expiryFor`'s clamp (:127-132); `liveProposals` (`refresh.ts:185`), `paused()` (:312), `canArm()` (:451-455).
- Gates: `ui/tools/client-lint.mjs` (template literals, hardcoded colors, non-ASCII bytes, off-origin URLs), `ui/tools/proposal.test.mjs` (:289 and :304 the store-to-bus integration, :330-353 the literal scan, :147 the expiry-constant pin), `ui/tools/example-proposal.test.mjs`, `ui/browser/panel-spec.mjs` (`signedInAt` :60, `definitions` :46), `ui/browser/turnprobe-spec.mjs` (`scriptReply` :151, `armProbeDefinition` :171, `requireFreeSlot` :231) -- the harness that scripts a real turn so a browser spec can mint a live proposal.

Instance, the restore path only:

- `src/OcuPilot/Kernel/State/Propose.cls` -- `GuardedRowsForTurn` (:213-244) builds the ten-key wire row; `ConvKey` (:52) is stored and unindexed. The restore read is a sibling method over `ConvKey`.
- `src/OcuPilot/Api/Conversation.cls` (81 lines) and `src/OcuPilot/Kernel/State/Convo.cls` -- `GuardedView` (:133-146) answers `{conversationId, turns[]}` from `Entry.GuardedRows`; its own doc comment (:127-132) records the precedent this story follows: **the API adds what the state package may not name, outside the escalated frame**, exactly as `src/OcuPilot/Api/Turn.cls:225-230` attaches `proposals` to the progress view.
- `src/OcuPilot/Kernel/State/Entry.cls` -- `ConvoKey`/`Seq` (:13-16) and `GuardedRows` (:90-140). It carries no turn key; `src/OcuPilot/Kernel/Agent/Job.cls:137-152` already holds the turn key as `pKey` when it appends the entry.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- `Merge`'s diff rows (:211-215, `field`/`before`/`after` all strings), `Display` (:266-272, a JSON null renders `""`), the secret refusal (:74-79), the stored values (:121-135) and the tool-result projection (:151-157).
- `src/OcuPilot/Test/` -- `ProposalWire.cls` (`WIREKEYS` :28 pins the ten keys), `TurnWire.cls` (:134 the progress key roster, :154 the end-to-end poll), `Proposal.cls`, `ProposalFixture.cls` (`SetState` :118, `AgeExpiry` :125 -- the only route to a non-live row), `ProposalMint.cls`, `ProposalScreen.cls` (the probe descriptor).

## Tasks & Acceptance

**Execution** -- in dependency order: the strings, the declaration and the restore read land before the components that consume them.

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- add two Fixed strings rows: the singular entity noun the card title needs, and the in-card audit-warning sentence that today appears only in the lifecycle prose at :197. Both are copy the document already uses; recorded under `amendments:`.
- `ui/src/app/core/strings.ts` -- append exactly one key, the singular entity noun (`Web application`); every other proposal string already ships. Shared-append: add only.
- `src/OcuPilot/Screen/Registry.cls` -- add the optional entity-label declaration key to `DECLARATIONKEYS` (:318) and validate it, so `DeclarationProblem`'s unknown-key check admits it.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` -- declare the entity-label string key for `web-application`.
- `ui/tools/screen-mirror.mjs` -- emit the new declaration key onto `ScreenDeclaration` and validate it identically to the ObjectScript side, then regenerate `ui/src/app/core/screens.generated.ts`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- compute the audit warning with a kernel predicate over the resolved tool, target and arguments, and project it on the proposal row. The predicate has exactly one home, in the kernel; no screen, descriptor or policy file carries it.
- `src/OcuPilot/Kernel/State/Entry.cls` + `src/OcuPilot/Kernel/State/Convo.cls` + `src/OcuPilot/Kernel/Agent/Job.cls` -- store the turn key on the conversation entry, threaded from `Job.AppendConvoEntry`'s own `pKey` (:137-152). Every pre-existing row reads `""`, a safe default, so `SCHEMAVERSION` does not move (Consistency Conventions); record that reasoning at the change.
- `src/OcuPilot/Kernel/State/Propose.cls` -- add a conversation-scoped guarded read answering this user's proposals for one `ConvKey`, keyed by turn, in one query, plus its `(ConvKey, UserName)` index. One read per restored conversation, never one per turn.
- `src/OcuPilot/Api/Conversation.cls` -- attach each turn's `proposals[]` to the view outside the escalated frame, the way `Api/Turn.cls:225-230` does, degrading to no proposals when the store cannot be read.
- `src/OcuPilot/Test/ProposalWire.cls` + `src/OcuPilot/Test/TurnWire.cls` -- extend `WIREKEYS` for the warning key, and add the conversation-read assertions: a restored turn's proposals are answered, another user's are not, and an unreadable store degrades rather than failing the read.
- `ui/src/app/core/proposal-view.ts` -- new, framework-free: `toCardView(proposal, entityLabel)` mapping `TurnProposal` onto `ProposalCardView` by field reference only; `formatCountdown(msRemaining)` producing `m:ss`; `countdownPhase(msRemaining)` answering normal / warning / expired at the 1:00 boundary; `ProposalPhase` for live, confirming and the six terminal states. The mirror lookup that supplies `secretArguments` is a **parameter**, never a module-level read of the generated file, so a test can supply a screen record as data. No literal default for any proposal field (`ui/tools/proposal.test.mjs:336`).
- `ui/src/app/core/proposal-view.test.mjs` -- new `node --test` suite over the mapper, the formatter and the phase boundaries, including `expiresAt === 0` reading as unknown rather than expired.
- `ui/src/app/core/turn.ts` -- **DW-1213**: read the conversation view's per-turn `proposals` in `parseRestoredEntry` (:373-389) instead of hard-coding `[]`, mark them terminal-expired on the restore path, and never publish `proposal-open` for a restored proposal. Replace the false premise at :175-177 with what is true: a restored proposal may still be live on the instance, and the card is shown expired by product decision.
- `ui/src/app/shell/proposal-card.ts` -- grow it: the countdown caption with its tooltip, and its 1:00 announcement emitted **once into a polite region as a one-shot, never by making the caption itself live**; the unchanged disclosure as a real `aria-expanded` button listing unchanged rows on open; the masked secret field per the supplied `secretArguments`, required before Confirm; the delete form with no Reverse line; the in-card audit warning above the footer; the footer with the runs-as caption, Confirm, Cancel and the guard caption; and the terminal status line with `tabindex="-1"` that replaces them, takes focus, and leaves the outgoing buttons `aria-disabled` for the transition. Keep every `@if` condition a paren-free getter.
- `ui/src/styles/_components.scss` -- extend the `:4057-4191` section with the countdown, footer, masked-field, warning and status-line rules, and the restrained variant by role at opacity 1. Tokens only.
- `ui/src/app/shell/proposal-card.spec.ts` -- replace the two placeholder assertions (:133-143) with the live contract: every string resolved from `STRINGS`, the focus hand-off on each terminal transition, the announcement emitted once, and the masked field gating Confirm.
- `ui/src/app/shell/panel.ts` -- carry `proposals` on `PanelTurnView` (:633-660), render one card per proposal in the transcript after the turn's steps, add the Send secondary variant while any card is live, append `proposalConfirmSentence` to the accompanying reply, and cancel every live card as `Canceled — by your message` on send and `Canceled — by you` on New conversation while Stop cancels nothing. No batch control.
- `ui/src/app/shell/panel.spec.ts` -- the stacking order, the absence of any "Confirm all", the Send variant flip and back, and the three cancel paths.
- `ui/browser/proposal-card.browser-spec.mjs` -- new: script a turn that mints a real proposal through `turnprobe-spec.mjs`, then assert the geometry jsdom cannot compute -- the card reflows at the panel's 400px, the countdown caption's warning color at 1:00, the restrained card's computed opacity is 1, and Confirm is the view's only filled button.

**Acceptance Criteria:**

- Given a live proposal on the progress poll, when its card renders, then the target heading, the instance-computed diff rows, the closed `N unchanged fields` disclosure with every field reachable on open, both labeled agent blocks on the agent tint, the Reverse line where `reverse` is non-empty, the countdown from `10:00`, and the two footer captions are all present and every string resolves from `core/strings.ts`.
- Given the countdown, when it crosses 1:00, then the caption takes the warning token and holds it to 0:00, and `One minute left to confirm` is announced exactly once and never per second.
- Given a delete proposal, when its diff renders, then it carries no after-state and no Reverse line.
- Given a proposal whose target screen declares a secret argument, when the card renders, then a masked field appears for the user to fill, Confirm is `aria-disabled` until it is filled, and the diff row reads the mask on both sides.
- Given several proposals in one turn, when they render, then they stack in wire order each with its own Confirm and Cancel, and the panel exposes no control that confirms more than one.
- Given any terminal transition, when the buttons go away, then they are `aria-disabled` for the transition rather than removed while focused, and the status line that replaces them receives focus and is announced.
- Given an expired or canceled card, when it renders, then every receding element is drawn in the restrained tokens at opacity 1 and the diff stays readable.
- **Integration AC (Rule 1).** Given a transcript restored after a reload while a proposal is unburned and unexpired on the instance, when `restore()` settles, then the consumer `RefreshService` reports `paused()` false and arms normally -- because the restore path published no `proposal-open` -- while the card is on screen showing `Expired` and `Re-propose`.
- **Integration AC (Rule 1).** Given a live proposal in the current turn, when the panel renders, then the consumer `panel.ts` shows one card per wire proposal and its Send button carries the secondary class, so Confirm is the only filled button in the view.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs.** AD-6 (the 10-minute constant is the instance's; the client formats it and never extends it; the confirm channel accepts only the descriptor's declared secret fields, which is why the masked field is driven by the mirror's `secretArguments` rather than by a wire marker), AD-39 (one envelope, two renderings -- the card renders the human half), AD-11 (the rationale, expected impact and reverse are model-authored text rendered as delimited data under their own headings and the agent tint, never as OcuPilot's voice, and nothing rendered issues a request to any host), AD-33 (progress content is untrusted and owned by the turn's user; a poll or conversation read for another user's turn answers nothing), AD-19 (`core/` is framework-free; the mapper, formatter and clock are plain functions with an injected `now`, mirrored into signals by the component), AD-43 (the card rides the `proposal-open` / `proposal-closed` events and must not arm the pause on a restored card), AD-13 (the target is the scoped triple; the title's name segment is the triple's id), AD-4 (the diff is what the user reviews while the payload is the whole object, which is why the unchanged count is shown and the payload never is), AD-9 and AD-37 (the restore read is a guarded read of OcuPilot's own protected state, assembled outside the escalated frame, and a proposal reference stays weak), AD-14 (the entity-type vocabulary is the kernel's closed enum; the entity label is a descriptor declaration over it, not a client-side table), AD-10 (the audit-warning predicate has exactly one home, in the kernel). No AC here contradicts an AD's Rule.

**The DW-1213 ruling: the acceptance criterion governs the presentation, the ledger entry governs the mechanism, and they are not in opposition.** DW-1213's stated harm is that a restored proposal is *dropped* and "the user loses the card ... with no other route to it"; the AC's remedy is that a restored card *is shown*, expired, with Re-propose. Today neither holds, because `parseRestoredEntry` hard-codes `proposals: []` and the conversation read carries none -- one defect violating both. So the story keeps always-expired and fixes the drop. Always-expired is not a coin toss: EXPERIENCE.md:205, :548 and :559, DESIGN.md:1190 and :857 all state it, DESIGN.md:1262 carries "show a restored card as live, with Confirm still available" as an explicit **Don't**, and review-accessibility.md:7 and :15 reason *from* the rule, accepting Re-propose as the WCAG 2.2.1 accommodation. Against that stands one `med` / `fix-risk: low` entry whose own trailer reads "Non-blocking". Keeping the rule is strictly more restrained -- a restored card can never apply a write -- so it preserves the product promise rather than changing it, which is why this is reconciled here and not escalated. DW-1213's second half is a false claim, and it is corrected at its origin: `turn.ts:175-177` no longer says a restored proposal is always expired; it says the card is shown expired by product decision while the proposal may still be live on the instance. **Residual, recorded once:** the `Expired` line on a proposal that has not expired is a deliberate UX restraint. Changing it is a DESIGN.md and EXPERIENCE.md decision for the owner, not a slice change, and it sits beside the spine's existing deferred entry for per-instance proposal expiry.

**Two contradictions in the source documents, resolved toward EXPERIENCE.md, which is canonical (EXPERIENCE.md:250).** DESIGN.md:1193 still renders kill-switched buttons at Material's 38% unavailable opacity, while EXPERIENCE.md:208 and :660 require them replaced by a status line that takes focus and DESIGN.md:857's own rule 7 lists kill-switched among the states that must be restrained at full opacity -- the status line governs. DESIGN.md:1188 writes the confirmed line as `<user>` where the canonical string (EXPERIENCE.md:274) is `<user name>` -- the canonical spelling governs.

**The masked field has no production instance yet, and that is why its lookup is a parameter.** `WebAppList` declares `secretArguments: []` and `Mint.cls:74-79` refuses any call carrying a secret argument, so no shipped tool can produce a masked row until Story 5.10's first real secret. The AC is still falsifiable rather than vacuous because the card takes the declared names as data: its pinning test supplies a screen record with a non-empty `secretArguments`, and the mutation that drops the Confirm gate reddens it. A module-level read of `screens.generated.ts` would have made the same AC untestable until 5.10, which is the trap this parameter avoids.

**Why the countdown needs no new string.** `proposalCountdownLabel` is `Expires in m:ss`, and `m:ss` is the substitution point, the same `split`/`join` idiom `formatUnchangedCaption` already uses for `N`. UJ-3's own `Expires in 9:59` is that substitution, so the published literal stays intact and `ui/tools/strings.test.mjs` -- contended, and untouched -- keeps its count equality.

**Why the entity label is a descriptor declaration.** The title is `Proposal · <entity type> <name>` and UJ-3 resolves it to `Proposal · Web application /csp/myapp`, but the wire carries the slug `web-application` and the mirror's `labelKey` is the plural screen label. A singular noun per entity type is needed; declaring it on the screen descriptor keeps AD-5's single source and lets each of Stories 5.8-5.13 add its own area's noun as its write lands, rather than authoring twenty-eight labels now. The one this story needs already exists as a literal in `example-proposal.ts:79`, derived from EXPERIENCE.md UJ-3.

**Why the restore read is conversation-scoped and assembled in the API.** One query per restored conversation, not one per turn: `Propose.ConvKey` is already stored, so a single guarded read over it plus a `(ConvKey, UserName)` index answers the whole transcript. It is attached in `Api/Conversation.cls` rather than inside `Convo.GuardedView` because AD-9's re-entry rule keeps escalation to a storage call and nothing else, and because `Convo.GuardedView`'s own doc comment (:127-132) already records that precedent for the error `reason` -- `Api/Turn.cls:225-230` does the same for the progress view.

**Consumes:** `src/OcuPilot/Kernel/Proposal/{Mint,Write,Fingerprint}.cls` and `src/OcuPilot/Kernel/State/Propose.cls` (Story 5.1 -- the wire row, the diff, the unchanged count, the expiry); `src/OcuPilot/Kernel/State/{Convo,Entry,Turn,Step}.cls` and `src/OcuPilot/Api/{Turn,Conversation}.cls` (Stories 4.1, 4.5); `ui/src/app/core/{turn,change-bus,refresh,agent-status}.ts` (Stories 1.14, 4.5, 5.0 -- `restraintSentence` and the single `restrained()` selector at `agent-status.ts:345`); `ui/src/app/shell/{panel,tool-call-card,example-proposal}.ts` (Stories 3.6, 4.3, 4.5); `ui/src/app/core/screens.generated.ts` and `ui/tools/screen-mirror.mjs` (Stories 1.9, 2.2 -- `entityType` and `secretArguments`); `ui/browser/{panel-spec,turnprobe-spec,shell-entry}.mjs` (Stories 4.5, 5.0).

**Consumed-by:** Story 5.3 (fills the Confirm seam with the confirm request and the atomic transition, and makes the confirmed, canceled and target-changed status lines authoritative rather than client-derived; it also owns DW-1209, the expiry that never emits `proposal-closed`); Story 5.6 (the collapsed `done · audit not marked` line and the auditing-off banner that sits in the panel's reserved `not-marked` slot); Story 5.7 (the change-highlight the confirmed write raises on the screen, beside this card); Story 5.10 (the first proposal that actually trips the in-card audit warning this story renders, and the first real masked secret field); Stories 5.8-5.13 (each declares its area's singular entity noun as its write tool lands); Story 14.7 (the typed-name field on a destructive card).

**Ledger inbox (Rule 17).** DW-1213 is addressed by the restore-path task, its I/O row and the ruling above. It is the only entry owned by this story key.

**Amendments (Rule 5, apply-and-report tier).** Two EXPERIENCE.md Fixed strings rows: the singular entity noun the card title needs, and the in-card audit-warning sentence that today appears only in the lifecycle prose at :197 and therefore has no canonical entry. Both promote copy the document already uses; neither changes what the product does.

**Footprint extensions.** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, per the amendments above. No contended path is touched.

## Verification

**Commands** -- from `/Users/jbrandt/git/OcuPilot/.worktrees/epic-5`, slot A throughout (`server: "ocupilot-slot-a"`, dev container `ocupilot`; never stop, remove, recreate or `down` it, any `ocupilot-slot-*` container, or `ocupilot-b-ci`):

- `uv run scripts/check-objectscript.py` -- expected: 0 problems over 21 rules.
- `uv run scripts/test_check_objectscript.py` -- expected: all OK.
- `bash scripts/lint-docs.sh` -- expected: clean, including the amended EXPERIENCE.md.
- Load and compile the whole `src/OcuPilot/` tree through the IRIS MCP tools with `server: "ocupilot-slot-a"` -- expected: compile clean. Recompile the **package**, never one class, before reading any mutation result.
- `cd ui && node tools/screen-mirror.mjs` then `node tools/screen-mirror.mjs --check` -- expected: the regenerated mirror carries the new declaration key and `--check` is silent.
- `cd ui && npm run build` -- expected: the six `prebuild` checkers pass. The build writes `ui/dist/ocupilot-ui/`, never `dist/ocupilot`.
- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` then the component runner, all green, including the new `proposal-view.test.mjs` and the rewritten `proposal-card.spec.ts`, with `proposal.test.mjs`, `example-proposal.test.mjs`, `change-bus.test.mjs`, `refresh.test.mjs`, `turn.test.mjs` and `strings.test.mjs` green **unmodified**.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975` then `sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/` -- expected: readiness answers. Tear this throwaway down at the end with `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, and tear down nothing else (Rule 24).
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>` -- **one class per call**, each landed in `%UnitTest_Result` before the next, for at least `OcuPilot.Test.ProposalWire`, `TurnWire`, `Proposal`, `Convo`, `ProposalWrite`, `Descriptor`, `ScreenRegistry` -- expected: each green with a non-zero assertion count. Then `node ui/tools/ci-runner.mjs --container ocupilot-ci` for the full sweep -- expected: 0 failed, 0 leftovers, 0 overlaps. Read the totals back with the `%UnitTest_Result` SQL probe before claiming green; the runner's envelope truncates a package-form tail.
- `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check passes, the executed count is non-zero, and `agentwrite` / `auditmarker` still report `pending` (Stories 5.8 and 5.6 clear them).
- Browser leg, on a **freshly brought-up** throwaway the ObjectScript class sweep has not run on (DW-1204: a swept container's own audit rows cost the audit spec seven tests in a full run while it passes 7/7 in isolation) -- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` -- expected: every spec green, `proposal-card.browser-spec.mjs` included. Rebuild and redeploy before reading **any** browser result: the spec loads the deployed bundle, not the working tree. `messages-log`'s seed guard is window-aware since DW-1190, so repeated full runs on one container are the instrument for a flake claim.
- When copying a single class into the throwaway, copy it to its exact relative path and `grep` inside the container to confirm before believing a red or a green: `%SYSTEM.OBJ.LoadDir` with `cuk` skips a file it judges unchanged, and `cp -R src/ /tmp/ocupilot-ci/` nests a stray copy rather than overwriting.

**Mutations (Rule 19)** -- one per AC and per I/O row, each applied **alone on the throwaway** (never on `ocupilot`), the package or bundle rebuilt before reading, observed red, reverted, with `git status --short` and `git diff --stat` confirmed identical to the pre-mutation snapshot afterwards. A mutation that leaves a `%SYS.Capture` open leaks into a pooled Atelier worker and reddens unrelated classes on good code (DW-1185), so stateful test classes run one class per tool call. Record each as `mutation: <what was changed> -> <which test went red>`. The minimum set:

- make `parseRestoredEntry` hard-code `proposals: []` again -> the DW-1213 restore assertion red on a restored turn rendering no card.
- make the restore path pass the wire `state` through instead of marking a restored proposal terminal -> the `RefreshService` integration AC red, because `paused()` reads true after a reload and never lifts.
- drop the `proposal-open` suppression on the restore path -> the same integration AC red, and `proposal.test.mjs`'s store-to-bus legs still green, which is what distinguishes the two mutations.
- have `Api/Conversation.cls` answer the proposals of a conversation the caller does not own -> the cross-user assertion in `Test.ProposalWire` red.
- remove the turn key from `Entry`'s append so a restored proposal cannot be attached -> the conversation-read assertion red, naming the turn.
- move `countdownPhase`'s warning boundary off 60 s -> the 1:00 phase test red alone, and the browser leg's warning-color assertion red.
- announce the countdown on every tick instead of once -> the single-announcement test red.
- make `formatCountdown` treat `expiresAt === 0` as a past deadline -> the unknown-expiry row red, on a card shown expired that should still be live.
- render the Reverse line on a delete proposal -> the delete row red alone.
- drop the masked field's gate on Confirm -> the secret row red on Confirm being pressable with the field empty.
- remove the audit-warning predicate from `Mint` -> the probe-tool assertion red on the wire key, and the card's warning assertion red.
- remove a diff row's visually hidden `was` / `now` word -> the spoken-form assertion red, which is the AC color alone cannot carry.
- remove the outgoing buttons' `aria-disabled` and delete them on transition -> the focus hand-off test red on each terminal status line.
- apply the restrained treatment with an opacity fade instead of the restrained tokens -> the browser leg's computed-opacity assertion red (jsdom computes no layout, so this belongs there and nowhere else).
- leave Send on the primary class while a card is live -> the panel integration AC red, and the browser leg's one-filled-button assertion red.
- add a control that confirms every card at once -> the no-batch assertion red.
- cancel live proposals on Stop -> the Stop row red, and the New-conversation row still green, which is what separates them.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
