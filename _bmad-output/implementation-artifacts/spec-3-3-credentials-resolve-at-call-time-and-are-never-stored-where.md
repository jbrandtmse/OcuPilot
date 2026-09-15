---
title: 'Story 3.3: Credentials resolve at call time and are never stored where OcuPilot can show them'
type: 'feature'
created: '2026-09-15'
status: 'done'
baseline_revision: 'bf3ce4d05e44524c66033f0ffdcaacaeae773a55'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      AC4's inline key-shape rendering -- aria-invalid wired through aria-describedby, evaluated
      on blur -- has no client surface in this story, because the Definition form does not exist
      yet. The server-side refusal ships here; the rendering is Story 3.5's form-page contract.
    evidence: |-
      epics.md:2418 already makes inline validation on blur plus aria-invalid and
      aria-describedby Story 3.5's own acceptance criterion, and no ui/ file for this screen
      exists. Story 3.1 recorded the same split for its validation copy.
    location: >-
      Story 3.5 (The Definition form); this story ships AGENT.KEY.SHAPE on the apiKey field
    severity: medium
  - summary: >-
      AC5's key-field rendering -- empty after save, the published caption "Stored. Enter a new
      value to replace it.", a labeled reveal toggle, pastes accepted without trimming -- is
      entirely client work with no surface in this story.
    evidence: |-
      The copy is already published in EXPERIENCE.md:298 and the masked-secret-field pattern at
      :366; the strings.ts key lands with the component, the split Story 3.1 recorded. The
      server half that makes it true -- no route returns a stored value -- ships here.
    location: >-
      Story 3.5 (The Definition form)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Story 3.2 shipped one rung of the credential ladder — the environment variable — and no
way to put a key anywhere. A definition names a credential it cannot store, the IRIS-credentials
rung answers `""` on every instance, and a turn whose reference no longer resolves fails silently
forever because nothing marks the definition (DW-22).

**Approach:** Complete the ladder: add the `creds` rung behind a namespace-reachability predicate,
reached by dynamic dispatch so OcuPilot still compiles where Interoperability is absent. Add one
write-only endpoint that puts a key into that store and returns nothing, with the per-provider shape
check applied through the shipped argument-free seam. On an unresolved reference at call time, the
port clears the stored definition's verification so the operator sees the broken one.

## Boundaries & Constraints

**Always:**
- The ladder returns `%String`, never `%Status`; `""` is the only "unresolved" signal, and no
  message anywhere names a value (AD-35, AD-42).
- **No OcuPilot frame binds key material to a local.** The value moves property → property →
  vendor argument: `%DynamicObject` member into `Base.ApiKey`, `%DynamicObject` member into the
  credential row's `Password`. `^%ETN` captures the local symbol table at **every** stack level
  (AD-48) and OcuPilot renders that log (AD-35, AD-46).
- `Ens.Config.Credentials` is named only through `$ClassMethod` / late-bound property access and a
  single `Parameter`, never `##class(...)`, so the tree compiles on an edition without
  Interoperability — the `images` CI leg compiles it on `intersystems/iris-community:2026.2`.
- Every new refusal is a `{field, code}` violation in Story 3.1's accumulating envelope shape, so
  Story 3.5's error summary renders it unchanged.
- Compile through the IRIS MCP tools with `server: "ocupilot-iris"`; `uv run
  scripts/check-objectscript.py` clean (`check_route_ordering`, `check_handler_wire_tests`,
  `check_naming`, `check_rename_tokens`).

**Never:**
- No client file, no `strings.ts` key, no screen descriptor. AC4's `aria-invalid` /
  `aria-describedby` wiring and AC5's reveal toggle, caption and paste handling are Story 3.5's
  `form-page` contract (`epics.md:2418`) — see Design Notes.
- No `$System.Security.Audit()` call: the triple is unregistered and would be dropped (AD-15).
  Story 3.8 emits from the one `Api/Definitions.LogChange` seam. Same split 3.1 and 3.2 recorded.
- No real outbound call to a paid API. No principal, SSL configuration or `^ERRORS` write on the
  live `ocupilot` container; no `docker compose up`/`down` against it.
- No second read-only or kill-switch enforcement point (AD-30). No key ever reaches a `ChangeSet`,
  a `LogChange` payload, a `%Status` or a log line.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Store a key, `creds` rung | admin, definition `credType` `creds`, name `OcuPilotProbeCredential`, reachable rung | 200 `{"stored":true}`; the row holds the value; the definition's `Enabled` and `ConnectionVerified` are cleared | body carries no part of the value |
| Store, `env` rung | `credType` `env` | 422, `AGENT.CREDENTIAL.ENVUNWRITABLE` on `apiKey` | IRIS publishes `GetEnviron` and no setter, so OcuPilot cannot write it; the operator sets it on the host |
| Store where the rung is unreachable | `credType` `creds`, `Ens.Config.Credentials` absent in the namespace | 422, `AGENT.CREDENTIAL.RUNGUNAVAILABLE` on `apiKey` | never attempts the write |
| Store a badly shaped key | value fails the row's `keyPrefix` gate | 422, `AGENT.KEY.SHAPE` on `apiKey`; **nothing is written** | the reason states the expected prefix, never the value |
| Store with no `apiKey` member | `{}` or a non-string member | 422, `AGENT.CREDENTIAL.REQUIRED` on `apiKey` | absent body read as naming no field, as Story 3.1 reads it |
| Store, not an administrator | authenticated, no `OcuPilotAdmin:USE` | 403, `AUTH.NOPRIVILEGE` with `detail.failedPair` | the shipped `RenderForbidden` |
| Store, unknown id | any body | 404, before the body is read | the shipped `RenderNotFound` |
| Store fails in the vendor | `%Save()` answers an error | 500, generic reason; the vendor status's **error codes only** reach the log | the raw status text is discarded, never logged (AD-35) |
| Resolve, `env` rung | variable set, rung predicate answers 0 | the value, unchanged | the env arm consults no namespace and no rung predicate |
| Resolve, `creds` rung, reachable | row exists | its `Password` | never through `GetValue`, which answers a `<N/A ...>` placeholder string on failure |
| Resolve, `creds` rung, unreachable or absent row | either | `""` | no status, no log line, no exception |
| Turn whose reference no longer resolves | `ProviderPort.Invoke` on a stored, enabled definition | `PROVIDER.CREDENTIAL` naming the reference **and** the row's `Enabled` and `ConnectionVerified` cleared | **DW-22** |
| Same failure through `InvokeDraft` | values a caller supplied | the same refusal; **no stored row changes** | there is no row to flag, and testing a disabled definition is how it is re-enabled |
| Reinstall over a disabled TLS configuration | `Enabled` 0 or `Type` 1 on `OcuPilotProvider` | repaired to `Enabled` 1, `Type` 0, and the report names the drifted fields | **DW-335** |

</intent-contract>

## Code Map

Anchors verified against the working tree on 2026-09-15.

**Shipped, and already satisfying part of this story**

- `src/OcuPilot/Kernel/Secret/Ladder.cls` — `Resolve` **:30** (env arm only; `creds` answers `""`),
  `Environment` **:42** (the overridable seam, value read twice rather than held in a local). Its
  header **:9-14** already names this story as the one that replaces the body.
- `src/OcuPilot/Kernel/Provider/Base.cls` — `Property ApiKey [ Internal ]` **:41**, `KeyPrefix`
  **:45**, `SecretClassName` **:54**, `Invoke` **:102** (resolves straight onto the property **:114**,
  `PROVIDER.CREDENTIAL` **:116**, shape gate **:119**, clear on every exit **:128,:137,:142**),
  `IsApiKeyShapeValid()` **:332** — **argument-free by review decision**; reuse it, do not widen it.
- `src/OcuPilot/Port/ProviderPort.cls` — `Invoke` **:72** (stored row; `ValuesFor` **:220**),
  `InvokeDraft` **:115**, `Dispatch` **:147** (adapter from the catalog row **:153**, adapter dropped
  **:214**), `SecretClass()` **:291** (overridable seam).
- `src/OcuPilot/Kernel/State/Agent.cls` — no `ApiKey`; `CredType` **:59**, `EnvVarName` **:63**,
  `CredentialName` **:68**, `Enabled` **:94**, `ConnectionVerified` **:99**, `SecurityFields()`
  **:122**, `SnapshotSecurityFields` **:131**, `GuardedUpdate` **:181** (clears both flags on a
  security-field change), `GuardedOpenId` / `GuardedExistsId` on `State/Base`.
- `src/OcuPilot/Kernel/AgentRules.cls` — `#CREDTYPEENV` **:28**, `#CREDTYPECREDS` **:33** (its header
  already assigns the namespace condition to this story), `Normalize` **:53** (XOR), `Add` **:179**,
  `ViolationsJson` **:322**.
- `src/OcuPilot/Api/Definitions.cls` — `UrlMap` **:65-70** (`/agent/definitions/:id/default` is the
  sub-resource precedent), `Fields()` **:44**, `IsAdministrator` **:323**, `RenderForbidden` **:333**,
  `RenderNotFound` **:343**, `RenderViolations` **:385**, `BodyIsReadable` **:369**, `OpenDefinition`
  **:395**, `LogChange` **:571**, `FullProjection` **:490**.
- `src/OcuPilot/Test/AgentSchema.cls:42` `TestNoPropertyCanHoldACredentialValue` — **AC1's pin**
  (no `ApiKey` property, no property whose name denotes a secret).
- `src/OcuPilot/Test/ProviderSecret.cls` — AC6's canary proof; `#CANARY` **:28**, `DriveAndAssert`
  **:82**, `AssertErrorEntriesAreClean` **:212**. `src/OcuPilot/Test/SecretProbe.cls` — the
  `Environment` override.
- `src/OcuPilot/Test/ProviderSsl.cls` — `TestInstallRepairsADriftedConfiguration` **:107** (drifts
  `VerifyPeer` and `CAFile` only — the DW-335 hole), `AssertProperties` **:126** (already asserts
  `Type` 0 and `Enabled` 1, so it becomes load-bearing once the drift reaches them), `Modify` **:185**.
- `src/OcuPilot/Install/Installer.cls:2569` `EnsureSslConfiguration` — four repair arms
  (`VerifyPeer` **:2590**, `CAFile` **:2594**, `Type` **:2598**, `Enabled` **:2602**), the drift
  string **:2612**.

**Vendor surfaces, read in the export**

- `irislib/Ens/Config/Credentials.cls` — `%Persistent`, `SystemName` is the `IdKey`; `Password`
  **:19** is `%CSP.Util.Passwd`, written through `%SYS.Ensemble.SecondarySet` by `PasswordSet`
  **:40** and read by `PasswordGet` **:28**. `SetCredential` **:75** sets `Username` unconditionally,
  so an existing row is edited by `%OpenId` instead. **`GetValue` :128 is a trap** — it builds
  dynamic SQL and answers a `<N/A ...>` *string* on failure, which would be treated as a key.
- `irislib/%Library/EnsembleMgr.cls` — `IsEnsembleNamespace` **:79** reads
  `^|ns|oddCOM("Ens.StudioManager")` and its own `Catch` swallows a privilege failure;
  `IsHealthShareInstalled` **:57** is the vendor's own precedent for `##class` against a class that
  may be absent, inside a `Try`.
- `irislib/%SYSTEM/Util.cls` — `GetEnviron` **:86**. **There is no `SetEnviron`**, which is why the
  `env` rung has no write path.

**Probed on the live `ocupilot` instance, 2026-09-15 — reads only, nothing created**

| Namespace | `IsEnsembleNamespace` | `Ens.Config.Credentials` compiled | `%Library.EnsembleMgr` compiled |
|---|---|---|---|
| `HSCUSTOM` (install), `USER`, `HSLIB`, `HSSYS` | 1 | 1 (HSCUSTOM) | 1 |
| `%SYS`, `HSSYSLOCALTEMP` | 0 | 0 | 1 |

The two predicates agree on every namespace probed, and `%Library.EnsembleMgr` is present in the
non-Interoperability ones because it is IRISLIB, not ENSLIB.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Api/Error.cls` — add four codes with their producer in the doc comment, in the
   `AGENT.*` neighborhood: `AGENTCREDENTIALREQUIRED` = `AGENT.CREDENTIAL.REQUIRED`,
   `AGENTCREDENTIALENVUNWRITABLE` = `AGENT.CREDENTIAL.ENVUNWRITABLE`,
   `AGENTCREDENTIALRUNGUNAVAILABLE` = `AGENT.CREDENTIAL.RUNGUNAVAILABLE`, `AGENTKEYSHAPE` =
   `AGENT.KEY.SHAPE`. Each must satisfy `CODEPATTERN` **:279**.
2. `src/OcuPilot/Kernel/Secret/Ladder.cls` — replace the header's "environment rung only" paragraph
   with what ships. Add `Parameter CREDSCLASS = "Ens.Config.Credentials"`;
   `CredentialsRungAvailable() As %Boolean` = `##class(%Dictionary.CompiledClass).%ExistsId(..#CREDSCLASS)`,
   **overridable**; `Credential(pName) As %String` — `$ClassMethod(..#CREDSCLASS, "%ExistsId", pName)`
   then `%OpenId`, answering the row's `Password` through late-bound access and `""` on anything
   else, inside `Try`/`Catch`, using `Return` rather than an argumented `Quit` (ERROR #1043) so no
   named local ever holds the value; `Store(pCredentialName, pBody As %DynamicObject, pField) As
   %Status` — opens or creates the row, assigns `pBody.%Get(pField)` straight onto `Password`, saves,
   drops the reference. **On a vendor failure it answers an OcuPilot-written status naming the
   reference only and logs the vendor status's `$System.Status.GetErrorCodes` — never its text.**
   Widen `Resolve` with the `creds` arm: empty name or unavailable rung ⇒ `""`. The `env` arm
   consults neither the rung predicate nor a namespace.
3. `src/OcuPilot/Kernel/State/Agent.cls` — add `GuardedClearVerification(pId) As %Status`: open the
   row, snapshot its security fields, set `ConnectionVerified` and `Enabled` to 0, and call
   `GuardedUpdate` with that snapshot, so the timestamp and the default rebalance stay in one place.
   One home for both callers below. No Storage section.
4. `src/OcuPilot/Api/Definitions.cls` — add `<Route Url="/agent/definitions/:id/credential"
   Method="POST" Call="AgentDefinitionStoreCredential"/>` **beside `:id/default` and above every
   single-segment `:id` route** (`check_route_ordering`), a thin `Call=` wrapper, and
   `HandleStoreCredential(pId)`: administrator gate, 404 on an unknown id, then the four 422
   refusals in this order — `AGENT.CREDENTIAL.REQUIRED`, `AGENT.CREDENTIAL.ENVUNWRITABLE`,
   `AGENT.CREDENTIAL.RUNGUNAVAILABLE`, `AGENT.KEY.SHAPE` (the shape check is last because it needs a
   value and a reachable store) — then `Ladder.Store`, then `GuardedClearVerification`, then
   `LogChange("credential", pId, ...)` with **no value and no key-bearing field in the payload**, then
   `{"stored":true}`. The shape check instantiates the row's adapter, assigns `pBody.%Get("apiKey")`
   onto `..ApiKey`, sets `..KeyPrefix` from the catalog row, calls the argument-free
   `IsApiKeyShapeValid()`, and clears `..ApiKey` in a `Try`/`Catch` that runs on every exit —
   `Base.Invoke` **:128-143**'s discipline, copied, not re-invented.
5. `src/OcuPilot/Port/ProviderPort.cls` — in `Invoke` only, when the adapter's fault code is
   `PROVIDER.CREDENTIAL`, call `GuardedClearVerification(pDefinitionId)` and log one line naming the
   definition id and the reference. A failure to flag never changes the refusal the caller sees.
   `InvokeDraft` is untouched. **(DW-22.)**
6. `src/OcuPilot/Test/SecretProbe.cls` — add `SetRungAvailable(pState)` with three states, held in
   the existing `^||OcuPilotSecretProbe` node: `1`, `0`, and `raise` — the last making the overridden
   `CredentialsRungAvailable` throw, so "the env arm consults no rung predicate" is falsifiable
   rather than asserted. The shipped `Resolve` and the XOR selection above it stay unreplaced.
7. `src/OcuPilot/Test/Secret.cls` — **new.** Every ladder branch in the matrix: the env arm with the
   predicate off and with it raising; `creds` with an empty name; `creds` with the rung unavailable;
   the availability predicate against this namespace and against a class name nothing holds; and the
   real round trip — `Store` then `Resolve` answers the stored value — on a probe credential named
   `OcuPilotProbeCredential`, removed in `OnAfterOneTest` with an assertion that it is gone. The
   round-trip legs run only where `CredentialsRungAvailable()` is true and report how many legs ran,
   so an assertion over nothing is visible as such.
8. `src/OcuPilot/Test/AgentCredential.cls` — **new.** The over-the-wire leg for the new route
   (`check_handler_wire_tests` needs status, content type and body shape in the class that names the
   literal): each matrix row's status and `code`, the 200 body, and — the AC2 assertion — that
   neither the 200 body nor the subsequent `GET /agent/definitions/:id` carries any part of the
   stored value, and that the definition reads `enabled` 0 and `connectionVerified` 0 afterwards.
9. `src/OcuPilot/Test/ProviderPort.cls` — add the DW-22 pair: after `Invoke` against a stored,
   enabled definition whose credential does not resolve, the row reads both flags 0; after the same
   failure through `InvokeDraft`, no row changed.
10. `src/OcuPilot/Test/ProviderSecret.cls` — add a fifth leg driving the canary through the **`creds`**
    rung (stored by `Ladder.Store`, resolved by the shipped ladder, removed afterwards), so AC6's
    proof covers the new rung and not only the environment one.
11. `src/OcuPilot/Test/ProviderSsl.cls` — extend `TestInstallRepairsADriftedConfiguration` to drift
    `Enabled` to 0 **and** `Type` to 1 alongside `VerifyPeer` and `CAFile`, assert the drift itself
    took (so a vendor refusal is loud rather than silent), and assert the repair report names all
    four fields. `AssertProperties` **:126** then pins both arms. **(DW-335, both legs.)**
12. `src/OcuPilot/Test/ProviderConsumer.cls` — add AC6's leg, using only `ProviderPort`'s public
    class methods: store a probe key, invoke, observe the call served with it; delete the credential
    row, invoke again, observe `$$$OK` plus a `PROVIDER.CREDENTIAL` envelope and the definition left
    disabled. Inspects no internal state of the provider or secret layers.

**Acceptance Criteria:**

- **AC1 (already shipped by Story 3.1; carried as a regression leg)** — Given a definition, when its
  stored schema is read from the class dictionary, then it holds the credential *type* and the
  variable or credential *name* and no property that can hold a value — pinned by
  `OcuPilot.Test.AgentSchema.TestNoPropertyCanHoldACredentialValue`. No new code.
- **AC2** — Given an administrator posting a key to `/agent/definitions/:id/credential`, when the
  store succeeds, then the value is in the credential store, the response and every definition route
  carry no part of it, and the definition's `Enabled` and `ConnectionVerified` are cleared, so Test
  connection must pass again — the rule Story 3.1 already applies to a credential *reference* change.
- **AC3** — Given a definition's credential reference, when the ladder resolves it at call time, then
  the `env` rung answers in any namespace and consults no rung predicate; the `creds` rung answers
  only where `Ens.Config.Credentials` is reachable in the calling namespace and answers `""`
  otherwise; and no path returns a value, or any text derived from one, in a `%Status` or an error.
- **AC4 (server half)** — Given a key of the wrong shape for the definition's provider, when it is
  posted, then it is refused with `AGENT.KEY.SHAPE` on `apiKey` **before anything is written and
  before any provider call**, through the argument-free `IsApiKeyShapeValid()` seam, with no local
  holding the value. The inline `aria-invalid` / `aria-describedby` rendering is Story 3.5's.
- **AC5 (server half)** — Given a stored key, when any OcuPilot route answers, then no response ever
  carries it, which is what makes a never-pre-filled field possible. The reveal toggle, the published
  caption's `strings.ts` key and untrimmed pastes are Story 3.5's.
- **AC6 (Integration)** — Given a consumer holding only `ProviderPort`'s public contract, when it
  invokes a definition whose key was stored through this story's endpoint, then the call is served
  with the stored credential; and when the reference is then removed, the next `Invoke` yields a
  turn error naming the reference and leaves the definition disabled. **Consumed-by:** Story 3.4
  (Test connection resolves through this ladder and clears the flag this story sets), Story 3.5 (the
  form posts to this endpoint and renders AC4/AC5), Epic 4's turn. **Consumes:** Story 3.2
  (`Kernel/Secret/Ladder`, `Kernel/Provider/Base`, `Port/ProviderPort`, `Kernel/Provider/Catalog`),
  Story 3.1 (`Kernel/State/Agent`, `Kernel/AgentRules`, `Api/Definitions`), Story 1.1
  (`Api/Error`, `Kernel/Fault`), Story 1.4 (`Install/Installer`, `scripts/ci-throwaway.sh`).

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-42 (the credential ladder is a fixed contract that
never returns a value into a status or an error), AD-35 and AD-48 (OcuPilot renders the logs it
writes, and `^%ETN` captures every local at every stack level), AD-46, AD-9 (the flag write goes
through `State/Agent`'s guarded methods from a non-escalated frame; nothing is spawned from or
re-enters one), AD-29 and AD-21 (the new route inherits `Api/Definitions`' administrator gate and the
router's anonymous refusal), AD-12/AD-39 (one envelope; the vendor's status never reaches either
consumer), AD-15 (no audit call here), AD-30 (no second enforcement point), AD-37 (the credential
reference stays weak — a name, never a foreign key, rendering as unresolved), AD-32 (DW-335's repair
arms are AD-32's properties), AD-7 as amended for this story (see below).

**AC4 / AC5 split, and why.** Story 3.5 is "The Definition form" and `epics.md:2418` already makes
the `form-page` contract — inline validation on blur, `aria-invalid` plus `aria-describedby`, the
focused first invalid field — that story's own AC. No client file for this screen exists yet, and
Story 3.1 recorded the same split for its validation copy: server rules land on the field they name,
and 3.5 adds the `strings.ts` keys with the component. The caption AC5 names is already published in
`EXPERIENCE.md:298`, so nothing is being invented later. This story therefore ships the halves that
are server-observable — the per-provider shape refusal keyed to `apiKey`, and the guarantee that no
route returns a stored value — and the rendering halves are recorded in frontmatter `deferred:` for
the lead to route to Story 3.5, which is the sanctioned path (Rule 15(a): build-auto never writes the
ledger).

**Why the `env` rung has no write path.** `%SYSTEM.Util` publishes `GetEnviron` and no setter, so
IRIS cannot set an environment variable for the processes that would read it. AC2's "the chosen
credential store" is therefore writable only on the `creds` rung; the `env` rung's store is the
operating system and the operator owns it. The endpoint says so with a named code rather than
failing obscurely.

**Why the reachability check is the class and not `IsEnsembleNamespace`.** The predicate the rung
actually needs is "can this namespace reach `Ens.Config.Credentials`", and
`%Dictionary.CompiledClass.%ExistsId` asks exactly that while naming no class outside `%Dictionary`,
which every IRIS edition carries. `%Library.EnsembleMgr.IsEnsembleNamespace` is the semantic answer
and agreed with it on all six namespaces probed above; it is recorded, not called, so there is one
predicate to keep correct. Both read `^oddCOM`, so neither is more privilege-tolerant than the other.

**Why `$ClassMethod` and not `##class`.** The tree is compiled whole on every container start
(AD-17, AD-38) and, in CI's `images` leg, on `intersystems/iris-community:2026.2` in that edition's
own namespace. Dynamic dispatch removes the question of what a literal `##class` against an absent
class does at compile time entirely, and it is the same move `ProviderPort.Dispatch` **:154** already
makes for the adapter class. (The vendor's own `EnsembleMgr.IsHealthShareInstalled` **:57** uses a
literal inside a `Try`, which suggests it compiles — **inference**; this story does not rely on it.)

**The residual AD-48 window, stated rather than claimed closed.** `Ens.Config.Credentials.PasswordSet`
and `PasswordGet` bind the value to a local in the **vendor's** frame for the duration of one call,
and OcuPilot cannot instrument that frame. Both are wrapped in the vendor's own `Try`/`Catch`, so an
`^%ETN` entry would need an error that escapes them (**inference** — no probe here forced one). Every
frame OcuPilot authors is clean, and Task 10 extends AC6's forced-entry proof to the `creds` rung so
the claim is measured on the path this story adds.

**DW-22, and what it does and does not change.** The named reason already ships
(`PROVIDER.CREDENTIAL` carrying the credential *type and name*, never a value, `Base.cls:410`). What
is added is the flag, and it is narrowed deliberately to the unresolved case the entry names — not to
`PROVIDER.KEYSHAPE`, which is a wrong key rather than a missing one. Flagging is a write to
OcuPilot's own protected state, not an instance mutation, which AD-7 now says explicitly: the lead
amended it at this plan's gate so the scope is in the contract rather than inferred per story.
A non-administrator can therefore cause a definition to be disabled by running a turn, which is
acceptable because an unresolvable credential means the definition serves nobody.

**DW-335, both legs.** `EnsureSslConfiguration` repairs four properties and the adjacent test drifts
two, so deleting the `Enabled` arm or the `Type` arm leaves every assertion green. The fix is in the
test, not the installer: drift all four, and assert the repair report names all four. `Type` 1 with
no certificate is assumed acceptable to `Security.SSLConfigs.Modify` — the vendor's
`%OnValidateObject` body is stripped from the export — and the drift's own
`$$$AssertStatusOK` is what makes a wrong assumption loud in the implement pass rather than silent.

## Verification

Every instance-touching check runs on the throwaway `ocupilot-ci` (`bash scripts/ci-throwaway.sh`),
never on the live container. Nothing here opens a socket to a provider.

**Commands:**
- `uv run scripts/check-objectscript.py` — expected: clean.
- `uv run scripts/test_check_objectscript.py` — expected: green (no new rule).
- Load and compile the **whole tree** through `mcp__iris-dev__iris_doc_load` with
  `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`, `path:
  "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` — expected: no error text.
- `sh scripts/ci-image-compile.sh --image intersystems/iris-community:2026.2` — expected: the tree
  compiles where Interoperability may be absent. This is the gate the dynamic dispatch exists for.
- `bash scripts/lint-docs.sh` — expected: clean.
- From `ui/`: `npm run build` and `npm test` — expected: unchanged and green; this story adds no
  client file and no `strings.ts` key.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <one class>` — **one class per
  invocation, one invocation per message**, each landed in `%UnitTest_Result` before the next, in
  this order: `OcuPilot.Test.Secret`, `OcuPilot.Test.AgentCredential`, `OcuPilot.Test.ProviderPort`,
  `OcuPilot.Test.ProviderConsumer`, `OcuPilot.Test.ProviderSsl`, `OcuPilot.Test.ProviderSecret`, then
  the regression trio `OcuPilot.Test.AgentSchema`, `OcuPilot.Test.AgentWire`,
  `OcuPilot.Test.Provider`. Confirm totals with the `%UnitTest_Result` SQL probe in
  `.claude/rules/objectscript-testing.md`, not the runner envelope.

**Recorded mutations (Rule 19) — one per AC. Apply to the throwaway's own `src/`, recompile the
whole tree (a subclass keeps its own copy of an inherited method), observe red, revert, and confirm
`git status --short` and `git diff --stat` unchanged.**

- **AC1** — `mutation:` add `Property ApiKey As %String;` to `Kernel/State/Agent.cls` →
  `Test/AgentSchema.TestNoPropertyCanHoldACredentialValue` goes red naming `ApiKey` (the mutation the
  shipped class header **:40** already records).
- **AC2** — `mutation:` drop the `GuardedClearVerification` call from `HandleStoreCredential` →
  `Test/AgentCredential`'s two flag assertions go red (run 21). Second `mutation:` echo the stored
  value into the 200 body → the "carries exactly that one key" and "no response carries any part of
  it" assertions go red (run 22).
- **AC3** — `mutation:` gate `Ladder.Resolve`'s **env** arm on `CredentialsRungAvailable()` →
  `Test/Secret.TestTheEnvironmentArmConsultsNoRungPredicate` red on both the predicate-off and the
  predicate-raises leg (run 23), which is the only way "works in any namespace" is falsifiable from
  one namespace. Second `mutation:` make `CredentialsRungAvailable` answer 1 unconditionally →
  `Test/Secret.TestTheRungPredicateReadsTheClassItNames` red on the absent-class predicate assertion
  (run 24). It does **not** surface as `<CLASS DOES NOT EXIST>`: `Credential` and `Store` catch that
  and answer `""` and a named status, which is the fail-closed behavior those legs assert.
- **AC4** — `mutation:` move the shape check after `Ladder.Store` → `Test/AgentCredential`'s
  "nothing is written on a badly shaped key" assertion goes red, because the credential row exists
  afterwards (run 25).
- **AC5** — covered by AC2's second mutation plus AC1's; the rendering half has no server pin and is
  Story 3.5's, as Design Notes record.
- **AC6** — `mutation:` bind the resolved key to a local in `Kernel/Provider/Base.Invoke` on the
  `creds` path alone → `Test/ProviderSecret`'s variable-table assertion goes red on the new leg's
  forced entries and on no other (run 29), so the leg is load-bearing rather than a fifth repetition.
  A local inside `Ladder.Credential` is **not** a falsifier — that frame has unwound before the entry
  is forced and `^%ETN` captures only live stack levels (measured: the mutation ran green, run 28).
- **DW-22** — `mutation:` delete the `FlagUnresolvedCredential` call from `ProviderPort.Invoke` →
  `Test/ProviderPort.TestAnUnresolvedCredentialDisablesTheStoredDefinition` red on both flag
  assertions (run 26). `TestTheDraftEntryFlagsNothing` is the scope guard for that mutation and has
  no single-line falsifier of its own; its header says so.
- **DW-335** — `mutation:` delete `EnsureSslConfiguration`'s `Enabled` arm →
  `Test/ProviderSsl.TestInstallRepairsADriftedConfiguration` red on `AssertProperties`' enabled
  assertion **and** on the report's `Enabled` leg (run 27). Second `mutation:` send that step's
  report array back to a local → the three report assertions go red while every property assertion
  stays green (observed as the defect itself, run 5 red, run 6 green after the fix). The `Type` arm
  has no drift leg: the vendor refuses a server-typed configuration carrying no certificate
  (`ERROR #982`), pinned by `TestAServerTypedConfigurationCannotBeDriftedInto`.

**Manual checks:**
- `docker compose ps` against the live container only, to confirm it was never recreated.
- After the run, confirm the live instance holds no `OcuPilotProbeCredential` and no agent
  definitions — read through the IRIS MCP tools with `server: "ocupilot-iris"`, which create nothing.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** The `creds` rung behind a class-reachability predicate, reached only through
`$ClassMethod` and late-bound property access; one write-only endpoint,
`POST /agent/definitions/:id/credential`, answering `{"stored":true}`; DW-22's flag on a reference
that no longer resolves at call time; DW-335's missing drift legs. No OcuPilot frame binds key
material to a local -- the value moves `%DynamicObject` member onto `Base.ApiKey` and member onto
the credential row's `Password`, and `IsApiKeyShapeValid()` stayed argument-free.

**Three places the spec was wrong about the shipped code, corrected here.**

- `EnsureSslConfiguration` handed `AssertSslConfiguration` an **undefined local** instead of its
  caller's report array, so neither its create report nor its repair report ever reached the log:
  the step repaired correctly and said nothing. Task 11's "assert the repair report names the
  drifted fields" is what found it; fixed at both call sites, which were the only two in the class.
  DW-335 is two defects, not one.
- DW-335's `Type` arm is **not reachable by drift**. The vendor refuses a server-typed configuration
  carrying no certificate (`ERROR #982`, measured on this build), so the arm is pinned as unreachable
  by `TestAServerTypedConfigurationCannotBeDriftedInto` rather than left as a claim; the other three
  arms are drifted, and the drift itself is asserted before the repair runs.
- AC6's recorded mutation was unfalsifiable: a local inside `Ladder.Credential` is gone by the time
  the stub forces the `^ERRORS` entry, because `^%ETN` captures only live stack levels. It ran green.
  Replaced with one that leaks on the `creds` path alone inside `Base.Invoke`, which reddens the new
  leg and no other.

**Matrix audit.** Two rows had no covering test. "Store fails in the vendor" now runs against a real
vendor refusal -- the credential entry's `SystemName` holds 50 characters and a definition's
`credentialName` holds 128, so a reference between the two is one an operator can save and the store
will not accept -- pinned in `Test/Secret` for the status and the logged codes, and over the wire in
`Test/AgentCredential` for the 500. The 403 row is `Test/AgentWireSecurity`'s sixth leg, now run.
`Test/ProviderPort.TestTheDraftEntryFlagsNothing` is the one assertion with no single-line falsifier;
its header says so and names the pair it guards, rather than carrying a mutation that cannot redden.

**Verified.** `check-objectscript` clean (255 files, 17 rules); `test_check_objectscript` 85 green;
`lint-docs` clean; whole-tree compile on `ocupilot-iris`; `ci-image-compile` green on
`intersystems/iris-community:2026.2`, the gate the dynamic dispatch exists for; `ui` build plus 720
and 290 client tests green. On the throwaway `ocupilot-ci`, one class per call: **167 methods, 167
passed, 0 failed** across 15 classes, read from `%UnitTest_Result` rather than the runner envelope.
Nine mutations were applied to the throwaway's own `src/`, observed red and reverted; the
repository's working tree was never mutated. The live `ocupilot` container was never recreated, and
it holds no agent definition and no OcuPilot credential entry.
