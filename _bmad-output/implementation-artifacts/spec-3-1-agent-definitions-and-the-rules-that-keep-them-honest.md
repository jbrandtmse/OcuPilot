---
title: 'Story 3.1: Agent definitions, and the rules that keep them honest'
type: 'feature'
created: '2026-09-15'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The console change record masks maxTokens, because the log redactor matches credential
      names as a substring and its list contains "token".
    evidence: |-
      Probed on the live instance: OcuPilot.Kernel.Audit.Log.IsCredentialName("maxTokens") is 1.
      Api/Definitions.ChangeSet keys each changed field by its wire name and Log.Redact masks the
      value under any matching key, so a token-ceiling change logs "maxTokens":"[redacted]" with
      neither old nor new value. Story 3.8 builds its audit row on that record.
    location: >-
      src/OcuPilot/Kernel/Audit/Log.cls:55 (CREDENTIALNAMES) with src/OcuPilot/Api/Definitions.cls ChangeSet
    severity: medium
baseline_revision: 'f49c0865daf8e621fbc6c12dd76f1e45d1f55c7e'
baseline_commit: 'f49c0865daf8e621fbc6c12dd76f1e45d1f55c7e'
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

**Review-pass patch list (2026-09-15).** Nineteen entries the review triaged `patch`. Each is the
smallest change that closes the finding; nothing else in the tree is to be touched.

- **P1 — `MergeBody` trusts the body's shape.** `src/OcuPilot/Api/Definitions.cls`. A field whose JSON
  value is an object or array is stringified to an OREF and stored: probed on the instance,
  `{"name":{"a":1}}` yields `5375@%Library.DynamicObject`, 27 characters, which passes rule 1, so the
  create answers **201** with that as the definition's name. A body that is a top-level JSON **array**
  is worse in kind: probed, `["x","y"].%IsDefined("name")` is 1 and `%Get("name")` returns element 0,
  so every writable field takes the same value. Fix: in `MergeBody`, skip a field whose
  `%GetTypeOf` is `object` or `array`; and refuse a body that is not a `%DynamicObject` through
  `RenderBadBody`. Tests: one wire leg posting an object-valued field, one posting a top-level array.
- **P2 — an uppercase scheme is refused.** `Kernel/AgentRules.IsAbsoluteHttps`. Probed:
  `HTTPS://api.anthropic.com/v1` returns 0, `https://...` returns 1. URI schemes are
  case-insensitive, so a valid endpoint is refused as `AGENT.ENDPOINT.SCHEME`. Fix: match the scheme
  case-insensitively. Test: add the uppercase spelling to the accepted set in `Test/AgentRules`.
- **P3 — the four `LogChange` call sites are driven by no test.** Deleting the `LogChange` line from
  `HandleCreate`, `HandleUpdate`, `HandleDelete` or `HandleSetDefault` leaves the whole suite green:
  `Test/AgentWire` calls `ChangeSet` and `DefinitionsProbe.LogChange` directly and never through a
  handler. Fix: one `AgentWire` leg that performs an accepted write over HTTP and then reads the
  console tail through `GET /api/ocupilot/logs/messages` — the pattern `Test/LogSourceWire.cls`
  already uses — asserting a line carrying `"subsystem":"agent-definition"`, the verb, and the
  definition's id.
- **P4 — AC5 is pinned nowhere above the state class.** Moving `SnapshotSecurityFields` in
  `HandleUpdate` to after `ApplyValues` defeats the disable-on-security-change at the only tier a
  client can reach, and no test goes red. Fix: an `AgentWire` leg that creates an enabled and
  verified definition through `Test/AgentFixture.CreateDefinition(name, 1, 1)`, `PUT`s
  `{"endpointUrl":"https://other.example.com/v1"}` asserting the response carries `enabled` 0 and
  `connectionVerified` 0, then re-enables through the fixture and `PUT`s
  `{"model":"claude-sonnet-5"}` asserting both stay 1.
- **P5 — two of the four catalog fallbacks cannot be falsified.** `canonicalMaxTokens` 32000 and
  `canonicalTemperature` 0 equal the class's own `InitialExpression`s, so deleting those two entries
  from `Definitions.CatalogDefaults()` moves no assertion. Fix: give `Api/Definitions` an overridable
  `CatalogClass()` seam, the way `Kernel/AgentRules` already has one; have `ApplyCatalogDefaults`
  read through it; point `Test/DefinitionsProbe` at `Test/CatalogProbe`; assert that a values array
  naming the probe provider with no `maxTokens` and no `temperature` comes back 8000 and 1, and that
  a key the body supplied is left alone.
- **P6 — no failing `PUT` and no duplicate name are exercised over the wire.** Two matrix rows
  phrased as HTTP outcomes — "Enable while unverified" and "Create, name already taken" — are
  asserted only inside `Validate`. Fix: two `AgentWire` legs — `PUT` with `enabled` `true` on an
  unverified definition answers 422 `AGENT.ENABLE.UNVERIFIED`, and a `POST` carrying a name an
  existing definition holds answers 422 `AGENT.NAME.DUPLICATE` on `name`.
- **P7 — a body key sent as `""` is asserted nowhere.** `Definitions.cls`'s header publishes "a key
  sent as `""` is an explicit empty value and is taken verbatim" as its contract, and no test sends
  one. Fix: extend the wire leg with a `PUT` carrying `{"endpointUrl":""}`, asserting the response
  and a re-read both show `""`, and one create carrying `"endpointUrl":""` asserting the catalog does
  not backfill it.
- **P8 — the temperature round trip is untested.** `Temperature` is `%Numeric(SCALE = 2)` while
  `IsNumberInRange` admits more precision; probed, `0.755` normalizes to `.76`. Fix: one wire leg
  posting a fractional temperature and asserting what comes back, per the project's round-trip rule.
- **P9 — `Catalog.Row()` does not stop on a match.** It scans the whole array after finding the key,
  so a duplicate key resolves to the last row. Fix: an argumentless `Quit` after setting `pRow` and
  `tFound`, so the first match wins and the scan ends.
- **P10 — the redaction assertion checks one value and its message claims two.**
  `Test/AgentWire` asserts `tLine [ "OcuPilotOther"` is 0 under the message "neither the old nor the
  new credential reference reaches the log"; the old value `OcuPilotAnthropic` is never checked. Fix:
  assert it too.
- **P11 — `Test/AgentSchema`'s secret-name list silently drops `key` and bare `token`.** A property
  named `Key` or `Token` would pass the check while the log redactor still masks it. Fix: add
  whole-name checks for `key` and `token` (no property is exactly either) and say in the doc comment
  that only the *substring* forms are excluded, because of `MaxTokens` and `CredentialName`.
- **P12 — the case-insensitive `NameIdx` claim is asserted only in the rule.**
  `Agent.GuardedByName`'s header states that the unique index collates case-insensitively; nothing
  drives a case-differing name into the index. Fix: an `AgentState` assertion that saving a name
  differing only in case is refused with `#5808`.
- **P13 — `TestBothIndexesAreDeclaredUnique` can raise `<INVALID OREF>`.** Its last two lines call
  `%OpenId(...).Properties` unguarded. Fix: guard them the way the loop above already does, so a
  missing index is a named assertion failure rather than a crash.
- **P14 — `Test/AgentFixture` counts case-insensitively and removes case-sensitively.** `ProbeCount`
  uses `%STARTSWITH`, `RemoveProbeDefinitions` uses `$Extract`; a probe row named in another case
  would be counted and never removed, so teardown could not pass. Fix: fold case in the comparison.
- **P15 — the rule numbering contradicts itself.** `AgentRules.Validate`'s `<ol>` numbers all
  fourteen checks, and `CatalogClass()` follows it with "rule 9", while `Api/Error.cls`,
  `Kernel/Provider/Catalog.cls`, `Test/AgentRules.cls` and `Test/CatalogProbe.cls` all use the
  eleven-harvested-rule numbering in which the endpoint rule is 8. Fix: use the eleven-rule numbering
  everywhere; also correct `Test/AgentRules.cls`'s header, which says "thirteen rules" against
  fourteen violation codes.
- **P16 — `Test/AgentWireSecurity`'s header carries the claim this story corrected.** Its
  `TestEveryOtherRouteIsRefusedByNameAndWritesNothing` doc comment says the mutation is observed as
  "200 and a changed row count"; the method's own inline comment and AC6's amended mutation line both
  record that the count did **not** move. Fix: replace the header clause with what was observed.
- **P17 — `scripts/ci-throwaway.sh`'s armed-class list is one short.** The comment enumerating the
  classes `OCUPILOT_ALLOW_PRINCIPALS` arms does not name `AgentWireSecurity`. Fix: add it.
- **P18 — `TestTheClassNameIsInsideTheStorageGlobalCap` cannot fail.** It compares two parameters of
  the test class, so renaming the production class cannot turn it red. Fix: say in the doc comment
  that `scripts/check-objectscript.py`'s `check_naming` is the gate that enforces the cap and this is
  a read-off of it.
- **P19 — two comments describe a body value that cannot arrive.** `Fields()` declares
  `connectionVerified` non-writable, so `HandleCreate`'s "whatever the body said" and
  `HandleUpdate`'s "never the body's claim about it" narrate a defence against something `MergeBody`
  cannot do. Fix: keep the lines as belt-and-braces and reword the two comments to say so.

### Review Findings

**Code review (2026-09-15).** Four layers at the `full-opus` tier: Blind Hunter, Edge Case Hunter,
Verification Gap, Acceptance Auditor. Seventeen entries survived triage: 0 high, 7 medium in-story
(patched), 2 medium in-epic (routed, DW-330 and DW-331), 8 low (patched); twelve rejected on their
refutations, listed below. **No AD or Consistency-Conventions
mismatch**: the schema ships eighteen `%Library` scalars, no `ApiKey`, no collection, no
persistent-class-typed property, no hand-written `Storage`, both indexes unique, and the credential
reference as two scalars (AD-9, AD-35, AD-37, AD-39, AD-42 and
`.claude/rules/iris-persistent-storage.md` all checked against the shipped code, not the spec's claim).

- [x] [Review][Patch] Three of the four `LogChange` call sites were driven by no test, under a doc comment claiming all four were falsifiable — P3 closed one quarter of itself [src/OcuPilot/Test/AgentWire.cls:236]
- [x] [Review][Patch] A created definition's `readOnly`, `retentionDays` and `maxIterationsPerTurn` were asserted nowhere, so flipping `ReadOnly`'s `InitialExpression` to the permissive value left the suite green [src/OcuPilot/Test/AgentWire.cls:92]
- [x] [Review][Patch] `IsAbsoluteHttps` accepted userinfo, so `https://user:sk-ant-KEY@host/v1` stored a secret in the one field that is projected and logged verbatim (AD-35's closed loop) — and refused a valid query-only URL [src/OcuPilot/Kernel/AgentRules.cls:206]
- [x] [Review][Patch] `TestTheClassNameIsInsideTheStorageGlobalCap` compared two parameters of the test class and could not fail; it now sweeps the instance's own class dictionary [src/OcuPilot/Test/AgentSchema.cls:125]
- [x] [Review][Patch] `## Design Notes` was deleted by this diff, taking the Rule 6 governing-AD block and the Rule 2 `Consumes:`/`Consumed-by:` lists — while the surviving ledger-inbox paragraph still cites its "DW-20, answered" note [spec:479]
- [x] [Review][Patch] An unterminated backtick swallowed the `## Auto Run Result` heading, leaving `Status:`/`Blocking condition:` as list-continuation text under the triage log [spec:477]
- [x] [Review][Patch] The per-AC Rule 19 mutation record for AC1 and AC3-AC7 was deleted in the same pass whose `## Auto Run Result` claims every one of them was applied [spec:739]
- [x] [Review][Patch] A boolean field sent as a quoted string was coerced with `+tValue`, so `{"readOnly":"true"}` and `{"readOnly":"false"}` both stored 0 — fail-open on the flag Story 3.7 enforces [src/OcuPilot/Api/Definitions.cls:420]
- [x] [Review][Patch] `SelectionProjection` wrote `name`, `provider` and `model` untyped, so a value that reads as a number was a JSON number in the list and a string in the read [src/OcuPilot/Api/Definitions.cls:482]
- [x] [Review][Patch] `TestTheStorageSectionIsTheCompilersOwn` kept the unguarded chained `%OpenId` that P13 fixed in its sibling two methods below [src/OcuPilot/Test/AgentSchema.cls:140]
- [x] [Review][Patch] A mutation line named `OcuPilot.Api.Definitions.IsJsonObject`, which exists nowhere; the guard is `BodyIsReadable` [src/OcuPilot/Test/AgentWire.cls:395]
- [x] [Review][Patch] `Catalog`'s header claimed to be "the only place in the tree" spelling a provider key, which five test classes contradict [src/OcuPilot/Kernel/Provider/Catalog.cls:1]
- [x] [Review][Patch] `TestEveryNamedFieldIsPresent`'s doc said thirteen fields against a fourteen-property loop [src/OcuPilot/Test/AgentSchema.cls:104]
- [x] [Review][Patch] `TestAnEmptyOrOverlongNameIsRefused` passed a dead `$Justify("", 65)` argument, immediately overwritten [src/OcuPilot/Test/AgentRules.cls:77]
- [x] [Review][Patch] `## Auto Run Result` said twenty entries were patched against a nineteen-entry list, and claimed the triage log records all 58 findings when it enumerates a subset [spec:502]
- [x] [Review][Defer] An explicit set-default onto a disabled definition is accepted, then silently relocated by the next unrelated write — unreachable over the API today, since nothing here sets `ConnectionVerified` [src/OcuPilot/Kernel/State/Agent.cls:237] — deferred: DW-330, routed owner=3-4-test-connection
- [x] [Review][Defer] A create's change record is diffed against the class `InitialExpression`s, so every field created at its default is absent from the record Story 3.8 builds its audit row on [src/OcuPilot/Api/Definitions.cls] — deferred: DW-331, routed owner=3-8-every-configuration-change-is-resource-gated-and-audited

**Rejected.**

- Over-length `model`/`endpointUrl`/`envVarName`/`credentialName` render 500 rather than 422 — already adjudicated `[reject]` in this story's triage log with a recorded rationale; re-raised, not re-opened.
- `RenderBadBody` concatenates `$System.Status.GetErrorText` into the client reason — the matrix row AC's naming the `ReadRequestBody` stage, and the caller is already an administrator holding `%Admin_*`.
- `Catalog.Row()`'s first-match `Quit` (P9) is exercised by nothing — a duplicated key in a compiled XData table is a build fault, the class the triage log already rejected; what would make it real is Story 3.2 adding a second row that duplicates a key.
- The log-tail read could be pushed off the page during a full suite run — theoretical: the method has passed inside a 64-class run and four times in this pass; reopen if it reds in CI with the record present in `messages.log`.
- `MarkRow` stamps `UpdatedAt` on a rebalanced bystander, and a default move records only the gaining row — the row did change, and the record's shape is Story 3.8's, already adjudicated here.
- `ChangeSet` carries an `updatedAt` pair on every update — same owner, same adjudication.
- `<INVALID OREF>` windows between an id query and its open in `GuardedRebalanceDefault`/`MarkRow` — concurrent delete on a configuration surface holding a handful of rows; the triage log rejected the atomicity finding on the same ground, and the next write self-heals.
- Numeric bounds split between parameters and literals, `32000` in three places — the triage log's schema-range rejection covers it: the validator is the single source, and parameterising adds the duplication the refutation warns about.
- The smoke carries no `pending` naming the six definition routes — true (the two Epic 3 entries are `agentwrite` and `auditmarker`), but smoke coverage is story-sized work, not a fix-pack item; reopen if a definitions route regresses undetected.
- `RenderNotFound(pId)` declares a parameter it never reads — deliberate, and the doc comment says why.
- "Every commit carries `[skip ci]`" — false: `3d3da7f`, the source commit, carries none.
- "The uncommitted QA test files and `status: done` against sprint-status `review` are defects" — false: both are the designed `/epic-cycle` state; QA and code-review spawns do not commit, and the lead commits at the gate.

## Spec Change Log
- 2026-09-15, lead (spec gate, owner-delegated): both seed values are decided rather than carried. The Anthropic catalog row's **default model is `claude-opus-5`**, and its suggestion list is `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5-20251001`, `claude-fable-5-1` - the current Claude family, most capable first; the stale `claude-opus-4-7` is not carried at all. The catalog stays the one-source mechanism the plan designed, so a later model is a row edit. **`RetentionDays` defaults to 30**, inert until Story 14.4 enables the field and ships the purge task.

## Review Triage Log

### 2026-09-15 — Review pass
- verdicts: 58 findings — high 0, medium 10, low 45, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` Over-length `model`/`endpointUrl`/`envVarName`/`credentialName` fail at `%Save` (#7201) and render 500 rather than 422 — real (probed), but a >128-character model name is not everyday use and the fix adds violation codes, which is public surface Story 3.5 must publish copy for.
  - `[low]` `[reject]` Create, update and delete are not atomic with the marker rebalance — reachable only through an infrastructure failure mid-operation, and self-healing: the next write re-runs `GuardedRebalanceDefault`, which promotes when nothing is marked.
  - `[low]` `[reject]` `HandleList` skips a row it cannot open — the reachable cause is a concurrent delete, for which omitting the row is correct; erroring the whole list would make the common case worse.
  - `[false]` `[reject]` "The schema enforces none of the ranges the validator polices" — the claimed harm is two layers drifting, but there is only one layer: the validator is the sole source, and adding `MINVAL`/`MAXVAL` would create the duplication the finding warns about.
  - `[low]` `[patch]` Temperature admits more precision than `%Numeric(SCALE = 2)` keeps and the round trip is untested — P8 added a wire leg posting `0.755` and asserting `0.76` from both the create and the re-read.
  - `[low]` `[reject]` Nothing requires `model` non-empty or `endpointUrl` to survive an update — the intent scopes validation to the eleven harvested rules and none covers it; a twelfth rule is new public surface. P7 makes the accepted behaviour observable.
  - `[low]` `[reject]` `HandleSetDefault` projects the row it already holds — correct today and pinned by the set-default wire leg, which asserts `default` 1 on the response; it rests on `%OpenId`'s documented in-memory identity, not on luck.
  - `[low]` `[reject]` A default move records the gaining row and not the losing one, and automatic promotions are unrecorded — the operation itself is recorded and the previous owner is recoverable from the preceding record; the record's shape is Story 3.8's to settle.
  - `[medium]` `[defer]` `maxTokens` is redacted out of the change record — confirmed on the instance; root cause is the pre-existing substring redactor in `Kernel/Audit/Log.cls`, filed to the frontmatter `deferred:` list.
  - `[low]` `[reject]` All three `ReadRequestBody` stages render one 400 and the reason carries internal fault text — the read and decode branches need an infrastructure fault, the caller is already an administrator, and the fix adds a branch no test can drive.
  - `[low]` `[reject]` No optimistic concurrency on update (lost update) — last-write-wins is the conventional behaviour of a REST config surface with no stated concurrency contract; two administrators editing one definition at the same moment is not everyday use and the fix is a whole ETag contract.
  - `[low]` `[reject]` `GET /agent/definitions` is unbounded and issues one open per row — AD-36 binds "every list screen and every read tool"; these are descriptor-less configuration routes, the `/instance`, `/namespaces`, `/navigation` precedent the spec's AD-5 note names, so this is not an AD violation, and the population is a handful of definitions.
  - `[low]` `[reject]` A broken provider table reads as "every provider unknown" rather than an error — the XData block is compiled into the class, so the condition is a build fault, not a runtime one.
  - `[low]` `[reject]` The catalog is re-parsed per lookup and `Fields()` rebuilt per call — a configuration route at low volume; caching adds state for no measured gain.
  - `[low]` `[reject]` `Catalog.Table()` names its own class rather than `$classname()` — the documented seam (override `Table()`) works, which is what `CatalogProbe` does; `$classname()` is not a safe one-token substitution in a class-method context.
  - `[low]` `[patch]` `Catalog.Row()` scans past a match, so a duplicated key resolves to the last row — P9 added the argumentless `Quit`.
  - `[medium]` `[patch]` `canonicalMaxTokens` and `canonicalTemperature` equal the class's own `InitialExpression`s, so two of four catalog fallbacks cannot be shown to run — P5 added the `CatalogClass()` seam and an assertion through `CatalogProbe`'s 8000/1 row.
  - `[low]` `[reject]` Nothing pins the shipped catalog row's shape — refuted in part: the key set, `defaultModel`, `defaultEndpoint` and `endpointRequired` are all asserted; the remaining columns have no consumer until Stories 3.2 and 3.5, which add the second row.
  - `[medium]` `[patch]` No failing `PUT` and no duplicate name are exercised over the wire, though both are matrix rows phrased as HTTP outcomes — P6 added both legs.
  - `[low]` `[patch]` The redaction assertion checks the new credential value under a message claiming both — P10 added the assertion for the old value.
  - `[low]` `[patch]` `AgentSchema`'s secret-name list silently drops `key` and bare `token` — P11 added whole-name checks for both and said in the doc comment that only the substring forms are narrowed.
  - `[low]` `[patch]` `GuardedByName`'s case-insensitive-index claim is asserted only in the rule — P12 added an `AgentState` assertion that a case-differing name is refused with `#5808`.
  - `[low]` `[reject]` No smoke coverage for the six definition routes — the smoke already carries two explicit `pending` entries for Epic 3, and this story's Verification pins the smoke as unchanged.
  - `[low]` `[patch]` The rule numbering contradicts itself across six sites — P15 put every site on the eleven-harvested-rule numbering and labelled the two OcuPilot-own checks by the decision that forced them.
  - `[low]` `[patch]` `AgentWireSecurity`'s header still claimed the mutation changes the row count, which this story's own AC6 line corrects — P16 replaced the clause.
  - `[low]` `[patch]` The spec's plan-stage record miscounts the Execution list's files and says the seeds went to `deferred:` — corrected in this pass's `## Auto Run Result`.

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

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** The eleven files the Execution list names — `Kernel/State/Agent.cls`,
`Kernel/Provider/Catalog.cls`, `Kernel/AgentRules.cls`, `Api/Error.cls`, `Api/Definitions.cls`,
`Api/Router.cls` and the five `Test/Agent*` classes — plus three test probes and one shared fixture:
`Test/CatalogProbe` (a second catalog row, so rule 8 has a failing case), `Test/AgentRulesProbe` and
`Test/DefinitionsProbe` (which route the validator's and the handler's catalog and log seams at the
probes), and `Test/AgentFixture` (creates and purges the `OcuPilotProbeAgent*` rows the instance
classes share). One line of `scripts/ci-throwaway.sh`'s armed-class comment was corrected.

**Files changed.** `src/OcuPilot/Kernel/State/Agent.cls` — the definition, eighteen named scalars, no
`ApiKey`, `NameIdx` and `DefaultIdx` both unique, and `GuardedRebalanceDefault` holding every DW-20
promotion in one place. `src/OcuPilot/Kernel/Provider/Catalog.cls` — the one-row provider table and
its overridable `Table()` seam. `src/OcuPilot/Kernel/AgentRules.cls` — `Normalize` and a `Validate`
that accumulates all fourteen checks with no early quit. `src/OcuPilot/Api/Definitions.cls` — six
handlers, the `OcuPilotAdmin:USE` gate, the 422/403/404/400 envelopes, and `ChangeSet`/`LogChange`,
the seam Story 3.8 wires to `$System.Security.Audit()`. `src/OcuPilot/Api/Router.cls` — six routes,
longest first, with thin `Call=` wrappers. `src/OcuPilot/Api/Error.cls` — seventeen machine-code
parameters. Five `Test/Agent*` classes, three probes and one fixture carry the assertions.

**Review.** Four layers reported 58 findings: 0 high, 10 medium, 45 low, 3 false. Nineteen entries were
patched — the list P1-P19 in `## Tasks & Acceptance` — and applied by a fresh subagent working from
it; one medium was deferred to the frontmatter `deferred:` list (the log
redactor masks `maxTokens`, because it matches credential names as a substring — a pre-existing
`Kernel/Audit/Log.cls` behaviour this story is the first to meet). The rest were rejected on their
refutations; the triage log above records the dispositioned subset rather than all 58. The three `false` verdicts are the
schema-range claim, the model-only-edit-clears-a-credential claim and the `AgentState` precondition
claim. One correction was applied after the patch subagent returned: its body guard also refused an
**absent** body, which would have re-conflated the two things DW-24 separates, so
`Definitions.BodyIsReadable` now admits a missing body and refuses only a parsed non-object.

**Two decisions the plan left open**, both documented at their call sites: the malformed-body refusal
needed a machine code, so `AGENT.BADBODY` is declared beside the others rather than minted at the call
site; and the change record is keyed by field name rather than carrying the name as a value, because
`Kernel/Audit/Log.Redact` masks by key and the credential reference only arrives `[redacted]` that
way. The spec asks for both that redaction and a `{field, old, new}` entry shape, which are
incompatible; the redaction its Verification asserts is what was kept.

**Verification.** `check-objectscript.py` 231 files / 17 rules / 0 problems and its 85-test harness
green; `lint-docs.sh` clean over its nineteen files; the tree loaded and compiled into `ocupilot`
through the IRIS MCP tools with `server: "ocupilot-iris"`, no errors. Full ObjectScript suite on a
fresh `ocupilot-ci` throwaway: **64 classes, 612 tests, 0 failed**, 0 probe leftovers, 0 overlaps —
`AgentSchema` 7, `AgentRules` 17, `AgentState` 10, `AgentWire` 14, `AgentWireSecurity` 2. `npm run
build` and `npm test` (720 + 290) unchanged. `smoke.sh` 17 executed, 17 passed. Every Rule 19 mutation
in `## Verification` was applied, observed red and reverted. The live `ocupilot` container holds zero
agent definitions and was never `up`ped or `down`ed; the throwaway was removed.

**Follow-up review recommended: true.** Six medium entries were patched. The one risk left unverified by
assertion — `BodyIsReadable` admitting an absent body before any field is read, with a `POST` falling to
the rules and a `PUT` changing nothing — is closed in `## Verification` below by
`Test/AgentWire:TestAnAbsentBodyIsAdmittedFallsToTheRulesOnCreateAndChangesNothingOnUpdate` (QA).

**Ledger inbox (Rule 17).** `DW-20` — *"The single default definition is disabled by an endpoint change
or deleted"*, routed here on 2026-09-09 with the guard *"define the fallback - promote another enabled
definition, else the configuration-empty state"*. **Addressed**: six rows of the I/O matrix, AC4, and
the "DW-20, answered" note under Design Notes supply the deterministic lowest-`ID` tie-break, all of it
exercised by `Test/AgentState`.

## Verification

**QA pass (2026-09-15).** Checked the four candidates the gate named against the shipped suite. One
was the follow-up review's own named gap (the absent-body path); one was a refuted-in-part finding
(the shipped catalog row's shape) whose remaining unpinned column, `modelSuggestions`, had no consumer
and no assertion. Both are closed below. The other two — the eleven-rule accumulator and the
`endpointRequired` catalog seam — were already pinned (`Test/AgentRules`, `Test/AgentRulesProbe`,
`Test/CatalogProbe`) and are re-verified by mutation rather than re-pinned. The admin gate is already
exercised route-by-route against a real least-privileged principal in `Test/AgentWireSecurity` (the
list route served 200 with the six-key selection projection; each of the other five answered 403
naming `AUTH.NOPRIVILEGE` / `OcuPilotAdmin:USE` individually, with the row count and per-row state
checked after) — no route stands in for another, so no new test was added there.

**Commands:**

- `uv run scripts/check-objectscript.py` — 231 files / 17 rules / 0 problems (one forbidden-literal
  finding on a first draft of the catalog-row pin, corrected before compiling).
- IRIS MCP (`server: "ocupilot-iris"`): loaded and compiled `Test/AgentWire.cls` and
  `Test/AgentRules.cls`, one `iris_execute_tests` call per message, each waited to land before the
  next — `Test.AgentWire` 15/15 and `Test.AgentRules` 18/18, both before the mutations below and
  again after each revert. `SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent` read 0 before, during
  and after the whole pass; the live `ocupilot` container was never `up`ped or `down`ed and no
  principal was created.

**Rule 19 — the mutation for each acceptance criterion's pinning test (implement pass).** Restored by
the code review: the section was deleted in the same pass whose `## Auto Run Result` says every one of
them was applied, observed red and reverted. AC6's line records what was actually observed, which is a
403 becoming a 200 with the row count unmoved.

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
  200 where a 403 was expected; the row count does not move, because the writes the mutation admits
  are refused by the rules instead.` Run inside a recorded and reverted window on `ocupilot-ci`,
  since it requires a rebuilt image.
- **AC7** — `mutation: make GuardedList fail the read when a credential reference does not resolve →
  the absent-credential test goes red.`
- **AC8** — `mutation: same as AC2, observed at the wire tier → AgentWire's 422 leg goes red, the
  response carrying one violation instead of four.`

**Mutations (Rule 19) — QA pass: applied, observed red, reverted, and confirmed byte-identical
(`git status --short` / `git diff --stat`) before recompiling green:**

- The absent-body admission — mutation: `Api/Definitions.BodyIsReadable`'s `If '$IsObject(pBody)
  Quit 1` changed to `Quit 0` → `Test.AgentWire:TestAnAbsentBodyIsAdmittedFallsToTheRulesOnCreateAndChangesNothingOnUpdate`
  red alone (run 2064; the other 14 methods stayed green), the bodyless create answering 400
  `AGENT.BADBODY` instead of falling to the rules. Reverted; `Api/Definitions.cls` byte-identical;
  recompiled; 15/15 green (run 2065).
- The shipped catalog row's shape — mutation: dropped `claude-fable-5-1` from the `anthropic` row's
  `modelSuggestions` in `Kernel/Provider/Catalog.cls`'s `Providers` XData →
  `Test.AgentRules:TestTheShippedProviderRowIsPinned` red alone on the suggestion-list assertion
  (run 2066; the other 17 methods stayed green). Reverted; `Catalog.cls` byte-identical; recompiled;
  18/18 green (run 2067).
- The eleven-rule accumulator (pre-existing claim, re-verified rather than newly pinned) — mutation:
  added `If +$Get(pViolations) Quit +$Get(pViolations)` in `Kernel/AgentRules.Validate` immediately
  after the provider check → `Test.AgentRules:TestFourBrokenRulesYieldFourViolationsInDeclaredOrder`
  red alone, one violation instead of four (run 2068), and, in a separate single-method run,
  `Test.AgentWire:TestACreateBreakingFourRulesAnswersOneEnvelopeAndWritesNothing` red the same way
  (run 2069). Reverted; `AgentRules.cls` byte-identical; recompiled; both classes re-run in full and
  green (runs 2070, 2071).

mutations_demonstrated=3

**Files (QA).**

- `src/OcuPilot/Test/AgentWire.cls` — added
  `TestAnAbsentBodyIsAdmittedFallsToTheRulesOnCreateAndChangesNothingOnUpdate`: a direct assertion
  that `BodyIsReadable` admits `""`, a bodyless create falling to the rules (three violations —
  name, provider, credType — the exact set an entirely empty submission trips), and a bodyless
  update on an existing definition leaving every field, including the security-relevant flags,
  unchanged.
- `src/OcuPilot/Test/AgentRules.cls` — added `TestTheShippedProviderRowIsPinned`: the full shipped
  `anthropic` catalog row asserted field by field, closing the gap in `modelSuggestions`, the one
  column the review's refutation left unpinned.

**Mutations (Rule 19) — code-review pass: applied, observed red, reverted, and confirmed
byte-identical (per-file `md5` plus `git diff --stat`) before recompiling green:**

- The four change-record call sites — mutation: deleted `Do ..LogChange("update", …)` from
  `Api/Definitions.HandleUpdate` →
  `Test.AgentWire:TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler` red alone (run 2079; the
  other 14 methods stayed green), naming the update verb. Reverted; recompiled; 15/15 (run 2083).
- The endpoint authority — mutation: restored `[^/?#\s]+(/[^\s]*)?` as `IsAbsoluteHttps`'s pattern
  → `Test.AgentRules:TestAnEndpointThatIsNotAbsoluteHttpsIsRefused` red alone (run 2077), the two
  userinfo spellings accepted with no violation and the query-only URL refused. Reverted;
  recompiled; 18/18 (run 2082).
- The created definition's safe defaults — mutation: `Kernel/State/Agent.ReadOnly` to
  `[ InitialExpression = 0 ]` → `Test.AgentWire:TestASoundCreateIsReturnedByTheListImmediately` and
  `TestABodyThatIsNotAMapOfScalarsIsRefused` red (run 2078); before the assertions this pass added,
  that mutation moved nothing in the suite. Reverted; recompiled; 15/15 (run 2083).
- The class-name cap — mutation: narrowed the sweep's `Name %STARTSWITH 'OcuPilot.'` to a prefix no
  class holds → `Test.AgentSchema:TestTheClassNameIsInsideTheStorageGlobalCap` red alone (run 2080)
  on the coverage assertion, which the two-parameter comparison it replaced could not do. Reverted;
  recompiled; 7/7 (run 2081).

mutations_demonstrated=4

**Commands (code review).**

- `uv run scripts/check-objectscript.py` — 231 files / 17 rules / 0 problems.
- `bash scripts/lint-docs.sh` — 19 files, 0 issues; `check-prose` 0 problems.
- IRIS MCP (`server: "ocupilot-iris"`), one `iris_execute_tests` call per message, each waited to
  land: `AgentSchema` 7/7, `AgentRules` 18/18, `AgentWire` 15/15, `AgentState` 10/10 before the
  mutations and again after every revert. `SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent` read 0
  at the end of the pass. `AgentWireSecurity` was **not** re-run: it needs a principal, which only
  the `ocupilot-ci` throwaway may hold, and this pass changed no code it exercises — the selection
  projection's added type hints change value types, not the six key names it asserts.
- The live `ocupilot` container was never `up`ped or `down`ed and no principal was created on it.
