---
title: 'Story 16.16: The agent audit viewer'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '7c224fc548c3c3f4eed711b9461f93b50759cfba'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A tool row's argument stays as the model typed it when its tool does not declare it secret, when it is a nested or case-variant spelling of a declared name, or when the call resolved no tool. The credential-name pattern still masks it where the pattern matches.
    evidence: |-
      Plan-stage probe on ocupilot-ci (2026-09-28): RecordToolCall stored `certificate`, a nested `Certificate`, `Value` and a PEM block under `Notes` verbatim. Every declared name at its own spelling read `[redacted]`. The only declared secret name the pattern misses is x509 import's `Certificate`.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls RedactArguments
    severity: low
  - summary: >-
      A tool step's target, in the turn's progress and its stored transcript, keeps a declared secret's value the model sent as `id`. The ledger row's target stores the mark (this story); the step's does not.
    evidence: |-
      Implement on ocupilot-ci (2026-09-28): OcuPilot_Kernel_State.Step.Target held the probe value for each permissions.users.password step agent-ledger.browser-spec.mjs ran, while the ledger rows read [redacted].
    location: >-
      src/OcuPilot/Kernel/Agent/Loop.cls AnswerTools (Dispatch.TargetOf into Step.GuardedAppend)
    severity: medium
  - summary: >-
      The local-to-UTC conversion's direction cannot be falsified on this project's test instances: ocupilot-ci and CI's throwaways run Etc/UTC, so local and UTC coincide and a swapped or missing conversion keeps every begin, end, time and echo assertion green.
    evidence: |-
      Review probe on ocupilot-ci: /etc/localtime is Etc/UTC, $ZTIMEZONE 0, $H equals $ZTS; a process-level $ZTIMEZONE change does not move $ZDATETIME(h,-3). Settling it needs one test run on a throwaway started with a non-UTC TZ.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls LocalToUtc, LocalFromUtc
    severity: medium
  - summary: >-
      A declared secret the model sent as id can show in the agent panel's tool-call card on the same page as the ledger, because the step's target keeps it (same root cause as the step-target entry above).
    evidence: |-
      Review inference, not reproduced: tool-call-card.ts renders a step's target; the browser spec reads only app-ledger-page.
    location: >-
      ui/src/app/shell tool-call card; src/OcuPilot/Kernel/Agent/Loop.cls AnswerTools
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The agent ledger already records every provider call, tool answer, confirmed write and transcript read. `GET /agent/ledger` (`Kernel.Audit.Ledger.ViewForUser`) reads it back through AD-46's per-row gate, but no screen calls that route. It reads one user at a time, filters by no screen or date, leaves out a write's field names, and records no screen on write rows. An administrator can see what the agent did only through SQL.

**Approach:**

- Extend the one ledger read with four criteria:
  - every user the caller may see;
  - the screen the turn ran from;
  - a begin and an end time.
- Record a write row's screen and add the missing columns to the wire row.
- Add an Agent audit ledger screen in the Agent co-pilot area. A custom page there searches through the route and opens each row's arguments and result in a dialog.
- The agent gets no read tool over the ledger (Design Notes).

## Boundaries & Constraints

**Always:**

- **One read, one gate (AD-46, AD-9, AD-29).**
  - `ViewForUser` gains trailing parameters `pAllUsers = 0`, `pRoute = ""`, `pBegin = ""` and `pEnd = ""`. When all four are defaulted, every existing caller gets the same answer as today.
  - Every decision stays in `Kernel.Audit.Ledger`, evaluated in the caller's process after each guarded read returns. The route, the page and the descriptor decide nothing.
- **Who sees which rows (AD-46, AD-36 as amended by 14.4, AD-8).**
  - `pAllUsers` 1 with no subject:
    - a caller holding `OcuPilotAdmin:USE` (through `GateClass().HoldsPrivilege`) reads every user's rows;
    - anyone else reads their own rows, and is not refused.
  - Across users, rows are released like this:
    - the caller's own rows (user equal, ignoring case) are always released;
    - every other row passes `ReleasesRow` or is withheld and counted in `rowsWithheld`;
    - a named `user` behaves as it does today.
  - A read that reached another user's rows records one `LedgerRead` event through `RecordRead`. For an every-user read, the event's subject is `*`.
- **Criteria (AD-21, AD-36).**
  - Every value is bound, with no concatenation. `route` is matched exactly against `Route`.
  - `begin` and `end` are instance local time in `Screen.Read`'s `DATETIMEFORM`. One pure kernel helper converts them to the ledger's UTC ISO form, and both the handler's validation and `ViewForUser` call it.
  - The window runs from `begin`, and `begin` may be at most `BOUNDEDMAXHOURS` (720) hours ago.
  - With no `begin`, the window is `BOUNDEDDEFAULTHOURS` (24).
  - A `turnKey` read ignores all four criteria.
  - The view adds `criteria {user, route, begin, end, allUsers}`, the values it applied, in local time.
- **Wire row.** `RowObject` adds three members:
  - `fields` and `fieldsTruncated`, which the store already answers;
  - `time`, which is `loggedAt` as instance local `YYYY-MM-DD HH:MM:SS`. `loggedAt` stays.
- **Write rows record their screen.** `Confirm` reads the turn's `ContextRoute` through `Turn.GuardedForOwner`, which gains `route`, and passes it to `OpenConfirmedWrite` as a new trailing `pRoute = ""`. A failed read records `""` and never fails the confirm (AD-15 posture).
- **Secrets (AD-41, AD-3, AD-35).**
  - Secrets are excluded at write time and never redacted afterwards; the viewer masks nothing.
  - `RecordToolCall` also stores the redaction mark as the row's `Target` when the target contains the string value of a declared secret argument the input carries. This gap was measured at plan time.
- **Route (AD-12, AD-39).**
  - `Api/Ledger.cls` stays thin. It validates `all` (`""` or `1`), `route` (`^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$`, up to 512 characters), `begin` and `end` (shape, calendar, and `end` not before `begin`). It also refuses `begin` together with a non-zero `windowHours`, and `all` together with a non-empty `user` (criterion `all`).
  - A failing value answers 400 `LEDGER.CRITERION.INVALID` with `detail.criterion`. A `begin` more than 720 hours ago answers 400 `LEDGER.WINDOW.INVALID`, with the existing reason plus its bound.
  - The new code and its reason join `Api/Error.cls`'s `LEDGER.*` list and reason map (shared-append).
- **Screen (AD-5, AD-44).** `Screen/Descriptor/AgentLedger.cls`:
  - route `agent/ledger`, `labelKey` `agentLedgerLabel`, `sideBarPosition` 5; Transcripts moves to 6;
  - archetype `list (server criteria)`, `privileges` `[]`, `entityType` `""`, scope `instance`;
  - `id` composite `["ledgerId"]`, so `agent/ledger/:id` exists;
  - `context` `{fields: [], secretFields: []}`;
  - `emptyStateKey` `agentLedgerEmpty`;
  - aliases "agent audit ledger", "ledger", "agent activity";
  - three `auditUserEventPromptGroup` prompts;
  - `classicPage` `""`, `toolIdentifier` `agent.ledger`;
  - **no `read` and no `table`**.
- **Page (AD-19, AD-20, AD-11 rule 4).** `LedgerPage` is registered in `DESCRIPTOR_PAGES`. Its search state lives in a root-provided, framework-free store that is reset at sign-out (the `AuditSearch` precedent), so opening a row's dialog keeps the search.
  - **Criteria form:** User (text, 160); Screen (a select of every built screen with a route, grouped under its area label in rail order, plus "Any"); Begin and End (text, with the local-time hint); Search.
  - **Search.** It searches once on open. Every search sends `all=1` when User is empty. The form then shows the applied `criteria`.
  - **Columns:** Time (`time`), User, Kind (a label per kind), Name, Screen (the mirror's label for the route, else the route), Target (a `$Char(2)`-joined reference shown as its parts joined by " · "), and Status (`status`, plus `· code` when a code is present).
  - **Chrome:** the row-count and cap lines reuse the data table's `tableRowCount` and `tableRowCapNotice`. A withheld line appears when `rowsWithheld` > 0, and a dropped line when `rowsDropped` > 0.
  - **Row dialog.** A row opens a dialog at `agent/ledger/<ledgerId>` with two text blocks:
    - Arguments: the stored string verbatim, or the empty-cell word;
    - Result: `{status, code, fields, fieldsTruncated, auditMarked, model, requestTokens, responseTokens, requiredPairs, pairsSense}`.
  - Everything renders as text, never markup.
  - The page publishes no screen-context rows.
- **Strings.** Every new string goes into `strings.ts`, appended as a `// Story 16.16` block with `/** EXPERIENCE.md:336 */`. EXPERIENCE.md is edited in place and stays 993 lines:
  - :336 carries the same strings;
  - :152's Where cell gains "; Agent audit ledger (Story 16.16): every signed-in user sees their own rows, and an OcuPilot administrator every user's, each other user's row gated by the privileges it records".

  Existing keys are reused wherever a value already exists.

**Never:**

- No read tool, no `read` on the descriptor, and no ledger row in screen context or in any provider request.
- No redaction or masking in the page, the route or `RowObject`.
- No second gate in the route or the page, and no ledger row written for a ledger read.
- No write key, no governance key, no new route and no `SCHEMAVERSION` move.
- No new index on the ledger; an every-user read scans within its window (named limit).
- No change to what `GateTurns`, `GET /transcripts/:id` or a default `GET /agent/ledger` answers.
- No after-the-fact rewrite of rows stored before this story.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Ordinary user opens | U1 has rows; U2 has rows | only U1's rows; `allUsers` false | none |
| Ordinary user names another | U1 sends `user=U2` | 403; the page shows "You need OcuPilotAdmin:USE to see another user's agent activity." with no rows | `AUTH.NOPRIVILEGE`, `failedPair` |
| Admin, every user | A holds `OcuPilotAdmin:USE` and R1 but not R2; U2 has rows needing R1 and R2; A's own rows need R2 | A's rows listed, U2's R1 row listed, U2's R2 row absent; `rowsWithheld` 1 and the withheld line shown; one `LedgerRead` event with subject `*` | none |
| Admin names U2 | `user=U2` | R1 row listed, R2 row withheld (today's behavior) | none |
| Screen filter | `route=os-management/processes` | only rows with that `Route`, a confirmed write from a turn on that screen among them | none |
| Date filter | `begin`/`end` local | rows inside the window only; the form echoes both | none |
| Default window | no `begin` | 24 h; the form shows the applied begin | none |
| Old begin | `begin` more than 720 h ago | form-level refusal showing the reason | 400 `LEDGER.WINDOW.INVALID` |
| Bad criterion | `route=../x`, `all=2`, `begin=2026-02-30 00:00:00`, `end` before `begin` | refusal naming the criterion | 400 `LEDGER.CRITERION.INVALID` |
| Declared secret | a tool call with `Password` set to V, also sent as `id`; a confirmed secret-bearing write | arguments show `[redacted]`, target shows `[redacted]`, `fields` never names `Password`; V appears nowhere in the page or the route body | none |
| Overflow | a turn past `LEDGERMAXROWS` | the dropped line shows the count | none |
| Stale dialog | `agent/ledger/<id>` not among the rows | the no-longer-present sentence | none |
| Unreadable store | a store fault | Retry and the refused-request line | 503 `LEDGER.UNAVAILABLE` |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Audit/Ledger.cls` (outside Epic 16's paths; uncontended; report it):
  - `ViewForUser` :560
  - `ReleasesRow` :667
  - `RowObject` :808
  - `RecordRead` :844
  - `RecordToolCall` :261 (the target check goes beside `RedactArguments` :365)
  - `OpenConfirmedWrite` :298
  - `AppliedWindow` :796
  - `GateClass` and `HoldsPrivilege` :52 and :572 (the test seam `Test/LedgerGateProbe.cls`)
- `src/OcuPilot/Kernel/State/Ledger.cls` (report it):
  - `GuardedIdsForWindow` :368 and `GuardedDroppedFor` :386 each gain trailing `pRoute`, `pBeginUtc`, `pEndUtc` and `pAllUsers`, whose predicates are passed to `BoundedWhere` as literals.
  - `GuardedRow` :420 already answers `fields`. Nothing else changes; `GateTurns` :695 calls with positional arguments only.
- `src/OcuPilot/Kernel/State/Base.cls`: `BoundedWhere` :998 (window modes, predicate varargs), `BOUNDEDDEFAULTHOURS` 24 and `BOUNDEDMAXHOURS` 720 :143-146. Rule 21 of `scripts/check-objectscript.py` requires literal SQL.
- `src/OcuPilot/Kernel/State/Turn.cls` (report it): `GuardedForOwner` :511 gains `pValues("route")` from `ContextRoute` :92.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls`: `OpenConfirmedWrite` :411; the private `FieldNames` :834 is the write-time exclusion, exposed to tests as `Test/MarkerConfirm.cls` `FieldNamesFor` :25.
- `src/OcuPilot/Api/Ledger.cls`: `Handle` :56 and `RenderFault` :104. `src/OcuPilot/Api/Error.cls`: `LEDGER*` :983-1030. `Screen/Read.cls` `DATETIMEFORM` :122.
- `src/OcuPilot/Screen/Descriptor/AgentTranscripts.cls` is the template, and its `sideBarPosition` goes from 5 to 6.
- **Client** (`ui/src/app/`):
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :112-142.
  - Precedents in `areas/logs/audit.page.ts`: the criteria form :73-121, the `/:id` dialog :123-147 and :288-304. The root store is `audit.store.ts` :45, reset at `app.ts:559-561`.
  - `areas/logs/error-log.page.ts` :131-190 is a grid drawn with the data-table classes and no declared read.
  - `areas/agent/transcript.page.ts` and `transcript.store.ts`: phases, `formatDeniedAction`, and the no-longer-present sentence.
  - `core/navigation.ts` `hasIdRoute` :507 and `screenForRoute`.
  - `shell/data-table.ts` :944-960 has the count and cap strings.
- **Reused strings:**
  - `auditColumnTime`, `processColumnUser`, `tableColumnName`, `taskHistoryColumnStatus`, `taskHistoryColumnResult`;
  - `auditCriteriaBegin`, `auditCriteriaEnd`, `auditCriteriaTimeHint`, `auditCriteriaSearch`, `auditCriteriaAnyOption`;
  - `tableReadOnlyEmptyNext`, `privilegeDeniedAction`, `faultAbsentEntity`, `connectivityRequestRefused`.
- **Rosters:**
  - `Test/Wire.cls` :464 (7 → 8) and :487-490 (Transcripts at 6).
  - `ui/tools/navigation.test.mjs` :205-234 (built 8, listed 6, the ledger before Transcripts).
  - `Test/SurfaceCoverage.cls` :56-62.
  - `screens.generated.ts`, regenerated with `node tools/screen-mirror.mjs`.
  - `Test/ReadTool.cls` :93 stays 128 (the no-tool pin).
  - `scripts/ci-throwaway.sh` :203 principal-arming roster and `ui/tools/ci.test.mjs`, both add-only.
- **Test precedents:**
  - `Test/Ledger.cls` (in-process over `LedgerGateProbe`).
  - `Test/TranscriptsWire.cls` (real principals, rows seeded in process, `OCUPILOT_ALLOW_PRINCIPALS`).
  - `Test/AuditMarker.cls` `Seed` and `FIXTURECONFIRM` (a confirmed write on a seeded turn).
  - `ui/browser/transcripts.browser-spec.mjs` and `turnprobe-spec.mjs` (`armProbeDefinition`, `scriptReply`, `runIris`).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Ledger.cls`: add the four trailing selections to `GuardedIdsForWindow` and `GuardedDroppedFor`. `pAllUsers` 1 omits the user predicate and is the only way to do so. Add the begin and end predicates on `LoggedAt`, and the route predicate.
- `src/OcuPilot/Kernel/Audit/Ledger.cls`:
  - Extend `ViewForUser` as the Always block describes: subject resolution, the every-user release loop, `criteria`, and `RecordRead` with `*`.
  - Add the pure local-to-UTC helper, and the `time`, `fields` and `fieldsTruncated` members in `RowObject`.
  - In `OpenConfirmedWrite`, add the trailing `pRoute`.
  - In `RecordToolCall`, withhold a target that carries a declared secret value.
- `src/OcuPilot/Kernel/State/Turn.cls`: add `route` to `GuardedForOwner`'s values. `src/OcuPilot/Kernel/Proposal/Confirm.cls`: read the route and pass it at :411.
- `src/OcuPilot/Api/Ledger.cls` and `Api/Error.cls`: the new query parameters, their validation, and `LEDGER.CRITERION.INVALID`. `RenderFault` is unchanged.
- `src/OcuPilot/Screen/Descriptor/AgentLedger.cls` (new) and `AgentTranscripts.cls` (position 6), as the Always block describes.
- `ui/src/app/areas/agent/ledger.store.ts` and `ledger.page.ts` (new, standalone, `OnPush`). Register the page in `shell/screen-outlet.ts`, reset the store in `app.ts`, and add styles only if needed (`_components.scss` tail, append-only).
- `ui/src/app/core/strings.ts` (tail block) and EXPERIENCE.md :336 and :152, in place, with these values:
  - "Agent audit ledger", "No agent activity matches.", "Kind", "Screen", "Target", "Arguments";
  - "Model call", "Tool call", "Confirmed write", "Transcript read";
  - "<n> rows withheld: each records a privilege you do not hold.", "<n> calls were counted and not stored.", "see another user's agent activity";
  - "Who used the agent to change anything this week?", "Which web applications did the agent change this week?", "Did the agent change any user or role today?".
- Tests:
  - `src/OcuPilot/Test/LedgerSearch.cls` (new, in process over `LedgerGateProbe`): the criteria, the every-user release, the `criteria` echo, `time` and `fields`, the write row's route through `FIXTURECONFIRM`, the secret legs, and the declaration of `AgentLedger` (no read, no context fields).
  - `src/OcuPilot/Test/LedgerSearchWire.cls` (new, armed, principals U1, U2 and A as in the Matrix): the route's legs and refusals. Clean up principals and rows.
  - Update the rosters in the Code Map.
  - `ledger.store.spec.ts` and `ledger.page.spec.ts`.
  - `ui/browser/agent-ledger.browser-spec.mjs`: a `turnprobe` turn from Processes calls `osmgmt.processes.read` and a `permissions.users.password` call carrying V as `Password` and as `id`. The ledger, filtered to Processes, lists both; each dialog shows arguments and result; V is absent from the page text. The spec deletes its turn's rows and disarms the probe.

**Acceptance Criteria:**

- **AC1.** Given ledger rows of several users, screens and times, when a user opens Agent audit ledger, then:
  - it searches once with the defaults and lists the rows newest first with the seven columns;
  - setting User, Screen, Begin or End and pressing Search lists only the matching rows;
  - pressing a row opens `agent/ledger/<ledgerId>` showing that row's Arguments and Result.
- **AC1b.** Given a proposal minted in a turn started on a screen and then confirmed, when the viewer is filtered to that screen, then the write's row is listed.
- **AC2.** Given an ordinary user, when they open the viewer, then only their own rows are listed, and naming another user shows the refusal sentence naming `OcuPilotAdmin:USE`, with no rows.
- **AC3.** Given an OcuPilot administrator holding one resource another user's row records and lacking one another row records, when they search every user or name that user, then:
  - the first row is listed;
  - the second is absent and counted in the withheld line;
  - their own rows are listed;
  - the decision is `Kernel.Audit.Ledger`'s, over the same `GET /agent/ledger` the page calls.
- **AC4.** Given a tool call carrying a declared secret value (also as its id) and a confirmed secret-bearing write, when their rows are listed and opened, then:
  - the value appears nowhere on the page or in the route's body;
  - the declared name is absent from the write row's fields;
  - both hold because the writers excluded them at write time.
- **AC5.** Given the registry and the screen, when tools and screen context are derived, then no read tool reads the ledger (the `ReadTool` roster stays 128) and the screen's context carries no rows.
- **Integration (Rule 1).** Given a real instance, when `LedgerPage` calls `GET /agent/ledger` with its criteria, then the rows the extended `ViewForUser` answers render with the dialog (browser spec).

## Spec Change Log

- 2026-09-28T08:45Z, lead spec gate: the two spine changes under Design Notes (AD-46's "read by people, not by the agent"; Conventions › Dates) are written into the spine by the lead in this gate's commit. `Kernel/Audit/Ledger.cls`, `Kernel/State/Ledger.cls` and `Kernel/State/Turn.cls` are accepted as footprint extensions (uncontended).

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 29 findings — high 0, medium 13, low 12, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` VG: the browser spec could not tell the Screen search's answer from the open search's — now waits for the `route=` response and asserts its `criteria.route` and rows; mutation re-observed red.
  - `[medium]` `[patch]` VG: sign-out reset of `LedgerSearch` unpinned — `app.spec.ts` AD-8 leg added with its mutation.
  - `[medium]` `[patch]` VG: the store's late-answer guard untested — store-spec test (replaced search, reset while in flight) added with its mutation.
  - `[medium]` `[defer]` VG: local↔UTC direction is unobservable on UTC-only instances (`ocupilot-ci` and CI run `Etc/UTC`) — needs a non-UTC throwaway; out of footprint (compose/CI config). Code follows `$ZDATETIME`/`$ZDATETIMEH` dformat -3 as documented.
  - `[medium]` `[patch]` VG: the begin predicate could not redden — begin moved to 39.5 h with a row at 39.75 h inside the cutoff slack; mutation observed red.
  - `[medium]` `[patch]` VG: default `criteria.begin` checked for shape only — value asserted as 24 h before now; mutation observed red.
  - `[medium]` `[patch]` VG: no leg showed a target without the value survives — AC4 test gains the other-account leg; over-mask mutation observed red.
  - `[medium]` `[patch]` VG: `rowsDropped` under route and every-user untested — `TestTheDroppedCountFollowsTheCriteria` added; mutation observed red.
  - `[medium]` `[patch]` VG: `windowHours = 40` could read 41 across a second boundary — begin at 39.5 h makes the ceiling a steady 40.
  - `[low]` `[patch]` VG: browser `args.length > 0` could not fail — now parses the stored arguments as a JSON object.
  - `[low]` `[patch]` VG: "was seeded" assertions could not fail — now `TurnRowCount(key) = 1` in both classes.
  - `[medium]` `[defer]` VG: round-trip and drift assertions hold whatever the conversion direction on a UTC instance — same root cause and entry as the UTC item above.
  - `[low]` `[reject]` VG: sub-behaviours of AC1, AC2, AC4, AC5 lack their own mutation lines — Rule 19 asks one demonstrated mutation per AC; every AC has one, and this pass adds eight.
  - `[low]` `[reject]` IA: the `*` event is recorded on every administrator every-user read, not only when another user's row was met — auditing a read across users by its scope is the conservative reading; counting first adds a branch for no user-visible gain.
  - `[low]` `[reject]` IA: the route validates the criteria even beside a `turnKey` — no caller sends both; AD-12's thin route refuses a malformed value wherever it arrives.
  - `[medium]` `[patch]` IA: the page showed the generic reason without naming the refused criterion — the store keeps `detail.criterion` (a window refusal maps to Begin), the named field takes `aria-invalid` and `aria-describedby` to the refusal, and a tail style marks it; page and store specs added with a mutation.
  - `[false]` `[reject]` IA: the whole-mark arguments change is not in the contract — the Matrix's declared-secret row requires arguments to read `[redacted]`, which the fail-closed `""` did not.
  - `[medium]` `[defer]` IA: V may show in the panel's tool-call card outside the ledger page — pre-existing; the step target is the Loop's (Story 4.x), the same root cause as the implement-stage deferred entry.
  - `[false]` `[reject]` IA: a default `GET /agent/ledger` answers new members — the Always block adds `criteria`, `time`, `fields` and `fieldsTruncated`; rows and gating are unchanged.
  - `[false]` `[reject]` IA: ":152's Where cell" has no literal column — the note sits in the Purpose cell beside 16.22's, as written.
  - `[false]` `[reject]` IA: an ordinary user's echoed User sends `user=<self>` next — it reads the same own rows as `all=1`.
  - `[low]` `[reject]` IA: `rowsDropped` sums other users' overflow rows without the per-row gate — a count carries no row content, and the named-user read already counts ungated.
  - `[low]` `[reject]` IA: AC1b sets `ContextRoute` by SQL rather than from a turn begun on a screen — the Job→`ContextRoute` leg is 11.9's and pinned there; this pins Confirm→`OpenConfirmedWrite`.
  - `[low]` `[reject]` IA: AC4's write-row half runs in process through `FieldNamesFor`, not `Confirm.Transition` — the exclusion is `Confirm.FieldNames`, pinned since 5.6 through `MarkerConfirm`.
  - `[low]` `[reject]` IA: the withheld, denied, dropped, stale and 503 lines are pinned on stubs — each has its wire test and the browser spec is the real-runtime leg (Rule 3).
  - `[medium]` `[patch]` IA: `rowsDropped` under the new selections has no test — same root cause and fix as the VG dropped-count row.
  - `[low]` `[reject]` IA: a begin within a second of the 720 h bound can pass the route and fail in `ViewForUser` (500) — reachable only at that second; the status is logged and nothing leaks.
  - `[low]` `[patch]` IA: `Api.Ledger.Handle`'s doc omitted `criteria` and `all` — corrected.
  - `[low]` `[reject]` IA: nothing asserts an ordinary `all=1` records no event — `tEvery` is 0 on that path by the same line the AC2 mutation pins.

## Design Notes

**Governing ADs:**

- AD-46, AD-9, AD-36 (with its 14.4 amendment), AD-41, AD-3, AD-35, AD-8, AD-29 and AD-37 (a gone user's rows still read);
- AD-5, AD-24, AD-44, AD-11 rule 4, AD-12, AD-39, AD-13, AD-15, AD-19, AD-20, AD-21;
- AD-22 and AD-60 (no key and no tool, so the sanitizer is not reached);
- Conventions › Dates and › Secrets.

No AC contradicts an AD.

**The agent does not read the ledger.** The descriptor therefore declares no `read`. Every declared read derives an advertised read tool (`Tool/Registry.cls:160-172`, with no opt-out), and a `state` read can neither take criteria nor host AD-46's gate, because `Kernel.State` may not name `OcuPilot.Screen` (Rule 7). The reasons:

- **The ledger holds other users' activity.** An administrator's turn would send another user's targets and model-authored arguments to the provider. 14.4 released another user's text only on the caller's own rows for the same reason.
- **Arguments are model-authored text shaped by what the model read (AD-11).** Replaying them would make a one-time injection persist. AD-60's sanitizer is additional and is never the defense.
- **The authoritative record of agent writes is already readable.** It is the audit markers, through `logs.audit.read` with `eventSources` `OcuPilot` (AD-15, AD-46). The three prompts are answered there (inference: not run against a model).

AD-36 is not bypassed: with no tool, there is nothing to diverge from, and the read stays bounded and reports `truncated`, `rowsWithheld` and `rowsDropped`. The precedents are `LogErrorList` and 14.4's transcript page.

**Why a custom page.** `list (server criteria)` maps to the audit-specific `AuditPage`. With no declared read, the shared data table and its CSV download (16.23) do not apply. That is a named limit: this page has no Download CSV.

**Secrets were verified on `ocupilot-ci` at plan time, not assumed.** The probe covered 1,390 existing rows plus probe rows, cleaned up by count.

- Every declared secret at its own name reads `[redacted]` in tool-row arguments.
- 197 write rows of secret-declaring tools name no declared secret in `fields`.
- `permissions.users.password` records `fields` `""`.
- Two gaps:
  - A declared value the model also sent as `id` reached `Target`. This story closes it at write time.
  - Undeclared, nested or case-variant names are stored as typed; see the `deferred:` entry.
- Rows stored before this story are not rewritten.

**Named limits (each `wontfix-theoretical` unless made real):**

- Rows older than 720 hours are not reachable from the viewer. The existing route has the same bound, and default retention is 30 days.
- An every-user read scans its window with no index. Retention bounds the scan (inference).
- Write rows stored before this story and access rows record no screen, so they match only "Any".

**Spine change for the lead (Rule 20; non-contradicting):**

- **AD-46**, append: "**The ledger is read by people, not by the agent** [AMENDED 2026-09-28, Story 16.16 spec gate, Rule 20]. The agent audit viewer reads it through `GET /agent/ledger` (`ViewForUser`). A caller sees their own rows; an `OcuPilotAdmin:USE` holder who asks for every user also sees each other user's row that passes the per-row gate. The viewer's descriptor declares no read, so no read tool reads the ledger and no ledger row enters screen context or a provider request. A write row records the screen its turn ran from, and a tool row whose target carries a declared secret's value stores the redaction mark there, at write time (AD-41)."
- **Conventions › Dates**, append: "The agent audit viewer's criteria, and each ledger row's `time`, are the instance's local clock time as `YYYY-MM-DD HH:MM:SS`, converted on the instance. `loggedAt` stays ISO UTC (Story 16.16)."

**Integration.**

- **Consumes:** `ViewForUser` and `ReleasesRow` (14.4's Consumed-by names this story), the `access` rows, `Turn.ContextRoute`, and `Confirm.FieldNames`.
- **Consumed-by:** `LedgerPage` in this story. No later story is planned; the extended criteria serve any later reader.

**Footprint (Rule 11).**

- Outside the listed paths, uncontended, reported under `footprint_extensions`: `Kernel/Audit/Ledger.cls`, `Kernel/State/Ledger.cls` and `Kernel/State/Turn.cls`.
- Shared-append: `Api/Error.cls`, `strings.ts`, `_components.scss`, and EXPERIENCE.md :336 and :152 (in place).
- Contended add-only: `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs`.
- Existing-line edits: `AgentTranscripts.cls` (position), `Confirm.cls` :411, the counts in `Wire.cls` and `navigation.test.mjs`.
- There is no bundle re-base unless the build crosses 2107kB; if it does, re-base under DW-1166 and report the size.

**Ledger inbox:** empty. **Measured at implement, never recalled:**

- the local-to-UTC conversion, round-tripped;
- that `Event.Record` lands a `LedgerRead` row with subject `*`;
- that the registry and mirror admit a `list (server criteria)` descriptor with an `id` and no `read`;
- that `agent/ledger/:id` is built.

## Verification

Slot A. Load every changed `.cls` into `ocupilot-ci` only, never `ocupilot`, and run one test class at a time. Before each browser run, `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, and export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, for `LedgerSearch`, `LedgerSearchWire`, `Ledger`, `LedgerWire`, `LedgerPairs`, `LedgerEmptyPairs`, `LedgerSense`, `TranscriptGate`, `TranscriptsWire`, `AuditMarker`, `ProposalWire`, `Descriptor`, `ScreenRegistry`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Wire`, `ScreenGrounding` and `TurnContext`. Expected: 0 failures, with totals checked in `%UnitTest_Result`.
- `(loop)` `cd ui && npm run test:tools` (`navigation`, `screen-mirror`, `strings`, `suggested-prompts`, `classic-links`, `ci`) and `npx ng test --include src/app/areas/agent/ledger.page.spec.ts --include src/app/areas/agent/ledger.store.spec.ts --include src/app/shell/screen-outlet.spec.ts --include src/app/app.spec.ts`. Expected: green.
- `(loop)` `node --test --test-concurrency=1 browser/agent-ledger.browser-spec.mjs browser/transcripts.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/suggested-prompts.browser-spec.mjs`. Expected: green in both themes, with no new structural-baseline key.
- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh` and `wc -l` on EXPERIENCE.md. Expected: clean, and 993.
- `(once, before dev_complete)` The full ObjectScript sweep on `ocupilot-ci`, one class per call; then `cd ui && npm test && npm run build` (report the initial total against 2107kB); then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Pinning mutations (Rule 19; record each here as `mutation: … → …`):**

- AC1: `ledger.store` drops `route` from the query → `ledger.page.spec.ts` red and the browser spec red. Drop the route predicate in `GuardedIdsForWindow` → `LedgerSearch` red.
- AC1b: `Confirm` passes `""` for the route → the `LedgerSearch` write-route leg red.
- AC2: skip `HoldsPrivilege` in the every-user branch → the ordinary-user leg of `LedgerSearchWire` red.
- AC3: release other users' rows without `ReleasesRow` → `LedgerSearch` and `LedgerSearchWire` red.
- AC4: drop the target check in `RecordToolCall` → the `LedgerSearch` secret leg red, and, on the `ocupilot-ci` copy, the browser AC4 leg red (V appears in the Target cell); recompile it back afterwards. `Password` alone cannot redden the arguments leg: the name-pattern backstop still masks it.
- AC5: give `AgentLedger` a `read` → `ReadTool` red.

Applied at implement on `ocupilot-ci` (each reverted, recompiled with subclasses or rebuilt and redeployed, tree byte-identical):

- mutation: `ledgerPath` loops over `begin`, `end` only → `ledger.page.spec.ts` "Search sends User, Screen, Begin and End" and `ledger.store.spec.ts` "sends user, and never all" red; bundle redeployed → `agent-ledger.browser-spec.mjs` red (every listed row never reads Processes).
- mutation: `GuardedIdsForWindow` passes `""` for the route → `LedgerSearch.TestTheCriteriaSelectRowsAndEchoWhatTheyApplied` red (with the write-route and every-user legs).
- mutation: `Confirm` passes `""` to `OpenConfirmedWrite` → `LedgerSearch.TestAConfirmedWriteRecordsTheScreenItsTurnRanFrom` red alone.
- mutation: every-user branch sets `tEvery = 1` without `HoldsPrivilege` → `LedgerSearchWire.TestAnOrdinaryUserReadsTheirOwnRowsAndIsRefusedAnothers` and `LedgerSearch.TestAnOrdinaryUserAskingForEveryUserReadsTheirOwnRows` red.
- mutation: every-user rows skip `ReleasesRow` → `LedgerSearch.TestAnEveryUserReadReleasesOwnRowsAndGatesTheRest` and `LedgerSearchWire.TestAnAdministratorReadsEveryUserThroughThePerRowGate` red.
- mutation: `RecordToolCall` drops the `CarriesSecretValue` line → `LedgerSearch.TestADeclaredSecretReachesNoTargetNoArgumentsAndNoFields` red; browser spec red ("the password call's target is the redaction mark").
- mutation: `AgentLedger` declares a valid `read` and `table` → `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` red (131, not 130) and `LedgerSearch.TestTheLedgerScreenDeclaresNoReadAndNoContextFields` red.
- mutation: `Api.Ledger.Handle` drops the route shape check → `LedgerSearchWire.TestEachMalformedCriterionIsRefusedByName` red.
- mutation: `LocalToUtc` drops the `DATETIMEFORM` match → `LedgerSearch.TestTheLocalConversionRoundTripsAndRefusesANonInstant` red.

Applied at review on `ocupilot-ci` (same discipline):

- mutation: `ledgerPath` loops over `begin`, `end` only; bundle rebuilt and redeployed → `agent-ledger.browser-spec.mjs` red (the wait for the Search's `route=` response times out), independent of other screens' rows.
- mutation: `ViewForUser` passes `""` as the begin to `GuardedIdsForWindow` → `LedgerSearch.TestTheCriteriaSelectRowsAndEchoWhatTheyApplied` red (the row inside the whole-hour cutoff's slack is listed).
- mutation: `AppliedCriteria` adds the window instead of subtracting it → the same test red (the echoed begin reads -86400 s ago).
- mutation: `CarriesSecretValue` answers 1 whenever a declared value is present → `LedgerSearch.TestADeclaredSecretReachesNoTargetNoArgumentsAndNoFields` red (the other account's target reads the mark).
- mutation: `ViewForUser` passes `GuardedDroppedFor` only its four leading arguments → `LedgerSearch.TestTheDroppedCountFollowsTheCriteria` red on both counts.
- mutation: `LedgerSearch.search()` loses its generation check → `ledger.store.spec.ts` "drops a late answer…" red.
- mutation: the End field loses `[attr.aria-invalid]` → `ledger.page.spec.ts` "a refused criterion marks the field it names…" red.
- mutation: `App.verifyWhenSignedIn` loses `this.ledgerSearch.reset()` → `app.spec.ts` "AD-8: leaving the signed-in state…" red.

## Auto Run Result

Status: done
Blocking condition: none

**Implement (2026-09-28).**

- **Change:** `GET /agent/ledger` takes `all`, `route`, `begin` and `end`, validated in `Api/Ledger.cls` (400 `LEDGER.CRITERION.INVALID` naming the criterion; a begin past 720 h is `LEDGER.WINDOW.INVALID`). `ViewForUser` reads every user for an `OcuPilotAdmin:USE` holder through the per-row gate, records `LedgerRead` with `*`, and echoes `criteria`; rows carry `time`, `fields` and `fieldsTruncated`. Confirmed writes record their turn's screen. `RecordToolCall` stores the mark as the target when it carries a declared value, and as the arguments when the redaction fails closed for an object (the Matrix's declared-secret row). New `AgentLedger` descriptor (no read, no table, no context field; Transcripts to 6) and `LedgerPage` with its root store, reset at sign-out; a refused criterion marks its field.
- **Files:** kernel `Kernel/Audit/Ledger.cls`, `Kernel/State/Ledger.cls`, `Kernel/State/Turn.cls`, `Kernel/Proposal/Confirm.cls`; route `Api/Ledger.cls`, `Api/Error.cls`; descriptors `AgentLedger.cls` (new), `AgentTranscripts.cls`; client `areas/agent/ledger.store.ts`, `ledger.page.ts` (new), `shell/screen-outlet.ts`, `app.ts`, `core/strings.ts`, `core/screens.generated.ts`, `styles/_components.scss` (tail rule); docs EXPERIENCE.md :152 and :336 in place (993 lines); tests `LedgerSearch.cls`, `LedgerSearchWire.cls`, `ledger.store.spec.ts`, `ledger.page.spec.ts`, `agent-ledger.browser-spec.mjs` (new), and rosters `Wire`, `SurfaceCoverage`, `LedgerWire`, `TranscriptStore`, `LedgerFaultProbe`, `AuditMarker` (comment), `navigation.test.mjs`, `definitions.browser-spec.mjs`, `app.spec.ts`, `scripts/ci-throwaway.sh` (one roster line).
- **Counts re-derived from the merged tree:** `ReadTool` stays 130 (the spec text's 128 predates 18.1); 71 descriptors; the agent area builds 8 and lists 6.
- **Review:** 29 findings — 13 patched (10 medium, 3 low), 3 deferred (to frontmatter), 13 rejected with reasons (Review Triage Log). Follow-up review recommended: the review-added invalid-field marking is pinned in jsdom only, and the local/UTC direction is unverifiable on UTC-only instances (deferred).
- **Verification:** targeted classes green, including `LedgerSearch` 9/9 and `LedgerSearchWire` 3/3 after review. `npm test`: tools 1681/1681, components 1687/1687. Browser specs `agent-ledger`, `a11y-structural-invariants` (12/12) green after review; `transcripts`, `suggested-prompts` and `definitions` green at implement. `check-objectscript` and `lint-docs` clean. Build initial total 2.05 MB, under 2107 kB. Full ObjectScript sweep on `ocupilot-ci`: 338 classes, 2634 tests, 5 failed, all known residue (`Retention` 1, `TaskHistory` 3, `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`); 19 classes refused for arming variables. Smoke on `ocupilot-ci`: 49/49. No probe ledger row left.
- **Footprint extensions:** `Kernel/Audit/Ledger.cls`, `Kernel/State/Ledger.cls`, `Kernel/State/Turn.cls`, `ui/src/app/app.ts`, `ui/src/app/app.spec.ts` (add-only leg).

**Plan (2026-09-28).** Planned only; halted after planning as directed.

- **Surveyed:** the existing `GET /agent/ledger` and `ViewForUser` (no client consumer), the `state` source's limits (no criteria, and it cannot host AD-46's gate), read-tool derivation (no opt-out) and the agent-area rosters.
- **Probed on `ocupilot-ci`:** secret exclusion, with probe rows removed and the count back to 1,390. The target gap was found there, and this spec closes it.
- **Decided:** no agent read tool. The reasons, and two spine changes for the lead, are under Design Notes.
- **Ledger inbox:** empty.
- **Footprint extensions to report:** `Kernel/Audit/Ledger.cls`, `Kernel/State/Ledger.cls` and `Kernel/State/Turn.cls`.
