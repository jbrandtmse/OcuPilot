---
title: 'Story 16.15: The data-egress line'
type: 'feature'
created: '2026-09-30'
status: 'done'
baseline_revision: '96499dbc9fb562d695263185aece17f97ef16262'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The context chip shows where the next turn's screen context would go, and only to a person who reads it. Nothing in the transcript records where a turn's screen data actually went. The chip's re-read after a default-marker move is pinned only at store level (DW-1076). Separately, a Gemini endpoint without a `{model}` placeholder silently calls a model the definition does not name (DW-1192).

**Approach:**

- The provider port records an egress fact for each dispatched call: provider, endpoint host and whether the call leaves the instance. It uses the one computation the chip's `/agent/context` read uses, applied to the values the call was dispatched with.
- The turn keeps that fact on its row and its conversation entry, and the panel renders it as one line beneath the turn's message.
- A second probe definition on a private host, plus a browser leg, prove the chip and the line follow a real "Set default".
- A Gemini definition whose endpoint omits `{model}` is logged when it is saved and noted on the Definition form.

## Boundaries & Constraints

**Always:**

- **One computation (AD-42).** Add `ProviderPort.EgressOf(pProvider, pEndpoint, pMarkedLocal, ByRef pSettings)`. It answers `{provider, endpointHost, leavesInstance}`:
  - `endpointHost` is `Kernel.Egress.HostOf(pEndpoint)`.
  - The proxy is `ProxyHostOf`, blanked for a marked-local definition.
  - `leavesInstance` is `Kernel.Egress.LeavesInstance`.
  - The chip (through `ResolveEndpoint` → `Api/Context`) and the line (through `Dispatch`) both take their verdict from this method. Nothing client-side judges egress.
- **Recorded at dispatch.** `Dispatch` builds the fact only after every port-level refusal has passed, immediately before `tAdapter.Invoke`, from the `tEndpoint`, `tMarkedLocal` and `tSettings` that call uses. A call refused earlier records nothing.
- **Turn rule.** The turn keeps the first dispatched call's fact. If a later call leaves while the kept fact does not, the turn keeps that later call's fact instead, so a line never says "did not leave" for a turn whose data left. Each kept fact also records `contextSent`, which is `pContext '= ""`.
- **Storage.** The kept fact is JSON text in a new `Egress` property on `Kernel.State.Turn` and on `Kernel.State.Entry`.
  - No `SCHEMAVERSION` move: an older row reads `""`, which means no line. Record that reasoning at each property.
  - The fact is a snapshot. It is data, never a reference to the definition (AD-37).
- **Wire.** Add one key, `egress`, as `{provider, endpointHost, leavesInstance, contextSent}` or `null`, to two reads:
  - the progress payload, after `error`;
  - each conversation turn, after `stepsDropped`.
  - `Test/TurnWire`'s two key rosters move with it. Transcripts' `TurnObject` does not copy it.
- **Rendering (AD-11 rule 4, AD-33, AD-35).**
  - The line is text interpolation only, beneath `.ocu-panel-message-user` inside `.ocu-panel-turn`, so it is inside the `role="log"` transcript.
  - The words carry the meaning. A line that left adds the egress-warning colors as a supplement.
  - `<provider>` and `<host>` are filled by split and join, the same way `pillTitle` fills them.
  - An absent, `null` or malformed `egress` renders no line.
- **Copy and docs.**
  - The strings are published in EXPERIENCE.md Fixed strings and in `strings.ts`. EXPERIENCE.md is edited in place and stays at 993 lines.
  - The new CSS is appended to `_components.scss`.
  - Never hand-edit a Storage section.
- **Testing.** CI and every test use the stub provider (`turnprobe`).

**Never:**

- A second egress judgment, a client-side one included.
- A line computed from the current default or from `/agent/context` at render time.
- A line that names a model. DW-1192's third clause holds by construction.
- A new preference, screen, write tool, governance key or error code.
- The line on the Transcript page.
- A refusal of a placeholder-less Gemini endpoint, or a create-time model rule (DW-1192, second half, deferred).
- A logged endpoint URL, key or credential.
- Reading `.env.local`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Left | Sharing on; the Users screen; the default is A at `https://192.0.2.10/v1/messages` | `egress` is `{turnprobe, 192.0.2.10, true, true}`, equal to `/agent/context`'s provider, endpointHost and leavesInstance. The line reads `egressLineLeft`, filled, with the leaves modifier. | none |
| Stayed (AC3) | The default is B at `https://10.0.0.5/v1/messages` (private, unmarked) | `leavesInstance` is false. The line reads `egressLineStayed`, with no modifier. The chip draws no pill. | none |
| Proxy | B is the default, and the public proxy `192.0.2.99` is stored in `Kernel.State.Egress` | The line and the chip both answer true | Restore the proxy setting in teardown |
| Marked local | `EgressOf` is called with a marked-local flag and a public proxy | false, the same as `EgressLocal`'s chip leg | none |
| Sharing off | `PUT /agent/context {share:false}`, then Send | `contextSent` is false. The line reads `egressLineNone`. | Restore `share: true` |
| No call | The default's endpoint is refused by the address policy (an unmarked loopback, `PROVIDER.EGRESS`) | `egress` is `null` on the poll and on the conversation entry. No line is drawn. | Turn error banner as today |
| Two calls | The kept fact stays and a later call leaves; or the kept fact leaves and a later call stays | `Loop.KeepEgress` keeps the fact that leaves, in both orders | none |
| Default moved | Turn 1 on A, then the default moves to B, then turn 2 | Turn 1 keeps A's line, live and after reload. The chip, and turn 2's line, name B. | none |
| Old row or malformed | `egress` is missing, `""`, or of the wrong shape | `parseEgress` answers `null`, and no line is drawn | none |
| Markup host | `endpointHost` is `<img src=x>` (component test) | Rendered as text. No `img` element; no request. | none |
| Gemini, no placeholder (DW-1192) | Create, or update, of a `gemini` definition at `https://192.0.2.20/v1beta/models/pinned:generateContent` | One info line under `agent-definition` naming the definition id, its name and its Model as unused. No URL. The form shows `agentDefinitionModelUnused` under Endpoint. | A failed log is never a failed save |
| Gemini, placeholder | The endpoint carries `{model}` or is empty | No line, no note | none |

</intent-contract>

## Code Map

Server:

- `src/OcuPilot/Port/ProviderPort.cls`
  - `Invoke` :96: add a trailing `Output pEgress`, set to `""` before any `Quit`. Pass it to `Dispatch`.
  - `Dispatch` :254 (private): add `ByRef pEgress`. Set it just before `Do tAdapter.Invoke` (~:353).
  - `InvokeDraft` passes nothing.
  - `ResolveEndpoint` :370: keep its outputs, add a trailing `Output pLeaves`, and derive host, proxy and verdict through the new `EgressOf`.
- `src/OcuPilot/Api/Context.cls` :109-118: take `tLeaves` from `ResolveEndpoint`. The direct `LeavesInstance` call goes.
- `src/OcuPilot/Kernel/Egress.cls` :617 `LeavesInstance`, :95 `HostOf`: reused. Read-only.
- `src/OcuPilot/Kernel/Agent/Loop.cls`
  - `Run` :121, Invoke at :219: add `.tEgress`.
  - After the call, `tKept = ..KeepEgress(tKept, $Get(tEgress), pContext '= "")`, and `pOutcome("egress") = tKept`.
  - Pass `tKept` to `GuardedProgress` (~:239).
  - Initialize `pOutcome("egress") = ""` beside `citations` (:129).
  - New pure `KeepEgress` returns JSON text.
- `src/OcuPilot/Kernel/Agent/Job.cls`
  - `Run` :87-104: pass `$Get(tOutcome("egress"))` to `AppendConvoEntry`, on the normal path and in the `Catch`.
  - `AppendConvoEntry` :118: add a trailing `pEgress`.
- `src/OcuPilot/Kernel/State/Turn.cls`
  - New `Property Egress As %String(MAXLEN = 1000)` after `Citations` :101.
  - `GuardedProgress` :346: add a trailing `pEgress = ""`, written when non-empty.
  - `GuardedView` :544: add `egress` after `error`.
  - New `EgressObject(pJson)` answers the typed object, or `""` for empty, unparseable or wrong-shape text. It is the precedent of `CitationsArray` :670.
- `src/OcuPilot/Kernel/State/Convo.cls` `AppendEntry` :113: add a trailing `pEgress`, passed through.
- `src/OcuPilot/Kernel/State/Entry.cls`
  - New `Egress` property (as Turn's).
  - `GuardedAppend` :95: add a trailing `pEgress`.
  - `GuardedRows` :143: add `egress` after `stepsDropped`, through `Turn.EgressObject`.
- `src/OcuPilot/Api/Turn.cls` :201 and `Api/Conversation.cls` :70: pass the view through unchanged. Read-only.
- `src/OcuPilot/Kernel/Provider/Gemini.cls` `RequestUrl` :82-91: the early return uses a new `ClassMethod ModelUnused(pEndpoint) As %Boolean` (endpoint non-empty and lacking `MODELPLACEHOLDER` :50). The doc at :77-78 names the log and the note.
- `src/OcuPilot/Api/Definitions.cls`
  - After `LogChange` in `HandleCreate` :409 and in `HandleUpdate` :489, call a new `NoteModelUnused(pId, ByRef pAfter)`.
  - The predicate: the shipped `Kernel.Provider.Catalog` row's `defaultEndpoint` carries `{model}`, `endpointUrl` is non-empty, and `Gemini.ModelUnused` holds.
  - It emits through the `LogInfo` seam :1683, so `DefinitionsProbe` → `LogProbe` captures it as the last line.
- `src/OcuPilot/Test/TurnWireFixture.cls` :217: add `LOCALENDPOINTURL` = `https://10.0.0.5/v1/messages` and a definition named `OcuPilotProbeAgentTurnWireLocal`.
  - `EnsureLocalDefinition(pTag, .pId)` creates a `turnprobe` definition, enabled and verified, sharing `CREDENTIAL`, and leaves the marker alone. Call it after `EnsureDefinition`.
  - `MarkDefault(pId)`.
  - `SetEndpoint(pId, pUrl)`, in `SetTag`'s shape :242, for the No call leg.
  - `RemoveDefinition` :275 already removes it (the `OcuPilotProbeAgent` prefix).
- `src/OcuPilot/Test/EgressLocal.cls` :133 `StoreProxy`: the shape for storing and restoring a proxy through `Kernel.State.Egress.SetGuarded`.
- `src/OcuPilot/Test/TurnContext.cls`: the shape of a start body that carries a valid `context`.
- `src/OcuPilot/Test/TurnWire.cls` :134, :237: the key rosters.
- `src/OcuPilot/Test/EgressLocal.cls`, `ContextBound.cls`, `TurnContext.cls` :485: existing chip pins. They are expected green.
- `src/OcuPilot/Test/DefinitionsFaults.cls` :51-125: the shape for an unarmed in-process create through `Test.Dispatch` → `RouterFixture` `/agent-definitions`. `LogProbe.Captured("message")` holds the last line.
- `scripts/ci-throwaway.sh`: add `EgressLine` to the `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER` roster comments, add-only (`ui/tools/ci.test.mjs` :2175).

Client:

- `ui/src/app/core/turn.ts`
  - `TurnEntry` :312: add `egress: TurnEgress | null`.
  - New exported `TurnEgress` and `parseEgress`.
  - Fill `egress` in `pollOnce` :1617-1632, `parseRestoredEntry` :688-705, and the two `send()` literals :1167 and :1191 (`null`).
  - `finalizeLive` keeps it through the spread.
- `ui/src/app/core/egress-line.ts`: new, framework-free. `egressLine(egress)` answers `{text, leaves} | null` from `STRINGS`.
- `ui/src/app/shell/panel.ts`
  - `PanelTurnView` :190: add `egress`.
  - `turns` getter :972: fill it.
  - Template: after `<p class="ocu-panel-message-user">` :466, add `@if (turn.egress) { <p class="ocu-panel-egress-line" [class.ocu-panel-egress-line-leaves]="turn.egress.leaves">{{ turn.egress.text }}</p> }`.
- `ui/src/app/core/strings.ts`: append `egressLineLeft`, `egressLineStayed` and `egressLineNone` (`/** EXPERIENCE.md:261 */`), and `agentDefinitionModelUnused` (`/** EXPERIENCE.md:335 */`).
- `ui/src/styles/_components.scss`: append `.ocu-panel-egress-line`. It is `body-small`, `--ocu-on-surface-variant`, `align-self: flex-end`, and max-width 86%. The `-leaves` modifier is `--ocu-egress-warning` on `--ocu-egress-warning-container`, padded like `.ocu-context-chip-pill` :3778.
- `ui/src/app/areas/agent/definition-form.page.ts`
  - Inside the Endpoint `.ocu-field` :199-216, draw `<p class="ocu-field-caption" [id]="endpointField.id + '-caption'">` when a new `showModelUnused` holds. It holds when `store.provider()?.defaultEndpoint` contains `{model}` and the endpoint is non-empty and lacks it.
  - `fieldView` :1184 joins `-caption` for `endpointUrl` when the caption is drawn.
- `ui/src/app/core/agent-context.ts` :286 (`onChange`), `ui/src/app/areas/agent/definition-actions.ts` :119 (`setDefault` → publish): read-only. The chip re-read that DW-1076's leg proves.
- `ui/browser/turnprobe-spec.mjs` :129: append `ensureLocalDefinition(options, tag)`, in `ensureDefinition`'s shape.
- `ui/angular.json` :51-57 and `ui/tools/angular-json.test.mjs` :395: the warning budget is 2384kB with 377 B of headroom. Re-base under DW-1166 to the measured total rounded up. HALT above 3800kB.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: rows :261 and :335 (Fixed strings) and the `message-user` row :609 (Component Patterns), edited in place.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/ProviderPort.cls`: add `EgressOf`, `Invoke`'s `pEgress`, `Dispatch`'s set, and `ResolveEndpoint`'s `pLeaves`. One computation serves the chip and the line (AD-42).
- `src/OcuPilot/Api/Context.cls`: read the verdict from `ResolveEndpoint`.
- `src/OcuPilot/Kernel/Agent/Loop.cls`, `Job.cls`: implement `KeepEgress`, the outcome and the progress write, and pass the fact to the conversation entry.
- `src/OcuPilot/Kernel/State/Turn.cls`, `Entry.cls`, `Convo.cls`: implement the `Egress` properties, `EgressObject`, and the `egress` key on both reads.
- `src/OcuPilot/Kernel/Provider/Gemini.cls`, `src/OcuPilot/Api/Definitions.cls`: add `ModelUnused` and `NoteModelUnused` (DW-1192, first half).
- `src/OcuPilot/Test/TurnWireFixture.cls`, `ui/browser/turnprobe-spec.mjs`: build the two-host fixture (DW-1076).
- `src/OcuPilot/Test/EgressLine.cls` (new; armed like `TurnWire`, with `ARMINGVARIABLE` `OCUPILOT_ALLOW_PRINCIPALS` and `PROVIDERVARIABLE` `OCUPILOT_ALLOW_TEST_PROVIDER`; at most about 500 lines). Its legs, over the wire as `USERA`:
  - the Matrix rows Left, Stayed, Proxy, Sharing off, No call and Default moved, each on the poll and on `GET /conversation/:id`, each comparing provider, host and verdict with `GET /agent/context` taken before the move;
  - a start body that carries a `context` as `TurnContext` sends one, a `TurnProvider` script for each definition's tag, the No call leg through `SetEndpoint(B, "https://127.0.0.1/v1/messages")`, and the Proxy leg stored and restored as `EgressLocal.StoreProxy` does;
  - the two `KeepEgress` orders;
  - `EgressObject`'s malformed inputs;
  - `EgressOf`'s marked-local leg.
- `src/OcuPilot/Test/TurnWire.cls`: add `egress` to both rosters.
- `scripts/ci-throwaway.sh`: add the two roster entries.
- `src/OcuPilot/Test/GeminiModelUnused.cls` (new; unarmed, in `DefinitionsFaults`' shape):
  - the `Gemini.ModelUnused` cases;
  - a create and an update through `RouterFixture` `/agent-definitions`. The captured last line names the id, the name and the Model, and holds no `https://` and no host. A placeholder endpoint captures the change record instead.
  - Clean up the probe definitions afterwards.
- `ui/src/app/core/turn.ts`, `egress-line.ts`, `panel.ts`, `strings.ts`, `_components.scss`: build the line.
- `ui/tools/turn-egress.test.mjs` (new): `parseEgress` (good, `null`, malformed, wrong types), the poll carrying `egress` into the live entry, the restore carrying it, and `egressLine`'s three sentences.
- `ui/src/app/shell/panel-egress.spec.ts` (new): the three cases, the leaves class, no line for `null`, and the markup host rendered as text with no `img`.
- `ui/src/app/areas/agent/definition-form.page.ts` and `.page.spec.ts`: the note shows for a `gemini` row without the placeholder, and hides with it, with an empty endpoint and for another row. `aria-describedby` names it.
- `ui/browser/egress-line.browser-spec.mjs` (new). Arm A and B, script each definition's tag through `scriptReply`, sign in, open Users.
  - Leg 1 (Integration AC, AC1): the chip shows `192.0.2.10` with its pill. A scripted turn draws `egressLineLeft` with the modifier.
  - Leg 2 (DW-1076, AC3, AC4): on Agent co-pilot › Definitions, select B and press `Set default`. With no reload, the chip reads `10.0.0.5` with no pill. The next turn draws `egressLineStayed`, and turn 1's line is unchanged. After a reload both lines are restored.
  - Leg 3: sharing off draws `egressLineNone`. Restore sharing.
  - Disarm in `after`.
- `ui/angular.json`, `ui/tools/angular-json.test.mjs`: re-base the warning if it is crossed (DW-1166).
- `EXPERIENCE.md`: edit rows :261, :335 and :609 in place (see Design Notes, Copy). Run `cd ui && npm run test:tools`.

**Acceptance Criteria:**

- **Integration AC.** Given a turn on a screen that shares context, when the panel polls `GET /turn/:id/progress` and later reads `GET /conversation/:id`, then the panel renders the line from that `egress` beneath the turn's message. This is observable in the browser leg.
- **AC1.** Given context sharing on and a turn that dispatched a provider call, when the panel renders it, then one line names the provider and endpoint host and states whether screen context left the instance.
- **AC2.** Given a dispatched call, when its egress is recorded, then it is `EgressOf` over the values the call was dispatched with. For the definition that was the default at the time, provider, host and verdict equal `/agent/context`'s, with and without a proxy. A mutation of `EgressOf` reddens both the chip pin (`EgressLocal`) and the line pin (`EgressLine`).
- **AC3.** Given a provider on a private network, or marked local, when the line renders, then it says the screen context did not leave the instance, and the chip shows no pill.
- **AC4 (DW-1076).** Given a turn on A, when B is made the default through the Definitions list's Set default, then the chip's host and pill follow with no reload. The next turn's line names B. The earlier turn keeps A's line, live and after a reload.
- **AC5.** Given sharing off, or no screen context sent, when a turn dispatches a call, then the line says it sent no screen context and names the provider.
- **AC6.** Given a turn whose every call was refused before dispatch, or an entry stored before this story, when the panel renders it, then no line is drawn.
- **AC7 (DW-1192).** Given a `gemini` definition saved with an endpoint lacking `{model}`, when it is created or updated, then one info line names the definition and its unused Model, with no URL. The Definition form says so under Endpoint, and the egress line names no model.

## Spec Change Log

## Review Triage Log

### 2026-10-01 — Review pass

- verdicts: 19 findings — high 0, medium 2, low 12, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` A call refused at the proxy or TLS check is not pinned to record no egress — added `EgressLine.TestATurnWhoseProxyWasRefusedRecordsNoEgress` (loopback proxy; `null` on the poll and the entry).
  - `[medium]` `[patch]` A dispatched call that then fails is not pinned to keep its egress, on the server or in the panel — added `EgressLine.TestADispatchedCallThatFailedStillRecordsItsEgress` (401) and a failed-turn case in `panel-egress.spec.ts`.
  - `[medium]` `[patch]` The marked-local flag `Dispatch` passes to `EgressOf` is unpinned for the line — added `EgressLine.TestAMarkedLocalDefaultRecordsThatTheDataStayed` and `TurnWireFixture.SetMarkedLocal`.
  - `[low]` `[patch]` `NoteModelUnused`'s catalog-row condition is unpinned — an `anthropic` case added to `GeminiModelUnused.TestAnEndpointWithThePlaceholderOrNoneLogsOnlyTheChangeRecord`.
  - `[low]` `[patch]` Four EgressLine entry checks and the post-move turn-1 poll can skip silently — size and status assertions added before each guard.
  - `[low]` `[patch]` The `EgressOf` marked-local leg used a loopback host, so its verdict could not fail for a dropped flag — the host is now the public `192.0.2.10`.
  - `[low]` `[patch]` AC4's server-side live check is guarded (same root cause as the skipping checks) — closed by the same assertions.
  - `[low]` `[patch]` `Turn.EgressObject`'s test has no missing or wrong-typed `endpointHost` case — both added.
  - `[false]` `[reject]` AC7's update half has no `mutation:` line — Rule 19 asks one demonstrated mutation per AC; AC7's create leg carries it (run 23320).
  - `[low]` `[reject]` A refusal inside the adapter (no key, a mismatched built URL) records "left" though nothing is sent — spec-bound: the intent contract records "immediately before `tAdapter.Invoke`", and Named limits states this consequence.
  - `[low]` `[reject]` The line appears only once the first call returns, while EXPERIENCE.md says "once the turn has dispatched a provider call" — Named limits states it, and the published sentence (the spec's own Copy) holds as written.
  - `[false]` `[reject]` "Values the call was dispatched with" is held by structure, not by a test — no bad outcome; the reviewer names none, and the refusal-ordering mutations pin the call site.
  - `[low]` `[reject]` The two-call rule is tested on the pure `KeepEgress` only — every call of a turn uses one definition, so differing facts need a mid-turn settings change; a loop-level seam adds surface for a case users rarely meet.
  - `[low]` `[reject]` "A failed log is never a failed save" is untested — the note runs after the save and the change record, inside a `Try` with an empty `Catch`; a fault-injection seam is more than a direct correction.
  - `[false]` `[reject]` The live line is covered only by browser legs — that is the surface the intent names, and `egress-line.browser-spec.mjs` ran 4/4 against the redeployed bundle.
  - `[low]` `[patch]` `Entry.Egress`'s doc says it is copied from `Turn.Egress` — reworded: passed in at append time, the same text `Turn.Egress` holds.
  - `[low]` `[patch]` `Convo.GuardedView`'s doc lists the turn keys without `egress` — added.
  - `[false]` `[reject]` `EgressOf` takes five parameters where the intent lists four — the four inputs carry the specified semantics; the optional fifth output keeps `ResolveEndpoint`'s proxy on the same computation.
  - `[false]` `[reject]` The budget re-base and the roster comments lie outside the intent — both are in the spec's Code Map and Tasks (DW-1166; `ci.test.mjs`).

## Design Notes

**Governing ADs:**

- AD-42: one computation, the proxy, marked local.
- AD-33 and AD-7: the progress payload in protected storage, written by the job.
- AD-11 rule 4: text only.
- AD-24: sharing decides `contextSent`.
- AD-37: a snapshot, not a reference.
- AD-41: bounded, under 1,000 characters a turn.
- AD-35: no URL or key logged.
- AD-9: the Loop's write is a guarded leaf call.
- AD-19 and AD-14: the store is framework-free, and the chip re-reads on the bus.
- AD-39: a provider failure is still a turn error.
- AD-50: no preference.
- AD-22: no write key.

**Decisions for the lead** (the spec implements each as recommended):

1. **Recorded at dispatch, not at turn start.** A start-time snapshot would claim egress for a call the address policy refused. The fact comes from the call's own values, which is the AC's "configuration the request actually uses".
   - Alternative: snapshot at `Api/Turn` start.
2. **Transport.** One key on the progress payload and on the conversation read. AD-33 is amended below.
3. **Sharing off, or no context sent.** The line reads `egressLineNone`, because every dispatched turn reports. AC1 covers only sharing on.
   - Alternative: draw no line.
4. **Placement.** Beneath the user's message, because the message and its context went together.
   - Alternative: after the reply.
5. **DW-1192.** An info line at save, through `Definitions`' existing log seam. Both sides use the same predicate: the provider's canonical endpoint carries `{model}` and the stored endpoint does not.

**Copy** (EXPERIENCE.md, in place, 993 lines). Append to row :261's String cell:

- "This turn's screen context went to <provider> at <host> and left the instance."
- "This turn's screen context went to <provider> at <host> and did not leave the instance."
- "This turn sent no screen context to <provider>."

Then append to its Where cell: "; and the data-egress line beneath each turn's message (Story 16.15), `<provider>` and `<host>` resolving to the turn's own provider key and endpoint host as the context chip names them `[AMENDED 2026-10-01 - Story 16.15]`".

Append to row :335's String cell:

- "This endpoint has no {model} placeholder, so Model is not used; calls go to the model the endpoint names."

Then append to its Where cell: "; and the note beneath Endpoint when the provider's canonical endpoint carries `{model}` and the typed one does not (Story 16.15, DW-1192)".

Append to row :609 (`message-user`): "Beneath it, once the turn has dispatched a provider call, the data-egress line (Story 16.15): the turn's own recorded provider, host and verdict, never the current default's; text, with the egress-warning colors added only when it left; restored with the conversation `[AMENDED 2026-10-01 - Story 16.15]`".

**Spine amendments for the lead (Rule 20):**

- **(a) AD-33**, a new paragraph after the streaming paragraph:

  > **A turn's egress joins the progress payload** [AMENDED 2026-10-01, Story 16.15 spec gate, Rule 20]: `egress`, `{provider, endpointHost, leavesInstance, contextSent}` or `null` until a provider call of the turn has been dispatched, is the fact `ProviderPort` derived for that call (AD-42), kept by the job on the turn row and on its conversation entry and carried by the conversation read too. It is configuration, never model or tool content, and is rendered as text.

- **(b) AD-42**, after "so it cannot disagree with where the request actually goes.":

  > So is each turn's data-egress line (Story 16.15): `ProviderPort.EgressOf` is the one computation both use, the line's over the values its call was dispatched with, a call refused before dispatch recording nothing, and a turn keeping the first call's fact unless a later call leaves. The chip forecasts the next turn from the current default; the line reports the turn that ran, so after a default-marker move they may differ for an earlier turn [AMENDED 2026-10-01, Story 16.15 spec gate, Rule 20].

**Named limits:**

- The line appears once the turn's first provider call returns. Before Send, the chip is the forecast.
- A call the adapter refuses before opening a connection (no key, an unusable Gemini model), or whose connection never opens, still records its destination. The line errs toward "left" (inference).
- A job lost mid-call records nothing.
- A definition saved before this story logs at its next save. Its form shows the note at once.

**Integration (Rules 1 and 2):**

- **Consumes:**
  - Story 4.11's chip and `AgentContext` re-read;
  - Story 10.3's `LeavesInstance` and proxy bypass;
  - Story 4.5's conversation entry and restore;
  - Story 11.7's progress poll;
  - Story 10.2's Gemini adapter.
- **Consumed-by:** the panel, in this story: the Integration AC. No later consumer is planned.

**Ledger:**

- DW-1076 is addressed by AC4, the two-host fixture and browser leg 2.
- DW-1192 (first half) is addressed by AC7.
- Declined DW-1192 (second half, the create-time model rule): deferred by the merge-gate decision of 2026-09-19.
- Declined DW-1335: resolved by Story 15.9 (epic context).
- Declined DW-118: resolved by Story 15.6 (epic context).

**Footprint.** Epic 18 (`.worktrees/epic-18`) was checked on 2026-09-30. It changes no source file this story edits. The shared files are edited add-only.

The bundle budget is 2384kB in `angular.json`, not the 2346kB the spawn prompt states.

## Verification

This runs on slot A. Every test runs on `ocupilot-ci`, one run at a time. Never restart it.

- **Loading.** From the worktree root, run `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>`. Read every line of its output. Recompile each changed class together with its subclasses: `Kernel/Agent/Loop` with `Test/*LoopProbe` and `Test/Ledger*Probe`, `Port/ProviderPort` with `Test/ProviderPortProbe` and `Test/ProviderOwnerProbe`, and `Api/Definitions` with `Test/DefinitionsProbe`, `Test/DefinitionsFieldGapProbe` and `Test/AgentConnectionProbe`.
- **ObjectScript classes.** Run each class through the shim, with the full arming list: `cd ui && EPIC16_ARM="OCUPILOT_ALLOW_ACCOUNT_PREFERENCES OCUPILOT_ALLOW_AUDIT_EVENTS OCUPILOT_ALLOW_AUDIT_PURGE OCUPILOT_ALLOW_AUDIT_TOGGLE OCUPILOT_ALLOW_DATABASE_CONFIG OCUPILOT_ALLOW_ERROR_DELETE OCUPILOT_ALLOW_ERROR_SEED OCUPILOT_ALLOW_LOG_ROTATION OCUPILOT_ALLOW_NAMESPACE_CONFIG OCUPILOT_ALLOW_PRINCIPALS OCUPILOT_ALLOW_PROCESS_CONTROL OCUPILOT_ALLOW_PRODUCTION_INSTALL OCUPILOT_ALLOW_SERVICE_CONFIG OCUPILOT_ALLOW_SSL_CONFIG OCUPILOT_ALLOW_TASK_CONTROL OCUPILOT_ALLOW_TEST_PROVIDER" PATH=/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16-recover/shim:$PATH node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`.
- **Browser.** Rebuild and redeploy first (`cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`). Then export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `(loop)` `cd ui && npm run test:tools` -- expected: green.
- `(loop)` `cd ui && npx ng test --include src/app/shell/panel-egress.spec.ts --include src/app/shell/panel.spec.ts --include src/app/areas/agent/definition-form.page.spec.ts` -- expected: green.
- `(loop)` One class per call, where `<C>` is each of: `EgressLine`, `GeminiModelUnused`, `TurnWire`, `TurnContext`, `TurnLoop`, `TurnStore`, `TurnConversation`, `TurnCitations`, `TurnStream`, `EgressLocal`, `ContextBound`, `Egress`, `ProviderPort`, `ProviderProxy`, `ProviderStream`, `PortGate`, `GeminiAdapter`, `Convo`, `TranscriptStore`, `TranscriptsWire`, `DefinitionsFaults`, `AuditVerbs` -- expected: green.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/egress-line.browser-spec.mjs browser/context-chip.browser-spec.mjs browser/turn.browser-spec.mjs browser/definitions.browser-spec.mjs` -- expected: green. Report the build's initial total.
- `(once, before dev_complete)` `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md -- expected: green, and 993 lines.
- `(once, before dev_complete)` The full ObjectScript sweep on `ocupilot-ci`, one class at a time -- expected: green, apart from the residue the spawn prompt names. The full browser suite runs in CI only (Rule 29).

**Mutations** (Rule 19; one per AC; each reverted with the tree byte-identical afterwards):

- Integration and AC1: the template drops the line → `panel-egress.spec.ts` and browser leg 1. `GuardedView` omits `egress` → `TurnWire` and `EgressLine`.
- AC2: `EgressOf` ignores the proxy → `EgressLine`'s proxy leg and `EgressLocal`. `Dispatch` sets `pEgress` before its address-policy refusal → `EgressLine`'s No call leg.
- AC3: `EgressOf` answers `leavesInstance` 1 → `EgressLine`'s Stayed leg and browser leg 2.
- AC4: `AgentContext.onChange` ignores `agent-definition` → browser leg 2's chip host. `Entry.GuardedRows` reads the current default's fact → the Default moved leg.
- AC5: `KeepEgress` writes `contextSent` true always → `EgressLine`'s Sharing off leg. `egressLine` ignores `contextSent` → `turn-egress.test.mjs` and browser leg 3.
- AC6: `parseEgress` accepts a missing `leavesInstance` as false → `turn-egress.test.mjs`.
- AC7: `HandleCreate` skips `NoteModelUnused` → `GeminiModelUnused`'s create leg. `showModelUnused` answers false → `definition-form.page.spec.ts`.
- The two-call rule: `KeepEgress` keeps the first fact always → `EgressLine`'s order leg.
- AD-11 rule 4: the line is bound with `[innerHTML]` → `panel-egress.spec.ts`'s markup leg.

Demonstrated (2026-10-01, `ocupilot-ci`; each reverted, recompiled or rebuilt, tree byte-identical after):

- mutation: the panel template drops the `@if (turn.egress)` block → `panel-egress.spec.ts` (2 of 3 red) and browser Leg 1 (no line).
- mutation: `Turn.GuardedView` omits `egress` → `TurnWire.TestAStartRunsAsTheCallerAndThePollAnswersItsShape` (key roster, run 23311) and `EgressLine` (6 of 9 red, run 23312).
- mutation: `EgressOf` ignores the proxy → `EgressLine.TestAProxyMakesTheLineAndTheChipLeave` (run 23313) and `EgressLocal.TestAnUnmarkedDefinitionBehindAPublicProxyStillLeaves` (run 23314).
- mutation: `Dispatch` sets `pEgress` before its scheme and address-policy refusals → `EgressLine.TestATurnWhoseCallWasRefusedRecordsNoEgress` (run 23315).
- mutation: `EgressOf` answers `leavesInstance` 1 → `EgressLine.TestAPrivateDefaultRecordsThatTheDataStayed` (run 23316) and browser Leg 2 (chip keeps the pill).
- mutation: `AgentContext.onChange` ignores `agent-definition` → browser Leg 2 (chip keeps naming `192.0.2.10`).
- mutation: `Entry.GuardedRows` builds `egress` from the current default → `EgressLine.TestMovingTheDefaultLeavesEachTurnItsOwnEgress` (turn 1's entry names B, run 23317).
- mutation: `KeepEgress` writes `contextSent` true always → `EgressLine.TestSharingOffRecordsThatNoContextWasSent` (run 23318).
- mutation: `egressLine` ignores `contextSent` → `turn-egress.test.mjs` "sharing off reads the no-context sentence" and browser Leg 3.
- mutation: `parseEgress` accepts a missing `leavesInstance` as false → `turn-egress.test.mjs` "a missing, null or malformed egress parses to null".
- mutation: `HandleCreate` skips `NoteModelUnused` → `GeminiModelUnused.TestACreateWithoutThePlaceholderLogsTheUnusedModel` (run 23320).
- mutation: `showModelUnused` answers false → `definition-form.page.spec.ts` "DW-1192: Endpoint carries the model-unused note".
- mutation: `KeepEgress` keeps the first fact always → `EgressLine.TestKeepEgressKeepsTheFactThatLeavesInEitherOrder` (run 23319).
- mutation: the line is bound with `[innerHTML]` → `panel-egress.spec.ts` "renders an endpoint host carrying markup as text".

Demonstrated at review (2026-10-01, same discipline):

- mutation: `Dispatch` passes 0 as the marked-local flag to `EgressOf` → `EgressLine.TestAMarkedLocalDefaultRecordsThatTheDataStayed` (run 23328).
- mutation: `Dispatch` records the fact only when the adapter returned no fault → `EgressLine.TestADispatchedCallThatFailedStillRecordsItsEgress` (run 23329); the panel draws the line only without an error banner → `panel-egress.spec.ts` "draws the line for a failed turn whose call was dispatched".
- mutation: `Dispatch` records the fact before its proxy refusal → `EgressLine.TestATurnWhoseProxyWasRefusedRecordsNoEgress` (run 23330).
- mutation: `EgressOf` passes 0 to `LeavesInstance` → `EgressLine.TestEgressOfAnswersStayedForAMarkedLocalCallBehindAPublicProxy` (run 23331); `Turn.EgressObject` drops its `endpointHost` check → `TestEgressObjectRefusesEveryMalformedText` (same run).
- mutation: `NoteModelUnused` skips the catalog-row check → `GeminiModelUnused.TestAnEndpointWithThePlaceholderOrNoneLogsOnlyTheChangeRecord` (run 23332).

## Auto Run Result

**Change.** `ProviderPort.EgressOf` is the one egress computation: the chip reads it through `ResolveEndpoint`, and `Dispatch` records it immediately before the adapter is invoked. `Loop.KeepEgress` keeps the first dispatched call's fact unless a later call leaves. The fact is stored on `Turn.Egress` and `Entry.Egress` (no `SCHEMAVERSION` move) and served as `egress` on the progress poll and on each conversation turn. The panel draws it as one text line beneath the message. A `gemini` save whose endpoint lacks `{model}` logs one info line, and the Definition form notes it under Endpoint (DW-1192, first half).

**Files.**

- Server: `Port/ProviderPort.cls` (`EgressOf`, `Invoke`/`Dispatch` egress, `ResolveEndpoint` verdict), `Api/Context.cls` (verdict from `ResolveEndpoint`), `Kernel/Agent/Loop.cls` (`KeepEgress`, outcome, progress write), `Kernel/Agent/Job.cls` (entry append), `Kernel/State/Turn.cls`, `Entry.cls`, `Convo.cls` (property, wire key, `EgressObject`), `Kernel/Provider/Gemini.cls` (`ModelUnused`), `Api/Definitions.cls` (`NoteModelUnused`).
- Server tests: `Test/EgressLine.cls` (new, 12 legs), `Test/GeminiModelUnused.cls` (new), `Test/TurnWire.cls` (both rosters), `Test/TurnWireFixture.cls` (private-host definition, `MarkDefault`, `SetEndpoint`, `SetMarkedLocal`), `scripts/ci-throwaway.sh` (two roster comments).
- Client: `core/turn.ts` (`TurnEgress`, `parseEgress`), `core/egress-line.ts` (new), `shell/panel.ts`, `core/strings.ts`, `styles/_components.scss`, `areas/agent/definition-form.page.ts`; tests `tools/turn-egress.test.mjs`, `shell/panel-egress.spec.ts`, `definition-form.page.spec.ts`, `browser/egress-line.browser-spec.mjs` (new), `browser/turnprobe-spec.mjs`.
- `ui/angular.json` and `angular-json.test.mjs`: the warning budget was re-based under DW-1166 from 2384kB to 2387kB, because the measured initial total was 2,386,319 B.
- EXPERIENCE.md rows 261, 335 and 609 were edited in place; the file is still 993 lines. No path outside the Code Map and Tasks was edited.

**Review.** 19 findings: 2 medium and 12 low verdicts, 5 false. Ten entries were patched: 2 medium, 8 low.

- The patches added five EgressLine legs and assertions: refused proxy, provider-refused call, marked-local turn, size and status guards, public marked-local `EgressOf` host, and `endpointHost` malformed cases.
- They also added a non-gemini `NoteModelUnused` case and a failed-turn panel case, and corrected two doc comments.
- Each new pin's mutation reddened its test (runs 23328-23332, and the panel case).
- Nine were rejected (see the triage log). Nothing was deferred.

**Follow-up review: `false`.** The two medium patches were test gaps, each now closed with a demonstrated mutation. No unverified risk can be named.

**Verification** (all on `ocupilot-ci`, one run at a time):

- **Full ObjectScript sweep, all 16 arming variables:** 389 classes, 3,223 tests, 6 failed, all known residue: `PathPortInstance` 1, `Retention` 1, `TaskHistory` 3, `WireSecurityRead` task-history 1. Story classes ran green (`EgressLine` 12, `GeminiModelUnused` 4, `TurnWire` 15).
- **Browser** (`egress-line`, `context-chip`, `turn`, `definitions`, rebuilt bundle): 32 of 32.
- **Client:** `npm test` 1,763 tools tests and 2,045 component tests.
- **Gates:** `check-objectscript.py` 0, `lint-docs.sh` 0, EXPERIENCE.md 993 lines.

**Residual risk.** Each dispatched call now resolves its endpoint (and proxy) host once more for `LeavesInstance` (inference: a lookup per call beside the address policy's own).

Status: done
Blocking condition: none
