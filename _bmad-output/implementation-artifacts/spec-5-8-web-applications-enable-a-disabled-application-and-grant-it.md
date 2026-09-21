---
title: 'Story 5.8: Web applications - enable a disabled application and grant it a resource'
type: 'feature'
created: '2026-09-20'
status: 'done'
baseline_revision: 'b92c9326421f84ab65111df4550c72239c44028e'
baseline_commit: 'b92c932'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The demo card discloses the target's own Name as the secret mask, because
      webapp.list.update's generated field list carries no row for it.
    evidence: |-
      Measured in the checkout: src/OcuPilot/Screen/Tool/ToolFields.cls declares 47 rows for
      webapp.list.update, 45 of them ordinary+literal top level, and Name is not among them; a
      WebApp.App GET answers 46 keys. So on UJ-3's own card Name reads as eight bullets under the
      disclosure while the card header shows /csp/myapp in clear. This is AD-3's fail-closed rule
      applied exactly as this spec's matrix requires, so it is spec-bound rather than a code
      defect - but it makes an unclassified field indistinguishable from a real secret on the one
      card the demo is built around. Settling it is a choice between classifying Name in Story
      2.2's derivation and excluding the id field from the disclosure.
    location: >-
      src/OcuPilot/Screen/Tool/ToolFields.cls (webapp.list.update rows)
    severity: low
  - summary: >-
      The disclosure's rows are unbounded in total size and are re-projected on every poll of a
      live proposal.
    evidence: |-
      Kernel/Proposal/Disclosure.Rows renders each value verbatim through Mint.Display, so a
      proposal now carries ~44 field values on each once-a-second poll where the diff carried two;
      a long Description or a large CorsAllowlist travels every time. OrdinaryPaths also opens
      %Dictionary.XDataDefinition for ToolFields on every WireRow. AD-24's per-field bound covers
      context and tool results, not the proposal wire, so no existing limit applies. Applying
      Limits.FIELDMAXLENGTH to each disclosed value would bound it, but truncating a disclosed
      value changes what the card shows and this spec does not settle that.
    location: >-
      src/OcuPilot/Kernel/Proposal/Disclosure.cls:63
    severity: medium
  - summary: >-
      OcuPilot.Port.AdminPort.Invoke silently no-ops on a %String body for a mutating type.
    evidence: |-
      Measured both ways on ocupilot-ci during this story: its signature says
      %DynamicAbstractObject, ObjectScript does not enforce method-argument types, and the vendor's
      MergeJsonAndProperties reads a string as carrying no properties - so a WebApp.App PUT given
      JSON text answers HTTP 200 with the target's unchanged object and writes nothing. Nothing
      refuses it, and the caller cannot tell the write from a no-op. Refusing a non-object pBody for
      a mutating type would close it.
    location: >-
      src/OcuPilot/Port/AdminPort.cls:359
    severity: medium
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
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls:50` the screen's declared pairs, read this pass: `[{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}]` - **the write's resolved set is exactly this pair set, not merely a satisfiable one**; `:48-49` **`"refreshes": false`**, `"refreshRates": []`; `:57-58` `primaryAction`/`rowActions` both empty; `:64` `classicPage = "%CSP.UI.Portal.Applications.WebList"`; `:66-72` the declared read (`WebApp.App` `LIST`, six fields, `paging: "cap"`); `:73-84` the table columns.
- `src/OcuPilot/Screen/Gate.cls:42-45` `ADMINPERMISSION = "USE"` for all thirteen `%Admin_*` resources - the vocabulary DW-1208 rests on; `:106-122` `RequiredPairs`; `:132-168` `EvaluatePairs`/`EvaluateRequired`; `:227-248` `ParsePairSpec`; `:262-265` `HoldsPrivilege`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:198-390` `Transition` - gate order tool `:203`, secrets `:211`, **prohibited `:219`**, restraint `:235`, **pairs `:250-261`** (`MissingPair` -> `Refuse(403, AUTHNOPRIVILEGE, detail.failedPair)`), conversation `:265`, definition version `:279`, fingerprint `:292`, claim `:315`, **vendor PUT `:345`**, marker `:371`, ledger finalize `:373`; `:42` `WRITETYPE = "PUT"`; `:616-625` `HoldsPair` (`$SYSTEM.Security.CheckUserPermission`, overridable - the fixture's seam).
- `src/OcuPilot/Api/Error.cls:111,118` `AUTH.NOPRIVILEGE` and its reason; `src/OcuPilot/Api/Confirm.cls:81-116` `RenderRefusal` and the reason lookup.
- Tests that turn red on the literal, each re-read this pass: `src/OcuPilot/Test/ToolWrite.cls:214` asserts `tSpelled [ "%Admin_Secure:WRITE"` inside `TestThePairsAddTheWritePermission` (`:203-215`), whose name and `:203` doc both become wrong; `src/OcuPilot/Test/ProposalConfirm.cls:34` `DENIEDPAIR = "%Admin_Secure:WRITE"`, denied at `:240` and asserted at `:248` (`tDetail.%Get("failedPair")`) - **re-point it, do not merely update it: a `DENIEDPAIR` the tool no longer requires makes `MissingPair` return nothing and `:248` pass vacuously**; `src/OcuPilot/Test/ToolEmit.cls:186` derives from the two parameters (follows the change) but `:181-183`'s "the addition is the point" doc becomes false; `src/OcuPilot/Test/ToolDispatch.cls:448,455` hold the literal as synthetic envelope data only.
- Read-only evidence: `src/OcuPilot/Test/SurfaceCoverage.cls` and `Test/EndpointCoverage.cls` pin **no pair**, and neither holds a remaining "assert the zero" tripwire - Story 5.5 tripped the write-half one (`SurfaceCoverage.cls:93` row, `:281` `tDerived > 0`). Their stale doc comments at `SurfaceCoverage.cls:260-268` and `:284-286` still describe the deleted zero.

### The prohibited set (AC5) - already covers this story, pinned not built

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:69` `COVEREDTYPES = "web-application"`; `:134-138` `PermittedChangeFields` (the same four, kept equal to `PERMITTEDFIELDS` by the suite); `:146-150` `AlwaysProhibitedFields` (`MatchRoles`, `DispatchClass`); `:261-306` `WebApplication` - `:270` serving-path refusal via `ServesOcuPilot` (`:401-425`, reading `Install/Roster.cls:108,122,140`), `:278` **`Resource` refused only when the new value is empty**, `:286` `MatchRoles` -> `PRIVILEGEGRANT`, `:290-299` the uncovered-field sweep; `:317-340` `Changed`. So enable (`0->1`) and a resource **grant** are permitted today and need no kernel change; clearing the resource is the refusal, and it is a cheap second leg on the same fixture.

### The card (DW-1223, AC1)

- `src/OcuPilot/Kernel/State/Propose.cls:88-90` **`Payload`** ("the complete merged body the write will send"); `:92-97` `Diff` and `UnchangedCount`; `:99-105` `Rationale`/`ExpectedImpact`/`Reverse`; `:571-606` `RowValues` - **already reads `payload`, `diff` and `targetRef` into `pValues` in the same read**, so rows cost no second read; `:613-636` `WireRow`, the 11 keys, `unchangedCount` a pass-through at `:626`; **`:489-490` and `:610-612` assert the payload's absence from the wire as an invariant - rewrite both at their origin, do not append.**
- `src/OcuPilot/Kernel/Proposal/Mint.cls:113-121` and `:226-292` `Merge` - `tTotal` counts **top-level** payload properties, `pUnchanged = tTotal - tChanged` (`:284`), a no-op argument yields no diff row; `:384-390` `Display`, the shared renderer (empty -> `""`, boolean -> `true`/`false`, object/array -> compact JSON); `:123-127` `Fingerprint.Of` with `FingerprintExcludes`; `:140-142` `TextArgument` for the three agent sentences.
- `src/OcuPilot/Screen/Tool/ToolFields.cls` (generated) - the per-path `class` (`ordinary`/`secret`/`opaque`) keyed by tool name; `webapp.list.update`'s only `secret` rows are `MatchRoles[].MatchRole` and `MatchRoles[].TargetRoles[]` (`:38-39`). Readers to reuse rather than rewrite: `Screen/Tool/Write.cls:111-155` `FieldRows` and `Screen/Registry.cls:2139-2160` `ToolFieldRows` ("an unreadable field list is not a negative result"). Grammar and the fail-closed rule: `Screen/Tool/Classification.cls:1-18`.
- `src/OcuPilot/Screen/Tool/Write.cls:199-201` where `rationale`, `expectedImpact` and `reverse` are declared as **model-authored optional string arguments** under `additionalProperties: false`; `:210-219` their absence from the result schema.
- `ui/src/app/core/proposal-view.ts:59-65` **`ProposalCardView.unchanged` already declared and unsupplied**; `:262-283` `toCardView` - **does not pass `unchanged` through**; `:29-33` `ProposalDiffRow`; `:240-245` `MASKED_VALUE`/`maskedRow`; `:212-234` `statusLineFor`; `:44` and `:272` the card's target name, which is `proposal.target.id` off the wire.
- `ui/src/app/shell/proposal-card.ts:93-106` the changed rows; `:107-132` **the `aria-expanded` disclosure, already built and already spec-covered** (`<button>` iff rows exist, `<p>` otherwise); `:119-124` the unchanged row, which renders field + value and **no direction word**; `:135-149` rationale, expected impact and `Reverse:`; `:175-184` the DW-1348 refusal banner (`data-slot="refusal"`, live only); `:377-407` the row getters and `unchangedCaption`.
- `ui/src/app/core/strings.ts` - present: `:165` `proposalUnchangedFieldsDisclosure`, `:135/:137/:139` the three labels, `:320` `tableEmptyValue: '(none)'`, `:184` `toolCallStatusFailed: 'failed - <reason>'`, `:153-163` the status lines. **Absent: a visually hidden "unchanged" direction word (`EXPERIENCE.md:415` publishes it - unchanged rows read "<field>: <value>, unchanged") and the audit-entry offer sentence.**
- `ui/tools/proposal.test.mjs:413-445` the AD-6 literal-authoring gate - its `authoring` alternation names `before|after|unchangedCount|rationale|expectedImpact|reverse|fingerprint|auditWarning`; **a new wire field belongs in that alternation** or the gate stops covering the whole proposal shape. `ui/tools/example-proposal.test.mjs:83-127` derives the example's count from `EXPERIENCE.md`'s UJ-3 step and `:154` pins `EXAMPLE_PROPOSAL`'s key set to exactly seven keys - **read-only here; the empty-state example stays non-interactive**.
- `ui/src/app/shell/proposal-card.spec.ts:110-133` the changed rows, `:134-140` the caption, `:141-166` **the whole disclosure, already asserted against supplied rows**, `:489-533` the DW-1348 refusal banner.

### The refusal surface (DW-1426, AC4)

- `ui/src/app/shell/panel.ts:991-1008` `onCardConfirm`; **`:1012-1018` `recordWriteCard` opens `if (outcome === null || !outcome.ok) return;` under a doc comment that reads "A refusal records nothing: there is no write to show a card for" - that sentence is the defect and is rewritten at its origin**; `:813-829` `proposalView` (`:824` reads `turn.proposalRefusal(id)?.reason` into `toCardView`'s fourth argument); `:836-857` `phaseFor`; `:859-867`/`:881-894`/`:924-933` the three published reply-sentence appenders and `:791-798` where they compose - **AC3's fourth appender follows that template**; `:907-914` `writeSteps`.
- `ui/src/app/core/turn.ts:247-266` `ProposalOutcome` (`ok, state, closedReason, confirmedAt, status, code, reason, auditMarked`); `:926-994` `decideProposal` - `:967-993` the refusal branch, which already records `{status, code, reason}` per proposal (`:725-735` `recordProposalRefusal`, `:720-722` the reader); `:516-535` `confirmedWriteStep`, the shape a refused write card mirrors; `:216-220` `TurnNavigation` (`seq`, `route`, `entityId` - **no criterion**).
- `ui/src/app/shell/tool-call-card.ts:111-117` `toolCallStatusFailed`, whose detail is `step.failedPair` if non-empty else `step.reason`; `:121-124` the three audit-marker words.
- `ui/src/app/shell/panel.spec.ts:3130-3157` - the Story 5.6 pin this story's AC4 refines. Its last line is `expect(host.querySelectorAll('app-tool-call-card')).toHaveLength(0);` under the comment "No card was appended for a write that never happened", and its own `mutation:` line (`:3134-3137`) is about `recordProposalRefusal`, not about the card count - so the refinement changes the count assertion and leaves the reason assertions and that mutation line intact; `:3162-3234` the write card and the marker sentence; `ui/tools/turn.test.mjs:1270-1303` the DW-1348 per-proposal refusal record.

### The audit hand-off (AC3)

- `src/OcuPilot/Screen/Tool/Navigate.cls:25-31` `shell.screen.open`, `KIND = "read"`, **`FULFILMENT = "client"`**; `:43-59` `BuiltRoutes()`; **`:64-87` `InputSchema` - `route` (enum, required) and `entityId` only, `additionalProperties: false`**; `:100-113` `ResultSchema`; `:158-...` `Directive` and its refusals (`NAV.ROUTEUNKNOWN`, `NAV.ENTITYNOTALLOWED`). Its test class is `src/OcuPilot/Test/ToolNavigate.cls` (with `Test/TurnNavigate.cls` and `Test/Navigation.cls` on the turn and client sides).
- `src/OcuPilot/Screen/Descriptor/AuditList.cls:113` route `logs/audit`; `:117` archetype `list (server criteria)`; `:126` **composite id, so `entityId` on this route is refused** - AC3's event is reached by the filter, not by selecting a row; `:141-151` the nine criteria; **`:152` the declared marker criterion `{"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}` - a flag criterion whose value is the descriptor's own**; pinned at `Test/Descriptor.cls:503` and `Test/CriteriaCorpus.cls:39,49,79-81`.
- `ui/src/app/areas/logs/audit.store.ts:26` `AuditSearch`; `:88-96` `marker()`/`setMarker()` - **one caller only, the checkbox**; `:99-105` `searched()`/`noteSearched()` - **the archetype renders nothing until this is set**; `:145-153` `criteria()`, where the marker **overrides** `eventSources` rather than merging; `:158-161` `overriddenByMarker`.
- `ui/src/app/areas/logs/audit.page.ts:107-116` the checkbox (`data-ocu-marker="filter"`); `:297-299` `onMarker`.
- `ui/src/app/shell/agent-navigator.ts:11-18` the announce-first delay; `:93-94` the target build and `withQuery`; `:95-102` the arrival announcement; `:104` the guard decline.
- `ui/src/app/core/navigation.ts:531-543` **`withQuery` carries only `ns`, by documented intent** - the criterion travels on the directive, never as a query parameter.
- `src/OcuPilot/Api/Turn.cls:286,349-384` the closed navigation-answer vocabulary; `src/OcuPilot/Api/Error.cls:734-759` the closed `NAV.*` code family, which a new refusal joins; `src/OcuPilot/Kernel/Agent/Dispatch.cls:402,582-592` the directive and `SettleClient`.

### The smoke path (DW-1382)

- `src/OcuPilot/Install/Smoke.cls:25-27` **"`OcuPilot.Test.Http` is test-scope: it does not ship, so this class cannot depend on it"** - the scope wall; `:212-250` `Run` and its three frames; `:289-295` `Note` (name/outcome/reason); `:300-338` the one HTTP seam; `:462-502` `CheckSignIn`, which mints a real token pair for `--user`; `:1041-1090` `CheckAuditEvent`, which sweeps `Audit/Event.Names()` and therefore already covers the `AgentWrite` triple (`skipped`, not `fail`, on a partial roster - `:1089`); `:1153-1172` `CheckDemoFixture`; **`:1177-1181` `AddPending`, whose two `Note(..., "pending", "... -- Epic 3")` lines are the entries to replace**; `:1189-1223` `Render` (`executed = pass + fail`, verdict `executed > 0 && fail = 0`).
- `scripts/smoke.sh:50-63` the flags, `:127-137` `--demo` resolved from `/proc/1/environ`, `:156-163` the invocation, `:189-196` the failing-check names read positionally out of `Render`'s fixed-width lines - **no check name appears in the shell script**.
- `src/OcuPilot/Install/Fixture.cls:69` `APPPATH = "/csp/myapp"`; `:262-315` `CreateWebApp` - `:294-298` the created state (`Type` 2, **`Enabled` 0, no `Resource` key**); `:265-293` the absent-only guard and the pre-existing-application warning; `:224-234` `WebAppOwnedByProfile`, the ownership read the restore must use.
- Shipped seams the check can compose (no `Test/` class): `Kernel/State/Turn.cls:150` `GuardedReserve`, `:250` `GuardedBegin`, `:324` `GuardedFinish`; `Kernel/Proposal/Mint.cls` and `Kernel/State/Propose.cls:183` `GuardedMint`; `Kernel/Proposal/Confirm.cls:104` `Confirm`; `Kernel/Audit/Event.cls:38,243,272` the `AgentWrite` triple and its emitter. `src/OcuPilot/Test/AuditMarker.cls:154-192` is the worked precedent for the whole sequence - it needed `Test/` only for the turn row (raw SQL) and the probe application, both of which have shipped substitutes here.
- `scripts/ci-throwaway.sh:171` **`OCUPILOT_DEMO: "1"`** (so the `instance` job's `/csp/myapp` exists) and `:172-242` the seven arming rosters, held equal in both directions by `ui/tools/ci.test.mjs:1731-1761`. `docker-compose.yml:25-29` the same flag, pinned by `ui/tools/compose.test.mjs:71-73`. **`scripts/ci-ipm-archive.sh:389` starts its container with no environment at all, and `:442-456` runs smoke there** - that is the container on which both new checks must read `skipped`. `ui/tools/ci.test.mjs:1548-1586` compares compose keys but **not** the `environment:` block, so `ci-throwaway.sh`'s demo flag is pinned by nothing.
- `.github/workflows/ci.yml:144-145` `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, after `ci-runner.mjs` and before the browser leg.

### Case-preserved spellings - the 5.7 sharp edge, and where it bites here

- `src/OcuPilot/Kernel/State/Propose.cls:615-618` **`WireRow` parses the stored `targetRef`**, which `Mint.cls:89,134` wrote through `EntityRef.Key` - so the card's target name (`proposal-view.ts:44,272`) is the **folded** spelling, by construction. This story neither relies on that nor changes it; any read-back it adds must take the spelling the **instance** returns, never `target.id`.
- Already pinned, do not rebuild: `src/OcuPilot/Test/ProposalSpelling.cls:297` `TestAMintOfASecondSpellingStoresTheCanonicalTarget`, `:335` `TestACanonicalIdStillAddressesAMixedCaseApplication`, `:375`/`:452`/`:527` the sibling and in-flight legs - the server-side confirm-and-write path over a mixed-case application; `ui/browser/change-highlight-noncanonical.browser-spec.mjs:54,117-134,215-265` the browser path on `/csp/OcuPilotProbeConfirmMixedCase`, whose own header (`:4-12`) states why a canonical target cannot tell the two implementations apart; `ui/src/app/shell/data-table.ts:1013` `viewKeyFor` and `:1030` `changedKeyFor`, the two reconciliation points.
- The fixture this story drives, `/csp/myapp`, is **already canonical**: folding it changes nothing, so no leg built on it is evidence about folding. The story's own new read-back is `Install/Smoke.cls`'s, and `src/OcuPilot/Test/ProposalFixture.cls:483` `WRITETARGETMIXEDCASE = "/csp/OcuPilotProbeConfirmMixedCase"` with `:492` `EnsureMixedCaseWriteTarget`, `:525` `MixedCaseWriteTargetField` and `:545` `RemoveMixedCaseWriteTarget` is the ready-made lever for pinning it at the test tier.

### The browser tier (the precedent to copy exactly)

- `ui/browser/proposal-confirm.browser-spec.mjs` - the only spec that makes a real confirmed write. `:59-76` `before`: **live-container refusal guard**, readiness gate, `requireFreeSlot`, launch, `armProbeDefinition`, **`allowWrites()` (`:99-106`, `Test.Restraint.SetDefinitionReadOnly(id, 0)` - under read-only no proposal is minted at all, AD-30)**, `ensureTarget`, `dropProposals`; `:126-131` `storedEnabled()` the instance-side witness; `:134-150` the live-proposal count and `GuardedDeleteForUser`; `:160-193` **`proposeReply` and `withLiveCard` - the arm-and-drive bracket: `nextTag` -> `setTag` -> two `scriptReply` calls (the `tool_use`, then the closing text) -> `signedInAt` -> type -> Send -> wait for the card**; `:195-257` the AC10 confirm leg and its two read-backs.
- `ui/browser/turnprobe-spec.mjs` - **how a proposal is minted with no LLM**: `OcuPilot.Test.TurnProvider` is an Anthropic adapter whose `IssueHttpsPost` answers from a script keyed by the definition's `Model` string, so the real kernel, the real dispatch and the real mint all run. Exports: `runIris`, `markerValue`, `nextTag` (`:77-82`), `ensureDefinition`, `setTag` (`:132-139`), **`scriptReply` (`:151-158`)**, `forgetTag`, `armProbeDefinition` (`:171-176`), `disarmProbeDefinition`, `abandonTurns`, **`requireFreeSlot` (`:231-245`, needed before every Send)**. Reply builders: `src/OcuPilot/Test/TurnProvider.cls:38` `Script`, `:72` `TextReply`, `:84` `ToolUseReply`.
- `ui/browser/panel-spec.mjs:60-75` `signedInAt`, `:91-101` `saveAndSettle` (DW-1169).
- `ui/browser/change-highlight.browser-spec.mjs:61-70` `HIGHLIGHT_BUDGET_MS = 2000` with `HIGHLIGHT_WAIT_MS = BUDGET * 5` and the doc naming `data-table.browser-spec.mjs:141-151` as the mistake not to copy; `:190-208` `listWithLiveCard`, which signs in **on the list** so the highlight is observable; `:309-347` the `Date.now()` bracket and the elapsed log on a green run.
- `ui/browser/audit.browser-spec.mjs:292-311` `signedInAtScreen` with its `/api/ocupilot/screens/` request collector; `:546-614` **the agent-marker filter leg, which already asserts the override in both directions**; `:83-90`/`:733-767` the `FIRST_ROW_BUDGET_MS` bracket.
- `ui/browser/refused-tool.browser-spec.mjs:48-82` a **real least-privileged principal** built from `Test.TurnWireFixture.Resources(1)`, which deliberately omits `%Admin_Secure` and verifies the missing pair on the instance before driving the turn - **the ready-made lever for AC4's denied confirm**; `:145-156` the "exactly two provider calls, so no retry path exists" assertion.
- `src/OcuPilot/Test/ProposalFixture.cls:111-124` `DenyPair`/`DeniedPair` (the `HoldsPair` seam); `:373-377` the canonical write target and its marker; `:396-475` `EnsureWriteTarget`/`WriteTargetField`/`RemoveWriteTarget` with their two guards (`OCUPILOT_ALLOW_PRINCIPALS` and "will not adopt one it did not make"); `:483-567` the mixed-case trio.
- `ui/browser.config.mjs:24,42,45` `DEFAULT_ORIGIN`, `DEFAULT_CONTAINER = 'ocupilot-ci'`, `LIVE_CONTAINER = 'ocupilot'`; `:60-88` the origin/container cross-check; `:85-86` viewport 1440x900 and the 30 s navigation timeout.
- `ui/package.json:6-18` the scripts: `prebuild`'s six checkers, `test:tools`, `test:components`, `test:browser` (`node --test --test-concurrency=1 browser/*.browser-spec.mjs`). `ui/tools/ci-runner.mjs:38-39,359-380` its flags (`--container` required, repeatable `--class`).

### Measured, not recalled

- **The population is the top-level property count of a `WebApp.App` `GET`.** On `ocupilot-slot-a`, through the shipped port (`OcuPilot.Port.AdminPort.Invoke("WebApp.App", "GET", ...)`, `%Size()` on the answer): `/api/ocupilot` answers **46** (2026-09-20) and `/csp/user` answers **46** (2026-09-21) - a REST application and a CSP application, so the count is not one probe generalized. A two-field change therefore leaves `unchangedCount` at **44**, not the 38 `EXPERIENCE.md:756` names.
- `/csp/myapp` does **not** exist on `ocupilot-slot-a` (that container carries no `OCUPILOT_DEMO`; the `GET` answers 404), so the demo's own target is measured on the throwaway at implement time and the number written into `EXPERIENCE.md` is that measurement, with its population named in the same sentence. 44 is the expected value, not an assumed one.

## Tasks & Acceptance

### Execution

1. `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- set `WRITEPERMISSION` to `"USE"`, replace the `:53-54` doc sentence with what the pair now is and why (it is exactly what `%CSP.Portal.Application.CheckSecurity` checks, and exactly the pair set `WebAppList.cls:50` already declares), and make `PrivilegePairs()` emit each pair once -- so the resolved set is the screen's two pairs and the ledger's pair column carries no duplicate. (DW-1208)
2. `src/OcuPilot/Test/ToolWrite.cls` -- re-point `:203-215` at the new pair set: the assertion becomes that the resolved set is exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, each once, and that no pair carries a permission no shipped role grants. Rename the method and rewrite its doc to match; check no coverage roster names the old name. (DW-1208)
3. `src/OcuPilot/Test/ProposalConfirm.cls` -- change `DENIEDPAIR` to a pair the tool actually requires, so `MissingPair` still has something to fail on and `:248` still tests the naming rather than passing vacuously. (DW-1208)
4. `src/OcuPilot/Test/ToolEmit.cls` -- rewrite the `:181-183` doc: the write tool's set is the screen's set, and the barrier a write crosses beyond a read is the confirm transition, not a privilege delta. (DW-1208)
5. `src/OcuPilot/Kernel/State/Propose.cls` -- add `unchanged[]` of `{field, value}` to `WireRow`, built from `pValues("payload")` minus the changed field names, each value rendered by `Mint.Display`, and every path that is not `ordinary` + literal in `ToolFields` -- including any with no row at all -- carrying the published mask instead of its value. Its length must equal `unchangedCount`. Replace the `:489-490` and `:610-612` "not on the wire at all" sentences with the new rule at their origin. (DW-1223)
6. `src/OcuPilot/Test/ProposalWire.cls` -- pin the three properties: rows equal the payload's top-level properties minus the changed ones, `$ListLength` equals `unchangedCount`, and `MatchRoles` plus any unclassified property arrive masked with no raw value anywhere in the wire row. (DW-1223)
7. `ui/src/app/core/turn.ts` -- parse `unchanged[]` off the wire beside `changed`, authoring no value. (DW-1223)
8. `ui/src/app/core/proposal-view.ts` -- forward `unchanged` through `toCardView`, the one line that today drops it. (DW-1223)
9. `ui/src/app/shell/proposal-card.ts` -- give the unchanged row its visually hidden direction word (`EXPERIENCE.md:415`: "<field>: <value>, unchanged"), and render an empty value as `tableEmptyValue` on the changed row's before half and on an unchanged row alike, so AC1's `Resource: (none) -> %Development` reads as published.
10. `ui/src/app/core/strings.ts` + `EXPERIENCE.md`'s Fixed-strings table -- two keys at the **tail** (shared-append): the unchanged-row direction word and the audit-entry offer sentence. Reuse `tableEmptyValue` rather than adding a second key with the same value; non-ASCII authored as `\uXXXX` (Rule 14).
11. `ui/tools/proposal.test.mjs` -- add the new wire field to the `authoring` alternation at `:424`, so the AD-6 gate keeps covering the whole proposal shape.
12. `ui/src/app/shell/panel.ts` -- record a write tool-call card on a refused confirm, carrying the refusal's `failedPair` or `reason`, so `failed - <resource>` has a producer; rewrite `recordWriteCard`'s "a refusal records nothing" doc sentence at its origin; and add the fourth published reply appender for "Shall I show you the audit entry?", gated on the turn holding a confirmed write and idempotent like the other three. (DW-1426, AC3, AC4)
13. `ui/src/app/shell/panel.spec.ts` -- refine the `:3130-3157` pin: replace the "zero `app-tool-call-card`" assertion with the card AC4 names, keep the reason assertions and the existing `mutation:` line (which is about `recordProposalRefusal`, not the count), and state in the test's own name that 5.6 pinned the absence only because nothing produced one. (DW-1426)
14. `src/OcuPilot/Screen/Tool/Navigate.cls` -- add one optional `criterion` argument naming a criterion the target descriptor **declares as a flag** (value supplied by the descriptor, never by the caller); refuse anything else with a new `NAV.CRITERIONUNKNOWN` before any announcement exists. Carry it on the directive. (AC3)
15. `src/OcuPilot/Api/Error.cls` -- add `NAV.CRITERIONUNKNOWN` to the closed `NAV.*` family. (AC3)
16. `ui/src/app/core/turn.ts` + `ui/src/app/shell/agent-navigator.ts` -- carry the criterion on `TurnNavigation` and apply it on arrival through the target screen's own store seam, then run that screen's declared read, so the arriving screen shows rows rather than an unsearched form. No query parameter: `withQuery` stays `ns`-only. (AC3)
17. `ui/src/app/areas/logs/audit.store.ts` -- expose the non-interactive path the arrival uses (set the marker, note searched) beside the checkbox's, so there is one answer to "is the marker on" and not two. (AC3)
18. `src/OcuPilot/Install/Smoke.cls` -- replace `AddPending` with real `agentwrite` and `auditmarker` checks: mint and confirm a proposal for `webapp.list.update` against `/csp/myapp` through the shipped path, assert the target reads back enabled with `%Development` and that one `AgentWrite` audit row carries that proposal id, then restore the fixture to disabled with no resource. The read-back and the restore resolve the application by **the spelling the instance returns**, never by the proposal's stored (folded) `targetRef`. Both checks read `skipped`, with the reason naming the cause, when the demo fixture is absent or this install did not create it (`Fixture.WebAppOwnedByProfile`). `OcuPilot.PKG` classes only -- no `OcuPilot.Test.*` reference. (DW-1382)
19. `src/OcuPilot/Test/Smoke.cls` -- pin the three outcomes of each new check (executed pass, `fail` naming which half, `skipped` on an absent or unowned fixture), that a repeat run leaves the fixture disabled with no resource, and that the read-back resolves an application the instance holds in a **case-preserved** spelling -- driven through `Test/ProposalFixture.EnsureMixedCaseWriteTarget`, because `/csp/myapp` folds to itself and cannot tell a case-preserving read-back from one keyed off the folded ref. (DW-1382)
20. `ui/tools/ci.test.mjs` -- hold `ci-throwaway.sh`'s `OCUPILOT_DEMO` line equal to `docker-compose.yml`'s, so the `instance` job's new smoke checks do not rest on an unpinned line.
21. `src/OcuPilot/Test/SurfaceCoverage.cls` -- correct the stale `:260-268` and `:284-286` comments at their origin: the write half has a member and the zero is gone.
22. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:756` (UJ-3 step 3) -- two corrections to one sentence, both Rule 5 apply-and-report, both recorded in `## Spec Change Log`: replace "38 unchanged fields" with the count measured against `/csp/myapp` on the throwaway, **naming the population in the same sentence** (top-level properties of a `WebApp.App` `GET`, less the two the demo changes; expected 44); and delete the trailing clause "the list's auto-refresh chip reads paused", which is the same claim `epics.md:3606` was amended to remove and which this document is the origin of. Follow the count through `ui/tools/example-proposal.test.mjs` and `ui/src/app/shell/proposal-card.spec.ts`.
23. `ui/browser/proposal-demo.browser-spec.mjs` (new) -- the story's journey against the throwaway on AD-25's `/csp/myapp`, signed in **on the list** so the highlight is observable: a read card completes, the proposal card carries both diff rows with `(none)` on the before half, the disclosure opens to `unchangedCount` rows, the three agent sentences and the `Reverse:` line render, Confirm produces the status line and the `done - audit marked` card, and the row re-fetches and highlights inside the 2,000 ms budget measured with `Date.now()` and logged on a green run. Its header states that `/csp/myapp` is canonical, so this leg is not evidence about case folding -- `change-highlight-noncanonical.browser-spec.mjs` carries that and stays in the full suite.
24. `ui/browser/proposal-demo.browser-spec.mjs` -- two more legs on the same fixture: a **denied confirm** as the `Resources(1)` principal, asserting the `failed - <pair>` card, the proposal card's refusal banner, a Confirm that is still pressable and exactly the provider calls the turn made (no retry); and the audit hand-off, asserting the reply's published question sentence and that `shell.screen.open` with the marker criterion lands on `logs/audit` with the filter applied and the agent-marked event rendered under the confirming user's name.
25. `src/OcuPilot/Test/ToolNavigate.cls` -- pin the criterion argument: a declared flag is accepted and travels on the directive; an undeclared name, and a caller-supplied **value**, are each refused with `NAV.CRITERIONUNKNOWN` before any announcement exists. (AC3)
26. `src/OcuPilot/Test/ProhibitedRoute.cls` -- extend to AC5's two effects if not already covered: a disable and a resource-clear against each of OcuPilot's three serving paths is refused with `PROHIBITED.SERVINGPATH`, and the registry advertises no delete verb for web applications.

### Acceptance Criteria

- Given a principal holding the Web applications screen's own two pairs and **not** `%All`, when it confirms an enable plus a `%Development` grant on `/csp/myapp`, then the write succeeds and the ledger row records the pairs actually exercised, each once.
- Given a confirmed write, when the vendor PUT is issued, then its body is the complete merged property set read fresh at proposal time with the diff applied - not the two changed fields - and a test proves every unchanged property survives the round trip.
- Given the smoke script run twice against a container whose install created `/csp/myapp`, when each run finishes, then `agentwrite` and `auditmarker` both executed and passed, `executed=` rose by two against the run before this story, and the fixture is disabled with no resource afterwards.
- Given the same script on a container with no demo fixture, when it finishes, then both checks read `skipped` with the reason naming the absent fixture, no check reads `pending`, and the verdict is unchanged.
- Given the new check's read-back driven against an application the instance holds in a case-preserved spelling, when the check runs, then it finds, verifies and restores that application rather than missing it - a property `/csp/myapp` alone cannot demonstrate, since folding it changes nothing.
- Given the audit screen reached by an agent navigation carrying the marker criterion, when it arrives, then the marker filter is on, the screen has run its declared read, and the `AgentWrite` row for that proposal is rendered under the confirming user's own name.
- Given an agent navigation naming a criterion the target descriptor does not declare, or supplying a value for one it does, when the directive is resolved, then it is refused with `NAV.CRITERIONUNKNOWN` and no arrival is announced.

### Review Findings

Code review 2026-09-21, `full-opus` tier, four layers (`blind-hunter`, `edge-case-hunter`,
`verification-gap`, `acceptance-auditor`). 67 raw rows grouped to 29 entries: high 0, med 8, low 21,
plus 9 refuted. 27 patched or closed in-pass; 2 left with an owner.

#### Medium

- `[patch]` **`DW-1427`.** `AdminPort.Invoke` now refuses a `MUTATINGTYPES` call whose `pBody` is not
  an object, as an internal failure with the generic reason and the cause in the log. `RunSequence`
  substituted `{}` for it and the vendor answered 2xx having written nothing. Pinned by
  `OcuPilot.Test.AdminPortSync.TestAMutatingCallWithANonObjectBodyIsRefused`.
- `[patch]` **A `skipped` write check wrote to the instance.** `CheckAgentWrite`'s turn-slot arm is
  reached after the restore body has been built, so a run that reported doing nothing issued a PUT
  putting `/csp/myapp` back -- normalising a drift it did not cause. The body is dropped on that arm,
  and the skip's reason now names a reserve error instead of reporting one as a busy slot (DW-1402).
  Pinned by `Test.Smoke.TestASkippedWriteCheckLeavesTheInstanceAlone`.
- `[patch]` **The reply appenders' idempotency guards did not hold.** `replyWithMarkerSentence` and
  `replyWithAuditOfferSentence` tested `endsWith` against text an appender nested inside them had
  already extended, so a model reply that itself ended with the published question was given it
  twice. All four now test containment, which is `replyWithChangeSentence`'s own idiom and is
  order-independent. The new `panel.spec.ts` leg was red before the fix and is the pin.
- `[patch]` **An agent arrival ran the user's last search, not the screen's declared read.**
  `AuditSearch` is root-provided and keeps the criteria form across visits, and `criteria()` sends
  every declared criterion the form holds, so an arrival inherited a `usernames` value typed visits
  earlier and rendered no row for the write just made -- against AC3's and AC6's own matrix rows.
  `openWith` clears the form. Pinned in `audit.page.spec.ts`; mutation red.
- `[patch]` **The disclosure's "an ordinary value travels in clear" half was only ever asserted as
  `%All`.** `Disclosure.OrdinaryPaths` reads `ToolFields` out of the class dictionary -- a
  code-database read -- and answers fail-closed on any failure, so a real non-`%All` operator could
  see all 44 rows as bullets with the caption still correct: `unchanged.length === count`, the field
  names, the direction word and the masked `MatchRoles` all hold in that state. The AC1 browser leg
  now asserts an `ordinary` literal carries its value. Measured: mutating `OrdinaryPaths` to answer 0
  reddens that assertion and nothing else in the file.
- `[patch]` **The criterion channel is descriptor-generic on the instance and one screen wide in the
  client.** `Base.FlagCriteria` derives a flag from any well-formed entry on any descriptor, so a
  second declarer would be advertised, accepted, announced and then applied to nothing.
  `Test.ToolNavigate.TestTheAuditScreenIsTheOnlyDeclarerOfAFlagCriterion` is the roster tripwire; the
  fix when it trips is a client seam for that screen's store, not a wider assertion.
- `[defer]` **`DW-1428`** is `decision-pending owner=burndown`: whether a disclosed value may be
  truncated is the product question `EXPERIENCE.md`'s "every field stays available" bears on. The
  cost half is **declined at review with evidence**, not carried: a cross-request cache of the
  classification is fail-**open** on a security decision (a worker recompiled under load would
  disclose a value newly classified secret), and an in-call cache saves nothing while a turn mints
  one proposal. The per-poll projection is inherent to the wire shape.
- `[route]` **`DW-1432`** (new, `routed owner=burndown`): DW-1208's standing rule -- an `%Admin_*`
  write tool gates on `USE` -- is recorded in a tool parameter's doc comment and a ledger trailer
  only. This spec's own `Consumed-by` says every later `%Admin_*` write tool takes it as standing,
  which is Rule 20's threshold. The lead's write: one AD-8 amendment or one Conventions row.

#### Low, patched

- `AuditNow` truncated to whole seconds, matching `Test/UninstallSurvival.Now()`'s documented
  rationale: `%SYS.Audit.UTCTimeStamp` is a `%String`, so `>=` is lexicographic. **Measured on the
  build: it stores three fractional digits, so the widths agree today** -- a measurement, not a
  contract, and the proposal id is what identifies the row.
- `Test.Smoke`'s stale "carries the three pending items" doc corrected at its origin, and its
  `pending` scan moved off `Render`'s pad width onto the two named lines, so widening that width
  cannot make it vacuous.
- `Mint.Display`'s "not `Private` because" comment names its second caller.
- `Install/Smoke` resolves the descriptor class by `##class(...).#DESCRIPTORCLASS`, not a late-bound
  `$Parameter` string.
- `ProhibitedRoute` counts write-kind tools, so the assertion inside that branch is known to have run.
- `proposal-demo.browser-spec.mjs`'s AC3 leg forgets its tag in the outer `finally` as well.
- `proposal-view.test.mjs` gains the one fail-**open** tripwire `Disclosure.OrdinaryPaths` has: a
  generated container row classified `ordinary`+`literal` with member rows under it would put a
  secret subtree through `Mint.Display`. Zero such rows today; asserted rather than assumed, because
  the block is generated by Story 2.2's derivation and the leaf shape is what makes it unreachable.
- `### Integration ACs` names the module the implement stage created after that section was written
  (Rule 1).

#### Low, closed at emission

`wontfix-accepted`, each with its probe: `smoke.sh`'s header and `CLAUDE.md`'s run line do not say
the smoke now writes on a demo-armed container (`reopen_if` an operator reports `/csp/myapp` changing
unexpectedly); `ToolEmit`'s pair sweep mirrors `PrivilegePairs` line for line and is tautological --
`ToolWrite:233`'s list equality is the pin (`reopen_if` a write tool ships whose pair set `ToolWrite`
does not cover); `Test.Smoke`'s four probe methods assert nothing on a container without
`OCUPILOT_ALLOW_PRINCIPALS` (`reopen_if` a green run reports zero assertions for them); AC6's browser
leg asserts "an `AgentWrite` row under this user" rather than "for this proposal", which
`Install/Smoke.MarkerRows` correlates by id at the other tier (`reopen_if` a second proposal's row
can reach that screen in one run); AC1's "the ledger records the pairs exercised" holds by
construction through one call site and is unread by any test (`reopen_if` a ledger row's pair column
differs from `Registry.RequiredPairs`); the discarded statuses and the after-`Catch` namespace
restores in the new test helpers; the browser spec's third copy of the mask literal.

`wontfix-theoretical`: `Disclosure.Rows` answering `[]` on an unparseable payload would leave the
caption with nothing behind it -- reachable only from a stored payload `Mint` did not write; the
`Catch` arm's second `Note` for a check already noted; a bare `failed - ` from an answer carrying
neither reason nor code, which no OcuPilot envelope produces (AD-12); `Nav.Criterion`'s `MAXLEN 64`
against a longer declared flag name, which `InputSchema`'s own `maxLength` makes unnameable.

`by-design`: a successful re-press replaces the refused card in `writeCards`; the transcript is a
live view and the ledger is the record (AD-41). `failedPair` as the `failed - <reason>` detail is
what AC4's matrix row names.

#### Refuted by measurement

Nine, the load-bearing ones: `AuditNow`'s bound is **not** systematically wider than the stored value
(the build stores three fractional digits, probed); no `ToolFields` row is a disclosable container
with member rows (zero, swept); `MarkerRows` cannot over-count on a substring (ids are fixed-length
32-hex from `GenCryptRand`); `ProhibitedRoute` leaving its role is what its own doc says it does,
deliberately, and its guarded early returns are each preceded by a failing assertion; the unchanged
row's direction word is after the value because `EXPERIENCE.md:415` publishes it there; `shell`
importing an area store has precedent in `shell/screen-outlet.ts` and AD-19's target is state in a
component field; `executed=44` reconciles once the third skip (`demofixture`) is counted.

#### Adjudicated, as the spawn prompt asked

The identity of the write's pair set and the screen's declared read set is a **structural
guarantee**, not a present-tense coincidence: `ToolWrite.cls:233` asserts `PrivilegePairs()` equals
`Gate.RequiredPairs(DESCRIPTORCLASS)` as lists, and since `PrivilegePairs()` appends its own pair
only when absent, that equality holds exactly when the write's pair is already declared. Both sides
read the same `Gate.RequiredPairs`, so the classic-page union moves both and cannot fake agreement.
QA's "no new test needed" therefore holds. Two corrections to the record: the permission is
discriminated at **two** tiers, not one -- the AC1 browser leg's principal holds
`Resources(1)` + `%Admin_Secure:U` + `%DB_IRISSYS:R` and never sees a card under `WRITEPERMISSION =
"WRITE"` -- and the real-principal evidence for the DW-1208 defect is the AC4 browser leg plus QA's
`ProhibitedRoute` test, not the two `ProposalConfirm` order tests, both of which drive the gates
through fixtures and pin block order only.

## Spec Change Log

- **2026-09-21, lead.** The `intent gap` this spec halted on is resolved. `epics.md:3606` is amended
  (Rule 5 tier-1, orchestrator-authorised): AC1's `**And** the list's auto-refresh chip reads paused`
  is deleted. Story 5.7's final AC already owns the pause, conditioned on `**When** that screen's
  auto-refresh is on` -- a condition satisfiable only on AD-43's seven roster screens. The Web
  applications list declares `refreshes: false` and is absent from that roster, so the deleted clause
  restated 5.7's promise without the condition that makes it true. Status reset to `draft` to re-plan.
- **2026-09-21, lead.** `DW-1252` is dropped as a duplicate of `DW-1348` (code half landed in Story
  5.6). Its genuine narrower residual is now **`DW-1426`**: a refused confirm produces no write
  tool-call card at all, so AC4's `failed - <resource>` has no producer. The ledger inbox and the
  `epics.md` acceptance bullets both carry `DW-1426` in its place. The frozen `**Never:**` bullet's
  "(AD-43's roster governs - see the halt below)" points at that resolved halt, which this log now
  carries in the halt's place.
- **2026-09-21, lead.** `DW-1208`'s decision is confirmed and is stronger than it looked:
  `WebAppList.cls:50` already declares `[{"resource": "%Admin_Secure", "permission": "USE"}, ...]`,
  so the write requires **exactly the pair the screen's own read already declares** -- not merely a
  satisfiable pair, but the one already on the descriptor. That belongs in the spec's rationale.
- **2026-09-21, implement.** Task 22's two `EXPERIENCE.md:756` amendments applied (Rule 5
  apply-and-report). The count is **44**, with its population in the same sentence: the top-level
  property count of a `WebApp.App` `GET` for `/csp/myapp`, measured on `ocupilot-ci` (46 keys),
  less the two the demo changes. `EXAMPLE_PROPOSAL.unchangedCount` and `proposal-card.spec.ts`'s
  caption literal follow it. The trailing "the list's auto-refresh chip reads paused" clause is
  deleted at this origin, for the reason the `epics.md:3606` amendment gives.
- **2026-09-21, implement.** Task 10 adds **one** string, not two: `proposalDiffUnchanged`. The
  audit-entry offer is already published as `agentAuditFollowUpQuestion` (the Fixed-strings row at
  `EXPERIENCE.md:282`), and adding a second key with the same value is what
  `strings.test.mjs`'s uniqueness assertion refuses. The panel appends the existing key.
- **2026-09-21, implement.** Task 5's projection lives in a new
  `OcuPilot.Kernel.Proposal.Disclosure`, not in `Propose.WireRow` as planned:
  `scripts/check-objectscript.py`'s AD-9 rule forbids any reference to `OcuPilot.Screen` under
  `Kernel/State/`, and the masking has to read `Screen/Tool/ToolFields`. `WireRow` calls it and
  stays the one place the wire shape is written.
- **2026-09-21, implement.** `Kernel/Proposal/Confirm.Transition` now evaluates the **privilege
  pairs before the prohibited set**. Measured in a browser as a real least-privileged principal:
  the prohibited set reads live state through the port (AD-10), the port's own gate requires the
  same `%Admin_Secure:USE` the pairs gate names, so a caller that had lost it was answered
  `An internal error occurred` instead of `failed - %Admin_Secure:USE` -- which is what AC4 names
  and what AD-8 requires. Every unit test stayed green because the suite runs as `%All` and the
  fixture's `HoldsPair` seam never reaches the port. Pinned by
  `ProposalConfirm.TestThePrivilegeGateAnswersBeforeTheProhibitedSet`, with both gates armed.
- **2026-09-21, implement.** The `criterion` argument travels on the directive, which meant a
  trailing `Output pCriterion` on `Screen/Tool/Navigate.Directive` -- and therefore on the two
  test probe classes that override it (`Test/LedgerClientTool/Probe`, `Test/ClientCallFault/Probe`).
  `OcuPilot.Kernel.Agent.Dispatch` calls `Directive` positionally by name, so a near-miss signature
  compiles and answers `TOOL.UNAVAILABLE`: the full sweep caught it as four failures in
  `LedgerClientRows` and `LedgerRedaction`, and both probes now mirror the signature with a note
  saying why.
- **2026-09-21, plan (pass 2).** Re-planned against the amended `epics.md`. Four changes carry into
  the mutable sections; the `<intent-contract>` block is preserved verbatim, so its two `DW-1252`
  labels name the entry that has since been dropped and are read as `DW-1426`. (1) `DW-1426`
  replaces `DW-1252` in the Code Map, tasks, Design Notes and ledger inbox. (2) Task 22 amends
  `EXPERIENCE.md:756` twice under Rule 5 apply-and-report: the "38 unchanged fields" count, with its
  population named, and the same auto-refresh-chip clause the `epics.md` amendment removed -- this
  document is that clause's origin, and leaving it would have it mined as evidence again. (3) A
  case-preserved read-back is planned and pinned (tasks 18, 19, 23 and the fifth AC), because
  `/csp/myapp` folds to itself and would otherwise assume the 5.7 defect away. (4) The verification
  class list is corrected: `OcuPilot.Test.ProposalWire` covers `WireRow` and `OcuPilot.Test.ToolNavigate`
  covers the navigation tool; the names the first pass used do not exist.

## Review Triage Log

### 2026-09-21 — Review pass

- verdicts: 17 findings — high 0, medium 4, low 10, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` `recordWriteCard`'s new `status === 0` exclusion had no test, so a Confirm whose request never reached the instance could ship a `failed - ` card with no reason — added `panel.spec.ts`'s "a Confirm whose request never reached the instance records no card at all", with `ApiService`'s own aborted-fetch shape; mutation applied, red, reverted. Writing it found my first fixture omitted `detail`, which is not optional on the error variant — the fixture now matches `core/api.ts:346`.
  - `[medium]` `[patch]` `TestAWriteThatWouldChangeNothingFailsNamingIt` asserted nothing about the fixture's state, so narrowing the restore to the success path reddened nothing while the check's own reason still promised "it is put back" — added the two left-disabled assertions. The mutation I first named (guard on `tProblem = ""`) proved to be a no-op, because `tProblem` is unset on every early `Quit`; the mutation line now names the form that does falsify it (move the call inside the `Try`), observed red.
  - `[medium]` `[patch]` `Disclosure.OrdinaryPaths`' `[]`-stripping branch was untested although `webapp.list.update` declares `CorsAllowlist[]` and `CorsHeadersList[]` as ordinary literals (verified in `ToolFields.cls`), so deleting it would mask two real fields on every web-application proposal with nothing red — extended `FRESHCLASSIFIED` with an array of literals and asserted its value; mutation applied, red, reverted.
  - `[medium]` `[patch]` The gate reorder also moved the pairs check above AD-30's restraint verdict, and no test pinned that precedence either way — so a read-only instance now names a missing privilege, and the order could flip back with the suite green. AD-30's Rule requires a confirm to re-evaluate read-only and refuse (it still does, and nothing reaches the port); it does not fix which gate names the refusal, while AD-8's Rule does require a denial to name the pair. Pinned as implemented by `TestThePrivilegeGateAnswersBeforeTheRestraintVerdict` and stated in `Transition`'s own comment; both directions observed red.
  - `[low]` `[patch]` `shown()` was applied to both halves of a changed row but only the `before` half was asserted against an empty value, so reverting `shown(row.after)` reddened nothing — the empty-value test now carries a clearing row and asserts both halves; mutation applied, red, reverted.
  - `[low]` `[patch]` `AgentNavigator.applyCriterion` handed `AuditSearch` whichever screen arrived, and `openWith` declined only by inspecting the declaration — so a second screen declaring `marker` (a field on the shared generated `ReadCriteria`) would have the audit store set its own filter and bind that other screen's declaration into `RefreshService`. Guarded `openWith` on `AUDIT_DESCRIPTOR` at its origin and gave the method its first direct test in `audit.page.spec.ts` (it was covered only by a stub); mutation applied, red, reverted.
  - `[low]` `[patch]` The `### Rule 19 mutations` line labeled **AC2** named a `Disclosure.Rows` mutation, which pins the disclosure and not AC2 — AC2's real pinning tests are `ProposalConfirm.TestTheConfirmedWriteSendsTheStoredPayload` and `Proposal.TestThePayloadCarriesEveryPropertyTheFreshReadReturned`, neither of which that mutation would redden. Relabeled, AC2 given its own line naming its real mutation, and `OcuPilot.Test.Proposal` added to the targeted run list (Rule 19's sanctioned tracking-section correction).
  - `[low]` `[patch]` Every automated test of the two new smoke checks runs through `Test/SmokeWriteProbe`'s overrides, and the one test that runs the real list passes demo `"0"` and skips before reaching them — so the shipped `WriteTarget`/`WriteTargetOwned` bodies were asserted nowhere. Added `TestTheShippedCheckNamesTheDemoFixture`; mutation applied, red, reverted.
  - `[low]` `[patch]` (same root cause as the `applyCriterion` row) The instance's criterion channel is generic — `Base.FlagCriteria` admits any well-formed flag on any descriptor — while the client's is one screen wide, so a flag declared on a second screen would pass the instance gate, ride the directive and apply nothing. Closed by the same `AUDIT_DESCRIPTOR` guard and its foreign-declaration leg, which makes the decline explicit rather than incidental.
  - `[low]` `[patch]` (same root cause as the restraint-precedence row) The reorder makes AC5's named `PROHIBITED.SERVINGPATH` caller-dependent: a caller lacking `%Admin_Secure:USE` who proposes disabling `/ocupilot` is now answered `AUTH.NOPRIVILEGE`. The matrix row's own error-handling cell ("Refused on the instance whatever the caller") still holds, and the precedence is now stated and pinned rather than incidental.
  - `[low]` `[defer]` The demo card discloses the target's own `Name` as the secret mask — confirmed against `ToolFields.cls` (47 rows, 45 ordinary+literal top level, no `Name` row). Spec-bound: it is exactly the fail-closed rule the frozen matrix requires, so it is recorded rather than changed; settling it is a choice between classifying `Name` in Story 2.2's derivation and excluding the id field.
  - `[medium]` `[defer]` The disclosure's rows are unbounded in total size and re-projected on every poll, and `OrdinaryPaths` opens the `ToolFields` XData on every `WireRow`. AD-24's per-field bound does not cover the proposal wire, and bounding a disclosed value changes what the card shows — not settled by this spec.
  - `[medium]` `[defer]` `AdminPort.Invoke` silently no-ops on a `%String` body for a mutating type — measured both ways on `ocupilot-ci` during implementation: a `WebApp.App` PUT given JSON text answers 200 with the target unchanged and writes nothing. Out of this story's footprint; the fix is to refuse a non-object `pBody`.
  - `[low]` `[reject]` Two of `CheckAgentWrite`'s four skip arms ("the record could not be read", "a turn of this user is already running") are undriven. The spec's fourth AC and its matrix name the absent and unowned fixture, both of which are driven; the arms behave correctly and exercising them needs new injection machinery, which is more than a direct correction for a defect no user would meet.
  - `[low]` `[reject]` `ToolWrite`'s "no shipped role grants it" half is a proxy over a subset (it checks only `ADMINRESOURCES` members carry `USE`, leaving `%DB_IRISSYS:READ` unchecked) and never reads `%CSP.Portal.Application`. The test also asserts the resolved set *equals* the screen's declared set, which is the stronger property the Boundaries name, and the non-`%All` claim is exercised on a real principal at the browser tier; reading vendor source from a test is more than a direct correction.
  - `[false]` `[reject]` "`Test.Smoke`'s probe tests assert nothing off an armed throwaway." Refuted: `OCUPILOT_ALLOW_PRINCIPALS=1` on `ocupilot-ci`, and in run 2337 the four probe-driven methods recorded 9, 8, 6 and 9 assertions respectively — they ran for real where CI runs them, and `ArmMixedCase` logs the case where it declines.
  - `[false]` `[reject]` "`RestoreWriteTarget` is a new ungated write path in shipped code." Refuted: `AdminPort.Invoke` calls the endpoint **as the calling process's user** with no port elevation (its own header: AD-1, AD-2, AD-26; "Must not be called from an escalated frame"), so the vendor endpoint's own `%Admin_Secure:USE` check applies to the restore as to any caller. AD-34 binds the proposal transition and AD-10 the agent write path; the method is `[ Private ]` with one caller and a target fixed by `WriteTarget()`.
  - `[false]` `[reject]` "The matrix requires the agent's reply to state the refusal, and it does not." The same matrix row's error-handling cell reads "Rendered on both cards, never swallowed", which is what was built — the `failed - %Admin_Secure:USE` card and the proposal card's refusal banner. A confirm is a foreground press after the reply was composed, so no reply sentence is mechanically available without a new published string the spec does not ask for; the user is told either way.

## Design Notes

### Governing ADs (Rule 6), checked against each Rule's own text

**AD-8** is this story's own: privilege is the process's, checked at call time, and the descriptor declares a **set of pairs**; DW-1208 is that Rule applied to a permission the resource model does not carry. **AD-29**'s "`ResourcesOR()` is a lower bound, established two ways together" is why the pair is read off the vendor's own check rather than guessed. **AD-4** (read fresh, apply the diff, send the complete property set - `WebApp.App` is not one of the 19 merging `RunPut`s to be assumed about), **AD-3** (the field list is derived and each field carries a reviewed `ordinary`/`secret`/`opaque` entry; an unclassified field is **secret**, which is the fail-closed rule the unchanged rows inherit), **AD-6** (the instance mints; the confirm channel is closed; the fingerprint covers the whole payload), **AD-34** and **AD-40** (every gate inside the one transition, confirm reachable only from the browser), **AD-10** (the prohibited set has one home and is evaluated against live state inside that transition), **AD-15** and **AD-45** (the marker, and the one smoke path that names a confirmed agent write **and** its marker - DW-1382 is that Rule unmet), **AD-25** (the `/csp/myapp` fixture is opt-in, created only when absent, never modified if pre-existing - which is why the smoke restores it), **AD-11** rule 3 and **AD-21** (a navigation is an announced proposal of a route, and no caller value reaches a read - so the criterion is **named**, never valued, by the caller), **AD-13** as amended and **AD-14** (the scoped triple, the closed action, screens re-fetch), **AD-12/AD-39** (one envelope, two renderings; `NAV.CRITERIONUNKNOWN` joins a closed family), **AD-36**, **AD-19**, **AD-5**, **AD-30**, **AD-35**, **AD-41**, **AD-43**, **AD-44**, **AD-46**, **AD-47** all hold unchanged. **AD-43 is now satisfied by subtraction**: its Rule admits a screen to the auto-refresh set only by the descriptor **and** the published roster together, the Web applications list is in neither, and the clause that claimed a chip on it is deleted at both origins (`epics.md:3606`, task 22 for `EXPERIENCE.md:756`).

### Why masking, not withholding (DW-1223)

The ledger entry says to exclude secret-typed fields, and there are two readings: drop the field, or disclose the field and withhold the value. The published copy selects the second. `EXPERIENCE.md:470` reads "the unchanged fields that the payload still sends, collapsed under the disclosure 'N unchanged fields' (**every field stays available**, FR-17)", and `EXPERIENCE.md:415` reads "Secret values render as '••••••••' on both sides". Masking therefore keeps three things true at once that withholding cannot: the caption's number equals the rows behind it, every field stays available, and no secret value reaches the wire. It also leaves `UnchangedCount`'s computation untouched, so no stored column changes meaning and the `SCHEMAVERSION` question does not arise. The masking happens on the **instance**, in `WireRow`, so the value never travels rather than travelling and being hidden.

### Why the rows cost no second read

`RowValues` (`Propose.cls:571-606`) already materializes `payload` and `diff` in the same read the wire row is built from, so the rows are a projection of data in hand. `unchangedCount` stays a pass-through of the stored integer; the new invariant is that the projection's length equals it, which is a falsifiable pin rather than two independent computations.

### Why the navigation criterion is named and not valued

`AuditList.cls:152` declares the marker as `{param, value, labelKey}` - a flag whose value is the descriptor's. A caller that supplied a value would be a caller value reaching a read, which AD-21 forbids; naming a declared flag is the same shape the route argument already has (an enum of built routes). `withQuery` (`navigation.ts:531-543`) deliberately carries only `ns`, and its own comment says why, so the criterion travels on the directive rather than the URL and that comment stays true.

### What is model prose and what is published copy

"The agent states what it verified and ends 'Shall I show you the audit entry?'" is not assertable against model-authored text, so it is met the way 5.6 and 5.7 met the same shape: one published sentence the panel appends, idempotently, through the existing appender chain (`panel.ts:791-798`). "Answering yes navigates" is likewise the model choosing to call `shell.screen.open`; what this story makes deterministic and falsifiable is that the sentence is there and that the tool call, when made with the marker criterion, lands on the filtered screen with the event rendered.

### The refused-confirm card refines a 5.6 pin, it does not loosen it

`panel.spec.ts:3130-3157` asserts zero tool-call cards on a live-row refusal because `recordWriteCard` produced none. AC4 names one (`failed - <resource>`, which is `toolCallStatusFailed`'s published shape), and the epic context says a reachable refusal renders through that string on the card that was refused. The proposal card's DW-1348 refusal banner stays: the banner is the reason the row is still live, the tool-call card is the record that the write was attempted and failed. The test's own `mutation:` line is about `recordProposalRefusal` and stays true after the refinement; only the count assertion changes.

### DW-1426 is the residual; DW-1252 is dropped

The same defect was filed twice - from spec 5.5 as DW-1348 and from spec 5.3 as DW-1252 - and 5.6 closed DW-1348, which was the reason reaching the card. `DW-1252` is terminal (`dropped`, `by=merge_gate`, 2026-09-21). `DW-1426` is the narrower genuine residual: `panel.ts:1012-1018` returns early on a refusal, so **no write card exists at all** to carry a reason, and `panel.spec.ts:3130-3157` pins that absence. Tasks 12 and 13 and AC4's browser leg are its disposition, and it closes `resolved-by` this story.

### The smoke check's scope wall

`Smoke.cls:25-27` states it cannot depend on `OcuPilot.Test.*`. `Test/AuditMarker.cls:154-192` is the worked sequence, and the only two things it took from `Test/` are the turn row (`Kernel/State/Turn.GuardedReserve` + `GuardedBegin` + `GuardedFinish` are the shipped substitutes) and the write target (AD-25's `/csp/myapp` is the shipped one). `AuditMarker` already stores an empty conversation key, so the conversation is not a prerequisite; verify the same of the definition id against the throwaway before building on it. The write **mutates** the instance, which no other smoke check does, so the restore is not tidiness: without it a second run finds `/csp/myapp` enabled with a resource, which contradicts `Fixture.cls`'s own created-state contract and AD-25's "never modifies one it did not create". Both checks read `skipped`, never `fail`, where the environment cannot carry them - the same shape DW-1402 requires, where the reason travels even when the count cannot.

### Case-preserved spellings: what this story exercises, and what it cannot

`Mint` stores a folded `targetRef` (`EntityRef.Key`) while `Security.Applications` keeps a web application's name exactly as created. Two HIGH defects came from that gap in Story 5.7, both found with the whole suite green, because every fixture id was already canonical. `/csp/myapp` is canonical too, so **no leg of this story's demo path is evidence about folding** - task 23's header says so rather than leaving the green to be misread. What is already pinned stays pinned and is not rebuilt: `Test/ProposalSpelling.cls` on the server confirm-and-write path, `change-highlight-noncanonical.browser-spec.mjs` end to end, `data-table.ts`'s `viewKeyFor`/`changedKeyFor` at the component tier. The one **new** surface that resolves a target by name is `Install/Smoke.cls`'s read-back and restore, so that is where a case-preserved spelling is exercised deliberately (tasks 18, 19, fifth AC) - the check takes the instance's own spelling, and `Test/Smoke.cls` drives it against `ProposalFixture`'s mixed-case application. Read-only observation, not a promise this story makes: `WireRow` parses the stored folded ref (`Propose.cls:615-618`), so a mixed-case target's card heading renders folded; nothing here depends on that, and changing it would be an `EntityRef` change, not a slice call.

### The measured 44, and the published 38

`EXPERIENCE.md:756` names "38 unchanged fields" among "the values that make this demo concrete". The population is the **top-level property count of a `WebApp.App` `GET`**: measured through the shipped port on `ocupilot-slot-a`, `/api/ocupilot` answers 46 (2026-09-20) and `/csp/user` answers 46 (2026-09-21) - a REST and a CSP application, so this is two probes, not one generalized. A two-field change therefore leaves 44. `/csp/myapp` exists only where `OCUPILOT_DEMO` ran, so the demo's own target is measured on the throwaway and that number is what lands, with the population named in the sentence - a bare number swap would be a new unsourced claim. The empty-state example card derives from the same line and follows it; its seven-key shape (`example-proposal.test.mjs:154`) is untouched.

### Integration ACs (Rule 1)

Two, both at the browser tier against observable DOM: the Web applications list consumes the confirmed write's `changed` event and shows `Enabled Yes` with `%Development` on the re-fetched row inside the budget; and the Audit database screen consumes the navigation criterion and renders the `AgentWrite` row for that proposal under the confirming user's name.

A third, added at code review for the module the implement stage created after this section was written (`Kernel/Proposal/Disclosure`, see the `## Spec Change Log`): the proposal card consumes its `{field, value}` rows through `Propose.WireRow` and renders the disclosure to `unchangedCount` rows, each carrying the published direction word, with a secret-classified path masked and an `ordinary` literal in clear -- asserted at the browser tier in `ui/browser/proposal-demo.browser-spec.mjs`'s AC1 leg, against a non-`%All` principal.

### Consumes (Rule 2)

`Kernel.Proposal.Mint`, `Confirm` and `Kernel.State.Propose` (5.1, 5.3); `Kernel.Proposal.Prohibited` (5.5); `Kernel.Audit.Event`'s `AgentWrite` triple and the ledger (5.6); `core/change-bus.ts`, `core/refresh.ts`, `shell/data-table.ts`'s `viewKeyFor` and the toast (5.7); `Screen/Tool/ToolFields` and `Classification` (2.2); `Screen/Descriptor/AuditList` and `areas/logs/audit.*` (2.10); `Screen/Tool/Navigate` and `shell/agent-navigator.ts` (4.7); `Install/Fixture`'s `/csp/myapp` (1.4, AD-25); `Install/Smoke` (1.17).

### Consumed-by (Rule 2)

Stories 5.9-5.13, each of which is this story's shape in another area - the unchanged rows, the refused-confirm card and the audit hand-off are built once here and only pinned there; 5.10, whose destructive disable-auditing card renders the same disclosure; 5.11, whose navigation target is the Task schedule list and which inherits the criterion argument; Story 7.4's Auditing screen, which calls the same operation; every later `%Admin_*` write tool, which takes DW-1208's `USE` rule as standing.

### Footprint

In-epic throughout, plus three files no contended epic owns, reported under `footprint_extensions:` at the commit: `src/OcuPilot/Install/Smoke.cls`, `ui/tools/ci.test.mjs` (the demo-flag pin), and `EXPERIENCE.md`'s UJ-3 paragraph, amended in place under the narrow in-place allowance the owner granted, since that line is itself the subject of the fix; its Fixed-strings rows still go at the **tail**. `ui/src/styles/**` and `ui/src/app/shell/{header,account-menu,side-bar,command-box}*` are Epic 15's and are not edited.

### Ledger inbox (Rule 17) - four entries, all addressed

DW-1208 by tasks 1-4 and the first AC. DW-1223 by tasks 5-11 and two matrix rows. **DW-1426** by tasks 12-13, AC4's browser leg (task 24) and the refusal matrix row - the row is labeled `DW-1252` inside the frozen intent contract, which predates the substitution. DW-1382 by tasks 18-20, two matrix rows and three ACs. None declined.

## Verification

### Targeted - run these inside the implement loop (Rule 29)

- `(loop)` `uv run scripts/check-objectscript.py src/OcuPilot/Screen/Tool/WebAppUpdate.cls src/OcuPilot/Kernel/State/Propose.cls src/OcuPilot/Screen/Tool/Navigate.cls src/OcuPilot/Install/Smoke.cls src/OcuPilot/Api/Error.cls` -- expected: clean.
- `(loop)` `cd ui && npm run test:tools` -- expected: green, including `proposal.test.mjs`, `proposal-view.test.mjs`, `turn.test.mjs`, `example-proposal.test.mjs`, `ci.test.mjs` and `strings.test.mjs`.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `proposal-card.spec.ts`, `panel.spec.ts`, `audit.page.spec.ts` and `agent-navigator.spec.ts`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <one class>` -- one class per call, landed in `%UnitTest_Result` before the next, never two test calls in one message: `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.ToolEmit`, `OcuPilot.Test.ProposalConfirm`, `OcuPilot.Test.ProposalWire`, `OcuPilot.Test.ProposalSpelling`, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.ProhibitedByEffect`, `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.Smoke`, `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.Proposal` (AC2's pinning test lives there and this story does not change the class).
- `(loop)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: PASSED, `executed=` up by two and `pending=` down by two against the pre-story run; read the skip lines, not the number (DW-1402). Run it twice and confirm the second is identical and leaves `/csp/myapp` disabled with no resource.
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

### Full - run these once, at the end of the implement stage, before `dev_complete` (Rule 29)

- `(once, before dev_complete)` `cd ui && npm run build && npm test` -- the six prebuild checkers and both client tiers.
- `(once, before dev_complete)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` -- the whole browser suite, which is where `change-highlight-noncanonical.browser-spec.mjs` runs.
- `(once, before dev_complete)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci` -- the full ObjectScript sweep.
- `(once, before dev_complete)` `bash scripts/lint-docs.sh` -- expected: 0 issues.

### Rule 19 mutations

Each applied on `ocupilot-ci`, observed red, reverted; `git status --short` identical afterwards and
`git diff --stat` differing only by the AC5 fix the pass itself produced (below). The browser-tier
one was rebuilt and redeployed before the run and again after the revert.

- **AC1** -- `mutation:` drop the `$ListFind(tPairs, tOwn)` guard from
  `Screen/Tool/WebAppUpdate.PrivilegePairs()`, so the write's own pair is appended unconditionally
  -> `OcuPilot.Test.ToolWrite.TestTheResolvedPairsAreTheScreensOwnSetEachOnce` red on three
  assertions, naming `%Admin_Secure:USE,%DB_IRISSYS:READ,%Admin_Secure:USE`.
- **AC2** -- pinned by `OcuPilot.Test.ProposalConfirm.TestTheConfirmedWriteSendsTheStoredPayload`
  (the port receives the stored payload verbatim) together with
  `OcuPilot.Test.Proposal.TestThePayloadCarriesEveryPropertyTheFreshReadReturned` (the stored
  payload is the whole fresh read with the diff applied). `mutation:` take the payload from the
  request instead of the stored row in `Kernel/Proposal/Confirm.Transition` -> the first goes red on
  its body assertion. Both classes are pre-existing and this story does not change them, so the
  run list adds `OcuPilot.Test.Proposal`.
- **DW-1223 (rows)** -- `mutation:` drop `If $Data(tChanged(tKey)) Continue` from
  `Kernel/Proposal/Disclosure.Rows` -> `OcuPilot.Test.ProposalWire`'s length and order assertions
  red; the disclosure would carry the two rows the diff already shows.
- **DW-1223 (arrays)** -- `mutation:` drop the `If $Extract(tPath, *-1, *) = "[]"` line from
  `Kernel/Proposal/Disclosure.OrdinaryPaths` ->
  `ProposalWire.TestAnOrdinaryLiteralIsDisclosedWithItsValue` red on `CorsAllowlist`, the branch
  `webapp.list.update`'s two declared arrays of literals reach the disclosure through.
- **AC3** -- `mutation:` drop the restore's `PUT` from `Install/Smoke.RestoreWriteTarget` ->
  `OcuPilot.Test.Smoke.TestARepeatRunExecutesAgainAndLeavesTheFixtureDisabled` red on the second
  run and on both left-disabled assertions.
- **AC4** -- `mutation:` note `fail` instead of `skipped` on both arms of
  `Install/Smoke.CheckAgentWrite`'s skip -> `TestTheWriteChecksSkipWhereTheEnvironmentCannotCarryThem`
  red, and `smoke.sh --demo 0` flips from `PASSED` to `FAILED` naming both checks.
- **AC5** -- `mutation:` have `Install/Smoke.ApplicationName` answer `pPath` instead of the
  instance's own `Name` -> `TestTheAgentWriteCheckRunsOnACasePreservedTarget` red.
  **This mutation is why that assertion changed in this pass:** asked with the fixture's own
  literal it compared the argument against itself and stayed green, so it is now asked with the
  **folded** path -- the spelling `EntityRef.Key` stores and the one a check keyed off the
  proposal's `TargetRef` would carry.
- **AC6** -- `mutation:` drop the `applyCriterion` call from `shell/agent-navigator.ts`'s `act()`
  -> `agent-navigator.spec.ts`'s arrival assertion red at the component tier, and (rebuilt and
  redeployed) `browser/proposal-demo.browser-spec.mjs`'s AC3 leg red at the browser tier.
- **AC7** -- `mutation:` drop the `FlagCriteria` guard from `Screen/Tool/Navigate.Directive` ->
  `OcuPilot.Test.ToolNavigate.TestAnUndeclaredOrValuedCriterionIsRefused` red on all three shapes.
- **DW-1426** -- `mutation:` restore `Panel.recordWriteCard`'s `if (!outcome.ok) return;` ->
  both refused-confirm assertions in `panel.spec.ts` red.
- **DW-1223 (client)** -- `mutation:` drop `unchanged: proposal.unchanged` from `toCardView` ->
  `proposal-view.test.mjs`'s pass-through pin red.
- **Task 20** -- `mutation:` change `ci-throwaway.sh`'s `OCUPILOT_DEMO` to `"0"` ->
  `ci.test.mjs` red naming the drifted demo opt-in flag.
- **The gate order** (the `## Spec Change Log` entry names why it moved) -- `mutation:` put the
  pairs block back below the prohibited block in
  `Kernel/Proposal/Confirm.Transition` -> `TestThePrivilegeGateAnswersBeforeTheProhibitedSet` red
  naming the prohibited code. And below the **restraint** block ->
  `TestThePrivilegeGateAnswersBeforeTheRestraintVerdict` red naming a restraint code. Both
  directions are pinned, because before this story the restraint was evaluated above the pairs and
  a flip back would otherwise have reddened nothing.
- **DW-1426 (the boundary)** -- `mutation:` drop the `outcome.status === 0` clause from
  `Panel.recordWriteCard` -> `panel.spec.ts`'s "a Confirm whose request never reached the instance
  records no card at all" red; a thrown or aborted fetch would put `failed - ` in the transcript
  for a write the instance never received.
- **AC6 (the recipient)** -- `mutation:` drop the `declaration.descriptor !== AUDIT_DESCRIPTOR`
  guard from `areas/logs/audit.store.ts`'s `openWith` -> `audit.page.spec.ts`'s foreign-declaration
  leg red; the audit store would set its own filter and bind another screen's declaration.
- **DW-1382 (the shipped seams)** -- `mutation:` have `Install/Smoke.WriteTarget` answer any other
  path -> `OcuPilot.Test.Smoke.TestTheShippedCheckNamesTheDemoFixture` red. Every other test of
  these checks runs through `Test/SmokeWriteProbe`'s overrides, so without this the shipped bodies
  were asserted nowhere.
- **DW-1382 (the restore on the failure path)** -- `mutation:` move `CheckAgentWrite`'s
  `RestoreWriteTarget` call inside the `Try`, after its last `Note` ->
  `TestAWriteThatWouldChangeNothingFailsNamingIt` red on its two left-disabled assertions, and
  nothing else in the class. The coarser AC3 mutation (dropping the restore's `PUT` outright) does
  not catch that narrowing, which is the case a drifted container actually hits. Guarding the call
  on `tProblem = ""` was tried first and is **not** a mutation: `tProblem` is unset on every path
  that `Quit`s early, so `$Get` answers `""` and the restore still runs.
- **(QA) AC5, least-privileged.** Every over-the-wire AC5 leg in `OcuPilot.Test.ProhibitedRoute`
  ran as `%All`, and `OcuPilot.Test.ProhibitedByEffect`'s own-application leg replaces the port with
  a fixture, so nobody had measured that a caller holding exactly `%Admin_Secure:USE` and
  `%DB_IRISSYS:READ` -- the write's own pairs, DW-1208 -- reaches `PROHIBITED.SERVINGPATH` for one
  of OcuPilot's own applications rather than an internal error, the same shape DW-1208's own defect
  took for the pairs gate. Added `OcuPilot.Test.ProhibitedRoute.TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal`,
  which creates a dedicated least-privileged principal (measured on the instance, not assumed),
  discovers that reaching the confirm route at all also requires the install namespace's code
  database read resource (independent of and beneath DW-1208's pairs -- undocumented before this
  pass), and drives a real HTTP confirm against this class's own probe application, recorded as
  OcuPilot's own for the leg's duration only (`OcuPilot.Kernel.State.WebApp.GuardedRecord`), so
  nothing touches the instance's real API or shell applications. `mutation:` `Prohibited.WebApplication`'s
  `If pServes && +$Get(pChanged)` -> `If 0 && pServes && +$Get(pChanged)` -> the proposal actually
  confirmed and wrote (`"state":"confirmed","auditMarked":true`) instead of being refused; the other
  five tests in the class were unaffected (the mutation only disables the `pServes` branch, and
  nothing else in the class records a path as OcuPilot's own). Reverted; recompiled;
  `OcuPilot.Test.ProhibitedRoute` green again at 6/6 (run 2563); `git status --short` / `git diff
  --stat` confirmed unchanged by the mutation-and-revert. This test does not pin the pairs-before-
  prohibited order (`ProposalConfirm.TestThePrivilegeGateAnswersBeforeTheProhibitedSet` does, and
  this principal holds the pair `Target`'s own read requires regardless of gate order) -- it pins
  that the order's fix generalizes to AC5's own refusal for a caller who is not `%All`.
- **(CR) DW-1427, a mutating call's body.** `mutation:` drop the `'$IsObject(pBody)` guard from
  `Port/AdminPort.Invoke` -> `OcuPilot.Test.AdminPortSync.TestAMutatingCallWithANonObjectBodyIsRefused`
  red on four assertions, answering OK at HTTP 200 for a `PUT` that wrote nothing. Run 2566 green,
  2567 red, reverted, 7/7 green again; tree byte-identical.
- **(CR) A skip must not write.** `mutation:` drop `Set tRestoreBody = ""` from `CheckAgentWrite`'s
  turn-slot arm -> `Test.Smoke.TestASkippedWriteCheckLeavesTheInstanceAlone` red on its
  left-as-found assertion **alone**, with the two outcome assertions still green -- which is the
  point: the outcome was always right and the side effect was not. Run 2571 green, 2572 red, 2573
  green after the revert.
- **(CR) The disclosure discriminates a read classification from a fail-closed one.** `mutation:`
  have `Kernel/Proposal/Disclosure.OrdinaryPaths` answer `0` -> `proposal-demo.browser-spec.mjs`'s
  AC1 leg red on the new `Description` assertion and on nothing else in the file (AC4 and AC3 both
  still green), which is what the leg could not previously tell apart. Server-side only, so
  recompiled rather than rebuilt; reverted and 3/3 green again.
- **(CR) The audit arrival's own read.** `mutation:` drop `this.values = {}` from
  `areas/logs/audit.store.openWith` -> `audit.page.spec.ts`'s stale-criterion assertion red,
  carrying `&usernames=someone-else` into the arrival's read. **The first form of this assertion was
  itself vacuous** -- it set `Username`, and the declared parameter is `usernames`, so nothing was
  ever sent; the mutation is what found that, not review of the test.
- **(CR) The appenders' idempotency.** `mutation:` restore `endsWith` in
  `Panel.replyWithAuditOfferSentence` -> `panel.spec.ts`'s "appended once, even to a reply that
  already ends with it" red at length 3. Observed as the natural red before the fix: the guard was
  broken, and the test that claimed to pin it could not fail because `Panel.turns` recomposes from
  the store's pristine reply on every read.
- **(CR) The flag-criterion roster.** `mutation:` add a second `{param, value}` criterion to any
  other built descriptor's read -> `Test.ToolNavigate.TestTheAuditScreenIsTheOnlyDeclarerOfAFlagCriterion`
  red naming that descriptor.
- **(CR) The disclosable-container tripwire.** `mutation:` add
  `{"path":"MatchRoles[]","shape":"literal","class":"ordinary"}` to `webapp.list.update` in
  `ToolFields.cls` -> `proposal-view.test.mjs`'s container sweep red naming it and the two member
  rows it would have overridden. Applied, observed red, reverted.

## Auto Run Result

Status: done
Blocking condition: none

Story 5.8 is implemented: the write's gate is now `%Admin_Secure:USE` and `%DB_IRISSYS:READ` --
exactly the pair set `WebAppList.cls:50` already declares, deduped so the ledger records one check
once; the "N unchanged fields" disclosure has rows, projected on the instance from the payload the
mint stored and masked wherever the tool's own classification does not admit a value; a refused
confirm leaves a `failed - <pair>` card; the navigation tool takes a **named** flag criterion and
the audit hand-off's published sentence is appended by the panel; and `smoke.sh`'s last two
`pending` checks are real, driving a mint-and-confirm against AD-25's `/csp/myapp` and restoring it.

### Files changed

- `Screen/Tool/WebAppUpdate.cls` -- `WRITEPERMISSION` `WRITE` -> `USE`, `PrivilegePairs()` dedupes.
- `Kernel/Proposal/Disclosure.cls` (new) -- the `{field, value}` projection and its fail-closed mask.
  It is its own class because `check-objectscript.py`'s AD-9 rule forbids `OcuPilot.Screen`
  references under `Kernel/State/`, and the masking must read `ToolFields`.
- `Kernel/State/Propose.cls` -- `WireRow` gains `unchanged[]`; the two "not on the wire at all"
  sentences rewritten at their origin.
- `Kernel/Proposal/Confirm.cls` -- the privilege pairs now evaluate **first**, above the prohibited
  set and above the restraint verdict, with the precedence stated in the method's own comment.
- `Screen/Tool/Navigate.cls`, `Screen/Descriptor/Base.cls`, `Api/Error.cls`, `Kernel/State/Nav.cls`,
  `Kernel/State/Turn.cls`, `Kernel/Agent/{Dispatch,Loop}.cls` -- the `criterion` argument, its
  `FlagCriteria` allow-list, `NAV.CRITERIONUNKNOWN`, and the directive it travels on.
- `Install/Smoke.cls` -- `AddPending` replaced by `CheckAgentWrite`; `ApplicationName` resolves by
  the spelling the instance stores, never the proposal's folded `TargetRef`.
- Client: `core/turn.ts`, `core/proposal-view.ts`, `core/strings.ts` (one key,
  `proposalDiffUnchanged`), `shell/proposal-card.ts`, `shell/panel.ts`, `shell/agent-navigator.ts`,
  `areas/logs/audit.store.ts`, `shell/example-proposal.ts`.
- Tests: `Test/{ToolWrite,ToolEmit,ProposalConfirm,ProposalWire,Smoke,SurfaceCoverage,ToolNavigate,
  ProhibitedRoute,ProhibitedByEffect,ProposalFixture}.cls`, two new probe classes, four client specs,
  and `ui/browser/proposal-demo.browser-spec.mjs` (new, three legs).
- `EXPERIENCE.md` -- task 22's two apply-and-report amendments, plus the Fixed-strings row at the tail.

### Review findings

Two layers ran (`verification-gap`, `intent-alignment`; `blind-hunter` and `edge-case-hunter` are
disabled in `bmad-build-auto.toml`). 17 findings: 0 high, 4 medium, 10 low, 3 false. **8 entries
patched** (3 medium, 5 low), **3 deferred** (frontmatter `deferred:`), **2 rejected low**, **3
rejected on refutation**. Every row, with its evidence, is in `## Review Triage Log`. No
`intent_gap` and no `bad_spec`, so no loopback.

Two of the patches are worth naming because they changed what the tests can catch rather than
adding coverage: `TestAWriteThatWouldChangeNothingFailsNamingIt` now asserts the fixture is restored
on the **failure** path, and the privilege/restraint precedence is pinned in both directions. In
writing the first I found the mutation I had named for it was a no-op (`tProblem` is unset on every
early `Quit`, so `$Get` answers `""`); the line now names the mutation that does falsify it.

### Verification

- `uv run scripts/check-objectscript.py` -- 574 files, 21 rules, 0 problems.
- `bash scripts/lint-docs.sh` -- 0 issues, 103 files; `check-prose` 0 problems.
- `cd ui && npm run build` -- the six prebuild checkers pass. `npm test` -- 1200 tool tests + 722
  component tests, 0 failed, no unhandled errors.
- Full ObjectScript sweep on `ocupilot-ci`: **166 classes, 1482 tests, 0 failed**, 0 probe
  leftovers, 0 overlaps, 0 foreign runs.
- Full browser suite on `ocupilot-ci`: **200 tests, 198 pass**. The two failures are
  `tasks.browser-spec.mjs`'s Story 6.6 legs on a reused throwaway (DW-1425, `%SYS_Task.History`
  probe residue); no third, distinct failure. `proposal-demo`'s budget leg logged **15 ms** against
  NFR-1's 2,000.
- `smoke.sh --container ocupilot-ci` twice: `executed=47 passed=47 failed=0 pending=0 skipped=0`,
  PASSED both times, and `/csp/myapp` left `Enabled 0` with no resource. With `--demo 0`: both new
  checks `skipped` naming the absent fixture, `executed=44`, verdict unchanged.
- Rule 19: 7 mutations applied, observed red and reverted this pass (3 client, 4 ObjectScript), on
  top of the 11 from implementation. Each ObjectScript mutation was recompiled over the whole tree
  before reading the result; the tree is byte-identical after each revert.
- AC5 was checked rather than assumed: `OCUPILOT_ALLOW_PRINCIPALS=1` on `ocupilot-ci` and the four
  probe-driven `Test.Smoke` methods recorded 9, 8, 6 and 9 assertions, so the case-preserved
  read-back genuinely executed and did not take `ArmMixedCase`'s zero-assertion path.

### Residual risks

Follow-up review is recommended (`true`) because three medium entries were patched. The specific
unverified risk is the **gate precedence**: pairs now answer before AD-30's restraint verdict, so a
caller on a read-only instance who is also short a pair is told to acquire a privilege that would
not by itself help. AD-30's Rule requires only that the confirm re-evaluate read-only and refuse --
which it does, with nothing reaching the port -- and AD-8's Rule requires a denial to name the failed
pair, so both orders are defensible and the spec settles neither. It is pinned as implemented and
stated in the method's comment; whether that is the precedence the product wants is a judgment a
second reader should take, not one this pass could make.

The three deferred items carry the rest: the disclosure's unbounded row size on a once-a-second poll
and its per-`WireRow` XData read (medium), `AdminPort.Invoke` silently no-opping on a `%String` body
for a mutating type (medium, measured both ways), and the demo card disclosing the target's own
`Name` as the mask because `ToolFields` carries no row for it (low, spec-bound by the frozen
matrix's fail-closed rule). The last is demo-visible and worth the owner's eye before the freeze.
