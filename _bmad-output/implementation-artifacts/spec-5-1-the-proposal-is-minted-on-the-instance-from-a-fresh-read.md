---
title: 'The proposal is minted on the instance, from a fresh read'
type: 'feature'
created: '2026-09-19'
status: 'in-review'
baseline_revision: '3f002a9db607e0d74d1ba8bcdb3fe78a54dff75d'
baseline_commit: '966ec611a161f6682ac3c452e298b855887edd64'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot's registry holds read tools only. Nothing on the instance can author a
change the user reviews before it happens, so the product's central claim — "what I confirm
cannot differ from what will run" — has no mechanism behind it.

**Approach:** The instance mints a **proposal** when the agent calls a write tool: it reads the
target fresh through the port, merges the tool's resolved arguments over that whole object,
stores the complete payload, the computed diff, a fingerprint, a scoped target triple and a
single-use token in OcuPilot's protected state, and publishes a proposal-open event. The model
can reach only the minting path; the applying path refuses every call with no valid, unexpired,
unburned token. The first write tool, `webapp.list.update`, is the vehicle and the thing Story
5.8 later exercises end to end.

## Boundaries & Constraints

**Always:**

- The **instance** mints. The client posts no proposal, no diff and no payload; the only
  proposal-shaped datum in the client stays `shell/example-proposal.ts`'s static UJ-3
  illustration.
- The stored target is `EntityRef.Key(type, scope, id)` — AD-13's triple, `instance` scope for a
  configuration object — never a bare id.
- The fingerprint covers the **complete property set the write will send**, minus only the paths
  the descriptor declares under `fingerprintExcludes`. Default is everything else; a tool never
  chooses its own fields.
- The payload is the **whole object**: read fresh, apply the diff, keep every other property the
  fresh read returned (AD-4). The merge is over the fresh read's object, never over the derived
  field list.
- Secret-classified values are never accepted from the model and never stored. Expiry is the
  server-side constant `PROPOSALEXPIRYSECONDS = 600`.
- A proposal is confirmable only while its turn ended **normally**; a turn that ended
  `stopped`, `abandoned` or `failed` makes its proposals unconfirmable. A turn ends the moment it
  emits the card, so `completed` must not be caught.
- Every gate that decides whether a write may happen is evaluated at the write, not at the mint
  (AD-40).

**Never:**

- No instance mutation in this story. `AdminPort` gains no mutating request type; the payload is
  assembled and stored, and Story 5.3 sends it inside the atomic transition.
- No edit to `src/OcuPilot/Screen/Tool/Registry.cls`, `src/OcuPilot/Api/Error.cls`,
  `src/OcuPilot/Api/Definitions.cls` or any other contended path (Epic 10 owns them).
- No row action or primary action on `WebAppList` — the screen's affordances are Story 5.8's, and
  declaring one flips `IsWriteCapable` and forces `table.emptyAgentKey` copy this story does not own.
- No new key in `ui/src/app/core/strings.ts`. Every string a proposal needs already ships.
- No change to `core/change-bus.ts` or `core/refresh.ts`: the two proposal event kinds, the
  validation, the expiry clamp and the pause are already built.
- No confirm route, no token burn, no sibling cancellation, no audit marker, no card rendering,
  no screen highlight — 5.3, 5.6, 5.2 and 5.7.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Mint | model calls `webapp.list.update` with `{Name: "/csp/myapp", Enabled: true, Resource: "%Development"}` | one `State.Propose` row: 32-hex id and token, user, conversation, turn, tool name, resolved arguments, `TargetRef` = `web-application`+`instance`+`/csp/myapp`, fingerprint, complete merged payload, 2 diff rows, `UnchangedCount`, `ExpiresAt` = now+600s, `State` `live`; tool result carries the proposal id and the diff | No error expected |
| Target absent | same call, `/csp/myapp` does not exist | no row minted; tool result `TOOL.ARGUMENTS`-class refusal naming the target | the GET's 404 reads as zero rows, never as an empty success |
| Payload completeness | fresh read returns 40 properties, 2 change | stored payload carries all 40; `UnchangedCount` = 38; diff carries exactly the 2 | a merge that drops a property fails the payload-completeness assertion |
| Merge source | published `Application` schema carries `Type`, the instance's GET does not | payload holds exactly the fresh read's property names | a field-list-driven merge would add `Type`; refused by the same assertion |
| Privilege grant | model sends `MatchRoles` | refused as an unknown argument — the input schema does not admit the `MatchRoles` subtree (AD-10); the fresh read's own `MatchRoles` still travels unchanged in the payload | `TOOL.ARGUMENTS`, `detail.problem` |
| Secret argument | a descriptor declares a field `secret` | the value is neither accepted from the model nor written to `Arguments` or `Payload` | argument refused before any port call |
| Apply, no token | `Proposal.Write.Claim("", "")` | refused `PROPOSAL.NOTOKEN` | the write path refuses, not its caller |
| Apply, expired | token whose `ExpiresAt` has passed | refused `PROPOSAL.EXPIRED` | clock read once from `$ZTimeStamp` |
| Apply, burned | `Burned` = 1 | refused `PROPOSAL.BURNED` | — |
| Apply, wrong user | token minted by another user | refused `PROPOSAL.NOTYOURS` | never discloses whether the id exists |
| Apply, turn ended abnormally | turn `State` `stopped`/`abandoned`/`failed` | refused `PROPOSAL.TURNENDED` | — |
| Apply, turn ended normally | turn `State` `completed`, proposal unexpired | the claim succeeds and reaches the seam Story 5.3 fills | the ordinary path must not trip the rule above |
| Restraint | kill switch on, model calls the write tool | dispatch's write branch drops the call before any mint, through the real `Kernel.Restraint.Verdict` (DW-449) | verdict `code` becomes the tool result |
| Events | proposal minted, then it expires | `proposal-open` then `proposal-closed` on the change bus for `web-application`/`instance`/`/csp/myapp` | a proposal event with no id is already refused by the bus |
| Validation detail | write tool answers a validation envelope | the model sees `detail.violations[]` as `{field, code}` only; no `reason` text reaches it (DW-450) | AD-39: the tool result renders the machine half |
| Tool output on the step | any tool call finishes | the step stores the bounded result content the model received (DW-1052), capped by `TEXTMAXLENGTH` and marked `Truncated` when cut | — |

</intent-contract>

## Code Map

**Already built — read, do not rebuild.**

- `src/OcuPilot/Screen/Tool/FieldLists.cls:505-558` -- `WebApp.App`'s derived field list, 53 rows,
  `source: template`, `method: RequestBodySchema`. No row matches the credential pattern.
- `src/OcuPilot/Screen/Tool/Classification.cls:21-25` -- `XData Entries` is `{}`, "No write tool
  exists yet". This story mints the first entry. `ToolFields.cls:10-14` is `{}` and is regenerated.
- `ui/tools/field-lists.mjs` -- `classify()` :216, `generate()`; `--check` byte-compares the
  committed `ToolFields.cls` and runs in `ui` `prebuild`. Fails closed: an unnamed classifiable
  path is emitted `secret`; `opaque` only for a member-less object/array.
- `src/OcuPilot/Kernel/State/Base.cls` -- `GuardedSave` :132, `GuardedSaveIfCurrent` :167
  (row-versioned conditional update, `STALESAVEREASON` :103), `GuardedOpenId` :244,
  `GuardedOpenOneWhere` :518, `GuardedOpenIdExclusive` :852, `GuardedExecuteOneParam` :461. No
  abstract methods; a store adds properties, indexes and its own `Guarded*` wrappers.
- `src/OcuPilot/Kernel/State/Turn.cls:541` -- `NewKey()`, the house id:
  `$ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")`.
  Copied verbatim in `Convo.cls:197` and `Ledger.cls:341`.
- `src/OcuPilot/Kernel/State/Turn.cls:47` -- `State` (`queued|running|completed|stopped|abandoned|failed`,
  parameters :21-31), `IsTerminal` :127, `Code` :50, `EndedAt` :57, `GuardedFinish` :324,
  `GuardedSweep` :504 (deletes terminal turns older than `RETENTIONSECONDS`, called only from
  `GuardedReserve` :182).
- `src/OcuPilot/Kernel/EntityRef.cls` -- `Key(pType, pScope, pId, Output pKey)` :36,
  `Parse` :55, `Wire` :87 (`{type, scope, id}`), `ScopeFor` :110, `Validate` :119. Its header
  already names "Epic 5's proposal targets".
- `src/OcuPilot/Kernel/EntityType.cls:28` -- closed `TYPES`, already holds `web-application`.
  `src/OcuPilot/Kernel/Scope.cls:21,25` -- `instance` / `namespace`.
- `src/OcuPilot/Port/AdminPort.cls:342` -- `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output
  pResult, Output pHttpStatus, Output pFault)`. `TYPESUFFIXES` :118 is reads only; `pBody` is
  already threaded to `ValidateRequest`/`Run` (:781, :831, :857). `Template(pEndpoint, Output
  pTemplate, Output pMethod)` :448. Must not be called from an escalated frame (:338).
- `src/OcuPilot/Kernel/Agent/Dispatch.cls:178` -- `AnswerOne`, the ordered gate chain;
  `Parameter WRITEKIND` :37; the write branch :241-255 calling `..Restraint(pUser,
  pDefinitionId, .tVerdict)` :63; `ErrorContent(pCode, pDetail)` :672-678, which `%Set`s the
  fault detail **whole** — DW-450's site. `RedactedArguments`/`StepArguments` :212-220.
- `src/OcuPilot/Kernel/Restraint.cls:79` -- `Verdict(pUserName, pDefinitionId, Output pVerdict)`;
  precedence :117-125; any failed read forces `blocked` :129-131.
- `src/OcuPilot/Test/ToolDispatchProbe.cls:39,95-109` -- `ForceRestraint`; this is the override
  DW-449 says must be **unset** for the new tool's leg.
- `src/OcuPilot/Screen/Tool/Base.cls` -- `TOOLNAME` :26, `KIND` :30, `FULFILMENT` :41,
  `DESCRIPTION` :44, `InputSchema` :48, `ResultSchema` :55, `PrivilegePairs` :71,
  `SecretArguments` :91, `ArgumentPairs` :102, `View` :115, `ArgumentsRefusal` :125,
  `InternalRefusal` :137.
- `src/OcuPilot/Screen/Tool/Registry.cls:104` -- `ListTools` builds from a class scan
  (`ToolClasses` :552, `%STARTSWITH 'OcuPilot.'`, abstract and `OcuPilot.Test.` skipped) plus the
  descriptor enumeration. `ProviderTools` :227 refuses an undeclared `SecretArguments` :254-258,
  an empty `DESCRIPTION` :250, `KindProblem` :502, `FulfilmentProblem` :514 (`client` + `write`
  refused). **Adding a compiled concrete tool class is the whole registration — this file is not
  edited.**
- `src/OcuPilot/Screen/Tool/ErrorRead.cls:41,80-84` -- the class-tool idiom: `Parameter
  DESCRIPTORCLASS` plus `Gate.RequiredPairs(..#DESCRIPTORCLASS, .pResolved)`. Copy this shape.
- `src/OcuPilot/Screen/Registry.cls:318` -- `DECLARATIONKEYS`, an **unknown-key** check, never a
  presence check (:312-317), so a new optional key costs no edit to the other descriptors.
  `IsWriteCapable` :1857 and its `TableProblem` consequence :1846-1853.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls:30-72` -- `entityType: web-application`,
  `scope: instance`, `id: {kind: single}`, `toolIdentifier: "webapp.list"`, `privileges`
  `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, `read.source` `WebApp.App` **LIST** with no `rowGet`
  and no criteria, `primaryAction`/`rowActions` empty, `context.secretFields` empty.
- `src/OcuPilot/Screen/Descriptor/TaskDetails.cls:79-101` -- the worked single-object `GET` source
  with a route-id criterion, for reference only.
- `src/OcuPilot/Kernel/State/Step.cls:135-152` -- `GuardedFinishTool`, which hard-codes
  `ApplyContent(tRow, pName, "", "", pLimitsClass)` :146 and takes no text parameter. `Text` :28
  is `MAXLEN = ""`, capped by `ApplyContent` :213. DW-1052's site.
- `src/OcuPilot/Kernel/Agent/Loop.cls:506,518` -- `tResult.%Get("content")` is the bounded JSON
  string the model received; :518 is the finish that would carry it.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- `RETENTIONSECONDS` 900 :24, `TEXTMAXLENGTH` 131072
  :36, `TOOLRESULTMAXLENGTH` 65536 :48, `SUMMARYMAXLENGTH` 1000 :33, `FIELDMAXLENGTH` 1000 :54.
  Resolved per call through `Loop.LimitsClass()` :27, so a test subclass narrows any of them.
- `src/OcuPilot/Kernel/Agent/Prompt.cls:11` -- `Parameter BUILTIN`, one string literal. Its third
  sentence reads "Your tools read this instance and change nothing: say so when a request needs a
  change, and never claim to have changed anything." No test pins the text.
- `src/OcuPilot/Kernel/Shell/ReadTool.cls:19-23` and `src/OcuPilot/Screen/Tool/Read.cls:63-68` --
  the two abstract intermediates that answer `pDeclared = 1 / Quit ""`. DW-1121's site.
- `src/OcuPilot/Api/Turn.cls:227,272` -- `HandleStop` / `HandleNavigation`: owner gate first
  (`Turn.GuardedForOwner`), 404 identical for "not found" and "not yours", closed body vocabulary,
  409 `STATE.CONFLICT` via `RenderStateConflict` :500. `Api/Router.cls:99-103` -- the `/turn`
  route block and its three ordering invariants (:54-69).
- `ui/src/app/core/change-bus.ts` -- `ChangeEventKind` :30 already `'changed' | 'proposal-open' |
  'proposal-closed'`; `ChangeEvent` :36-50 carries `{kind, type, scope, id, key, proposalId,
  expiresAt}`; `publish` :105 refuses a proposal event with no `proposalId` :109;
  `PROPOSAL_EXPIRY_MS` :33 = 600000; `expiryFor` :127 clamps. **No change needed.**
- `ui/src/app/core/refresh.ts` -- `liveProposals` :184, `canArm()` :451-457, `onBusEvent` :608-632,
  `paused()` :312, `armedFor()` :323, `chipLabel()` :341-348, `noteScopeChanged()` :384.
  **The pause is already built. No change needed.**
- `ui/src/app/core/turn.ts` -- `TurnStore` :342, `turnProgressPath` :49, `pollOnce` :706-742
  hand-parsing a `Record<string, unknown>`, `TurnEntry` :125-137, `TurnStep` :90-104.
  `ui/src/main.ts:148-160,222` -- where `ChangeBus` is constructed and handed to `AgentStatus` /
  `AgentContext`; `TurnStore` takes no bus yet.
- `ui/src/app/shell/example-proposal.ts:20-41` -- `ProposalDiffRow {field, before, after}` and
  `ProposalCardView {entityType, name, changed, unchangedCount, rationale, expectedImpact,
  reverse}`. The mint's wire shape maps onto this; the card is 5.2's.
- `ui/src/app/core/strings.ts:67,133-165,220,528-532` -- every proposal string already ships,
  including `statusAutoRefreshPaused`.

**Static gates that bind this story** (`scripts/check-objectscript.py`, 21 rules):
`check_tool_kind` :1721, `check_tool_dispatch` :917 (no `%Net.HttpRequest`, no `/api/`, no
`OcuPilot.Api.*` but `Error`, no capture under `Screen/Tool/`; `InvokeTool` only in the two
allowed files), `check_restraint_containment` :792 (a restraint code is produced only in
`Kernel/Restraint.cls` and `Api/Error.cls`), `check_state_package_isolation` :825 (no `JOB`, no
`OcuPilot.Api|Port|Screen|Area|Kernel.Agent` under `Kernel/State/`), `check_agent_job_reach` :865
(under `Kernel/Agent/` the only outside names are `Port.ProviderPort` and
`Screen.Tool.Registry`), `check_escalation_containment` :736, `check_admin_api_containment` :707,
`check_state_sql_literal` :966, `check_naming` :383 with `MAX_CLASS_NAME_LENGTH = 29` :208,
`check_write_discipline` :584, `check_non_ascii_literals` :1609, `check_handler_wire_tests` :1533.

## Tasks & Acceptance

**Execution** (in dependency order):

- `src/OcuPilot/Kernel/Agent/Limits.cls` -- add `Parameter PROPOSALEXPIRYSECONDS As %Integer = 600`
  beside `RETENTIONSECONDS` -- AD-6's server-side constant, resolvable per test through
  `pLimitsClass` so an expiry test narrows it instead of waiting ten minutes.
- `src/OcuPilot/Kernel/State/Propose.cls` -- NEW store extending `Kernel.State.Base`, class name
  **`Propose`** with `[ SqlTableName = Proposal ]`. Properties: `ProposalKey`, `Token` (both
  `%String(MAXLEN=64)`, 32-hex from the house `NewKey()` one-liner), `Burned` `%Boolean`,
  `UserName`, `ConvKey`, `TurnKey`, `ToolName`, `TargetRef` (`EntityRef.Key`'s value),
  `Fingerprint`, `Arguments` / `Payload` / `Diff` as `%Stream.GlobalCharacter`, `UnchangedCount`,
  `Rationale` / `ExpectedImpact` / `Reverse` (capped at `SUMMARYMAXLENGTH`), `CreatedAt`,
  `ExpiresAt`, `State` (`live|confirmed|canceled|expired`). Unique indexes on `ProposalKey` and
  `Token`; an index on `(UserName, State)`. Its own `Guarded*` wrappers over Base's helpers, each
  SQL argument a call-site literal. No `list Of`, no hand-written Storage, no `JOB`, no reference
  to `Api`/`Port`/`Screen`/`Area`/`Kernel.Agent`. Record at the class why `SCHEMAVERSION` does not
  move, as `State/Ledger.cls:19-20` does.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- NEW. `Mint(pDescriptor, pToolName, pUser, pConvKey,
  pTurnKey, pArgs, pLimitsClass, Output pProposal, Output pHttpStatus, Output pFault) As %Status`:
  read the target fresh through `AdminPort.Invoke(<endpoint>, "GET", .tQuery)`, treat a 404 /
  zero rows as "target gone", merge the resolved arguments over the **fresh read's own object**,
  compute the diff and `UnchangedCount`, compute the fingerprint over the merged payload minus the
  descriptor's `fingerprintExcludes`, and store one row. Lives outside `Kernel/Agent/` and
  `Kernel/State/` precisely so it may name the port and the descriptor.
- `src/OcuPilot/Kernel/Proposal/Fingerprint.cls` -- NEW. `Of(pPayload As %DynamicObject, pExcludes
  As %List, Output pDigest) As %Status` -- canonical key-ordered serialisation minus the excluded
  paths, hashed with `$System.Encryption.SHAHash(256, ...)` and hex-encoded. Deterministic across
  key insertion order; round-trip tested.
- `src/OcuPilot/Kernel/Proposal/Write.cls` -- NEW. `Claim(pProposalId, pToken, pUser, Output
  pProposal) As %Status` -- the single gate every instance mutation passes, refusing
  `PROPOSAL.NOTOKEN`, `PROPOSAL.UNKNOWN`, `PROPOSAL.EXPIRED`, `PROPOSAL.BURNED`,
  `PROPOSAL.NOTYOURS`, `PROPOSAL.TURNENDED`. Reads the minting turn's `State` and refuses the
  three abnormal terminal states while admitting `completed`. Burning the token and committing are
  Story 5.3's; this story ships the gate and its refusals.
- `src/OcuPilot/Screen/Tool/Write.cls` -- NEW abstract base: `KIND = "write"`, `FULFILMENT =
  "instance"`, a final `View()` that delegates to `Kernel.Proposal.Mint` and answers the proposal
  id, target, diff and unchanged count, and an abstract `Endpoint()` / `SettableFields()` pair. The
  model reaches `View()` and nothing else; `Claim` is not reachable from a tool body.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` -- NEW. `TOOLNAME = "webapp.list.update"`,
  `DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList"`, endpoint `WebApp.App`.
  `InputSchema` derived from `ToolFields`' entry, `additionalProperties: false`, **excluding the
  `MatchRoles` subtree** (AD-10 forbids granting privilege through any path) and requiring `Name`.
  `PrivilegePairs` = `Gate.RequiredPairs(..#DESCRIPTORCLASS, .pResolved)` plus
  `%Admin_Secure:WRITE`.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add the first reviewed entry, keyed
  `webapp.list.update`, `fieldList: "WebApp.App"`, classifying every classifiable path of the 53
  rows as `ordinary` except the `MatchRoles` subtree. The reserved `required`/`enum`/`description`
  keys stay empty.
- `src/OcuPilot/Screen/Tool/ToolFields.cls` -- regenerate with `cd ui && node tools/field-lists.mjs`;
  never hand-edited.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` -- add two optional top-level keys,
  `"secretArguments": []` and `"fingerprintExcludes": []` -- AD-6's declared exclusions and closed
  confirm channel. No action is declared.
- `src/OcuPilot/Screen/Registry.cls` -- admit both keys in `DECLARATIONKEYS`; validate each as an
  array of strings, every `fingerprintExcludes` path present in the tool's field list, and
  **refuse a descriptor whose declared criteria or settable fields hold a name matching the
  credential pattern that `secretArguments` does not list** -- the refusal DW-1121 says cannot
  currently bite.
- `ui/tools/screen-mirror.mjs` -- mirror the same two keys in `DECLARATION_KEYS` and the emitted
  `ScreenDeclaration` interface, returning the same refusal sentences as `Screen/Registry.cls`.
- `src/OcuPilot/Screen/Tool/Read.cls` -- `SecretArguments` answers from the descriptor's
  `secretArguments` (absent = empty, `pDeclared = 1`) instead of a hard-coded constant (DW-1121).
- `src/OcuPilot/Kernel/Shell/ReadTool.cls` -- delete the `SecretArguments` override; declare it on
  each of `Kernel/Shell/InstanceRead.cls`, `NamespacesRead.cls`, `PrivilegesRead.cls` so the next
  subclass inherits no answer (DW-1121).
- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- restate the third sentence of `BUILTIN` so it says
  what a proposal is: the tools read this instance and propose changes the user confirms, the
  agent never applies one itself, and it never claims a change has happened before confirmation
  (DW-454).
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- in `ErrorContent`, project a `detail.violations[]`
  member to `{field, code}` before it reaches the model, leaving every other detail key as it is
  (AD-39: the tool result renders the machine half) (DW-450).
- `src/OcuPilot/Kernel/State/Step.cls` -- add a trailing `pText As %String = ""` to
  `GuardedFinishTool` and pass it to `ApplyContent` in place of the literal `""` (DW-1052).
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- pass `tResult.%Get("content")` as that text at the
  success/failure finish (`:518`), leaving the dispatcher-failed finish empty (DW-1052).
- `src/OcuPilot/Api/Turn.cls` -- the progress payload carries the turn's live proposals as a
  `proposals` array of `{proposalId, target: {type, scope, id}, expiresAt, tool, changed,
  unchangedCount, rationale, expectedImpact, reverse, state}`, owner-gated exactly as the rest of
  the payload is. No new route.
- `ui/src/app/core/turn.ts` -- parse `body['proposals']`, carry them on `TurnEntry`, and publish
  `proposal-open` on first sight of an id and `proposal-closed` when an id leaves a poll or its
  state turns terminal, through an optional `bus` option in the shape `AgentStatus` already uses.
- `ui/src/main.ts` -- hand the existing `ChangeBus` to `TurnStore`.
- `src/OcuPilot/Test/ProposalFixture.cls` -- a `%RegisteredObject` (not a `TestCase`) that seeds
  and sweeps probe proposals, turns and a probe web application under an `OcuPilotProbe` prefix,
  modeled on `Test/TurnFixture.cls`.
- `src/OcuPilot/Test/Proposal.cls`, `ProposalWrite.cls`, `ProposalWire.cls`, `ToolWrite.cls` --
  the four suites below, each under ~500 lines, each with a header naming what it pins and what it
  needs from the environment, and no property whose name begins with `Test`.
- `ui/tools/proposal.test.mjs` -- the client half: the publisher's open/close behavior over a
  stubbed poll, and `PROPOSAL_EXPIRY_MS` held equal to `PROPOSALEXPIRYSECONDS * 1000` read from
  `Kernel/Agent/Limits.cls` on disk, the way `credential-lists.test.mjs` holds its two lists equal.

**Acceptance Criteria** (system-level; the I/O matrix rows are not repeated here):

- Given the shipped registry, when `Registry.ProviderTools` is asked, then `webapp.list.update`
  is advertised with `kind` `write` and `fulfilment` `instance`, and no edit was made to
  `Screen/Tool/Registry.cls`.
- Given a write tool body, when the tree is searched, then no path from `View()` reaches
  `Kernel.Proposal.Write.Claim`, so the model can mint and cannot apply.
- Given the client bundle, when every `.ts` under `ui/src/app` outside `shell/example-proposal.ts`
  is searched, then nothing constructs a proposal, a diff or a payload and nothing posts one.
- Given a proposal minted by a turn that then ends `completed`, when `Claim` is called with its
  token, then it succeeds; given the same proposal on a turn that ended `stopped`, `abandoned` or
  `failed`, then it is refused `PROPOSAL.TURNENDED`.
- Given `Kernel.Agent.Limits`, when `RETENTIONSECONDS` and `PROPOSALEXPIRYSECONDS` are read, then
  retention is greater than or equal to expiry, so a turn record outlives its proposals' window.
- **Integration AC (Rule 1).** Given consumer `Kernel.Agent.Dispatch` and the shipped registry,
  with `Test/ToolDispatchProbe`'s restraint seam **unset** so the real `Kernel.Restraint.Verdict`
  decides, when the turn calls `webapp.list.update` under a kill switch, then the call is dropped
  and the verdict's own code is the tool result; and when it calls it with the switch off, then a
  `State.Propose` row exists and the turn's progress payload carries that proposal (DW-449).
- **Integration AC (Rule 1).** Given consumer `RefreshService` (`ui/src/app/core/refresh.ts`)
  bound to a refreshing screen over `web-application` at scope `instance`, when `TurnStore`
  publishes `proposal-open` for that target on the real bus, then `paused()` reads true and
  `armedFor()` reads `expiry`; and when it publishes `proposal-closed` for the same id, then
  `paused()` reads false again — with no change to `refresh.ts` or `change-bus.ts`.

## Spec Change Log

- 2026-09-19, lead: **the first implement attempt was killed mid-run by an account-level API rate
  limit**, after its implementation pass but before its four self-review layers ran (the spec was
  left at `status: in-review`). Its output was kept, not discarded: 502 classes compile clean on
  slot A, every artefact and member this section names exists, no contended path was touched and
  `core/strings.ts` is unmodified. It is therefore **unreviewed draft completed by the lead**, and
  it goes through the full review loop from scratch rather than inheriting a self-review it never
  had. No self-review finding count is recorded for this story, because none was produced.

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-6 (server-minted, single-use, fingerprinted,
expiring; the fingerprint covers the complete property set minus descriptor-declared exclusions;
the confirm channel is closed to all but declared secret fields). AD-4 (OcuPilot computes the
merge and sends a complete body; the merge is over the fresh read's object, never the derived
field list). AD-40 (confirm is not a tool; every write gate is evaluated at the write, which is
why `Claim` carries no prohibited-set or restraint evaluation of its own). AD-34 (one atomic
transition — its shape is honoured by `Claim` being the only door, and the transition itself is
5.3's). AD-13 (the scoped triple through `EntityRef`; ids percent-encoded by the one shared pair
only when they reach a URL). AD-3 (derived field lists, reviewed classification, fail-closed
secret emission). AD-43 (proposal-open and proposal-closed on the change-event bus, which is what
the auto-refresh pause rides on). AD-7 and AD-30/AD-31 (the turn's lifetime, the abnormal-end
rule, the named constants). AD-9 and AD-37 (proposal state is OcuPilot's own protected state,
written through the row-versioned guarded save; references to IRIS objects are weak — scoped
identity as data, never a foreign key). AD-10 (the `MatchRoles` subtree is not admitted by the
tool's input schema; the instance-side predicates are Story 5.5's). AD-36 (the screen's declared
read is unchanged — the write's fresh read is a separate single-object GET through the port,
because the screen read is projected, capped and stripped of secret fields while the merge needs
the whole object). AD-39 (one envelope; the tool result renders `code`, the screen renders
`reason` — which is what DW-450's projection restores). No AC here contradicts an AD.

**Rule 20 — the spine amendment this story needs (DW-445).** AD-7's Rule still reads "It writes
per-step progress to a temp global keyed by turn id", which AD-33 and the shipped
`Kernel.State.Turn` / `Kernel.State.Step` tables contradict. The clause is stale, not the code.
Recommended replacement, for the lead to write into the spine at the moment of the decision (this
story does not edit the spine): **"It writes per-step progress to OcuPilot's own protected storage
(AD-33), keyed by turn id and owned by the user who started the turn; the panel polls
`GET /api/ocupilot/turn/{id}/progress`."** This is an amendment to an existing AD's Rule, so it
claims no new `AD-n`.

**Why `Propose` and not `Proposal`.** `OcuPilot.Kernel.State.` spends 22 of the Conventions row's
29 characters, so a store's own name may be 7 at most; `Proposal` is 8 and
`check-objectscript.py:208` refuses it. The class is `Propose` with `[ SqlTableName = Proposal ]`,
the same split `State/Switch.cls:9-15` already uses for `SwitchState`.

**Why the first write tool is `webapp.list.update`.** Three things already name it: the shipped
`ProposalCardView` example is UJ-3's web application with its two changed fields and 38 unchanged
(`shell/example-proposal.ts:78-89`), `FieldLists.cls` already carries `WebApp.App`'s 53-row
derived list, and `Classification.cls` is empty with "No write tool exists yet". Story 5.8
exercises this same tool end to end through the screen, the marker and the highlight; it does not
build a second one.

**Why no descriptor action.** A class tool registers by class scan and needs no `rowActions`
entry. Declaring one would flip `Screen/Registry.IsWriteCapable` and pull in `TableProblem`'s
`emptyAgentKey` requirement (`Registry.cls:1846-1853`), which is copy this story does not own.
The screen's affordance arrives with Story 5.8.

**Why `AdminPort` gains no mutating type here.** Nothing in this story writes to the instance: the
payload is assembled and stored at mint and sent inside 5.3's transition. `TYPESUFFIXES` stays
reads-only, which also means the AD-40 property "no mutation without `Claim`" holds by
construction for the whole of this story.

**Consumes:** `Kernel/Agent/{Dispatch,Loop,Job,Limits,Prompt}.cls` and `Kernel/Restraint.cls`
(Epic 4); `Kernel/State/{Base,Turn,Step,Convo}.cls` (Epic 4, Story 1.3); `Port/AdminPort.cls` and
`Screen/{Read,Gate,Registry}.cls` (Epic 2); `Kernel/{EntityRef,EntityType,Scope,Fault}.cls`
(Epic 1); `Screen/Tool/{Base,Read,Registry,FieldLists,Classification}.cls` and
`ui/tools/field-lists.mjs` (Story 2.2, 4.2); `ui/src/app/core/{change-bus,refresh,turn}.ts` and
`ui/src/app/shell/example-proposal.ts` (Story 1.14, 4.10); `ui/browser/panel-spec.mjs` and the
split ledger fixtures (Story 5.0).

**Consumed-by:** Story 5.2 (the card renders the stored diff, unchanged count and countdown, and
fills `proposal-card.ts`'s two `ng-content` slots); Story 5.3 (confirm claims the token through
`Proposal.Write.Claim`, re-reads the target, compares the fingerprint and burns inside one
transition); Story 5.5 (the prohibited-set predicates run inside that transition, against the
resolved target this story stores); Story 5.6 (the audit marker carries the proposal id, tool,
target triple and user); Story 5.7 (screens pause on `proposal-open` and re-fetch on `changed`);
Stories 5.8-5.13 (each area's write tool is an instance of `Screen/Tool/Write.cls` with its own
descriptor and classification entry).

**Ledger inbox (Rule 17).** DW-445 addressed by the recommended AD-7 wording above. DW-449
addressed by the second Integration AC and its mutation. DW-450 addressed by the `ErrorContent`
projection task and its I/O row. DW-454 addressed by the `Prompt.BUILTIN` task. DW-1052 addressed
by the `Step.GuardedFinishTool` / `Loop.cls:518` pair. DW-1121 addressed by moving the declaration
off the two abstract intermediates and adding the descriptor-side refusal.

**Declined DW-1170:** its only fix site is `src/OcuPilot/Api/Error.cls:375` — every fixed refusal
sentence in the tree is declared there by AD-39 and confined there by the write-discipline rule,
and that file is contended by Epic 10 for the length of this run, so an edit is refused rather than
judged. The entry's own trailer already records that the wording is the owner's call. Re-own it to
the range-end cleanup story (Rule 27) or to the decision sheet, whichever the lead's gate reaches
first; nothing in this story renders that sentence.

**Footprint extensions to report (Rule 11(b)):** none expected. Every path above is inside the
footprint named in the dispatch, and `Screen/Tool/Registry.cls`, `Api/Error.cls`,
`Api/Definitions.cls` and `ui/tools/strings.test.mjs` are left untouched.

## Verification

**Commands** — from `/Users/jbrandt/git/OcuPilot/.worktrees/epic-5`, slot A throughout
(`server: "ocupilot-slot-a"`, container `ocupilot`):

- `uv run scripts/check-objectscript.py` -- expected: 0 problems over 21 rules. If a rule is added,
  update the count pin at `scripts/test_check_objectscript.py:275-300`.
- `uv run scripts/test_check_objectscript.py` -- expected: all OK.
- `bash scripts/lint-docs.sh` -- expected: clean.
- Load and compile the whole `src/OcuPilot/` tree through the IRIS MCP tools -- expected: compile
  clean. Recompile the **package**, not one class, before reading any mutation result.
- `cd ui && node tools/field-lists.mjs` then `node tools/field-lists.mjs --check` -- expected: the
  regenerated `ToolFields.cls` carries the one new entry and `--check` is silent.
- `cd ui && npm run build` -- expected: the six `prebuild` checkers pass, including
  `screen-mirror.mjs --check` over the two new declaration keys and `field-lists.mjs --check`.
- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` then the component runner, all
  green, including the new `proposal.test.mjs`, plus `change-bus.test.mjs`, `refresh.test.mjs`,
  `turn.test.mjs`, `screen-mirror.test.mjs`, `field-lists.test.mjs` and `strings.test.mjs`
  unchanged.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  then `sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/` --
  expected: readiness answers. Tear this throwaway down at the end with
  `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, and tear down
  nothing else (Rule 24).
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>` -- **one class per call**,
  each landed in `%UnitTest_Result` before the next, for at least `OcuPilot.Test.Proposal`,
  `ProposalWrite`, `ProposalWire`, `ToolWrite`, `ToolDispatch`, `Restraint`, `ReadTool`,
  `ToolRoundTrip`, `LedgerStep`, `TurnLoop`, `TurnWire`, `Descriptor`, `ScreenRegistry`,
  `DerivedFields` -- expected: each green with a non-zero assertion count. Then
  `node ui/tools/ci-runner.mjs --container ocupilot-ci` for the full sweep -- expected: 0 failed,
  0 leftovers, 0 overlaps.
- `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every
  check passes, the executed count is non-zero, and `agentwrite` / `auditmarker` still report
  `pending` (Stories 5.8 and 5.6 clear them).
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  -- expected: every spec green. The build writes `dist/ocupilot-ui`, not `dist/ocupilot`. Run the
  browser suite against a **freshly brought-up** throwaway: a used one fails `messages-log` AC5 and
  AC6 deterministically because the suite's own logging pushes the seeded severity mix out of the
  viewer's tail window (DW-1190). Destructive verification belongs on the throwaway, and stateful
  test classes run one per tool call (DW-1185).

**Mutations (Rule 19)** — one per AC and per I/O row, each applied, observed red, reverted, with
`git status --short` and `git diff --stat` confirmed identical to the pre-mutation snapshot
afterwards. Record each as `mutation: <what was changed> -> <which test went red>` here. The
minimum set:

- drop one unchanged property from the merged payload in `Proposal.Mint` -> the payload-completeness
  assertion red, naming the missing property.
- build the merge from the derived field list instead of the fresh read's object -> the merge-source
  assertion red on a property the read never carried.
- include a `fingerprintExcludes` path in `Fingerprint.Of` -> the exclusion assertion red.
- reverse `Fingerprint.Of`'s key ordering -> the determinism round trip red.
- admit `MatchRoles` in `WebAppUpdate.InputSchema` -> the privilege-grant refusal row red.
- make `Claim` accept a burned token / an expired token / another user's token / a `stopped` turn,
  one at a time -> the matching refusal test red alone each time.
- make `Claim` also refuse a `completed` turn -> the ordinary-path test red, which is the AC that
  is easy to under-read.
- unset `PROPOSALEXPIRYSECONDS`'s relation to `RETENTIONSECONDS` by raising expiry above retention
  -> the retention-window assertion red.
- leave `Test/ToolDispatchProbe`'s restraint seam forced -> the DW-449 leg red, because the real
  `Kernel.Restraint.Verdict` no longer decides.
- swap `Dispatch.Restraint`'s two arguments -> the same DW-449 leg red (the slip the entry names).
- leave `ErrorContent` rendering the detail whole -> the DW-450 assertion red on the violation
  `reason` reaching the model.
- revert `GuardedFinishTool`'s text to `""` -> the DW-1052 step-output assertion red.
- restore `SecretArguments` on `Kernel/Shell/ReadTool.cls` and plant a credential-named criterion
  -> the DW-1121 descriptor refusal red.
- make `TurnStore` publish `proposal-open` without the `proposalId` -> the bus's own refusal path
  observed, and the `RefreshService` integration AC red on `paused()`.
- return the wrong scope from the mint's `EntityRef.Key` -> the `RefreshService` integration AC red,
  because the event no longer matches the bound screen's scope.

**Applied.** Each was applied alone, observed red, reverted, and the tree confirmed identical to
the pre-mutation snapshot (`git status --short` and `git diff --stat`) afterwards.

- mutation: `Proposal.Mint.Merge` drops `ProbeOnly` from the merged payload ->
  `Test.Proposal.TestThePayloadCarriesEveryPropertyTheFreshReadReturned` red, naming the property.
- mutation: `Proposal.Mint.Merge` sets a settable field the fresh read never carried ->
  `Test.Proposal.TestAFieldTheFreshReadDidNotCarryIsRefusedRatherThanAdded` red.
- mutation: `Proposal.Fingerprint.Canonical` stops skipping an excluded path ->
  `Test.Proposal.TestAnExcludedPathIsOutsideTheFingerprint` and
  `TestTheMintTakesItsExclusionsFromTheDescriptor` red.
- mutation: `Proposal.Fingerprint.Canonical` emits members in insertion order ->
  `Test.Proposal.TestTheFingerprintIsDeterministicAcrossKeyOrder` red.
- mutation: `WebAppUpdate.ExcludedFields` answers empty ->
  `Test.ToolWrite.TestARoleGrantIsRefusedAsAnUnknownArgument` red on the exclusion. Classifying the
  subtree `ordinary` on top of it does **not** admit it: a nested path is outside the flat advertised
  schema, so three independent guards keep a role grant out and the `unassigned` assertion is pinned
  by outcome rather than by a one-line mutation.
- mutation: `Proposal.Write.Claim` drops the burned branch ->
  `Test.ProposalWrite.TestABurnedTokenIsRefused` red alone.
- mutation: it drops the expiry branch -> `TestAnExpiredProposalIsRefused` red alone.
- mutation: it drops the user branch -> `TestAnotherUsersTokenIsRefused` red alone.
- mutation: `ABNORMALSTATES` loses `stopped` ->
  `TestATurnThatEndedAbnormallyLeavesItsProposalsUnconfirmable` red alone.
- mutation: `ABNORMALSTATES` gains `completed` -> `TestAProposalOnACompletedTurnIsClaimable` red.
- mutation: `PROPOSALEXPIRYSECONDS` raised to 1200 ->
  `TestRetentionOutlivesTheProposalWindow` and `proposal.test.mjs`'s two constant tests red.
- mutation: `Test.ToolDispatchProbe.ForceRestraint("clear")` left set ->
  `Test.ToolWrite.TestAHeldUserIsDroppedByTheRealRestraintVerdict` red.
- mutation: `Dispatch.Restraint`'s two arguments swapped -> the same leg red.
- mutation: `Dispatch.ErrorContent` renders the detail whole ->
  `Test.ToolDispatch.TestAValidationViolationReachesTheModelAsFieldAndCodeAlone` red.
- mutation: `Step.GuardedFinishTool` passes `""` as the text ->
  `Test.LedgerStep.TestAToolStepStoresTheResultContentTheModelWasHanded` red.
- mutation: `SecretArguments` restored on `Kernel/Shell/ReadTool.cls` ->
  `Test.ToolWrite.TestTheSecretArgumentsComeFromTheDescriptor` red on the method origin; planting a
  credential-named criterion on `WebAppList` -> `Test.Descriptor`'s confirm-channel test red and the
  client mirror's `buildMirror` refuses to emit.
- mutation: `TurnStore.publishProposals` omits `proposalId` -> the bus refuses the event and six
  `proposal.test.mjs` tests red, the `RefreshService` integration among them.
- mutation: it publishes a fixed scope -> the `RefreshService` integration test red, because the
  event no longer matches the bound screen's scope.

Three more, added with the assertions the full sweep's own two reds called for:

- mutation: `Step.ApplyContent` assigns `pText` instead of capping it ->
  `Test.LedgerStep.TestAToolStepStoresTheResultContentTheModelWasHanded`'s cap leg red alone,
  on the length and on `Truncated`.
- mutation: `Proposal.Mint.Merge` removes `MatchRoles` from the copied payload ->
  `Test.ToolWrite.TestWithNothingRestrainingItTheCallMintsAProposal` red alone, on the excluded
  subtree still travelling in the body the write will send.
- mutation: `Api.Turn.HandleProgress` stops setting `proposals` ->
  `Test.TurnWire.TestAStartRunsAsTheCallerAndThePollAnswersItsShape` red on the declared-key
  roster, which is the story's only over-the-wire assertion on that key. Applied to the
  throwaway's own source copy and reloaded there, so the repository tree stayed byte-identical
  throughout.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
