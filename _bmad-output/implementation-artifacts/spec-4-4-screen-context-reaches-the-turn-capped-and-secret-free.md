---
title: 'Story 4.4: Screen context reaches the turn, capped and secret-free'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
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

## Spec Change Log

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

- Skip the per-field cut in `Bound` → TurnContext Integration.
- Drop the secret-descriptor identity-only branch → secret screen case.
- Ignore the `Sharing` row → sharing-off case.
- Advertise or resolve `screen_context` → model-issued case.
- Remove the budget subtraction in `AnswerTools` → reply-budget case.
- Accept 1,001 in `Registry` → descriptor-bound corpus.
- Drop `credential` from `field-lists.mjs` → credential-lists test.
- Treat `172.16/12` as public → leaves-instance case.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
