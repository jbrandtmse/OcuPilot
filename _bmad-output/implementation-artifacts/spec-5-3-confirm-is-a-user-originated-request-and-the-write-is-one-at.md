---
title: 'Story 5.3: Confirm is a user-originated request, and the write is one atomic transition'
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

**Problem:** Nothing confirms a proposal. `Kernel/Proposal/Write.Claim` checks six conditions and
burns nothing; `Kernel.State.Propose` writes only `live`; the card's `(confirm)` and `(repropose)`
outputs are unbound; and the wire's single `canceled` word plus `turn.ts`'s unconditional
restore-to-`expired` are correct only while every stored row is `live`. Until confirm exists, the
product's central claim — one explicit user confirmation per write, and the agent structurally
unable to approve its own proposal — is a promise rather than a property.

**Approach:** Add a confirm path that is not a tool and is not in the registry: a separate
authenticated `POST` that refuses when `Kernel.Proposal.Caller.IsTurn()` is set, accepts only the
descriptor's declared secret-typed keys, and executes the **stored** payload. Its claim is one
conditional update exactly one caller wins, which in the same transaction burns the token, writes
the terminal state and cancels the siblings on the same scoped target; every gate that decides
whether a write may happen is evaluated inside that transition, and the port call follows its
commit. The wire then carries real terminal states, so the card, the restore path and the
auto-refresh pause stop pretending every row is live.

## Boundaries & Constraints

**Always:**

- Confirm is a user-originated request: not a tool, absent from the tool registry, refused when the
  process carries the turn marker (AD-40). The barrier is explicit because AD-1 removed the HTTP one.
- The executor uses the **stored** arguments and the **stored** payload. The client sends the
  proposal id in the route and, in the body, only the fields the descriptor declared secret-typed
  for that tool. Any other key is **rejected outright, not ignored**; the identifying key is never
  accepted from the client (AD-6).
- The claim is a single conditional update on `Proposal` — `WHERE ProposalKey = ? AND Burned = 0
  AND State = 'live' AND COALESCE(RowVersion,0) = ?` — inside one `TSTART`/`TCOMMIT` that also sets
  `Burned`, `State`, `ConfirmedAt`/`ClosedReason` and cancels every other `live` row on the same
  `TargetRef`. A zero row count is the loser: refused with the row's terminal state, never retried
  (AD-34).
- Every write gate is evaluated inside that transition, before the commit: the prohibited-set seam
  (AD-10, empty until 5.5), `Restraint.Verdict` for the kill switch, enforced read-only, the
  per-user hold and the definition's read-only flag (AD-30), the declared `(resource, permission)`
  pairs (AD-8), and the fingerprint re-read (AD-6). Never at the tool call that minted the proposal.
- All five FR-17 refusals are built, each with its own code, card state and status line: **user**,
  **conversation**, **definition**, **read-only state**, **fingerprint**.
- Only the minting user can confirm. A proposal whose turn ended abnormally is unconfirmable
  (`Write.Claim`, shipped).
- Supplied secret values are merged into the payload at the port call only. They are never stored,
  never logged, never part of the re-computed digest (AD-35, Conventions › Secrets).
- Terminal state is written once and read everywhere: the wire carries `state`, `closedReason` and
  `confirmedAt`; a row past `ExpiresAt` projects as `expired` wherever it is read.
- Three Story 5.2 rulings stand: a restored **live** card is still shown expired with Re-propose;
  AD-4 governs the vendor body, not the wire; the unconditional restore override is this story's to
  replace (DW-1225).

**Never:**

- No `docker compose up`/`down`/`restart` against `ocupilot` or any `ocupilot-slot-*` container. A
  confirmed write is **never** pointed at `ocupilot`; destructive verification runs on the
  throwaway `ocupilot-ci` only.
- No edit to a contended path: `Kernel/Provider/**`, `Port/ProviderPort.cls`,
  `Kernel/{AgentRules,Egress}.cls`, **`Kernel/State/Agent.cls`**, `Api/{Definitions,Error}.cls`,
  `Screen/Tool/Registry.cls`, the named `Test/*` classes, `ui/src/app/areas/agent/definition-form.*`,
  `ui/src/app/shell/context-chip.ts`, `ui/browser/definitions.browser-spec.mjs`,
  `ui/tools/strings.test.mjs`, `README.md`. A needed change there is an `intent gap`, never an edit.
- No new slug or code in `Api/Error.cls`. Confirm's machine codes extend the `PROPOSAL.*` set
  already declared on `Kernel/Proposal/Write.cls` (Story 5.1's own home for them); `Error.Render`
  validates a code by **shape** (`IsValidCode`, `Api/Error.cls:1233`), not against a registry, so no
  contended edit is required.
- Do **not** design AD-10's prohibited set here — Story 5.5 owns it and AD-10 gives it exactly one
  home. This story places the call site only.
- No "Confirm all", no client-authored proposal field, no retry of a lost claim, no second
  sibling-cancel step outside the transition, no vendor PUT inside a `TSTART` frame.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Confirmed write | `POST /api/ocupilot/proposal/{id}/confirm`, body `{}`, live row, all gates pass, fingerprint matches | 200; row is `Burned=1`, `State=confirmed`, `ConfirmedAt` set; siblings on the same `TargetRef` are `canceled` reason `sibling`; the vendor PUT carries the stored payload | No error expected |
| Called from a turn | Same call made from a process where `Caller.IsTurn()` is 1 | 403, `code=PROPOSAL.FROMTURN`; no claim, no write | Refused before the store is read |
| Closed channel | Body carries a key that is not a declared secret-typed field, or carries the identifying key | 400, `code=PROPOSAL.CLOSEDCHANNEL` naming nothing of the value; no claim, no write | Rejected outright, never ignored |
| Not the minting user | Confirm by a different authenticated user | 403, `code=PROPOSAL.NOTYOURS`; row untouched | `Write.Claim`, shipped |
| Conversation replaced | A newer turn exists in the proposal's `ConvKey`, or the conversation was replaced | 409, `code=PROPOSAL.CONVERSATION`; card reads "Canceled — by your message" | Proactively canceled at turn start; the check is the backstop |
| Definition changed | `Agent.GuardedVersion(DefinitionId)` differs from the stored `DefinitionVersion`, or answers `""` (deleted) | 409, `code=PROPOSAL.DEFINITION` | `""` is "no row", never conflated with `0` (DW-430) |
| Read-only turned on | `Restraint.Verdict` returns a restraint between mint and confirm | 403 with the shipped restraint code (`AGENT.READONLY.ENFORCED` / `.DEFINITION` / `AGENT.KILLSWITCH.GLOBAL` / `.USER`) | Existing codes; no new slug |
| Privilege lost | A declared `(resource, permission)` pair is no longer held | 403, `code=AUTH.NOPRIVILEGE`, naming the failed pair | AD-8; evaluated in the transition |
| Fingerprint mismatch | Target re-read and re-merged digest differs | 409, `code=PROPOSAL.TARGETCHANGED`; row closes `canceled` reason `target-changed`; card shows the status line inside a warning banner above the footer and offers only Re-propose | The refusal is terminal; Re-propose is the accommodation |
| Two confirms race | Two requests claim the same live proposal | Exactly one row count of 1; the loser reads the row's terminal state and is refused with it | 409, `code=PROPOSAL.BURNED`; never retried |
| Write fails after the claim | Claim commits; `AdminPort.Invoke` returns a fault | The proposal stays `confirmed` and burned; the fault's normalized envelope is returned | Single-use holds; no automatic re-attempt |
| Expired row read | A `live` row past `ExpiresAt` is read by the turn or conversation projection | Projected `state: expired`; the client publishes `proposal-closed` and the screen's pause lifts | DW-1209; no background task needed |
| Cancel | `POST /api/ocupilot/proposal/{id}/cancel` by the minting user | Row closes `canceled` reason `you`; `proposal-closed` published | DW-1243 |

</intent-contract>

## Code Map

**Server — extend:**

- `src/OcuPilot/Kernel/Proposal/Write.cls` — six `PROPOSAL.*` parameters (`:20–38`) and
  `Claim(id, token, user, …)` (`:64`), whose header already states it evaluates no policy of its
  own and that the burn is 5.3's. Add `ClaimById` (the token is never client-supplied, so the
  confirm path resolves it from the row), the new codes, and the prohibited-set seam.
- `src/OcuPilot/Kernel/Proposal/Caller.cls` — `IsTurn()` (`:38`) over the process-private global
  `^||OcuPilotProposalCaller`, set at `Kernel/Agent/Loop.cls:133`, cleared at `:261`. A REST
  request process never ran `Set`, which is exactly the condition confirm requires.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` — `Mint` (`:66`), `Merge` (`:217`). `Merge`'s
  `tAfterType = pArgs.%GetTypeOf(tField)` (`:245`) is DW-1212's line. `PortClass()` (`:36`) and
  `StoreClass()` (`:43`) are the fixture seams.
- `src/OcuPilot/Kernel/Proposal/Fingerprint.cls` — `Of` (`:27`), `Canonical` (`:54`), the `path[]`
  exclusion spelling.
- `src/OcuPilot/Kernel/State/Propose.cls` — `STATE*` (`:23–33`), `GuardedMint` (`:141`),
  `GuardedByToken` (`:193`), `GuardedByKey` (`:208`), `GuardedRowsForTurn` (`:231`),
  `GuardedRowsForConvo` (`:262`), `RowValues` (`:311`), `WireRow` (`:348`), `NowSeconds`/`SecondsOf`.
  Neither list read compares `ExpiresAt` today (DW-1209).
- `src/OcuPilot/Kernel/State/Base.cls` — `GuardedSaveIfCurrent` (`:167`): `tNext` at `:175`, the
  conditional `UPDATE` at `:188`, the zero-row-count refusal at `:193`, and
  `Set pObject.RowVersion = tNext` at `:197` — **after** the refusal branch, so DW-412's stated
  location is wrong; the real residue is the `%Save()`-failure path, where `RowVersion` stays raised
  across `TROLLBACK 1`. Also `IsStaleSave` (`:215`), `GuardedOpenIdExclusive` (`:884`),
  `GuardedTurnSlotLock` (`:346`) — the only `LOCK` in `Kernel/State`.
- `src/OcuPilot/Kernel/Restraint.cls` — `Verdict(pUserName, pDefinitionId, …)` (`:79`),
  `Resolved(pUserName, …)` (`:175`), `DefinitionReadOnly` (`:151`, reads `Kernel.State.Agent`'s
  `ReadOnly` directly). The one public way to answer the definition's read-only flag without
  touching the contended `Kernel/State/Agent.cls`.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` — the shipped gate order (governance → restraint for
  `kind=write` at `:241` → declared pairs → schema → `Registry.InvokeTool`); the confirm transition
  re-runs the write-relevant subset rather than reusing a mint-time answer.
- `src/OcuPilot/Screen/Registry.cls` — `ConfirmChannelProblem` (`:1967`); the exclusion membership
  test against `ToolFieldRows` is DW-1205's line. `DECLARATIONKEYS` at `:368`.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — `SecretArguments()` (`:475`), `FingerprintExcludes()`
  (`:485`), `Field("toolIdentifier")` (`:453`).
- `src/OcuPilot/Port/AdminPort.cls` — `Invoke(pEndpoint, pType, ByRef pQuery, pBody, …)` (`:342`);
  `pType` resolves a `TYPE<suffix>` parameter on the vendor endpoint class, so a mutating type needs
  no new mechanism. `RunSequence` (`:760`) is where `pBody` reaches the vendor.
- `src/OcuPilot/Api/Router.cls` — `XData UrlMap` (`:72–109`), `OnPreDispatch` (`:501`). Route order
  rules are structurally enforced by `scripts/check-objectscript.py`.
- `src/OcuPilot/Api/Error.cls` (**read-only, contended**) — `Render(status, slug, reason, code,
  detail)` (`:1196`), `IsValidCode` (`:1233`, shape only), `STATECONFLICT` (`:567`), the
  `AGENT.READONLY.*` / `AGENT.KILLSWITCH.*` family (`:580–590`), `AUTH.NOPRIVILEGE` (`:111`).
- `src/OcuPilot/Api/{Turn,Conversation}.cls` — `Api.Turn.HandleProgress` (`:225`) and
  `Api.Conversation.AttachProposals` (`:102`) are the two readers of the proposals array.
- `src/OcuPilot/Test/Dispatch.cls` — `Invoke` (`:48`), `InvokeHttp500` (`:141`), `InvokeHandler`
  (`:189`); each sets `%request`/`%response` without `New` (DW-1184).
- `src/OcuPilot/Test/{Proposal,ProposalFixture,ProposalMint,ProposalScreen,ProposalWire,ProposalWrite}.cls`
  — the shipped fixtures. `ProposalFixture.Invoke` (`:74`) mirrors `AdminPort.Invoke`'s signature and
  is where a `PUT` answer is armed.

**Client — extend:**

- `ui/src/app/core/turn.ts` — `TurnProposal` (`:147`), `parseProposal` (`:324`),
  `restoredProposals` (`:365–367`, the unconditional `expired` override), `publishProposals`
  (`:921`), `newConversation` (`:745`), `endSession` (`:767`), the path builders (`:46–60`).
- `ui/src/app/core/proposal-view.ts` — `ProposalPhase` (`:79`, `target-changed` deliberately
  absent), `TERMINAL_PHASES` (`:90`), `REPROPOSABLE_PHASES` (`:104`), `phaseForState` (`:118`),
  `statusLineFor` (`:196`), `CONFIRMED_TIME_PLACEHOLDER` (`:129`), `toCardView` (`:233`).
- `ui/src/app/shell/panel.ts` — the card binding (`:319–327`, only `(cancel)` bound),
  `phaseFor` (`:745`), `liveCards` (`:799`), `cancelLiveCards` (`:815`), `onCardCancel` (`:825`),
  `syncTicker` (`:834`), `sendCurrentDraft` (`:1163`, the pre-cancel at `:1175`).
- `ui/src/app/shell/proposal-card.ts` — inputs (`:221–237`), outputs (`:240–246`), the status line
  (`:174–182`, both `role="status"` and `tabindex="-1"`), the focus effect (`:279–315`, the
  `heldFocus` guard at `:310`), `confirmAriaDisabled` (`:488`), the Re-propose button (`:206–213`,
  no `aria-disabled`).
- `ui/src/app/core/refresh.ts` — `liveProposals` (`:185`), `paused()` (`:312`), `sweepExpired`
  (`:507`), `onBusEvent` (`:608`). No change expected; it already lifts on `proposal-closed`.
- `ui/src/app/core/api.ts` — `requestJson` (`:328`), `JsonResult` (`:107`), `buildInit` (`:418`,
  Bearer only, `credentials: 'omit'`).
- `ui/src/app/core/strings.ts` — shared-append. Existing keys: `proposalStatusConfirmedBy` (`:151`),
  `…CanceledByYou` (`:153`), `…CanceledByMessage` (`:155`), `…CanceledSibling` (`:157`),
  `…Expired` (`:159`), `proposalTargetChanged` (`:67`, currently referenced by nothing in
  `proposal-view.ts`), `actionConfirm`/`actionCancel`/`actionRepropose` (`:101–103`).
- `ui/tools/strings.test.mjs` (**read-only, contended**) re-parses EXPERIENCE.md's Fixed strings
  table at run time, so a new string is added to that table and to `strings.ts` and the contended
  test is never edited.
- Build: `ui/angular.json` `outputPath` is `dist/ocupilot-ui`.

## Tasks & Acceptance

**Execution:**

**Server — the transition:**

- `src/OcuPilot/Kernel/State/Propose.cls` — add `ConfirmedAt As %String(MAXLEN=32)`,
  `ClosedReason As %String(MAXLEN=16)` (`you|message|sibling|target-changed`, empty while live),
  `DefinitionId As %String(MAXLEN=64)` and `DefinitionVersion As %String(MAXLEN=32)`; add
  `ProposalTargetIdx (TargetRef Exact, State)`. `SCHEMAVERSION` does not move — every pre-existing
  row reads the new columns as empty and, inside AD-6's ten-minute window, is already expired;
  record that reasoning at the change per the Conventions row.
- `src/OcuPilot/Kernel/State/Propose.cls` — add `GuardedClaimAndClose(pProposalKey, pExpectedVersion,
  pTargetRef, Output pWon, Output pTerminal)`: one `TSTART`/`TCOMMIT` holding the conditional
  `UPDATE … SET Burned = 1, State = 'confirmed', ConfirmedAt = ?, RowVersion = ? WHERE ProposalKey = ?
  AND Burned = 0 AND State = ? AND COALESCE(RowVersion,0) = ?` and, on a row count of 1, the sibling
  `UPDATE … SET State = 'canceled', ClosedReason = 'sibling' WHERE %EXACT(TargetRef) = ? AND
  State = 'live' AND ProposalKey <> ?`. A row count of 0 sets `pWon = 0` and reads the row's terminal
  state into `pTerminal`. Siblings are closed regardless of owning user — the target moved for
  everyone, and that is what makes the sibling state a consequence of the mechanism (AD-34).
- `src/OcuPilot/Kernel/State/Propose.cls` — add `GuardedClose(pProposalKey, pUser, pReason, Output
  pClosed)` (the `canceled` counterpart, same conditional shape) and
  `GuardedCloseLiveForConvo(pConvKey, pUser, pReason, Output pCount)`.
- `src/OcuPilot/Kernel/State/Propose.cls` — project expiry at read: `RowValues` reports
  `state = "expired"` when the stored state is `live` and `NowSeconds() > SecondsOf(ExpiresAt)`, and
  `WireRow` emits `closedReason` and `confirmedAt` alongside `state`. Flip such a row to stored
  `expired` when it is next touched by the confirm or cancel path; a scheduled retention task is
  **not** this story's (see Design Notes). Addresses DW-1209.
- `src/OcuPilot/Kernel/Proposal/Write.cls` — add `Parameter FROMTURN = "PROPOSAL.FROMTURN"`,
  `CLOSEDCHANNEL = "PROPOSAL.CLOSEDCHANNEL"`, `CONVERSATION = "PROPOSAL.CONVERSATION"`,
  `DEFINITION = "PROPOSAL.DEFINITION"`, `TARGETCHANGED = "PROPOSAL.TARGETCHANGED"`; add
  `ClaimById(pProposalId, pUser, Output pProposal, Output pCode)` resolving the stored token and
  delegating to `Claim`, so the token never crosses the wire; add
  `ClassMethod ProhibitedClass() As %String { Quit "" }` as AD-10's single call site.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` (**new**) — `Confirm(pProposalId, pSuppliedSecrets,
  pUser, Output pResult, Output pHttpStatus, Output pCode)`. Order, and each step's `AD-n`, in the
  class header: refuse when `Caller.IsTurn()`; validate the closed channel against the descriptor's
  `SecretArguments()` and refuse the identifying key; `Write.ClaimById`; then, inside the
  transition frame — `ProhibitedClass()` seam, `Restraint.Verdict(pUser, DefinitionId)`, the
  declared `(resource, permission)` pairs, the conversation check, the definition-version check,
  the fresh `AdminPort.Invoke(endpoint, "GET")` re-read re-merged through `Mint.Merge` and
  re-digested through `Fingerprint.Of` against the **stored** fingerprint — then
  `GuardedClaimAndClose`. After its commit, and only then, merge the supplied secrets into the
  stored payload and issue `AdminPort.Invoke(endpoint, "PUT", , payload, …)`. Every refusal before
  the claim leaves the row untouched; a fingerprint mismatch closes the row `canceled` reason
  `target-changed`. `PortClass()` and `StoreClass()` seams mirror `Mint.cls`'s.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` — store `DefinitionId` and the `Agent.GuardedVersion`
  answer as `DefinitionVersion` at mint (read, never written — `Kernel/State/Agent.cls` is
  contended); in `Merge`, when the fresh read carried the field, set the new value with the
  **fresh read's** JSON type rather than the model's, coercing the value, so a numeric instance
  field is not sent back as a string. Addresses DW-1212.
- `src/OcuPilot/Screen/Registry.cls` — in `ConfirmChannelProblem`, admit a `fingerprintExcludes`
  path that names a field of the write tool **or** a declared read field (including declared detail
  and derived field names) of the same descriptor, so AD-6's side-effect fields are declarable while
  a typo is still refused. Addresses DW-1205.
- `src/OcuPilot/Test/ProposalScreen.cls` — restate its fingerprint exclusion as one the widened
  validator accepts, so the mint-honours-an-exclusion test no longer depends on the fixture sitting
  outside `DESCRIPTORPACKAGE`.

**Server — the API:**

- `src/OcuPilot/Api/Confirm.cls` (**new**) — `HandleConfirm(pId)` and `HandleCancel(pId)`: read the
  caller as `$Username`, parse the body as a flat object of secret-typed keys only, delegate, and
  render exactly one envelope through `Error.Render` / `Response.JSON`. Map `IsStaleSave` to
  `STATE.CONFLICT`; map each `PROPOSAL.*` code to an existing coarse slug
  (`forbidden` / `bad_request` / `conflict` / `not_found`).
- `src/OcuPilot/Api/Router.cls` — add `POST /proposal/:id/confirm` and `POST /proposal/:id/cancel`
  with their 405 method guards, respecting the three route-ordering invariants
  `scripts/check-objectscript.py` enforces.
- `src/OcuPilot/Api/Turn.cls` — at turn start, close the conversation's `live` proposals with reason
  `message` before the job is spawned, so "a typed message cancels every live proposal" is the
  instance's fact and not an optimistic client write. Addresses DW-1231.
- `src/OcuPilot/Api/Conversation.cls` — at conversation create, close the caller's `live` proposals
  with reason `you`; `AttachProposals` carries the new wire fields. Addresses DW-1243.

**Server — the concurrency residue routed here:**

- `src/OcuPilot/Kernel/State/Base.cls` — in `GuardedSaveIfCurrent`, capture the prior `RowVersion`
  and restore it on every path that rolls back, so a caller retrying the same object is not refused
  forever. Addresses DW-412 **at its real location** (the `%Save()`-failure path), not the one the
  entry names.
- `src/OcuPilot/Kernel/State/{Hold,WebApp,Sharing}.cls` — route `Hold.GuardedCreate` (`:89`),
  `WebApp.GuardedRecord` (`:138`), `WebApp.GuardedMarkGatewayReported` (`:150`) and
  `Sharing.GuardedSetForUser` (`:66`) through `GuardedSaveIfCurrent` — creates via its no-id branch,
  the two genuine updates with the row's current version. Partially addresses DW-407; the fifth site,
  `Agent.GuardedCreate`, is on the contended `Kernel/State/Agent.cls` (see Design Notes).
- `src/OcuPilot/Kernel/State/{Switch,Egress}.cls` — add a unique discriminator index so a second
  concurrent first create is refused rather than hidden behind `SELECT TOP 1`. Addresses DW-435.
- `src/OcuPilot/Test/Dispatch.cls` — add `New %request,%response` to `Invoke`, `InvokeHttp500` and
  `InvokeHandler` so the stubs do not outlive the call. Addresses DW-1184.

**Client:**

- `ui/src/app/core/turn.ts` — add `proposalConfirmPath`/`proposalCancelPath`, `confirmProposal(id,
  secrets)` and `cancelProposal(id)` through `ApiService.requestJson`; carry `closedReason` and
  `confirmedAt` on `TurnProposal`; replace the unconditional `expired` override so a restored row
  keeps a **terminal** state and only a still-`live` restored row is shown expired (DW-1225); close
  `proposal-closed` for a row that reaches a terminal state or passes `expiresAt`, and call
  `publishProposals([])` from `newConversation()` (DW-1209, DW-1243).
- `ui/src/app/core/proposal-view.ts` — add the `target-changed` phase to `ProposalPhase`,
  `TERMINAL_PHASES` and `REPROPOSABLE_PHASES`; map `state` + `closedReason` to
  `canceled-by-you` / `canceled-by-message` / `canceled-sibling` / `target-changed` / `confirmed` /
  `expired`; give `target-changed` its status line. Gives `confirming`, `canceled-sibling` and
  `confirmedAt` their writers (DW-1230).
- `ui/src/app/shell/panel.ts` — bind `(confirm)` and `(repropose)`; `onCardConfirm` sets the
  `confirming` phase, awaits `turn.confirmProposal`, and lets the wire supply the terminal phase;
  `onCardRepropose` starts a new turn carrying the message that produced the proposal's turn
  (DW-1224); remove the pre-send `cancelLiveCards` so a failed send leaves the proposals live
  (DW-1231).
- `ui/src/app/shell/proposal-card.ts` — render the in-flight Confirm (progress, `aria-disabled`,
  focus kept); render `confirmedAt` in the confirmed status line; for `target-changed`, wrap the
  status line in the warning banner above the footer and offer only Re-propose; give Re-propose the
  same `aria-disabled` discipline as the other two; bind `role="status"` on the status line so it is
  present only when the card did not hold focus, so the transition is announced exactly once
  (DW-1229).
- `ui/src/app/core/strings.ts` + the EXPERIENCE.md Fixed strings table — append only what is
  genuinely new; `proposalTargetChanged` already carries "target changed, re-propose" and becomes
  the `target-changed` status line rather than a second string.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:662` — amend the
  Focus destinations sentence to say the status line receives focus **when a control of that card
  held it**, matching the shipped guard and the same clause already written at line 205. Rule 5
  apply-and-report; record it in `## Spec Change Log` with an inline `[AMENDED …]` marker.
  Addresses DW-1245.

**Tests:**

- `src/OcuPilot/Test/ProposalConfirm.cls` (**new**) — the happy path plus every refusal, one at a
  time: from-turn, closed channel, not-yours, conversation, definition, restraint, privilege,
  fingerprint. Arms a `PUT` answer on `ProposalFixture`.
- `src/OcuPilot/Test/ProposalRace.cls` (**new**) — the claim is single-winner: seed one live row,
  call `GuardedClaimAndClose` twice with the same expected version, assert one `pWon = 1` and one
  `pWon = 0` carrying the terminal state; assert siblings on the same `TargetRef` are `canceled`
  reason `sibling` and a row on a different `TargetRef` is untouched.
- `src/OcuPilot/Test/ProposalClose.cls` (**new**) — cancel, turn-start close, conversation-create
  close, and the expiry projection.
- `src/OcuPilot/Test/ConfirmRoute.cls` (**new**) — HTTP tests through `Test/Dispatch.Invoke` for both
  routes: status, content type, single well-formed envelope, code from the enum shape, and the 405
  guard.
- `ui/tools/turn.test.mjs`, `ui/tools/proposal-view.test.mjs` — the restore mapping, the
  state+reason→phase table, and the `proposal-closed` publication.
- `ui/src/app/shell/proposal-card.spec.ts`, `ui/src/app/shell/panel.spec.ts` — the rendered
  contract: in-flight Confirm, the confirmed line with its time, the target-changed banner with only
  Re-propose, the `role="status"` binding, and the Re-propose re-send.
- `ui/browser/proposal-confirm.browser-spec.mjs` (**new**) — a real confirmed write end to end
  against the throwaway: press Confirm, the buttons are replaced by "Confirmed by …", the status
  line takes focus, Send returns to primary, and the web-applications list re-fetched shows the new
  value.

**Acceptance Criteria:**

- **AC1 (AD-40).** Given the shipped tool registry, when it is enumerated, then no entry names the
  confirm path; and given a process in which `Caller.Set` has run, when it calls `Confirm`, then the
  call is refused with `PROPOSAL.FROMTURN` and the proposal row is byte-identical afterwards.
- **AC2 (AD-6).** Given a confirm body carrying any key that is not a declared secret-typed field of
  that tool — including the identifying key — when it is posted, then the response is
  `PROPOSAL.CLOSEDCHANNEL`, no claim is made, and no request reaches the port.
- **AC3 (AD-6).** Given a live proposal, when it is confirmed, then the body the port receives is
  the **stored** payload with only declared secret values merged in, and no value from the confirm
  request appears in any non-secret field.
- **AC4 (FR-17, five conditions).** Given a live proposal, when confirm runs after each of — a
  different user, a newer turn in its conversation, a changed or deleted agent definition, a
  restraint turned on, a changed target — then each is refused with its own code and the card shows
  its own status line; and each refusal is reachable independently of the other four.
- **AC5 (AD-34).** Given two confirms of the same proposal, when they race, then exactly one commits
  the claim, the other is refused with the row's terminal state and is never retried, and the port
  is invoked exactly once.
- **AC6 (AD-34).** Given a second live proposal on the same scoped target, when the first is
  confirmed, then the second reads `canceled` with reason `sibling` from the same committed
  transaction, with no second request and no window in which both are live and one is burned.
- **AC7 (AD-40, AD-10, AD-30).** Given a proposal minted while a gate allowed the write, when that
  gate's state is changed before Confirm is pressed — the kill switch, enforced read-only, the
  definition's read-only flag, or a revoked `(resource, permission)` pair — then confirm follows the
  state **at confirm**, refusing where mint had allowed; and given the prohibited-set seam, when it
  is called, then it is called once, inside the transition and before the port call, and returns
  "not prohibited" until Story 5.5 populates it.
- **AC8 (EXPERIENCE.md).** Given Confirm is pressed, when the request is in flight, then the button
  shows progress and is `aria-disabled` with focus kept; and on success the buttons are replaced by
  "Confirmed by \<user name\> · hh:mm:ss", which takes focus when a control of that card held it,
  and Send returns to primary.
- **AC9 (DW-1225).** Given a conversation is reloaded, when its proposals are restored, then a row
  in a terminal state is shown in that state and only a still-`live` row is shown expired with
  Re-propose.
- **AC10 — Integration (Rule 1).** Given the web-applications list screen (Story 2.5) is open and
  bound to the proposal's entity type, when the proposal is confirmed, then its auto-refresh pause
  lifts and a re-fetch shows the value the diff promised — asserted by
  `ui/browser/proposal-confirm.browser-spec.mjs` against the throwaway, not by inspecting
  `Kernel/Proposal/Confirm.cls`'s own state.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-40 (confirm is user-originated; the gate is on the write), AD-34 (one
atomic transition; siblings in it), AD-6 (server-minted, single-use, fingerprinted, closed channel),
AD-8 (privilege re-checked at call time as pairs), AD-30 (read-only and the kill switch at the point
of effect), AD-7 (the write runs in the confirm request), AD-9 (protected state, `New $ROLES`,
nothing spawned or re-entered), AD-13/AD-37 (scoped triple, weak references), AD-4 (the complete
merged body), AD-12/AD-39 (one envelope, one writer, stable code), AD-35 (secrets never surface),
AD-41 (the ledger row is finalized after the write), AD-43 (proposal-open/closed drives the pause).
AD-10 is named but **not implemented here** — Story 5.5 owns its one home.

**What "one atomic transition" means here, and why the port call follows the commit.** AD-34's words
are "burning the token and **committing to** the write". The transition is the point of no return:
one conditional update exactly one caller wins, carrying the burn, the terminal state and the
sibling cancel, with every gate evaluated inside it before the commit. The vendor call is the effect
that commit commits to, issued immediately after `TCOMMIT`. Holding a `TSTART` open across it is
refused on two grounds — the project's ObjectScript rule forbids a side effect inside a transaction,
and the vendor's `%Api.Admin.*` classes run their own transactions, so a rollback could leave a
vendor write half-undone. Single-use is preserved either way: a claim that commits and a write that
then fails leaves the proposal burned and `confirmed`, refused on any re-attempt, which is the safe
direction. (inference — that this is AD-34's intended reading rather than an exception to it; the
alternative has no implementable form.)

**The prohibited-set gate point (DW-1207, sequencing).** `Write.ProhibitedClass()` returns `""` in
this story and `Confirm` calls it once, inside the transition, before the port call. Story 5.5
creates AD-10's single kernel home and points the seam at it — a one-line change with no new call
site. DW-1207 is owner-level and undecided; this story neither designs nor pre-empts the set, and
after it a confirmed `webapp.list.update` can still change `AutheEnabled`, `Resource` or
`DispatchClass` until 5.5 lands.

**Reading the definition's version without editing a contended file.** `Agent.GuardedVersion(pId,
Output pVersion)` already exists and answers `""` for no row. `Mint` stores its answer and `Confirm`
compares against it; neither writes `Kernel/State/Agent.cls`. `Restraint.Verdict` remains the only
public answer to the definition's read-only flag. Because `GuardedVersion` carries no `Try`/`Catch`,
the confirm transition wraps the call in its own `Try` with a `TROLLBACK`, so a raise cannot leave a
transaction open — the harm DW-430 describes is neutralized at the call site even though the
alignment itself is declined below.

**The fingerprint-mismatch banner.** EXPERIENCE.md supplies one fixed string for this transition,
"target changed, re-propose" (line 259), and DESIGN.md:1191 says the banner's fixed string is
EXPERIENCE.md's. The only reading buildable from both documents is that the status line **is** the
banner's text: the line is rendered inside a warning banner above the footer. No new copy is
invented. (inference) If the owner wants distinct banner wording it is a one-line EXPERIENCE.md
addition, not a code change.

**Consumed-by (Rule 2):** 5.4 (execution identity hardening over this write path), 5.5 (fills
`ProhibitedClass()`), 5.6 (emits the audit marker at this write, and finalizes the ledger row after
it), 5.7 (publishes the change event from this commit), 5.8–5.13 (the six area writes all confirm
through it), 7.4 (re-uses 5.10's confirmed operation).

**Consumes (Rule 2):** 5.1 (`Mint`, `Fingerprint`, `Write.Claim`, `Caller`, `Kernel.State.Propose`),
5.2 (the card's phase model, status lines, countdown and restore path), 4.2 (`Dispatch`'s gate chain
and `Restraint`), 4.5 (the turn's progress and lock contract), 3.7 (switches, holds, enforced
read-only), 2.5 (the web-applications list, AC10's consumer), 2.1 (`AdminPort`), 1.13 (the error
envelope). Every Integration AC runs against a real instance — the throwaway — never a mock.

**Ledger inbox — disposition of all fifteen (Rule 17).** Addressed by a Tasks item above:
**DW-407** (partially — four of five sites; see below), **DW-412** (at its corrected location),
**DW-435**, **DW-1184**, **DW-1205**, **DW-1209**, **DW-1212**, **DW-1224**, **DW-1225**,
**DW-1229**, **DW-1230**, **DW-1231**, **DW-1243**, **DW-1245**.

- **Declined DW-430:** aligning `Agent.GuardedVersion`'s `""` sentinel with `Switch.GuardedVersion`'s
  `0`, and adding the missing `Try`/`Catch`, both require editing
  `src/OcuPilot/Kernel/State/Agent.cls`, which Epic 10 owns as a contended path — an `intent gap`,
  never an edit. Changing `Switch` instead would move a sentinel three shipped callers already read,
  which is a larger change than the entry asks for. This story consumes both methods correctly
  (empty is "no row", never `0`) and guards the raise at its own call site. Owner: the story that
  next owns `Kernel/State/Agent.cls` after Epic 10 merges, else the range-end cleanup story (Rule 27).
- **DW-407 residual:** `Agent.GuardedCreate` (`Kernel/State/Agent.cls:178`) is the fifth
  unconditional write and sits on the same contended file. It is a create with no id, so no false
  positive is reachable; it is re-owned with the same owner as DW-430. Routing the other four makes
  the Conventions row (spine line 540) literally true for every store this story can reach, so no
  spine amendment is required.
- **Correction to record at origin:** DW-412's evidence says the in-memory `RowVersion` is "set
  before the conditional update and not restored on the zero-row-count path". `Base.cls:188–197`
  shows the assignment happening only **after** the row-count check, so the zero-row-count path never
  raises it; the residue is on the `%Save()`-failure path, across `TROLLBACK 1`. The fix covers the
  real path and the ledger note is corrected rather than appended to.

**Not this story.** A scheduled retention sweep over `Proposal` rows (AD-41's bounded-resources
work): read-time projection plus a flip on next touch satisfies every observable this story's ACs
name, and a background task is a separate, testable unit. Raise it at the epic's burn-down gate
under Rule 27 rather than growing this story.

## Verification

**Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Every confirmed write runs on the
throwaway `ocupilot-ci` — never on `ocupilot`, and never on any `ocupilot-slot-*` container.**

**Commands:**

- `uv run scripts/check-objectscript.py src/OcuPilot/...` (staged paths) — expected: no findings;
  the three `UrlMap` ordering invariants hold for the two new routes.
- `bash scripts/lint-docs.sh` — expected: clean, including the amended EXPERIENCE.md.
- `cd ui && npm run build` — expected: the six `prebuild` checkers pass (`screen-mirror.mjs --check`
  and `field-lists.mjs --check` in particular, since the descriptor validator changed), and the
  bundle lands in `ui/dist/ocupilot-ui/`.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` then the component runner, both
  green. `ui/tools/strings.test.mjs` is contended and is **not** edited; it passes because the new
  string rows are added to EXPERIENCE.md's Fixed strings table, which it re-parses.
- `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  — expected: container `ocupilot-ci` healthy. Tear down only this throwaway, and only because this
  transcript names its `up`.
- Load and compile into the throwaway with the IRIS MCP tools, **one file at a time to its exact
  relative path**, then `grep` the loaded source inside the container before believing a red or a
  green: `%SYSTEM.OBJ.LoadDir` with `cuk` skips a file it judges unchanged, and `cp -R src/ …` nests
  a stray copy.
- `iris_execute_tests` — **one test class per tool call**, each landed in `%UnitTest_Result` before
  the next is sent (these classes seed and close shared proposal rows and arm the same port fixture).
  Order: `OcuPilot.Test.ProposalConfirm`, `…ProposalRace`, `…ProposalClose`, `…ConfirmRoute`, then
  the shipped `…Proposal`, `…ProposalWrite`, `…ProposalWire`, `…ToolWrite`, `…ToolDispatch`,
  `…Restraint`, `…State`, `…SwitchState`, `…AgentState`. Confirm the totals with the
  `%UnitTest_Result` SQL probe before reporting any suite green; a client-side timeout is not a
  failed run and is never re-submitted.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  — expected: green. A browser spec reads the **deployed** bundle, so the rebuild and the copy are
  part of the check, not preparation for it.
- **The full-suite browser leg runs on a throwaway the `%UnitTest` class sweep has not touched**
  (DW-1204, open): the sweep's classes write audit rows and the audit spec then loses tests in a
  full run while passing in isolation. Bring up a second throwaway for the full leg, or run the
  browser leg first on a fresh container.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: every
  assertion executed and passing; zero executed checks is a failure, never a pass.

**Rule 19 mutations** — one per AC, applied, observed red, reverted, and `git status --short` plus
`git diff --stat` confirmed unchanged afterwards. Record each next to its test as
`mutation: <change> → <test that went red>`. Suggested mutations: AC1 — make `Caller.IsTurn()`
return 0 unconditionally; AC2 — ignore an unknown confirm key instead of refusing it; AC3 — take
the payload from the request instead of the row; AC4 — skip one of the five checks; AC5 — drop the
`State = 'live'` clause from the conditional `UPDATE`; AC6 — move the sibling cancel after
`TCOMMIT`; AC7 — hoist a gate to mint time; AC8 — remove the `heldFocus` guard; AC9 — restore the
unconditional `expired` override; AC10 — stop publishing `proposal-closed` on confirm. Client
mutations prove nothing until the bundle is rebuilt and redeployed; server mutations prove nothing
until the whole package is recompiled, since every subclass keeps its own compiled copy.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
