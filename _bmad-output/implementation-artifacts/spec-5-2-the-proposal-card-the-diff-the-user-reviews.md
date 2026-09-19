---
title: 'Story 5.2: The proposal card - the diff the user reviews'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: 'd17375cbeebb361803772f5a47649aa86c780871'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The progress payload carries the unchanged field COUNT and no unchanged rows, so a live card's open disclosure lists nothing.
    evidence: |-
      OcuPilot.Kernel.State.Propose.WireRow emits unchangedCount and the stored diff; the payload is deliberately absent (AD-4, and Test.ProposalWire pins that no payload property reaches the wire). ProposalCardView.unchanged is optional and the mapper has nothing to fill it from, so the disclosure is a real aria-expanded button only where a caller supplies rows -- which today is its own spec. AC1's "every field reachable on open" is therefore satisfied as a mechanism and not yet as data.
    location: >-
      src/OcuPilot/Kernel/State/Propose.cls WireRow; ui/src/app/core/proposal-view.ts toCardView
    severity: medium
  - summary: >-
      Re-propose is rendered on an expired card and wired to nothing, so pressing it does not ask the agent for a fresh proposal.
    evidence: |-
      EXPERIENCE.md's expiry step has Re-propose ask the agent for a fresh proposal as a new turn. The card emits a repropose output carrying the proposal id; panel.ts binds only cancel. The story's Boundaries stage Confirm's request for Story 5.3 and say nothing about Re-propose, and no acceptance criterion covers the new turn.
    location: >-
      ui/src/app/shell/proposal-card.ts repropose; ui/src/app/shell/panel.ts transcript template
    severity: medium
  - summary: >-
      A new index on the Proposal table is not built for rows stored before it, and nothing in the install path builds it.
    evidence: |-
      ProposalConvIdx is added to OcuPilot.Kernel.State.Propose the way Story 5.1 added ProposalTurnIdx; IRIS does not populate an index on compile and OcuPilot.Install.Installer runs no %BuildIndices. A row minted before the upgrade is therefore absent from the index a restored conversation reads through. Bounded by AD-6's own ten-minute window -- such a row is unconfirmable within minutes -- so the effect is a card missing from one reload, never a stale write.
    location: >-
      src/OcuPilot/Kernel/State/Propose.cls ProposalConvIdx, ProposalTurnIdx
    severity: low
  - summary: >-
      The entity-label rule's four sentences are written twice, once per engine, with no shared corpus behind them.
    evidence: |-
      Every other two-engine declaration rule reads one XData corpus from disk (OcuPilot.Test.DeclarationCorpus, RowTargetCorpus, TabCorpus). EntityLabelProblem's four sentences are literals in both OcuPilot.Test.Descriptor and ui/tools/screen-mirror.test.mjs, so a reword lands in two places or in one.
    location: >-
      src/OcuPilot/Screen/Registry.cls EntityLabelProblem; ui/tools/screen-mirror.mjs entityLabelProblem
    severity: low
  - summary: >-
      AC1's "every field reachable on open" cannot be met while AD-4 keeps the payload off the wire, so the disclosure ships as a mechanism with nothing behind it.
    evidence: |-
      AC1 asks for the closed "N unchanged fields" disclosure "with every field reachable on open"; AD-4's Rule, as this spec's Design Notes record it, is that the unchanged COUNT is shown and the payload never is. Propose.WireRow emits unchangedCount and no rows, toCardView never sets `unchanged`, and the aria-expanded button therefore appears only where a caller supplies rows -- today only its own spec. Two readings survive: publish the unchanged field NAMES on the wire (arguably not "the payload"), or read the AC as "the disclosure is a real control over whatever the view carries", which is what shipped. The lead adjudicates at this story's gate; it is an AC-versus-AD tension, not an implementation slip.
    location: >-
      ui/src/app/core/proposal-view.ts toCardView; src/OcuPilot/Kernel/State/Propose.cls WireRow
    severity: medium
  - summary: >-
      The wire's single `canceled` word and the unconditional restore override are both insufficient once Story 5.3 writes terminal states.
    evidence: |-
      restoredProposals maps EVERY restored proposal to `expired`, and phaseForState maps the store's one `canceled` state to `canceled-by-you`. Both are correct today, and mandated: the spec's Always clause says terminal state on restore is decided client-side "never from the wire's `state`, which is `live` on every row until Story 5.3". The moment 5.3 writes `confirmed` or `canceled`, a reload will show a confirmed write as "Expired" with Re-propose, and a sibling-cancel as the user's own. 5.3 owns the transition and needs both revisited with it.
    location: >-
      ui/src/app/core/turn.ts restoredProposals; ui/src/app/core/proposal-view.ts phaseForState
    severity: medium
  - summary: >-
      Mint.WarnsAuditingOff answers false for a non-boolean auditing argument, so `0`, `"false"` or a null would mint an auditing-off write with no in-card warning.
    evidence: |-
      The predicate quits unless `pArgs.%GetTypeOf("Enabled")` is exactly "boolean". Tool arguments originate from a model, which can emit a number or a string for a boolean field. Unreachable today -- the trigger tool `security.auditing.update` does not exist until Story 5.10, and Test.ProposalWire drives only the boolean path -- so it is filed for the story that ships the tool rather than patched against no consumer.
    location: >-
      src/OcuPilot/Kernel/Proposal/Mint.cls WarnsAuditingOff
    severity: low
  - summary: >-
      The masked-field lookup is by entity type rather than by the proposal's own tool, is not filtered to the fields the diff touches, and screenForEntityType has no test of its own.
    evidence: |-
      panel.ts resolves secretArguments through screenForEntityType(target.type), whose first built match wins; a detail screen declaring a secret argument behind a sibling list screen that does not would render the value in clear. toCardView then gates Confirm on EVERY declared name, including one this proposal does not change. AD-6 scopes the confirm channel to the tool's declared secret fields, so the tool is arguably the right key. All unreachable today: no shipped descriptor declares a secret argument and Mint refuses one outright, which is also why screenForEntityType's first-match and unbuilt-skipped branches are exercised by no test. Story 5.10 ships the first real secret.
    location: >-
      ui/src/app/core/navigation.ts screenForEntityType; ui/src/app/shell/panel.ts proposalView
    severity: medium
  - summary: >-
      Nothing refuses a built screen that ships a write tool and declares no singular entity noun, and a missing noun renders a title with a doubled space and no noun.
    evidence: |-
      stringFor('') returns '', so formatProposalTitle resolves `Proposal \u00b7  /csp/x`. screenForEntityType returning null lands in the same place. Unreachable today -- web-application is the only entity a shipped write tool proposes against, and WebAppList declares its noun -- but the spec's Design Notes deliberately let each of Stories 5.8-5.13 add its own area's noun as its write tool lands, and nothing fails when one forgets. A fallback to the wire's type slug would contradict "the noun is a descriptor declaration, not a client-side table", so this is a product call rather than a patch.
    location: >-
      ui/src/app/shell/panel.ts proposalView; src/OcuPilot/Screen/Registry.cls Validate
    severity: low
  - summary: >-
      The delete row's drawn and spoken removed-marker forms have no producer, so two of its three clauses are exercised nowhere.
    evidence: |-
      The I/O row expects `field \u00b7 value \u2192 (removed)` drawn and `<field>: <value>, removed` spoken. No removed marker is emitted anywhere under src/OcuPilot/Kernel/Proposal/, core/strings.ts carries no removed word, and the card renders every row as "was <before> / now <after>". `(removed)` exists once in the tree, as a literal in proposal-card.spec.ts's Story 5.1 fixture. The row's third clause (no Reverse line) and the story's own delete AC are both tested. The marker arrives with the first delete write tool (Stories 5.8-5.13).
    location: >-
      ui/src/app/shell/proposal-card.ts diff row; src/OcuPilot/Kernel/Proposal/Mint.cls Merge
    severity: medium
  - summary: >-
      The reload-after-retention row has no mechanism: no retention sweep exists, so a restored turn still carries its cards after RETENTIONSECONDS.
    evidence: |-
      Propose.cls ships GuardedDeleteForTurn and GuardedDeleteForUser only, and its own ProposalTurnIdx comment records that "the retention sweep is Story 5.3's". The client half -- an absent or empty proposals array reading as no cards -- is tested in proposal-view.test.mjs. The row becomes reachable when 5.3 lands the sweep.
    location: >-
      src/OcuPilot/Kernel/State/Propose.cls
    severity: low
  - summary: >-
      The terminal status line is both a role=status live region and a focus target, and may therefore announce twice or not at all.
    evidence: |-
      Two review layers read the same element oppositely: one that focusing an inserted role=status element announces it twice, one that a live region inserted WITH its text may not announce at all. Both are plausible and screen-reader dependent, and AC6 requires the line to be announced. Settled only by driving a real screen reader (VoiceOver or NVDA) against the deployed card on each terminal transition; neither jsdom nor headless Chrome answers it.
    location: >-
      ui/src/app/shell/proposal-card.ts status template
    severity: medium (unverified)
  - summary: >-
      The conversation read's "an unreadable proposal store degrades to no cards" contract is pinned only by a scan of the handler's source text.
    evidence: |-
      Test.ProposalWire.TestTheConversationHandlerAttachesThemInsideItsOwnerGate reads Api.Conversation with %Compiler.UDL.TextServices and asserts substring presence, $Find ordering and an exact count of three LogRaw occurrences; it never invokes HandleRead or AttachProposals. No test makes GuardedRowsForConvo or GuardedTurnKeys fail. Settled by a fixture seam that drives one guarded read to an error, then asserting 200 with every turn carrying proposals: []. Not patched here because the seam is new fixture surface rather than a direct correction.
    location: >-
      src/OcuPilot/Test/ProposalWire.cls TestTheConversationHandlerAttachesThemInsideItsOwnerGate
    severity: medium
  - summary: >-
      No executing test distinguishes AttachProposals' seq join from a join by ordinal.
    evidence: |-
      The review replaced a positional pairing with a join on each turn's own seq, because Entry.GuardedRows skips a row it cannot open while GuardedTurnKeys counts it. Applied and observed: Entry.Seq is COUNT(*) + 1 per conversation, so the two joins coincide in every state the append path can produce and the ordinal mutation left Test.TurnWire green. They diverge only once a row is unopenable, which no fixture here can force. Settled by a seam that makes one Entry row fail GuardedOpenId. The two-turn test is falsifiable against its other two mutations.
    location: >-
      src/OcuPilot/Api/Conversation.cls AttachProposals; src/OcuPilot/Kernel/State/Entry.cls GuardedTurnKeys
    severity: medium
  - summary: >-
      The conversation read loads and discards every proposal's Arguments and Payload streams, and caps the number of proposals attached at nothing.
    evidence: |-
      GuardedRowsForConvo calls RowValues, which reads all three streams, while WireRow consumes only diff. Neither reaches the wire -- Test.ProposalWire pins the eleven-key roster -- so this is cost, not leak: three stream reads per proposal per GET /conversation/:id. The same RowValues is what GuardedRowsForTurn already uses, and the turns of one conversation are bounded by AD-6's ten-minute window, so a leaner values read was judged more surface than the saving is worth.
    location: >-
      src/OcuPilot/Kernel/State/Propose.cls GuardedRowsForConvo
    severity: low
  - summary: >-
      The `confirming` and `canceled-sibling` phases and the confirmedAt input ship with no writer, and a `confirmed` wire state would render its status line with an empty timestamp.
    evidence: |-
      panel.ts binds neither (confirm) nor [confirmedAt], and nothing sets either phase. phaseForState already maps the store's `confirmed` state, so if the wire ever answered it, statusLineFor would resolve proposalStatusConfirmedBy with the hh:mm:ss placeholder replaced by ''. Story 5.3 fills all three seams; until then they are reviewable surface with no behavior behind them.
    location: >-
      ui/src/app/core/proposal-view.ts ProposalPhase, statusLineFor
    severity: low
  - summary: >-
      A typed message cancels every live card before the send is known to have succeeded.
    evidence: |-
      sendCurrentDraft calls cancelLiveCards('canceled-by-message') and only then awaits turn.send. A send refused by the conversation lock (409), a transport fault or a validation refusal leaves the draft and the turn untouched but the proposals terminally canceled, with Re-propose the only route back and Re-propose wired to nothing. The ordering is deliberate and commented -- it is what keeps a user who types "yes" from habit from seeing a card that still offers Confirm -- so which risk is worse is a product call, not a defect to patch.
    location: >-
      ui/src/app/shell/panel.ts sendCurrentDraft
    severity: medium
  - summary: >-
      A Confirm disabled by an unfilled masked field says nothing about why, and no published string exists to say it.
    evidence: |-
      confirmAriaDisabled returns 'true' with no aria-describedby and no sentence anywhere, so a keyboard or screen-reader user meets a dead primary button. The fix needs a new user-visible string, which needs an EXPERIENCE.md Fixed strings row -- and ui/tools/strings.test.mjs, which derives its expected literals from that table, is a contended path this story may not touch. Reachable only once a descriptor declares a secret argument (Story 5.10).
    location: >-
      ui/src/app/shell/proposal-card.ts confirmAriaDisabled
    severity: low
  - summary: >-
      Small hygiene items in the new fixtures and specs, each real and each below the bar for a patch.
    evidence: |-
      (1) proposal-card.browser-spec.mjs runs (a), (c), (b) and depends on (b) being last, recorded only in a comment; its before() clears the probe definition's read-only flag with no paired restore; its "held to 0:00" assertion is one sample taken after the warning class already implies under a minute. (2) cardPhases is never pruned and a card's typed secret stays in component state after it goes terminal. (3) .ocu-proposal-card-disclosure has padding: 0 over a caption line, below WCAG 2.2's 24x24 target size. (4) Entry.GuardedAppend discards Cap's truncation flag and repeats MAXLEN as a bare 64. (5) Test.ProposalFixture.SetExpiryForUser inlines %ExecDirect rather than extending the fixture's own Update, and SeedIn's pAuditing uses "" as a third meaning beside 0 and 1.
    location: >-
      ui/browser/proposal-card.browser-spec.mjs; ui/src/app/shell/panel.ts; ui/src/styles/_components.scss; src/OcuPilot/Kernel/State/Entry.cls; src/OcuPilot/Test/ProposalFixture.cls
    severity: low
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

### 2026-09-19 - Review pass

- verdicts: 65 findings - high 0, medium 22, low 37, false 4, maybe-false 2
- findings:
  - `[medium]` `[patch]` blind-hunter: `Panel.phaseFor` never reads `expiresAt`, so a card that draws itself `Expired` is still counted live - verified: `phaseFor` resolved from `cardPhases` and the wire state only, while `ProposalCard.livePhase` promotes live to expired from the clock. Patched: `phaseFor` now reads the same `countdownRemaining`/`countdownPhase` pair the card reads.
  - `[medium]` `[patch]` blind-hunter: the one-second ticker is never disarmed on expiry - verified: `syncTicker` ran only from `bump()` and the tick does not bump, and `liveCards` never emptied by clock either. Patched with the row above, plus a `syncTicker()` call on each tick.
  - `[medium]` `[defer]` blind-hunter: a typed message cancels every live card before the send is known to have succeeded - verified at `sendCurrentDraft`; the ordering is deliberate and commented, so which risk is worse is a product call. Deferred.
  - `[low]` `[defer]` blind-hunter: `restoredProposals` overwrites the wire state unconditionally - verified, but the spec's Always clause mandates exactly that until Story 5.3, so no bad outcome today. Deferred to 5.3.
  - `[low]` `[defer]` blind-hunter: `phaseForState` collapses every cancellation into `canceled-by-you` - verified; the wire sends only `live` today. Deferred to 5.3 with the row above.
  - `[medium]` `[patch]` blind-hunter: `AttachProposals` paired turns to keys by array position - verified: `Entry.GuardedRows` does `If $$$ISERR(tOpenSC) Continue` while `GuardedTurnKeys` selects a column per row, so one unopenable row shifts every later turn. Patched to join on each turn's own `seq`.
  - `[low]` `[reject]` blind-hunter: one unreadable `targetRef` empties the whole conversation's proposals - verified, but the spec's own error column makes "no cards" the declared degradation, and `GuardedRowsForTurn` already behaves the same way; diverging one sibling is not a direct correction.
  - `[low]` `[defer]` blind-hunter: the conversation read loads and discards Arguments and Payload, and caps nothing - verified; neither reaches the wire, so it is cost rather than leak. Deferred.
  - `[low]` `[reject]` blind-hunter: the keyless-row `Continue` sits after the row is opened and wired - verified and cosmetic; moving it interacts with the error path above for no user-visible gain.
  - `[medium]` `[patch]` blind-hunter: the "client authors no proposal" scan was not extended with `auditWarning` - verified: the regex named seven fields and its literal class admitted no boolean. Patched; mutation applied (`auditWarning: false` in `proposal-view.ts`) and observed red.
  - `[low]` `[reject]` blind-hunter: `GuardedAppend` discards `Cap`'s truncation flag and repeats `MAXLEN` as a bare 64 - verified; turn keys are store-generated and fixed-shape, so over-64 is unreachable. Recorded in the hygiene deferral.
  - `[low]` `[reject]` blind-hunter: `AttachProposals` returns nothing where the convention is `%Status` - verified; `check-objectscript.py` (the project's authority on that rule) reports 0 problems, and an unconditional `$$$OK` invites an unchecked-status finding instead.
  - `[low]` `[defer]` blind-hunter: `WarnsAuditingOff` fires only on a strictly boolean argument - verified; the trigger tool does not exist until Story 5.10, so there is no consumer to patch against. Deferred.
  - `[low]` `[defer]` blind-hunter: no shipped screen but one declares a noun, and a missing one renders `Proposal \u00b7  /csp/x` - verified (`stringFor('')` is `''`); unreachable today, and a slug fallback would contradict the spec's own Design Note. Deferred.
  - `[medium]` `[defer]` blind-hunter: `screenForEntityType` is untested and keys secrets by entity type, so a first match could render a declared secret in clear - verified as written; unreachable today because no descriptor declares a secret and `Mint` refuses one. Deferred to 5.10.
  - `[low]` `[patch]` blind-hunter: the masked inputs invite a password manager - verified; patched with `autocomplete="off"`. The "no reason on a disabled Confirm" half needs a new published string and is deferred.
  - `[maybe-false]` `[defer]` blind-hunter: the status line is announced twice - could not settle; the edge-case layer read the same element as announcing not at all. Deferred as medium (unverified) with the screen-reader check that would settle it.
  - `[low]` `[defer]` blind-hunter: the disclosure button is below the 24x24 target size - verified; deferred in the hygiene entry rather than patched, since the padding change moves a line the browser leg measures.
  - `[low]` `[defer]` blind-hunter: `cardPhases` is never pruned, and New conversation records a different phase from a new turn - verified; both unobservable because the transcript clears. Deferred.
  - `[low]` `[reject]` blind-hunter: `replyWithConfirmSentence` removes its sentence when the card goes terminal - verified; keeping it would need per-turn state, which is more than a direct correction, and the sentence is the panel's own copy about a card that no longer takes a decision.
  - `[low]` `[defer]` blind-hunter: `confirming`, `canceled-sibling` and `confirmedAt` have no writer, and a `confirmed` wire state would render an empty `hh:mm:ss` - verified. Deferred to 5.3, which fills all three seams.
  - `[low]` `[patch]` blind-hunter: `DECLARATIONKEYS` says "Nine are optional" above a list of ten - verified; patched to "Ten" and the ragged re-wrap closed. The ordering half is rejected: position 11, beside `entityType`, is the defensible reading of "the order Base reads them".
  - `[low]` `[patch]` blind-hunter: `Test.DeclarationCorpus` uses the plural screen label as the singular noun - verified; the corpus is the example the next author copies and nothing resolves its value. Patched to `proposalEntityTask`.
  - `[low]` `[patch]` blind-hunter: the new mirror test was inserted inside `confirmChannelProblem`'s header comment - verified; patched by moving the entity-label comment and test below that test.
  - `[low]` `[reject]` blind-hunter: `TestTheConversationHandlerAttachesThemInsideItsOwnerGate` asserts on source text including a `LogRaw` count - verified and real, but it is the ordering assertions that carry the finding; the behavioral gap it points at is deferred separately rather than fixed by deleting a brittle assertion.
  - `[low]` `[defer]` blind-hunter: the browser spec's execution order lives only in a comment and `allowWrites` has no paired restore - verified. Deferred in the hygiene entry.
  - `[low]` `[defer]` blind-hunter: the browser spec's "held to 0:00" claims more than one sample checks - verified. Deferred in the hygiene entry.
  - `[low]` `[defer]` blind-hunter: `SetExpiryForUser` duplicates the fixture's `Update` idiom and `pAuditing` carries a third meaning - verified. Deferred in the hygiene entry.
  - `[low]` `[reject]` blind-hunter: the two projection slots survive alongside the built-in countdown and footer - verified; `proposal-card.spec.ts` still exercises both `select=` attributes, which is the only thing that can catch a typo in them, and nothing in the app projects either.
  - `[medium]` `[patch]` blind-hunter: coverage gaps - multi-turn `AttachProposals`, the panel ticker, a no-screen entity type - verified. The first two are patched (a two-turn HTTP leg; a panel test that drives a card past its expiry); the third is deferred with the malformed-title entry.
  - `[medium]` `[patch]` edge-case: `phaseFor` ignores the clock - same root cause as the first row; patched there.
  - `[medium]` `[patch]` edge-case: `cancelLiveCards` relabels a card the clock already expired, taking Re-propose away - verified; fixed by the same patch, and pinned by the new panel test's second half.
  - `[medium]` `[patch]` edge-case: the positional turn/key join - same root cause as the sixth row; patched there.
  - `[false]` `[reject]` edge-case: two proposals parsing to an empty id break `@for`'s track key - refuted: `parseProposal` returns `null` when `proposalId` is `''`, so no such proposal reaches the view.
  - `[low]` `[defer]` edge-case: an empty `entityLabelKey` renders a doubled space - same root cause as the malformed-title row; deferred there.
  - `[medium]` `[defer]` edge-case: `screenForEntityType` returning null silently drops a declared secret - same root cause as the masked-lookup row; deferred there.
  - `[maybe-false]` `[defer]` edge-case: a `role="status"` inserted with its text may not announce at all - could not settle; grouped with the double-announcement row and deferred as medium (unverified).
  - `[low]` `[defer]` edge-case: `WarnsAuditingOff` and a number or string `Enabled` - same root cause as the boolean row; deferred there.
  - `[medium]` `[defer]` edge-case: `maskedFields` is not filtered to the fields the diff touches - verified; grouped with the masked-lookup row and deferred to 5.10.
  - `[false]` `[reject]` edge-case: `restore()`'s 404 branch leaves a bound screen paused - refuted: `restore()` is called once, from `main.ts:162` at bootstrap, when this store has nothing open.
  - `[low]` `[defer]` edge-case: a typed secret stays in component state after the card goes terminal - verified; unreachable today and deferred in the hygiene entry.
  - `[low]` `[patch]` edge-case: the mirror test's comment placement - same root cause as the blind-hunter row; patched there.
  - `[false]` `[reject]` edge-case: the spec said "append exactly one key" and two were appended - refuted: the spec's Tasks line names the entity noun, and its Amendments note independently declares two EXPERIENCE.md rows, the second being the audit-warning sentence. Both keys are accounted for.
  - `[medium]` `[defer]` edge-case: AC1's "every field reachable on open" is satisfied as a mechanism only - verified, and it is an AC-versus-AD-4 tension rather than an implementation slip. Deferred with the tension stated for the lead's gate.
  - `[low]` `[reject]` edge-case: AC6's "takes focus" versus the `heldFocus` guard - verified as a deliberate reading the implementation pinned with its own test, and the I/O matrix's typed-message row ("focus moved from any button that held it") supports it. Spec-bound, closed by-design.
  - `[low]` `[patch]` edge-case: EXPERIENCE.md gained two rows with no amendment trail - partly refuted (the `amendments:` key belongs to the lead's contract per Rule 5, and the spec does report them; an added row is not an amendment of existing copy), but `updated:` was stale. Patched to 2026-09-19.
  - `[false]` `[reject]` edge-case: the "the way `Api/Turn.cls` does" parity claim hides a positional assumption - refuted as of this pass: the positional assumption is gone, so the claim now holds in the respect it was doubted.
  - `[medium]` `[patch]` verification-gap: no test drives a card to expiry through the panel, and the ticker is never observed advancing - pre-verified; patched with a panel test that mounts an already-expired card and asserts Send returns to primary. Mutation applied (drop the clock from `phaseFor`) and observed red.
  - `[medium]` `[patch]` verification-gap: `Registry.Validate`'s entity-label refusal has no test - pre-verified; patched with `Test.EntityLabel.Bad` + `Test.EntityLabelRegistry` and a `Validate` leg. Mutation applied on the throwaway (delete the call) and observed red on `Test.Descriptor`.
  - `[medium]` `[patch]` verification-gap: the conversation read's join is only ever read at one turn - pre-verified; patched to two turns with the proposal on the second and the first asserted empty. Mutation applied (drop `AttachProposals`) and observed red.
  - `[medium]` `[patch]` verification-gap: AC7's restrained-token color is unverified; only opacity is pinned - pre-verified; patched by resolving `--ocu-restrained` through a probe node, as test (b) already does for `--ocu-warning`, and comparing the title's and diff field's computed color.
  - `[medium]` `[defer]` verification-gap: the degradation contract is pinned only by a source-text scan - pre-verified; the seam needed to fail a guarded read is new fixture surface rather than a direct correction. Deferred with what would settle it.
  - `[low]` `[patch]` verification-gap: ACs and I/O rows with no `mutation:` line - AC1, the 0:00 row, AC5's ordering half, the typed-message row, the retention row and the two declaration-rule mutations. Closed in-pass per Rule 19: the lines are written into `## Verification` below, and the retention row is recorded as having no producer to mutate.
  - `[low]` `[reject]` verification-gap: `proposal-view.test.mjs`'s delete-reversal test echoes its own input - verified; it is weak but not vacuous, and the delete case's real pin is `proposal-card.spec.ts`'s. Deleting it removes a mapper assertion for no gain.
  - `[low]` `[patch]` verification-gap: the browser spec's "held to 0:00" cannot fail in practice - verified; the claim is corrected in place and the load-bearing color assertion is the one strengthened above. The residual is deferred in the hygiene entry.
  - `[low]` `[patch]` verification-gap: `assert.notEqual(restrainedToken, '')` pins only that the token exists - verified; superseded by the equality assertion added for AC7.
  - `[low]` `[reject]` verification-gap: `MASKED_VALUE.length === 8` compares a constant with its own construction - verified; it pins the published eight-bullet count against a silent change to the repeat count, which is the only way that value goes wrong.
  - `[medium]` `[defer]` verification-gap: `ProposalCardView.unchanged` has no production writer - same root cause as AC1's tension; deferred there.
  - `[medium]` `[patch]` verification-gap: `replyWithConfirmSentence`'s idempotence guard has no test - verified; patched with an assertion that the sentence appears exactly once when the reply already ends with it. Mutation applied (drop the guard) and observed red.
  - `[low]` `[reject]` intent-alignment: the diff implements a wider reading than a pure client story - descriptive, and the widening is what the I/O matrix's own inputs require (an audit-warning field, a singular noun, a conversation-scoped read). No bad outcome named.
  - `[medium]` `[defer]` intent-alignment: the delete row's drawn and spoken removed-marker forms are exercised nowhere - verified: no removed marker is produced anywhere in the kernel and the card has no delete branch. The row's third clause and the story's delete AC are tested. Deferred to the first delete write tool.
  - `[low]` `[defer]` intent-alignment: the reload-after-retention row has no mechanism - verified: no retention sweep exists; Story 5.3 owns it. Deferred.
  - `[medium]` `[defer]` intent-alignment: Re-propose is rendered and wired to nothing - verified; already recorded by the implementation as a deferred medium, carried forward.
  - `[low]` `[reject]` intent-alignment: the confirm sentence is appended inside the model's own reply block - verified, but the spec's I/O row requires the reply to end with that sentence and AD-11 governs the card's three model-authored fields, not the reply block. Spec-bound, closed by-design.
  - `[low]` `[reject]` intent-alignment: the restore projection is a sibling method rather than a literal reuse of `GuardedRowsForTurn` - verified; both now write the wire row through one private `WireRow`, which is the reuse the intent asked for.

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

**Mutations (Rule 19)** -- one per AC and per I/O row, each applied **alone**, reverted, with `git status --short` and `git diff --stat` confirmed identical to the pre-mutation snapshot afterwards; every instance-side one on the throwaway (never on `ocupilot`), the package or bundle rebuilt before reading. A mutation that leaves a `%SYS.Capture` open leaks into a pooled Atelier worker and reddens unrelated classes on good code (DW-1185), so stateful test classes run one class per tool call. Recorded as `mutation: <what was changed> -> <which test went red>`; each line below was applied and observed:

- `parseRestoredEntry` hard-codes `proposals: []` again -> `proposal.test.mjs` "a restored turn carries its proposals" and the reload integration AC both red; `panel.spec.ts`'s restored-card test red on the card count.
- `restoredProposals` passes the wire `state` through instead of recording the terminal one -> `proposal-view.test.mjs`'s restore test red, and the reload integration AC red because `paused()` reads true after a reload and never lifts. **The terminal state is the suppression**: `publishProposals` opens a proposal only while its state is live, so there is one guard here rather than two, and this is the mutation that reddens it.
- `publishProposals` stops skipping a non-live proposal -> the reload integration AC red, together with the existing "a proposal whose state turns terminal is closed" leg. The publisher's own skip is the second half of the same rule, and it is not independently removable without that leg going red too.
- `GuardedRowsForConvo` keyed on `ConvKey` alone, so it answers the proposals of a conversation the caller does not own -> `Test.ProposalWire` 1 of 11 red: `TestAnotherUsersConversationAnswersNoProposals`.
- the turn key is dropped from `Entry.GuardedAppend` -> `Test.TurnWire` 1 of 13 red: `TestARestoredConversationCarriesTheTurnsProposals`, over HTTP on the throwaway.
- `countdownPhase`'s warning boundary moved off 60 s -> `proposal-view.test.mjs`'s 1:00 boundary test red alone, and the browser leg's test (b) red alone on the warning color.
- the countdown announces on every tick instead of once -> `proposal-card.spec.ts`'s AC2 red.
- `countdownRemaining` treats `expiresAt === 0` as a past deadline -> the unknown-expiry test red, on a card shown expired that should still be live.
- the Reverse line renders on a delete proposal -> the delete test red alone.
- the masked field's gate is dropped from `confirmAriaDisabled` -> AC4 red on Confirm being pressable with the field empty.
- `Mint.WarnsAuditingOff` answers 0 unconditionally, and separately 1 unconditionally -> `Test.ProposalWire` 1 of 11 red on `TestTheAuditWarningIsTheKernelsPredicateOnTheWire` each time; the card's own warning assertion is `proposal-card.spec.ts`'s, reddened by the view carrying false.
- a diff row's visually hidden `was` word is removed -> the spoken-form assertion red, which is what color alone cannot carry.
- the outgoing buttons are dropped the moment the phase turns terminal -> AC6 red on the `aria-disabled` hand-off.
- the restrained treatment applied as an opacity fade instead of the restrained tokens -> the browser leg's test (c) red alone, on the computed opacity (jsdom computes no layout, so this belongs there and nowhere else).
- Send left on the primary class while a card is live -> the panel integration AC red, and the browser leg's test (a) red on Confirm no longer being the only filled button. **That browser assertion is only load-bearing with a draft typed first**: an empty composer leaves Send `aria-disabled`, whose own restrained fill differs from Confirm's whatever the variant, and on the first attempt this mutation passed for exactly that reason.
- a Confirm control added to the panel footer -> the panel's no-batch button roster red (and two earlier panel rosters with it).
- the status line focused unconditionally rather than only when a button of its own card held focus -> the "a transition nobody pressed leaves focus where it was" test red; without that guard a typed message canceling three cards would pull focus out of the composer.
- live proposals canceled on Stop -> the Stop test red, and the New-conversation test still green, which is what separates them.

**Added in the review pass** (Rule 19: whoever changes a pinning test writes its line in the same pass). Each was applied alone and observed:

- the clock dropped from `panel.ts`'s `phaseFor` -> `panel.spec.ts`'s "a card whose countdown has run out is expired to this panel too" red alone, on Send still carrying the secondary class with no Confirm in the view. This is AC1's and the 0:00 row's panel half, which no mutation reached before.
- `replyWithConfirmSentence`'s "already ends with it" guard dropped -> `panel.spec.ts`'s "the confirm sentence is appended once" red alone; the integration AC's `toContain` stays green, which is why it needed its own line.
- `auditWarning: false` written into `proposal-view.ts`'s `toCardView` -> `proposal.test.mjs`'s literal scan red. Before this pass the scan named neither the field nor a boolean literal, so the mutation was green.
- the `EntityLabelProblem` call deleted from `Screen/Registry.cls`'s `Validate` (throwaway, package recompiled, grep confirmed inside the container) -> `Test.Descriptor` 1 of 47 red: `TestTheEntityLabelRuleAnswersTheSameSentencesAsTheMirror`.
- the `AttachProposals` call deleted from `Api/Conversation.cls`'s `HandleRead` (throwaway, same discipline) -> `Test.TurnWire` 1 of 13 red: `TestARestoredConversationCarriesTheTurnsProposals`, now over two turns.
- **Applied and NOT red, recorded rather than claimed:** pairing turns to keys by ordinal instead of by `seq` left `Test.TurnWire` green. `Entry.Seq` is `COUNT(*) + 1` per conversation, so the two joins coincide in every state the append path produces; they diverge only once `GuardedRows` skips an unopenable row, which no fixture here can force. The seq join is kept as the correct form and the gap is recorded under `deferred:`.
- **AC5's ordering half** is pinned by `panel.spec.ts`'s `cardTitles(host)).toEqual([...])`; mutation: swap the two cards' render order -> that assertion red alone, while the no-batch button roster stays green.
- **The typed-message row's** mutation is "drop the `cancelLiveCards` call from `sendCurrentDraft`" -> `panel.spec.ts`'s "a typed message cancels every live card" red. It was recorded only in the test file; it belongs here too.
- **The reload-after-retention row has no mutation**, because it has no producer: no retention sweep exists (Story 5.3 owns it), so nothing can put the instance in the state the row describes. The client half -- an absent or empty `proposals` reading as no cards -- is pinned by `proposal-view.test.mjs`, whose mutation is "have `restoredProposals` throw on a non-array instead of answering `[]`".

## Auto Run Result

**Change.** The card is the live surface the wire already feeds: `core/proposal-view.ts` maps `TurnProposal` onto `ProposalCardView` and owns the countdown's formatter and its two boundaries; `shell/proposal-card.ts` grows the countdown with its one-shot 1:00 announcement, the disclosure, the masked field, the in-card audit warning, the footer and every terminal status line; `shell/panel.ts` stacks one card per wire proposal, drops Send to secondary while one is live and owns the three client-side cancels. On the instance, the conversation entry now stores its turn key and `Api/Conversation` hangs each turn's proposals off the restored view, which is what closes DW-1213; `Mint` projects the kernel's own audit-warning predicate on the row; and a screen descriptor declares the singular entity noun the card title reads.

**Files.**

- Server: `Kernel/State/Propose.cls` (`AuditWarning`, `ProposalConvIdx`, `GuardedRowsForConvo`, `WireRow`); `Kernel/State/Entry.cls` (`TurnKey`, `GuardedTurnKeys`, keyed by `Seq`), `Convo.cls`, `Kernel/Agent/Job.cls` (the key threaded from the job); `Kernel/Proposal/Mint.cls` (`WarnsAuditingOff`); `Api/Conversation.cls` (`AttachProposals`, joined on `seq`); `Screen/Registry.cls` (`entityLabelKey`, `EntityLabelProblem`), `Screen/Descriptor/Base.cls`, `WebAppList.cls`.
- Server tests: `Test/ProposalWire.cls` (+5 methods, `WIREKEYS`), `TurnWire.cls` (+1, over two turns), `Descriptor.cls` (+1, with a `Validate` leg), `DeclarationCorpus.cls`, `ProposalFixture.cls` (`SetExpiryForUser`), and the new `Test/EntityLabelRegistry.cls` + `Test/EntityLabel/Bad.cls` fixture pair.
- Client: `core/proposal-view.ts` (new; the two view-model types moved here and re-exported from `shell/example-proposal.ts`), `core/turn.ts` (`auditWarning`, `restoredProposals`, the restore path), `core/navigation.ts` (`screenForEntityType`), `core/strings.ts` (two keys), `core/screens.generated.ts` (regenerated), `shell/proposal-card.ts`, `shell/panel.ts`, `styles/_components.scss`, `tools/screen-mirror.mjs`.
- Client tests: `tools/proposal-view.test.mjs` (new, 14), `tools/proposal.test.mjs` (+2 and a widened literal scan), `tools/screen-mirror.test.mjs` (+1), `shell/proposal-card.spec.ts` (rewritten, 20), `shell/panel.spec.ts` (+10), `browser/proposal-card.browser-spec.mjs` (new, 3), `testing/screen-declaration.ts`.
- Docs: EXPERIENCE.md Fixed strings rows 381-382, and its `updated:` moved with them.

**Two deviations from the spec's own text, both narrower than what it asked for.** `toCardView` takes the entity noun and the declared secret names as two parameters rather than one, which is what the Code Map's "the mirror lookup that supplies `secretArguments` is a parameter" requires; and the new `node --test` suite is `ui/tools/proposal-view.test.mjs`, not `ui/src/app/core/proposal-view.test.mjs`, because `npm test` globs `tools/*.test.mjs` and a suite outside it runs nowhere. `Test.ScreenRegistry`, named in the verification roster, is a fixture registry with no test methods; `Test.Descriptor` and `Test.ReadTool` are the classes that exercise the declaration rules.

**Review findings.** 65 findings across four layers: 0 high, 22 medium, 37 low, 4 false, 2 maybe-false. **22 patched** (9 at medium, 13 at low), **26 deferred**, **17 rejected**. No entry routed `intent_gap` or `bad_spec`.

- Patched at medium: `phaseFor` now reads the clock, so the panel and the card cannot disagree once a countdown runs out (this alone fixed Send stuck on secondary, a ticker that never disarmed, and a typed message relabelling an expired card and taking Re-propose away); `AttachProposals` joins each turn to its key by `seq` rather than by array position; the client-authors-no-proposal scan gained `auditWarning` and a boolean literal class; `Registry.Validate`'s entity-label refusal, the conversation read's multi-turn attribution, AC7's restrained-token color and `replyWithConfirmSentence`'s idempotence each gained the pinning test they lacked.
- Patched at low: the masked input's `autocomplete`, `DECLARATIONKEYS`' stale count, the corpus's plural-for-singular example, the mirror test's misplaced header comment, EXPERIENCE.md's `updated:`, and the Rule 19 mutation lines above.
- Rejected, with reasons recorded per row in the triage log: two refuted outright (`parseProposal` already drops an empty id, so `@for`'s track key cannot collide; `restore()` is bootstrap-only, so its 404 branch cannot strand a pause), two closed by-design against the spec (`heldFocus`, the confirm sentence's placement), and the remainder cosmetic or unreachable in everyday use with a fix larger than a direct correction.

**Verification.** `check-objectscript` 0 problems over 21 rules (505 files); `test_check_objectscript` 126 OK; `lint-docs` clean over 91 files; `screen-mirror --check` silent; `npm run build` green through its six prebuild checkers; `npm test` 1,078 `node --test` plus 661 component tests green, with the contended `strings.test.mjs` untouched and green. The whole `src/OcuPilot/` tree loaded and compiled clean on `ocupilot-slot-a` (505 documents, 0 failed). `ocupilot-ci` was **recreated** before the browser leg, so the gate ran on a container the class sweep had not touched (DW-1204): the whole browser suite **188/188** green against the freshly deployed bundle -- the 185 this epic has been reading, plus this story's three. Then, on that same container, the whole ObjectScript class sweep: **134 classes, 1,279 tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign runs**; and `smoke.sh` **executed 45, passed 45, failed 0**, with `agentwrite` and `auditmarker` still pending as Stories 5.8 and 5.6 require. Five review-pass mutations were applied one at a time -- two under the component runner, one under `node --test`, two inside the throwaway with the file grepped in the container before each read -- and each was observed red on the named test and reverted.

**Residual risks.** 19 `deferred:` entries, 9 of them medium. The two the lead should look at first: **AC1's "every field reachable on open" is satisfied as a mechanism and not as data**, because AD-4 keeps the payload off the wire -- an AC-versus-AD tension the lead adjudicates rather than an implementation slip; and **no executing test distinguishes the corrected `seq` join from the ordinal one it replaced**, because `Entry.Seq` is `COUNT(*) + 1` and the two coincide until a row is unopenable, which no fixture can force. Beyond those: the wire's state vocabulary and the unconditional restore override both need revisiting when Story 5.3 writes terminal states; the masked-field lookup keys secrets by entity type rather than by tool and is unreachable until Story 5.10 ships the first real secret; the delete row's removed marker and the reload-after-retention row have no producer yet; and the terminal status line's announcement is `medium (unverified)` pending a real screen reader. Confirm's request remains the seam Story 5.3 fills, so pressing Confirm applies nothing -- the staged affordance the spec names. `ocupilot-ci` is left running and has now had the class sweep run on it, so the next consumer of a browser gate recreates it first.

**Follow-up review recommended: true.** Nine medium entries were patched in this pass (two or more is the threshold), and the named unverified risk is the one patch whose red could not be observed: `AttachProposals`' join moved from array position to each turn's own `seq`, and no fixture in this suite can make an `Entry` row unopenable, which is the only state in which the two differ. The change is correct by inspection and the surrounding test is falsifiable against its other mutations, but that one edit ships unfalsified.

Status: done
Blocking condition: none
