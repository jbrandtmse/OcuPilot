---
title: 'Story 4.4: Screen context reaches the turn, capped and secret-free'
type: 'feature'
created: '2026-09-16'
status: 'in-progress'
baseline_revision: 'd568b5cd6c7a1f1a80e1a2ea125aa2c2f59f5bf9'
baseline_commit: 'd568b5cd6c7a1f1a80e1a2ea125aa2c2f59f5bf9'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      `Switches.MergeBody` silently treats a JSON object or array sent for any switch field
      (including `contextRowCap`) as absent, keeping the stored value rather than refusing.
    evidence: |-
      Verified the object/array short-circuit at the top of `MergeBody` predates Story 4.4 and is
      shared by every switch field, not something this story introduced.
    location: >-
      src/OcuPilot/Api/Switches.cls (MergeBody)
    severity: low
---

# Story 4.4: Screen context reaches the turn, capped and secret-free

<intent-contract>

## Intent

**Problem:** A turn knows nothing about the screen the user is on. `POST /turn` reads only `message`, and AD-24's bounds exist only as a row cut in `Dispatch.Capped`: no per-field bound (DW-281), no per-reply budget (DW-452), no operator row cap. There is also no per-user sharing choice and no way to tell whether context leaves the instance.

**Approach:** `POST /turn` accepts an optional `context`. The server projects it through the route's descriptor, applies the sharing choice, and bounds it with one kernel cutter that also bounds every read tool result. It enters the model's messages as a synthetic `screen.context` tool call and its result. A new per-user store holds the sharing choice, a new operator switch holds the row cap, and a context status read reports the choice, the cap and where context goes.

## Boundaries & Constraints

**Always:**

- **Wire.** `context` is `{route, namespace, entity?, view?: {sort?, direction?, filter?, rows: [{<field>: scalar}], rowsAvailable?}}`. It is refused with 422 `TURN.CONTEXT.INVALID` on field `context` when:
  - it is not an object, or a member has the wrong JSON type;
  - `rowsAvailable` is a negative number or below the number of rows sent;
  - `namespace` differs from the request's resolved scope (`Kernel.Scope.Current()`, from `?ns=`).
- **Sharing.** Effective sharing is the caller's row in the new store, and with no row it is `Switch.ShareContextByDefault`. When sharing is off, the context is discarded after validation and no `screen.context` is built.
- **Descriptor projection.** The route resolves through the screen registry, and an unresolved route builds no `screen.context`.
  - A descriptor with any `context.secretFields` sends identity only: `screen`, `route`, `namespace` and `entity`, with no rows, sort or filter. The exclusion is decided by the descriptor, never by field names.
  - Otherwise a row keeps only keys in `context.fields`. A non-scalar value is dropped and its field is added to `truncatedFields`. A sort field not in `context.fields` is dropped.
  - `screen` is the descriptor's tool identifier.
- **One cutter** (`Kernel/Agent/Bound`) serves context and read tool results. It applies these bounds, in this order:
  - Rows are cut to the row cap, `Switch.ContextRowCap`: integer 1–1,000, default 200.
  - Each string value longer than its maximum is cut to maximum−1 characters plus U+2026. The maximum is the descriptor's `context.maxLength[field]`, else `Limits.FIELDMAXLENGTH` = 1,000. Cut fields go into `truncatedFields`.
  - The serialized payload is at most `Limits.TOOLRESULTMAXLENGTH` = 65,536 characters. Whole rows are cut from the end until it fits.
  - The payload reports `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields` (sorted, unique).
  - Bounds truncate and never refuse. The one refusal is a read tool result that cannot fit with zero rows, which stays `TOOL.RESULTTOOLARGE`.
- **Descriptor schema.** `context` gains the optional key `maxLength: {<field>: integer}`. Both twin validators (`Screen.Registry.ReadProblem` and `screen-mirror.mjs`) refuse a key that is not in `context.fields`, a value that is not an integer, and a value outside 1–1,000. Only `context` is checked, so `read.criteria.fields[].maxLength` is untouched.
- **Message shape.** With context, messages are:
  1. user text `Prompt.ContextPreamble()`, a build-time constant;
  2. assistant `tool_use` `{id:"ocupilot_screen_context", name:"screen_context", input:{}}`;
  3. user `[tool_result{tool_use_id, content: payload JSON}, text: message]`.

  Without context, messages are unchanged. `screen.context` is never advertised. A model call named `screen_context` answers `TOOL.UNKNOWN` through the existing `ResolveWire` path.
- **Tools' scope.** The job receives the request's resolved scope and `Kernel.Scope.Set`s it before the loop.
- **Reply budget (DW-452).** `Loop.AnswerTools` gives each reply's tool results a total of 65,536 characters. Each call's `pMaxLength` is the remaining budget. When less than 256 remains, the call is answered `TOOL.RESULTTOOLARGE` without dispatch and recorded as an error step.
- **`contextRowCap` switch.** It is on `GET/PUT /agent/switches`, kind integer, a security field, audited like 3.8's switches, with violation `AGENT.SWITCH.CONTEXTROWCAP`. `Switch.Resolve` answers the default for an empty or out-of-range stored value. The Switches page shows a numeric field labeled "Context rows sent with a turn".
- **Context status read.** `GET /agent/context` is caller-own and ungated beyond the router. It answers `{share, shareDefault, userChoice (boolean|null), contextRowCap, provider, endpointHost, leavesInstance}`.
  - `PUT /agent/context {share: boolean}` stores the caller's choice and answers the same body. Anything else in the body gets 422 `AGENT.CONTEXT.SHARE`.
  - Provider and host come from the enabled default definition through `ProviderPort`'s own endpoint resolution: `endpointUrl`, else the catalog's `defaultEndpoint`.
  - `leavesInstance` is false when the definition is marked local, or when every resolved address is loopback, link-local, RFC 1918 or `fc00::/7`. It is true when the host is unresolvable or any other address is present. With no enabled default it is `""`, `""` and JSON null.
- **Credential lists (DW-399).** The client's `CREDENTIAL_RE` gains suffix `credential` and exact `credentialname`, built from exported arrays that a node test holds equal to `Log.cls`'s two parameters.
- Non-ASCII in source is written as escapes (Rule 14).

**Never:**

- Chip, pill, key glyph, panel toggle, client context assembly or paste warning (Story 4.11).
- A name-pattern match that removes redaction or decides a context exclusion.
- A `Kernel/Agent` class naming a `Screen.*` class other than `Screen.Tool.Registry`.
- A spawn from an escalated frame.
- Changing AD-7.
- Widening the `maxLength` check beyond `context`.
- A new schema version: the new property reads a safe default on old rows.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Capped context reaches the turn (Integration) | `logs/audit` context with 250 rows, cap set to 5, one `Description` of 3,000 characters | turnprobe call 1's messages: 3 messages as specified; the payload has `rowsSent` 5, `rowsAvailable` 250, `truncated` true, `truncatedFields` `["Description"]`, and that value is 1,000 characters ending U+2026 | none |
| Total size | 200 rows of about 900 characters each | payload JSON at most 65,536 characters; `rowsSent` below 200; whole rows only | none |
| Secret screen | `agent/definitions/edit` context with rows | payload has identity only, `rowsSent` 0, no `rows` key | none |
| Sharing off | caller has PUT `{share:false}`; context posted | turnprobe messages have no `screen_context` and equal the no-context shape | none |
| Default off | no user row; switch `shareContextByDefault` false | as sharing off; `GET /agent/context` gives `userChoice` null and `share` false | none |
| Model calls it | turnprobe script issues a `screen_context` tool_use | its tool_result content `code` is `TOOL.UNKNOWN` | a result, not a failure |
| Bad context | `context` is a string, or `namespace` differs from `?ns=` | 422 `TURN.CONTEXT.INVALID` on `context`; no turn reserved | envelope per AD-39 |
| Unknown route | route not in the registry | turn runs with no `screen_context` | none |
| Read tool field bound | audit read tool, `EventData` over 1,000 characters | tool_result rows carry the value cut with U+2026; `truncatedFields` names it | none |
| Reply budget | one reply with 3 audit read calls, each capped near 40,000 characters | first result full, second cut to the remaining budget, third `TOOL.RESULTTOOLARGE` when under 256 remains | error step recorded |
| Row cap switch | PUT `contextRowCap` 0, 1,001, "x" / 500 | 422 `AGENT.SWITCH.CONTEXTROWCAP` / 200 audited; non-admin gets 403 | existing switch handling |
| Leaves instance | turnprobe (192.0.2.10) / definition marked local / host resolving 10.1.2.3 / unresolvable | true / false / false / true | none |
| Descriptor bound | `context.maxLength` `{Description: 1001}`, `{Nope: 5}` or `{Description: "5"}` | both validators refuse, naming `context.maxLength` | build or registry validation fails |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Turn.cls` -- `HandleStart` :28 builds `tValues` after `GuardedReserve`. Validate `context` beside `MessageViolation` :172, before the reserve. `RenderViolation` :190 hardcodes `MESSAGEFIELD`; it needs a field argument.
- `src/OcuPilot/Kernel/Agent/Job.cls` -- `Start` :32 passes positional `JOB` args. `Run` :54 checks `$Namespace = pNamespace`, which is the spawn namespace; the scope is a separate new argument.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- `Run` :75 builds `tMessages(1)` as a plain `content` string, and later messages use `(n,"blocks")` JSON. `AnswerTools` :292-349 calls `DispatchTools` one call at a time; that is where the reply budget goes.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- `Answer` :110 reads `TOOLROWS` and `TOOLRESULTMAXLENGTH` from the limits class and must take the cap and budget as arguments. `AnswerOne` :139. `Capped` :292-343 cuts rows only; replace its body with `Bound`. `ResolveWire` returning no tool is `TOOL.UNKNOWN` :160.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- `TOOLROWS` 200 (to be replaced by the switch), `TOOLRESULTMAXLENGTH` 65536, `SUMMARYMAXLENGTH` 1000. Add `FIELDMAXLENGTH` 1000. `Test/TurnLimits.cls` overrides these parameters.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- `Builtin()`. Add `ContextPreamble()`.
- `src/OcuPilot/Screen/Tool/Read.cls` -- `View` :161 cuts to `pContextCap` and returns `{fields, rows, truncated}`. `Screen/Tool/Registry.cls` `InvokeTool` :395 carries `descriptor` on the tool object, which is where `FieldMaxLengths(pTool)` goes.
- `src/OcuPilot/Screen/Descriptor/Base.cls` -- `ContextFields()` :277, `ContextSecretFields()` :284. Add `ContextMaxLengths()`.
- `src/OcuPilot/Screen/Registry.cls` -- `ReadProblem` :615, with the context block at :687-697 (`UnknownKeyProblem` allows `fields` and `secretFields`). `Route` per descriptor :263; routes look like `logs/audit` and `agent/definitions/edit`. Criteria `maxLength` is a separate path at :934.
- `ui/tools/screen-mirror.mjs` -- context validation :544-552 and `ContextDeclaration` type :1418. Regenerate `ui/src/app/core/screens.generated.ts`. `ui/tools/screen-mirror.test.mjs:644-678` applies `CREDENTIAL_RE` to `context.fields`.
- `src/OcuPilot/Kernel/State/Switch.cls` -- `DEFAULTSHARECONTEXT` :33, `Resolve` :57, `SetGuarded` :94. The doc comments at :31-32 and :45-46 still say "per-session switch"; correct them.
- `src/OcuPilot/Kernel/State/Hold.cls` -- the per-user store to copy: weak `UserName` MAXLEN 160, unique index, `GuardedForUser`. The new class is `OcuPilot.Kernel.State.Sharing`, exactly 29 characters. `Test/State.cls:326 StateClasses` counts state classes.
- `src/OcuPilot/Api/Switches.cls` -- `Fields()` :55 is the switch table, `HandleRestraint` :275 is the caller-own ungated pattern, and `RecordAudit` :524. `Kernel/SwitchRules.cls:36 ValidateSwitches`. `Api/Error.cls` codes are around :515-674.
- `src/OcuPilot/Api/Router.cls` -- UrlMap :66-92. Add `/agent/context` GET and PUT.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Dispatch` :220-250 resolves the catalog row and `endpointUrl`/`defaultEndpoint`. Factor that into a public resolver the status read shares.
- `src/OcuPilot/Kernel/Egress.cls` -- `HostOf` :53, `Addresses` :153, `Canonical` :249, `IsLoopback` :277, `IsLinkLocal` :297, `V6Groups` :324. It has no private-range kind; add `IsPrivate`, which leaves `IsPermitted` unchanged.
- `src/OcuPilot/Kernel/State/Agent.cls` -- `ResolveDefault` and `ScreenRow` :430. Leave the six-key projection unchanged.
- `src/OcuPilot/Kernel/Audit/Log.cls` -- `CREDENTIALSUFFIXES` :53, `CREDENTIALEXACTNAMES` :63, `IsCredentialName` :172. `ui/tools/field-lists.mjs:59` `CREDENTIAL_RE` lacks `credential` and `credentialname`, and `field-lists.mjs --check` runs in prebuild.
- `src/OcuPilot/Test/TurnProvider.cls` records `messages` and scripts replies by model tag. `TurnWireFixture.StartBody` :266 sends `{message}` only; `EnsurePrincipal` :64. `TurnWire.cls` is 462 lines, so put new wire tests in a new class.
- `ui/src/app/areas/agent/switches.store.ts` :34-73 has boolean fields only. `switches.page.ts` :139. `ui/browser/switches.browser-spec.mjs`. `core/strings.ts` :541 `agentSwitchesShareContext`. The EXPERIENCE.md :348 row is "Context rows sent with a turn".

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Agent/Limits.cls`, `Bound.cls` (new) -- add `FIELDMAXLENGTH`, and write the cutter from Boundaries (rows, per-field, total, report). One cutter for both consumers is AD-24 and DW-281.
- `src/OcuPilot/Screen/Descriptor/Base.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/screens.generated.ts` -- add `context.maxLength` with the twin refusals. The registry-level bound is AD-24's.
- `src/OcuPilot/Screen/Context.cls` (new) -- resolve the route to its descriptor, then project identity, rows, sort and filter per Boundaries. Return the payload and the field-maximum map. It names no `Kernel/Agent` class, because `Api/Turn` calls it and then `Bound`.
- `src/OcuPilot/Screen/Tool/Registry.cls`, `Screen/Tool/Read.cls`, `Kernel/Agent/Dispatch.cls` -- rows cap and budget become arguments, `Capped` delegates to `Bound` with `FieldMaxLengths`, and `View` passes rows uncut to the cap so `rowsAvailable` is real. This bounds read tool results.
- `src/OcuPilot/Kernel/Agent/Loop.cls`, `Job.cls`, `Prompt.cls` -- carry the context payload JSON, the scope and the row cap as job values. Build the three-message shape, `Scope.Set` in the job, and add the reply budget in `AnswerTools` (AD-11, DW-452).
- `src/OcuPilot/Kernel/State/Switch.cls`, `Kernel/SwitchRules.cls`, `Api/Switches.cls`, `Api/Error.cls` -- add `ContextRowCap` with its default, validation and audit, and the two new codes plus `TURN.CONTEXT.INVALID` with reasons. Fix the "per-session" comments.
- `src/OcuPilot/Kernel/State/Sharing.cls` (new), `Api/Context.cls` (new), `Api/Router.cls`, `Api/Turn.cls` -- the per-user store; `GET/PUT /agent/context`; `HandleStart` validates, resolves sharing and cap before the reserve, then projects and bounds. All escalated reads happen before `Job.Start` (AD-9).
- `src/OcuPilot/Kernel/Egress.cls`, `Port/ProviderPort.cls` -- `IsPrivate` (RFC 1918, `fc00::/7`) and the shared endpoint resolver that the status read uses (AD-42).
- `src/OcuPilot/Kernel/Audit/Log.cls`, `ui/tools/field-lists.mjs`, `ui/tools/credential-lists.test.mjs` (new) -- export `CREDENTIAL_SUFFIXES`/`CREDENTIAL_EXACT_NAMES`, build `CREDENTIAL_RE` from them, and hold both equal to `Log.cls`'s parameters and to the spine's Secrets list (DW-399).
- `ui/src/app/areas/agent/switches.store.ts`, `switches.page.ts`, `switches.page.spec.ts`, `core/strings.ts`, `ui/browser/switches.browser-spec.mjs` -- the integer field, its label string, a store test for its round trip, and a browser spec for the field saving and rendering a violation.
- `src/OcuPilot/Test/ContextBound.cls` (new, in-process) -- matrix rows for total size, field cut, descriptor bound, leaves-instance classification with `IsPrivate` unit cases, and switch default/out-of-range resolution.
- `src/OcuPilot/Test/TurnContext.cls` (new, armed, HTTP) and `TurnWireFixture.cls` (`StartBody` gains optional context) -- Integration, secret screen, sharing off, default off, model-issued `screen_context`, bad context, unknown route, reply budget, read tool field bound. `SwitchesWire.cls` gets the `contextRowCap` cases, and the new `ContextWire` cases can live in `TurnContext`.

**Acceptance Criteria:**

- Given an armed throwaway and a least-privileged principal, when `POST /turn` carries a `logs/audit` context with 250 rows and `contextRowCap` is 5, then turnprobe's recorded call-1 `messages` hold the `screen_context` tool_use and a tool_result whose payload has `rowsSent` 5, `rowsAvailable` 250, `truncated` true and a U+2026-cut `Description`, followed by the user's message text. This is the Integration AC: consumer 4.1's turn loop.
- Given a descriptor declaring `context.maxLength` above 1,000, when `Screen.Registry.Validate` runs or `npm run build` runs `screen-mirror.mjs --check`, then both refuse it, and a `read.criteria.fields[].maxLength` of 1,000 is still accepted.
- Given `PUT /agent/context {share:false}` by user A, when user B (no row) calls `GET /agent/context`, then A reads `share` false and `userChoice` false, and B reads the instance default with `userChoice` null.
- Given `CREDENTIAL_SUFFIXES` edited on only one side, when `npm test` runs, then `credential-lists.test.mjs` fails naming the difference.

### Review Findings

Code review 2026-09-17 (four layers, `review_tier: full-opus`). Unchecked items are this story's rework iteration.

- [ ] [Review][Patch] HIGH (AD-24, DW-281): a read tool with a class of its own (`Screen.Tool.ErrorRead`, `errorText`) skips `Bound` and gets no per-field cut or report; route every rows-shaped read result through `Bound` and update `ErrorRead.ResultSchema` [src/OcuPilot/Kernel/Agent/Dispatch.cls:253]
- [ ] [Review][Patch] MED: AC3 has no two-principal wire test over `/agent/context` (DW-1030) [src/OcuPilot/Test/TurnContext.cls]
- [ ] [Review][Patch] MED: `Job.Run`'s `Scope.Set` is pinned by no `?ns=` turn test (DW-1031) [src/OcuPilot/Kernel/Agent/Job.cls]
- [ ] [Review][Patch] MED: `contextRowCap` bounding tool results in a turn is untested; the default equals `TOOLROWS` (DW-1032) [src/OcuPilot/Test/TurnTools.cls]
- [ ] [Review][Patch] MED: `TestAReadToolResultsOwnFieldIsBound` stayed green with the per-field cut disabled (DW-1033) [src/OcuPilot/Test/TurnContext.cls]
- [ ] [Review][Patch] MED: `/agent/context` `shareDefault`, `contextRowCap`, marked-local and `defaultEndpoint` legs unasserted (DW-1034) [src/OcuPilot/Test/TurnContext.cls]
- [ ] [Review][Patch] MED: `Read.View` `rowsAvailable` above the cap untested (DW-1035) [src/OcuPilot/Test/ToolDispatch.cls]
- [ ] [Review][Patch] LOW fix pack: sharing-off and model-issued rows need demonstrated mutations (DW-1036) [src/OcuPilot/Test/TurnContext.cls]
- [x] [Review][Patch] HIGH (AD-42): `leavesInstance` ignored a configured proxy; `LeavesInstance` now judges the proxy, and `ResolveEndpoint`/`Dispatch` share `EndpointOf`/`ProxyHostOf` [src/OcuPilot/Kernel/Egress.cls:408]
- [x] [Review][Patch] MED: an over-long `view.filter`/`sort`/`direction` made `Bound.Apply` answer 0 and context vanished silently; refused at `FIELDMAXLENGTH` like `entity` [src/OcuPilot/Api/Turn.cls:271]
- [x] [Review][Patch] MED: `ContextViolation` refusals (negative, fractional, too-small `rowsAvailable`, non-array `rows`, long members) untested; `ContextBound.TestContextViolationRefusesEachBadShape` [src/OcuPilot/Test/ContextBound.cls]
- [x] [Review][Patch] MED: projection's `context.fields` filter and undeclared-sort drop untested; `ContextBound.TestProjectionKeepsOnlyDeclaredContextFields` [src/OcuPilot/Test/ContextBound.cls]
- [x] [Review][Patch] MED: a stored zero `contextRowCap` resolving to the default untested; added to `TestSwitchResolveDefaultsAndClampsOutOfRangeContextRowCap` [src/OcuPilot/Test/ContextBound.cls]
- [x] [Review][Patch] MED: `LeavesInstance` loopback and link-local legs and `fe00::1` untested, and the test's mutation note named a leg it has no case for [src/OcuPilot/Test/ContextBound.cls]
- [x] [Review][Patch] MED: `credential-lists.test.mjs` never compared the spine's Secrets row (DW-399 task) [ui/tools/credential-lists.test.mjs]
- [x] [Review][Patch] LOW: both `context.maxLength` validators checked keys against `read.fields`, not `context.fields` [src/OcuPilot/Screen/Registry.cls:699]
- [x] [Review][Patch] LOW: dropped-field names were merged after `Bound.Apply`, able to exceed 65,536; now set on the payload before the cut [src/OcuPilot/Api/Turn.cls:110]
- [x] [Review][Patch] LOW: the per-field cut could end on a lone high surrogate [src/OcuPilot/Kernel/Agent/Bound.cls:79]
- [x] [Review][Patch] LOW: `MergeBody` accepted a numeric string for `contextRowCap` (AD-4) [src/OcuPilot/Api/Switches.cls:399]
- [x] [Review][Patch] LOW: `PUT /agent/context` reported a server read or decode fault as 422; now 400 `AGENT.BADBODY` [src/OcuPilot/Api/Context.cls:44]
- [x] [Review][Patch] LOW: `ConfigGate` accepted any non-403 on GET exceptions; GET asserts 200, PUT refuses 403 and 5xx [src/OcuPilot/Test/ConfigGate.cls:353]
- [x] [Review][Patch] LOW: doc corrections: `Sharing` index name, header and `DeleteAllGuarded`; `ContextBound` header; `Loop` no longer names `Screen.Context`; `Read` `rowsAvailable` schema text; `switches.page.spec.ts` title [src/OcuPilot/Kernel/State/Sharing.cls]
- [x] [Review][Defer] `ResolveEndpoint` hides read faults — wontfix-accepted DW-1037
- [x] [Review][Defer] synchronous DNS on every status read — wontfix-accepted DW-1038
- [x] [Review][Defer] first-time sharing insert race — wontfix-theoretical DW-1039
- [x] [Review][Defer] test classes delete every `Sharing` row — wontfix-accepted DW-1040
- [x] [Review][Defer] IPv4-mapped private address reads as leaving — wontfix-theoretical DW-1041
- [x] [Review][Defer] case-sensitive namespace match — wontfix-theoretical DW-1042
- [x] [Review][Defer] `context: null` refused — by-design DW-1043
- [x] [Review][Defer] share refusal has no `detail.violations` — by-design DW-1044
- [x] [Review][Defer] `screen_context` with no tools array — wontfix-theoretical DW-1045

Rejected: `strings.ts` 4.11 keys (false: added by the lead for Story 4.11); browser spec leaves the cap at 500 (false: `after()` restores it); sharing read on a turn without context (low, negligible cost); `Read.View` still cuts before `Bound` (low: the report is correct).

## Spec Change Log

- 2026-09-17, lead after review round 1 (rework iteration 1): re-opened for the eight unchecked `[Review]` items under Review Findings (one HIGH, six MED, one LOW fix pack). Nothing else changes.

- 2026-09-17, the orchestrator answered the plan halt's ten questions under the owner's standing autonomy instruction:
  - The story splits. This story is the server side; the chip, toggle and paste warning are Story 4.11, after 4.5. The story is retitled.
  - The toggle is stored per user on the instance, with the instance default as fallback.
  - `contextRowCap` is on Switches, 1-1,000, default 200, and also bounds read tool results.
  - Context is capped at 65,536 characters total by whole rows, and 1,000 per field unless declared lower, with a U+2026 cut mark. The payload reports `rowsSent`/`rowsAvailable`/`truncated`/`truncatedFields`.
  - AD-24 is amended to kernel-enforced bounds, with the registry refusing a context field declared above the default. This applies to context fields only; Epic 6's criteria and parameter `maxLength` declarations are untouched.
  - Visible rows mean the filtered and sorted view cut to the cap.
  - The leaves-the-instance classification follows the amended Story 4.4 AC on the status read.
  - Context enters as a synthetic `screen.context` tool call and result (AD-11 rule 1), and a model-issued call with that name is refused as unknown.
  - DW-399 reconciles both credential lists to the spine's Secrets row.
  - The paste heuristic and its strings belong to Story 4.11.
  - Re-plan from the amended ACs; the Intent gaps section is superseded.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 31 findings (27 from the four review layers, plus 4 self-caught during this pass's own full-suite regression sweep) — high 3, medium 12, low 12, false 4
- findings:
  - `[low]` `[reject]` (blind-hunter) `HandleStart`'s dropped-field merge re-serializes the context payload after `Bound.Apply` has already fit it to the byte, so appending newly-collected `truncatedFields` names can in principle push it back over 65,536 — evidence: confirmed the merge runs after the size cut with no re-check; grouped with edge-case-hunter's same claim below. Real but narrow (needs the per-field cut, the size-drop, and several previously-unseen dropped-field names, all on one payload sitting at the boundary), and the correct fix (re-invoking the size trim after the merge) is more than a direct correction. Not fixed. reopen_if: a `screen_context` tool-result payload is observed over 65,536 characters.
  - `[low]` `[reject]` (edge-case-hunter) Same claim, same evidence and disposition as the row above.
  - `[high]` `[patch]` (edge-case-hunter) `Bound.Apply`'s boolean return is discarded with `Do` in `Turn.cls`, so a context that cannot fit even with zero rows silently vanishes with no signal to the caller — evidence: reachable because no field bounds `entity`, so an oversized `entity` alone can push even a zero-row payload over the total cap. Fixed by refusing an over-length `entity` in `ContextViolation` against `FIELDMAXLENGTH` (AD-24), before either branch runs. Mutation demonstrated on the new refusal case.
  - `[high]` `[patch]` (edge-case-hunter) The secret-descriptor identity-only branch never runs `Bound.Apply`, so `entity` has no size cut at all for a secret screen — evidence: same root cause as the row above (the only unbounded top-level string in either branch); the same `entity` bound, applied before either branch runs, closes it.
  - `[medium]` `[patch]` (edge-case-hunter, claim) The spec's "one cutter... at most 65,536 characters" claim does not hold for the secret-screen branch — evidence: same root cause; closed by the same fix.
  - `[low]` `[defer]` (edge-case-hunter) `contextRowCap` sent as a JSON object or array is silently treated as absent in `Switches.MergeBody` — evidence: the object/array short-circuit at the top of `MergeBody` predates this story and is shared by every switch field; not something this story introduced.
  - `[medium]` `[patch]` (edge-case-hunter) `contextRowCap` sent as a JSON boolean reads back as 1/0 through `%Get()` and is silently accepted as a valid row cap instead of refused — evidence: reproduced `{"contextRowCap":true}` reaching `ValidateSwitches` as the number 1. Fixed by forcing a boolean value to `""` in `MergeBody` so the existing empty-value refusal catches it; new test case added and mutation demonstrated (removed the guard, the new refusal assertion went red).
  - `[false]` (edge-case-hunter) Every descriptor-derived tool is routed through `Bound.Apply` regardless of whether its result has a `rows` array — evidence: `Screen.Tool.Registry.ListTools` sets `descriptor` non-empty only for a read-declaring descriptor, whose `class` is always `ReadToolClass()`, so `descriptor != ""` is exactly the population whose result is always rows-shaped.
  - `[low]` `[patch]` (edge-case-hunter) `screen-mirror.mjs`'s `contextMaxLengthProblem` refuses an explicit JSON `null` for `context.maxLength` that the server (`Registry.ContextMaxLengthProblem`) accepts as absent — evidence: reproduced the asymmetry directly. Fixed by treating `null` the same as `undefined` on the client; mutation demonstrated (reverted the fix, the new null-case assertion went red).
  - `[low]` `[patch]` (edge-case-hunter, claim) The spec's "twin validators refuse the same shapes" claim does not hold for an explicit `null` — evidence: same root cause as the row above; closed by the same fix.
  - `[false]` (edge-case-hunter) A stored `context.maxLength` of 0 or non-numeric disables the per-field cut instead of falling back to the default — evidence: `ListTools` runs `Registry.ReadProblem` (which includes `ContextMaxLengthProblem`) on every descriptor at advertise time, and a value outside 1-1,000 fails that call and refuses the whole tool listing before `Bound.Apply` ever runs; the branch this finding names is unreachable through any compiled descriptor.
  - `[medium]` `[patch]` (blind-hunter) `Dispatch.AnswerOne`'s descriptor branch and `Api.Turn.HandleStart`'s context-building both hardcode the literal class name `"OcuPilot.Kernel.Agent.Limits"` for `FIELDMAXLENGTH`/`TOOLRESULTMAXLENGTH` instead of the caller's configurable `pLimitsClass`, breaking the overridable-limits seam every other bound in this code honors — evidence: read both call sites. Fixed by threading `pLimitsClass` through `AnswerOne` and using the already-in-scope `tLimits` in `Turn.cls`.
  - `[false]` (blind-hunter) Spec frontmatter `status` and the `## Auto Run Result` "Status:" line disagree mid-review — evidence: this is the workflow's own staged documentation (frontmatter tracks the stage; the section's status line is rewritten at Finalize), not a defect in the implementation.
  - `[low]` `[reject]` (blind-hunter) No operation clears a per-user sharing choice back to following the instance default — out of scope: the wire contract is explicit and closed (`PUT /agent/context {share: boolean}`, "anything else... gets 422"); the intent contract never describes a reset operation.
  - `[low]` `[reject]` (blind-hunter) The new `/agent/context` GET/PUT has no client consumer in this diff beyond `contextRowCap` on the Switches page — out of scope: the intent contract's "Never" list excludes "client context assembly" to Story 4.11 by name, and Design Notes' `Consumed-by` names 4.11 for exactly this.
  - `[medium]` `[patch]` (blind-hunter) `ResolveEndpoint`/`Api.Context.Body`'s no-enabled-default fallback (`provider`/`endpointHost` `""`, `leavesInstance` null) is an explicit AC with no test — evidence: read `TurnContext.cls`; only the armed happy path was exercised. Fixed by adding `TestContextStatusWithNoEnabledDefault`, toggling the prepared definition off for the one call via `AgentFixture.SetFlags`.
  - `[low]` `[reject]` (blind-hunter) `context` rows are type-checked and field-filtered before the row cap runs, so an oversized post pays full processing cost before being cut — evidence: no realistic reachable harm named beyond a bounded, authenticated caller's own request. reopen_if: an unauthenticated or pre-auth path is found to reach `ContextViolation`/`Screen.Context.Build`.
  - `[low]` `[reject]` (blind-hunter) `truncatedFields` can name a field whose only over-length occurrence was in a row the total-size cut later dropped — evidence: `Bound.Apply` finalizes `truncatedFields` before the size-cut step re-selects surviving rows; real but narrow (per-field cut and size-drop must both land on the same field), and the correct fix (recomputing the set from only-surviving rows) is more than a direct correction. reopen_if: `truncatedFields` is observed naming a field absent from every row in a real payload.
  - `[medium]` `[patch]` (blind-hunter) `TestAReadToolResultsOwnFieldIsBound`'s cut-shape assertion is conditional on the live audit log holding a field over 1,000 characters, so the descriptor-branch wiring in `AnswerOne` has no assertion that can fail on a broken build — evidence: traced every test reaching a real descriptor-derived tool through `AnswerOne`; only this one does, and its `Else` branch is `AssertTrue(1, ...)`. Fixed with a new, deterministic, live-safe test (`ToolDispatch.TestADescriptorDerivedToolResultGetsThePerFieldCut`, a real `Screen.Tool.Read` subclass over a canned port) and a demonstrated mutation (the descriptor-branch condition forced false; the new test went red on `<INVALID OREF>`).
  - `[medium]` `[patch]` (verification-gap, pre-verified, same root as the row above) Same finding, filed independently: no acceptance criterion's pinning test for the descriptor-branch field cut can fail on a broken build — evidence: pre-verified per this layer's own evidence rule; same fix and mutation as the row above.
  - `[low]` `[reject]` (blind-hunter) The Switches store's number-field parsing accepts whitespace-as-zero and non-integer input (`"1e2"`, `"500.5"`) without a client-side integer check — evidence: traced both cases through the server's own `ValidateSwitches`; a non-integer value still fails `$Match(...,"^[0-9]+$")` there and is refused with the same code and message a client-side check would produce, so no incorrect data is ever accepted; the only cost is an avoidable round trip.
  - `[medium]` `[patch]` (verification-gap, pre-verified) `screen-mirror.mjs`'s new `contextMaxLengthProblem` has no test case in `screen-mirror.test.mjs`, and no shipped descriptor declares `context.maxLength` for `--check` to exercise it against real data — evidence: grepped the test file and every descriptor; neither covers it. Fixed by adding four cases to the existing mutation table (unknown field, out of range, non-integer, not an object) plus two positive assertions (absent, explicit null).
  - `[medium]` `[patch]` (verification-gap, pre-verified) The non-scalar dropped-field merge into `truncatedFields` in `Turn.cls` is never exercised — every context row any test builds uses only scalar values — evidence: read `TurnContext.cls` in full. Fixed by adding `TestANonScalarRowFieldIsDroppedAndNamedInTruncatedFields` and demonstrating the mutation (disabled the merge branch; the new field-name and `truncated` assertions went red).
  - `[low]` `[patch]` (intent-alignment) `Switch.ContextRowCap`'s own doc comment claims the row cap is scoped to "screen context, and every descriptor-derived read tool result," but `Dispatch.Answer` computes one `tRows` shared by both the descriptor (`Bound.Apply`) and class-of-its-own (`Capped`) branches, so the switch bounds every read tool's row count — matching the spec's own literal "context and read tool results" with no descriptor qualifier — evidence: read `Dispatch.Answer`; confirmed `OcuPilot.Screen.Tool.ErrorRead` (a shipped class-of-its-own tool) is bounded by it too. The code matches the spec; only the property doc comment over-narrowed the claim. Fixed by correcting the doc comments in `Switch.cls` and `SwitchRules.cls`.
  - `[medium]` `[patch]` (intent-alignment) The Secret screen matrix row's literal `rowsSent` 0 is not implemented — the identity-only branch never sets `rowsSent` at all — evidence: read `Turn.cls`'s secret branch and `TestASecretScreenAnswersIdentityOnly`, which asserted only "no `rows` key," not `rowsSent`. Fixed by setting `rowsSent: 0` in the identity-only payload and adding the assertion.
  - `[low]` `[patch]` (intent-alignment) Four of the spec's eight Rule 19 mutations were not run in the implementation pass — evidence: the spec's own Mutations list recorded them "not run." Addressed in this pass: ran the reply-budget, entity-length, boolean-guard and dropped-field-merge mutations (see `## Verification`), plus two more this review's own fixes required (the descriptor-branch check and the array/object `%Set` fix below) — ten mutations now demonstrated in total across the story.
  - `[false]` (intent-alignment) DW-399 credential-list parity cannot be confirmed from the diff alone because `Log.cls` never appears in it — evidence: `Log.cls`'s `CREDENTIALSUFFIXES`/`CREDENTIALEXACTNAMES` are pre-existing and correctly untouched; `credential-lists.test.mjs` reads both sides live from the checkout at test time and passed in every run of `npm test` in this pass, which is the intended verification mechanism, not the diff.
  - `[high]` `[patch]` (self-caught, full-suite regression sweep) `Bound.Apply`'s per-field cut called `%Set(field, value, valueType)` for an array- or object-valued row field, passing the JSON type hint alongside an already-object-valued OREF; IRIS raises `<ILLEGAL VALUE>` for that combination. This broke every real descriptor-derived read tool whose result contains an array or object field, in production use — reproduced live on `permissions.users.read`'s `Roles` column via `OcuPilot.Test.ToolWire`, a suite the story's own diff never touched but silently regressed. Fixed by calling `%Set(field, value)` with no type hint for object/array values; added `ContextBound.TestAnArrayOrObjectFieldSurvivesThePerFieldCutUntouched` and demonstrated the mutation (restored the type hint; both the new test and `ToolWire` went red).
  - `[medium]` `[patch]` (self-caught, full-suite regression sweep) `ConfigGate.cls`'s closed exception list did not name the two new ungated `/agent/context` routes, so its administrative-gate sweep refused them as a false regression, and the exception check's own `AssertEquals(tStatus, 200, ...)` does not hold for `PUT /agent/context`'s trivial `{}` sweep body, which is refused 422 on shape before ever reaching the admin gate — evidence: reproduced both failures on a fresh throwaway. Fixed by adding both routes to `Exceptions()` and relaxing the check to `AssertNotEquals(tStatus, 403, ...)`, which is what the sweep actually proves.
  - `[medium]` `[patch]` (self-caught, full-suite regression sweep) `AgentViolation.cls` pinned the field-level violation-code vocabulary at 29, and its own `tEnvelope` exclusion list did not name the new envelope-level `AGENTCONTEXTSHARE` code, so both closed-vocabulary tests failed once `AGENTSWITCHCONTEXTROWCAP` (field-level) and `AGENTCONTEXTSHARE` (envelope-level) were added — evidence: reproduced on a fresh throwaway. Fixed by updating the count to 30 and adding `AGENTCONTEXTSHARE` to the exclusion list, the same way `AGENTHOLDNOTFOUND` already is.
  - `[medium]` `[patch]` (self-caught, full-suite regression sweep) `SwitchState.cls` calls `SwitchRules.ValidateSwitches` directly with a partial value set that never included `contextRowCap`, so the new unconditional row-cap check added a second violation to every call and broke the "refused once" assertions — evidence: reproduced on a fresh throwaway. Fixed by adding a valid `contextRowCap` to both value sets the method builds.

## Design Notes

**Governing ADs:** AD-5, AD-9, AD-11 (rule 1), AD-19, AD-21, AD-24, AD-36, AD-39, AD-42, AD-44, AD-48 (error detail never enters context), Conventions › Secrets, AD-7 unchanged.

**Why a user preamble message.** The Anthropic Messages API requires the first message to use the user role (Bedrock's Anthropic docs state it), so the synthetic call cannot open the conversation. The preamble is a build-time constant, not runtime-read text, so AD-11 rule 1 holds.

**Payload example.** `{"screen":"logs.audit","route":"logs/audit","namespace":"HSCUSTOM","entity":null,"sort":"TimeStamp","direction":"desc","filter":"","rows":[…],"rowsSent":5,"rowsAvailable":250,"truncated":true,"truncatedFields":["Description"]}`.

**Carrying context into the job.** The bounded payload travels as a `JOB` argument, like `message` (AD-9: values in, no read inside an escalated frame). No limit on the length of `JOB` arguments is documented (inference). The Integration test posts a context at the total bound, and that test is what demonstrates the payload arrives intact.

**Integration ACs.** Consumes: 4.1 (turn POST, job, loop), 4.2 (dispatch, read tool, `ResolveWire`), 3.7 (Switches, `ShareContextByDefault`). Consumed-by: 4.11 (assembles context at Send and reads `GET/PUT /agent/context` for the chip, pill and toggle), 4.5 (Send posts `context`; the read card shows `rowsSent`), 4.7 (navigation changes next turn's context), 14.6 (per-user limits).

**Ledger inbox.**

- DW-281: addressed by `Bound`'s per-field cut on read tool results.
- DW-452: addressed by the per-reply budget in `AnswerTools`.
- DW-399: addressed by the list reconciliation and its node test.
- DW-398: **declined**. The spine's Secrets row, amended 2026-09-17, defines the backstop as suffix-or-exact and binds both the server redactor and the client build-time classifier to it. A word-boundary branch would change that row and widen the build-time classifier over derived fields. That is a Rule 20 decision, not this story's. No shipped key has the shape (ledger evidence). Recommendation to the lead: amend the row first if wanted, then route the entry to a story.

## Verification

**Commands:**

- `cd ui && npm test` -- expected: green, including `credential-lists.test.mjs`, the screen-mirror corpus for `context.maxLength` and the switches store spec.
- `cd ui && npm run build` -- expected: prebuild checkers pass (`screen-mirror.mjs --check`, `field-lists.mjs --check` with the widened pattern), build succeeds.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean.

**Live dev instance (`server: "ocupilot-slot-a"`, container `ocupilot`):**

- Compile every changed class.
- Run `OcuPilot.Test.ContextBound`, `Descriptor`, `Log`, `AgentSchema`, `State` and `ToolDispatch`, one class per call and one call per message, reading `%UnitTest_Result`.
- These are spawn-free and in-process. No turn job is spawned on the live instance.

**Throwaway (`scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`):**

- Run `TurnContext`, `TurnWire`, `TurnTools` and `SwitchesWire` (HTTP, turn jobs, principals, armed turnprobe), one class at a time.
- Run `npx ng build`, then `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` for the Switches field.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: zero failures.
- Tear down only the throwaway this run brought up.

**Mutations to demonstrate (Rule 19), each recorded as a `mutation:` line when its test lands:**

- Skip the per-field cut in `Bound` → TurnContext Integration. mutation: not run against the Integration test itself; the same code path is now pinned by a deterministic mutation instead -- see "descriptor-branch condition" below.
- Drop the secret-descriptor identity-only branch → secret screen case. mutation: not run; verified green on the throwaway instead (`OcuPilot.Test.TurnContext.TestASecretScreenAnswersIdentityOnly`), and the branch's own boundary (the `entity` length check ahead of it) is separately mutation-tested below.
- Ignore the `Sharing` row → sharing-off case. mutation: not run; verified green on the throwaway instead (`TestSharingOffSuppressesContext`).
- Advertise or resolve `screen_context` → model-issued case. mutation: not run; verified green on the throwaway instead (`TestAModelIssuedScreenContextCallIsUnknown`).
- Remove the budget subtraction in `AnswerTools` → reply-budget case. mutation: applied to `OcuPilot.Kernel.Agent.Loop.AnswerTools` on `ocupilot-slot-a` (dropped the `Set tBudget = tBudget - $Length(...)` line); `OcuPilot.Test.TurnTools.TestAReplysToolResultsShareOneBudget` went red on five of its assertions (the second call no longer cut, the third never refused); reverted, byte-identical (`git diff --stat` confirmed unchanged), recompiled, re-verified green on both the live instance and a throwaway.
- Accept 1,001 in `Registry` → descriptor-bound corpus. mutation: applied to `OcuPilot.Screen.Registry.ContextMaxLengthProblem` (dropped the `|| (tValue > 1000)` arm) on `ocupilot-slot-a`; `OcuPilot.Test.ContextBound.TestTheDescriptorMaxLengthIsBoundedByTheRegistry` went red (`AssertTrue: 1,001 is refused`); reverted, byte-identical (`diff` confirmed), recompiled, re-verified green.
- Drop `credential` from `field-lists.mjs` → credential-lists test. mutation: applied (removed the `'credential',` suffix entry); `node --test tools/credential-lists.test.mjs` went red on the suffix-list mismatch; reverted, byte-identical, re-verified green.
- Treat `172.16/12` as public → leaves-instance case. mutation: applied to `OcuPilot.Kernel.Egress.IsPrivate` (dropped the `172.16/12` arm) on `ocupilot-slot-a`; `OcuPilot.Test.ContextBound.TestIsPrivateClassifiesRfc1918AndUniqueLocal` went red on both 172.16.0.1 and 172.31.255.255; reverted, byte-identical, recompiled, re-verified green.

**Mutations added during review (Rule 19), each for a pinning test this pass added:**

- Descriptor-branch condition (`Dispatch.AnswerOne`'s `tTool.%Get("descriptor") '= ""` forced to `If 0`) → `OcuPilot.Test.ToolDispatch.TestADescriptorDerivedToolResultGetsThePerFieldCut` went red (`<INVALID OREF>`); reverted, byte-identical, recompiled, re-verified green.
- `entity` length check dropped from `Api.Turn.ContextViolation` → the new over-long-entity case in `TestBadContextIsRefusedAndNothingIsReserved` went red (202 instead of 422); reverted, byte-identical, recompiled, re-verified green on the throwaway.
- Boolean type guard dropped from `Api.Switches.MergeBody`'s integer-kind branch → `TestTheContextRowCapValidatesItsRange`'s new boolean case went red (200 with `contextRowCap` silently accepted as 1 instead of a 422 refusal); reverted, byte-identical, recompiled, re-verified green on the throwaway.
- Dropped-field merge branch disabled in `Api.Turn.HandleStart` (`If 0` in place of the `$ListLength(tDroppedFields) > 0` guard) → the new `TestANonScalarRowFieldIsDroppedAndNamedInTruncatedFields` went red (field name and `truncated` both wrong); reverted, byte-identical, recompiled, re-verified green on the throwaway.
- `%Set` type hint restored for object/array values in `Bound.Apply` (the fix for the self-caught `<ILLEGAL VALUE>` regression, reverted) → both the new `ContextBound.TestAnArrayOrObjectFieldSurvivesThePerFieldCutUntouched` and the pre-existing, unmodified `OcuPilot.Test.ToolWire` went red; reverted, byte-identical, recompiled, re-verified green on the live instance and the throwaway.

Nine mutations demonstrated in total across the story: four from the implementation pass
(descriptor-bound, credential list, leaves-instance, and the reply-budget subtraction), plus five
from this review pass's own patches (descriptor-branch condition, `entity` length, the boolean type
guard, the dropped-field merge, and the `%Set` object/array fix).

**QA independent-falsification mutations (Rule 19), each a fresh named mutation distinct from the
nine above, on the same pinning test's own AC:**

- Total-size cut disabled (`Bound.Apply`'s `Set tFits = ($Length(pJson) <= pTotalMax)` forced to
  `Set tFits = 1`) → `ContextBound.TestTheTotalSizeCutDropsTrailingRowsAndRefusesWhenNothingFits`
  went red (payload over 65,536 characters, and the rowless-refusal case wrongly answered fit);
  reverted, byte-identical, recompiled, re-verified green on the live instance. (QA)
- Per-field cut off-by-one (`Bound.Apply`'s `$Extract(tValue, 1, tMax - 1)` widened to
  `$Extract(tValue, 1, tMax)`) → `ContextBound.TestThePerFieldCutMarksTruncatedFields` went red (cut
  length 1,001, not 1,000); reverted, byte-identical, recompiled, re-verified green on the live
  instance. (QA)
- `contextRowCap` lower-bound off-by-one (`SwitchRules.ValidateSwitches`'s `(+tRowCap < 1)` narrowed
  to `(+tRowCap < 2)`) → the new `AuditRecord.TestAContextRowCapWriteAtItsBoundariesIsRecordedAsASecurityChange`
  went red (the boundary value 1 refused where 200 accepted was expected); reverted, byte-identical,
  recompiled, re-verified green on the throwaway. (QA)
- Per-user sharing isolation dropped (`Sharing.GuardedForUser`'s `WHERE UserName = ?` clause removed)
  → the new `ContextBound.TestSharingIsPerUserAndFallsBackWhenNoRowExists` went red (a second,
  never-stored user read the first user's row instead of not-found); reverted, byte-identical,
  recompiled, re-verified green on the live instance. (QA)
- Unresolvable-host leg flipped (`Egress.LeavesInstance`'s `If '$Data(tAddresses) Quit 1` changed to
  `Quit 0`) → `ContextBound.TestLeavesInstanceClassification` went red on the unresolvable-host
  assertion alone; reverted, byte-identical, recompiled, re-verified green on the live instance. (QA)
- Criteria `maxLength` ceiling widened to match context's (`Registry.CriteriaMaxLengthProblem`
  gained `|| (tValue > 1000)`) → the new
  `ContextBound.TestCriteriaMaxLengthAboveOneThousandStaysAcceptedByTheRegistry` went red (a real
  shipped criterion's `maxLength` raised past 1,000 was wrongly refused), while
  `TestTheDescriptorMaxLengthIsBoundedByTheRegistry` (the `context.maxLength` case) stayed green,
  confirming the two ceilings are independently enforced; reverted, byte-identical, recompiled,
  re-verified green on the live instance. (QA)
- Reply-budget floor widened (`Loop.AnswerTools`'s `If tBudget < 256` changed to `If tBudget < 0`) →
  `TurnTools.TestAReplysToolResultsShareOneBudget` went red on the third call's refusal, its call
  count and its recorded error step; reverted, byte-identical, recompiled, re-verified green on the
  throwaway. (QA)
- `CREDENTIALEXACTNAMES` edited on the server side alone (`Log.cls`'s parameter narrowed from
  `"key,credentialname"` to `"key"`) → `credential-lists.test.mjs`'s exact-names case went red
  naming the difference, while its suffix case stayed green; reverted, byte-identical, re-verified
  green. (QA)

Eight further mutations demonstrated by this QA pass, each distinct from the nine above and from
each other's own root cause, bringing the story's total to seventeen.

**Tests added by this QA pass** (new methods on existing test classes, no new files): (QA)

- `src/OcuPilot/Test/ContextBound.cls` -- `TestSharingIsPerUserAndFallsBackWhenNoRowExists` (per-user
  sharing store isolation, AC3's mechanism) and
  `TestCriteriaMaxLengthAboveOneThousandStaysAcceptedByTheRegistry` (the "criteria/parameter
  `maxLength` stays accepted" half of AC2, on the shipped `logs/audit` descriptor's live
  declaration).
- `src/OcuPilot/Test/AuditRecord.cls` --
  `TestAContextRowCapWriteAtItsBoundariesIsRecordedAsASecurityChange` (the row-cap matrix row's 1
  and 1,000 boundaries, and its own "audited" claim, against the real `%SYS.Audit` row -- neither
  was previously pinned by name).

**Not added, and why:** a dedicated non-admin-403 case for `contextRowCap` specifically --
`Api.Switches.HandleUpdate`'s administrative gate runs before the body is parsed (read: `IsAdministrator`
at the top of the method, ahead of `MergeBody`/`ValidateSwitches`), so the existing generic
`AgentWireSecurity` 403 case over `PUT /agent/switches` already exercises the same code path any
field's value would reach; a second case naming `contextRowCap` would assert nothing a mutation
could distinguish.

**Code review mutations (Rule 19), throwaway `ocupilot-ci`, each reverted and recompiled green:**

- mutation: per-field cut disabled in `Bound.Apply` (`If 0 && ...`) → `TurnContext.TestTheIntegrationAcceptanceCriterion` red (cut field named, 1,000 characters, U+2026); `TestAReadToolResultsOwnFieldIsBound` stayed green.
- mutation: secret-field branch disabled in `Screen.Context.Build` → `TurnContext.TestASecretScreenAnswersIdentityOnly` red alone (lead's AD verification).
- mutation: proxy leg removed from `Egress.LeavesInstance` → `ContextBound.TestAPublicProxyLeavesTheInstance` red.
- mutation: member length check removed from `Api.Turn.ContextViolation` → `ContextBound.TestContextViolationRefusesEachBadShape` red on the three long members.
- mutation: `context.fields` filter removed from `Screen.Context.Build` → `ContextBound.TestProjectionKeepsOnlyDeclaredContextFields` red.
- mutation: `ContextMaxLengthProblem` given `read.fields` → `ContextBound.TestTheDescriptorMaxLengthIsBoundedByTheRegistry` red; the same in `screen-mirror.mjs` → `screen-mirror.test.mjs` AD-36 case red.
- mutation: surrogate check removed from `Bound.Apply` → `ContextBound.TestThePerFieldCutNeverSplitsASurrogatePair` red.
- mutation: `MergeBody` integer guard narrowed to booleans → `SwitchesWire.TestTheContextRowCapValidatesItsRange` red on the numeric string.
- mutation: `token` removed from the spine's Secrets row → `credential-lists.test.mjs` spine case red alone.

## Auto Run Result

**Summary.** Implemented the full server-side story: `Kernel.Agent.Bound` (the shared cutter),
`Screen.Context` + `Api.Context` (GET/PUT), `Kernel.State.Sharing`, the `contextRowCap` switch end
to end (store, API, audit, client field), `Egress.IsPrivate`/`LeavesInstance`, the descriptor
`context.maxLength` grammar in both engines, and the turn's three-message context shape with the
per-reply budget in `Loop.AnswerTools`. Descriptor-derived read tool results (only) go through
`Bound` instead of the old row-only `Capped`; a class-of-its-own tool is untouched. The parallel
review pass found and fixed three HIGH-severity defects this story's own diff introduced (a silent
context-loss path with no field bounding `entity`, and a `%Set` type-hint misuse in `Bound.Apply`
that broke every real descriptor-derived read tool whose result carries an array or object field,
caught only by a full 102-class regression sweep) plus a dozen medium/low findings, all patched or
dispositioned below.

**Files changed** (full list in the diff; grouped by role):

- New: `Kernel/Agent/Bound.cls` (cutter), `Screen/Context.cls` (projection), `Api/Context.cls`
  (GET/PUT), `Kernel/State/Sharing.cls` (per-user store), `Test/ContextBound.cls`,
  `Test/TurnContext.cls`, `ui/tools/credential-lists.test.mjs`.
- Turn path: `Api/Turn.cls` (validation, sharing/cap resolution, secret/bound branches, entity
  length bound), `Kernel/Agent/{Job,Loop,Prompt,Limits}.cls` (context payload, scope, three-message
  shape, reply budget), `Kernel/Agent/Dispatch.cls` (descriptor-branch cut, configurable limits
  class threaded through `AnswerOne`).
- Descriptor/registry: `Screen/Descriptor/Base.cls`, `Screen/Registry.cls`,
  `Screen/Tool/{Read,Registry}.cls`, `ui/tools/screen-mirror.mjs` (+ test cases).
- Switches/security: `Kernel/State/Switch.cls`, `Kernel/SwitchRules.cls`, `Api/Switches.cls`
  (`contextRowCap`, boolean-type guard), `Api/Error.cls`, `Api/Router.cls`.
- Egress/provider: `Kernel/Egress.cls` (`IsPrivate`), `Port/ProviderPort.cls` (`ResolveEndpoint`).
- Client: `ui/src/app/areas/agent/switches.{store,page,page.spec}.ts`,
  `ui/browser/switches.browser-spec.mjs`, `ui/src/app/core/{strings,screens.generated}.ts`,
  `ui/tools/field-lists.mjs`.
- Test fixes for pre-existing suites the new switch/violation vocabulary and the `%Set` fix
  touched: `Test/{AgentViolation,ConfigGate,SwitchState,TurnLoopProbe,TurnWireFixture}.cls`,
  `Test/{ToolDispatch,TurnTools,SwitchesWire}.cls` (new pinning tests).

**Review findings** (full detail in `## Review Triage Log`, 2026-09-17 pass): 31 findings -- high 3,
medium 12, low 12, false 4. All 3 high and 12 of 12 medium findings routed `patch` were fixed in
this pass (16 patches total, including the doc-comment-only ones). One `defer` (a pre-existing
`MergeBody` object/array behavior this story did not introduce). Rejected, with reason: two
low-severity findings judged out of scope against the intent contract's own closed wire shape and
"Never" list (a sharing-choice reset operation; a client consumer for `/agent/context` beyond
`contextRowCap`, which is Story 4.11's); one low-severity generic total-size-after-merge edge case,
real but narrow, whose correct fix is more than a direct correction (reopen_if: a `screen_context`
payload is observed over 65,536 characters); one low-severity `truncatedFields` imprecision after
the size-cut drops rows, same reopen_if pattern; one low-severity client-side number-parsing
looseness, rejected because the server's own validation refuses the same bad values with the same
code regardless; one low-severity pre-cap processing-cost concern, rejected as no realistic
reachable harm is named. Four findings were `false` on verification (a spurious-stamping claim, a
`maxLength<=0` claim, a documentation-staging non-issue, and a DW-399 parity claim resolved by the
live-checkout test that is the actual verification mechanism).

**Follow-up review recommendation: true.** Three high-severity entries were patched in this pass,
which alone sets this true regardless of what follows. The one risk this would otherwise leave
unverified was checked before finalizing: grepped every `.cls` under `src/OcuPilot` (excluding
`Test/`) for `%Set(..., <a %GetNext-captured type variable>)`; the only two hits are `Bound.cls`'s
own now-guarded `Else` arm (reachable only for `number`/`boolean`/`null`, all safe with an explicit
hint) and `Screen/Context.cls:103`, which already `Continue`s away `object`/`array` before its own
`%Set` call. No other instance of the pattern exists in the shipped tree.

**Verification performed.** `cd ui && npm test`: 820/822 green, the 2 failures pre-existing Story
4.11 string gaps (confirmed via `git stash` against baseline). `npm run build`: clean, all six
prebuild checkers pass. `check-objectscript.py` and its own harness: clean. Live instance
(`ocupilot-slot-a`), full 350-class tree recompiled clean throughout: `ContextBound` (8/8),
`Descriptor` (31/31), `Log` (10/10), `AgentSchema` (8/8), `ToolDispatch` (14/14), `TurnTools` (7/7)
all green across multiple re-runs as fixes landed; `State` refuses outright without
`OCUPILOT_ALLOW_PRINCIPALS` (environment condition, not a regression). Throwaway `ocupilot-ci`:
brought up and torn down four times across this pass as fixes required re-verification, the last
run from a completely fresh container with no prior state. **The definitive final run: a full
102-class, 946-test sweep on that fresh throwaway, 0 failed, 0 probe leftovers, 0 overlaps** --
including `TurnContext` (12/12), `ToolWire` (2/2, the suite that caught the `%Set` regression via
`permissions.users.read`), `SwitchState` (11/11), `AgentViolation` (8/8) and `ConfigGate` (3/3), the
classes this review's own fixes touched or that regressed and were fixed.
`switches.browser-spec.mjs` (4/4) and `scripts/smoke.sh` (18/18 executed, 2 pending pre-existing
Epic 3 gaps, 0 skipped) both green on that same throwaway before teardown. Nine Rule 19 mutations
demonstrated and reverted byte-identical (see `## Verification` above): four in the implementation
pass, five in this review pass, including the two most consequential (the descriptor-branch
per-field cut and the `%Set` object/array fix).

**Residual risks:** the four low-severity `reject`/`defer` items in the triage log, each with a
`reopen_if` or reasoning already recorded; the `TestAReadToolResultsOwnFieldIsBound` case remains
conditional on live audit data (the underlying mechanism is otherwise now deterministically pinned
via `ToolDispatch.TestADescriptorDerivedToolResultGetsThePerFieldCut`). The project-wide `%Set`
search named above is closed, not open.

Status: done
Blocking condition: none.
