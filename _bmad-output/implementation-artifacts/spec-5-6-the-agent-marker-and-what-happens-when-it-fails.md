---
title: 'Story 5.6: The agent marker, and what happens when it fails'
type: 'feature'
created: '2026-09-20'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A confirmed write leaves no record that it came through the agent. `Kernel/Audit/Event.cls`
registers four event names and none of them is a write marker, `Confirm.Transition` writes no ledger
row at all, and nothing anywhere asks whether the instance is still marking. So FR-21/FR-22's whole
claim — find the change in the instance's own audit database and know the agent made it — is
unmet, and SM-5's pairing metric has nothing to count. Three ledger entries land on the same seam:
the ledger row's `RequiredPairs` column carries three incompatible meanings and withholds an
honestly-empty requirement from every cross-user reader (DW-1305, DW-1321), the provider port's gate
reads the calling process where AD-31 names the turn owner (DW-1309), and a confirm refusal that
leaves the row live is invisible in the panel, so 5.5's prohibited set cannot be seen to hold
(DW-1348).

**Approach:** Add one roster event name and one emission that carries the proposal id, the tool, the
AD-13 scoped target and the user; check its return value at the emission site; open the confirmed
write's ledger row before the port call and finalize it after with what was actually executed,
including the marker's outcome; project "writes are being marked" onto the panel's existing
restraint read so its reserved `not-marked` slot can fill; and surface a refusal the user can reach
inside the card that was refused.

## Boundaries & Constraints

**Always:** The marker is emitted from exactly one place — `Confirm.Transition`, after `tWriteSC`
reads OK and before `Answer` — so a write made any other way emits none. `$System.Security.Audit`'s
return value is checked at that site and a drop is recorded on the ledger row and reported through
`Event.LogFailure`; **the marker never fails the write and never propagates** (AD-15). The marker
names the target with the **canonical** ref the proposal stored (`EntityRef.NormalizedId`, Story
5.5), never the spelling the agent typed. The ledger row is created before the port call and
finalized after it with the resolved target, the field names actually sent and the pairs actually
evaluated; secret-typed fields are excluded at write time, never redacted afterwards (AD-41, AD-3).
Every emission stays in the install namespace — `Event.Record`'s documented reason (a least-privileged
OcuPilot administrator holds no `%DB_IRISSYS:READ`) binds the new one too. Every user-visible string
comes from `core/strings.ts`; every IRIS MCP call carries `server: "ocupilot-slot-a"`; a denial test
uses a purpose-built least-privileged role, never `%Operator`.

**Never:** No second escalation and no new privileged routine application — AD-8 and AD-9 name two
purposes and this story adds neither (see Design Notes, *Why the banner reads a recorded fact*). No
new web application, route or tool, so no `EndpointCoverage` or `SurfaceCoverage` roster row. No
`SCHEMAVERSION` move. No hand-written Storage section. No banner link or "Turn auditing on" action —
both strings exist and both stay unrendered until Story 7.4. No change to 5.3's gate order, to
`Prohibited.cls`, or to the mint path. No edit to `ui/src/app/shell/{header,account-menu,side-bar,command-box}*`
or `ui/src/styles/**` (Epic 15 holds them). Do not write `deferred-work.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| The marker, on a confirmed write | A live proposal for `webapp.list.update`; the user confirms; the port answers OK | Exactly one `OcuPilot`/`Security`/`AgentWrite` row, its payload carrying `proposalId`, `tool`, the canonical `target` triple, `actor` and `writtenAt`; the vendor's own `%System/%Security/*Change` row for the same target and user at or after `writtenAt` | None |
| Either record locates the other | The pair above | From the marker: the vendor row is the `*Change` row for that target and user at or after `writtenAt`. From the vendor row: the marker is the `OcuPilot`-source row for the same target within that window, and it names the proposal id | None |
| The same write not made by the agent | The identical vendor `PUT` issued straight through `Port.AdminPort.Invoke` | Zero `AgentWrite` rows in the window; the vendor's own change row is still there | None |
| The marker is dropped | The `AgentWrite` registration deleted, then a confirmed write | HTTP 200; the target really changed; ledger row `AuditMarked = "not-marked"`; one `Event.LogFailure` report carrying `DROPPEDAGENTWRITE`; confirm answers `auditMarked: false`; zero audit rows under that name | The drop is the recorded outcome, never a failure |
| The card and the reply say so (DW-1174 scope) | The dropped-marker confirm above, in the panel | The confirmed write's tool-call card's **collapsed** line reads `done · audit not marked` carrying the warning class; the reply gains `auditMarkerReplySentence`. A marked write reads `done · audit marked` | None |
| Writes are not being marked | `Switch.WritesMarked` 0 | `GET /agent/restraint` answers `writesMarked: false`; the panel's reserved `not-marked` slot renders `auditingOffBanner` alone, to every user, with no link and no action | None |
| The executor records it | A confirmed write whose emission is dropped | `Switch.WritesMarked` is set 0 by the executor in the same pass, so the banner is showing on the next panel read | Refresh failure logged, never propagated |
| The ledger row is finalized after the write | A confirmed write | One `write`-kind row on the proposal's `TurnKey`: opened `pending` before the port call, finalized `ok`/`error` after it with the canonical target, the sent field names (secret-declared names absent) and the evaluated pairs | A write that raises leaves the row `pending`, which is the trace |
| A row that needs no privilege (DW-1305) | A `llm` row whose route resolved to an empty pair set — every turn from Home | `PairsSense = "none"`; a cross-user reader holding the ledger's admin resource sees the row | None |
| A row whose requirement is unknown (DW-1321) | `RequiredPairs` empty with `PairsSense` `checked`/`declared`/`route`, truncated, or a legacy row with `PairsSense` `""` | Withheld from every cross-user reader, exactly as today | Withheld, not an error |
| The three meanings are legible (DW-1321) | Rows from `Dispatch`, `Loop.RecordRefusedRow`, `Ledger.RecordProviderCall` and the confirm | `PairsSense` reads `checked`, `declared`, `route`, `checked`; `RowObject` carries `pairsSense` | None |
| The provider gate names the turn owner (DW-1309) | A turn whose owner's grant is revoked after the job spawned | `ProviderPort.Invoke` refuses on the owner's **live** grants (`CheckUserPermission`), not the job's frozen `$ROLES` | `AUTH.NOPRIVILEGE` with `failedPair`, unchanged shape |
| A refusal that leaves the row live (DW-1348) | Confirm refused 403 `PROHIBITED.*` or by the restraint verdict; the row is still `live` | The card renders the envelope's own `reason` in a warning banner above its footer; Confirm stays offered because the condition can clear; the panel does not silently drop the decision | Rendered, never swallowed |
| The audit spec's marker leg (DW-1174) | An instance carrying thousands of `OcuPilot`-source rows | The leg bounds its population with `beginDateTime` taken before the confirm and asserts on its own marker row, never on the instance's whole marker count | Passes on a long-lived instance |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Audit/Event.cls:82` `Roster()` -- the registration list; a name added here is
  registered by the installer **with no edit of its own** (its own header says so, `:79-81`).
  `:161` `Record` is the configuration-change emitter: it hardcodes `Scope.#SCOPEINSTANCE` at `:172`,
  so the marker cannot reuse it -- the proposal's stored `TargetRef` is already a full AD-13 key.
  `:182` is the `$System.Security.Audit` call, `:186` the return check, `:200` `LogFailure`.
  `:148-160` the caller contract and the no-namespace-switch finding that binds the new emitter.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:167` `Transition`; gate order at `:188` prohibited,
  `:204` restraint, `:219-228` pairs, `:261` fingerprint, `:284` `GuardedClaimAndClose`, `:301` the
  port call, `:302-316` the write-failure branch, `:318` `Answer`. **The marker and the finalize go
  between `:316` and `:318`; the ledger row opens just before `:301`.** `:565` `Answer` composes
  `{proposalId, state, closedReason, confirmedAt}` -- the one place a new `auditMarked` key is added.
  `:550` `HoldsPair` is the `CheckUserPermission` idiom to reuse.
- `src/OcuPilot/Kernel/State/Propose.cls:71` `TurnKey`, `:74` `ToolName`, `:78` `TargetRef`,
  `:122` `AuditWarning` (the mint-time warning -- a **different** fact from the marker outcome; its
  header is also the "added with no `SCHEMAVERSION` move" precedent to follow).
- `src/OcuPilot/Kernel/State/Ledger.cls:25-35` `KINDLLM`/`KINDTOOL`/`KINDOVERFLOW`; `:84` `Status`;
  `:102` `RequiredPairs` with its scalar-format note at `:93-97`; `:109` `RequiredPairsTruncated`;
  `:128` `LedgerTurnSeqIdx On (TurnKey, Seq)` **unique** -- the confirm's row takes the proposal's
  turn key and the next seq; `:141` `GuardedAppend` (single insert-and-save -- finalize is new).
- `src/OcuPilot/Kernel/Audit/Ledger.cls:70` `RoutePairs`, `:106` `RecordProviderCall` (sense
  `route`), `:146` `RecordToolCall`, `:189` `RedactArguments`, `:289` `PairsToString`, `:340`
  `StringToPairs`, `:379` `ViewForUser` with its admin gate at `:391`, self-read at `:441-448`,
  truncation at `:449`, unparseable at `:456-461`, **`:466` the empty-set withholding DW-1305 is
  about**; `:505` `RowObject` and `:524` `requiredPairs`.
- `src/OcuPilot/Screen/Gate.cls:132` `EvaluatePairs` (empty = satisfied) vs `:163` `EvaluateRequired`
  (empty = never held, DW-1120) -- the deliberate contrast the new sense column resolves; `:262`
  `HoldsPrivilege` is `$System.Security.Check`, the **calling process**.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls:72` `HoldsPair` (`CheckUserPermission`), `:257`/`:279` the
  pairs it actually checks, `:363` `RecordLedger` -> sense `checked`.
- `src/OcuPilot/Kernel/Agent/Loop.cls:211` the **only** `ProviderPort.Invoke` call site, with `pUser`
  in scope from `Run` at `:119`; `:332` `HoldsAnyResource` (the AD-31 idiom); `:782`
  `RecordRefusedRow` -> sense `declared`; `:806` `RecordClientRow` -> sense `checked`.
- `src/OcuPilot/Port/ProviderPort.cls:87` `Invoke` and its gate at `:96` (`GateAnyOf`), `:198`
  `InvokeDraft` and `:204` (Test connection, a foreground request whose caller **is** the user --
  out of scope), `:457`/`:464` the two gate helpers, `:520` `ResolvedUsername`.
- `src/OcuPilot/Api/Switches.cls:275` `HandleRestraint` and `:285-292` the body keys the panel reads;
  `:57` the settable field list the new property stays **out of**.
- `src/OcuPilot/Kernel/State/Switch.cls:39-70` -- the instance's one switches row; `Restraint.cls:99`
  already reads it.
- `src/OcuPilot/Install/Installer.cls:2914` `EnsureAuditEvents` (guarded by `Security.Events.Exists`
  at `:2924`, repairs a disabled registration at `:2930`, creates at `:2937`), `:2964`
  `EnsureAuditingEnabled`, `:2991` `AuditEnabledSetting`, `:3354-3358`/`:3387-3388` the per-event and
  instance flags `StateFingerprint` already folds, `:866`/`:869` the call order.
- `ui/src/app/core/turn.ts:113-128` `TurnStep`, `:270` `boolAt`, `:290-313` `parseStep`, `:820-853`
  `decideProposal` with **`:845` the `detail.state` read and `:852` the gate DW-1348 names**,
  `:860-886` `recordProposalState`, `:1021-1060` `pollOnce`.
- `ui/src/app/shell/panel.ts:204-241` the banner strip in literal document order, **`:217` the empty
  `data-slot="not-marked"` div already reserved**, `:227-234` the `lock` slot's wrapper-plus-`@if`
  precedent; `:334` the proposal `@for`; `:583`/`:598`/`:673` the banner getters; `:764` `phaseFor`;
  `:781-792` `replyWithConfirmSentence` (the one sanctioned client-appended sentence);
  **`:853-861` `onCardConfirm`, whose `finally` at `:858` drops the decision**.
- `ui/src/app/shell/tool-call-card.ts:48-50` the collapsed status span and its
  `ocu-tool-call-status-warning` binding, `:86-88` `failed`, `:98-109` `statusText` -- the one
  composer.
- `ui/src/app/core/strings.ts:61` `auditingOffBanner` (verbatim, unused today), `:63`/`:65` the link
  and action that stay unrendered, `:181-182` `toolCallStatusDone`/`Failed`, `:1004`
  `auditMarkerFailed: 'done · audit not marked'` (already authored; **never write the raw `·`**,
  Rule 14 and the header note at `:36-40`).
- `ui/src/app/core/agent-status.ts:68-77` `Restraint`, `:94` `UNRESTRAINED`, `:88-92` `FOOTER_KEYS`.
- `ui/src/styles/_components.scss:370` `.ocu-banner-warning`, `:3239-3242`
  `.ocu-panel-banner-slot:empty { display: none }`, `:3970` `.ocu-tool-call-status-warning` -- all
  three exist, so **no SCSS edit is needed** (Epic 15 holds that tree).
- `ui/browser/audit.browser-spec.mjs:439` the AC2 leg, `:452-454` the `expectedTotal` computation
  DW-1174 names, `:178` `markerRowCount`, `:699` `seedRowsPresent`, `:122-149` `seedAuditRows`,
  `:223` `typeCriterion`, `:233` `search`, `:252` `waitForCount`, `:305` `setMaxRows`; criterion ids
  are `ocu-audit-criterion-<param>` (`ui/src/app/areas/logs/audit.page.ts:251`) and the nine params
  are fixed by `src/OcuPilot/Screen/Descriptor/AuditList.cls:139-150` -- `beginDateTime` is the one
  that bounds the population, and there is **no** proposal-id criterion.
- `src/OcuPilot/Test/AuditEvent.cls:355` `TestADroppedEmissionNeitherFailsTheWriteNorPassesSilently`
  -- the exact shape the marker's drop test copies; `:536` `DeleteRegistration`, `:92`
  `MissingTriples`, `:124` `RowsCarrying`, `:156` `Marker`, `:162` `Now`; `Test/EventProbe.cls:18`
  `LogFailure` capture. `Test/ProposalFixture.cls:75` `ArmWriteFault`, `:375` `EnsureWriteTarget`
  (armed by `OCUPILOT_ALLOW_PRINCIPALS`), `Test/ConfirmFixture.cls:13-31` the three seams.
  `Test/LedgerEmptyPairs.cls:116` `TestARowWithNoRecordedRequirementIsWithheldCrossUser` and `:150`
  `TestTheProviderWriterRecordsTheTurnsRequirement` -- **both change with DW-1305 and must be
  rewritten deliberately, not deleted.** `Test/TurnWireFixture.cls:70` `EnsurePrincipal` is the
  least-privileged-role helper.
- `scripts/ci-throwaway.sh:202` the `OCUPILOT_ALLOW_PRINCIPALS` roster, `:216`
  `OCUPILOT_ALLOW_AUDIT_EVENTS`, held equal to the declaring classes by `ui/tools/ci.test.mjs:1731`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:258` the
  Fixed-strings row for the banner (present verbatim), `:409` the tool-call-card status vocabulary
  including `done · audit marked`, `:558` the audit-emission-failure state row, `:479` the banner
  kinds.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Audit/Event.cls` -- add `EVENTAGENTWRITE = "AgentWrite"`,
  `DESCRIPTIONAGENTWRITE = "OcuPilot agent confirmed write"` (within the 128 characters its own
  `:40-44` note gives as the bound that matters) and
  `DROPPEDAGENTWRITE = "the confirmed write was applied and no audit row was written"`; put the name in `Roster()` and its arm in `Description()`. Add
  `RecordAgentWrite(pProposalId, pToolName, pTargetRef, pUser, pWrittenAt, pFields As %List) As %Status`:
  it parses the **stored canonical** ref with `EntityRef.Parse` rather than assuming instance scope,
  builds `{actor, target, verb, proposalId, tool, writtenAt, fields}`, redacts through
  `Audit.Log.Redact`, emits, checks the return, and reports `DROPPEDAGENTWRITE` through
  `LogFailure`. Add `WritesMarked() As %Boolean` and `RecordMarking(pMarked)` reading and writing the
  switch row's new property. No namespace switch anywhere in this class.
- `src/OcuPilot/Kernel/State/Switch.cls` -- add `WritesMarked As %Boolean [ InitialExpression = 1 ]`,
  documented as **observed, never operator-set**, and deliberately absent from
  `Api/Switches.cls:57`'s settable list. Record why `SCHEMAVERSION` does not move.
- `src/OcuPilot/Install/Installer.cls` -- `EnsureAuditEvents` needs no edit (the roster drives it);
  after `EnsureAuditingEnabled` (`:869`) compute marking from the instance flag it already reads and
  the `AgentWrite` registration's own `Enabled`, and store it through `Event.RecordMarking`. Report
  it in `pReports` like its siblings.
- `src/OcuPilot/Api/Switches.cls` -- `HandleRestraint` adds one key,
  `writesMarked`, from `Event.WritesMarked()`. The verdict itself is untouched: marking is not a
  restraint (AD-30), so `Kernel/Restraint.cls` is not edited.
- `src/OcuPilot/Kernel/State/Ledger.cls` -- add `KINDWRITE = "write"`, `STATUSPENDING = "pending"`,
  `Property AuditMarked As %String(MAXLEN = 16)` (`""` pending, then `marked`, `not-marked` or
  `not-marking`), `Property Fields As %String(MAXLEN = 512)` with its own truncation flag, and
  `Property PairsSense As %String(MAXLEN = 16)` (`checked` | `declared` | `route` | `none`; `""` on a
  legacy row). Add `GuardedFinalize(pLedgerKey, ...)` beside `GuardedAppend`, using the same
  row-versioned guarded save. No `SCHEMAVERSION` move -- every pre-existing row reads `""`, which is
  today's withholding answer; record that reasoning at the change.
- `src/OcuPilot/Kernel/Audit/Ledger.cls` -- add `OpenConfirmedWrite(...)` (the `pending` row, opened
  before the port call on the proposal's `TurnKey` at the next seq) and `FinalizeConfirmedWrite(...)`
  (status, code, canonical target, sent field names, evaluated pairs, marker outcome). Thread
  `pPairsSense` through `RecordProviderCall` (`route`), `RecordToolCall` and `GuardedAppend`; a
  writer that resolved its pairs and found none passes `none`. Change `ViewForUser`'s `:466` arm:
  `none` is readable cross-user, every other sense with an empty or unparseable set stays withheld,
  truncation stays withheld. Add `pairsSense` and `auditMarked` to `RowObject`.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls`, `src/OcuPilot/Kernel/Agent/Loop.cls` -- pass the sense at
  each of the four writers: `RecordLedger` and `RecordClientRow` `checked`, `RecordRefusedRow`
  `declared`, and `none` where the resolved set was empty.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- open the ledger row just before `:301`, emit the
  marker between `:316` and `:318`, finalize the row with what was sent, and set marking from the
  emission's own answer. `Answer` gains `auditMarked`. The write-failure branch at `:302-316`
  finalizes the row `error` and emits **no** marker. Failures of any of the three never change
  `tSC`: a write that happened is never reported as a failure (AD-15).
- `src/OcuPilot/Port/ProviderPort.cls` -- `Invoke` takes the turn owner and evaluates its pairs
  against that user's live grants with the `Dispatch.HoldsPair` idiom (`CheckUserPermission`), per
  AD-31. `InvokeDraft` is unchanged and its header says why. `Kernel/Agent/Loop.cls:211` passes
  `pUser`. (DW-1309)
- `ui/src/app/core/strings.ts` -- add `auditMarkerMarked: 'done · audit marked'` beside `:1004`
  and `auditMarkerReplySentence: 'This change was applied but not marked in the audit database.'`.
  Escapes only, never literal bytes (Rule 14).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- append the
  reply sentence as one row at the **tail** of the Fixed-strings table (epic-wide shared-append). Add
  nothing else.
- `ui/src/app/core/agent-status.ts` -- `Restraint` gains `writesMarked: boolean`, `UNRESTRAINED`
  carries `true` (an unanswered read never shows the banner), and the parser reads it with the
  existing boolean helper.
- `ui/src/app/core/turn.ts` -- `ProposalOutcome` gains `auditMarked: boolean`; `decideProposal` reads
  it off the 200 body. **DW-1348:** record the refusal for the caller even when `state` is `''` --
  keep `recordProposalState` gated on a terminal state, and publish the refusal's `code`/`reason`
  on a new per-proposal refusal surface the panel reads.
- `ui/src/app/core/proposal-view.ts` -- carry the refusal `reason` into `ProposalCardView` so the
  card can render it in the warning banner it already draws above the footer for a fingerprint
  mismatch. No new `ProposalPhase`: the row is still live.
- `ui/src/app/shell/proposal-card.ts` -- render that reason in the existing warning banner; Confirm
  and Cancel stay offered, because a restraint or a prohibited refusal can clear. (DW-1348)
- `ui/src/app/shell/panel.ts` -- fill `:217`'s reserved slot with the `auditingOffBanner` sentence
  alone (wrapper div plus inner `@if`, the `lock` precedent, so `panel.spec.ts:280`'s slot order
  holds); stop `onCardConfirm`'s `finally` swallowing a refusal that left the row live; append the
  confirmed write's tool-call card from the confirm answer and append
  `auditMarkerReplySentence` to the reply when the marker was not written, the way
  `replyWithConfirmSentence` already appends published copy.
- `ui/src/app/shell/tool-call-card.ts` -- widen the warning channel so it is not only
  `status === 'error'`, and compose `done · audit marked` / `done · audit not marked` in
  `statusText`. The status text stays part of the accessible name.
- `src/OcuPilot/Test/AuditMarker.cls` -- the suite for the server half: every matrix row above the
  ledger rows, the drop path modeled on `AuditEvent.cls:355`, and the not-made-by-the-agent leg. It
  deletes a registration and uses `ProposalFixture.EnsureWriteTarget`, so it declares **both**
  `OCUPILOT_ALLOW_AUDIT_EVENTS` and `OCUPILOT_ALLOW_PRINCIPALS` with the refusal shape at
  `AgentWireSecurity.cls:61-63`, and re-installs the registration in `OnAfterAllTests`. Keep under
  ~500 lines.
- `scripts/ci-throwaway.sh` -- add `AuditMarker` to the `# classes:` blocks at `:202` and `:216`, or
  `ui/tools/ci.test.mjs:1731` reddens naming it.
- `src/OcuPilot/Test/LedgerSense.cls` -- the `PairsSense` suite: the three writers' senses, `none`
  readable cross-user, every other empty set still withheld, a legacy `""` row still withheld.
- `src/OcuPilot/Test/LedgerEmptyPairs.cls` -- rewrite `:116` and `:150` to the new contract and say
  in the class header that DW-1305 changed what "empty" means. Do not delete either test.
- `src/OcuPilot/Test/ProviderPortOwner.cls` -- pins DW-1309: the gate answers on the owner's live
  grants, and a revoked grant refuses even where the job's frozen roles would have passed.
- `ui/tools/turn.test.mjs`, `ui/src/app/shell/panel.spec.ts`,
  `ui/src/app/shell/tool-call-card.spec.ts`, `ui/src/app/shell/proposal-card.spec.ts` -- the client
  matrix rows: `auditMarked` parsing, the banner in its slot with the slot order unchanged, the two
  `done · …` statuses with the warning class, and the refusal reason rendered on a card whose row
  stayed live.
- `ui/browser/audit.browser-spec.mjs` -- **DW-1174:** rescope the AC2 leg. Take a UTC timestamp
  before the confirm, type it into `#ocu-audit-criterion-beginDateTime`, and assert on the rows that
  window holds -- the marker filter still narrowing to a proper non-empty subset and still overriding
  `eventSources`. Never compute a bound from the instance's whole `OcuPilot`-source count.

**Acceptance Criteria:**

- Given a confirmed write whose marker emitted, when the ledger row is read, then it is one
  `write`-kind row on the proposal's turn key whose `Status` is `ok`, whose target is the canonical
  ref, whose `Fields` names exactly the fields the port was sent with no secret-declared name among
  them, whose `PairsSense` is `checked`, and whose `AuditMarked` is `marked`.
- Given the port call raises after the claim committed, when the confirm answers, then the ledger row
  exists and is finalized `error`, no `AgentWrite` row was written, and the proposal is still
  `confirmed` and burned.
- Given the `AgentWrite` registration is deleted, when a write is confirmed, then the HTTP status is
  200, the target really changed on the instance, and the only trace of the drop is the ledger row,
  one `LogFailure` report and `auditMarked: false` on the answer -- the status the caller receives is
  unchanged from the marked case.
- **Integration AC (Rule 1).** Given the panel after that confirm, when the tool-call card for the
  confirmed write renders, then its **collapsed** line reads `done · audit not marked` and carries
  the warning class, and the reply carries `auditMarkerReplySentence`; a marked write's collapsed
  line reads `done · audit marked`. Asserted by the Angular component runner against the DOM, not by
  reading server state.
- **Integration AC (Rule 1).** Given `writesMarked` false on `GET /agent/restraint`, when any user
  opens the panel, then the `not-marked` slot renders `auditingOffBanner` and nothing else -- no
  link, no action -- and `panel.spec.ts`'s slot-order assertion still passes.
- Given a confirm refused 403 `PROHIBITED.UNAUTHENTICATED` on a row that stays `live`, when the user
  pressed Confirm, then the card shows the envelope's own written `reason` and the user can tell the
  press was refused; the card is not silently returned to its pre-press state. (DW-1348)
- Given a ledger row whose route resolved to no pairs, when an administrator holding the ledger's
  admin resource reads another user's rows, then that row is returned; given a row whose requirement
  was never resolved, it is still withheld. (DW-1305, DW-1321)
- Given a turn whose owner lost a required grant after the job spawned, when the loop calls the
  provider, then the port refuses on the owner's live grants. (DW-1309)
- Given an instance carrying thousands of `OcuPilot`-source audit rows, when `npm run test:browser`
  runs the audit spec, then its agent-marker leg passes within its timeout. (DW-1174)
- Given `bash scripts/smoke.sh`, when it runs against a throwaway with OcuPilot installed, then its
  audit-marker assertion still passes and the executed-check count is non-zero.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** **AD-15** (registration at install under OcuPilot's own Source; the
marker alongside the vendor's own change event; emission never fails and never propagates; a failed
marker surfaces as "done · audit not marked"), **AD-41** (the ledger is bounded; the row finalized
after the write, recording what was executed, secrets excluded at write time), **AD-46** (OcuPilot's
markers are ordinary, never-hidden audit rows; the ledger is per-user protected state and its
cross-user gate lives with the ledger), **AD-13 as amended by DW-1359** (the recorded ref is the
canonical spelling), **AD-31** (the turn job re-validates against the owner's live grants).
Also in force: AD-34 and AD-40 (the marker is outside the transition because the transition commits
before the port call, and no gate moves), AD-8/AD-9 as amended, AD-3 (schema-driven exclusion),
AD-12/AD-39 (one envelope, one reason per code), AD-16 (no namespace switch is added), AD-30
(marking is not a restraint), AD-17/AD-38 (install registers and observes), AD-19 (the client store
is framework-free).

**Why the marker is not `Record`.** `Event.Record` hardcodes `Scope.#SCOPEINSTANCE` (`:172`). The
proposal already stores a full AD-13 key in `TargetRef`, and Stories 5.11 and 5.13 target
namespace-scoped entities, so a marker built on `Record` would record the wrong scope for them from
the moment those tools land. `RecordAgentWrite` parses the stored key instead, which is also what
makes the marker's target and the ledger row's target the same string by construction.

**How either record locates the other.** The join is the pair *(scoped target, user)* inside a
window opened by `writtenAt`, the instance timestamp taken immediately before the port call and
carried in the marker's payload; the marker additionally carries the proposal id, so the ledger row
names the marker and the marker names the proposal. Nothing reads the vendor's row back to stamp an
id into the marker: doing so would mean querying `%SYS.Audit` on the write path, which is the exact
shape DW-1174 shows does not scale, and it would couple the write to a read the caller may not be
privileged for (AD-29).

**Why the banner reads a recorded fact rather than a live read.** "Is auditing on" lives in
`Security.System`, and "is this event enabled" in `Security.Events`; both are `%SYS`-only, verified
on `ocupilot-slot-a`, where neither class resolves in `HSCUSTOM`. The nearest `%`-package class that
*does* resolve there is `%SYS.Audit`, and it does not help twice over: it carries
`Parameter RESOURCEREQUIRED = "%Admin_Secure"`, which a panel user does not hold, and it is about
audit **records** rather than the instance flag. So the absence is established over the classes that
could plausibly answer, not over the two whose names were tried first. Reading them from the ungated restraint route would need a **third** privileged routine
application, and AD-8 and AD-9 name exactly two purposes -- so that is a spine change, not a slice
choice, and this story does not make it. The fact is therefore written by the two parties that
legitimately hold `%SYS` or the answer: **install**, which already reads the instance flag
(`Installer.cls:2991`) and every event's own `Enabled` (`:3354-3358`) and runs on every container
start (AD-17, AD-38); and **the executor**, whose emission return value is the instance's own answer
and which the AC already requires to record the condition on each write. Named limitation, accepted:
an operator who turns auditing off through the classic portal between a start and the next confirmed
write sees the banner only from that write or the next start. The two OcuPilot-visible paths --
Story 5.10's confirmed write and Story 7.4's screen toggle -- both refresh it, and
`UNRESTRAINED.writesMarked` is `true` so an unanswered read never shows the banner over a healthy
instance. **The requirement that makes the staleness acceptable, and it is a requirement rather than
a consequence: the banner's absence is never rendered as a positive claim that writes are being
marked.** Nothing in the panel, the reply or a card may say marking is working; the only positive
statement about a given write is that write's own card, which reads `done · audit not marked` when
the emission was dropped. A user in the stale window is therefore told nothing, and then told the
truth by the first write it affects -- which is different in kind from being told something that is
not so.

**Why `PairsSense` settles DW-1305 and DW-1321 together.** `EvaluateRequired` treats an empty
requirement as never held (`Gate.cls:163`, DW-1120), which is right for a refusal row and wrong for
Home's `llm` rows -- and the column cannot tell them apart because it carries three different claims.
One column recording *which claim the row makes* answers both: `none` is "the writer resolved the
pairs and there were none", so the row is readable; `checked`, `declared` and `route` with an empty
set mean the writer could not say, so the row stays withheld, as does every legacy row, whose sense
is `""`. The gate's own asymmetry at `Gate.cls:132` versus `:163` is preserved, not softened --
`EvaluateRequired` keeps answering 0 for an empty list, and it is simply no longer the only question
`ViewForUser` asks.

**Why the confirmed write's ledger row is opened before the port call.** AD-41 says the row is
finalized after the write and records what was executed. Opening it first is what makes a write that
raised mid-flight leave a trace at all: a row that only ever appears on success cannot record a
write nobody can account for. `pending` is the state that says so, and it is the one status a reader
must not read as an outcome.

**Why the refusal is rendered in the card rather than closing it.** A prohibited or restrained
refusal leaves the proposal `live` on purpose -- the condition can clear, and AD-10's refusal is
about this write, not about this proposal's validity. So the card keeps Confirm and gains the
envelope's own written `reason` in the warning banner it already draws for a fingerprint mismatch
(AD-39: the server's words, not a second client-authored copy). No new `ProposalPhase` is added,
because a phase is a terminal state and this is not one.

**Integration ACs (Rule 1).** Two are named above, both exercised by the client's own tier against
the DOM.

**Consumes:** `Kernel.Proposal.Confirm` (the transition and its answer, Story 5.3);
`Kernel.State.Propose` (`TurnKey`, `ToolName`, the canonical `TargetRef`); `Kernel.EntityRef`;
`Kernel.Audit.Log.Redact`; `Screen.Tool.Registry.SecretArguments` and `Screen.Gate`;
`Kernel.State.Switch`; `Install.Installer.EnsureAuditEvents`/`EnsureAuditingEnabled`; the panel's
`GET /agent/restraint` read and its reserved `not-marked` slot (Story 4.3).

**Consumed-by:** Stories 5.8-5.13 -- every area's first confirmed write is marked by this emitter and
counted by SM-5's pairing metric, and 5.11 and 5.13 are the first namespace-scoped targets the
marker's ref must carry; Story 5.7 (the change event follows the same successful write);
Story 7.4 (the Auditing configuration screen makes this banner's link and "Turn auditing on" action
live, and its write refreshes `WritesMarked` through the same executor path);
Story 2.10's audit viewer (a new event **name** under the existing `OcuPilot` Source is picked up by
the shipped agent-marker filter with no descriptor edit -- `AuditList.cls:152` filters on
`eventSources`).

**Ledger inbox (Rule 17).** DW-1348, DW-1174, DW-1305, DW-1321 and DW-1309 are each addressed by a
matrix row and a task above. None is declined.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py <changed paths>` -- expected: clean; `New $ROLES` still only
  in `Kernel/State/Base.cls`.
- `sh scripts/ci-unit-test.sh --container ocupilot-ci --class OcuPilot.Test.AuditMarker` -- expected:
  all green. **One class per call, landed in `%UnitTest_Result` before the next** (never two test
  calls in one message). Then, one at a time: `OcuPilot.Test.LedgerSense`,
  `OcuPilot.Test.LedgerEmptyPairs`, `OcuPilot.Test.Ledger`, `OcuPilot.Test.LedgerPairs`,
  `OcuPilot.Test.LedgerWire`, `OcuPilot.Test.ProviderPortOwner`, `OcuPilot.Test.AuditEvent`,
  `OcuPilot.Test.ProposalConfirm`, `OcuPilot.Test.ConfirmRoute`, `OcuPilot.Test.SurfaceCoverage`,
  `OcuPilot.Test.EndpointCoverage`.
- `cd ui && npm run build && npm test` -- expected: the six prebuild checkers and both client tiers
  green.
- `cd ui && npm run build` then
  `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` then
  `npm run test:browser` -- expected: green, the audit spec included. The bundle must be redeployed
  before any browser result is read.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: the
  audit-marker assertion passes and the executed-check count is non-zero.

**Rule 19 mutations** (run on the runner's own throwaway `ocupilot-ci`, never the shared dev
instance; revert each and confirm `git status --short` and `git diff --stat` are unchanged):

- Marker emitted -- drop the `$System.Security.Audit` call from `RecordAgentWrite` ->
  `AuditMarker.TestAConfirmedWriteIsMarked` goes red.
- Marker never fails the write -- make the drop path set `tSC` ->
  `AuditMarker.TestADroppedMarkerNeitherFailsTheWriteNorPassesSilently` goes red.
- Only the agent marks -- emit from `Port.AdminPort.Invoke` ->
  `AuditMarker.TestAWriteNotMadeByTheAgentEmitsNoMarker` goes red.
- Row finalized after the write -- finalize before the port call ->
  `AuditMarker.TestTheRowRecordsWhatWasExecuted` goes red.
- Secrets excluded at write time -- let a secret-declared name into `Fields` ->
  the same class's field-list assertion goes red.
- `PairsSense` -- make `ViewForUser` read `none` as withheld ->
  `LedgerSense.TestARowThatNeedsNoPrivilegeIsReadableCrossUser` goes red.
- Unknown requirement still withheld -- make `ViewForUser` read `""` as `none` ->
  `LedgerSense.TestALegacyRowIsStillWithheld` goes red.
- Provider owner -- put `Gate.HoldsPrivilege` back in `ProviderPort.Invoke` ->
  `ProviderPortOwner.TestTheGateReadsTheTurnOwnersLiveGrants` goes red.
- Collapsed line -- move the status suffix into the card body ->
  `tool-call-card.spec.ts`'s collapsed-line assertion goes red.
- Banner slot -- render the banner outside `data-slot="not-marked"` ->
  `panel.spec.ts:280`'s slot-order assertion goes red.
- Refusal visible -- restore `onCardConfirm`'s unconditional `finally` ->
  `proposal-card.spec.ts`'s refusal-reason assertion goes red.
- Audit spec scope -- restore the whole-population bound ->
  the AC2 leg times out on a seeded long-lived instance (the DW-1174 reproduction).

Each mutation's outcome is recorded here as `mutation: <change> -> <test>` by whoever adds or
materially changes the pinning test.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
