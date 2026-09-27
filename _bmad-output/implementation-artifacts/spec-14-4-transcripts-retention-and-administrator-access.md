---
title: 'Story 14.4: Transcripts, retention and administrator access'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: 'a95032ab212a514db252cff52c74c473d6a33a7f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-14-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The production Uninstall's call to Installer.RemoveRetentionTask is covered by no test.
    evidence: |-
      Deleting the call at Install/Installer.cls in Uninstall leaves every suite green; no test runs the production uninstall, and a probe uninstall names no task class.
    location: >-
      src/OcuPilot/Install/Installer.cls Uninstall
    severity: medium
  - summary: >-
      GET /transcripts/:id maps a non-AUTH.NOPRIVILEGE gate fault (LEDGER.UNAVAILABLE) to 503, and no test drives it.
    evidence: |-
      Mapping every fault to NotFound leaves every suite green; driving it needs a failing ledger store reachable over HTTP, which no probe seam provides.
    location: >-
      src/OcuPilot/Api/Transcripts.cls HandleRead
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Conversations are already stored per user (`Kernel.State.Convo` and `Entry`, Story 4.5), but four things are missing:

- The turn's screen context is not kept with them.
- Nothing ever purges them or the ledger. The definition's `RetentionDays` field is inert and `aria-disabled` (DW-1122).
- Nobody can reopen a conversation that New conversation replaced.
- An administrator has no gated route to another user's transcript.

**Approach:**

- Store each turn's bounded screen context, definition and time on its entry.
- Add a daily `%SYS.Task` that the installer creates, which purges entries by their definition's retention and the ledger by the longest retention.
- Add a Transcripts list (a declared `state` read) and a transcript page over `GET /transcripts/:id`. Another user's tool results and screen context pass through the ledger's own per-row gate, and each such open writes a ledger row.

## Boundaries & Constraints

**Always:**

- **Storage (AD-9, AD-37, Conventions › When `SCHEMAVERSION` moves).**
  - `Entry` gains three properties: `ContextJson` (a stream holding the payload `Job.Run` already holds, bounded and secret-stripped per AD-24/AD-35, or empty), `DefinitionId`, and `AppendedAt` (ISO UTC).
  - `SCHEMAVERSION` does not move. An older row falls back to its `Convo.CreatedAt` and to the default definition.
  - References stay weak: a user or definition that is gone still reads.
- **Retention (AD-37).**
  - An entry is removed when it is older than its own definition's `RetentionDays`. If that definition is gone, the default definition's value applies; if there is no definition at all, `Agent.#DEFAULTRETENTIONDAYS` (30) applies.
  - A conversation left with no entries is removed once its `CreatedAt` is older than the **longest** retention.
  - Ledger rows older than the longest retention are removed, so a transcript never outlives the rows its gate reads (DW-1122).
  - A deleted user's transcripts age like everyone's. Deletion alone never removes them.
- **Principal gone (AD-37, AD-31).** The sweep asks `Base.GuardedUserEnabled` about every user named by a non-terminal `Turn`, a `Pref` or a `Sharing` row. If the answer is known 0 and not unavailable:
  - abandon their turns (`Turn.GuardedAbandonForUser`);
  - delete their `Pref` and `Sharing` rows.

  Holds, transcripts and the ledger are kept. `UserDelete.AfterWrite` abandons the deleted user's turns at once, for both callers. It logs any failure and always answers `$$$OK`.
- **The gate lives with the ledger (AD-46).**
  - Extract `ViewForUser`'s cross-user per-row decision (truncated set, unparseable set, `SENSENONE`, `EvaluateRequired`) into one private `ReleasesRow`. `ViewForUser`'s behavior does not change.
  - Add `GateTurns(pCaller, pSubject, pConvKey, pTurnKeys, Output pReleased, Output pFailedPair, Output pFault)` beside it. It requires `AdminPair`, reads each turn's rows through the store outside any escalated frame, and releases only when every row passes `ReleasesRow`. These fail closed: a turn key of `""`, a turn with no rows, a truncated read, or any dropped count.
  - A cross-user call always appends one row: `Kind` `access`, `UserName` the caller, `TurnKey` the conversation key (bounded per conversation, AD-41), `Name` `transcript`, `Target` the owner, `Arguments` `{conversationId, released}`, and `RequiredPairs` `AdminPair`, sense checked.
- **`GET /transcripts/:id`** (`Api/Transcripts.cls`) answers `{conversationId, user, own, released, failedPair, turns:[{seq, appendedAt, message, state, reply, error, steps, context}]}`.
  - An unknown id, or another user's id asked for by a caller without `AdminPair`, gets the same 404 `TURN.CONVERSATION.NOTFOUND` (AD-33).
  - When not released, every turn's `steps` is `[]` and its `context` is `null`. Messages and replies are always sent.
  - Proposals are never attached.
- **Screens (AD-5, AD-36).**
  - `AgentTranscripts`: route `agent/transcripts`, a `list` with `sideBarPosition` 4, `privileges` `[]`, `entityType` `""`, scope `instance`, composite id `["id"]`, read `{port:"state", endpoint:"Convo"}`, and fields `id, user, started, lastActivity, turns, title`.
  - `Convo.GuardedScreenRows` answers every user's conversations to a holder of `OcuPilotAdmin:USE`, checked in the caller's process before any guarded call (AD-8, AD-9), and the caller's own to anyone else. It lists only conversations that have at least one entry. `title` is the first message cut to 120 characters, and only on the caller's own rows.
  - `AgentTranscript`: route `agent/transcripts/details`, a `detail` with `sideBarPosition` 0 and `parentScope` `agent/transcripts`, no read, and the same three prompts. A custom `TranscriptPage` renders it.
- **Admin rendering adds nothing.** An administrator sees the same stored step projection and context the owner sees (AD-24, AD-35, AD-48). The sanitizer (AD-60) is not applied to stored data.
- **Strings.** The retention field becomes editable. EXPERIENCE.md is edited in place and keeps 981 lines: row :336 gains every new string, and :646 and :736 drop "cannot be reopened". `strings.ts` is add-only.

**Never:**

- No second gate at the screen or the route.
- No change to `Kernel/Governance/Gate.cls`, `Kernel.EntityType`, `Propose.cls`, `Api/Error.cls` or the panel's `GET /conversation/:id` contract.
- No appending after EXPERIENCE :573. Stay off Epic 16's hunks:
  - `Router.cls` (HEAD lines): UrlMap after :116, :121 and :141; methods near :660-667, :700-720 and :859-870
  - `strings.ts` :1816-1954 and the tail from :2855
  - `_components.scss` :4846, :6450 and the tail
  - `turn.ts` :38, :89, :249, :358, :566, :1172-1243
  - EXPERIENCE :83, :476, :571-578, :612, :658, :830

## I/O & Edge-Case Matrix

| Scenario | State / Input | Expected | Error |
|---|---|---|---|
| Own transcript | owner `GET /transcripts/:id` | 200, `own` true, steps and context present, no ledger row | none |
| Admin, released | admin holding every recorded pair | 200, steps and context present; one `access` row, `released` true | none |
| Admin, withheld | admin missing one row's pair | messages and replies only; `failedPair` names the pair; `access` row with `released` false | none |
| Fail closed | turn with no ledger rows, overflow, or legacy `""` key | withheld | none |
| Not allowed | non-admin, another user's id; or an unknown id | the same 404 body; no row written | `TURN.CONVERSATION.NOTFOUND` |
| List | non-admin; admin | own rows only; every user's rows, `title` only on own | none |
| Purge | entries on definitions A (1 day) and B (30 days), both 2 days old | A's entry removed, B's kept; ledger rows older than 30 days removed (DW-1122) | a failed store call is logged; the task answers its status |
| Reload after retention | turn ended more than `RETENTIONSECONDS` ago, sweep runs | `GET /conversation/:id` carries no proposals for it; entry intact (DW-1240) | none |
| Deleted user | probe user with transcripts, prefs and a running turn is deleted | token answers 401 `AUTH.DISABLED`; turn abandoned; prefs and sharing removed after the sweep; transcripts and ledger kept, and an admin can still read them | an unreadable identity removes nothing |

</intent-contract>

## Code Map

- **Stores** (`src/OcuPilot/Kernel/State/`):
  - `Entry.cls`: `GuardedAppend` :70, `GuardedRows` :110, `GuardedTurnKeys` :174.
  - `Convo.cls`: `AppendEntry` :105, `GuardedOwner` :90.
  - `Turn.cls`: `GuardedSweep` :550, whose `GuardedDelete` :569 cascade gains `Propose.GuardedDeleteForTurn` :598; `GuardedAbandonForUser` :381.
  - `Ledger.cls`: `GuardedAppend` :227, `GuardedIdsForWindow` :361, `GuardedDroppedFor` :379, `GuardedRow` :413.
  - `Agent.cls`: `RetentionDays` :123, `GuardedList` :439.
  - `Base.cls`: `GuardedUserEnabled` :584, `ADMINRESOURCE`.
  - `Pref.cls` (contended; add at the end only) and `Sharing.cls` gain `GuardedUsers` and `GuardedDeleteForUser`.
- `src/OcuPilot/Kernel/Agent/Job.cls`: `Run` :79 holds `pContext` and `pDefinitionId`; `AppendConvoEntry` :140 passes them on.
- `src/OcuPilot/Kernel/Audit/Ledger.cls`:
  - `ViewForUser` :553; the per-row loop to extract is :612-655.
  - `AdminPair` :190, `GateClass` :45; `RecordRead` stays for `ViewForUser`.
- `src/OcuPilot/Screen/Read.cls` `StateRows` :437 calls `GuardedScreenRows(.rows, max)`. The precedents are `Descriptor/AgentDefinitionList.cls` and `ProcessDetails.cls` :53-66.
- `src/OcuPilot/Api/Conversation.cls`: `HandleRead` :70 is the pattern, including `ReasonForTurnError`. `Api/Router.cls` has the conversation routes at :131-132 and `ConversationRead` at :769.
- `src/OcuPilot/Screen/Tool/UserDelete.cls` :16 has no `AfterWrite`; the default is `Tool/Write.cls` :244, reached through `Kernel/Proposal/Operation.cls` `ApplyAt` :372.
- `src/OcuPilot/Install/Installer.cls`:
  - `Install` :687 (steps :802-934, the `tFailingStep` pattern, `EnsureAdminResource` :2018 as a model).
  - `Uninstall` :3691: the destroy message :3790 and the %SYS removals :3874-3989.
  - The task create/find/delete pattern is `Install/Fixture.cls` :463, :528-551 and :1063-1088. `Install/DemoTask.cls` is a `%SYS.Task.Definition` compiled in HSCUSTOM.
- **Client** (`ui/src/app/`):
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :108.
  - `shell/tool-call-card.ts` (input `step`) and `shell/reply.ts` (`text`, `citations`).
  - `core/turn.ts` `parseStep` :432, to be exported.
  - `areas/agent/definition-form.page.ts` retention :461-475. `switches.store.ts` :261 is the `requestJson` pattern.
- **Rosters:**
  - `Test/SurfaceCoverage.cls` :57
  - `Test/Descriptor.cls` `ReadShapes` :70
  - `Test/ReadTool.cls` :94 and :112
  - `Test/EndpointCoverage.cls` :120
  - `ui/tools/navigation.test.mjs` :196-221
  - `Test/Wire.cls` listed count
  - `ui/tools/strings.test.mjs`
  - Regenerate `screens.generated.ts` with `node tools/screen-mirror.mjs`.
- **Test precedents:**
  - `Test/LedgerPairs.cls`, with `LedgerGateProbe` for the set semantics and the real reader `OcuPilotProbeLedgerReader`.
  - `ui/browser/citation-chips.browser-spec.mjs`, with the `turnprobe` provider (`Test/TurnProvider`).

## Tasks & Acceptance

**Execution:**

- **Stores.**
  - `Entry.cls`: add the three properties and the trailing `GuardedAppend` arguments. Give `GuardedRows(pConvoKey, .rows, pWithContext = 0)` an opt-in `appendedAt` and parsed `context`. Add `GuardedPurge(pCutoffs)`.
  - `Convo.cls`: pass the new arguments through `AppendEntry`. Add `GuardedOwnerOf(pKey, .user)`, `GuardedScreenRows(.rows, pMaxRows)` and `GuardedPurgeEmpty(pCutoff)`.
  - `Ledger.cls`: add `KINDACCESS = "access"` and `GuardedPurgeBefore(pIso)`.
  - `Agent.cls`: add `Parameter DEFAULTRETENTIONDAYS = 30` (used as `InitialExpression`) and `GuardedRetentions(.byId, .defaultDays, .longestDays)`.
  - `Turn.cls`: cascade proposals in `GuardedDelete`, and add `GuardedLiveUsers`.
  - `Pref.cls` and `Sharing.cls`: add `GuardedUsers` and `GuardedDeleteForUser`.
  - All SQL is literal and bound (AD-21, check-objectscript rule 21).
- `Kernel/Agent/Job.cls`: pass `pContext` and `pDefinitionId` into `AppendConvoEntry`.
- `Kernel/Audit/Ledger.cls`: add `ReleasesRow`, `GateTurns` and `RecordTranscriptAccess`, and make `ViewForUser` call `ReleasesRow`.
- `Kernel/Retention.cls` (new): `Sweep(pLimitsClass)` runs, in order:
  1. `Turn.GuardedSweep`;
  2. the entry purge, then the empty-conversation purge;
  3. the ledger purge;
  4. the principal-gone pass.

  Each step's error is logged and does not stop the next. It answers the first error.
- `Kernel/RetentionTask.cls` (new): extends `%SYS.Task.Definition`, with `TaskName` "OcuPilot transcript retention". `OnTask` calls `Retention.Sweep`.
- `Install/Installer.cls`:
  - Add an `EnsureRetentionTask` step, guard-then-act by `TaskClass`. It creates a daily task at 03:15, in the install namespace, with the vendor's default `RunAsUser`, and repairs drift.
  - `Uninstall` removes it by class, and the :3790 message names it.
- `Screen/Tool/UserDelete.cls`: add the `AfterWrite` override (Always).
- `Api/Transcripts.cls` (new): `HandleRead`, as in Always.
- `Api/Router.cls`: add `<Route Url="/transcripts/:id" Method="GET" Call="TranscriptRead"/>` after :132, and a thin target after `ConversationCreate`.
- `Screen/Descriptor/AgentTranscripts.cls` and `AgentTranscript.cls` (new), as in Always:
  - Columns: `started` is the name column (`taskHistoryColumnStarted`); `user` (`processColumnUser`); `turns`; `lastActivity`; `title`.
  - `emptyNextKey` `tableReadOnlyEmptyNext`; `toolIdentifier` `agent.transcripts` and `agent.transcript`.
  - Group `promptGroupAgentSetup`; aliases "transcripts", "conversation history".
- **Client.**
  - `areas/agent/transcript.page.ts` (new, standalone, OnPush):
    - It reads `GET /api/ocupilot/transcripts/<id>` and mirrors a framework-free store (`transcript.store.ts`) into a signal (AD-19).
    - Each turn shows its message, `<app-reply [text] [citations]="[]">`, its `<app-tool-call-card>`s and a "Screen context" disclosure with the route and the payload as text.
    - A withheld view shows "You need <pair> to see this transcript's tool results and screen context."
    - A 404 shows the :265 no-longer-present sentence.
  - Register it in `DESCRIPTOR_PAGES` and export `parseStep`.
- `areas/agent/definition-form.page.ts`: the retention input becomes editable (`(input)="onText('retentionDays', …)"`, with the aria-invalid and reason wiring its siblings use). The caption stays, and the doc drops "nothing enforces".
- **Strings.**
  - `strings.ts` (add-only, after the agent-definition block near :564): "Transcripts" · "Transcript" · "Turns" · "Last activity" · "First message" · "No conversations are kept for you yet." · "Screen context" · "No screen context was sent with this turn." · "see this transcript's tool results and screen context" · "Which conversations did I have today?" · "Which of my conversations ran the most turns?" · "When did I last talk to the agent?"
  - EXPERIENCE.md :336 carries the same strings, and :646 and :736 are edited in place.
  - Run `npm run test:tools`.
- **Tests.**
  - New ObjectScript classes:
    - `Test/TranscriptStore.cls`: entry fields, list scoping, fallbacks.
    - `Test/TranscriptGate.cls`: `GateTurns` over `LedgerGateProbe`, the fail-closed rows, the access row, and `ViewForUser` unchanged.
    - `Test/TranscriptsWire.cls`: HTTP with real principals (owner, a second user, and an admin holding `OcuPilotAdmin:USE` without `%Admin_Secure:USE`).
    - `Test/Retention.cls`: every Purge, Reload and Deleted-user row, with backdated stamps and a probe definition.
    - `Test/RetentionTask.cls` (armed): the install is idempotent, `RunNow` records success in task history, and uninstall removes the task.
  - A `ToolWrite` leg: a confirmed `UserDelete` abandons the probe user's running turn.
  - Client:
    - `transcript.page.spec.ts` and `transcript.store` tests;
    - the `definition-form.page.spec.ts` retention case;
    - `ui/browser/transcripts.browser-spec.mjs`: two `turnprobe` turns, New conversation, then Transcripts lists the first and opens it with its message, reply and context.
  - Update the roster files in the Code Map.

**Acceptance Criteria:**

- **AC1.** Given a finished turn, when its owner opens `GET /transcripts/:id`, then each turn carries its stored screen context, and the Transcripts list and that route show a non-administrator only their own.
- **AC2.**
  - Given entries older than their definition's retention, when the retention task runs (`RunNow`), then they are removed and newer ones stay.
  - Given an instance, when install runs twice, then one scheduled task named "OcuPilot transcript retention" exists and the Definition form's retention field is editable.
- **AC3.** Given an administrator, when they open another user's transcript, then an `access` row is recorded, and tool results and context appear only when every recorded row passes `ReleasesRow`.
- **AC4.** Given two conversations, the first replaced by New conversation, when Transcripts opens, then the first is listed and reopens.
- **AC5.** Given a user deleted through OcuPilot, when the sweep runs, then their transcripts and ledger rows survive while their turns are abandoned and their token is refused.
- **Integration (Rule 1).** Given the admin's `access` row, when the admin's own `ViewForUser` (16.16's read) runs, then the row appears with `kind` `access`. The browser consumer renders a real transcript from the route.

## Spec Change Log

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 30 findings — high 0, medium 9, low 11, false 10, maybe-false 0
- findings:
  - `[medium]` `[patch]` Ledger and empty-conversation purges not pinned to the longest retention — rows a day younger than the longest now asserted kept (run 1739 mutation).
  - `[medium]` `[patch]` Purge fallbacks for older entries untested — added `TestAnOlderEntryAgesByItsConversationAndTheDefault`.
  - `[medium]` `[patch]` `Job` passing the definition id unpinned — `transcripts.browser-spec` asserts the stored `DefinitionId` of a real turn.
  - `[medium]` `[patch]` `lastActivity` pinned only by an assertion that cannot fail — dated entries, exact `started` and `lastActivity`.
  - `[medium]` `[patch]` The `RunNow` leg cannot tell a sweep from a no-op — it now seeds an expired entry and asserts it gone.
  - `[medium]` `[patch]` Principal-gone sources never tested separately — added `TestEachStoreNamesAGoneAccountToThePass`; the unavailable leg is a later row.
  - `[medium]` `[defer]` Production `Uninstall`'s `RemoveRetentionTask` call untested — no test runs the production uninstall by design.
  - `[medium]` `[patch]` A probe profile scheduling no task is unpinned — added `TestAProbeProfileSchedulesNoTaskAndLeavesTheProductionOne`.
  - `[medium]` `[defer]` The route's 503 fault mapping has no test — needs a failing-store seam reachable over HTTP.
  - `[low]` `[patch]` `TranscriptGate` never asserts an own read writes nothing — counts access rows for the conversation under any name.
  - `[low]` `[patch]` AC1 route half has no `mutation:` line — recorded (run 1746).
  - `[low]` `[patch]` AC2 editable field has no `mutation:` line — recorded.
  - `[low]` `[patch]` AC2 `RunNow` leg has no `mutation:` line — recorded with the strengthened leg (run 1743).
  - `[false]` `[reject]` AC5's token refusal has no `mutation:` line — AC5 is pinned by run 1417's mutation; the 401 is the existing Identity behavior this story measures.
  - `[false]` `[reject]` AC4's mutation lacks a run id — a browser run has no result index; the line names the spec that went red.
  - `[low]` `[reject]` A transcript withheld for a row's shape shows no sentence — every resolvable route records a pair, so it needs a legacy or overflowed turn, and the fix is a new published string; reopen_if an admin reports a stripped transcript with no reason shown.
  - `[low]` `[reject]` The list's own-row title compares names case-sensitively — `Convo.UserName` is written from `$USERNAME`, so a mismatch needs a hand-edited row.
  - `[false]` `[reject]` Reload is tested in process, not over `GET /conversation/:id` — the route reads proposals through the same `Propose.GuardedRowsForConvo` (`Api/Conversation.cls:116`).
  - `[false]` `[reject]` Deletion abandons only a queued turn in the test — `GuardedAbandonForUser` selects queued and running (`Turn.cls:384`), through the `ApplyAt` path both callers share.
  - `[false]` `[reject]` An admin reads a deleted user's transcript in process only — the route resolves the owner by a weak read and calls the same `GateTurns`.
  - `[low]` `[patch]` An unreadable identity removing nothing is untested — `Retention.IdentityClass` seam plus `TestAnUnreadableIdentityRemovesNothing` (run 1753 mutation).
  - `[false]` `[reject]` Fail-closed is tested only at `GateTurns` — the route adds no decision (AD-46).
  - `[false]` `[reject]` No test releases over real turns' `llm` rows — `ReleasesRow` is `ViewForUser`'s decision, whose suites cover the route and none senses; `TranscriptGate` pins it unchanged.
  - `[low]` `[reject]` A failing step is driven only by a throw — `Sweep` sends a returned error and a caught throw through the same `Step` call.
  - `[low]` `[reject]` The ledger cutoff trails the longest retention by one hour — at a daily cadence the row goes at the next sweep, and it keeps the gate's rows past every entry.
  - `[false]` `[reject]` "No definition at all" read as none marked default — `GuardedRetentions` answers 30 whenever no default is marked, including an empty table.
  - `[low]` `[reject]` Title case-sensitivity across list and route — same root as the case-sensitivity row above.
  - `[false]` `[reject]` Stored context not tested for secret stripping — the entry stores the payload `Job.Run` already holds, as the Storage row says.
  - `[false]` `[reject]` The proposal cascade also runs from `GuardedReserve`'s sweep — same `RETENTIONSECONDS`, which `ProposalWrite` pins at or above the proposal window.
  - `[low]` `[reject]` Legacy transcripts show no sentence to an admin — same root as the withheld-sentence row above.

## Design Notes

**Governing ADs:** AD-37, AD-46, AD-41, AD-9, AD-8, AD-24, AD-36, AD-5, AD-33, AD-31, AD-35, AD-48, AD-60, AD-17, AD-16, AD-21, AD-53 and AD-55 (`AfterWrite` for both callers), AD-19, AD-20 and AD-44 (no classic page). Also Conventions › Dates and › When `SCHEMAVERSION` moves.

**AC2 against AC5 (Rule 5), resolved from AD-37.** Retention by age applies to every transcript, including a deleted user's. AD-37 forbids deleting transcripts *because* the principal is gone, and nothing else. There is no intent gap.

**"Recorded in the agent audit ledger"** is the PRD glossary's meaning (:180): OcuPilot's own ledger, not the IRIS audit database. So the access is a ledger row. AD-15 binds only writes.

**Which retention applies.** Every definition's field takes effect for the entries it produced, so no enabled field promises nothing (Story 3.1). The ledger follows the longest retention so the gate never loses rows first (inference: the Operational Envelope's Retention row).

**Why a `state` read that is scoped per caller.** AD-50's objection is to adding a caller argument, and none is added. Anything that reaches the agent is only the caller's own titles.

**AD-36 amended by the runner at the spec gate (2026-09-27; no new id):** a `state` store's guarded list may be scoped to the caller. It answers the caller's own rows and, to an `OcuPilotAdmin:USE` holder, every user's, with the check made in the caller's process before any escalated frame.

**Operational Envelope › Retention amended by the runner at the spec gate (2026-09-27):** entries age by their own definition's `RetentionDays`, and the ledger by the longest, so the per-row gate outlives every transcript.

**Consumed-by:**

- Story 16.16 (agent audit viewer): `ReleasesRow` through `ViewForUser`, and the `access` rows.
- `TranscriptPage`: `GET /transcripts/:id`.
- `RetentionTask`: `Retention.Sweep`.
- The panel's restore: DW-1240's sweep.

**Consumes:** `Kernel.Audit.Ledger.ViewForUser`'s gate, `Screen.Read` `state`, the `Convo`, `Entry`, `Ledger`, `Turn`, `Pref` and `Sharing` stores, `Base.GuardedUserEnabled`, and `Operation.ApplyAt`'s `AfterWrite`.

**Contended with Epic 16:**

- Files: `Router.cls`, `Pref.cls`, `strings.ts`, `_components.scss`, `turn.ts`, EXPERIENCE.md and `EndpointCoverage.cls`. Each edit stays off their hunks.
- 16.22 (planned) takes agent position 3 and edits `navigation.test.mjs` and `Wire.cls`, so the Rule 22 merge reconciles those counts. Position 4 avoids the collision (inference: `SideBarPositionProblem` checks only the shape).
- `Kernel/Audit/Ledger.cls` is untouched by Epic 16.

**DW-1122** is addressed by the ledger purge (the Purge row). **DW-1240** is addressed by the `Turn.GuardedDelete` cascade (the Reload row).

**Measured at implement, never recalled:**

- the task's default `RunAsUser` and a successful scheduled run;
- that `GuardedUserEnabled` answers a deleted account as known 0;
- that a deleted user's token answers 401;
- that the Registry admits a readless `detail` and an empty `entityType` on a list. A refusal here is a HALT.

## Verification

Slot B. Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Only one test run is in flight at a time. Before any browser run, rebuild and `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands:**

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for each of:
  - `TranscriptStore`, `TranscriptGate`, `TranscriptsWire`, `Retention` and `RetentionTask`;
  - `LedgerPairs`, `LedgerEmptyPairs` and `LedgerWire`;
  - `Convo`, `TurnStore`, `ToolWrite` and `ProposalWire`;
  - `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage` and `Wire`.

  Expected: 0 failures, with totals checked against `%UnitTest_Result`.
- `(loop)` Run `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1` over `browser/transcripts`, `definitions` and `panel` (each `.browser-spec.mjs`). Expected: all pass.
- `(loop)` Run `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(once, before dev_complete)` Run the full ObjectScript sweep on `ocupilot-b-ci` one class per call, then `cd ui && npm test && npm run build`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

- **AC1:** drop `ContextJson` from `Entry.GuardedAppend` → `TranscriptStore` goes red.
- **AC1:** drop the owner filter in `Convo.GuardedScreenRows` → `TranscriptsWire` goes red.
- **AC2:** compare against the longest retention instead of the entry's own → the A/B leg of `Retention` goes red.
- **AC2:** make `EnsureRetentionTask` a no-op → `RetentionTask` goes red.
- **AC3:** make `GateTurns` skip `ReleasesRow` → `TranscriptGate` and the withheld leg of `TranscriptsWire` go red.
- **AC3:** drop `RecordTranscriptAccess` → the Integration leg goes red.
- **AC4:** unregister `TranscriptPage` → `transcripts.browser-spec` goes red.
- **AC5:** add `Convo.GuardedDelete` to the principal-gone pass → the deleted-user leg of `Retention` goes red.
- **DW-1240:** drop the proposal cascade → the reload leg goes red.

**Recorded (implement, `ocupilot-b-ci`):**

- mutation: drop the `ContextJson` write from `Entry.GuardedAppend` → `TranscriptStore.TestAnEntryKeepsItsContextDefinitionAndTime` red (run 1409)
- mutation: drop the owner filter in `Convo.GuardedScreenRows` → `TranscriptsWire.TestTheListShowsANonAdministratorTheirOwnOnly` red (run 1410)
- mutation: give every definition the longest retention's cutoff in `Retention.Sweep` → `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` red (run 1411)
- mutation: make `Installer.EnsureRetentionTask` a no-op → `RetentionTask.TestInstallSchedulesExactlyOneTaskAndRepairsDrift` red (run 1412)
- mutation: make `GateTurns` skip `ReleasesRow` → `TranscriptGate` (withheld, fail-closed) and `TranscriptsWire.TestAnAdministratorMissingOnePairSeesMessagesAndRepliesOnly` red (runs 1413, 1414)
- mutation: drop the `RecordTranscriptAccess` call → `TranscriptGate.TestTheAccessRowAppearsInTheReadersOwnLedgerView` and `TranscriptsWire.TestTheAccessRowAppearsInTheAdministratorsOwnLedgerView` red (runs 1415, 1416)
- mutation: register `TranscriptPage` under another descriptor name (rebuilt, redeployed) → `transcripts.browser-spec` red
- mutation: delete the user's conversations in `Retention.SweepGonePrincipals` → `Retention.TestADeletedUsersSettingsGoAndTheirTranscriptsStay` red (run 1417)
- mutation: drop the `Propose.GuardedDeleteForTurn` cascade from `Turn.GuardedDelete` → `Retention.TestATurnPastRetentionTakesItsProposalsAndLeavesItsEntry` red (run 1418)
- mutation: rename `UserDelete.AfterWrite` → `ToolWrite.TestADeletedAccountsTurnsAreAbandonedByTheDelete` red (run 1419)
- mutation: remove the `Try` around `Retention.Sweep`'s first step → `Retention.TestAFailingStepIsLoggedAndTheLaterStepsStillRun` red (run 1733)
- mutation: purge the ledger at a one-day cutoff in `Retention.Sweep` → `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` red (run 1739)
- mutation: drop the `CreatedAt` fallback in `Entry.GuardedPurge` → `Retention.TestAnOlderEntryAgesByItsConversationAndTheDefault` red (run 1740)
- mutation: drop `Turn:GuardedLiveUsers` from `SweepGonePrincipals` → `Retention.TestEachStoreNamesAGoneAccountToThePass` red (run 1741)
- mutation: make `IsGone` ignore `pUnavailable` → `Retention.TestAnUnreadableIdentityRemovesNothing` red (run 1753)
- mutation: answer `started` as `lastActivity` in `Convo.GuardedScreenRows` → `TranscriptStore.TestTheListNamesConversationsWithEntriesAndTitlesOnlyTheCallersOwn` red (run 1742)
- mutation: `RetentionTask.OnTask` answers OK without sweeping → `RetentionTask.TestAForcedRunRemovesAnExpiredEntryAndRecordsSuccess` red (run 1743)
- mutation: drop the probe branch of `retentionTaskClass` in `Installer.Names` → `RetentionTask.TestAProbeProfileSchedulesNoTaskAndLeavesTheProductionOne` red (run 1744)
- mutation: record an access row on an own read in `GateTurns` → `TranscriptGate.TestNoAdministrativePairIsRefusedAndAnOwnReadRecordsNothing` red (run 1745)
- mutation: stop mapping `AUTH.NOPRIVILEGE` to the shared 404 in `Transcripts.HandleRead` → `TranscriptsWire.TestANonAdministratorGetsTheSameNotFoundAsAnUnknownId` red (run 1746)
- mutation: drop the retention input's `(input)` binding → `definition-form.page.spec.ts` "Story 14.4 AC2" red
- mutation: pass `""` for the definition in `Job.AppendConvoEntry` (throwaway) → `transcripts.browser-spec` red

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Entries keep screen context, definition and time; a daily `%SYS.Task` (installer step `EnsureRetentionTask`, 03:15, vendor-default run user, which measured as the saving account) runs `Kernel.Retention.Sweep`; `Ledger.ReleasesRow`/`GateTurns`/`RecordTranscriptAccess`; `GET /transcripts/:id`; Transcripts list and transcript page; editable retention field; `UserDelete.AfterWrite`; `Turn.GuardedDelete` cascades proposals (DW-1240); ledger purge (DW-1122).

**Files.** Stores (`Kernel/State/` Entry, Convo, Ledger, Agent, Turn, Pref, Sharing, Base), `Kernel/Agent/Job.cls`, `Kernel/Audit/Ledger.cls`, new `Kernel/Retention.cls` and `RetentionTask.cls`, `Install/Installer.cls`, `Screen/Tool/UserDelete.cls`, new `Api/Transcripts.cls` and `Router.cls` route, two new descriptors, client page/store/strings/form, EXPERIENCE.md :336/:646/:736 (981 lines), tests (5 new classes, `AcceptPort` and `RetentionIdentityDown` fixtures, `ToolWrite`, `ProposalWrite`, rosters, three client suites, `transcripts.browser-spec`), `ci-throwaway.sh` arming lists.

Contended files: EXPERIENCE.md, `scripts/ci-throwaway.sh`, `Api/Router.cls`, `Kernel/State/Pref.cls`, `Test/Descriptor.cls`, `Test/EndpointCoverage.cls`, `Test/SurfaceCoverage.cls`, `screens.generated.ts`, `strings.ts`, `turn.ts` — add-only, off Epic 16's hunks.

**Measured on `ocupilot-b-ci`.** Registry admits the readless detail and the empty-`entityType` list; a deleted account reads `pKnown` 0 / `pUnavailable` 0 and its token answers 401 `AUTH.DISABLED`; a forced task run records Status 1.

**Review.** 30 findings: 12 patched (7 medium, 5 low), 2 deferred (medium), 16 rejected with reasons in the triage log. Verification fixes before review: `Retention.Sweep` wraps each step in `Try`; `ProposalWrite.TestAProposalWhoseTurnRecordIsGoneIsRefused` removes only the turn row (the cascade now takes proposals). Follow-up review recommended: 7 medium test patches landed after the review layers read the diff, including a probe install/uninstall leg in `RetentionTask` that shares the probe profile with the Installer suites on CI.

**Verification.** Full ObjectScript sweep on `ocupilot-b-ci`: 311 classes, 2564 tests, 1 failure (`ProposalWrite`, fixed and re-run green, run 1731); every class touched after the sweep re-run green (runs 1747-1755). `npm test` 1505 + 1496 pass; `npm run build` 1.87 MB initial; browser `transcripts`, `definitions`, `panel` 23/23 after redeploy; smoke 49/49; check-objectscript 0; lint-docs clean. Every mutation above reverted byte-identical.

**Residual risk.** A transcript withheld for a row's shape shows no reason; the two deferred coverage gaps.
