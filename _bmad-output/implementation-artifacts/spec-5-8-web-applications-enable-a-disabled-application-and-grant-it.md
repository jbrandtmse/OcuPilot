---
title: 'Story 5.8: Web applications - enable a disabled application and grant it a resource'
type: 'feature'
created: '2026-09-20'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Stories 5.1-5.7 built every part of the write path, but no part of it has been driven
end to end in a real area by a user, and four of this story's own promises have no producer. The
write tool's gate is `%Admin_Secure:WRITE`, a pair no shipped role grants, so the central demo would
be `%All`-only (DW-1208). The card's "N unchanged fields" disclosure has no rows behind it and
renders an empty value as blank where the AC's own diff reads `Resource: (none) -> %Development`
(DW-1223). A refused confirm produces no write tool-call card, so nothing reads
`failed - <resource>` (DW-1252's surface half). The reply carries no "Shall I show you the audit
entry?" and the navigation tool cannot name a filter, so the audit hand-off has no channel. And
`smoke.sh` still reports `agentwrite` and `auditmarker` as `pending`, leaving AD-45's one smoke path
short of the write and the marker it names (DW-1382).

**Approach:** Change the write permission to the one the classic editor checks; give the disclosure
its rows from the payload the proposal already stores, masking secret-classified values rather than
dropping fields; record a failed write card on a refusal; add one **declared-flag** criterion to the
navigation tool plus one published reply sentence; light the two smoke checks by driving the shipped
mint-confirm path against AD-25's `/csp/myapp`; and pin the whole journey with one browser spec.

## Boundaries & Constraints

**Always:** The write tool requires `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, each once - the pair
set the Web applications screen already declares and exactly what
`%CSP.Portal.Application.CheckSecurity` checks, which is what makes "the same 403 the editor would
give" true by construction (DW-1208, owner decision 2026-09-21). Every gate stays inside AD-34's
transition. The write sends the **complete merged property set** (AD-4) through the screen's own
declared endpoint `WebApp.App`. Unchanged rows are built from the **stored** payload - no second read

- and every secret-classified or unclassified path renders as the published mask, so the caption's
count and the rows rendered are the same population and no secret value reaches the wire (AD-3,
AD-35, Conventions > Secrets). The navigation tool may **name** a criterion the target descriptor
declares; it never supplies a value (AD-21). Every user-visible string comes from
`ui/src/app/core/strings.ts` and appears in EXPERIENCE.md's Fixed-strings table at the **tail**
(shared-append); non-ASCII is authored as `\uXXXX` (Rule 14). `core/` imports no `@angular/core`
(AD-19). The smoke check uses `OcuPilot.PKG` classes only and restores the fixture's created state.
Every IRIS MCP call carries `server: "ocupilot-slot-a"`; the throwaway is `ocupilot-ci` on 52776/1975.

**Never:** No new resource of OcuPilot's own carrying its own WRITE - the rejected alternative in
DW-1208, because it is a second authorization model the vendor's can diverge from. No new write tool,
no `SCHEMAVERSION` move, no change to `UnchangedCount`'s computation. No second read at wire time.
No caller-supplied criterion value and no non-`ns` query parameter on an agent navigation
(`navigation.ts:531-534` governs). No edit to `ui/src/styles/**` or
`ui/src/app/shell/{header,account-menu,side-bar,command-box}*` - Epic 15 holds those and is live. No
auto-refresh chip added to the Web applications list (AD-43's roster governs - see the halt below).
Do not write `deferred-work.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| **DW-1208.** The write tool's pair set | `Registry.RequiredPairs("webapp.list.update")` | `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, each exactly once, and no pair carrying a permission no shipped role grants | None |
| **DW-1208.** A non-`%All` holder of the screen's own pairs | That principal confirms an enable + resource grant | The write succeeds; no `%All` is needed anywhere on the path | None |
| **DW-1223.** The disclosure has rows | A live `webapp.list.update` proposal changing `Enabled` and `Resource` | `WireRow` emits `unchanged[]` of `{field, value}` built from the stored payload minus the changed field names; its length equals `unchangedCount`; the card's disclosure is a `<button>` and expands to that many rows | None |
| **DW-1223.** A secret-classified or unclassified path | `MatchRoles` and any payload property with no `ordinary` literal row in `ToolFields` | The row is present with the published mask as its value; the raw value never reaches the wire | Fail closed - anything not classified `ordinary`/literal is masked |
| An empty value in any diff row | `Resource` reads `""` before the change | The row renders `(none)` (`tableEmptyValue`), on the changed row's before half and on an unchanged row alike | None |
| **DW-1252.** A confirm refused 403 | `Confirm` answers `AUTH.NOPRIVILEGE` with `detail.failedPair`, row stays `live` | One write tool-call card reads `failed - %Admin_Secure:USE`, the proposal card keeps its refusal banner and its Confirm, and the agent's reply states the refusal with no second confirm attempt | Rendered on both cards, never swallowed |
| AC3. The audit hand-off | A confirmed write in the turn | The reply ends with the published "Shall I show you the audit entry?" sentence, appended by the panel | None |
| AC3. The filtered navigation | `shell.screen.open` called with `route: "logs/audit"` and `criterion: "marker"` | The client navigates to `logs/audit`, applies the descriptor's own marker criterion, runs the screen's declared read, and the agent-marked event for that proposal is rendered under the confirming user's name | None |
| AC3. An undeclared criterion | `criterion: "nosuchthing"`, or one the target descriptor does not declare | The directive is refused with `NAV.CRITERIONUNKNOWN` before any announcement exists | Closed code, never a silent no-op |
| AC5. OcuPilot's own application | A proposal to disable or drop the resource of `/ocupilot`, `/api/ocupilot` or `/api/ocupilot/readiness` | Refused inside the transition with `PROHIBITED.SERVINGPATH`; no delete verb for web applications is advertised at all | Refused on the instance whatever the caller |
| **DW-1382.** The smoke path with the demo fixture | `smoke.sh --demo 1` on a container whose install created `/csp/myapp` | `agentwrite` and `auditmarker` execute: a proposal is minted and confirmed through the shipped path, the target reads back enabled with `%Development`, one `AgentWrite` audit row carries that proposal id, and the fixture is restored to disabled with no resource | A failed write or a missing marker row is `fail` naming which |
| **DW-1382.** The smoke path without the fixture | The `package` job's container (no `OCUPILOT_DEMO`), or a `/csp/myapp` this install did not create | Both checks read `skipped` with the reason naming the absent or unowned fixture - never `pending` and never `fail` | Skip, so `executed=` stays honest |
| A repeat smoke run | The same container smoked twice | The second run executes both checks again and leaves the fixture disabled with no resource, as the first did | Idempotent by the restore |

</intent-contract>

## Code Map

### The gate (DW-1208)

- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls:51` `PERMITTEDFIELDS = "AutheEnabled,Description,Enabled,Resource"`; **`:55` `WRITERESOURCE = "%Admin_Secure"`, `:57` `WRITEPERMISSION = "WRITE"` - the literal to change**; `:53-54` the doc sentence "writing needs more than using it", which becomes false; `:92-97` `PrivilegePairs()` = `Gate.RequiredPairs(DESCRIPTORCLASS)` concatenated with the one own pair - **the site that then holds `%Admin_Secure:USE` twice**. `KIND = "write"` is inherited from `Screen/Tool/Write.cls:25`. Nothing in schema generation reads the pairs.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls:50` the screen's declared pairs (`%Admin_Secure:USE`, `%DB_IRISSYS:READ`); `:48-49` **`"refreshes": false`**; `:57-58` `primaryAction`/`rowActions` both empty; `:64` `classicPage = "%CSP.UI.Portal.Applications.WebList"`; `:66-72` the declared read (`WebApp.App` `LIST`, six fields, `paging: "cap"`); `:73-84` the table columns.
- `src/OcuPilot/Screen/Gate.cls:42-45` `ADMINPERMISSION = "USE"` for all thirteen `%Admin_*` resources - the vocabulary DW-1208 rests on; `:106-122` `RequiredPairs`; `:132-168` `EvaluatePairs`/`EvaluateRequired`; `:227-248` `ParsePairSpec`; `:262-265` `HoldsPrivilege`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:198-390` `Transition` - gate order tool `:203`, secrets `:211`, **prohibited `:219`**, restraint `:235`, **pairs `:250-261`** (`MissingPair` -> `Refuse(403, AUTHNOPRIVILEGE, detail.failedPair)`), conversation `:265`, definition version `:279`, fingerprint `:292`, claim `:315`, **vendor PUT `:345`**, marker `:371`, ledger finalize `:373`; `:42` `WRITETYPE = "PUT"`; `:616-625` `HoldsPair` (`$SYSTEM.Security.CheckUserPermission`, overridable - the fixture's seam).
- `src/OcuPilot/Api/Error.cls:111,118` `AUTH.NOPRIVILEGE` and its reason; `src/OcuPilot/Api/Confirm.cls:81-116` `RenderRefusal` and the reason lookup.
- Tests that turn red on the literal: `src/OcuPilot/Test/ToolWrite.cls:214` (`tSpelled [ "%Admin_Secure:WRITE"`, method `:203-215`, whose name and doc both become wrong); `src/OcuPilot/Test/ProposalConfirm.cls:34` `DENIEDPAIR = "%Admin_Secure:WRITE"`, used `:240`, asserted `:248` - **must become a pair the tool actually requires, or `MissingPair` returns nothing and the test proves nothing**; `src/OcuPilot/Test/ToolEmit.cls:186` derives from the two parameters (follows the change) but `:181-183`'s "the addition is the point" doc becomes false; `src/OcuPilot/Test/ToolDispatch.cls:448,455` hold the literal as synthetic envelope data only.
- Read-only evidence: `src/OcuPilot/Test/SurfaceCoverage.cls` and `Test/EndpointCoverage.cls` pin **no pair**, and neither holds a remaining "assert the zero" tripwire - Story 5.5 tripped the write-half one (`SurfaceCoverage.cls:93` row, `:281` `tDerived > 0`). Their stale doc comments at `SurfaceCoverage.cls:260-268` and `:284-286` still describe the deleted zero.

### The prohibited set (AC5) - already covers this story, pinned not built

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:69` `COVEREDTYPES = "web-application"`; `:134-138` `PermittedChangeFields` (the same four, kept equal to `PERMITTEDFIELDS` by the suite); `:146-150` `AlwaysProhibitedFields` (`MatchRoles`, `DispatchClass`); `:261-306` `WebApplication` - `:270` serving-path refusal via `ServesOcuPilot` (`:401-425`, reading `Install/Roster.cls:108,122,140`), `:278` **`Resource` refused only when the new value is empty**, `:286` `MatchRoles` -> `PRIVILEGEGRANT`, `:290-299` the uncovered-field sweep; `:317-340` `Changed`. So enable (`0->1`) and a resource **grant** are permitted today and need no kernel change; clearing the resource is the refusal, and it is a cheap second leg on the same fixture.

### The card (DW-1223, AC1)

- `src/OcuPilot/Kernel/State/Propose.cls:88-90` **`Payload`** ("the complete merged body the write will send"); `:92-97` `Diff` and `UnchangedCount`; `:99-105` `Rationale`/`ExpectedImpact`/`Reverse`; `:571-606` `RowValues` - **already reads `payload` and `diff` into `pValues` in the same read**, so rows cost no second read; `:613-636` `WireRow`, the 11 keys, `unchangedCount` a pass-through at `:626`; **`:489-490` and `:610-612` assert the payload's absence from the wire as an invariant - rewrite both at their origin, do not append.**
- `src/OcuPilot/Kernel/Proposal/Mint.cls:113-121` and `:226-292` `Merge` - `tTotal` counts **top-level** payload properties, `pUnchanged = tTotal - tChanged` (`:284`), a no-op argument yields no diff row; `:384-390` `Display`, the shared renderer (empty -> `""`, boolean -> `true`/`false`, object/array -> compact JSON); `:123-127` `Fingerprint.Of` with `FingerprintExcludes`; `:140-142` `TextArgument` for the three agent sentences.
- `src/OcuPilot/Screen/Tool/ToolFields.cls` (generated) - the per-path `class` (`ordinary`/`secret`/`opaque`) keyed by tool name; `webapp.list.update`'s only `secret` rows are `MatchRoles[].MatchRole` and `MatchRoles[].TargetRoles[]` (`:38-39`). Readers to reuse rather than rewrite: `Screen/Tool/Write.cls:111-155` `FieldRows` and `Screen/Registry.cls:2139-2160` `ToolFieldRows` ("an unreadable field list is not a negative result"). Grammar and the fail-closed rule: `Screen/Tool/Classification.cls:1-18`.
- `src/OcuPilot/Screen/Tool/Write.cls:199-201` where `rationale`, `expectedImpact` and `reverse` are declared as **model-authored optional string arguments** under `additionalProperties: false`; `:210-219` their absence from the result schema.
- `ui/src/app/core/proposal-view.ts:59-65` **`ProposalCardView.unchanged` already declared and unsupplied**; `:262-283` `toCardView` - **does not pass `unchanged` through**; `:29-33` `ProposalDiffRow`; `:240-245` `MASKED_VALUE`/`maskedRow`; `:212-234` `statusLineFor`.
- `ui/src/app/shell/proposal-card.ts:93-106` the changed rows; `:107-132` **the `aria-expanded` disclosure, already built and already spec-covered** (`<button>` iff rows exist, `<p>` otherwise); `:119-124` the unchanged row, which renders field + value and **no direction word**; `:135-149` rationale, expected impact and `Reverse:`; `:175-184` the DW-1348 refusal banner (`data-slot="refusal"`, live only); `:377-407` the row getters and `unchangedCaption`.
- `ui/src/app/core/strings.ts` - present: `:165` `proposalUnchangedFieldsDisclosure`, `:135/:137/:139` the three labels, `:320` `tableEmptyValue: '(none)'`, `:184` `toolCallStatusFailed: 'failed - <reason>'`, `:153-163` the status lines. **Absent: a visually hidden "unchanged" direction word (EXPERIENCE.md:415 publishes the requirement) and the audit-entry offer sentence.**
- `ui/tools/proposal.test.mjs:413-445` the AD-6 literal-authoring gate - its `authoring` alternation names `before|after|unchangedCount|rationale|expectedImpact|reverse|fingerprint|auditWarning`; **a new wire field belongs in that alternation** or the gate stops covering the whole proposal shape. `ui/tools/example-proposal.test.mjs:83-127` derives the example's count from EXPERIENCE.md's UJ-3 step and `:154` pins `EXAMPLE_PROPOSAL`'s key set to exactly seven keys - **read-only here; the empty-state example stays non-interactive**.
- `ui/src/app/shell/proposal-card.spec.ts:110-133` the changed rows, `:134-140` the caption, `:141-166` **the whole disclosure, already asserted against supplied rows**, `:489-533` the DW-1348 refusal banner.

### The refusal surface (DW-1252, AC4)

- `ui/src/app/shell/panel.ts:991-1008` `onCardConfirm`; **`:1012-1018` `recordWriteCard` returns early on `!outcome.ok`, which is why a refusal produces no write card**; `:813-829` `proposalView` (`:824` reads `turn.proposalRefusal(id)?.reason` into `toCardView`'s fourth argument); `:836-857` `phaseFor`; `:859-867`/`:881-894`/`:924-933` the three published reply-sentence appenders and `:791-798` where they compose - **the template AC3's fourth appender follows**; `:907-914` `writeSteps`.
- `ui/src/app/core/turn.ts:247-266` `ProposalOutcome` (`ok, state, closedReason, confirmedAt, status, code, reason, auditMarked`); `:926-994` `decideProposal` - `:967-993` the refusal branch, which already records `{status, code, reason}` per proposal (`:725-735` `recordProposalRefusal`, `:720-722` the reader); `:516-535` `confirmedWriteStep`, the shape a refused write card mirrors; `:216-220` `TurnNavigation` (`seq`, `route`, `entityId` - **no criterion**).
- `ui/src/app/shell/tool-call-card.ts:111-117` `toolCallStatusFailed`, whose detail is `step.failedPair` if non-empty else `step.reason`; `:121-124` the three audit-marker words.
- `ui/src/app/shell/panel.spec.ts:3130-3157` asserts **zero** `app-tool-call-card` on a live-row refusal - the Story 5.6 pin this story's AC4 refines; `:3162-3234` the write card and the marker sentence; `ui/tools/turn.test.mjs:1270-1303` the DW-1348 per-proposal refusal record.

### The audit hand-off (AC3)

- `src/OcuPilot/Screen/Tool/Navigate.cls:25-31` `shell.screen.open`, `KIND = "read"`, **`FULFILMENT = "client"`**; `:43-59` `BuiltRoutes()`; **`:64-87` `InputSchema` - `route` (enum, required) and `entityId` only, `additionalProperties: false`**; `:100-113` `ResultSchema`; `:158-...` `Directive` and its refusals (`NAV.ROUTEUNKNOWN`, `NAV.ENTITYNOTALLOWED`).
- `src/OcuPilot/Screen/Descriptor/AuditList.cls:113` route `logs/audit`; `:117` archetype `list (server criteria)`; `:126` **composite id, so `entityId` on this route is refused** - AC3's event is reached by the filter, not by selecting a row; `:141-151` the nine criteria; **`:152` the declared marker criterion `{"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}` - a flag criterion whose value is the descriptor's own**; pinned at `Test/Descriptor.cls:503` and `Test/CriteriaCorpus.cls:39,49,79-81`.
- `ui/src/app/areas/logs/audit.store.ts:26` `AuditSearch`; `:88-96` `marker()`/`setMarker()` - **one caller only, the checkbox**; `:99-105` `searched()`/`noteSearched()` - **the archetype renders nothing until this is set**; `:145-153` `criteria()`, where the marker **overrides** `eventSources` rather than merging; `:158-161` `overriddenByMarker`.
- `ui/src/app/areas/logs/audit.page.ts:107-116` the checkbox (`data-ocu-marker="filter"`); `:297-299` `onMarker`.
- `ui/src/app/shell/agent-navigator.ts:11-18` the announce-first delay; `:93-94` the target build and `withQuery`; `:95-102` the arrival announcement; `:104` the guard decline.
- `ui/src/app/core/navigation.ts:531-543` **`withQuery` carries only `ns`, by documented intent** - the criterion travels on the directive, never as a query parameter.
- `src/OcuPilot/Api/Turn.cls:286,349-384` the closed navigation-answer vocabulary; `src/OcuPilot/Api/Error.cls:734-759` the closed `NAV.*` code family, which a new refusal joins; `src/OcuPilot/Kernel/Agent/Dispatch.cls:402,582-592` the directive and `SettleClient`.

### The smoke path (DW-1382)

- `src/OcuPilot/Install/Smoke.cls:25-27` **"`OcuPilot.Test.Http` is test-scope: it does not ship, so this class cannot depend on it"** - the scope wall; `:212-250` `Run` and its three frames; `:289-295` `Note` (name/outcome/reason); `:300-338` the one HTTP seam; `:462-502` `CheckSignIn`, which mints a real token pair for `--user`; `:1041-1090` `CheckAuditEvent`, which sweeps `Audit/Event.Names()` and therefore already covers the `AgentWrite` triple (`skipped`, not `fail`, on a partial roster - `:1089`); `:1153-1172` `CheckDemoFixture`; **`:1177-1181` `AddPending`, the two entries to replace**; `:1189-1223` `Render` (`executed = pass + fail`, verdict `executed > 0 && fail = 0`).
- `scripts/smoke.sh:50-63` the flags, `:127-137` `--demo` resolved from `/proc/1/environ`, `:156-163` the invocation, `:189-196` the failing-check names read positionally out of `Render`'s fixed-width lines - **no check name appears in the shell script**.
- `src/OcuPilot/Install/Fixture.cls:69` `APPPATH = "/csp/myapp"`; `:262-315` `CreateWebApp` - `:294-298` the created state (`Type` 2, **`Enabled` 0, no `Resource` key**); `:265-293` the absent-only guard and the pre-existing-application warning; `:224-234` `WebAppOwnedByProfile`, the ownership read the restore must use.
- Shipped seams the check can compose (no `Test/` class): `Kernel/State/Turn.cls:150` `GuardedReserve`, `:250` `GuardedBegin`, `:324` `GuardedFinish`; `Kernel/Proposal/Mint.cls` and `Kernel/State/Propose.cls:183` `GuardedMint`; `Kernel/Proposal/Confirm.cls:104` `Confirm`; `Kernel/Audit/Event.cls:38,243,272` the `AgentWrite` triple and its emitter. `src/OcuPilot/Test/AuditMarker.cls:154-192` is the worked precedent for the whole sequence - it needed `Test/` only for the turn row (raw SQL) and the probe application, both of which have shipped substitutes here.
- `scripts/ci-throwaway.sh:171` **`OCUPILOT_DEMO: "1"`** (so the `instance` job's `/csp/myapp` exists) and `:172-242` the seven arming rosters, held equal in both directions by `ui/tools/ci.test.mjs:1731-1761`. `docker-compose.yml:25-29` the same flag, pinned by `ui/tools/compose.test.mjs:71-73`. **`scripts/ci-ipm-archive.sh:389` starts its container with no environment at all, and `:442-456` runs smoke there** - that is the container on which both new checks must read `skipped`. `ui/tools/ci.test.mjs:1548-1586` compares compose keys but **not** the `environment:` block, so `ci-throwaway.sh`'s demo flag is pinned by nothing.
- `.github/workflows/ci.yml:144-145` `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, after `ci-runner.mjs` and before the browser leg.

### The browser tier (the precedent to copy exactly)

- `ui/browser/proposal-confirm.browser-spec.mjs` - the only spec that makes a real confirmed write. `:59-76` `before`: **live-container refusal guard**, readiness gate, `requireFreeSlot`, launch, `armProbeDefinition`, **`allowWrites()` (`:99-106`, `Test.Restraint.SetDefinitionReadOnly(id, 0)` - under read-only no proposal is minted at all, AD-30)**, `ensureTarget`, `dropProposals`; `:126-131` `storedEnabled()` the instance-side witness; `:134-150` the live-proposal count and `GuardedDeleteForUser`; `:160-193` **`proposeReply` and `withLiveCard` - the arm-and-drive bracket: `nextTag` -> `setTag` -> two `scriptReply` calls (the `tool_use`, then the closing text) -> `signedInAt` -> type -> Send -> wait for the card**; `:195-257` the AC10 confirm leg and its two read-backs.
- `ui/browser/turnprobe-spec.mjs` - **how a proposal is minted with no LLM**: `OcuPilot.Test.TurnProvider` is an Anthropic adapter whose `IssueHttpsPost` answers from a script keyed by the definition's `Model` string, so the real kernel, the real dispatch and the real mint all run. Exports: `runIris`, `markerValue`, `nextTag` (`:77-82`), `ensureDefinition`, `setTag` (`:132-139`), **`scriptReply` (`:151-158`)**, `forgetTag`, `armProbeDefinition` (`:171-176`), `disarmProbeDefinition`, `abandonTurns`, **`requireFreeSlot` (`:231-245`, needed before every Send)**. Reply builders: `src/OcuPilot/Test/TurnProvider.cls:38` `Script`, `:72` `TextReply`, `:84` `ToolUseReply`.
- `ui/browser/panel-spec.mjs:60-75` `signedInAt`, `:91-101` `saveAndSettle` (DW-1169).
- `ui/browser/change-highlight.browser-spec.mjs:61-70` `HIGHLIGHT_BUDGET_MS = 2000` with `HIGHLIGHT_WAIT_MS = BUDGET * 5` and the doc naming `data-table.browser-spec.mjs:141-151` as the mistake not to copy; `:190-208` `listWithLiveCard`, which signs in **on the list** so the highlight is observable; `:309-347` the `Date.now()` bracket and the elapsed log on a green run. `ui/browser/change-highlight-noncanonical.browser-spec.mjs:54,117-134` the **mixed-case** fixture (`/csp/OcuPilotProbeConfirmMixedCase`) and `:261-265` the case-preserved row assertion.
- `ui/browser/audit.browser-spec.mjs:292-311` `signedInAtScreen` with its `/api/ocupilot/screens/` request collector; `:546-614` **the agent-marker filter leg, which already asserts the override in both directions**; `:83-90`/`:733-767` the `FIRST_ROW_BUDGET_MS` bracket.
- `ui/browser/refused-tool.browser-spec.mjs:48-82` a **real least-privileged principal** built from `Test.TurnWireFixture.Resources(1)`, which deliberately omits `%Admin_Secure` and verifies the missing pair on the instance before driving the turn - **the ready-made lever for AC4's denied confirm**; `:145-156` the "exactly two provider calls, so no retry path exists" assertion.
- `src/OcuPilot/Test/ProposalFixture.cls:111-124` `DenyPair`/`DeniedPair` (the `HoldsPair` seam); `:373-377` the canonical write target and its marker; `:396-475` `EnsureWriteTarget`/`WriteTargetField`/`RemoveWriteTarget` with their two guards (`OCUPILOT_ALLOW_PRINCIPALS` and "will not adopt one it did not make"); `:483-567` the mixed-case trio.
- `ui/browser.config.mjs:24,42,45` `DEFAULT_ORIGIN`, `DEFAULT_CONTAINER = 'ocupilot-ci'`, `LIVE_CONTAINER = 'ocupilot'`; `:60-88` the origin/container cross-check; `:85-86` viewport 1440x900 and the 30 s navigation timeout.
- `ui/package.json:6-18` the scripts: `prebuild`'s six checkers, `test:tools`, `test:components`, `test:browser` (`node --test --test-concurrency=1 browser/*.browser-spec.mjs`). `ui/tools/ci-runner.mjs:38-39,359-380` its flags (`--container` required, repeatable `--class`).

### Measured, not recalled

- `WebApp.App` `GET` on `/api/ocupilot`, `ocupilot-slot-a`, 2026-09-20: **46 top-level properties**, of which three are arrays (`CorsAllowlist`, `CorsHeadersList`, `MatchRoles`). A two-field change therefore leaves `unchangedCount` at **44**, not the 38 EXPERIENCE.md:756 names. Re-measure against `/csp/myapp` on the throwaway before writing the number down.

## Tasks & Acceptance

### Execution:

1. `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- set `WRITEPERMISSION` to `"USE"`, replace the `:53-54` doc sentence with what the pair now is and why (the classic editor's own check), and make `PrivilegePairs()` emit each pair once -- so the resolved set is the screen's two pairs and the ledger's pair column carries no duplicate. (DW-1208)
2. `src/OcuPilot/Test/ToolWrite.cls` -- re-point `:203-215` at the new pair set: the assertion becomes that the resolved set is exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, each once, and that no pair carries a permission no shipped role grants. Rename the method and rewrite its doc to match; check no coverage roster names the old name. (DW-1208)
3. `src/OcuPilot/Test/ProposalConfirm.cls` -- change `DENIEDPAIR` to a pair the tool actually requires, so `MissingPair` still has something to fail on and `:248` still tests the naming rather than passing vacuously. (DW-1208)
4. `src/OcuPilot/Test/ToolEmit.cls` -- rewrite the `:181-183` doc: the write tool's set is the screen's set, and the barrier a write crosses beyond a read is the confirm transition, not a privilege delta. (DW-1208)
5. `src/OcuPilot/Kernel/State/Propose.cls` -- add `unchanged[]` of `{field, value}` to `WireRow`, built from `pValues("payload")` minus the changed field names, each value rendered by `Mint.Display`, and every path that is not `ordinary` + literal in `ToolFields` -- including any with no row at all -- carrying the published mask instead of its value. Its length must equal `unchangedCount`. Replace the `:489-490` and `:610-612` "not on the wire at all" sentences with the new rule at their origin. (DW-1223)
6. `src/OcuPilot/Test/Proposal*` (the class covering `WireRow`) -- pin the three properties: rows equal the payload's top-level properties minus the changed ones, `$ListLength` equals `unchangedCount`, and `MatchRoles` plus any unclassified property arrive masked with no raw value anywhere in the wire row. (DW-1223)
6b. `ui/src/app/core/turn.ts` -- parse `unchanged[]` off the wire beside `changed`, authoring no value. (DW-1223)
7. `ui/src/app/core/proposal-view.ts` -- forward `unchanged` through `toCardView`, the one line that today drops it. (DW-1223)
8. `ui/src/app/shell/proposal-card.ts` -- give the unchanged row its visually hidden direction word, and render an empty value as `tableEmptyValue` on the changed row's before half and on an unchanged row alike, so AC1's `Resource: (none) -> %Development` reads as published.
9. `ui/src/app/core/strings.ts` + EXPERIENCE.md's Fixed-strings table -- two keys at the tail: the unchanged-row direction word and the audit-entry offer sentence. Reuse `tableEmptyValue` rather than adding a second key with the same value.
10. `ui/tools/proposal.test.mjs` -- add the new wire field to the `authoring` alternation at `:424`, so the AD-6 gate keeps covering the whole proposal shape.
11. `ui/src/app/shell/panel.ts` -- record a write tool-call card on a refused confirm, carrying the refusal's `failedPair` or `reason`, so `failed - <resource>` has a producer; and add the fourth published reply appender for "Shall I show you the audit entry?", gated on the turn holding a confirmed write. (DW-1252, AC3, AC4)
12. `ui/src/app/shell/panel.spec.ts` -- replace the `:3130-3157` "zero tool-call cards" assertion with the card AC4 names, stating in the test's own name that 5.6 pinned the absence only because nothing produced one.
13. `src/OcuPilot/Screen/Tool/Navigate.cls` -- add one optional `criterion` argument naming a criterion the target descriptor **declares as a flag** (value supplied by the descriptor, never by the caller); refuse anything else with a new `NAV.CRITERIONUNKNOWN` before any announcement exists. Carry it on the directive. (AC3)
14. `src/OcuPilot/Api/Error.cls` -- add `NAV.CRITERIONUNKNOWN` to the closed `NAV.*` family. (AC3)
15. `ui/src/app/core/turn.ts` + `ui/src/app/shell/agent-navigator.ts` -- carry the criterion on `TurnNavigation` and apply it on arrival through the target screen's own store seam, then run that screen's declared read, so the arriving screen shows rows rather than an unsearched form. No query parameter: `withQuery` stays `ns`-only. (AC3)
16. `ui/src/app/areas/logs/audit.store.ts` -- expose the non-interactive path the arrival uses (set the marker, note searched) beside the checkbox's, so there is one answer to "is the marker on" and not two. (AC3)
17. `src/OcuPilot/Install/Smoke.cls` -- replace `AddPending` with real `agentwrite` and `auditmarker` checks: mint and confirm a proposal for `webapp.list.update` against `/csp/myapp` through the shipped path, assert the target reads back enabled with `%Development` and that one `AgentWrite` audit row carries that proposal id, then restore the fixture to disabled with no resource. Both read `skipped`, with the reason naming the cause, when the demo fixture is absent or this install did not create it. `OcuPilot.PKG` classes only. (DW-1382)
18. `src/OcuPilot/Test/Smoke.cls` -- pin the three outcomes of each new check (executed pass, `fail` naming which half, `skipped` on an absent or unowned fixture) and that a repeat run leaves the fixture disabled with no resource.
19. `ui/tools/ci.test.mjs` -- hold `ci-throwaway.sh`'s `OCUPILOT_DEMO` line equal to `docker-compose.yml`'s, so the `instance` job's new smoke checks do not rest on an unpinned line.
20. `src/OcuPilot/Test/SurfaceCoverage.cls` -- correct the stale `:260-268` and `:284-286` comments at their origin: the write half has a member and the zero is gone.
21. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:756` -- amend the demo's "38 unchanged fields" to the number measured against `/csp/myapp`, and follow it through `ui/tools/example-proposal.test.mjs` and `ui/src/app/shell/proposal-card.spec.ts`. Record it in `## Spec Change Log` (Rule 5, apply-and-report: an observable restated to match the instance, intent unchanged).
22. `ui/browser/proposal-demo.browser-spec.mjs` (new) -- the story's journey against the throwaway on AD-25's `/csp/myapp`, signed in **on the list** so the highlight is observable: a read card completes, the proposal card carries both diff rows with `(none)` on the before half, the disclosure opens to `unchangedCount` rows, the three agent sentences and the `Reverse:` line render, Confirm produces the status line and the `done · audit marked` card, and the row re-fetches and highlights inside the 2,000 ms budget measured with `Date.now()` and logged on a green run.
23. `ui/browser/proposal-demo.browser-spec.mjs` -- two more legs on the same fixture: a **denied confirm** as the `Resources(1)` principal, asserting the `failed - <pair>` card, the proposal card's refusal banner, a Confirm that is still pressable and exactly the provider calls the turn made (no retry); and the audit hand-off, asserting the reply's published question sentence and that `shell.screen.open` with the marker criterion lands on `logs/audit` with the filter applied and the agent-marked event rendered under the confirming user's name.
24. `src/OcuPilot/Test/ProhibitedRoute.cls` -- extend to AC5's two effects if not already covered: a disable and a resource-clear against each of OcuPilot's three serving paths is refused with `PROHIBITED.SERVINGPATH`, and the registry advertises no delete verb for web applications.

**Acceptance Criteria:**

- Given a principal holding the Web applications screen's own two pairs and **not** `%All`, when it confirms an enable plus a `%Development` grant on `/csp/myapp`, then the write succeeds and the ledger row records the pairs actually exercised, each once.
- Given a confirmed write, when the vendor PUT is issued, then its body is the complete merged property set read fresh at proposal time with the diff applied - not the two changed fields - and a test proves every unchanged property survives the round trip.
- Given the smoke script run twice against a container whose install created `/csp/myapp`, when each run finishes, then `agentwrite` and `auditmarker` both executed and passed, `executed=` rose by two against the run before this story, and the fixture is disabled with no resource afterwards.
- Given the same script on a container with no demo fixture, when it finishes, then both checks read `skipped` with the reason naming the absent fixture, no check reads `pending`, and the verdict is unchanged.
- Given the audit screen reached by an agent navigation carrying the marker criterion, when it arrives, then the marker filter is on, the screen has run its declared read, and the `AgentWrite` row for that proposal is rendered under the confirming user's own name.
- Given an agent navigation naming a criterion the target descriptor does not declare, when the directive is resolved, then it is refused with `NAV.CRITERIONUNKNOWN` and no arrival is announced.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6), checked against each Rule's own text.** **AD-8** is this story's own: privilege is the process's, checked at call time, and the descriptor declares a **set of pairs**; DW-1208 is that Rule applied to a permission the resource model does not carry. **AD-29**'s "`ResourcesOR()` is a lower bound, established two ways together" is why the pair is read off the vendor's own check rather than guessed. **AD-4** (read fresh, apply the diff, send the complete property set - `WebApp.App` is not one of the 19 merging `RunPut`s to be assumed about), **AD-3** (the field list is derived and each field carries a reviewed `ordinary`/`secret`/`opaque` entry; an unclassified field is **secret**, which is the fail-closed rule the unchanged rows inherit), **AD-6** (the instance mints; the confirm channel is closed; the fingerprint covers the whole payload), **AD-34** and **AD-40** (every gate inside the one transition, confirm reachable only from the browser), **AD-10** (the prohibited set has one home and is evaluated against live state inside that transition), **AD-15** and **AD-45** (the marker, and the one smoke path that names a confirmed agent write **and** its marker - DW-1382 is that Rule unmet), **AD-25** (the `/csp/myapp` fixture is opt-in, created only when absent, never modified if pre-existing - which is why the smoke restores it), **AD-11** rule 3 and **AD-21** (a navigation is an announced proposal of a route, and no caller value reaches a read - so the criterion is **named**, never valued, by the caller), **AD-13** as amended and **AD-14** (the scoped triple, the closed action, screens re-fetch), **AD-12/AD-39** (one envelope, two renderings; `NAV.CRITERIONUNKNOWN` joins a closed family), **AD-36**, **AD-19**, **AD-5**, **AD-30**, **AD-35**, **AD-41**, **AD-44**, **AD-46**, **AD-47** all hold unchanged. **AD-43 is the halt** - see `## Auto Run Result`.

**Why masking, not withholding (DW-1223).** The ledger entry says to exclude secret-typed fields, and there are two readings: drop the field, or disclose the field and withhold the value. The published copy selects the second. EXPERIENCE.md:470 reads "the unchanged fields that the payload still sends, collapsed under the disclosure 'N unchanged fields' (**every field stays available**, FR-17)", and EXPERIENCE.md:415 reads "Secret values render as '••••••••' on both sides". Masking therefore keeps three things true at once that withholding cannot: the caption's number equals the rows behind it, every field stays available, and no secret value reaches the wire. It also leaves `UnchangedCount`'s computation untouched, so no stored column changes meaning and the `SCHEMAVERSION` question does not arise. The masking happens on the **instance**, in `WireRow`, so the value never travels rather than travelling and being hidden.

**Why the rows cost no second read.** `RowValues` (`Propose.cls:571-606`) already materializes `payload` and `diff` in the same read the wire row is built from, so the rows are a projection of data in hand. `unchangedCount` stays a pass-through of the stored integer; the new invariant is that the projection's length equals it, which is a falsifiable pin rather than two independent computations.

**Why the navigation criterion is named and not valued.** `AuditList.cls:152` declares the marker as `{param, value, labelKey}` - a flag whose value is the descriptor's. A caller that supplied a value would be a caller value reaching a read, which AD-21 forbids; naming a declared flag is the same shape the route argument already has (an enum of built routes). `withQuery` (`navigation.ts:531-543`) deliberately carries only `ns`, and its own comment says why, so the criterion travels on the directive rather than the URL and that comment stays true.

**What is model prose and what is published copy.** "The agent states what it verified and ends 'Shall I show you the audit entry?'" is not assertable against model-authored text, so it is met the way 5.6 and 5.7 met the same shape: one published sentence the panel appends, idempotently, through the existing appender chain (`panel.ts:791-798`). "Answering yes navigates" is likewise the model choosing to call `shell.screen.open`; what this story makes deterministic and falsifiable is that the sentence is there and that the tool call, when made with the marker criterion, lands on the filtered screen with the event rendered.

**The refused-confirm card refines a 5.6 pin, it does not loosen it.** `panel.spec.ts:3130-3157` asserts zero tool-call cards on a live-row refusal because `recordWriteCard` produced none. AC4 names one (`failed - <resource>`, which is `toolCallStatusFailed`'s published shape), and the epic context says a reachable refusal renders through that string on the card that was refused. The proposal card's DW-1348 refusal banner stays: the banner is the reason the row is still live, the tool-call card is the record that the write was attempted and failed.

**DW-1252's code half already landed.** The same defect was filed twice - from spec 5.5 as DW-1348 and from spec 5.3 as DW-1252 - and 5.6 closed DW-1348 (`deferred-work.md`: `resolved-by:5-6-...`). The residual this story closes is that the refusal had never been driven against a real instance and had no tool-call card; AC4's browser leg and task 11 are DW-1252's disposition, and the ledger entry closes `resolved-by` this story rather than being declined.

**The smoke check's scope wall.** `Smoke.cls:25-27` states it cannot depend on `OcuPilot.Test.*`. `Test/AuditMarker.cls:154-192` is the worked sequence, and the only two things it took from `Test/` are the turn row (`Kernel/State/Turn.GuardedReserve` + `GuardedBegin` + `GuardedFinish` are the shipped substitutes) and the write target (AD-25's `/csp/myapp` is the shipped one). `AuditMarker` already stores an empty conversation key, so the conversation is not a prerequisite; verify the same of the definition id against the throwaway before building on it. The write **mutates** the instance, which no other smoke check does, so the restore is not tidiness: without it a second run finds `/csp/myapp` enabled with a resource, which contradicts `Fixture.cls`'s own created-state contract and AD-25's "never modifies one it did not create".

**The measured 44, and the published 38.** EXPERIENCE.md:756 names "38 unchanged fields" among "the values that make this demo concrete". `WebApp.App` `GET` answers **46** top-level properties (measured on `ocupilot-slot-a`, 2026-09-20), so a two-field change leaves 44. The number is corrected at its origin (task 21) rather than left to be mined as evidence later; the empty-state example card derives from that same line and follows it, and its seven-key shape (`example-proposal.test.mjs:154`) is untouched.

**Integration ACs (Rule 1).** Two, both at the browser tier against observable DOM: the Web applications list consumes the confirmed write's `changed` event and shows `Enabled Yes` with `%Development` on the re-fetched row inside the budget; and the Audit database screen consumes the navigation criterion and renders the `AgentWrite` row for that proposal under the confirming user's name.

**Consumes:** `Kernel.Proposal.Mint`, `Confirm` and `Kernel.State.Propose` (5.1, 5.3); `Kernel.Proposal.Prohibited` (5.5); `Kernel.Audit.Event`'s `AgentWrite` triple and the ledger (5.6); `core/change-bus.ts`, `core/refresh.ts`, `shell/data-table.ts`'s `viewKeyFor` and the toast (5.7); `Screen/Tool/ToolFields` and `Classification` (2.2); `Screen/Descriptor/AuditList` and `areas/logs/audit.*` (2.10); `Screen/Tool/Navigate` and `shell/agent-navigator.ts` (4.7); `Install/Fixture`'s `/csp/myapp` (1.4, AD-25); `Install/Smoke` (1.17).

**Consumed-by:** Stories 5.9-5.13, each of which is this story's shape in another area - the unchanged rows, the refused-confirm card and the audit hand-off are built once here and only pinned there; 5.10, whose destructive disable-auditing card renders the same disclosure; 5.11, whose navigation target is the Task schedule list and which inherits the criterion argument; Story 7.4's Auditing screen, which calls the same operation; every later `%Admin_*` write tool, which takes DW-1208's `USE` rule as standing.

**Footprint.** In-epic throughout, plus three files no contended epic owns and which are reported under `footprint_extensions:` at the commit: `src/OcuPilot/Install/Smoke.cls`, `scripts` are untouched but `ui/tools/ci.test.mjs` is edited for the demo-flag pin, and `EXPERIENCE.md`'s UJ-3 paragraph is amended in place - the narrow in-place allowance the owner granted, since that line is itself the subject of the fix; its Fixed-strings rows still go at the **tail**. `ui/src/styles/**` is contended and is not edited.

**Ledger inbox (Rule 17).** DW-1208 addressed by tasks 1-4 and the first AC. DW-1223 by tasks 5-10 and two matrix rows. DW-1252 by tasks 11-12 and the refusal matrix row plus AC4's browser leg. DW-1382 by tasks 17-19 and two matrix rows plus two ACs. None declined.

## Verification

**Targeted -- run these inside the implement loop (Rule 29).**

- `(loop)` `uv run scripts/check-objectscript.py src/OcuPilot/Screen/Tool/WebAppUpdate.cls src/OcuPilot/Kernel/State/Propose.cls src/OcuPilot/Screen/Tool/Navigate.cls src/OcuPilot/Install/Smoke.cls src/OcuPilot/Api/Error.cls` -- expected: clean.
- `(loop)` `cd ui && npm run test:tools` -- expected: green, including `proposal.test.mjs`, `proposal-view.test.mjs`, `turn.test.mjs`, `example-proposal.test.mjs`, `ci.test.mjs` and `strings.test.mjs`.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `proposal-card.spec.ts`, `panel.spec.ts`, `audit.page.spec.ts` and `agent-navigator.spec.ts`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <one class>` -- one class per call, landed in `%UnitTest_Result` before the next, never two test calls in one message: `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.ToolEmit`, `OcuPilot.Test.ProposalConfirm`, the `WireRow` class, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.Smoke`, `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.Navigate`.
- `(loop)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: PASSED, `executed=` up by two and `pending=` down by two against the pre-story run; read the skip lines, not the number (DW-1402). Run it twice and confirm the second is identical.
- `(loop)` the browser legs, bundle redeployed first or the spec reads the old bundle:

  ```bash
  cd ui && npm run build \
    && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ \
    && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci \
       node --test --test-concurrency=1 browser/proposal-demo.browser-spec.mjs \
                                        browser/proposal-confirm.browser-spec.mjs \
                                        browser/audit.browser-spec.mjs
  ```

  -- expected: green, the budget assertion reporting its measured elapsed time.

**Full -- run these once, at the end of the implement stage, before `dev_complete` (Rule 29).**

- `(once, before dev_complete)` `cd ui && npm run build && npm test` -- the six prebuild checkers and both client tiers.
- `(once, before dev_complete)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` -- the whole browser suite.
- `(once, before dev_complete)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci` -- the full ObjectScript sweep.
- `(once, before dev_complete)` `bash scripts/lint-docs.sh` -- expected: 0 issues.

**Rule 19 mutations** -- one per AC, each applied, observed red, reverted, with `git status --short` and `git diff --stat` unchanged afterwards; the ObjectScript ones run on `ocupilot-ci`, never the shared dev instance (DW-1185), and every client mutation whose subject is a browser spec is rebuilt and redeployed before the run.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**The gap.** Story 5.8's first acceptance criterion ends "**And** the list's auto-refresh chip reads
paused" (`epics.md:3607`). The Web applications list has no auto-refresh chip and cannot be given one
by this story.

**Evidence, three independent sources.** **AD-43**'s Rule reads: "The set is seven, and
EXPERIENCE.md's Auto-refresh controls row is the roster: Processes, Process details, Databases,
Database details, Task schedule, Task details, System usage... A screen joins the set by declaring it
in its descriptor and appearing in that roster, never by either alone." That roster
(`EXPERIENCE.md:645`) names those seven and not the Web applications list.
`src/OcuPilot/Screen/Descriptor/WebAppList.cls:48-49` declares `"refreshes": false` with
`"refreshRates": []`, and its own header at `:33` says "it does not refresh (AD-43)". Story 5.7's
spec recorded the same finding from the other side: "The seven auto-refreshing screens declare
`database`, `process`, `task` and `''` -- checked on all seven descriptors, not one -- and the only
registered write tool is `webapp.list.update` over `web-application`. **No live proposal reachable
today can pause an auto-refreshing screen**... Stories 5.11 and 5.12 are the first that could raise
it to the browser."

**Why it is not planned around.** There is no reading on which a chip that does not exist reads
paused. Giving the Web applications list a chip would add an eighth member to AD-43's set, which that
AD's Rule reserves to a change in the descriptor **and** the published roster together - a
re-architecture, not a slice call - for a screen whose data is static configuration and whose classic
page does not refresh. Rule 6 makes an AC that contradicts an AD's Rule an intent-gap halt.

**Recommended amendment (the lead's call, Rule 5 "ask first" tier - it drops an AC clause).** Delete
the clause "**And** the list's auto-refresh chip reads paused" from Story 5.8's first acceptance
criterion in `epics.md:3607`, and record in its place that the Web applications list does not
auto-refresh per AD-43's roster, so the proposal pause has no chip on this screen; the pause itself is
already pinned at the tools tier by Story 5.7 (`ui/tools/refresh.test.mjs:502-661`) and reaches the
browser at Story 5.11 (Task schedule) and Story 5.12 (Processes), both of which are in the roster. The
product promise is unchanged - nothing on this screen moves under the diff, which is the reason the
pause exists. The alternative, amending AD-43's count and `EXPERIENCE.md:645`'s roster to admit an
eighth screen, is a spine change under Rule 20 and is not recommended: it would add a timer to a
screen nobody asked to refresh in order to satisfy one clause.

**Everything else is planned and ready.** The rest of this spec is complete against the
READY-FOR-DEVELOPMENT standard: five ACs, four ledger entries addressed, the Code Map drained from
five parallel investigations, and the Rule 29 verification shape. The one clause above is isolated to
the first matrix row group and AC1; amending `epics.md` and resetting this spec's `status` to `draft`
re-plans it in one pass with the `<intent-contract>` block preserved verbatim.

**Two further findings the amendment pass should carry, neither a halt.** `epics.md:3612`'s "the same
endpoint the screen's editor uses" reads as the screen's own declared endpoint `WebApp.App`, since the
Web applications list declares no primary or row action and the editor in question is the classic
portal's - stated here so it is not re-derived. And `epics.md:3624`'s "was never advertised as a tool"
is satisfied by there being no delete verb for web applications at all, not by hiding a tool from a
caller, which AD-8 forbids.
