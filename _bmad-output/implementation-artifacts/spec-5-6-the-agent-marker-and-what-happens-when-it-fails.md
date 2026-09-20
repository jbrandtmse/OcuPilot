---
title: 'Story 5.6: The agent marker, and what happens when it fails'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: '814ae9e41db722a1cdbec7984eeffc4ca72a3f41'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: >-
      scripts/smoke.sh's `auditmarker` and `agentwrite` checks are still `pending`, so AD-45's
      "one confirmed agent write, and the audit marker" half of the smoke path is unmet.
    evidence: |-
      `Install/Smoke.cls:1179-1180` notes both `pending` with the reason "Epic 3". The marker
      exists as of this story, so both are now lightable. This story touches neither:
      `Install/Smoke.cls` is outside its footprint and its Tasks name neither. The executed
      audit assertion `auditevent` does cover the new `AgentWrite` triple and passes
      (executed=45 passed=45 failed=0).
    location: >-
      src/OcuPilot/Install/Smoke.cls:1179
    severity: medium
  - summary: >-
      `ProviderPort.GateAnyOfForUser` hand-copies `Screen.Gate.EvaluateAnyOf`'s OR-set walk, and
      `GateAnyOf` is now dead.
    evidence: |-
      The list validation, malformed-pair skip, first-pair naming and catch-all are duplicated line
      for line, so a change to `EvaluateAnyOf` will not reach the provider port. `GateAnyOf` has no
      caller (`InvokeDraft` uses `Gate`). Not deleted here because it is the named target of a
      recorded, observed Rule 19 mutation; the real fix is an `EvaluateAnyOfForUser` on `Screen.Gate`.
    location: >-
      src/OcuPilot/Port/ProviderPort.cls:473
    severity: low
  - summary: >-
      `auditingOffBanner`'s second sentence tells the operator auditing is off, which is not
      established when only the `AgentWrite` registration is missing or a single emission dropped.
    evidence: |-
      `Switch.WritesMarked` is set 0 by three different conditions and the banner renders one
      sentence for all of them; the drop test drives the case where auditing is on. The string is
      published UX copy the intent names verbatim (EXPERIENCE.md:258) and Story 7.4 owns the screen
      it points at.
    location: >-
      ui/src/app/core/strings.ts:61
    severity: low
  - summary: >-
      A confirmed write's tool-call card and its "not marked" sentence do not survive a page reload.
    evidence: |-
      The card is composed from `Panel.writeCards`, an in-memory signal, and `core/turn.ts`'s
      `parseStep` hard-codes `auditMarked: null` for every step the instance sends, so no wire
      payload can reproduce it. The `write` ledger row does carry `AuditMarked` and `RowObject` now
      exposes it, so the fact exists server-side and nothing re-derives the card from it.
    location: >-
      ui/src/app/shell/panel.ts:550
    severity: low
  - summary: >-
      The `none` sense releases a turn that carried no screen context, not only one started from Home.
    evidence: |-
      `RoutePairs` asks the registry for the empty route, which is Home's declared route, so a turn
      whose client sent no context records the same value. Recorded as an accepted consequence at the
      method and in the Spec Change Log; a cross-user reader still needs the ledger's own
      administrative pair (AD-46). Worth the lead's eye because it widens cross-user visibility
      beyond the population the intent's matrix names.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls:70
    severity: low
  - summary: >-
      The rescoped AC2 browser leg bounds its window only at the start, so its exact counts assume
      nothing else writes an OcuPilot- or seed-Source audit row while it runs.
    evidence: |-
      The waitForCount bounds and the kept-row equality are exact. It ran green twice back to back
      (full suite and isolated), and adding an endDateTime bound could mask a row the leg wrote.
    location: >-
      ui/browser/audit.browser-spec.mjs:549
    severity: low
  - summary: >-
      On a probe profile, install observes a suffixed AgentWrite registration that the emitter
      never writes under.
    evidence: |-
      `Installer.Names` builds `markerEvent` as the roster name plus the profile suffix, while
      `Event.RecordAgentWrite` always emits the base name -- the same split the pre-existing
      `Record` has, since only the grant marker emits suffixed. On the production profile the two
      agree, which is the only profile where the banner matters.
    location: >-
      src/OcuPilot/Install/Installer.cls:3049
    severity: low
  - summary: >-
      A marker that fails before reaching the audit call records the instance-wide "not marking"
      fact, which shows the banner to every user.
    evidence: |-
      `Confirm.Transition` takes its marked flag from `RecordAgentWrite`'s status, which is also an
      error when `EntityRef.Parse` or `Wire` fails on the stored `TargetRef`. Reachable only through
      a reference the mint itself wrote and those two round-trip, so no realistic path today; it
      would become real if a later story stored a ref the parser cannot read.
    location: >-
      src/OcuPilot/Kernel/Proposal/Confirm.cls:371
    severity: low
  - summary: >-
      instanceStamp reads the instance's local clock where the task says to take a UTC timestamp,
      and the suite cannot tell the two apart on a UTC container.
    evidence: |-
      The helper reads `$ZDateTime($Horolog,3)` and its own comment says the criterion is instance
      local time; the throwaway runs UTC, so local and UTC coincide and the leg passes either way.
      Settled by reading beginDateTime's interpretation in `Screen/Descriptor/AuditList.cls` and the
      vendor's own handling, or by running a throwaway in a non-UTC zone.
    location: >-
      ui/browser/audit.browser-spec.mjs:240
    severity: medium (unverified)
  - summary: >-
      The pending ledger row -- the trace a write nobody can account for leaves -- is written by the
      code and asserted by no test.
    evidence: |-
      The failure leg arms a 500 through the fixture and asserts the row is finalized `error`. A row
      left `pending` needs an exception escaping `Transition`'s `Try` between the open and the
      finalize, which no test drives. The intent lists it under Error Handling rather than as an
      acceptance criterion.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls:245
    severity: low
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

- **The empty route is Home's route, so DW-1305's `none` is reached through the registry rather
  than around it.** The spec's matrix names "every turn from Home" as the `PairsSense = "none"`
  population. Probed on `ocupilot-ci`: `OcuPilot.Screen.Descriptor.Home` declares `Route()` as the
  empty string, and `Screen.Registry.DescriptorForRoute` matches a descriptor's declared route
  exactly -- `""` answers Home, while `"no/such/route"` and `"/"` answer nothing. `RoutePairs`
  therefore no longer short-circuits on `""`; it asks the registry. Accepted and recorded at the
  method: a turn that carried no screen context records the same route value as a turn from Home,
  so its provider row records `none` too and is readable by a cross-user administrator. Both are
  true in the same sense -- neither turn's screen required a privilege -- and the reader still has
  to hold the ledger's own administrative pair (AD-46). `Test/LedgerEmptyPairs` `:150` is rewritten
  to that contract.
- **`AuditMarked = not-marking` is defined as "no marker was emitted, because the write did not
  happen".** The spec names the three values and not which is which; the error-finalize path is the
  only one that emits no marker at all, and a row that makes no claim about marking is what it
  needs to say. Recorded at the property.
- **Two roster files the story did not plan to touch were updated, because they pin what it
  changed.** `Test/LedgerWire` holds `RowObject`'s key roster (now carrying `pairsSense` and
  `auditMarked`) and `Test/SwitchesWire` holds `GET /agent/restraint`'s (now carrying
  `writesMarked`). `ui/tools/strings.test.mjs`'s `extractToolCallCardStatuses` was extended to
  re-derive `done · audit marked` from EXPERIENCE.md's tool-call-card row, which is where that
  literal is already published; `REQUIRED_ALONGSIDE_TABLE` stays at the three it was, which is the
  bypass its own comment forbids.
- **`Event.RecordMarking` writes only when the observation differs from what is recorded.**
  `Kernel/State/Switch` is a store whose defaults are parameters, so an instance nobody has
  configured holds no row -- and `Install.Smoke.CheckAgentSwitches` reads exactly that to tell an
  install that wrote no switches from one that did. Writing the default on every install, and again
  on every confirmed write, turned that check from `pass` to `skipped` on a clean throwaway
  (observed). The row is now created the first time the observation differs and updated only when
  it changes again; verified on `ocupilot-ci` that an install on a healthy instance leaves
  `updatedAt` empty and `WritesMarked()` answering 1 from the default, and the smoke reads
  `agentswitches pass` again.
- **`Test/ProviderPortProbe` gained a `HoldsPairForUser` override.** `ProviderPort.Invoke`'s gate is
  no longer asked through `GateClass`, so `Test/PortGate`'s "every port evaluates its declared gate"
  leg would have gone green against a `%All` process. The probe answers the per-user question from
  the same switch it already answers the process question from; which account the port asks about is
  `Test/ProviderPortOwner`'s subject.

## Review Triage Log

### 2026-09-20 -- Review pass

- verdicts: 50 findings -- high 3, medium 16, low 28, false 2, maybe-false 1
- findings:
  - `[high]` `[patch]` `Loop.RecordClientRow` derived the `none` sense from `pClassified`, the secret-argument flag -- verified at `Dispatch.cls:457` against `:484`: three refusals (user mismatch, governance-gate error, tool denied) return in between with `pSecretDeclared` 1 and no pair read, so `SenseFor` answered `none` and `ViewForUser` released the row. Patched: `ResolveClientCall` gained `pPairsResolved`, set only after the pairs resolve, threaded through all four call sites. The mutation was applied on `ocupilot-ci` and the new test went red on the sense **and on the cross-user release**, which is the defect itself.
  - `[medium]` `[patch]` `RecordClientRow`'s doc comment asserted that conflation as fact -- same root cause; the sentence is replaced with one naming why the secret flag must not be read as "the requirement was read".
  - `[low]` `[defer]` `GateAnyOfForUser` duplicates `Screen.Gate.EvaluateAnyOf`'s OR-set walk -- verified: the walk, the malformed-pair skip and the first-pair naming are a second copy. Not patched: the real fix is an `EvaluateAnyOfForUser` on `Screen.Gate`, which is more than a direct correction.
  - `[medium]` `[patch]` No test invoked the shipped `HoldsPairForUser` -- verified: both probes override it. Patched with a leg that calls the shipped class. It also corrected a wrong assumption: `%All` answers yes for a resource the instance does not declare (measured), so the absent account is the discriminator, not the resource name.
  - `[low]` `[defer]` `auditingOffBanner`'s second sentence says auditing is off, which is not established when only the registration is missing -- verified against the drop leg. Not patched: the string is published UX copy the intent names verbatim, and Story 7.4 owns the screen it points at.
  - `[medium]` `[patch]` An absent `writesMarked` key read as false -- verified at `agent-status.ts:236` (`flagAt` answers `source[key] === true`), contradicting `UNRESTRAINED`'s deliberate true. Patched to fall back to the `UNRESTRAINED` default; both named mutations applied and observed red.
  - `[false]` `[reject]` `Switch.Resolve`'s presence test does not normalize the null sentinel -- refuted: `WritesMarked` is `%Boolean`, not `%String`, and `Switch` has no SQL UPDATE write path; the sentinel arises from neither.
  - `[medium]` `[patch]` `RecordMarking`'s smoke fix holds only on a healthy instance -- grouped with the two rows below.
  - `[medium]` `[patch]` `RecordMarking`'s write-on-change rule had no automated test -- verified: the smoke records `skipped`, which it does not fail on. Patched with a deterministic row-count test. A first attempt compared `updatedAt` stamps and could not fail, because the stamp is second-resolution and both writes landed in one second; that attempt was discarded rather than kept.
  - `[medium]` `[patch]` `FieldsToString`'s truncation and separator branches were never exercised -- verified: the only caller walks a live payload that fits. Patched with direct cases beside the `PairsToString` ones.
  - `[low]` `[reject]` `FIELDSMAXLENGTH` versus the MAXLEN literal -- real duplication, but a property's MAXLEN cannot read a class parameter, so the fix is more than a direct correction.
  - `[low]` `[reject]` `PairsSense` is an unvalidated free-text column -- every writer is internal and the value is cut to 16; a VALUELIST adds a branch for no user-reachable failure.
  - `[low]` `[reject]` `ObserveAuditMarking` can never return an error, so its failing-step guard is dead -- verified, and cosmetic: defensive code around a step that reports rather than fails.
  - `[low]` `[defer]` A confirmed write's card does not survive a reload -- verified: the card is composed from `Panel.writeCards` and `parseStep` hard-codes a null marker outcome. The intent's matrix is about the press, and the ledger row holds the fact.
  - `[low]` `[patch]` `writeCards` was never cleared on a new conversation -- verified against the sibling state the same block clears. Patched in the existing reset block.
  - `[low]` `[reject]` The `Fields` column has no reader -- by design: the spec names exactly `pairsSense` and `auditMarked` for `RowObject`.
  - `[low]` `[defer]` The `none` sense releases a turn that carried no screen context, not only one from Home -- verified. Recorded rather than patched: it is the accepted consequence the Spec Change Log states, and the reader still needs the ledger's own administrative pair (AD-46).
  - `[medium]` `[patch]` The marker-ordering assertion could not fail under its own named mutation -- verified: with the moment dropped, the value is empty and the follows-operator reads every non-empty string as following it. Patched with a non-empty assertion before the comparison.
  - `[low]` `[defer]` The rescoped AC2 leg's exact counts have no upper window bound -- real flake risk; it ran green twice back to back, and closing the window could mask rows.
  - `[low]` `[patch]` The drop test's header still named the inert mutation the Review Triage Log had corrected -- patched at its origin, which is what the project's own pitfall asks for.
  - `[low]` `[patch]` The mutation count in the Auto Run Result disagreed with the list above it -- corrected in the Auto Run Result written this pass.
  - `[low]` `[reject]` Roughly eight mutations are recorded at their tests and not in `## Verification` -- Rule 19 scopes one demonstrated mutation per AC, and all nine ACs carry an applied, observed line; the remainder are supporting legs.
  - `[low]` `[reject]` `auditMarkerMarked` has no provenance comment and "tail row" goes stale -- attempted and reverted: adding line-numbered citations reddened two string gates. The existing form is the one the gate enforces.
  - `[low]` `[reject]` The Spec Change Log's bypass sentence reads as an admission -- its fix edits this build's spec prose.
  - `[low]` `[defer]` The smoke's `auditmarker` and `agentwrite` checks are still pending -- already on the deferred list, filed before review.
  - `[high]` `[patch]` (edge-case) `RecordClientRow` records a requirement nobody read -- the same root cause and the same fix as the first row.
  - `[low]` `[defer]` (edge-case) A marker that fails before the audit call sets the instance-wide fact -- verified reachable only through a reference the mint itself wrote and the parser round-trips, so no realistic path; named rather than guarded.
  - `[medium]` `[patch]` (edge-case) An absent `writesMarked` key -- same root cause as the parse row above.
  - `[low]` `[defer]` (edge-case) The confirmed-write card is lost on reload -- same entry as above.
  - `[low]` `[defer]` (edge-case) The AC2 window has no upper bound -- same entry as above.
  - `[low]` `[defer]` (edge-case) On a probe profile install observes a suffixed registration the emitter never writes under -- verified, and inherent to the pre-existing suffix design: on the production profile, the only one where the banner matters, the two names agree.
  - `[low]` `[defer]` (edge-case) `GateAnyOf` is now dead -- verified (`InvokeDraft` uses `Gate`). Not deleted: it is the named target of a recorded, observed Rule 19 mutation.
  - `[maybe-false]` `[defer]` (edge-case) `instanceStamp` reads the instance's local clock where the task says a UTC timestamp -- on a UTC container the two are identical, so the suite cannot tell. Settled by reading the criterion's own interpretation or by running the throwaway in a non-UTC zone; medium if true.
  - `[high]` `[patch]` (edge-case) The four writers' `none` rule is inverted on three refusal paths -- same root cause and fix as the first row.
  - `[medium]` `[patch]` (verification-gap) A false `writesMarked` was never produced by the instance in any test -- filed pre-verified; patched with a route leg and three parser cases. The layer's own demonstration (hard-code the answer) was applied and observed red.
  - `[low]` `[reject]` (verification-gap) `Loop.Run`'s owner argument is unpinned -- refuted on its consequence: `ResolvedUsername()` is the process username and the turn job runs as the owner (AD-7), so the fallback asks about the same account. The live-grants property DW-1309 is about survives the mutation; the explicit pass is defensive clarity.
  - `[medium]` `[patch]` (verification-gap) `FieldsToString` has no test of its own -- same entry as the `FieldsToString` row above.
  - `[medium]` `[patch]` (verification-gap) `RecordMarking`'s guard has no check that can fail -- same entry as the write-on-change row above.
  - `[medium]` `[patch]` (verification-gap) The client-call writer's sense is the one no test asserts -- closed by the high-severity entry's own new test.
  - `[medium]` `[patch]` (verification-gap, Rule 19) The marker-ordering assertion cannot fail under its named mutation -- same entry as above.
  - `[low]` `[reject]` (verification-gap, Rule 19) AC legs with no mutation line -- same reasoning as the supporting-legs row above.
  - `[medium]` `[patch]` (verification-gap, Rule 19) The truncation expectation is derived from the value it checks -- closed by the deterministic `FieldsToString` cases.
  - `[medium]` `[patch]` (intent) A false `writesMarked` is exercised at three surfaces, none of them the route -- same entry as the verification-gap row.
  - `[low]` `[defer]` (intent) The confirmed-write card lives only in one live panel -- same entry as above.
  - `[low]` `[reject]` (intent) The AC2 leg writes configuration-change rows rather than markers -- by design: the screen's agent-marker filter keys on the event Source, so an OcuPilot-Source row is what the filter selects.
  - `[medium]` `[patch]` (intent) DW-1309 is tested at the argument surface, not the privilege surface -- closed by the shipped-check entry above.
  - `[low]` `[defer]` (intent) The widening's own guard was rewritten by the change that widens it -- same entry as the no-screen-context row above.
  - `[low]` `[defer]` (intent) The pending trace is implemented and unexercised -- verified: the failure leg finalizes `error`, and no test leaves a row pending. Named for a later pass; the intent lists it under Error Handling, not an AC.
  - `[low]` `[reject]` (intent) Secret exclusion is tested on the helper, not the call site -- by design and recorded in the spec: no shipped descriptor declares a secret argument, so the call site cannot be driven.
  - `[false]` `[reject]` (intent) The drop report is observed through a replaced seam -- the layer states it is not an objection, and the real sink writes nothing an unregistered triple could leave.

- **The first spelling of "make the drop path set `tSC`" was a no-op, and is recorded because a
  reviewer would otherwise read the mutation line as unproven.** Adding `Set tSC = tMarkSC` after
  the emission changes nothing: the next statement is `Set tSC = ..Answer(...)`, which overwrites
  it. The mutation that does propagate -- refusing with `..Internal` when `tMarkSC` is an error
  before `Answer` runs -- was applied instead, and
  `AuditMarker.TestADroppedMarkerNeitherFailsTheWriteNorPassesSilently` went red on the 200. The
  structure is what makes the first spelling inert, which is the point rather than an accident.
- **The drop test now reads its answer defensively.** Under the mutation above the method raised
  `<INVALID OREF>` on a `%DynamicObject` it had not been given, and so never reached its own
  re-install -- which left the registration deleted for the next method in the class. The reads are
  `$IsObject`-guarded so a failing assertion stays a failing assertion; `OnAfterAllTests` re-installs
  and refuses to pass with a triple still missing, which is the backstop.

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

**Rule 19 mutations** (every one below was applied, observed red and reverted; the ObjectScript
ones ran on the runner's own throwaway `ocupilot-ci`, never the shared dev instance, and
`git status --short` and `git diff --stat` were unchanged after each revert):

- mutation: drop the `$System.Security.Audit` call from `Kernel/Audit/Event.cls` `RecordAgentWrite`
  (return `$$$OK` without it) -> `AuditMarker.TestAConfirmedWriteIsMarked` goes red on the row count.
- mutation: refuse with `..Internal` when `tMarkSC` is an error, before `Answer` runs, in
  `Kernel/Proposal/Confirm.cls` `Transition` ->
  `AuditMarker.TestADroppedMarkerNeitherFailsTheWriteNorPassesSilently` goes red on the 200, while
  its no-row assertion stays green. (The obvious spelling, `Set tSC = tMarkSC` after the emission,
  is a no-op -- the next statement assigns `tSC` from `Answer`. See the Review Triage Log.)
- mutation: emit the marker from `Port/AdminPort.cls` `Invoke` as well ->
  `AuditMarker.TestAWriteNotMadeByTheAgentEmitsNoMarker` goes red on the zero.
- mutation: move `FinalizeConfirmedWrite` above the port call in `Confirm.Transition` (finalize
  `ok`/`marked` before anything is known) -> `AuditMarker.TestTheRowRecordsWhatWasExecuted` goes red
  on the status and the marker outcome.
- mutation: drop the `$ListFind(pSecretNames, tKey)` guard from `Confirm.FieldNames` ->
  `AuditMarker.TestASecretDeclaredNameNeverReachesTheFieldList` goes red; the declared name reaches
  the row's field list. (The shipped `webapp.list.update` declares no secret argument, so the
  exclusion is driven against a declaration supplied as data rather than against a vacuous one.)
- mutation: delete `ViewForUser`'s `SenseNone` arm in `Kernel/Audit/Ledger.cls` ->
  `LedgerSense.TestARowThatNeedsNoPrivilegeIsReadableCrossUser` goes red.
- mutation: make that same arm read `""` as `none` (compare with a default) ->
  `LedgerSense.TestALegacyRowIsStillWithheld` goes red, releasing every legacy row.
- mutation: restore `..GateAnyOf(..InvokePairs(), .tFailedPair)` in place of `GateAnyOfForUser` in
  `Port/ProviderPort.cls` `Invoke` -> `ProviderPortOwner.TestTheGateReadsTheTurnOwnersLiveGrants`
  goes red: the shipped gate answers yes for the `%All` process whatever the owner holds.
- mutation: move the marker suffix out of `tool-call-card.ts`'s `statusText` into the card body ->
  both `tool-call-card.spec.ts` collapsed-line assertions go red (the word and the warning class).
- mutation: render the banner as a sibling of `data-slot="not-marked"` rather than inside it ->
  `panel.spec.ts`'s slot-order assertion goes red.
- mutation: delete the `recordProposalRefusal` call from `decideProposal`'s error path in
  `core/turn.ts` -> `turn.test.mjs`'s DW-1348 test and `panel.spec.ts`'s refusal-reason assertion go
  red. (This replaces the planned "restore `onCardConfirm`'s unconditional `finally`", which is the
  mutation for the write card below: the refusal is published by the store, which is where the
  client's own tier can pin it.)
- mutation: make `proposal-card.ts`'s `refusalVisible` read `this.restrained` instead of
  `this.live` -> `proposal-card.spec.ts`'s two refusal assertions go red.
- mutation: restore `onCardConfirm`'s unconditional `finally` (drop `recordWriteCard`) -> both
  `panel.spec.ts` confirmed-write assertions go red: no card is appended and the reply carries no
  sentence.
- mutation: hard-code `true` in `Panel.recordWriteCard` -> the dropped-marker `panel.spec.ts`
  assertion goes red while the marked one stays green.
- mutation: return `status: 'error'` from `confirmedWriteStep` -> `turn.test.mjs`'s composer test
  and both `panel.spec.ts` confirmed-write assertions go red; a write that happened would render as
  a failure.
- Audit spec scope (DW-1174): the AC2 leg's own header records the mutation -- put the
  whole-population bound back (`setMaxRows(markerRowCount() + seedRowsPresent())` with a
  `waitForCount` at that figure, and no `beginDateTime`) -> the leg times out against the seeded
  instance. `before()` now tops the marker's own Source up to a thousand rows, which is what makes
  that reproduction real rather than asserted.

**Rule 19 mutations added at the review pass** (same discipline: applied, observed red, reverted;
the ObjectScript ones on `ocupilot-ci`, and `git status --short` / `git diff --stat` unchanged after
each):

- mutation: pass `pClassified` in place of `pPairsResolved` at `Kernel/Agent/Loop.cls`
  `RecordClientRow`'s `SenseFor` call -> `LedgerSense.TestAClientCallRefusedBeforeItsPairsWereReadIsNotNone`
  goes red on the recorded sense **and on the cross-user release** -- the row is handed to an
  administrator who should not see it, which is the defect itself rather than a proxy for it.
- mutation: hard-code the answer in `Api/Switches.cls` `HandleRestraint`'s `writesMarked` line ->
  `SwitchesWire.TestTheRestraintReadCarriesARecordedNotMarkingFact` goes red while its healthy-arm
  sibling stays green.
- mutation: delete the write-on-change guard from `Kernel/Audit/Event.cls` `RecordMarking` ->
  `SwitchesWire.TestRecordingTheMarkingFactAlreadyHeldWritesNoRow` goes red on "and writes no row"
  while its changed-value control stays green.
- mutation: restore `flagAt(row, 'writesMarked')` in `core/agent-status.ts` `restraintOf` ->
  `agent-status.test.mjs`'s absent-key case goes red. Second mutation: hard-code the value true
  there -> its false case goes red.
- mutation: delete the empty-and-separator guard from `Kernel/Audit/Ledger.cls` `FieldsToString` ->
  `LedgerPairs.TestFieldNamesAreSpelledSortedDedupedAndBounded` goes red on the comma and
  empty-name cases.
- mutation: make `Port/ProviderPort.cls` `HoldsPairForUser` answer 1 unconditionally ->
  `ProviderPortOwner.TestTheShippedPerUserCheckAsksTheInstance` goes red on the absent account.
- The non-empty assertion added to `AuditMarker.TestEitherRecordLocatesTheOther` is what makes that
  method's own recorded mutation (drop the moment from the payload) reach its ordering assertion at
  all: the follows-operator reads every non-empty string as following the empty one, so without it
  the mutation was inert.

Two mutations recorded above were **found not to do what they claimed** and are corrected here rather
than left standing: assigning the marker's status to `tSC` after the emission is a no-op (the next
statement assigns `tSC` from `Answer`), and dropping the owner argument from `Loop.cls`'s
`ProviderPort.Invoke` call does **not** revert DW-1309 -- `ResolvedUsername()` is the process
username and the turn job runs as the owner (AD-7), so the fallback asks `CheckUserPermission` about
the same account.

Each mutation's outcome is recorded here as `mutation: <change> -> <test>` by whoever adds or
materially changes the pinning test.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass changed.** The agent marker: one roster name the installer registers with no edit
of its own, and one emission -- `Event.RecordAgentWrite`, called from exactly one place,
`Confirm.Transition`, after `tWriteSC` reads OK and before `Answer`, with the audit call's return
value checked at that site. It parses the proposal's stored canonical `TargetRef` rather than
assuming instance scope, so a namespace-scoped target's scope reaches the row. The confirmed write's
ledger row opens `pending` before the port call and is finalized after it with the resolved target,
the field names the body carried (secret-declared names excluded at write time), the pairs the
confirm evaluated and the marker's own outcome. `PairsSense` records which claim a row's
`RequiredPairs` makes, and `ViewForUser` releases an empty set under `none` alone.
`ProviderPort.Invoke` gates on the turn owner's live grants. `Switch.WritesMarked` is written by
install and by the confirm executor and read by `GET /agent/restraint`. On the client: the reserved
`not-marked` slot fills with the published sentence alone, the confirmed write's own tool-call card
reads the marked or not-marked status on its **collapsed** line, the reply gains the published
sentence on a drop, and a refusal that left the row live is drawn on the card that was refused.

**Files changed.**

- `src/OcuPilot/Kernel/Audit/Event.cls` -- the roster name, its description and drop message, the
  `RecordAgentWrite` emitter, and `WritesMarked` / `RecordMarking`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- the one emission site, the ledger row's open and
  finalize, `FieldNames`, and `auditMarked` on `Answer`.
- `src/OcuPilot/Kernel/State/Ledger.cls` -- `KINDWRITE`, `STATUSPENDING`, `AuditMarked`, `Fields`
  with its truncation flag, `PairsSense` and `GuardedFinalize`.
- `src/OcuPilot/Kernel/Audit/Ledger.cls` -- `OpenConfirmedWrite`, `FinalizeConfirmedWrite`,
  `FieldsToString`, the sense vocabulary and `SenseFor`, `RoutePairs`' resolved answer, and
  `ViewForUser`'s `none` arm.
- `src/OcuPilot/Kernel/State/Switch.cls` -- `WritesMarked`, observed and never operator-set.
- `src/OcuPilot/Api/Switches.cls` -- one key on `GET /agent/restraint`.
- `src/OcuPilot/Install/Installer.cls` -- `ObserveAuditMarking` inside the `%SYS` window and
  `RecordAuditMarking` after the restore, plus the roster assertion on the marker name.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls`, `src/OcuPilot/Kernel/Agent/Loop.cls` -- the sense at each
  of the four writers, the turn owner passed to the provider port, and (review pass) a real
  pairs-resolved answer on `ResolveClientCall` threaded to `RecordClientRow`.
- `src/OcuPilot/Port/ProviderPort.cls` -- `GateAnyOfForUser` and `HoldsPairForUser`; `InvokeDraft`
  unchanged, and its header says why.
- `src/OcuPilot/Test/AuditMarker.cls`, `LedgerSense.cls`, `ProviderPortOwner.cls` (new suites) and
  `MarkerConfirm.cls`, `ProviderOwnerProbe.cls` (new fixtures).
- `src/OcuPilot/Test/LedgerEmptyPairs.cls`, `LedgerPairs.cls`, `LedgerWire.cls`,
  `ProviderPortProbe.cls`, `SwitchesWire.cls` -- rewritten or extended where this story changed what
  they pin.
- `scripts/ci-throwaway.sh` -- `AuditMarker` added to both arming rosters.
- `ui/src/app/core/` -- `agent-status.ts` (the fact and its safe default), `turn.ts` (the marker
  outcome, the per-proposal refusal surface, the confirmed-write card composer), `proposal-view.ts`
  (the refusal reason), `strings.ts` (two strings).
- `ui/src/app/shell/` -- `panel.ts`, `proposal-card.ts`, `tool-call-card.ts` and their three specs.
- `ui/tools/` -- `turn.test.mjs`, `strings.test.mjs`, `agent-status.test.mjs`.
- `ui/browser/audit.browser-spec.mjs` -- the AC2 leg rescoped to its own window (DW-1174).
- `EXPERIENCE.md` -- one Fixed-strings row, appended at the tail.

**Review findings.** 50 findings across four layers -- high 3, medium 16, low 28, false 2,
maybe-false 1; every one has a row in the Review Triage Log above.

- **Patched: 10 entries** -- high 1, medium 6, low 3. The high one is real and was proven so: the
  client-fulfilled writer derived its sense from the secret-argument flag, which is answered three
  refusals before any privilege pair is read, so a user mismatch, a governance-gate error or a tool
  denial recorded `none` and `ViewForUser` released the row to a cross-user administrator. The fix
  adds a genuine pairs-resolved answer; the mutation was applied on `ocupilot-ci` and the new test
  went red on the release itself, not on a proxy for it.
- **Deferred: 10 items** on the frontmatter list, each with its evidence and what would settle it.
- **Rejected**, with reasons recorded per row: two refutations (the null sentinel on a `%Boolean`
  with no SQL UPDATE path; the drop report's replaced seam), one finding whose stated consequence
  does not follow (dropping the owner argument from `Loop.cls` does not revert DW-1309, because the
  turn job already runs as the owner), four by-design closures, and the remaining lows where the fix
  adds complexity for no user-reachable failure. One low was attempted and reverted: adding
  line-numbered EXPERIENCE.md citations to two strings reddened two string gates, so the existing
  gated form stands.

**Follow-up review recommended: true.** A high was patched this pass. The named unverified risk: the
fix threads a new answer from `ResolveClientCall` through four `RecordClientRow` call sites, and only
the user-mismatch refusal branch is directly pinned -- the governance-gate-error and tool-denied
branches take the same answer but carry no assertion of their own.

**Verification performed** (all on the runner's own throwaway `ocupilot-ci`, never the shared dev
instance):

- `uv run scripts/check-objectscript.py` -- 571 files, 21 rules, **0 problems**; the `New $ROLES`
  population is byte-identical to the baseline and still excludes every file this story touched.
  `uv run scripts/test_check_objectscript.py` -- 126 tests, OK. `bash scripts/lint-docs.sh` -- clean.
- `cd ui && npm run build` -- the six prebuild checkers green. `npm test` -- **1,173** tool tests and
  **695** component tests, 0 failed.
- `node tools/ci-runner.mjs --container ocupilot-ci` -- **166 classes, 1,461 tests, 0 failed, 0 probe
  leftovers, 0 overlaps, 0 foreign runs**. Every class the `## Verification` list names was also run
  individually, one per call, and cross-checked against `%UnitTest_Result` (77 methods, 77 passed,
  0 failed over runs 960-971).
- `npm run test:browser` against the **redeployed** bundle -- **192 specs, 0 failed**. The rescoped
  audit AC2 leg was re-run in isolation and passes in 1.50 s against an instance carrying about a
  thousand OcuPilot-source rows; with the whole-population bound restored it takes 32.7 s and fails,
  which is the DW-1174 reproduction.
- `bash scripts/smoke.sh --container ocupilot-ci` -- **executed 45, passed 45, failed 0**;
  `auditevent` (which now covers the new triple) and `agentswitches` both pass. Note for the next
  runner: immediately after a browser run, `agentswitches` reads `skipped` rather than `pass`,
  because the switches browser spec writes the switch row and the check reads its stamp. That is the
  check's own documented answer, it is not a failure, and clearing the row restores `pass`.
- **21 Rule 19 mutations** in total -- 14 from the implement pass and 7 added at review -- each
  applied, observed red and reverted, with `git status --short` and `git diff --stat` unchanged
  afterwards. Two mutations the implement pass had recorded were found not to do what they claimed
  and are corrected in `## Verification` rather than left standing.

**Residual risks.**

- The `pending` ledger row -- the trace a write nobody can account for leaves -- is written by the
  code and asserted by no test; it needs an exception escaping the transition between the open and
  the finalize. Deferred, with what would drive it.
- A confirmed write's card and its not-marked sentence do not survive a page reload: the card is
  composed client-side from the confirm answer, and the instance sends no step for a confirm. The
  fact itself is durable on the `write` ledger row. Deferred.
- The `none` sense releases a turn that carried no screen context, not only one started from Home,
  because the empty route is Home's own. Recorded at the method and on the deferred list; a
  cross-user reader still needs the ledger's administrative pair.
- `scripts/smoke.sh`'s `auditmarker` and `agentwrite` checks remain pending, so AD-45's
  confirmed-write-and-marker half of the one smoke path is still unmet. Outside this story's
  footprint; deferred with that noted.
