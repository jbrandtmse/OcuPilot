---
title: 'Story 14.2: The tool governance policy'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: '0c1ea07b7bd6882b9be85d20659fe17b397b45b1'
baseline_commit: '0c1ea07b7bd6882b9be85d20659fe17b397b45b1'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Policy.Resolve's fail-closed return on an unreadable policy store has no test at the resolver itself.
    evidence: |-
      The Confirm and dispatch legs drive a failing gate through seams; nothing makes State.Policy.GuardedAll fail, so
      a Resolve that fell through to the baseline on a read error would stay green. Settling it needs a store seam.
    location: >-
      src/OcuPilot/Kernel/Governance/Policy.cls Resolve
    severity: medium
---

<intent-contract>

## Intent

**Problem:** `Kernel/Governance/Gate.cls` `Decide` allows every registered tool, so an administrator can only switch the whole agent off or make it read-only. They cannot disable one write. `security.auditing.purge` stays unadvertised because nothing can default it to disabled (AD-53).

**Approach:**

- A checked-in baseline lists every registered write key: enabled, except the purge.
- A stored policy adds a preset and per-key settings on top of the baseline.
- `Decide` resolves the key at dispatch. Confirm asks it again at the write (AD-40).
- A denial is the tool result `{"code":"GOVERNANCE.DISABLED"}`, and the tool stays advertised.
- An administrator views and edits the policy on a new Agent co-pilot screen, Governance policy. Every change is audited.
- The purge becomes advertised, disabled by default, and its card states the consequence.

## Boundaries & Constraints

**Always:**

- **Key.** A key is the tool's canonical name. For a tool declaring `Parameter GOVERNANCEACTION` (the name of an argument with an `enum`), the key is `tool:<value>`. No shipped tool declares one; a test fixture proves the form.
- **Baseline.**
  - `Kernel/Governance/Baseline.cls` holds XData JSON, one line per key: `"<key>": true|false`.
  - It carries today's 76 registered write keys, in name order, measured through `Registry.ListTools` on `ocupilot-b-ci` (2026-09-27) and cross-checked against `Screen/Tool/*.cls`.
  - Every key is `true` except `"security.auditing.purge": false`, which Story 12.3's AC and the routed bullet require.
  - The list is never regenerated.
- **Cascade**, per key, with the first non-null layer winning:
  1. the stored setting;
  2. the preset seed: `read-only` makes a write false, `full` makes it true;
  3. the baseline seed: the listed value, and false for a write key that is not listed.
  - A `false` is a value and is never skipped.
  - A read tool is always allowed.
  - A call whose kind is neither `read` nor `write` is denied under every layer, so it fails safe.
- **Storage (AD-9).**
  - New `Kernel/State/Policy.cls` extends `State.Base`, with one row per `Name` (unique) and a `Value`.
  - The `preset` row holds `""`, `read-only` or `full`. It is also the policy's version anchor: every accepted PUT saves it conditionally on the `rowVersion` the page read (`STATE.CONFLICT` on a mismatch), in the same transaction as the key rows.
  - Resolution reads the store on every call and never caches.
  - `SCHEMAVERSION` does not move: this is a new table, and older rows keep their meaning.
- **Where `Decide` is called.**
  - Unchanged: `Dispatch.AnswerOne` :227-239 and `ResolveClientCall` :478-491, after identity and before restraint, pairs and ports.
  - New: `Confirm.Transition`, between the `Operation.Gate` refusal (:256-268) and the restraint verdict (:270). It passes the stored `toolName`, kind `write` and the stored arguments, before the claim commits and the port is called.
  - Not called on a person's own action or Save (AD-53, AD-55) or on the draft (AD-59).
- **Refusal precedence.**
  - Dispatch: governance, then restraint, then pairs.
  - Confirm: pairs, then prohibited, then governance, then restraint.
  - A governance denial is its own code and never touches the restraint verdict, the footer or the context `readOnly` (AD-30, Story 14.5).
- **Confirm after a disable.** The response is 403 `GOVERNANCE.DISABLED` and the row stays live. The card keeps its buttons and shows the reason. The draft is still offered and still closes the row `canceled`/`draft`, because it runs no write.
- **Routes (AD-12, AD-39).** Both require `OcuPilotAdmin:USE` (`Definitions.IsAdministrator`, `RenderForbidden`).
  - `GET /agent/governance` answers `{preset, rowVersion, keys:[{key, baseline:"enabled"|"disabled"|"absent", setting:"inherit"|"enabled"|"disabled", enabled, source:"setting"|"preset"|"baseline"}]}`, one entry per registered write key, in name order.
  - `PUT /agent/governance` accepts exactly `{preset, settings:{<key>: setting}, rowVersion}`. A key missing from `settings` is left unchanged.
  - A key that no registered write tool yields is refused 422 `GOVERNANCE.KEY`; the ledger, the marker and a read tool are not keys.
  - Any other shape is refused 422 `GOVERNANCE.BODY`, with `violations` of `{field, code, reason}`.
  - An accepted PUT writes `Audit.Event.Record("governance", "agent-policy", "instance", changes, 1)`, carrying the old and new value of the preset and of each changed key (FR-29, Story 3.8).
- **Purge.**
  - Delete `AuditPurge`'s `ADVERTISED = 0`, so it is advertised.
  - Add `Consequence` answering `AUDIT.PURGEMARKERS`. The card shows its sentence.
  - The write path, marker and ledger are unchanged.
- **Strings.** EXPERIENCE.md rows are edited in place, keeping the line count, and `strings.ts` is add-only after :640.

**Never:**

- No edit to `Dispatch.cls`, `Loop.cls`, `Restraint.cls` or `Kernel/Proposal/Prohibited.cls`.
- No key can reach the prohibited set (AD-10).
- No environment-variable layer (Conventions › Config).
- No policy cache.
- No production baseline key for a test fixture: a probe that dispatches a fixture write tool answers its own gate seam.
- Stay off Epic 16's hunks:
  - `Confirm.cls` :114-117 and :426+; `proposal-view.ts` :21, :120 and :448;
  - `Router.cls` :116, :122, :142 and :654+; `Error.cls` :371;
  - `SurfaceCoverage` :59 and :70; `EndpointCoverage` :105, :112 and :132;
  - `screen-outlet.ts` :15-16 and :110;
  - `strings.ts` :1819, :1957 and :2857+;
  - EXPERIENCE.md :83, :85, :152, :169, :226, :479, :573+, :615, :661 and :833.

## I/O & Edge-Case Matrix

| Scenario | State / Input | Expected | Error |
|---|---|---|---|
| Default | no rows | every write key allowed except the purge, whose source is `baseline` | none |
| Setting false over full | preset `full`, `webapp.list.update`=disabled | denied, source `setting` | none |
| Read-only preset | preset `read-only` | writes denied (source `preset`); reads allowed; kind `""` denied | none |
| Setting true over read-only | `security.auditing.purge`=enabled, preset `read-only` | allowed, source `setting` | none |
| Denied call | model calls a disabled key | `is_error`, content `{"code":"GOVERNANCE.DISABLED"}`; no proposal; ledger row with that code; still in `ProviderTools`, `ResolveWire` and context `tools` | none |
| Disabled after mint | live proposal, key then disabled | Confirm 403 `GOVERNANCE.DISABLED`, row live; draft 200 `canceled`/`draft` | card refusal slot |
| Bad PUT | unknown member, bad preset or setting, `agent.ledger`, a read key | 422 with violations; nothing written | `GOVERNANCE.BODY` / `GOVERNANCE.KEY` |
| Stale PUT | `rowVersion` moved | 409 `STATE.CONFLICT`; nothing written | stale-save sentence |
| Non-admin | `%Admin_Operate` only | 403 `AUTH.NOPRIVILEGE`, pair `OcuPilotAdmin:USE` | none |
| Store unreadable | resolver status error | dispatch: `TOOL.UNAVAILABLE`, logged; confirm: 500 internal; nothing written | fail closed |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Governance/Gate.cls` -- `Decide` :19-25; the header already names this story.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- read-only evidence: the gate calls are at :227-239 and :478-491, and `RecordLedger` :353 records every refusal.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- `Transition` :221; gates at :256-285; seams :37-110. Refusals use `Refuse(403, code)`, and `Api/Confirm.ReasonFor` :146 falls back to `Error.ReasonForToolCode`.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- `ListTools` :106, `Resolve` :195 (the default skips unadvertised tools), `ProviderTools` :256. Read only.
- `src/OcuPilot/Screen/Tool/AuditPurge.cls` :5-8 and :27-28 -- the unadvertised declaration. `OAuthAuthorizationServerRotateKeys.Consequence` :110 is the pattern; `Mint.ConsequenceOf` :713 calls it.
- `src/OcuPilot/Api/Switches.cls` -- `LogChange` :579, `RecordAudit` :649, `RenderConflict` :550. `HandleUpdate` :119 is the admin PUT pattern.
- `src/OcuPilot/Kernel/State/Base.cls` -- `GuardedSaveIfCurrent` :193, `IsStaleSave` :251. `State/Switch.cls` is a guarded store to copy.
- `src/OcuPilot/Api/Error.cls` -- `TOOLDENIED` :768, `ToolCodes` :1030, `ReasonForTool` :1036.
- `src/OcuPilot/Kernel/EntityType.cls` :37 -- `TYPES`.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` :18 -- `BUILTIN`. `Test/ScreenGrounding` :49 pins it whole.
- `src/OcuPilot/Screen/Descriptor/AgentSwitches.cls` -- the descriptor pattern. `AgentTranscripts.cls` :26 is at position 4.
- `ui/src/app/areas/agent/switches.page.ts` and `switches.store.ts` -- the form-page, buffer, sticky-bar and violation pattern.
- `ui/src/app/shell/screen-outlet.ts` :108 -- `DESCRIPTOR_PAGES`.
- `ui/src/app/core/proposal-view.ts` :131-206 -- consequence constants and `consequenceSentence`.
- Tests that change:
  - `Test/AuditPurge.cls` :92-150: the unadvertised tests.
  - `Test/ToolDispatch.cls` :136: `TestTheShippedGateAllowsEveryLiveTool`.
  - `Test/Prohibited.cls` :605: `TestGovernanceCannotEnableAProhibitedWrite`.
  - `Test/ToolDispatchProbe.cls` :81 and `LedgerClientDispatchProbe.cls` :58: these fall through to the shipped gate.
  - `Test/SurfaceCoverage.cls` :147 and after :61; `Test/EndpointCoverage.cls` after :83; `Test/ToolEmit.cls` :89; `Test/ToolSetFull.cls` :193.
  - `Test/ConfigGate.cls` sweeps new routes automatically.
- `ui/browser/preferences-reset.mjs` `resetRememberedState`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Governance/Baseline.cls` (new): the XData list from Always, plus `Seed(pKey, Output pListed) As %Boolean` and `Keys(Output pList)`.
- `src/OcuPilot/Kernel/State/Policy.cls` (new): the store from Always, with `GuardedAll(Output pValues, Output pVersion)`, `GuardedApply(pPreset, ByRef pSettings, pExpectedVersion)` and `DeleteAllGuarded()`.
- `src/OcuPilot/Kernel/Governance/Policy.cls` (new):
  - `KeyFor(pToolClass, pName, pArgs)` and `KeysOf(pToolEntry)`;
  - `Resolve(pKey, pKind, Output pEnabled, Output pSource)`, applying the cascade;
  - `Effective(Output pRows)`, the GET body's `keys`.
- `src/OcuPilot/Kernel/Governance/Gate.cls`: `Decide` resolves the tool through `Registry.Resolve`, takes its key from `Policy.KeyFor`, and applies `Policy.Resolve`. A denial carries `code` = `GOVERNANCE.DISABLED` and `key`. Update the header.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls`: add the governance block at the place Always names, then update the header's "six gates".
- `src/OcuPilot/Api/Error.cls`, beside :768:
  - `GOVERNANCEDISABLED`, reason "This tool is disabled by policy.", added to `ToolCodes` and `ReasonForTool`;
  - `GOVERNANCEBODY`, reason "The body must carry preset, settings and rowVersion, with a setting of inherit, enabled or disabled.";
  - `GOVERNANCEKEY`, reason "That key names no write tool on this instance."
- `src/OcuPilot/Api/Governance.cls` (new): `HandleRead` and `HandleUpdate`, as Always describes.
- `src/OcuPilot/Api/Router.cls`: GET and PUT `/agent/governance` after :74; thin targets after :225.
- `src/OcuPilot/Kernel/EntityType.cls`: add `agent-policy` to `TYPES`.
- `src/OcuPilot/Screen/Tool/Base.cls`: add `Parameter GOVERNANCEACTION = ""` with its doc.
- `src/OcuPilot/Screen/Tool/AuditPurge.cls`: as Always's Purge item says. Update the doc at :5-8.
- `src/OcuPilot/Kernel/Agent/Prompt.cls`: append to `BUILTIN`: "When a tool answers GOVERNANCE.DISABLED, say that the tool is disabled by policy on this instance, describe the change you would have made, and do not call it again."
- `src/OcuPilot/Screen/Descriptor/AgentGovernance.cls` (new):
  - route `agent/governance`, `sideBarPosition` 4, `form-page`, privileges `OcuPilotAdmin:USE`;
  - entityType `agent-policy`, scope `instance`, no read, no actions, no classic page;
  - three `promptGroupAgentSetup` prompts;
  - `toolIdentifier` `agent.governance`.
- `src/OcuPilot/Screen/Descriptor/AgentTranscripts.cls`: `sideBarPosition` becomes 5, following EXPERIENCE's order.
- `ui/src/app/areas/agent/governance.page.ts` and `governance.store.ts` (new):
  - The preset is a radio group: None, Read-only, Full.
  - The table's columns are Write tool, Baseline, Setting (a select: Inherit, Enabled or Disabled) and In effect (Enabled or Disabled, followed by the source words).
  - Save and Cancel sit on a sticky bar with `rowVersion`. The stale-save and request-refused patterns follow Switches, and every sentence the server refuses with is the server's.
- `ui/src/app/shell/screen-outlet.ts`: add the import after :48 and the entry at the end of `DESCRIPTOR_PAGES`.
- `ui/src/app/core/proposal-view.ts`: add `CONSEQUENCE_PURGEMARKERS` after :180, and one `consequenceSentence` line before its `return ''` at :206.
- `ui/src/app/core/strings.ts`, add-only after :640: every label, the consequence sentence and the prompts. Each carries its `/** EXPERIENCE.md:NNN */` citation, and a string that already exists is reused.
- `ui/src/app/core/screens.generated.ts`: regenerate it with `node tools/screen-mirror.mjs`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, in place:
  - :257 gains `· "This tool is disabled by policy."`, used on the tool card's failed line and in the card's refusal slot;
  - :342 gains the screen's labels, choices and source words ("by this setting", "by the preset", "by the baseline", "not in the baseline"), and its Where cell names the Governance policy screen (Story 14.2);
  - :344 gains `· "change the governance policy"`;
  - :516 gains `· "This removes audit records, including the markers that record the agent's own writes. It cannot be undone."`, the purge card's consequence;
  - :526 gains "What does the read-only preset change?", "What happens when the agent calls a tool the policy disables?" and "Why is the audit purge disabled by default?"
- `ui/browser/preferences-reset.mjs`: `resetRememberedState` sends GET and then PUT `/agent/governance` `{preset:"", settings:{every key:"inherit"}, rowVersion}`, and asserts 200.
- Tests (new):
  - `Test/GovernanceBaseline.cls`: every `ListTools` write key, across every key `KeysOf` yields for it, is listed; the purge is false; every other listed key is true.
  - `Test/Governance.cls`, covering:
    - the matrix's cascade rows, plus a no-cache leg (set, resolve, clear, resolve);
    - `tool:action`, through a `GOVERNANCEACTION` fixture class passed to `KeyFor` and `Resolve`;
    - a real `Dispatch.Answer` over `webapp.list.update` when disabled;
    - disabled after mint, then Confirm and the draft;
    - the ledger row;
    - the prohibited leg under `full` with the key enabled.
  - `Test/GovernanceWire.cls`: the HTTP legs, the audit row read back, and the 403, 409 and 422 responses.
  - Every class that writes `Policy` snapshots its rows in `OnBeforeOneTest` and restores them in `OnAfterOneTest`, then asserts the restore.
  - `ui/src/app/areas/agent/governance.page.spec.ts`.
  - `ui/browser/governance.browser-spec.mjs`, which restores the policy in `finally`.
- Tests (changed):
  - `AuditPurge`: the purge is in every roster, the model's call is `GOVERNANCE.DISABLED` by default, and with its key enabled a destructive proposal carries `AUDIT.PURGEMARKERS`. Rename the method at `SurfaceCoverage` :147 to match.
  - `ToolDispatch` :136: every live tool is allowed except the purge.
  - `Prohibited` :605.
  - The two probes answer allowed only for a name their fixture registry lists, and fall through to the shipped gate for every production tool, so `AuditPurge`'s default-denied leg still runs the real policy.
  - Coverage rows: `SurfaceCoverage` gets an `AgentGovernance` row after :61; `EndpointCoverage` gets two rows after :83.
  - `ToolEmit` and `ToolSetFull`: the AD-53 comments.

**Acceptance Criteria:**

- **AC1.** Given an administrator on Governance policy, when they set `webapp.list.update` to Disabled with preset Read-only and Save, then:
  - a reload and `GET /agent/governance` both read it back;
  - the row shows "Disabled · by this setting";
  - one audit row names the actor, the target, and the old and new values.
  - A principal without `OcuPilotAdmin:USE` is refused 403.
- **AC2.** Given the default policy, when each registered write key resolves, then every one is enabled except `security.auditing.purge`. Given a write tool registered with no baseline line, when `GovernanceBaseline` runs, then it fails naming the key.
- **AC3.** Given the three layers, when a key resolves, then the first non-null layer wins, and an explicit false there is honored (matrix rows 2-4).
- **AC4.** Given the read-only preset, when the kind is unclassifiable, then the call is denied.
- **AC5.** Given a disabled key, when the model calls it, then the result is `{"code":"GOVERNANCE.DISABLED"}`, nothing is minted, and the tool stays advertised.
- **AC6.** Given a proposal minted while enabled, when its key is disabled before Confirm, then Confirm is refused 403 and the row stays live, and the draft still succeeds.
- **AC7.** Given this story's diff, when it is inspected and Confirm is driven with a disabled key, then `Dispatch.cls` is unchanged, and Confirm's refusal comes before the claim and the port call (the row stays live and the port records no call).
- **AC8.** Given a denied call, when it returns, then its ledger row is still written. Given a PUT naming the ledger or a read tool, when it is sent, then it is refused `GOVERNANCE.KEY`.
- **AC9.** Given preset `full` and the key enabled, when a prohibited effect is confirmed, then its `PROHIBITED.*` refusal stands.
- **AC10 (routed from 12.3).** Given the purge key enabled, when the agent proposes a purge, then the card is destructive and shows the consequence sentence, and Confirm writes it with the agent marker.
- **AC11.** Given a tool declaring `GOVERNANCEACTION`, when its keys are derived and one of them is set, then its keys are `tool:<value>`, and the setting governs that action alone.
- **Integration (Rule 1).** Given a key disabled in the real store, when `Dispatch.Answer` and `Confirm.Confirm` are driven against the real instance, then each refuses with `GOVERNANCE.DISABLED`. These are `Governance.cls` legs.

### Review Findings

Code review 2026-09-27 (full-opus tier; blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor all ran). 13 patched, 0 deferred, 22 rejected. No AD violation found (AD-22, AD-10, AD-53/AD-8, AD-40/AD-34, AD-39, AD-9 checked clause by clause). Rule 3: `governance.browser-spec` and the `GovernanceWire` HTTP legs.

- [x] [Review][Patch] [medium] DW-1754: the resolver's fail-closed read had no test [src/OcuPilot/Kernel/Governance/Policy.cls:93]: `Policy.StoreClass()` seam, `Test/GovernanceStoreProbe`, `Governance.TestAnUnreadableStoreResolvesTheKeyDisabled`.
- [x] [Review][Patch] [medium] A change to a key ending in a credential word (`permissions.users.password`, `*.setpassword`, `*.setsecret`, `*.settoken`) was audited as `[redacted]` (AC1, FR-29) [src/OcuPilot/Api/Governance.cls:LogChange]: key changes are now `changes.keys[{tool, old, new}]`; the AC1 wire leg names `permissions.users.password`.
- [x] [Review][Patch] [medium] `GuardedApply`'s in-place change and `inherit` delete were unpinned [src/OcuPilot/Kernel/State/Policy.cls:103]: `Governance.TestAStoredKeyIsChangedInPlaceAndInheritRemovesIt`.
- [x] [Review][Patch] [medium] The GET's `baseline: "enabled"` was asserted nowhere, on the wire or on the screen [src/OcuPilot/Kernel/Governance/Policy.cls:158]: `GovernanceWire.TestTheReadAnswersEveryWriteKey` pins the `webapp.list.update` entry; the page spec pins its Baseline cell.
- [x] [Review][Patch] [low] The audit was skipped when the post-commit re-read failed, and a concurrent save could be credited to this actor [src/OcuPilot/Api/Governance.cls:108]: the after-state is computed from what this request wrote (`Applied`).
- [x] [Review][Patch] [low] The browser reset saved the policy for every spec, adding a security-change audit row and moving the version each time [ui/browser/preferences-reset.mjs:96]: a policy that reads default is left alone; `preferences-reset.test.mjs` pins it.
- [x] [Review][Patch] [low] The prompt's GOVERNANCE.DISABLED sentence was untested [src/OcuPilot/Kernel/Agent/Prompt.cls:19]: `Governance.TestThePromptSaysWhatAGovernanceDenialMeans`.
- [x] [Review][Patch] [low] `Gate.Decide`'s doc said an unregistered name is always denied; a stale baseline line would allow it [src/OcuPilot/Kernel/Governance/Gate.cls:24]
- [x] [Review][Patch] [low] The restraint-precedence leg forced enforced read-only to 0 afterwards [src/OcuPilot/Test/Governance.cls:302]: it restores the value it read.
- [x] [Review][Patch] [low] `Wire` did not assert the Governance screen is denied to a principal holding nothing [src/OcuPilot/Test/Wire.cls:481]
- [x] [Review][Patch] [low] `AuditPurge.OnAfterOneTest` did not clear the turn marker [src/OcuPilot/Test/AuditPurge.cls:47]
- [x] [Review][Patch] [low] `TestThePurgeIsTheOneDisabledLine` gave no instruction for a later `false` line (Epic 18's) [src/OcuPilot/Test/GovernanceBaseline.cls:48]
- [x] [Review][Patch] [low] `ToolDispatch`'s doc said it asserts the default only where no policy is stored; it asserts none is stored [src/OcuPilot/Test/ToolDispatch.cls:137]

**Rejected:**

- low (theoretical): the AC9 leg would leave `/api/ocupilot` repointed only if the prohibited gate regressed, on a discarded throwaway; real if that leg ever runs outside one.
- false: `Governance` declares no arming variable; `ProposalFixture.EnsureWriteTarget` holds the refusal, as for `DraftRoute`, and the roster pins declaring classes.
- low: a stored row for a key no longer registered cannot be cleared from the screen. reopen_if a tool is removed while a stored row names it.
- low (spec-bound): no reverse baseline check; lines are never removed (Design Notes).
- low (spec-bound): unparseable JSON answers 422 `GOVERNANCE.BODY`, not 400 ("any other shape is refused 422").
- low: `Validate`'s non-object `settings` and string `rowVersion` branches are untested. reopen_if a malformed body is stored.
- low (theoretical): a `GOVERNANCEACTION` call with an out-of-enum value answers `GOVERNANCE.DISABLED`, not `TOOL.ARGUMENTS`; real when a tool declares the parameter (Dispatch order is fixed).
- low (theoretical): a numeric enum member in `KeysOf`; same trigger.
- low: the GET parses the baseline once per key. reopen_if `GET /agent/governance` takes over 1 s.
- low: `AuditPurge`'s failed-mint early exit leaves that turn's ledger rows. reopen_if a later class reads them.
- low: the policy table has no accessible name, like every other in-page table; the walk reads 0 violations. reopen_if the walk flags unnamed tables.
- low: EXPERIENCE.md's amended rows carry no amendment marker; the fix edits a planning document.
- low: the Epic 16 merge residue is recorded only in the Auto Run Result; the orchestrator holds it, and the fix edits the spec.
- low (theoretical): a `settings` member past the local subscript limit answers 500, writing nothing.
- low: `ToolDispatch` and `Prohibited` fail on a stored policy; adjudicated in the triage log above.
- low (theoretical): `GovernanceFixture.Restore` deletes, then re-applies, outside one transaction.
- low: a network-level failure on the first GET leaves the page empty, as on Switches. reopen_if an administrator reports a blank Governance screen.
- low (spec-bound): a 409 keeps the buffer and asks for a reload, the Switches pattern.
- low (spec-bound): a save that changes nothing is audited; every accepted PUT is.
- low: the second halves of AC5, AC6, AC8 and AC10 carry no mutation of their own; Rule 19 asks one per AC, and each has one.
- low: `GovernanceBaseline.TestEveryWriteToolYieldsAKey` cannot fail on today's registry. reopen_if a tool declares `GOVERNANCEACTION`.
- low: the commit's "audited on every accepted write" claim; true after the two audit patches above.

## Spec Change Log

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 21 findings — high 0, medium 7, low 14, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Confirm's order (prohibited before governance before restraint) had no two-gate test — added `TestAProhibitedEffectAnswersBeforeADisabledKey` and `TestADisabledKeyAnswersBeforeTheRestraintVerdict`; red under runs 1830 and 1831.
  - `[medium]` `[patch]` AC9's test ran with the key enabled, so no 14.2 mutation could redden it — the disabled-key-plus-prohibited leg is AC9's pin (run 1830).
  - `[medium]` `[patch]` "a key missing from settings is left unchanged" was unpinned — added `GovernanceWire.TestAKeyTheWriteDoesNotNameIsLeftAsItIs` (run 1835).
  - `[low]` `[patch]` The audit row's changed-keys-only filter was unpinned — the AC1 PUT now names an unchanged key and asserts it is absent (run 1836).
  - `[medium]` `[patch]` The store-unreadable row had no test — added the `Confirm.GovernanceGateClass` seam, its `ConfirmFixture` override and `TestAGateThatCannotDecideFailsTheConfirmClosed` (run 1832); the resolver-level half is deferred (no store seam).
  - `[low]` `[reject]` `tool:action` is verified at `KeyFor`/`Resolve` only — no shipped tool declares `GOVERNANCEACTION`, and driving `Decide` with the fixture needs a registry seam in `Gate`.
  - `[low]` `[patch]` AC7, AC9, AC1's non-admin half, AC8's ledger half and AC2's second clause lacked `mutation:` lines — applied and recorded (runs 1830, 1834, 1837, 1838; AC7 by run 1817 and inspection).
  - `[medium]` `[patch]` "nothing is minted" could not fail because the target did not exist — the dispatch leg now targets the probe application with the turn marker set (run 1833 reddens it).
  - `[low]` `[reject]` `governanceToolDisabled` in `strings.ts` is unreferenced — it mirrors EXPERIENCE.md:257 as `agentWriteBlockedByReadOnly` mirrors the same row; the server renders the sentence.
  - `[low]` `[reject]` `ToolDispatch`/`Prohibited` fail rather than skip on a stored policy — a leaked policy refuses later suites' writes, so failing loudly is the wanted tripwire; CI starts with no rows.
  - `[low]` `[patch]` `KeyFor`'s doc said an argument-less key "resolves disabled", false under `full` — now says the baseline layer reads it disabled.
  - `[low]` `[reject]` No client test of the proposal card after a post-mint disable — the generic live-row refusal path is unchanged; the 403 code is pinned by `Governance` and its sentence by `ToolEmit`.
  - `[low]` `[reject]` No client test of the tool-call card's failed line — it renders the server's reason, pinned as above.
  - `[medium]` `[patch]` Confirm order untested (intent-alignment view of the first finding) — same patch.
  - `[low]` `[reject]` Dispatch order is pinned only by the existing probe-seam tests — `Dispatch.cls` is unchanged (Never list).
  - `[medium]` `[patch]` Store-unreadable untested (intent-alignment view of the fifth finding) — same patch.
  - `[low]` `[reject]` A non-admin's refused GET is not rendered in a test — the descriptor gates the screen on `OcuPilotAdmin:USE` (pinned by `Wire`), and a refused GET takes the `absorbAnswer` path the PUT tests cover.
  - `[low]` `[reject]` The purge card's rendering is not tested for this code — generic consequence rendering; the mapping is pinned by `proposal-view.test.mjs` and the stored code by `AuditPurge`.
  - `[low]` `[reject]` Environment-conditioned preconditions (intent-alignment view of the tenth finding) — as above.
  - `[low]` `[reject]` The dispatch leg does not assert `readOnly` or the footer untouched — `Restraint.cls` and the context builder are unchanged, and the governance code is distinct.
  - `[low]` `[patch]` `StoredArguments` sat inside `Confirm.cls` :426+ under the literal reading of Epic 16's hunk list — moved, with the new seam, above `Transition`.

## Design Notes

**Governing ADs:** AD-22, AD-10, AD-53, AD-8, AD-30, AD-40, AD-34, AD-39, AD-12, AD-9, AD-15, AD-24, AD-5, AD-59, AD-55, and Conventions › Config, › Concurrent writes and › Tool naming.

- **AD-22 amended by the runner at the spec gate (2026-09-27):** the shipped shape.
  - The layers are the stored setting, the preset seed and the baseline seed. There is no environment layer.
  - The baseline is `Kernel/Governance/Baseline.cls`.
  - `tool:action` applies only to a tool declaring `GOVERNANCEACTION`.
  - The gate is also asked at Confirm (AD-40), and never for a person's own write or for a draft.
- **AD-53 amended by the runner at the spec gate (2026-09-27):** the named unadvertised case is now empty, because 14.2 advertises the purge behind a key that is disabled by default. The mechanism stays.
- **AD-8 amended by the runner at the spec gate (2026-09-27):** "today only `security.auditing.purge`" becomes "none today".

**Layers (inference).** The harvested cascade is env ?? file ?? preset ?? default. OcuPilot has no environment configuration, and `Decide` receives no definition id. The AC forbids changing Dispatch, so a per-definition layer would need exactly that change. The stored layer is therefore the one layer an administrator writes.

**How a later story adds a key.** Add one line, `"<tool>": true` (or `false` where that story's criteria say disabled), to `Kernel/Governance/Baseline.cls`, in the same change as the tool. `Test/GovernanceBaseline.cls` reddens, naming the key, until that line exists. Removing a line is a review failure.

**Consumed-by:**

- Every Epic 16 story and every Epic 18 story that adds a write tool: each adds its baseline line. Epic 18's lines are `false` (epics.md :6966).
- Story 16.22 Guardrails, post-merge: `Test/Guardrails.cls` :21 and :71 (on `origin/OCU-1-epic16`) pin the purge as unadvertised. Those pins invert once 14.2 merges, so the orchestrator must tell Epic 16. Its `screens.generated.ts` also conflicts with ours; regenerate it at the merge.

**Consumes:** `Registry.ListTools` and `Resolve`, `Kernel.State.Base`, `Audit.Event.Record`, `Definitions.IsAdministrator`.

**Contended with Epic 16:** `Confirm.cls`, `Router.cls`, `Error.cls`, `SurfaceCoverage.cls`, `EndpointCoverage.cls`, `screen-outlet.ts`, `proposal-view.ts`, `strings.ts`, `screens.generated.ts` and EXPERIENCE.md. Each edit sits off their hunks (see Never).

**Independent parts, if time runs short.**

- (A) The kernel: Baseline, stores, Gate, Confirm, codes, the purge and the prompt, with their tests. This satisfies AC2-AC11.
- (B) The routes, with audit.
- (C) The screen and the browser spec.
- B needs A, and C needs B. AC1 needs B and C.

**Bundle.** A new page may cross the 1900kB warning. If it does, re-base the warning under DW-1166.

## Verification

Slot B. Load the changed `.cls` into `ocupilot-b-ci` from `/tmp/ocupilot-b-ci/src`. Keep one test run in flight at a time. Rebuild and `docker cp` the bundle before any browser run.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, for:
  - the new classes: `GovernanceBaseline`, `Governance`, `GovernanceWire`;
  - the changed classes: `AuditPurge`, `ToolDispatch`, `Prohibited`, `SurfaceCoverage`, `EndpointCoverage`, `ConfigGate`;
  - the regression neighbours: `ToolEmit`, `ToolSetFull`, `ScreenGrounding`, `DraftRoute`, `ToolWrite`, `LedgerSense`, `Descriptor`.
  - Expected: 0 failures, checked against `%UnitTest_Result`.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/governance.browser-spec.mjs browser/audit-copy-purge.browser-spec.mjs browser/switches.browser-spec.mjs` -- expected: all pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(once, before dev_complete)` The full ObjectScript sweep on `ocupilot-b-ci`, one class per call. Then `cd ui && npm test && npm run build`, and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count, and the policy reads default afterwards.

**Pinning mutations (Rule 19), each recorded as `mutation: … → …`:**

- **AC2:** delete one baseline line → `GovernanceBaseline` goes red.
- **AC3:** swap `??` for "any false wins" → `Governance`'s setting-true-over-read-only leg goes red.
- **AC4:** read an unclassified kind as a read → `Governance` goes red.
- **AC5:** `Decide` answers allowed → `Governance`'s dispatch leg and `AuditPurge` go red.
- **AC6:** remove the Confirm block → `Governance`'s confirm leg goes red.
- **AC1:** drop `RecordAudit` → `GovernanceWire` goes red; unbind the setting select → the page spec and the browser spec go red.
- **AC8:** admit read keys in the PUT → `GovernanceWire` goes red.
- **AC10:** remove `Consequence` → `AuditPurge` goes red.
- **AC11:** `KeyFor` ignores `GOVERNANCEACTION` → `Governance` goes red.

Recorded on `ocupilot-b-ci` (ObjectScript mutated in the mount copy and recompiled with subclasses; the client mutation rebuilt and redeployed; each reverted byte-identical, `git diff --stat` unchanged):

- mutation: deleted the `webapp.list.delete` baseline line → `GovernanceBaseline.TestEveryRegisteredWriteKeyHasABaselineLine` red (run 1812).
- mutation: `Policy.Cascade` answers false when any layer holds false → `Governance.TestTheFirstLayerHoldingAValueDecides` red (run 1813).
- mutation: `Policy.Resolve` reads a kind that is not `write` as allowed → `Governance.TestAnUnclassifiableKindIsDenied` red (run 1814).
- mutation: `Gate.Decide` answers allowed → `Governance` dispatch and confirm legs red (run 1815), `AuditPurge.TestThePurgeIsInEveryRosterAndDisabledByDefault` red (run 1816).
- mutation: the `Confirm.Transition` governance refusal disabled → `Governance.TestADisableAfterTheMintRefusesTheConfirmAndTheDraftStillCloses` red (run 1817).
- mutation: `Api.Governance.LogChange` records no audit row → `GovernanceWire.TestAnAcceptedWriteIsReadBackAndAudited` red (run 1818).
- mutation: the PUT admits a `.read` key → `GovernanceWire.TestABadBodyOrKeyIsRefusedAndWritesNothing` red (run 1819).
- mutation: `AuditPurge.Consequence` removed → `AuditPurge.TestThePurgeIsAnAdvertisedDestructiveActionWrite` and `TestWithItsKeyEnabledTheAgentsPurgeIsConfirmedMarked` red (run 1820).
- mutation: `Policy.KeyFor` ignores `GOVERNANCEACTION` → `Governance.TestAnActionKeyGovernsThatActionAlone` red (run 1821).
- mutation: the setting select's `(change)` binding removed → `governance.page.spec.ts` AC1 red and `governance.browser-spec.mjs` AC1 red (timeout on the saved row).
- mutation (AC9): the Confirm governance block moved above the shared gates → `Governance.TestAProhibitedEffectAnswersBeforeADisabledKey` red (run 1830).
- mutation (Confirm precedence): the governance block moved below the restraint verdict → `Governance.TestADisabledKeyAnswersBeforeTheRestraintVerdict` red (run 1831).
- mutation (matrix: store unreadable): Confirm reads a gate error as allowed → `Governance.TestAGateThatCannotDecideFailsTheConfirmClosed` red (run 1832).
- mutation (AC5, AC8 ledger half): `Gate.Decide` answers allowed → the dispatch leg's code, "nothing is minted" and ledger assertions red (run 1833); `Decide` drops the denial's code → the dispatch leg's code and ledger assertions red (run 1834).
- mutation (PUT leaves unnamed keys): `State.Policy.GuardedApply` deletes every key row first → `GovernanceWire.TestAKeyTheWriteDoesNotNameIsLeftAsItIs` red (run 1835).
- mutation (audit carries changed keys only): `LogChange`'s unchanged-key skip removed → `GovernanceWire.TestAnAcceptedWriteIsReadBackAndAudited` red (run 1836).
- mutation (AC1 non-admin half): both handlers skip `IsAdministrator` → `GovernanceWire.TestANonAdministratorIsRefusedBothRoutes` red (run 1837).
- mutation (AC2 every other key enabled): `webapp.list.create` listed `false` → `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` red (run 1838).
- AC7: the port-call half is the AC6 mutation above (run 1817: the write reaches the port) with run 1832; the `Dispatch.cls` half is inspection, `git diff --stat` names no `Dispatch.cls`.

Code review, same method (green runs 2153, 2155, 2157-2160):

- mutation (matrix: store unreadable, DW-1754): `Policy.Resolve` goes on to the cascade after a failed store read -> `Governance.TestAnUnreadableStoreResolvesTheKeyDisabled` red (run 2154).
- mutation (inherit and in-place change): `State.Policy.GuardedApply` skips the `inherit` delete -> `Governance.TestAStoredKeyIsChangedInPlaceAndInheritRemovesIt` red (run 2154).
- mutation (prompt): the GOVERNANCE.DISABLED sentence removed from `BUILTIN` -> `Governance.TestThePromptSaysWhatAGovernanceDenialMeans` red (run 2154).
- mutation (audit of a credential-word key): `LogChange` names each key's entry by the key -> `GovernanceWire.TestAnAcceptedWriteIsReadBackAndAudited` red (run 2156).
- mutation (baseline enabled): `Effective` drops the enabled arm -> `GovernanceWire.TestTheReadAnswersEveryWriteKey` red (run 2156); `BASELINE_WORDS.enabled` mapped to Disabled -> `governance.page.spec.ts` render leg red.
- mutation (reset leaves a default policy alone): the early return removed from `resetGovernancePolicy` -> `preferences-reset.test.mjs` red.

## Auto Run Result

Status: done
Blocking condition: none

- Built A, B and C: the kernel (baseline of 76 keys measured on `ocupilot-b-ci`, `State.Policy`, `Governance.Policy`, `Gate`, the Confirm block, the three codes, the purge advertised with `AUDIT.PURGEMARKERS`, the prompt), the two routes with audit, and the Governance policy screen at side-bar position 4 with Transcripts moved to 5.
- Loop verification, one class per call on `ocupilot-b-ci`, all green: `GovernanceBaseline`, `Governance`, `GovernanceWire`, `AuditPurge`, `ToolDispatch`, `Prohibited`, `SurfaceCoverage`, `EndpointCoverage`, `ConfigGate`, `ToolEmit`, `ToolSetFull`, `ScreenGrounding`, `DraftRoute`, `ToolWrite`, `LedgerSense`, `Descriptor`, `TranscriptStore`, `Wire`, `ProposalConfirm`, `LedgerClientRows`, `Navigation`, `ToolNavigate`. Browser: `governance`, `audit-copy-purge`, `switches`, `definitions` and the structural walk (0 violations) green. `npm run test:tools` 1507/1507, `npm run test:components` 1499/1499, `check-objectscript` and `lint-docs` clean. Initial bundle 1.88 MB, under the 1900 kB warning.
- Tests the spec did not list that the new screen or code moved: `Wire` (six agent screens, positions), `TranscriptStore` (position 5), `Descriptor` (31 entity types), `ToolEmit`'s tool-code sweep (admits `GOVERNANCEDISABLED`), `navigation.test.mjs`, `definitions.browser-spec.mjs`, `preferences-reset.test.mjs`, `proposal-view.test.mjs`; `GovernanceWire` joins the `OCUPILOT_ALLOW_PRINCIPALS` roster in `ci-throwaway.sh`.
- Contended files: `EXPERIENCE.md`, `scripts/ci-throwaway.sh`, `Api/Error.cls`, `Api/Router.cls`, `Kernel/Proposal/Confirm.cls`, `Test/Descriptor.cls`, `Test/EndpointCoverage.cls`, `Test/SurfaceCoverage.cls`, `Test/Wire.cls`, `ui/browser/definitions.browser-spec.mjs`, `proposal-view.ts`, `screens.generated.ts`, `strings.ts`, `screen-outlet.ts`, `_components.scss`, `navigation.test.mjs`. A trial three-way merge against `origin/OCU-1-epic16` adds no conflict: `Wire.cls`, `definitions.browser-spec.mjs`, `screen-outlet.ts` and `navigation.test.mjs` already conflict at HEAD (Story 14.4 against 16.22), on the lines this story also moves.
- Review pass (two layers, 21 findings; 0 high, 7 medium, 14 low): 11 rows patched, 10 rejected with reasons, 1 residue deferred to `deferred:`. Patches: the `Confirm.GovernanceGateClass` seam and its `ConfirmFixture` override; three `Governance` legs (prohibited before governance, governance before restraint, a gate that cannot decide answers 500 with the row live); the dispatch leg aimed at a real target so "nothing is minted" can fail; `GovernanceWire`'s partial-PUT leg and unchanged-key audit assertion; the `KeyFor` doc; `StoredArguments` moved above `Transition`. Every new or missing pin has its `mutation:` line (runs 1830-1838).
- Follow-up review recommended: false. Two or more mediums were patched, but each patch is a test or a seam whose mutation was observed red; no unverified risk can be named.
- Full ObjectScript sweep on `ocupilot-b-ci` (`ci-runner.mjs`, one class at a time, each checked against the result global): 314 classes, 2,595 tests, 1 failed. The failure is `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` "nothing is cut at 1,000": the reused throwaway's task history holds 1,110 rows. The diff touches no task code, so this reads as the container's accumulated history (inference), not this story. Browser, run after the final build and redeploy: `governance`, `audit-copy-purge`, `switches`, `definitions` and the structural walk, 29/29. `npm test`: 1,507 tools and 1,499 components green. `npm run build` green, initial total 1.88 MB. Smoke: 48/48. `check-objectscript` and `lint-docs` clean. EXPERIENCE.md holds 981 lines. The policy reads default afterwards (no preset, 76 keys, all `inherit`).
- Took longest: the implementation hand-off (36 min), then the sweep (33 min).
- Residual risk: Epic 16's `Test/Guardrails.cls` pins the purge as unadvertised, and its new write tools need baseline lines. `GovernanceBaseline` goes red, naming each missing key, until they are added at the merge.
