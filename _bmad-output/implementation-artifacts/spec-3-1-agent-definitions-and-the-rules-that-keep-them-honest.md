---
title: 'Story 3.1: Agent definitions, and the rules that keep them honest'
type: 'feature'
created: '2026-09-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 3's remaining seven stories — the provider adapter, the credential ladder, Test
connection, the Definition form, the first-login gate, the switches and the audit — all read or write
one thing that does not exist yet: a persisted agent definition on the instance, with the rules that
keep it honest. There is no `%Persistent` class for it, no provider vocabulary, no validation service,
and no mutating REST route anywhere in the tree (`Api/Router.cls:61-74` is nine `GET`s).

**Approach:** Add one protected-state class (`OcuPilot.Kernel.State.Agent`, AD-9), one provider
catalog that is the single source of the provider vocabulary and its canonical defaults, one
validation service that accumulates every violation of the eleven harvested rules into a single
response, and six routes under `/agent/definitions` gated on the OcuPilot administrative resource for
writes. The schema's defining feature is an absence: **no `ApiKey` property**, locked by a test.

## Boundaries & Constraints

**Always:** The class extends `OcuPilot.Kernel.State.Base` and is reached only through its `Guarded*`
methods (AD-9); every `%Persistent`-reaching class name is 29 characters or fewer including package
dots, which is why the class is `…State.Agent` (27) and not `…State.AgentDef` (30). Named scalars
only — no `list Of`, no relationship, no property typed as a persistent class — and **no hand-written
Storage XData**. Every violation code is declared as a parameter in `Api/Error.cls` and never minted
as a literal at a call site; the response is the flat `{error, reason, code, detail}` envelope with
the violation list inside `detail`, because AD-39 forbids a slice adding an envelope field of its own.
`Kernel/Provider/Catalog.cls` is the only place in the tree that spells a provider key, a default
model or a model suggestion. Writes require `OcuPilotAdmin:USE` checked server-side through
`Screen/Gate.cls:123`'s seam. A definition is created disabled.

**Never:** No `ApiKey` property, no `pApiKey` argument, and no API response that carries a credential
*value* — only its type and its name (AD-35). No screen descriptor, no client file, no string-table
row, no `strings.ts` key: the Definitions list and the Definition form are Story 3.5's, and
EXPERIENCE.md publishes no copy for any validation rule, so this story returns machine codes and
publishes no sentence. No `$System.Security.Audit()` call — Story 3.8 owns registration and emission
together, and an unregistered triple is dropped silently. No loopback/link-local/marked-local endpoint
rules and no resolved-address check (Story 3.2, DW-21). No credential *resolution* (Story 3.3). No
Test connection (Story 3.4). Never carry a harvested name: not `SessionAgent*` anywhere, and the
default credential names are OcuPilot's own, never `SessionAgentAnthropic`. Never create a principal
or change auditing on the live `ocupilot` container, and never `docker compose up`/`down` against it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create, valid | `POST /agent/definitions` with a sound body, caller holds `OcuPilotAdmin:USE` | 201, full projection; `Enabled` 0, `ConnectionVerified` 0; the row is the first, so it takes `DefaultMark` | none |
| Create, several rules broken at once | body with `provider` `"openai"`, `maxTokens` `99000`, `temperature` `3`, `credType` `"env"` and no `envVarName` | **one** 422 whose `detail.violations` holds four entries, each `{field, code}`, in declared rule order | this is the error path |
| Create, name already taken | a `name` an existing definition holds | 422, one violation `AGENT.NAME.DUPLICATE` on `name` | the `NameIdx` unique index also refuses it; the rule answers first so the caller gets a field, not `#5808` |
| XOR normalization | `credType` `"env"`, both `envVarName` and `credentialName` sent | saved with `credentialName` `""`; **no violation** — the invariant normalizes, it does not reject | none |
| XOR normalization exposes a gap | `credType` `"env"`, `envVarName` `""`, `credentialName` `"X"` | `credentialName` cleared first, then rule 6 fires: 422, `AGENT.ENVVAR.REQUIRED` | this is the error path |
| Endpoint required by the catalog row | a provider whose catalog row says `endpointRequired`, `endpointUrl` empty | 422, `AGENT.ENDPOINT.REQUIRED` | provider-name-free: the rule reads the row's column |
| Endpoint not absolute HTTPS | `endpointUrl` `"http://host/v1"` | 422, `AGENT.ENDPOINT.SCHEME` | the local exception is Story 3.2's; at this floor HTTPS is the only accepted scheme |
| Update changes provider, endpoint or credential | `PUT` altering any of `provider`, `endpointUrl`, `credType`, `envVarName`, `credentialName` on an enabled definition | 200; `ConnectionVerified` and `Enabled` are both forced to 0 | none — the disable is the outcome, not a refusal |
| Update changes only the model | `PUT` altering `model` alone | 200; `Enabled` and `ConnectionVerified` unchanged | none |
| Enable while unverified | `PUT` with `enabled` `true` and `ConnectionVerified` 0 | 422, `AGENT.ENABLE.UNVERIFIED` | Story 3.4 is what clears this |
| Set default | `POST /agent/definitions/:id/default` | 200; the marker moves in one transaction — cleared on the old row **before** it is set on the new | setting before clearing raises `#5808` on `DefaultIdx`; the order is the implementation |
| Delete the default, an enabled peer exists | `DELETE` on the marked row | 200; the marker moves to the lowest-`ID` **enabled** remaining definition (DW-20) | none |
| Delete the default, no enabled peer | `DELETE` on the marked row, every peer disabled | 200; the marker moves to the lowest-`ID` remaining definition | none |
| Delete the last definition | `DELETE` on the only row | 200; no marker exists — "exactly one marked" holds only while one exists | none |
| Disable the default, an enabled peer exists | the marked row is disabled, directly or by a credential change | the marker moves to the lowest-`ID` enabled peer (DW-20) | none |
| Disable the default, no enabled peer | the marked row is disabled, no peer is enabled | the marker stays; `ResolveDefault` answers `""` — the configuration-empty state, not a failure | none |
| Credential reference names something absent | a stored `credentialName` naming no credential on the instance | the row lists and reads back with the name verbatim; nothing fails (AD-37) | resolution and the "no longer present" rendering are Stories 3.3 and 3.5 |
| Non-administrator lists | `GET /agent/definitions`, caller holds an `%Admin_*` resource but not `OcuPilotAdmin` | 200 with the selection projection: `id`, `name`, `provider`, `model`, `enabled`, `default` — and nothing else | none |
| Non-administrator reads one | `GET /agent/definitions/:id`, same caller | 403, `AUTH.NOPRIVILEGE`, `detail.failedPair` `"OcuPilotAdmin:USE"` | the published `You need <resource> to <action>.` row renders it |
| Non-administrator writes | `POST`/`PUT`/`DELETE`, same caller | 403 as above, and **nothing is written** | assert the row count is unchanged, not only the status |
| Unknown id | any `:id` route with an id no row holds | 404, `AGENT.NOTFOUND` | never a 500 |
| Malformed body | `POST` with unparseable JSON | 400, `BADREQUEST` with the stage `Kernel/Utils.ReadRequestBody` named | a read fault is not an empty body (DW-24) |

</intent-contract>

## Code Map

Every anchor below was re-verified against the working tree on 2026-09-15.

**What exists and is reused**

- `src/OcuPilot/Kernel/State/Base.cls` — the tree's only `%Persistent` root and only escalation point
  (AD-9). `Parameter APPLICATION = "OcuPilotState"` **:48**, `DATABASENAME = "OCUPILOT"` **:51**,
  `DBRESOURCE = "%DB_OCUPILOT"` **:60**, `ADMINRESOURCE = "OcuPilotAdmin"` **:64**,
  `MAPPINGPATTERN = "OcuPilot*"` **:67**, `AUDITSOURCE = "OcuPilot"` **:71**. Public guarded surface:
  `GuardedSave` **:79**, `GuardedOpenId` **:98**, `GuardedExistsId` **:118**. `Private` guarded
  surface, reached by inherited `..` dispatch only — never `##class(OcuPilot.Kernel.State.Base)`, which
  IRIS refuses against the named class: `GuardedExecuteOneParam` **:204**, `GuardedExecuteNoParam`
  **:232**, `GuardedOpenOneWhere` **:261**, `GuardedOpenOneWhereNoParam` **:295**,
  `GuardedOpenOneWhereTwoParam` **:322**, `GuardedIdsWhere` **:381**, `GuardedIdsWhereNoParam` **:406**.
  `pSql` must be a call-site literal (**:190-193**).
- `src/OcuPilot/Kernel/State/Version.cls` — the house style to copy for a new state class: `MAXLEN` on
  every string, `InitialExpression` on every flag, the class header naming the no-`list Of`/no-Storage
  rule (**:11-12**), an ISO-8601 UTC `UpdatedAt` (**:38-42**), and `GuardedOpenOneWhereNoParam` with a
  literal `SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Version …` (**:51-59**). SQL table names are
  `OcuPilot_Kernel_State.<Class>`.
- `src/OcuPilot/Api/Error.cls` — the one home for slugs and machine codes. `VALIDATIONFAILED =
  "validation_failed"` **:44**. It is already reachable in shipped code, but only as the slug
  `Kernel/Fault.cls:180` maps a **vendor** refusal onto (`PORT.VALIDATION`, doc at `Error.cls:171`);
  this story is the first shipped code to render it for **OcuPilot's own** input validation.
  `AUTHNOPRIVILEGE = "AUTH.NOPRIVILEGE"` **:111**. `CODEPATTERN =
  "^[A-Z][A-Z0-9]*(\.[A-Z][A-Z0-9]*)*$"` **:279** — every new code must match it. The envelope writer
  `Render(pStatus, pSlug, pReason, pCode, pDetail)` **:301**, which sets `%response.Status`, writes
  `{error, reason, code}` plus `detail` when `$IsObject(pDetail)` (**:322-324**). `IsValidCode`
  **:338**, `GetSlugForStatus` **:427** — `422` already maps to `VALIDATIONFAILED` at **:437**.
  **:157-159** records `ROUTE.SERVER_ERROR` as the defect behind the never-mint-a-code-at-the-call-site
  rule.
- `src/OcuPilot/Api/Response.cls` — `JSON(pData)` **:13**, `JSONStatus(pStatus, pData)` **:25**. With
  `Api/Error.cls` these are the only two files permitted a bare `Write`
  (`scripts/check-objectscript.py:163-167`).
- `src/OcuPilot/Api/Router.cls` — `XData UrlMap` **:61-74**, nine `GET` routes, **no write verb
  anywhere in the shipped tree**. `Parameter ADMINRESOURCES` **:41** (thirteen `%Admin_*` names).
  `HoldsAdminResource()` **:176-188**. `OnPreDispatch` **:278** already refuses before any handler
  runs: install gate (**:286-305**), anonymous caller (**:308-312**), no `%Admin_*` resource
  (**:314-318**), unknown or unenterable namespace (**:320-340**) — **so every caller that reaches a
  definitions handler is authenticated and holds at least one `%Admin_*` resource.** `Call=` targets
  are thin wrappers with no logic (**:59-60**, example **:78-81**).
- `src/OcuPilot/Screen/Gate.cls` — `HoldsPrivilege(pResource, pPermission)` **:123-126** is the single
  instance consultation (`$System.Security.Check`), overridable **only** so tests can drive it, because
  `%UnitTest` runs as `%All`. `EvaluatePairs` **:89** builds the `resource:permission` failure string.
- `src/OcuPilot/Kernel/Utils.cls` — `ReadRequestBody(Output pBody)` **:366-395**, three separated
  failure stages (read / decode / parse, **:386-392**). It ships today with **no route driving it**;
  this story is its first shipped consumer.
- `src/OcuPilot/Kernel/Fault.cls` — the precedent that `Kernel/` may reference `OcuPilot.Api.Error`'s
  parameters (**:55-82**). `Build(pSlug, pCode, pReason)` **:156-163** returns the fault object shape;
  **:180** is where `PORT.VALIDATION` takes the `VALIDATIONFAILED` slug.
- `src/OcuPilot/Test/RouterFixture.cls:220` — the shape precedent for this story's 422:
  `Render(422, #VALIDATIONFAILED, "Validation failed", "REQUEST.VALIDATION", {"fields": ["name"]})`.
  A field list already rides inside `detail` there. Copy the shape, **not** the literal code at the
  call site — that is a test fixture, and shipped code declares its codes as parameters.
- `src/OcuPilot/Kernel/Audit/Log.cls` — `Info(pSubsystem, pMessage, pData)` **:16**, `Redact` **:109**,
  the overridable `WriteConsole` seam **:192**. **Trap:** `Parameter CREDENTIALNAMES` **:55** includes
  `credential`, so a data key named `credentialName` is redacted to `[redacted]` (**:42**). A test that
  asserts a logged credential name will see the redaction, not the value — which is the desired
  behavior, and the reason to assert on the redaction rather than fight it.
- `src/OcuPilot/Install/Roster.cls` — `XData Manifest` **:81-160** declares
  `"packages": ["Api","Area","Install","Kernel","Port","Screen","Test"]` at **:95**. `module.xml` is
  generated from it. **A new class inside an existing package needs no manifest edit**, so
  `ipm-manifest.mjs --check` stays green with nothing to regenerate.
- `src/OcuPilot/Screen/Area.cls:91` — the `agent` area already exists
  (`railPosition` 8, `pinBottom` true, `privileges` `[]`) with **zero screens behind it**. This story
  adds no screen to it; Story 3.5 does.
- `src/OcuPilot/Test/State.cls` — the residue-free instance-state pattern: purpose-built names
  (**:43,:45**), guard-then-act create (**:100-115**), verify what was created (**:118**), and an
  `OnAfterOneTest` (**:130**) that deletes and then re-checks `Exists()`. `Parameter ARMINGVARIABLE =
  "OCUPILOT_ALLOW_PRINCIPALS"` **:28** with the `OnBeforeAllTests` refusal **:37**.
- `src/OcuPilot/Test/WireSecurityRead.cls` — the model for a real least-privileged principal over HTTP:
  `ARMINGVARIABLE` **:40**, guard **:126-128**, `EnsurePrincipal`, and `AssertReadRefused` **:285-293**
  asserting status, `code` and `detail.failedPair` together.
- `scripts/ci-throwaway.sh` — `PROJECT="ocupilot-ci"` **:25**, `WEB_PORT="52776"` **:26**,
  `OCUPILOT_ALLOW_PRINCIPALS: "1"` **:139**. It refuses `--web 52774`, `--super 1973` and
  `--project ocupilot` (**:45-52**).
- `ui/tools/ci-runner.mjs` — `--container <name> --class <one class>`; one class per invocation.

**Checker constraints that decide names and placement** (`scripts/check-objectscript.py`)

- `MAX_CLASS_NAME_LENGTH = 29` **:169**, applied to any class reaching `%Persistent`
  (`check_naming` **:344**, message **:359**). `OcuPilot.Kernel.State.Agent` is 27; `…AgentDef` is 30.
- `REENTRY_TOKENS = ("OcuPilot.Api","OcuPilot.Port","OcuPilot.Screen","OcuPilot.Area")` **:599**,
  enforced by `check_state_package_isolation` **:710** against anything under `Kernel/State/`. The
  validator needs `Api/Error.cls`'s code parameters, so **it cannot live under `Kernel/State/`** — it
  goes in `Kernel/`, beside `Fault.cls`, which already makes that reference.
- `check_escalation_containment` **:696** — `New $ROLES` / `AddRoles` only in
  `Kernel/State/Base.cls` and `Test/State.cls` (**:566-569**). The new class escalates only by
  inheriting Base's methods; it writes neither.
- `check_handler_wire_tests` **:1218** — every `<Route>` needs a class under `src/OcuPilot/Test/` naming
  the route literal **in code, not in a doc comment** (`wire_test_sources` **:1198** strips comments)
  and carrying all four `WIRE_MARKERS` **:1188-1193**: an `AbsoluteRequest|MakeRequest|RawRequest(`
  call, an `AssertEquals(tStatus` assertion, a `CONTENT-TYPE|ContentType` assertion, and a `%FromJSON`
  body-shape assertion.
- `check_route_ordering` **:1442** — two clauses. Duplicate URLs with **different** methods are fine
  (the `same_method` guard **:1462**; `Test/RouterFixture.cls:66-67` is the shipped precedent for
  `/guarded` GET then POST). But a shorter route whose pattern matches a longer route's leading
  segments must come **after** it (**:1478-1489**), regardless of method — so
  `/agent/definitions/:id/default` precedes `/agent/definitions/:id`, which precedes
  `/agent/definitions`.
- `check_rename_tokens` **:273** — `FORBIDDEN_LITERALS` **:182-193** includes `SessionAgent`.
- `check_test_class_properties` **:983** — no property on a `%UnitTest.TestCase` subclass may begin with
  `Test`.
- `check_non_ascii_literals` **:1289** — no literal non-ASCII byte in an ObjectScript string.

**Planning sources**

- `_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-session-agent.md`
  — the rules at **:129-137**, the `ApiKey` absence at **:110**, the field list at **:116**, the
  hashed-globals trap at **:121**, the one-source model-list rule at **:139**.
- `…/harvest/HARVEST-PLAN.md:63` — "Port the **contracts** … Accumulate errors into one round-trip.
  **Keep the absence of an `ApiKey` property**". Renames at **:100-114**.
- `_bmad-output/planning-artifacts/epics.md:311` — Anthropic is "**the only Release 1 provider**"; "The
  other three providers … copy at **build step 7**, not before." Story 3.1's block is **:2251-2291**.
- `…/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:149` — the Definitions list shows "name, provider,
  model, enabled, default", which is this story's selection projection. The Fixed strings table is
  **:252-332**; **it publishes no sentence for any validation rule** — verified negative.

**Client: nothing.** `ui/src/` has no agent area, no definitions route, store or model, and no
`/api/…/definition` reference. This story adds no client file and no `strings.ts` key, so
`strings.test.mjs`'s cardinality (221 = 206 + 12 + 3, `:346-350`) and `citations.test.mjs` are
untouched. `citations.test.mjs` **does** scan `src/OcuPilot/**/*.cls`, so a new `.cls` must not write a
bare `EXPERIENCE.md:N` citation (`:94`, `:162-179`); citing `epics.md` is invisible to it.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Agent.cls` — new, `Extends OcuPilot.Kernel.State.Base`. Properties, all
  named scalars with `MAXLEN` or `InitialExpression` in `Version.cls`'s style: `Name`(64),
  `Provider`(32), `Model`(128), `EndpointUrl`(512), `CredType`(8), `EnvVarName`(128),
  `CredentialName`(128), `MaxTokens As %Integer [=32000]`, `Temperature As %Numeric(SCALE=2) [=0]`,
  `MaxIterationsPerTurn As %Integer [=10]`, `SystemPromptOverride`(8192),
  `ReadOnly As %Boolean [=1]`, `RetentionDays As %Integer [=30]`, `Enabled As %Boolean [=0]`,
  `ConnectionVerified As %Boolean [=0]`, `DefaultMark`(1), `CreatedAt`(32), `UpdatedAt`(32).
  `Index NameIdx On Name [Unique]` and `Index DefaultIdx On DefaultMark [Unique]`. Class methods,
  each built on the inherited `Guarded*` surface with literal SQL: `GuardedCreate`, `GuardedUpdate`,
  `GuardedDeleteId`, `GuardedList`, `GuardedByName`, `SetDefaultGuarded(pId)`,
  `ResolveDefault(Output pId)`. **No `ApiKey`. No hand-written Storage. No `list Of`. No property typed
  as a persistent class.** Compile early and read the error text: `ReadOnly` is also a property keyword,
  so confirm it is accepted as a property *name* before the rest of the class is written.
  Rationale: this is the epic's foundation, and AD-9 puts it behind the guarded database.
- `src/OcuPilot/Kernel/Provider/Catalog.cls` — new, `Extends %RegisteredObject`. One `XData` table, one
  row per provider key, carrying `key`, `label`, `defaultModel`, `modelSuggestions`, `defaultEndpoint`,
  `endpointRequired`, `canonicalMaxTokens`, `canonicalTemperature`, `defaultEnvVarName`,
  `defaultCredentialName`, `keyPrefix`. **At this floor the table holds exactly one row, `anthropic`**
  (`epics.md:311`), with `defaultEndpoint` `https://api.anthropic.com/v1/messages`, `endpointRequired`
  0, `canonicalMaxTokens` 32000, `canonicalTemperature` 0, `defaultEnvVarName` `ANTHROPIC_API_KEY`,
  `defaultCredentialName` `OcuPilotAnthropic` (**never** the harvested `SessionAgentAnthropic`) and
  `keyPrefix` `sk-ant-`. Expose `Keys()`, `Row(pKey, Output pRow)`, `IsKnown(pKey)` and an overridable
  `Table()` seam so a test can supply a second row. Rationale: this is the "one source" the harvest
  demands (`iris-session-agent.md:139`), and it is what makes step 7 "one adapter plus one row".
- `src/OcuPilot/Kernel/AgentRules.cls` — new, `Extends %RegisteredObject`, **not** under
  `Kernel/State/`. `Normalize(ByRef pValues)` applies the XOR credential invariant; `Validate(ByRef
  pValues, pExistingId, Output pViolations)` appends `{field, code}` entries in declared rule order and
  returns the count. One method per rule, or one ordered pass — but **never an early `Quit`**: the
  accumulation is the requirement. Rationale: eleven rules in one round trip is the AC.
- `src/OcuPilot/Api/Error.cls` — add, in the machine-code block, one parameter per code:
  `AGENTVALIDATION` `"AGENT.VALIDATION"`, `AGENTNOTFOUND` `"AGENT.NOTFOUND"`, and the violation codes
  `AGENTNAMEREQUIRED`, `AGENTNAMEDUPLICATE`, `AGENTPROVIDERUNKNOWN`, `AGENTMAXTOKENSRANGE`,
  `AGENTTEMPERATURERANGE`, `AGENTCREDTYPEUNKNOWN`, `AGENTENVVARREQUIRED`, `AGENTCREDNAMEREQUIRED`,
  `AGENTENDPOINTREQUIRED`, `AGENTENDPOINTSCHEME`, `AGENTSYSTEMPROMPTLENGTH`, `AGENTRETENTIONRANGE`,
  `AGENTITERATIONSRANGE`, `AGENTENABLEUNVERIFIED`, each with the house doc comment naming the slug it
  is rendered on. Every value must satisfy `CODEPATTERN` (`:279`) and no parameter name may carry an
  underscore. Rationale: `:157-159` records what happens when a code is minted at the call site.
- `src/OcuPilot/Api/Definitions.cls` — new, `Extends %RegisteredObject`, one `Handle*` entry point per
  route. Reads the body through `Kernel/Utils.ReadRequestBody`, normalizes, validates, renders 422 via
  `Error.Render(422, #VALIDATIONFAILED, <reason>, #AGENTVALIDATION, tDetail)` with
  `tDetail.violations` as a `%DynamicArray`, and otherwise writes through the state class and returns
  `Api/Response.JSON`. The admin check is `##class(OcuPilot.Screen.Gate).HoldsPrivilege("OcuPilotAdmin",
  "USE")`; a refusal renders 403 `#FORBIDDEN` / `#AUTHNOPRIVILEGE` with
  `detail.failedPair = "OcuPilotAdmin:USE"` — reusing the published `You need <resource> to <action>.`
  row rather than minting a new code (AD-8). Never emit a credential value in any projection. On every
  accepted create, update, delete and set-default, compute the changed-field set as
  `{field, old, new}` entries and pass it to `##class(OcuPilot.Kernel.Audit.Log).Info("agent-definition",
  <verb>, tData)` — one call, one place, which is the seam Story 3.8 wires to
  `$System.Security.Audit()` once the event type is registered. Rationale: one handler, one envelope,
  one gate, and one place for 3.8 to reach.
- `src/OcuPilot/Api/Router.cls` — insert six `<Route>` entries as a block at the **top** of
  `<Routes>`, in this order: `/agent/definitions/:id/default` POST; `/agent/definitions/:id` GET, PUT,
  DELETE; `/agent/definitions` GET, POST. Add the six thin `Call=` wrappers beside `ScreenRead`
  (**:78-81**), each a single `Quit ##class(OcuPilot.Api.Definitions).Handle*(…)`. Rationale: the
  segment-length clause of `check_route_ordering` requires the longer routes first.
- `src/OcuPilot/Test/AgentSchema.cls` — new. Pins the absences: no property named `ApiKey` or matching
  the credential-name pattern; **every** property's type is a `%Library` datatype, so none is a foreign
  key and none is a collection (walk `%Dictionary.CompiledProperty`, assert `Collection` is empty and
  `Type` starts with `%Library.`); the class name is ≤29 characters; no `Storage` block was authored by
  hand. Rationale: the AC says the absence *is* the schema invariant, so the absence needs a test.
- `src/OcuPilot/Test/AgentRules.cls` — new. One method per rule, plus the accumulation case (a body
  breaking four rules yields four violations in declared order), the XOR normalization cases in both
  directions, and the two OcuPilot-only rules. Drives `Catalog.Table()`'s seam with a second,
  `endpointRequired` row so rule 8 is exercised at a floor whose real table has one row. Rationale: a
  rule with no failing case is not enforced, it is merely written.
- `src/OcuPilot/Test/AgentState.cls` — new. The default invariant (a second `DefaultMark` save raises
  `#5808`), `SetDefaultGuarded`'s clear-then-set order, the first definition taking the marker, every
  DW-20 fallback row of the matrix, the disable-on-change field set, and a definition whose credential
  reference names nothing still reading back. Creates rows named `OcuPilotProbeAgent<n>` and deletes
  them in `OnAfterOneTest`, then asserts a `SELECT COUNT(*) … WHERE Name %STARTSWITH 'OcuPilotProbeAgent'`
  of 0. Rationale: instance state that a test leaves behind becomes the next story's mystery.
- `src/OcuPilot/Test/AgentWire.cls` — new. Drives all six routes over HTTP with the four
  `WIRE_MARKERS`, naming each route literal in code. Covers the happy create, the four-violation 422
  (asserting `detail.violations` shape and order, not only the status), the 404, and the malformed
  body. Also pins the change record: with `Kernel/Audit/Log.WriteConsole` subclassed the way
  `Test/LogProbe.cls` does it, an accepted update emits one line carrying the changed field with its
  old and new values — and `credentialName` arrives `[redacted]`, because `Log.cls:55` lists
  `credential`. Rationale: `check_handler_wire_tests` refuses a route with no wire test, Rule 3
  refuses a review with no real-runtime evidence, and a seam Story 3.8 will build on needs a test
  before 3.8 arrives.
- `src/OcuPilot/Test/AgentWireSecurity.cls` — new, `Parameter ARMINGVARIABLE =
  "OCUPILOT_ALLOW_PRINCIPALS"` with the `OnBeforeAllTests` refusal, modeled on `WireSecurityRead.cls`.
  Creates one principal holding `%Admin_Operate:USE` and **not** `OcuPilotAdmin`, and asserts: the list
  route answers 200 with the six-key selection projection and no credential key; each of the five
  other routes answers 403 with `code` `AUTH.NOPRIVILEGE` and `detail.failedPair` `OcuPilotAdmin:USE`;
  and the row count is unchanged after the refused writes. Tears the principal down and re-checks
  `Exists()`. Rationale: `Gate.HoldsPrivilege` is overridable, so only a real principal proves the gate.

**Acceptance Criteria:**

- **AC1 (schema, and the absence that defines it).** Given the definition class, when it is compiled
  and inspected through `%Dictionary.CompiledProperty`, then it holds name, provider, model, endpoint
  URL, credential type, credential reference, maximum tokens, temperature, maximum iterations per turn,
  system prompt override, read-only flag, retention period and enabled flag — **and no property named
  `ApiKey`, no property whose type is a persistent class, and no collection property** — with the class
  name at 29 characters or fewer and no hand-written Storage section.
- **AC2 (the eleven rules, accumulated).** Given a single submission that breaks four of the eleven
  harvested rules at once, when it is saved, then **one** 422 response comes back whose
  `detail.violations` holds exactly four `{field, code}` entries in declared rule order, and nothing is
  written — never one error at a time, and never a violation without a field.
- **AC3 (the XOR credential invariant).** Given a submission carrying both `envVarName` and
  `credentialName`, when `credType` selects one of them, then the other is stored as `""` and the save
  succeeds; and given `credType` `env` with an empty `envVarName`, then the normalization runs first
  and `AGENT.ENVVAR.REQUIRED` is the violation returned.
- **AC4 (exactly one default, and DW-20's fallback).** Given definitions exist, when any of them is
  created, deleted, disabled or set default, then exactly one carries the marker while any definition
  exists, a second marker is refused by the unique index rather than by convention, and when the marked
  one is deleted or disabled the marker moves to the lowest-`ID` enabled definition — falling back to
  the lowest-`ID` remaining definition on a delete when none is enabled, and leaving `ResolveDefault`
  answering `""` (the configuration-empty state) when nothing is enabled.
- **AC5 (a security-relevant change disables).** Given an enabled, verified definition, when a save
  changes its provider, endpoint URL, credential type or credential name, then `ConnectionVerified` and
  `Enabled` are both 0 afterwards and an attempt to set `enabled` while unverified returns
  `AGENT.ENABLE.UNVERIFIED`; and when a save changes only the model, both flags are unchanged.
- **AC6 (who may see, who may edit — on the instance, not in the client).** Given a real principal on
  the throwaway holding `%Admin_Operate:USE` and not `OcuPilotAdmin`, when it calls the six routes over
  HTTP, then the list route answers 200 carrying only `id`, `name`, `provider`, `model`, `enabled` and
  `default`, the other five answer 403 with `code` `AUTH.NOPRIVILEGE` and `detail.failedPair`
  `OcuPilotAdmin:USE`, and the definition count is unchanged.
- **AC7 (weak references, AD-37).** Given a definition whose stored credential reference names a
  credential that is not present on the instance, when the definition is listed and read, then both
  answer normally with the reference verbatim and neither fails — the reference being scoped identity
  data, never a foreign key.
- **AC8 (Integration AC).** Given the shipped routes on a real instance, when a consumer issues one
  `POST /agent/definitions` whose body breaks four rules and then one that is sound, then the first
  answers 422 with four violations in one round trip and writes nothing, and the second answers 201
  with a definition that `GET /agent/definitions` immediately returns carrying `default` true and
  `enabled` false — observed over HTTP by `OcuPilot.Test.AgentWire`, not by reading the state class.

## Spec Change Log
- 2026-09-15, lead (spec gate, owner-delegated): both seed values are decided rather than carried. The Anthropic catalog row's **default model is `claude-opus-5`**, and its suggestion list is `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5-20251001`, `claude-fable-5-1` - the current Claude family, most capable first; the stale `claude-opus-4-7` is not carried at all. The catalog stays the one-source mechanism the plan designed, so a later model is a row edit. **`RetentionDays` defaults to 30**, inert until Story 14.4 enables the field and ships the purge task.

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).**

- **AD-9** (`ARCHITECTURE-SPINE.md:172-182`) — OcuPilot's globals, and only its globals, live in the
  guarded database; the storage classes alone escalate through the privileged routine application
  inside `New $ROLES`, and **nothing is spawned from or re-enters from an escalated frame**. The new
  class inherits Base's guarded methods and writes no escalation of its own; the validator and the
  handler are outside `Kernel/State/` and never escalate.
- **AD-12 / AD-39** (`:216`, `:426`, Conventions `:537`) — one envelope, `{error, reason, code,
  detail}`, and *"no slice adds a field to the envelope for its own use."* This is why the violation
  list rides inside `detail` rather than as a top-level `errors` array, and why every violation carries
  a stable machine code rather than a sentence.
- **AD-8** (`:170`) — a denial names the `(resource, permission)` pair that failed. Reusing
  `AUTH.NOPRIVILEGE` with `detail.failedPair = "OcuPilotAdmin:USE"` lands the refusal on the copy
  Story 3.0 already published, and costs no new code and no string-table row.
- **AD-15** (`:236-240`) — audit events are registered with `Security.Events.Create()` at install, and
  an unregistered triple is dropped with no error and no log entry. **This story therefore emits no
  `$System.Security.Audit()` call.** Story 3.8 owns registration and emission together, including the
  old-value/new-value shape its own AC names (`epics.md:2520-2526`); the update path here computes the
  changed-field set it needs and hands it to `Kernel/Audit/Log.Info`, which needs no registration, so
  3.8 adds the audit row at one seam instead of retrofitting six handlers. The tree has no
  old→new audit precedent to copy; 3.8 mints it.
- **AD-19** (`:260`) — screen state is a store, never a component field. Named as governing because the
  epic context lists it, but **not exercised here**: this story adds no client file. Story 3.5 is where
  it binds.
- **AD-29** (`:358`) — every port declares and checks its own resource before any call, and a screen's
  pair set is settled by running as a least-privileged principal on a throwaway. AC6 is that technique
  applied to configuration routes: `Gate.HoldsPrivilege` is overridable so unit tests can drive it, so
  only the throwaway leg with a real principal actually proves the gate.
- **AD-30** (`:364-370`) — the kill switch and enforced read-only are instance state evaluated at the
  point of effect. The definition's own `ReadOnly` flag is **stored** here and **enforced** in Story
  3.7, which is the single enforcement point; this story adds no second one.
- **AD-32** (`:378`) — outbound TLS uses a named SSL configuration the installer creates. Nothing here
  makes an outbound call; Story 3.2 consumes the endpoint this class stores.
- **AD-35** (`:396-400`, Conventions `:541`) — secrets never reach a surface OcuPilot displays,
  redaction is schema-driven with a name-pattern backstop. The absence of `ApiKey` is this AD at the
  schema tier; no projection carries a credential value, and the backstop pattern (`password`, `pwd`,
  `secret`, `apikey`, `privatekey`, `token`, exactly `Key`) matches none of the property names chosen.
- **AD-37 / AD-13** (`:408-412`, `:228`) — every stored reference is weak: scoped identity as data,
  never a foreign key, rendering "no longer present" rather than failing the screen. See the note below
  on why the credential reference is two scalars rather than an `EntityRef` key.
- **AD-42** (`:448-454`) — the definition's endpoint requires the administrative resource to write, is
  validated to absolute HTTPS or a declared local address, cannot name the instance/loopback/link-local
  unless marked local, and is audited as a security change. This story ships the two halves its own ACs
  reach — the administrative gate, and the absolute-HTTPS rule — and ships **nothing looser** than
  AD-42's end state. The local exception, the `MarkedLocal` property, the resolved-address check
  (DW-21) and the security-change audit are Story 3.2's, named in its own AC at `epics.md:2316`.
- **AD-46** (`:486-492`) — OcuPilot's own records are visible in OcuPilot's own screens. Definitions are
  instance-wide and every portal user sees the selection projection; the narrower projection is about
  what a non-administrator needs, not about hiding OcuPilot from itself.
- **AD-5** (`:135`) — one screen descriptor is the source of everything about a screen. These are
  configuration routes, not screen reads: `/instance`, `/namespaces` and `/navigation` are the shipped
  precedent for a route with no descriptor. The Definitions **screen** and its descriptor are Story
  3.5's.
- **`.claude/rules/iris-persistent-storage.md`** — every property is a named scalar; nothing is a
  `list Of` and nothing is a relationship, so no subtable or projection question arises. The rule is
  recorded because a later story adding, say, a list of allowed models would have to answer it.

**Consumes:** Story 1.3 (`Kernel/State/Base.cls`, the `OCUPILOT` database, `OcuPilotAdmin`, and the
SQL-and-global half of the state-protection proof), Story 1.1 (`Api/Error.cls`'s envelope,
`Api/Response.cls`, `Kernel/Utils.ReadRequestBody`), Story 1.8 (`Api/Router.cls`'s pre-dispatch gate
and its `%Admin_*` floor), Story 1.9 (`Screen/Gate.cls`'s `HoldsPrivilege` seam), Story 2.9
(`Test/WireSecurityRead.cls`'s principal pattern and `scripts/ci-throwaway.sh`), Story 3.0
(`detail.failedPair` rendered through the published 403 row).

**Consumed-by:**

- **Story 3.2** — reads `Kernel/Provider/Catalog` for the provider key, canonical endpoint and key
  prefix, and adds `Kernel/Provider/Base.cls` plus the Anthropic adapter beside it; adds the
  `MarkedLocal` property and AD-42's remaining endpoint rules to this class.
- **Story 3.3** — reads `CredType`, `EnvVarName` and `CredentialName` as the ladder's input, and flags
  the definition when a reference does not resolve (DW-22).
- **Story 3.4** — calls the definition **as edited**, and is the only writer of `ConnectionVerified`;
  AC5 is what makes that flag meaningful.
- **Story 3.5** — renders the Definitions list from the selection projection, the form from the full
  projection, the provider cascade from `Catalog`, and publishes the Fixed-strings rows for the
  eleven violation codes, the field labels, the list columns and "Retention is not yet enforced".
- **Story 3.6** — reads `ResolveDefault`: `""` is the configuration-empty state and the first-login
  gate's trigger.
- **Story 3.7** — reads the definition's `ReadOnly` flag as the third source of the footer's read-only
  status line, and stores the switches beside this class in the same protected database.
- **Story 3.8** — registers the audit event types and emits the old-value/new-value row for every
  definition change, and adds the endpoint half of the state-protection test over these six routes.
- **Epic 4's turn** — calls `ResolveDefault` once per turn to find the enabled default definition, and
  takes provider, model, endpoint and tuning from it. `epics.md:2273` requires that the turn endpoint
  take no provider, endpoint, model or credential from the client, which is why the resolution is a
  server-side method and not a request parameter.

**Which eleven, and what each is in this project's terms.** Two planning sources enumerate them and
they do not agree on the count. `harvest/iris-session-agent.md:129-133` heads its list "the 11
validation rules" and then prints twelve items, because it inserts a "4b" and ends with a
"save-status catch-all". `research/…/digests/harvest-session-agent-r1-1.md:81` lists exactly eleven and
has no catch-all. The **eleven input rules are identical in both**; the discrepancy is the harvest
map's numbering artifact plus a twelfth item that is not an input rule at all. This story enforces the
eleven and keeps the catch-all as the save path's never-throw discipline, which is a superset of either
reading and so observably the same set of refusals.

| # | Harvested clause | In OcuPilot's terms | Code |
|---|---|---|---|
| 1 | `AgentName` in the known set | `Name` required, ≤64, unique across definitions. The closed two-literal set does not transfer — the digest's own note is *"OcuPilot needs an agent registry instead of two literals"* (`:157`) — but the harvested `AgentNameIdx [Unique]` does. | `AGENT.NAME.REQUIRED`, `AGENT.NAME.DUPLICATE` |
| 2 | `Provider` in the known set | `Provider` is a key in `Kernel/Provider/Catalog`. At this floor the known set is exactly `anthropic`. | `AGENT.PROVIDER.UNKNOWN` |
| 3 | `MaxTokens` 1–32000 | integer, 1–32000 inclusive | `AGENT.MAXTOKENS.RANGE` |
| 4 | `Temperature` 0–2 | numeric, 0–2 inclusive | `AGENT.TEMPERATURE.RANGE` |
| 5 | `CredType` in `{env,creds}` (the map's "4b") | same. `creds` additionally needs an interoperability-enabled namespace; that rung is Story 3.3's, so this story stores the choice and does not test the namespace. | `AGENT.CREDTYPE.UNKNOWN` |
| 6 | `env` ⇒ `EnvVarName` non-empty | same, after normalization | `AGENT.ENVVAR.REQUIRED` |
| 7 | `creds` ⇒ `CredentialName` non-empty | same, after normalization | `AGENT.CREDNAME.REQUIRED` |
| 8 | `openai-compatible` ⇒ `EndpointUrl` non-empty | the **catalog row's `endpointRequired` column** ⇒ non-empty. Provider-name-free, so build step 7 adds a row rather than a branch — which is Story 3.2's "adding a family means adding an adapter and a form entry". | `AGENT.ENDPOINT.REQUIRED` |
| 9 | `SystemPrompt` ≤ 8192 | `SystemPromptOverride` ≤ 8192 characters | `AGENT.SYSTEMPROMPT.LENGTH` |
| 10 | retention 1–365 and `^[0-9]+$` | `RetentionDays`, digits only, 1–365 | `AGENT.RETENTION.RANGE` |
| 11 | `MaxIterationsPerTurn` 1–100 | same | `AGENT.ITERATIONS.RANGE` |

Two more rules are OcuPilot's own, forced by other acceptance criteria rather than harvested, and they
are marked as such in `AgentRules.cls`: `AGENT.ENDPOINT.SCHEME` (AD-42's absolute-HTTPS clause) and
`AGENT.ENABLE.UNVERIFIED` (AC5, and Story 3.4's reason to exist).

**The XOR invariant normalizes; it does not reject.** `harvest/iris-session-agent.md:135`: *"whichever
of `EnvVarName`/`CredentialName` the radio didn't select is always cleared to `""`, so the `EnvSecret`
ladder is deterministic."* Sending both is therefore never an error — one is cleared. The order matters
and is load-bearing: normalization runs **before** validation, so `credType` `env` with an empty
`envVarName` and a populated `credentialName` clears the credential name first and then reports rule 6,
rather than silently accepting a credential the ladder would never read.

**Why "exactly one default" is a unique index and not a convention, with the probe that settled it.**
The harvest supplies nothing here — the original has no default flag at all, and its only index is
`AgentNameIdx [Unique]` on the name. The spine legislates nothing either: no AD covers a single-default
record. So the mechanism is chosen here, and the choice rested on an IRIS behavior worth checking
rather than recalling. Probed on the live `ocupilot` instance (IRIS for Health 2026.2), 2026-09-15, with
a throwaway class outside the `OcuPilot*` global mapping, since deleted along with its two globals: a
`[ Unique ]` index **accepts repeated empty-string values** and refuses the second non-empty duplicate —
three rows saved with `""` all succeeded, and the second row carrying `"1"` returned
`ERROR #5808: Key not unique: …:DefaultIdx:^…I("DefaultIdx"," 1")`.

That makes `DefaultMark` — `""` for every ordinary definition, `"1"` for the default — enforce "at most
one" **structurally**, at the storage layer, where no code path can talk its way past it. A guarded
setter alone would have rested the invariant on every future caller remembering; the index makes a
second default a save failure. What an index cannot express is "at least one", and that is the right
split: "at least one" belongs to the promotion rules below, and "which one is in force" belongs to
`ResolveDefault`, which returns the marked definition **only while it is enabled**. Consequence for the
implementer: `SetDefaultGuarded` must clear the old marker **before** setting the new one, inside one
transaction — the other order collides with the index and raises `#5808` on a legitimate request.

**DW-20, answered.** The ledger entry's guard names the fallback — *"promote another enabled
definition, else the configuration-empty state"* — so what this story owes is the deterministic
mechanism, which is the tie-break. The marker moves to the **lowest `ID`** among candidates, i.e.
creation order, because it is stable, needs no extra column and is the same rule a reader can verify
from a list. On the **first** definition, the marker is taken automatically: a single-definition
instance should not require a separate act to have a default. On **delete** of the marked row, the
marker moves to the lowest-`ID` enabled definition, or, if none is enabled, to the lowest-`ID` remaining
definition, so "exactly one is marked while any exists" holds. On **disable** of the marked row — by an
explicit disable or by the provider/endpoint/credential change of AC5 — the marker moves to the
lowest-`ID` enabled peer if one exists; otherwise it stays where it is and `ResolveDefault` answers
`""`. That last case is not a failure: it is precisely Story 3.6's configuration-empty state, and it is
also the reason default and enabled are orthogonal flags rather than one.

**Why the credential reference is two scalars and not an `EntityRef` key.** AD-37 requires a stored
reference to be weak — *"scoped identity as data, never a foreign key"* — and AD-13 supplies the
`(entity type, scope, id)` triple that `Kernel/EntityRef.cls` materializes. Materializing this
reference that way would mean adding `credential` and `environment-variable` to
`Kernel/EntityType.cls`'s closed `TYPES` parameter, which three separate checks refuse independently
(`check_entity_types`, `screen-mirror.mjs`, `Screen.Registry.Validate`) and which would regenerate the
client mirror for a story that ships no client. `EntityRef.cls`'s own header states what the triple is
for: *"a change event's subject, a proposal's target, a highlight target and an audit marker"* — every
one of them a reference that crosses a boundary. A definition's credential reference crosses none. Two
scalars — the type and the name — already satisfy AD-37's actual requirement, because the scope is
implied and constant (an `Ens.Config.Credentials` row is scoped to the install namespace, an
environment variable to the instance) and neither is a foreign key. What this story keeps from AD-37 is
the observable half: a reference that no longer resolves must not fail the read (AC7). Resolution is
Story 3.3's ladder and the "no longer present" rendering is Story 3.5's, both named above.

**Why this story publishes no copy, and returns codes instead.** EXPERIENCE.md's Fixed strings table
(`:252-332`) publishes no sentence for any validation rule — greps for `8192`, `32000`, `is required`
and `must be` return nothing. What it publishes is the *mechanism*: `:440`, *"server rules land on the
field they name"*, with the wording left to the field. `strings.ts:28-32` adds that a server-minted
`reason` is outside the string table's scope entirely, so a sentence returned from here would ship as
product copy that no gate verifies. AD-39's machine code is the channel the repo actually supports, and
Story 3.0 built the client-side pattern for it (`error-log.page.ts:284-308`). So each violation carries
`{field, code}`, Story 3.5 adds the table rows and the keys together in one batch, and this story leaves
`strings.test.mjs`'s cardinality at 221 = 206 + 12 + 3 untouched. Worth flagging for 3.5: the literal
band at `strings.test.mjs:306` allows 220 and the table holds 206, so eleven violation messages plus
the field labels and list columns will exceed it — that batch has to widen the band and its comment.

**Release 1 is a one-provider floor, and that is deliberate.** `epics.md:311` calls
`LLM/AnthropicProvider.cls` *"the only Release 1 provider"* and puts the other three at build step 7;
the PRD records the same decision (`prds/…/.memlog.md:70`, `addendum.md:43`), and EXPERIENCE.md:711
names the *"Anthropic-only floor"* directly. So the catalog ships one row and rule 2 accepts one value.
The consequence is that rule 8's `endpointRequired` column cannot fire in production at this floor —
which is why `Catalog.Table()` is an overridable seam and `Test/AgentRules.cls` drives the rule with a
second row. Left unexercised the rule would be unfalsifiable, which Rule 19 counts as a defect rather
than as coverage.

**Names, and the ones that must not travel.** `OcuPilot.Kernel.State.Agent` is 27 characters against
the 29-character cap that `check_naming` enforces on any `%Persistent`-reaching class; the more obvious
`OcuPilot.Kernel.State.AgentDef` is 30 and fails. The cap exists because the compiler hashes the
storage global of a longer name — the harvest map records exactly that happening twice, to
`^SessionAgenC88B*` and `^IRISCouch.Proje4479.MangoIndexD` (`HARVEST-PLAN.md:120`). Nothing harvested
keeps its name: the default credential name is `OcuPilotAnthropic`, never `SessionAgentAnthropic`, and
`check_rename_tokens` fails the build on the literal `SessionAgent` anywhere in the tree.

## Verification

**Commands** (client legs from `ui/`; throwaway legs need `npm run build` first, then
`sh scripts/ci-throwaway.sh up` — container `ocupilot-ci` on port 52776, which is what arms
`OCUPILOT_ALLOW_PRINCIPALS`. Never against the live `ocupilot` container, and never
`docker compose up`/`down` against it.):

- `uv run scripts/check-objectscript.py` — expected: 17 rules, no findings. The ones this story can
  trip are `check_naming` (the 29-character cap), `check_route_ordering` (the six new routes),
  `check_handler_wire_tests` (one wire test naming each route literal in code), and
  `check_state_package_isolation` (nothing under `Kernel/State/` may name `OcuPilot.Api`).
- `uv run scripts/test_check_objectscript.py` — expected: green; the checker itself is unchanged.
- Compile through the IRIS MCP tools with `server: "ocupilot-iris"`, namespace `HSCUSTOM`, and read the
  error text. Compile `Kernel/State/Agent.cls` **first and alone**, before the rest is written: it is
  the only file whose property names can be refused by the compiler (`ReadOnly` is also a property
  keyword), and a clean local file is not evidence that a class compiles.
- `node ui/tools/ci-runner.mjs --container ocupilot --class OcuPilot.Test.AgentSchema` — then the same
  for `AgentRules`, `AgentState` and `AgentWire`, **one class per invocation and one test call per
  message**, waiting for each run to land in `%UnitTest_Result` before sending the next. These four
  create and delete only definition rows, so they run on the dev container.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AgentWireSecurity` — the
  only leg that creates a principal, and the only one that must run on the throwaway.
- `cd ui && npm run build && npm test` — expected: unchanged and green. This story adds no client file,
  no `strings.ts` key and no descriptor, so `strings.test.mjs` still balances at 221 = 206 + 12 + 3,
  `screen-mirror.mjs --check` and `ipm-manifest.mjs --check` have nothing to regenerate, and
  `citations.test.mjs` — which does scan `src/OcuPilot/**/*.cls` — stays green because no new `.cls`
  writes a bare `EXPERIENCE.md:N` citation.
- `bash scripts/lint-docs.sh` — expected: clean. Verified 2026-09-15 that its document set is the
  nineteen files `scripts/check-prose.py` names and does **not** include
  `_bmad-output/implementation-artifacts/**`, so this spec is not linted by it; the command is listed
  because this story must leave all nineteen untouched, EXPERIENCE.md included.
- `bash scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` — expected: unchanged;
  zero executed checks is a failure, never a pass.

**How instance state is created and removed.** A definition is a row in the `OCUPILOT` protected
database and nothing else removes it, so each test class owns its own cleanup. `AgentSchema`,
`AgentRules`, `AgentState` and `AgentWire` create rows named `OcuPilotProbeAgent<n>` through the
guarded save and delete them in `OnAfterOneTest`, which then asserts
`SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent WHERE Name %STARTSWITH 'OcuPilotProbeAgent'` is 0 —
the residue check is an assertion, not a hope. These four run on the **live dev container
`ocupilot`**, because they create no principal, change no auditing and rotate no log.
`AgentWireSecurity` creates one IRIS user and one role and therefore runs **only on the throwaway
`ocupilot-ci`** behind `OCUPILOT_ALLOW_PRINCIPALS`, tearing both down in `OnAfterOneTest` and
re-checking `Exists()` afterwards, exactly as `Test/State.cls:130` does. **No audit rows are written by
this story**, so none are asserted; the structured console line is checked by subclassing
`Kernel/Audit/Log.WriteConsole` the way `Test/LogProbe.cls` already does, and a data key named
`credentialName` is expected to arrive `[redacted]` because `Log.cls:55` lists `credential`.

**Rule 19 — the mutation for each acceptance criterion's pinning test.** Each is the smallest change
that should break it; apply, observe red, revert, and confirm `git status --short` and
`git diff --stat` are byte-identical to the pre-mutation snapshot before recording the line.

- **AC1** — `mutation: add "Property ApiKey As %String;" to Kernel/State/Agent.cls → AgentSchema's
  no-secret-property assertion goes red naming ApiKey.` A second mutation for the foreign-key half:
  retype `CredentialName` to a persistent class → the datatype-only assertion goes red.
- **AC2** — `mutation: make AgentRules.Validate Quit after appending the first violation →
  AgentRules' accumulation test goes red with "expected 4 violations, found 1".`
- **AC3** — `mutation: delete the line in AgentRules.Normalize that clears the unselected credential
  name → the XOR test goes red because credentialName survives a credType of env.`
- **AC4** — `mutation: drop [ Unique ] from Index DefaultIdx in Kernel/State/Agent.cls → AgentState's
  second-default test goes red, because the save it expects to fail with #5808 succeeds.`
- **AC5** — `mutation: remove EndpointUrl from the changed-field set GuardedUpdate compares →
  AgentState's endpoint-change test goes red, the definition staying enabled and verified.`
- **AC6** — `mutation: delete the HoldsPrivilege("OcuPilotAdmin","USE") check from
  Api/Definitions.cls's write path → AgentWireSecurity's 403 legs go red on the throwaway, observing
  200 and a changed row count.` This one must be run inside a recorded and reverted window on
  `ocupilot-ci`, since it requires a rebuilt image.
- **AC7** — `mutation: make GuardedList fail the read when a credential reference does not resolve →
  the absent-credential test goes red.`
- **AC8** — `mutation: same as AC2, observed at the wire tier → AgentWire's 422 leg goes red, the
  response carrying one violation instead of four.`

A `mutation:` line that has not actually been run is not evidence; write each one only after observing
its red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

This is the plan stage only. The invocation directed a halt after planning, the spec meets the
READY-FOR-DEVELOPMENT standard on re-read, and no implementation was attempted.

**Ledger inbox (Rule 17).** `DW-20` — *"The single default definition is disabled by an endpoint change
or deleted"*, routed to this story on 2026-09-09 with the guard *"define the fallback - promote another
enabled definition, else the configuration-empty state"*. **Addressed**, not declined: six rows of the
I/O matrix, AC4, and the "DW-20, answered" note under Design Notes, which supplies the deterministic
tie-break the guard leaves open.

**Investigation notes carried forward.** Four questions the acceptance criteria assume an answer to had
none in the planning artifacts, and each is resolved in Design Notes rather than left for the
implementer: which eleven rules (two sources disagreed on the count); what the provider known set is at
this floor (`epics.md:311` — Anthropic only); how "exactly one default" is enforced (settled by a probe
on the live instance, since the harvest has no default flag and the spine has no AD); and whether the
credential reference must be an `EntityRef`. Two values are seeds rather than verified facts and are
recorded in the frontmatter `deferred:` list for harvest — the Anthropic row's model default and
suggestion list, and `RetentionDays`' default of 30.
