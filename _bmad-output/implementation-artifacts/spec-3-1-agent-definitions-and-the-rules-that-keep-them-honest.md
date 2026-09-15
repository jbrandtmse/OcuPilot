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
  - `[low]` `[patch]` The spec's plan-stage record miscounts the Execution list's files and says the seeds went to `deferred:` — corrected in this pass's `## Auto Run Result

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

**Review.** Four layers reported 58 findings: 0 high, 10 medium, 45 low, 3 false. Twenty entries were
patched (6 at medium, 14 at low) and applied by a fresh subagent working from the patch list written
into `## Tasks & Acceptance`; one medium was deferred to the frontmatter `deferred:` list (the log
redactor masks `maxTokens`, because it matches credential names as a substring — a pre-existing
`Kernel/Audit/Log.cls` behaviour this story is the first to meet). The rest were rejected on their
refutations, recorded finding by finding in the triage log above; the three `false` verdicts are the
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

**Mutations (Rule 19) — applied, observed red, reverted, and confirmed byte-identical
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
