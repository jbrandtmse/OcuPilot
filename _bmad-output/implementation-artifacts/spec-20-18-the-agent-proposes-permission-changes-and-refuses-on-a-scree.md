---
title: 'Story 20.18: The agent proposes permission changes and refuses on a screen the user cannot open'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_revision: '1785544e38f0fa442e829698667efa5c0b43005d'
baseline_commit: '1785544e38f0fa442e829698667efa5c0b43005d'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 20.15 shipped Screen permissions' three write tools unadvertised, so the agent cannot propose a change. When a write tool's screen is closed to the user, dispatch's refusal names only a pair, the built-in prompt has no line for it, and screen context does not say whether the user can use the screen or its tools.

**Approach:**

- Advertise the three tools, and mint a lowering destructive through AD-10's effect classifier.
- Dispatch names the tool's screen when the user cannot open it. The tool step and its card carry that name, and the prompt says what to do.
- Screen context gains the screen's own verdict and marks the tools the user cannot use.
- An integration turn run as a real principal proves the refusal.

## Boundaries & Constraints

**Always:**

- **Lowering, decided at the mint, on the instance.**
  - A proposal is a lowering when the port's composed fresh read's `Result` lacks a pair its `Pairs` holds. Pairs are compared without regard to case, as `ScreenAccessPort.Apply` compares them.
  - So a remove-pair is always a lowering and an add-pair never is. A reset is a lowering when the adjusted set held a pair the declared set lacks.
  - `Prohibited.WeakensByEffect` answers effect `SCREENACCESS.LOWERED`. The mint then marks the proposal destructive and names that effect as its consequence.
  - The card is the standard destructive agent card: the bar and the destructive Confirm, with no typed-name field. Its consequence sentence reuses `screenPermissionsLowerConsequence`.
- **The screen comes from the tool's descriptor**: the registry entry's `descriptor`, else the tool class's `DESCRIPTORCLASS`. A new tool-registry method resolves it, because `Kernel/Agent` names no `OcuPilot.Screen.*` class but the registry (lint rule 19).
- **When the screen is named.**
  - It is named when dispatch's `RequiredPairs` leg refuses and dispatch's own `MissingPair` finds a pair of that screen's `Gate.RequiredPairs` missing. `MissingPair` reads the user's current grants (AD-31).
  - The refusal's detail is then `{failedPair: <the screen's first missing pair>, screen: <its toolIdentifier>}`.
  - Otherwise the detail is `{failedPair}`, as today.
  - The argument-pair leg and the client-call (navigation) path are unchanged. Who dispatch admits is unchanged.
- **The screen read route's refusal carries the same `screen`** (`Api/ScreenRead.cls`), so a tool's 403 and a screen's 403 stay identical (AD-8).
- **The step and its card.**
  - The step stores `FailedScreen`, and progress carries `failedScreen`.
  - The tool-call card renders "failed — You need <pair> to open <screen title>.", composed from two existing Fixed strings (`toolCallStatusFailed`, `privilegeDeniedScreen`).
  - An identifier the mirror does not know renders the pair alone, as today.
- **Screen context's two new members.**
  - Both are computed in the caller's request process by `Api/Turn.BoundedContext`, before the total bound, on both branches.
  - `verdict` is `{allowed, failedPair?}`, built by `Navigation.SetVerdict` for the screen's descriptor.
  - `unavailable` maps each wire name in `tools` whose `Registry.RequiredPairs` the caller lacks (`Gate.EvaluatePairs`) to its first failed pair. An unresolved set maps to `""` (fail closed). With nothing to mark it is `{}`.
  - `tools` is unchanged. A request carrying either member is refused `TURN.CONTEXT.INVALID`.
- **The prompt** stays one ASCII build-time constant (AD-11 rule 1).
- **Tests.** A test that adjusts a screen resets it in its `OnAfter*` method. Principals and adjustments live on `ocupilot-b-ci` only, and are removed afterwards.

**Never:**

- No new error code, audit event, route, governance key or `Baseline.cls` edit. The three keys already ship `true`.
- No change to any declared pair, to `tools`' string elements, or to who any gate admits.
- No typed-name field on an agent card.
- No new `strings.ts` literal and no `screens.generated.ts` regeneration: no descriptor changes.
- No edit to `Api/ScreenAction.cls`, `Api/Error.cls`, `Test/SurfaceCoverage.cls` or `Test/ReadTool.cls` (Epic 18 overlap). The screen action route's and the confirm's refusals keep `{failedPair}`.

## I/O & Edge-Case Matrix

- **P** is `TurnWireFixture`'s `USERA`, holding `Resources(1)` plus a second role with `%DB_IRISSYS:RW`.
- **Raised Locks** is the adjustment of `osmgmt.locks` to `%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Secure:USE`.
- **In process** means running as the test user, with `ToolDispatchProbe.DenyPair` where a row names it.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Raise | Agent `agent_screenpermissions_addpair` `{Screen: osmgmt.locks, Pair: %Admin_Secure:USE}` | Proposal with one `Pairs` row, before and after. `destructive` false, no consequence. `privilege.requires` reads `%Development:USE or %Admin_Secure:USE` | none |
| Lower | `removepair` `%DB_IRISSYS:READ` on declared Locks | `destructive` true, consequence `SCREENACCESS.LOWERED` | none |
| Reset | `reset` on Raised Locks; `reset` on Locks lowered to `%Admin_Operate:USE` | destructive true; destructive false | 409 `ACCESS.NOTADJUSTED` at the mint when nothing is adjusted |
| Confirm | Each proposal above, confirmed | Store changed. `readBack`: `nothingSent` for add and remove; for reset the adjustment reads gone. One `OcuPilot/Security/SecurityChange` row, one agent marker carrying the proposal id, and a `screen-permission` change event | none |
| Screen closed | P, Raised Locks: a turn calls `osmgmt_locks_remove` | Tool result `{"code":"AUTH.NOPRIVILEGE","detail":{"failedPair":"%Admin_Secure:USE","screen":"osmgmt.locks"}}`; the step's `failedScreen` is `osmgmt.locks`; no proposal row; the turn completes | refused before any mint |
| Screen open | In process, `%DB_IRISSYS:WRITE` denied: `osmgmt_locks_remove` | `{"failedPair":"%DB_IRISSYS:WRITE"}`, with no `screen` | refused |
| Demo operator | In process, `%Admin_Secure:USE` denied: `webapp_list_update` | detail names `webapp.list` and `%Admin_Secure:USE` | refused |
| Context | P on route `os-management/locks`, before and after the raise | Before: `verdict {allowed:true}`, `unavailable {}`. After: `{allowed:false, failedPair:"%Admin_Secure:USE"}`, and every Locks tool in `tools` maps to `%Admin_Secure:USE` | none |
| Forged member | A turn request whose context carries `verdict` or `unavailable` | 422 `TURN.CONTEXT.INVALID` | nothing reserved |
| Card | Step `{failedPair: %Admin_Secure:USE, failedScreen: webapp.list}`; an unknown id | "failed — You need %Admin_Secure:USE to open Web applications."; "failed — %Admin_Secure:USE" | none |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Screen/Tool/ScreenAccessAction.cls`: `ADVERTISED` :23. `StateDiff` :92-113 already builds the `Pairs` row. `READANSWERS` includes `Result`.
- `Screen/Tool/ScreenAccessReset.cls`: `PortQuery` :35-39 is the payload branch (DW-2181); `ReadBackGone` :42-46.
- `Port/ScreenAccessPort.cls`:
  - `Row()` :374-383 answers `{Screen, Pairs, Adjusted, Pair, Result}`; for a reset, `Result` is the declared set (:317).
  - `Apply` :161-204 compares pairs.
  - `Audit` :387-399 records `SecurityChange` for both callers.
- `Kernel/Proposal/Mint.cls`:
  - :326 `GrantsPrivilegeByEffect` and :335-342 `WeakensByEffect` receive the full composed fresh read, `Result` included.
  - :343-344: `consequence`, and `destructive` = tool OR privileged OR effect.
  - `RecordedPairs` :470-506 resolves only advertised tools, so advertising fixes the "requires" line.
- `Kernel/Proposal/Prohibited.cls`: `WeakensByEffect` :1789, whose last arm is :1830; `TYPESCREENPERMISSION` :570; the effect parameters near `EFFECTSYSTEMGLOBAL` :763.
- `Kernel/Agent/Dispatch.cls`:
  - `Answer` :131-157 builds the tool result and `pDetails`.
  - `AnswerOne` :179; the `RequiredPairs` leg is :260-271 and the argument leg :282-296.
  - `MissingPair` :700-719 (Private; uses `HoldsPair`/`CheckUserPermission`, which `ToolDispatchProbe` seams).
  - `DeniedContent`.
- `Kernel/Denial.cls`: `Detail`, `Content`, `Envelope`, each taking only `pFailedPair` today.
- `Screen/Tool/Registry.cls`: `ListTools` :106, `ResolveWire` :221, `IsAdvertised` :239, `RequiredPairs` :423. Every `PrivilegePairs` override calls `Gate.RequiredPairs` or `##super`, except `Base` (`""`), `Navigate` (`""`) and `ScreenAccessAction` (the either-of) (read in source).
- `Screen/Context.cls`: `ScreenTools` :176 and `BoundTo` :246-254, the descriptor idiom to reuse.
- `Api/Turn.cls`: `BoundedContext` :530-570 (members :540-541) and `ContextViolation` :469-475.
- `Kernel/Shell/Navigation.cls`: `SetVerdict` :70.
- `Screen/Gate.cls`: `Evaluate` :103, `RequiredPairs` :237, `EvaluatePairs` :403.
- `Api/ScreenRead.cls`: :58-62 refuses through `Denial.Envelope(tFailedPair)` with `tDescriptor` in hand.
- `Kernel/State/Step.cls`: `FailedPair` :62, `GuardedAppend` :76, `GuardedFinishTool` :166 and the view :228. Adding a property moves no `SCHEMAVERSION` (:38 precedent).
- `Kernel/Agent/Loop.cls`: :622 passes the step details to `GuardedFinishTool`.
- `Kernel/Agent/Prompt.cls`: `BUILTIN` :19, and its sentence-count doc :8-18.

Client:

- `ui/src/app/core/turn.ts` :540-550 (the step parse).
- `ui/src/app/shell/tool-call-card.ts` `statusText` :108-117.
- `ui/src/app/core/navigation.ts`: `formatDeniedScreen` :685; `screenForToolName` :531 is the `SCREENS` lookup idiom.
- `ui/src/app/core/strings.ts`: `stringFor` :6286, `screenPermissionsLowerConsequence` :6249.
- `ui/src/app/core/proposal-view.ts`: the `CONSEQUENCE_*` constants :146-207 and `consequenceSentence` :387.

Test templates:

| Need | Template |
|---|---|
| Agent mint and confirm in process | `Test/SqlAgentWrite.cls` `Dispatch()` :109-127, `ConfirmIn()` :148-152, :258-296 |
| `SecurityChange` rows | `Test/ScreenAccessWire.cls` :371-409 |
| Real-principal turn | `Test/DeveloperFloorTurn.cls` (`TurnProvider.Script`, `AwaitEnd`); `Propose.GuardedCountForTurn` (`Kernel/State/Propose.cls` :719) |
| Context over the wire | `Test/TurnGrounding.cls` :144 |
| Destructive card in a browser | `ui/browser/auditing-write.browser-spec.mjs` :196-236 |
| "Requires" line in a browser | `ui/browser/proposal-privilege.browser-spec.mjs` :231-262 |
| Turnprobe helpers | `ui/browser/turnprobe-spec.mjs` |

Tests whose pins move:

- `Test/ScreenAccessDescriptor.cls`: :134 (`Advertised` 0), and :147-177, whose absence assertions flip.
- `Test/ScreenGrounding.cls`: `Statement` :20-33; :47-62; `TestTheMembersCountWithinTheTotalBound` :233; `TestBothMembersRideBothBranches` :193; `TestARequestSupplyingADerivedMemberIsRefused` :135.
- `Test/ToolWire.cls` :196: `permissions.users.read` is refused on a closed screen, so the detail gains `screen`.
- `Test/DenialParity.cls` :231-248.

These adjust themselves; re-run them only: `ToolEmit`, `ToolSetFull`, `Guardrails`, `TurnTools`, `GeminiEmptyEnum`, `DeveloperFloorTurn`, `InteropFloorTurn`, `TurnGrounding`, `TurnContext`, `ContextBound`, `ToolDispatch`.

## Tasks & Acceptance

**Execution** (in dependency order):

- `src/OcuPilot/Kernel/Denial.cls`: `Detail`, `Content` and `Envelope` take an optional `pScreen` and add `screen` after `failedPair` when it is non-empty.
- `src/OcuPilot/Screen/Tool/Registry.cls`: add `ScreenRequirement(pTool, Output pScreen, Output pResolved) As %List`.
  - It resolves the descriptor through the entry's `descriptor`, else its class's `DESCRIPTORCLASS`. It answers `Gate.RequiredPairs(descriptor)` and puts the descriptor's `ToolIdentifier()` in `pScreen`.
  - It answers `""` and `pScreen` `""` for a tool with no screen.
  - It is add-only.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls`: in the `RequiredPairs` leg's refusal, call `ScreenRequirement` through `RegistryClass()`.
  - When it resolves and `MissingPair` over its pairs is non-empty, answer `DeniedContent(<that pair>, <screen>)` and set `pFailedPair` and a new output `pFailedScreen`.
  - Thread `failedScreen` into `pDetails`, and correct the docs.
- `src/OcuPilot/Kernel/State/Step.cls`: add `Property FailedScreen As %String(MAXLEN = 128)`, a trailing optional `pFailedScreen` on `GuardedAppend` and `GuardedFinishTool`, and `failedScreen` in the view.
- `src/OcuPilot/Kernel/Agent/Loop.cls` :622: pass `tDetail.failedScreen`.
- `src/OcuPilot/Api/ScreenRead.cls` :62: `Denial.Envelope(tFailedPair, $ClassMethod(tDescriptor, "ToolIdentifier"))`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Add `Parameter EFFECTSCREENLOWERED = "SCREENACCESS.LOWERED"` beside `EFFECTSYSTEMGLOBAL`.
  - Add a first arm in `WeakensByEffect`: for `TYPESCREENPERMISSION`, set the effect when `pTarget.Result` lacks a member of `pTarget.Pairs`, compared upper-cased.
  - Add one doc line. All add-only.
- `src/OcuPilot/Screen/Tool/ScreenAccessAction.cls`: `ADVERTISED` 1, and correct the header and doc lines that say "until Story 20.18".
- `src/OcuPilot/Screen/Context.cls`: add `Unavailable(pTools As %DynamicArray, Output pUnavailable As %DynamicObject) As %Status`. For each wire name it runs `ResolveWire`, then `RequiredPairs`, then `Gate.EvaluatePairs` in the calling process.
- `src/OcuPilot/Api/Turn.cls`:
  - `BoundedContext`: after `readOnly`, set `verdict` (`Navigation.SetVerdict` on a new object) and `unavailable`.
  - `ContextViolation` :475: refuse `verdict` and `unavailable` as it refuses the other two.
  - Correct the docs ("two members" becomes four).
- `src/OcuPilot/Kernel/Agent/Prompt.cls` :19:
  - Statement 1 ends "..., whether you are read-only (readOnly), whether the user can open that screen and, if not, the permission they lack (verdict), and which of its tools the user cannot use, with the permission each lacks (unavailable)."
  - Append: "When a tool answers AUTH.NOPRIVILEGE, it names the permission the user lacks (failedPair) and, when the user cannot open that tool's screen, the screen (screen): say that the user cannot access that screen and which permission they would need, propose nothing on it, and do not call it again. Do not call a tool that unavailable names; say which permission it needs instead."
  - Update the doc's sentence count.
- **Client:**
  - `ui/src/app/core/turn.ts`: add an optional `failedScreen` to the step, parsed with `textAt`.
  - `ui/src/app/shell/tool-call-card.ts`: when `failedScreen` names a `SCREENS` entry, use `formatDeniedScreen(STRINGS.privilegeDeniedScreen, failedPair, stringFor(labelKey))` as the reason.
  - `ui/src/app/core/proposal-view.ts`: add `CONSEQUENCE_SCREENACCESSLOWERED` mapping to `STRINGS.screenPermissionsLowerConsequence`.
- **Docs:**
  - EXPERIENCE.md :631, the tool-call-card row: insert `· "failed — You need <resource> to open <screen>." when the tool's screen is one the user cannot open (Story 20.18)` after "failed — <reason>". Then run `cd ui && npm run test:tools`.
- `scripts/ci-throwaway.sh`: add a new `# classes: ScreenAccessTurn` line after :318 (PRINCIPALS) and after :521 (TEST_PROVIDER).
- **Tests (new),** each at most about 500 lines, none with a `Test*` property:
  - `Test/ScreenAccessAgent.cls`, in process (DW-2181): the Raise, Lower, Reset and Confirm rows through `Dispatch.Answer` and `Confirm.Confirm`. It asserts the stored diff, `destructive`, `consequence` and `requiredPairs`, the read-back, the `SecurityChange` row and the agent marker. `OnAfterOneTest` resets adjustments and drops the seeded proposals.
  - `Test/ScreenRefusal.cls`, in process:
    - the Screen open and Demo operator rows through `ToolDispatchProbe`;
    - the roster: every registered write tool resolves a screen through `ScreenRequirement`, and its `RequiredPairs` contains each of that screen's pairs.
  - `Test/ScreenAccessTurn.cls`, over the wire as P: the Screen closed and Context rows. Arm it like `DeveloperFloorTurn` (both variables, and the `OnBeforeAllTests` refusal).
  - `ui/browser/screen-permissions-agent.browser-spec.mjs`, signed in as the configured user:
    - a remove-pair card is destructive with no `.ocu-typed-name-field`, shows the `Pairs` row, the "requires" line and the consequence sentence, and Confirm writes the store;
    - an add-pair card is not destructive.
    - It resets `osmgmt.locks` first and in `after`, and never asserts the store empty.
- **Tests (edited):** as listed in the Code Map. Add `ui/tools/proposal-view.test.mjs` (the new code) and `ui/src/app/shell/tool-call-card.spec.ts` (the Card row).

**Acceptance Criteria:**

- **AC1 (advertised, the treatment).**
  - **Given** the three tools,
  - **when** the provider list, the dispatch lookup and Screen permissions' context `tools` are built,
  - **then** each appears.
  - An agent remove-pair, and a reset that drops a pair, mint `destructive` with consequence `SCREENACCESS.LOWERED`, and an add-pair mints neither. In a browser the lowering card shows the destructive bar and Confirm, no typed-name field, the `Pairs` row and the "requires" line.
- **AC2 (DW-2181, propose and confirm end to end).**
  - **Given** an agent proposal from each tool,
  - **when** it is confirmed,
  - **then** the store holds the new set (none after a reset), the read-back reads as the matrix says, and the audit database holds one `SecurityChange` row with the pairs before and after plus the agent marker.
- **AC3 (dispatch names the screen).**
  - **Given** a tool whose screen's effective pairs, an adjustment included, the caller lacks,
  - **when** it is dispatched,
  - **then** it is refused before any mint with `detail.screen` and that screen's failed pair. A tool whose screen is open is refused with `{failedPair}` alone. The screen read route's refusal names the same screen.
- **AC4 (every tool).**
  - **Given** every registered write tool,
  - **when** the roster test runs,
  - **then** each resolves a screen and requires all of its pairs.
- **AC5 (prompt).**
  - **Given** the built-in prompt,
  - **when** it is read,
  - **then** it carries the extended Statement 1 and the AUTH.NOPRIVILEGE sentence verbatim.
- **AC6 (card).**
  - **Given** a refused step naming a screen,
  - **when** its card renders,
  - **then** it reads "failed — You need <pair> to open <screen title>.".
- **AC7 (screen context).**
  - **Given** a turn carrying a screen context,
  - **when** it is built,
  - **then** it carries `verdict` and `unavailable` as the Context row says, and a request supplying either is refused.
- **AC8 (Integration: a real turn).**
  - **Given** P and Raised Locks,
  - **when** a turn asks the agent to remove a lock,
  - **then** the remove is refused naming `osmgmt.locks` and `%Admin_Secure:USE`, no proposal row exists for the turn, and the turn completes.

### Review Findings

Code review, 2026-10-08 (baseline 1785544e, implement aac4080b): 0 high, 4 medium and 17 low after triage. 14 are patched and verified on `ocupilot-b-ci`, 7 lows are closed in the ledger, 1 unverified medium is escalated, and 9 are rejected.

- [x] [Review][Patch] (medium) `Context.Unavailable` rebuilt the whole tool registry for every tool. `ListTools` measured 494 ms and `Unavailable` on Locks 1,951 ms, so a 12-tool screen would add about 6 s before the turn's 202 (NFR-1). It now reads the list `ScreenTools` already built, and `BoundedContext` on Locks measured 508 ms [src/OcuPilot/Screen/Context.cls:262]
- [x] [Review][Patch] (medium) Rules 3 and 30: `refused-tool.browser-spec.mjs` still expected "failed — %Admin_Secure:USE" for a refusal that now names `webapp.restapis`, which would have reddened CI. It now expects the screen sentence, which also gives AC6 a real-browser leg [ui/browser/refused-tool.browser-spec.mjs:181]
- [x] [Review][Patch] (medium) Rules 19 and 30: ScreenAccessTurn's Context test passed with no assertion when no `screen_context` arrived, and relied on switches and sharing it did not set. It now asserts the context pair arrived and resets both [src/OcuPilot/Test/ScreenAccessTurn.cls:134]
- [x] [Review][Patch] (medium) Rule 30: ScreenAccessAgent asserted that no reset proposal existed anywhere on the instance. It now asserts that none was added [src/OcuPilot/Test/ScreenAccessAgent.cls:199]
- [x] [Review][Patch] (low) `TestBothMembersRideBothBranches` asserts `verdict` and `unavailable` on the identity-only branch [src/OcuPilot/Test/ScreenGrounding.cls:231]
- [x] [Review][Patch] (low) `Unavailable`'s fail-closed answer is pinned: an unknown name, and every name when the list cannot be built, maps to `""` [src/OcuPilot/Test/ScreenGrounding.cls:138]
- [x] [Review][Patch] (low) Case folding in `LowersScreenPermission` is pinned: a reset of the declared set spelled in another case is not a lowering [src/OcuPilot/Test/ScreenAccessAgent.cls:237]
- [x] [Review][Patch] (low) The lowering reset's confirm asserts its read-back and audit rows, and the raise asserts AD-14's `action` [src/OcuPilot/Test/ScreenAccessAgent.cls:223]
- [x] [Review][Patch] (low) ScreenAccessAgent's `Dispatch` sets its outputs before an early error, and the unused `Effective()` is removed [src/OcuPilot/Test/ScreenAccessAgent.cls:70]
- [x] [Review][Patch] (low) `strings.test.mjs` holds the sixth tool-call status to the composition the card renders [ui/tools/strings.test.mjs:368]
- [x] [Review][Patch] (low) `proposal-view.test.mjs` reads `EFFECTSCREENLOWERED` from `Prohibited.cls` rather than restating it [ui/tools/proposal-view.test.mjs:314]
- [x] [Review][Patch] (low) Stale docs are corrected: `LowersScreenPermission` and `WeakensByEffect`, `Loop.DispatchTools`' detail shape, ScreenAccessTurn's header, ScreenRefusal's roster mutation note, and the `ci-throwaway.sh` comment for ScreenAccessTurn.
- [x] [Review][Patch] (low) AD-8 said "a write tool's screen", but read tools name it too (ToolWire, DenialParity). AD-24 said "declared pairs" where `unavailable` uses the required pairs, an adjustment included. Both are corrected at origin (memlog; lint_spine reports nothing new) [ARCHITECTURE-SPINE.md:226]
- [x] [Review][Patch] (low) Rule 19: AC1's add-pair mutation was named but never run. It has now been run and is recorded under Verification.
- [x] [Review][Closed] Seven lows are closed with terminal ledger entries DW-2207 to DW-2213:
  - `by-design`: the prompt sentence read on an open screen (AC5's text); form Save and Rules routes (Q2); the navigation refusal (Boundaries); and the process-role basis of `verdict` and `unavailable`;
  - `wontfix-accepted`: AC8's no-proposal sub-assertion, and `unavailable`'s per-tool leg;
  - `wontfix-theoretical`: unarmed adjustment resets.
- [x] [Review][Defer] Web turns stopped offering the three tools after a mutation reload, as QA observed. Deferred: maybe-false, because two reload cycles in this review did not reproduce it. Escalated as DW-2214.

Orchestrator questions:

- **Lowering.** It is decided at the mint, from the port's composed read. The confirm does not re-classify, and it does not need to: the fingerprint covers `Pair,Pairs,Adjusted` (`Pairs,Adjusted` for a reset), so a confirm against a changed store is refused as stale.
- **Screen named.** Naming the screen discloses nothing new. The mirror lists every screen id, the navigation map shows a closed screen with its failed pair, and an unadvertised tool never resolves.
- **Prompt.** The addition is one sentence, appended once, and the prompt stays one ASCII constant. That is honest to the ruling.

Rejected:

- `false`: EXPERIENCE.md :631's `<pair>` is deliberate, because `citations.test.mjs` needs the Fixed sentence to occur once. The new pin renames the slot.
- `false`: the AC4 roster need not cover read tools, because a read tool's pairs are its screen's by construction.
- `low`: `PairsRow`'s fallback to the last row still fails its assertion.
- `low`: `ADVERTISED = 1` restating the default, and the second `SCREENS.find`, cause no named harm.
- `low`: browser cleanup outside `finally` is the sibling specs' shape, and a timeout fails the test anyway.
- `low`: the duplicate Review Triage Log heading would need a spec edit.
- `low`: DW-2181 is closed by the lead's adjudication gate.
- `low`: AD-24's "two members" is followed by the 20.18 sentence naming both new members.
- `low`: separate mutation lines for the halves of AC3 and AC7 are not needed, because Rule 19 asks for one per AC.

## Spec Change Log

- 2026-10-08, runner spec gate: the orchestrator ruled Q1 A without the README edit (the `operator` account belongs to the demo deployment) and Q2 A, and cleared EXPERIENCE.md :631 and `Kernel/Agent/Prompt.cls` :19 on union terms; keep the prompt addition to one sentence. Rule 30 applies: the shared surfaces and the standing criterion are under `## Verification`. DW-2202 (existing literal counts) is 23.5's, not this story's.

## Review Triage Log

## Design Notes

**Governing ADs.**

- AD-64: rule 4's agent lowering and the advertising.
- AD-10: the privilege-grant precedent, and `WeakensByEffect` as the effect home.
- AD-8: the refusal by the failed pair, the "requires" line, the either-of, and tool/screen 403 identity.
- AD-11 rule 1: the members are instance-derived and untrusted content; the prompt is a constant.
- AD-22: the keys stay enabled.
- AD-24: context members.
- AD-31: dispatch's live grant check.
- AD-40 and AD-53: advertising.
- AD-6, AD-15, AD-34, AD-51 and AD-58: the end-to-end write.

**Decision 1: lowering.** "Lowering" is any change after which the stored set no longer contains a pair it held. It is computed on the instance at the mint, from the port's own `Pairs` and `Result`, and never from the request or the client. This is the effective-set reading (option C). It subsumes option A, every remove-pair, and is the only reading that classifies a reset correctly: resetting a raise lets more accounts in, while resetting a lowering does not. The classic resource and a tool's extra pairs never move (AD-64 rule 2), so the base set decides. The home is `WeakensByEffect`, beside AD-10's other "permitted at the strongest confirmation" effects, so the card's consequence line comes free and the static `DESTRUCTIVE` stays 0, as `ScreenAccessDescriptor` :132 pins.

**Decision 2: the tool's descriptor, not the route.**

- The descriptor reaches every write tool: all 187 resolve a `DESCRIPTORCLASS` (source count), and AC4's roster makes that a checked claim.
- It names the screen the tool acts on. The route names only the screen the user is viewing, which differs when the agent acts elsewhere, and is absent when sharing is off.
- The four tools with no screen (`shell.screen.open` and three shell reads) keep `{failedPair}`.

**Proposed AD amendments (one line each, for the runner at the spec gate).**

- **AD-8:** "A privilege refusal also names the screen (`detail.screen`, its `toolIdentifier`) when the caller cannot open it, the failed pair then being that screen's; a tool's and the screen read route's refusals carry it alike (Story 20.18)."
- **AD-10, the 20.15 bullet:** "An agent proposal that lowers a screen's requirement is minted destructive with effect `SCREENACCESS.LOWERED` (Story 20.18, AD-64)."
- **AD-24:** "Story 20.18 adds `verdict`, the screen's own `{allowed, failedPair?}` as navigation answers it, and `unavailable`, each wire name in `tools` whose declared pairs the caller lacks mapped to its first failed pair; both are derived in the caller's process, refused in a request, and counted within the total bound. Argument pairs are left to dispatch."
- **AD-53:** replace "Screen permissions' three tools (Story 20.15) stay unadvertised until Story 20.18 advertises them (AD-64)" with "Story 20.18 advertised Screen permissions' three tools (AD-64)".
- **AD-64 rule 4:** replace "The tools stay unadvertised until Story 20.18 (AD-53)" with "Story 20.18 advertises them (AD-53); a proposal whose resulting set lacks a pair of the stored set (every remove-pair, and a reset of an adjustment holding a pair the declared set lacks) is a lowering."
- **Deferred, the Story 20.15 row:** the agent half is done in Story 20.18.

**Questions for the orchestrator.** The plan builds each recommended option; neither halts.

| # | Question | Options | Recommended (planned) |
|---|---|---|---|
| Q1 | README step 5's `operator` account belongs to the hosted demo deployment, not to this repository. | **A** Pin the mechanism with an in-process principal lacking `%Admin_Secure:USE` on `webapp.list.update` (the Demo operator row); README.md stays as it is (ruled A without the README edit, orchestrator 2026-10-08). **B** Also add the account to the opt-in demo fixture (AD-25) so the smoke script pins it. | A |
| Q2 | Should the screen action route's 403 and the confirm's refusal also name the screen? | **A** No: the person is already on that screen, and the card's privilege line names the pair; `Api/ScreenAction.cls` is in Epic 18's diff. **B** Yes, in this story. | A |

**Integration ACs (Rules 1 and 2).**

- **Consumes:** Story 20.15's `Kernel/State/Access`, `Screen.Gate.RequiredPairs`, `Port/ScreenAccessPort` and the three tools. AC8 exercises them against a real instance.
- **Consumed-by:**
  - Story 20.17: its saves and creates are refused naming the screen, and it relies on dispatch's refusal.
  - Story 20.12: guided workflows can read `verdict` before proposing (inference).

**Rule 11 (checked 2026-10-08 against `epic-18` `origin/feature...HEAD` and its status).**

| File | Edit | Status |
|---|---|---|
| `Kernel/Agent/Prompt.cls` :19 | Statement 1 extended; one sentence appended | CONTENDED non-add-only: 18.12's known prompt overlap; not yet in Epic 18's diff |
| EXPERIENCE.md :631 | one form inserted in the tool-call-card cell | CONTENDED non-add-only |
| `Kernel/Proposal/Prohibited.cls` | a parameter, a first arm in `WeakensByEffect`, a doc line | add-only; Epic 18's hunks are at :652, :893, :939, :1289, :2406 |
| `scripts/ci-throwaway.sh` | two new `# classes:` lines | add-only |

**Ledger.** DW-2181 is addressed by AC2 (`Test/ScreenAccessAgent.cls`).

## Verification

**Shared surfaces (Rule 30):** screen context's members (`verdict`, `unavailable`); a privilege refusal's `detail` (`screen`) on the tools and the screen read route; the advertised tool set (three more tools); the built-in prompt's text; the proposal effect vocabulary (`SCREENACCESS.LOWERED`); EXPERIENCE.md's tool-call-card row.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):**

- Before each load, sync: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Load in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`, checking both the status and `tErrors`.
- Run one class or spec file per call, and never re-submit after a client-side timeout.
- Before a browser run:
  - run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`;
  - set `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>`: expected clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call. Expected: 0 failed, read from `%UnitTest_Result`. The classes:
  - the new ones: `ScreenAccessAgent`, `ScreenRefusal`, `ScreenAccessTurn`;
  - the edited ones: `ScreenAccessDescriptor`, `ScreenGrounding`, `ToolWire`, `DenialParity`;
  - the re-run list in the Code Map, plus `ScreenAccessGate`, `ScreenAccessWire`, `Governance`, `State`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/screen-permissions-agent.browser-spec.mjs browser/screen-permissions.browser-spec.mjs`: expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `bash scripts/lint-docs.sh`: expected clean.
- `(once, before dev_complete)` the full ObjectScript sweep, one class at a time; then `cd ui && npm test && npm run build`, with the bundle under 3165 kB; then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ADVERTISED` 0; separately, the `WeakensByEffect` screen arm removed | `ScreenAccessDescriptor` rosters; `ScreenAccessAgent` Lower and the browser spec's destructive leg |
| AC2 | `ScreenAccessReset.PortQuery` ignores the payload | `ScreenAccessAgent` reset confirm leg (inference: the read-back or the re-read reddens) |
| AC3 | `ScreenRequirement` answers `""` | `ScreenRefusal` Demo operator; `ToolWire` :196 |
| AC4 | one write tool's `DESCRIPTORCLASS` emptied | `ScreenRefusal` roster |
| AC5 | the AUTH.NOPRIVILEGE sentence removed | `ScreenGrounding` statement pin |
| AC6 | `statusText` ignores `failedScreen` | `tool-call-card.spec.ts` |
| AC7 | `Unavailable` answers `{}` | `ScreenAccessTurn` Context leg |
| AC8 | `Gate.RequiredPairs` ignores the store | `ScreenAccessTurn` Screen closed leg |

mutation: AC1 ADVERTISED=0 red in ScreenAccessDescriptor and ScreenAccessAgent; WeakensByEffect arm removed red in ScreenAccessAgent and the browser spec destructive leg.
mutation: AC2 reset PortQuery ignoring its payload red in the ScreenAccessAgent reset read-back leg.
mutation: AC3 ScreenRequirement unresolved red in ScreenRefusal, ToolWire, DenialParity.
mutation: AC4 a write tool's pair dropped from LockRemove.PrivilegePairs red in the ScreenRefusal roster (emptying DESCRIPTORCLASS is caught earlier by the registry guard).
mutation: AC5 prompt sentence changed red in ScreenGrounding.
mutation: AC6 statusText ignoring failedScreen red in tool-call-card.spec.ts; parseStep dropping failedScreen red in ui/tools/turn.test.mjs.
mutation: AC7 Unavailable answering {} red in ScreenAccessTurn Context leg.
mutation: AC8 Gate.RequiredPairs ignoring the store red in ScreenAccessTurn Screen closed leg.
mutation: AC1 add-pair (code review): LowersScreenPermission answering 1 red in the browser spec's add-pair leg ("the card is not destructive", actual true) and in ScreenAccessAgent's raise, lowering-reset and case legs; reverted byte-identical, all green again.
mutation: AC6 in a browser (code review): ScreenRequirement answering "" red in refused-tool.browser-spec.mjs (actual "failed — %Admin_Secure:USE"); reverted byte-identical, green again.

## Review Triage Log

### 2026-10-08 - Review pass

- verdicts: 9 findings - high 0, medium 2, low 4, false 0, maybe-false 0 (3 descriptive audit notes)
- findings:
  - `[medium]` `patch` parseStep's failedScreen untested - added the key to the Failed tool restore test in ui/tools/turn.test.mjs; dropping the read reddens it.
  - `[medium]` `patch` no mutation lines recorded - recorded above from the implementer's observed runs.
  - `[low]` `reject` RecordedContext silent skip on a wrong message shape - the turn-completes assertion and the Screen closed leg fail first.
  - `[low]` `reject` ci-timings.json lacks the new classes - ui/tools/ci.test.mjs passed in npm test.
  - `[low]` `reject` LowersScreenPermission case folding has no varying-case assertion - the AC1 mutations redden the arm itself; fix adds a test with no named harm.
  - `[low]` `reject` before-leg of the Context test depends on the principal's grants - setup assertions name them.
  - audit: reading A+D implemented as specified; unavailable vs verdict are two computations by the spec's design; no model-behavior test by design (stub provider).

## Auto Run Result

Status: done
Blocking condition: none

Advertised the three Screen permissions write tools; a lowering mints destructive via SCREENACCESS.LOWERED; dispatch and the screen read route name the screen on a closed-screen refusal; step, card, screen context (verdict, unavailable) and the prompt carry it; new tests ScreenAccessAgent, ScreenRefusal, ScreenAccessTurn and a browser spec.
Review: 2 patched (medium), 4 rejected low, 0 deferred. followup_review_recommended false.
Verification: full ObjectScript sweep 4112 tests, 3 reds re-run alone (TurnWire fixed, Retention green alone, WireSecurityRead task-history 1,520 rows is DW-2182 leftover on the throwaway); npm test green, bundle 3.12 MB, smoke 50/50, check-objectscript clean, lint-docs clean, turn.test.mjs 83/83.
Residual risk: the prompt addition joins the spec's two sentences with a semicolon per the one-sentence ruling.
