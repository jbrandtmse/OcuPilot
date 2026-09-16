---
title: 'Story 3.8: Every configuration change is resource-gated and audited'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: 'd7c1b4fa797ad57c88b793f9c0ecccd8deac89e4'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      `check_destructive_test_guard` does not see `Security.Events.Create` / `Delete`, so a test
      that registers or deletes an audit event type on whatever instance it is pointed at passes
      the gate unarmed.
    evidence: |-
      `DESTRUCTIVE_TEST_RE` (scripts/check-objectscript.py:1100) lists `Security.Users`,
      `Security.Roles.Create` and two log/account helpers only. Widening it reddens
      `Test/Installer.cls:462`, which deletes the probe registration today with no
      `ARMINGVARIABLE` -- arming that class is a separate call, because it is the one class whose
      `OnBeforeOneTest` primes production's `Install("")`, and refusing it unarmed changes where
      the whole install suite can run.
    location: >-
      scripts/check-objectscript.py DESTRUCTIVE_TEST_RE
    severity: low
  - summary: >-
      A Test connection against values the row does not hold that FAULTS records nothing, so a
      provider call that carried this definition's credential to an unaudited address leaves no
      audit row when it fails.
    evidence: |-
      `ConnectionOutcome` returns at `If $IsObject(pFault) Quit` before either `LogChange`, and
      that return predates this story -- DW-358 was about the `If tTestedAsStored` guard after it.
      Settled by driving `OcuPilot.Test.AgentConnection.Outcome` with an edited endpoint and a
      queued provider fault, then reading `%SYS.Audit` for a `test` row against that id.
    location: >-
      src/OcuPilot/Api/Definitions.cls ConnectionOutcome
    severity: medium
  - summary: >-
      The anchored credential-name backstop cannot mask a secret word that is not final in a key
      name, so a future key such as `passwordHash` or `secretRef` would reach a log line and an
      audit row unmasked.
    evidence: |-
      `IsCredentialName` now matches a suffix or an exact name. A key population sweep over this
      tree found only count- and name-shaped losses (`maxTokens`, `canonicalMaxTokens`,
      `secretFields`, `defaultCredentialName`), none of which carries a value, so nothing is
      unmasked today. Reopen when a payload key is added whose secret word is not its ending.
    location: >-
      src/OcuPilot/Kernel/Audit/Log.cls CREDENTIALSUFFIXES
    severity: low
  - summary: >-
      Nothing compares `Kernel/Audit/Log.CREDENTIALSUFFIXES` with `ui/tools/field-lists.mjs`'s
      `CREDENTIAL_RE`, which its own doc says it mirrors.
    evidence: |-
      `Test/AgentSchema.TestTheLogRedactorStillCoversTheNamesThisCheckNarrows` checks four bare
      words. A real comparison is a cross-language test with no home in either suite today.
    location: >-
      src/OcuPilot/Kernel/Audit/Log.cls, ui/tools/field-lists.mjs
    severity: low
  - summary: >-
      `check_handler_wire_tests` still keys a route by substring, so a route whose declared path is
      a leading prefix of another's is covered by the longer one's name.
    evidence: |-
      `covered = [name for name, source in sources.items() if key in source ...]`. With `:`
      admitted, `/agent/definitions/:id` is satisfied by a class naming
      `/agent/definitions/:id/credential`. This is the same rule's REACH, which the Design Notes
      hold with DW-393/394 pending Epic 4's first real caller; the precision fix this story made is
      the key, not the match.
    location: >-
      scripts/check-objectscript.py check_handler_wire_tests
    severity: medium
  - summary: >-
      DW-363's conservative fallback cannot be reached with the shipped declarations, so no test
      asserts that an incomplete wire translation refuses a verification and audits as security.
    evidence: |-
      All six of `Kernel/State/Agent.SecurityFields()`'s properties carry a `Fields()` entry, so
      `pComplete` is always 1. Reaching the branch needs a probe subclass of `Api/Definitions`
      overriding `Fields()`; the branch itself was tightened from a length test to a per-property
      one in this story's review pass.
    location: >-
      src/OcuPilot/Api/Definitions.cls SecurityFieldNames
    severity: low
  - summary: >-
      `Test/AuditRecord` runs `Install("")` with no arming variable, so a runner pointed at an
      instance someone cares about would register OcuPilot's audit event types on it.
    evidence: |-
      Nine test classes already in the tree do the same (`Installer`, `WebApp`, `Static`,
      `Manifest`, `Provenance`, `GrantReadBack`, `UninstallGuard`, `InstallNamespaceSource`,
      `GatewayGapIpmPath`), so this is the tree's standing shape rather than a new hole; it shares
      a root cause with the `DESTRUCTIVE_TEST_RE` entry above.
    location: >-
      src/OcuPilot/Test/AuditRecord.cls OnBeforeOneTest
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 3 shipped seven configuration write paths that compute a change record and write
it to the console log, and nothing else. No `$System.Security.Audit()` call exists outside the
installer's role-grant marker, only one audit triple is registered, and the record itself is wrong
in three ways: it masks `maxTokens`, it drops every field a create made at its default, and a Test
connection against unsaved values records nothing at all.

**Approach:** One emitter, `Kernel/Audit/Event.cls`, owning the triple roster the installer
registers and the `EventData` shape every configuration change lands as; both existing `LogChange`
seams call it; the change record is corrected at its three faults; and the gate that was asserted
screen by screen becomes a sweep over the router's own `UrlMap` and over every `Kernel/State/`
class, so coverage is a population query rather than a list somebody maintains.

## Boundaries & Constraints

**Always:**

- An emitted triple is one the installer registers. The roster is declared once and read by both,
  and a test asserts the emitter can name no triple registration does not carry (AD-15).
- Audit emission never throws and never fails the write it records (AD-15, Conventions: Logging).
- Every entity reference in a row carries `(entity type, scope, id)` — types from
  `Kernel/EntityType`'s closed enum, scope `Kernel/Scope.#SCOPEINSTANCE` (AD-13, AD-14).
- Privilege is checked in the calling process at the moment of the call, against
  `OcuPilotAdmin:USE`, and a denial names the pair that failed (AD-8).
- Secrets never reach the row: the change record passes through the same redactor as the log line
  (AD-35, Conventions: Secrets).
- `%SYS` is entered by explicit save and restore, with the restore the first line of every `Catch`
  (AD-16).
- **Every verification for this story runs on a throwaway** (`sh scripts/ci-throwaway.sh up`). The
  live `ocupilot` container is never asked to register an event type, and nothing in this story
  runs `Install("")` against it.

**Never:**

- No new audit *Source* and no per-slice event name: two names under the one registered Source.
- No `ui/` change, no `strings.ts` key, no `EXPERIENCE.md` row, no new `Api/Error.cls` code — this
  story adds no user-facing literal (see Design Notes).
- No bump of `Installer.#SCHEMAVERSION`: raising it makes the live instance's API gate answer
  `upgraderequired` until the owner restarts it (AD-38).
- No application `Resource` on any OcuPilot web application — the installer refuses one (AD-21).
- No agent marker, no ledger row, no turn, no proposal: AD-15's confirmed-write marker is Epic 5's
  and uses this same emitter.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Definition created with `{name, provider}` only | no prior row | one `ConfigChange` row; `changes` carries the five fields created at their defaults with `old` empty | — |
| Endpoint edited | `PUT /agent/definitions/:id` | one `SecurityChange` row; `changes.endpointUrl` carries old endpoint and new endpoint | — |
| `maxTokens` edited | `PUT` with a new bound | `changes.maxTokens` carries both values in clear | — |
| Credential reference edited | `credentialName` changes | `changes.credentialName` reads `[redacted]` on both halves | — |
| Test connection against stored values | body empty | one `ConfigChange` row for the verification flag | — |
| Test connection against an edited endpoint | body carries a different `endpointUrl` | one `SecurityChange` row naming old and new endpoint, `testedAsStored` false | — |
| Kill switch turned on | `PUT /agent/switches` | one `SecurityChange` row, target `agent-switch`/`instance`/`instance` | — |
| Unregistered triple | registration deleted | `$System.Security.Audit` returns an error status, **no row**, the failure is logged, the write still succeeds | AD-15 |
| Non-administrator on any gated route | principal holds `%Admin_Operate` only | 403, `AUTH.NOPRIVILEGE`, `detail.failedPair` `OcuPilotAdmin:USE`, nothing written | AD-8 |
| Principal holding no `%Admin_*` at all | any declared route | 403, `AUTH.NOADMIN`, the FR-3 sentence | AD-21 |
| Same principal via SQL or a global | any `Kernel/State/` table or global | `<PROTECT>` / `%SQLCODE < 0` | AD-9 |

</intent-contract>

## Code Map

Server — under `src/OcuPilot/`:

- `Kernel/Audit/Log.cls:55` `Parameter CREDENTIALNAMES` and `:161` `IsCredentialName` — substring
  match. **Verified live on `ocupilot-iris`:** `IsCredentialName("maxTokens")` = 1,
  `("credentialName")` = 1, `("envVarName")` = 0. `Redact` (`:109`) masks by key at every depth, so
  the whole `{old,new}` entry disappears. **DW-329.**
- `ui/tools/field-lists.mjs:59` `CREDENTIAL_RE = /(password|passwd|pwd|secret|secret64|apikey|privatekey|token)$|^key$/i`
  — the build-time anchoring to mirror (suffix, or the exact name `key`). Read-only here.
- `Api/Definitions.cls` — `ChangeSet` (`:1037`), `LogChange` (`:1065`), `IsSecurityChange` (`:1083`),
  `LogInfo` (`:1107`, the seam), `SecurityFieldNames` (`:90`), `MatchesStoredSecurityFields` (`:686`),
  `IsAdministrator` (`:816`), `RenderForbidden` (`:826`). `HandleCreate:274` builds `tDefaults` from a
  `%New()` row — **DW-331**. `ConnectionOutcome:641` calls `LogChange` only inside
  `If tTestedAsStored` and `LogChange:1075` special-cases only `CREDENTIALVERB` — **DW-358**.
- `Kernel/State/Agent.cls:127` `SecurityFields()` — six property names, all six wire-mapped today
  (verified live: both lists length 6). `SecurityFieldNames` silently drops an unmapped one —
  **DW-363**.
- `Api/Switches.cls:398` `LogChange` (verbs `switches`, `hold`, `release`), `:427` `LogInfo` — the
  second seam; `:362` `IsAdministrator` and `:370` `RenderForbidden` both delegate to `Definitions`.
  `HandleRestraint` (`:226`) is ungated **by design**.
- `Api/Router.cls:64` `XData UrlMap` (23 routes), `:44` `Parameter ADMINRESOURCES` (13 names),
  `OnPreDispatch:402` — anonymous reject (`:433`), `%Admin_*` floor (`:440`, `AUTH.NOADMIN`, the FR-3
  sentence), namespace gate (`:446`). The floor is on the dispatcher, so every route inherits it.
- `Install/Installer.cls:2652` `EnsureAuditEvent` → `Security.Events.Create` at `:2671`, guarded by
  `Exists` at `:2659`, repairs `Enabled` at `:2662`; `Names():159-161` resolves the triple from
  `Kernel/State/Base.cls:80,82,84` (`OcuPilot` / `Security` / `RoleGranted`, probe suffix
  `RoleGrantedProbe`). `EnsureGrant:2746` calls `AddRoles` (`:2774`) then `$System.Security.Audit`
  (`:2781`) with **no already-held branch** — **DW-44**. `AssertApplications:2477-2518` asserts
  `MatchRoles` equals the roster's value (`:2496`) and `Resource` is `""` (`:2500`).
- `Install/Roster.cls:105-152` — three applications; the `api` entry declares `matchRole: ""` and
  `"Resource": ""`. **Verified live:** `Security.Applications` has exactly one role-bearing
  property, `MatchRoles`; application roles are its empty-match entries. There is no second `Roles`
  property for AC4 to mean.
- `Install/Smoke.cls:611` `CheckAuditEvent` (registration of the one triple); `:652`
  `CheckAgentSwitches` — the precedent for `skipped` where a long-lived instance cannot answer the
  fresh-install question.
- `Test/State.cls` — Story 1.3's denial suite: principal `OcuPilotDenialProbe`
  (`%DB_<ns>:RW` + `%Admin_Operate`), but scoped to **one** global (`^OcuPilotKernelStateProbe`) and
  **one** table (`OcuPilot_Kernel_State.Stamp`). It does not touch `Agent`, `Switch` or `Hold`.
- `Test/AgentWireSecurity.cls:214,260,283` — the real-principal 403 sweep over 12 of the 13 agent
  routes; `:167` pins `GET /agent/definitions` at 200. `Test/Wire.cls:333` + `#NOADMINUSER` — the
  no-`%Admin_*` principal. `Test/Installer.cls:403,454` — the audit round trip, and the DW-85 rule:
  read `%SYS.Audit`'s master map with `%NOINDEX`, bounded by `UTCTimeStamp`, because the Event
  indexes lag ~60 s. `Test/DefinitionsProbe.cls` / `Test/LogProbe.cls` — the capture seams.
- `Test/ScreenReadWire.cls` names `/screens/:screen/read` only in comments; `Screen/Descriptor/AgentDefinitionList.cls:56`
  declares `OcuPilotAdmin:USE` and `Api/ScreenRead.cls:56-62` refuses — **untested over the wire.**
- `scripts/check-objectscript.py:1246` `LITERAL_ROUTE_RE = r"^/[A-Za-z0-9][A-Za-z0-9._/-]*$"` and
  `:1293-1304` `check_handler_wire_tests` — no colon, so all 8 `:param` routes key on
  `OcuPilot.Api.Router`, which `Test/AgentWire.cls:56` already names in code. **DW-364, confirmed by
  running the real function with the class patched: 0 problems today, 1 with the colon admitted, and
  that one is `/screens/:screen/read`.** `CHECKS` at `:1551`; harness `FixtureTreeCase` at
  `scripts/test_check_objectscript.py:43`, shipped-tree guard at `:1274`.
- `scripts/ci-throwaway.sh:133-149` — the one home of every `OCUPILOT_ALLOW_*` arming variable.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Audit/Event.cls` — **new.** `Names()` returns the triple roster
  (`ConfigChange`, `SecurityChange`, and the installer's existing `RoleGranted`) with the profile
  suffix `Installer.Names()` applies; `Record(pVerb, pType, pId, pChanges, pSecurityChange)` builds
  `{actor, target:{type,scope,id}, verb, securityChange, changes}`, passes it through
  `Kernel.Audit.Log.Redact`, and calls `$System.Security.Audit` **from the install namespace, with no
  `%SYS` switch** — the switch needs `%DB_IRISSYS` READ, which a least-privilege OcuPilot
  administrator does not hold, and AD-15 swallows the resulting `<PROTECT>` (corrected at code
  review; measured both ways, pinned by `Test/State`). Never throws; an error status is logged
  through `Kernel/Audit/Log` and swallowed.
- `src/OcuPilot/Install/Installer.cls` — `EnsureAuditEvent` becomes `EnsureAuditEvents`, looping the
  roster (guard-then-act and drift repair unchanged); `EnsureGrant` gains an already-held branch
  before `AddRoles`, emitting the marker and stamping `granted` only on a real grant, and stamping
  `alreadyheld` otherwise (**DW-44**); `AssertApplications` additionally re-reads `AutheEnabled` and
  `DispatchClass` from the instance, and its `MatchRoles` message states that the one property
  carries both application and matching roles.
- `src/OcuPilot/Install/Installer.cls` — new assertion: no application on the instance outside the
  roster's three carries an OcuPilot matching role, and OcuPilot's administrative role is an
  application role of nothing (a population query over `Security.Applications`, AD-10).
- `src/OcuPilot/Kernel/Audit/Log.cls` — `IsCredentialName` matches a **suffix** from
  `CREDENTIALSUFFIXES` or an **exact** name from `CREDENTIALEXACTNAMES` (`key`, `credentialname`),
  mirroring `field-lists.mjs`'s anchoring (**DW-329**). The existing 15-name positive corpus and the
  `credentialName` assertion in `Test/AgentSchema.cls:72` must stay green; `maxTokens` must not match.
- `src/OcuPilot/Api/Definitions.cls` — `HandleCreate` diffs against **nothing**, not against a
  `%New()` row (**DW-331**); `SecurityFieldNames` gains an `Output pComplete` length check against
  `Agent.SecurityFields()`, and `MatchesStoredSecurityFields` answers 0 / `IsSecurityChange` answers 1
  when it is incomplete (**DW-363**); `ConnectionOutcome` records the test verb **unconditionally**,
  and a test against values differing from the stored ones on any security field is classified a
  security change (**DW-358**); `LogChange` calls `Kernel.Audit.Event.Record` beside `LogInfo`.
- `src/OcuPilot/Api/Switches.cls` — `LogChange` calls `Kernel.Audit.Event.Record` with entity type
  `agent-switch`; `securityChange` stops being the constant 1 and is computed per verb.
- `src/OcuPilot/Install/Smoke.cls` — `CheckAuditEvent` sweeps the roster: `pass` when all are
  registered, `fail` when the baseline triple is absent, `skipped` naming the missing later ones on
  an instance whose last install predates them (the `CheckAgentSwitches` precedent).
- `scripts/check-objectscript.py` — admit `:` in `LITERAL_ROUTE_RE` so a `:param` route keys on its
  own declared path (**DW-364**); `scripts/test_check_objectscript.py` gains the per-route-key test.
- `src/OcuPilot/Test/ScreenReadWire.cls` — name `/screens/:screen/read` on a code line, which is what
  the corrected key requires.
- `src/OcuPilot/Test/ConfigGate.cls` — **new**, armed `OCUPILOT_ALLOW_PRINCIPALS`. The two sweeps:
  every route in the shipped `UrlMap`, and every `OcuPilotAdmin`-gated descriptor that declares a read.
- `src/OcuPilot/Test/AuditEvent.cls` — **new**, armed a new `OCUPILOT_ALLOW_AUDIT_EVENTS`, added to
  `scripts/ci-throwaway.sh` in the established comment style. The round trip and its negative leg.
- `src/OcuPilot/Test/AuditRecord.cls` — **new.** The change record's three corrections, through the
  real handlers and the capture seam.
- `src/OcuPilot/Test/State.cls` — extend the denial sweep to **every** class extending
  `Kernel.State.Base`, derived from `%Dictionary.CompiledClass`, table and global per class.
- `src/OcuPilot/Test/Installer.cls` — follow `EnsureGrant`'s new outcome vocabulary.
- Tests run **one `iris_execute_tests` call per message**, against the throwaway, never re-submitted
  on a client-side timeout.

**Acceptance Criteria:**

- **AC1** — Given the shipped `UrlMap`, when a principal holding `%Admin_Operate` but not
  `OcuPilotAdmin` calls every route it declares, then each is refused 403 `AUTH.NOPRIVILEGE` with
  `detail.failedPair` `OcuPilotAdmin:USE`, except the two routes named in a closed exception list —
  `GET /agent/definitions` and `GET /agent/restraint` — each carrying its reason; and the test fails
  if the exception list names a route that does not exist, or if the route count is zero.
- **AC2** — Given any accepted configuration write, when it completes, then exactly one audit row is
  written naming the actor, the target triple, the verb and every changed field with its old and new
  value; a definition's endpoint change appears as `changes.endpointUrl` carrying old endpoint and
  new endpoint; a credential reference appears redacted on both halves; `maxTokens` appears in clear;
  a create carries the fields it created at their defaults; and a Test connection against values that
  are not the stored ones is recorded, as a security change.
- **AC3** — Given the roster, when the installer has run, then every triple in it is registered, the
  emitter can name no triple the installer does not register, and an emission through each one is
  read back from `%SYS.Audit`'s master map as exactly one row with the expected `EventData` — and,
  with that registration deleted, the same emission returns an error status and produces no row.
- **AC4** — Given the API web application, when the installer asserts it, then it carries an empty
  `MatchRoles` — the one property IRIS stores both application and matching roles in — and no
  application resource; no application outside the roster carries an OcuPilot role; and a principal
  holding no `%Admin_*` resource is refused with the FR-3 sentence and `AUTH.NOADMIN` on **every**
  declared route, so a route added later inherits the refusal rather than declaring its own.
- **AC5** — Given a principal holding `%DB_<install-namespace>:RW` and `%Admin_Operate` but not
  `OcuPilotAdmin`, when it reaches OcuPilot's state through SQL, through a global, and through the
  API, then every attempt is refused: the SQL and global halves swept over every class extending
  `Kernel/State/Base` rather than over one, and the API half covering the configuration routes and
  `GET /screens/agent.definitions/read`.
- **AC6** *(integration, Rule 1)* — Given `Api/Switches.HandleUpdate` and
  `Api/Definitions.HandleUpdate` as the emitter's first consumers, when each is driven over HTTP,
  then a matching `%SYS.Audit` row is found by SQL — asserted from the consumer's side, never from
  the emitter's internal state.
- **AC7** — Given a second `Install()` on an instance where the administrative role is already held,
  when it completes, then no `RoleGranted` row is written and the stamp records `alreadyheld`; and
  on the run that actually grants it, exactly one row is written.

## Design Notes

**Consumes:** Story 3.1's `ChangeSet` / `LogChange` / `IsSecurityChange` and `Agent.SecurityFields`;
Story 3.4's `ConnectionOutcome`; Story 3.7's `Api/Switches.LogChange` seam; Story 1.3's
`EnsureAuditEvent`, `EnsureGrant`, `AssertApplications` and `Test/State.cls`.

**Consumed-by:** Epic 4's turn loop and Epic 5's confirm path emit AD-15's agent marker through
`Kernel/Audit/Event` rather than adding a second emitter; Story 4.2 inherits the corrected per-route
key in `check_handler_wire_tests`.

**Governing ADs:** AD-15 (registration is the contract; emission never fails a write), AD-8
(call-time pairs, denial names the pair), AD-9 (protected state), AD-30/AD-40 (the gate is on the
write), AD-14 (closed entity-type enum), AD-13 (the scoped triple), AD-39 (one envelope, two
renderings), AD-36 (the list read is the screen's read), AD-46 (OcuPilot's own rows stay visible),
AD-42 (an endpoint change is a security change), AD-21 (no application resource), AD-16, AD-17,
AD-38, AD-10.

**Two names, not seven.** One registered triple per verb would make the roster grow with every
future screen; one triple for everything would make AD-42's "audited as a security change"
unfilterable. The `securityChange` boolean the write path already computes — which `LogChange`'s own
doc comment says Story 3.8 would key off — selects between `ConfigChange` and `SecurityChange`, so
the roster is closed and the classification is made once.

**Why the test verb's rule is narrow.** A Test connection against the *stored* endpoint is not a
security change: that endpoint was audited as one when it was written. A test against values the row
does not hold is, because a provider call carrying a credential left the instance for an address
nobody audited (AD-42). That is the distinction DW-358's two halves collapse into one rule.

**No new published literal, on either side.** Server refusal sentences are server-authored data;
`Api/Error.cls:570-573` says outright that the client publishes none of that copy, and
`ui/tools/strings.test.mjs` reads only `EXPERIENCE.md` and `strings.ts`. The client sentences this
story would otherwise need are already published — `You need <resource> to <action>.`
(`EXPERIENCE.md:295`) with `change this definition` (`:339`) and `change the switches` (`:343`), and
the FR-3 notice (`:254`). A failed emission gets no user-facing sentence because AD-15 forbids it
failing the write and no published copy exists for a partial success on a human save; it goes to the
structured log, which OcuPilot renders on its own log screens (AD-46). So `strings.ts` stays at 261
keys and the band stays at 246 against `<= 260`.

**Why the smoke check can report `skipped`.** `CheckAuditEvent` is the check that keeps every later
audit assertion from being vacuous, so it must sweep the roster. But the live container's last
install predates this story (verified live: `RoleGranted` registered, `ConfigChange` absent), and
`Installer.#SCHEMAVERSION` is deliberately not raised, so nothing distinguishes "never installed
since the roster grew" from "deleted" except which triples are present. `fail` on the baseline,
`skipped` naming the rest, is the honest split and the one `CheckAgentSwitches` already established.

**Ledger inbox.** DW-44: addressed — `EnsureGrant` gains the already-held branch, AC7 pins it, and
the AC9 reword is named below for the lead. DW-329: addressed — suffix-or-exact anchoring.
DW-331: addressed — a create diffs against nothing. DW-358: addressed — the test verb is always
recorded, and classified by whether the tested values were the stored ones. DW-363: addressed — a
completeness check against `Agent.SecurityFields()`, per property rather than by list length,
driving both readers conservatively. DW-364:
addressed **here rather than with DW-393/394** — those two are the same rule's *reach* (one regex,
one corpus) and both are explicitly held pending Epic 4's first real caller, while this is a
*precision* defect in a different rule with a one-line fix whose only fallout is one code-line
mention in `Test/ScreenReadWire.cls`; and this story is the one that adds per-route gating
assertions, which is exactly where a key that cannot tell two routes apart costs most.

**For the lead — Story 1.3's AC9 reword (not mine to apply).** The wording lives in
`spec-1-3-…:133`, **not** in `epics.md`, whose Story 1.3 block carries five ACs and none about the
grant or the marker. Replace the marker clause with: *"…the grant is idempotent across runs, an
`OcuPilot/Security/RoleGranted` audit row naming the actor and the target is written **on the run
that actually grants the role and on no later run**, and the stamp records the outcome —
`granted`, `alreadyheld` or `skipped` — and the username."*

**For the lead — a spine amendment.** The "either OcuPilot application" wording this paragraph used
to ask for had already been fixed in the spine before this story's baseline (commit `f0ea08c`,
ancestor of `d7c1b4f`); AD-21 now reads "There are **three** applications … and two of them carry
such a role". What is still wrong is the sentence after it: *"no OcuPilot application carries an
application role at all"*. `MatchRoles` stores an application role as an entry whose matching half is
empty, the roster declares exactly that (`:OcuPilotShell`, `:OcuPilotReadiness`), and
`AssertApplications`'s own comment says so — so two of the three do carry one, and only the second
half of the stated invariant ("no application outside the roster carries an OcuPilot role") is what
`AssertNoForeignOcuPilotRole` can assert. AC4 is implemented against the true state; the spine is the
lead's to write (Rule 20). Ledgered as DW-403.

## Verification

**Commands:**

- `sh scripts/ci-throwaway.sh up` — the only instance this story's tests run against.
- `mcp__iris-dev__iris_doc_load` with `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`,
  `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` — the whole tree compiles. Loading does not run `Install()`, which
  is what keeps the live container's registrations untouched.
- `uv run scripts/check-objectscript.py` — 18 rules clean; `uv run scripts/test_check_objectscript.py`.
- `cd ui && npm run build` and `npm test` — unchanged by this story; `strings.test.mjs` must still
  report 261 keys and 246 table literals.
- `bash scripts/lint-docs.sh` — clean.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — non-zero executed
  checks, none failing, `auditevent` reading `pass` on a fresh install.
- `sh scripts/ci-throwaway.sh down` — tear down only what this story started.

**Manual checks:**

- The `%UnitTest_Result` SQL probe confirms per-class totals before any suite is called green.
- `bash scripts/smoke.sh --container ocupilot …` is expected to report `auditevent` **skipped**,
  naming the unregistered triples, until the owner next restarts that container. That is the check
  answering honestly, not a regression.

**Mutations (Rule 19).** One per acceptance criterion; each pinning test carries its own
`Mutation:` line in source. **Executed in the code review pass** on the `ocupilot-ci` throwaway, each
applied to the whole tree, recompiled `cku`, observed red, reverted, recompiled and observed green —
AC1, AC2 (all three), AC3, AC4, AC5, AC6, AC7, plus the three assertions that pass added.

- AC1 — `Test/ConfigGate`'s route sweep. mutation: delete the `IsAdministrator()` arm from any one
  handler → the sweep goes red naming that route.
- AC2 — `Test/AuditRecord`. mutation: restore `IsCredentialName`'s substring match → the
  `maxTokens`-in-clear assertion goes red; restore `HandleCreate`'s `%New()` before-row → the five
  default fields go red; restore `ConnectionOutcome`'s `If tTestedAsStored` guard → the unsaved-test
  row goes red.
- AC3 — `Test/AuditEvent`'s round trip. mutation: drop one triple from
  `Installer.EnsureAuditEvents`'s roster loop → the emission for it returns an error status and no
  row is found, red. The negative leg is what makes the positive one non-vacuous. Also
  `Test/AuditEvent`'s smoke leg. mutation: make `Smoke.CheckAuditEvent` note `skipped` for the
  baseline as well → the `fail` assertion goes red while the other two answers stay green. And its
  dropped-emission leg. mutation: make `Event.Record` return `$$$OK` whatever
  `$System.Security.Audit` answered → the report assertions go red while the no-row assertion holds.
- AC4 — `Test/WebApp` for the assertion, `Test/ConfigGate`'s no-`%Admin_*` sweep for the floor.
  mutation: put a matching role on the `api` roster entry → the install-time assertion refuses;
  delete the floor from `OnPreDispatch` → the sweep goes red on every route; delete either the
  `AutheEnabled` or the `DispatchClass` arm from `AssertApplications` → that arm's leg in
  `Test/WebApp` goes red while the positive control and the older arms stay green.
- AC5 — `Test/State`'s derived sweep for the SQL and global halves, `Test/ConfigGate`'s screen-read
  leg for the API half. mutation: drop the `OcuPilotAdmin:USE` pair from
  `Screen/Descriptor/AgentDefinitionList.cls` → `GET /screens/agent.definitions/read` answers 200 to
  the denial principal and that leg goes red; and grant the denial probe `%DB_OCUPILOT:R` → every
  table and global assertion in the sweep goes red at once, which is what shows the sweep reaches
  each class rather than reporting a login that failed.
- AC6 — `Test/AuditRecord`'s HTTP leg, read back by SQL over `%SYS.Audit` with `%NOINDEX` and a
  `UTCTimeStamp` floor (DW-85). mutation: remove the `Event.Record` call from
  `Api/Switches.LogChange` → the switch row is not found while the definition row still is.
- AC7 — `Test/Installer`. mutation: remove `EnsureGrant`'s already-held branch → a second install
  writes a second row and the count assertion goes red.
- AC4's wiring — `Test/WebApp.TestTheForeignRoleAssertionIsAStepOfEveryInstall` (added in review).
  mutation: delete the `AssertNoForeignOcuPilotRole` step from `Install()` → red, alone.
- AC3's residue — `Test/Installer.TestUninstallLeavesNoResidue` and
  `Test/WebApp.TestUnconfirmedUninstallNamesTheNewObjects` (roster sweeps added in review).
  mutation: narrow `Uninstall`'s and `EventList`'s roster loops to the baseline → both red naming
  `ConfigChangeProbe` and `SecurityChangeProbe`.
- AC3's drift detector — `Test/WebApp.TestFingerprintIsIdempotentAndSensitiveToApplicationDrift`'s
  sixth leg (added in review). mutation: narrow `StateFingerprint`'s roster fold to the baseline →
  red, alone.
- AD-15 for a real administrator — `Test/State.TestTheAuditRowIsWrittenForAPrincipalThatIsNotAllPrivileged`
  (added in review). mutation: put `Set $NAMESPACE = "%SYS"` back around `$System.Security.Audit` in
  `Event.Record` → its status and row assertions go red with the `<PROTECT>` in the message, while
  every other audit assertion in the suite stays green because they all run as `%All`.
- AC2's third fault — `Test/AgentSchema.TestAnUnmappedSecurityPropertyDrivesBothReadersConservatively`
  (added in review, with `Test/DefinitionsFieldGapProbe`). mutation: replace `SecurityFieldNames`'s
  per-property loop with `Set pComplete = 1` → the three probe assertions red, the three shipped
  controls green. This is what closed DW-401's "nothing asserts the fallback".

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 66 findings — high 0, medium 18, low 45, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` the two handler probes do not override the new audit seam, so a probe-driven write lands a real row — verified the opposite way round: `Test/AgentConnection.Outcome` calls `DefinitionsProbe.ConnectionOutcome`, so the real row is what the matrix's two Test-connection rows are read back from; overriding it would delete that coverage. Documented at both probe headers instead.
  - `[low]` `[patch]` `RecordAudit`'s doc called itself a capture seam nothing overrides, and the probe headers still counted the old seams — both corrected at their origin.
  - `[medium]` `[patch]` `Uninstall` deleted only the grant marker, so the two new registrations survived every uninstall — confirmed on the throwaway after a full suite run: `RoleGrantedProbe` gone, `ConfigChangeProbe` and `SecurityChangeProbe` still registered. `Uninstall`, `AnyObjectExists` and the destructive-confirmation message now loop the roster.
  - `[medium]` `[patch]` `StateFingerprint` folded only the grant marker's `Enabled`, so disabling either new registration — the silent-drop condition AD-15 is about — moved no fingerprint. Same fix: every roster entry is folded, absent and unreadable each named.
  - `[false]` `[reject]` the payload is unbounded against `%SYS.Audit.EventData`'s `MAXLEN = 16384` — measured on the pinned build: an 18,206-character `EventData` was written and read back intact, so `MAXLEN` is not enforced on this path and the claimed loss does not occur.
  - `[medium]` `[patch]` `Event.Description()` fell through to the grant marker's description for any name it did not recognise, so a fourth roster entry would register under a sentence about something else — it now names itself instead.
  - `[low]` `[patch]` `Event.NameList()` had no caller anywhere in the tree — deleted.
  - `[low]` `[reject]` `Record` never applies the profile suffix, so the probe profile's two change registrations are unreachable — only the production profile has a runtime, and the roster-symmetry assertion is over the unsuffixed names the emitter does select.
  - `[low]` `[patch]` the doc claimed `Security.Events.Create` truncates a description at 128 bytes — it is `%String(MAXLEN = 256)`; 128 is `%SYS.Audit.Description`. Corrected.
  - `[low]` `[reject]` the smoke check's `skipped` hides a deleted registration — spec-bound: the Design Notes decide `fail` on the baseline and `skipped` on the rest, and a new test now pins both answers.
  - `[low]` `[defer]` suffix anchoring cannot mask a secret word that is not final in a name — the verification-gap layer enumerated this tree's real keys and found only count-shaped and name-shaped losses; the forward risk is the trade DW-329 made.
  - `[low]` `[defer]` nothing compares `CREDENTIALSUFFIXES` with `field-lists.mjs`'s `CREDENTIAL_RE`.
  - `[low]` `[patch]` `AgentSchema`'s surviving paragraph still described the substring matcher — rewritten to say what the two lists now differ on.
  - `[medium]` `[patch]` `SecurityFieldNames`'s completeness test compared list lengths, the project's own count-without-structure pitfall in the one method meant to notice a missing mapping — now each security property is looked for by name.
  - `[low]` `[reject]` `RoleNamesIn` ignores a name's position inside a `MatchRoles` entry, so a matching-role grant is refused with the application-role wording — the refusal is correct; only its sentence, and the fix adds a branch.
  - `[false]` `[reject]` the owner map is order-dependent and tolerates an empty application name — the administrative role never equals a roster application role, and `Names()` refuses an empty application name before this runs.
  - `[low]` `[patch]` `AssertNoForeignOcuPilotRole` counted applications it had skipped and left its result set open on the error path — counted after the read, closed on both paths.
  - `[low]` `[patch]` the success report did not mention the two arms the method now also asserts — corrected.
  - `[low]` `[patch]` `InstallerProbe`'s doc called the assertion "the last step of a successful install"; four steps run after it — corrected at both occurrences.
  - `[low]` `[reject]` `Switches.IsSecurityChange` and `Definitions.ClassifyChange` are the same role under two names — no named harm; both are private to their handler.
  - `[low]` `[reject]` the verb constants were parameterised on the switches side only — cosmetic.
  - `[false]` `[reject]` a write that changed nothing still records a row — `changes:{}` is itself the mark that nothing moved, and a save that changed nothing is an accepted write.
  - `[low]` `[patch]` `Test/AuditEvent` restored a deleted registration only inside each method, so an aborted method left auditing off — the restore is now in `OnAfterOneTest` and reports a survivor as a failure.
  - `[low]` `[defer]` `check_destructive_test_guard` does not see `Security.Events.Delete` — already this spec's frontmatter entry; the new class carries its guard voluntarily.
  - `[low]` `[patch]` both new `UrlMap` readers took a single 32000-character read — both now read to the end, and the assertion reports how much it read.
  - `[low]` `[reject]` `ConfigGate` declares its own `ADMINPERMISSION` rather than reading the handler's — the tree's own wire-security suite spells the pair the same way.
  - `[low]` `[patch]` the route-ordering assertion could not fail and pinned nothing `%CSP.REST` would notice — deleted, with the reason recorded where it stood.
  - `[low]` `[patch]` the test-verb comment claimed the credential always left the instance for an unaudited address — true only for the endpoint and provider halves; corrected.
  - `[low]` `[patch]` the spec's closing result section still read "planning only" — rewritten below. The 17-versus-18 rule count belongs to `CLAUDE.md`: deferred, because the fix edits an agent-context file.
  - `[medium]` `[defer]` a Test connection against unstored values that faulted records nothing — pre-existing: the fault return predates this story's change to the same method.
  - `[medium]` `[patch]` (grouped with the `Uninstall` entry above) the two new registrations orphan on every uninstall.
  - `[medium]` `[patch]` (grouped with the `Description` entry above) an unrecognised roster name registers under the grant description.
  - `[low]` `[reject]` `Redact` throwing would write a row carrying `{}` with no failure logged — no realistic reachable input; `Redact` is total over this tree's payloads and pinned by its own suite.
  - `[low]` `[reject]` (grouped with the profile-suffix entry above) the probe profile's change registrations are unreachable through `Record`.
  - `[medium]` `[defer]` the per-route key is still a substring test, so a route that is a path prefix of another is covered by the longer one's name — the same rule's *reach*, which the Design Notes hold pending Epic 4 with DW-393/394.
  - `[low]` `[patch]` (grouped with the smoke entry above) the check's two answers are now pinned by a test.
  - `[low]` `[patch]` (grouped with the `UrlMap` reader entry above) the single 32000-character read.
  - `[medium]` `[patch]` `StateClasses` skipped a class whose table or global failed its shape filter, so a sweep could quietly cover seven of eight — it now refuses and names the class.
  - `[medium]` `[patch]` (grouped with the completeness entry above) length equality reports a complete translation over a missing property.
  - `[low]` `[reject]` `EnsureAuditEvents` repairs `Enabled` but not a drifted `Description` — `Enabled` is what decides whether a row is written; a description is cosmetic and the fix adds a branch.
  - `[low]` `[defer]` (grouped with the anchoring entry above) suffix anchoring un-masks mid-name secrets.
  - `[low]` `[reject]` `killSwitchReason` is declared non-security — deliberate, stated at `Fields()`, and now pinned by a test that observes the classifier's other answer.
  - `[low]` `[patch]` (grouped with the `NameList` entry above) dead code.
  - `[medium]` `[reject]` AC1's sweep is scoped to the `/agent/` routes rather than to every declared route — the fix edits this build's spec: AC1 as written is false against the shipped tree, where `/instance`, `/namespaces`, `/navigation`, `/logs/*` and the screen read are gated on other resources and answer this principal. Escalated to the lead below.
  - `[low]` `[reject]` the spec says `ConnectionOutcome` records the test verb "unconditionally" while a faulted call records nothing — the fix edits this build's spec; the code's own doc comment states the exception.
  - `[medium]` `[patch]` the eight state classes share one data global, so the sweep's global half is one reference re-read — the claim is corrected at the class header and at the method, and the SQL half is named as the discriminating one.
  - `[medium]` `[patch]` the two new `AssertApplications` arms were unreachable through the only seam that drives the method, so both could be deleted with every test green — a manifest-bearing seam and a drift test now reach them.
  - `[medium]` `[patch]` the smoke check's `fail`-versus-`skipped` discrimination was asserted nowhere — a new armed test deletes a later entry, then the baseline, and pins `skipped`, `fail` and the run verdict.
  - `[medium]` `[patch]` the switch classifier's "not a security change" branch was never exercised — a reworded-reason leg and a hold leg now observe both answers.
  - `[low]` `[defer]` the `pComplete` fallback is unreachable with the shipped declarations, so nothing asserts it — the structural check replaces the length test; constructing the incomplete state needs a probe overriding `Fields()`.
  - `[medium]` `[patch]` `ConfigGate`'s swept-count assertion compared two counters produced by the same predicate over the same array and could not fail — deleted, with the working guard named where it stood.
  - `[low]` `[patch]` (grouped with the `NameList` entry above) dead code with a doc comment describing a mechanism the installer does not use.
  - `[low]` `[reject]` the two new install guards cannot fire — they guard a future roster edit; code that refuses a state nothing can reach today is not a defect.
  - `[low]` `[reject]` the widened route rule can be satisfied by a source-text assertion — a property of the rule's own shape, unchanged by this story; the naming class drives the route in its other methods.
  - `[medium]` `[reject]` a create records `SecurityChange` where the matrix row says `ConfigChange` — the fix edits this build's spec. A create writes the provider, the endpoint and the credential reference, all of which AD-42 makes a security change, and the Design Notes make the computed boolean select the name; the two halves of the spec cannot both hold. Escalated to the lead below.
  - `[low]` `[reject]` the create row's input is `{name, provider}` and the test posts four members, and counts six default fields where the row says five — the row's substantive claim, defaults carried with an empty `old`, is asserted.
  - `[low]` `[reject]` the Test-connection legs are driven in process rather than over the route — the constraint is that no socket may open to a provider; the audit row read back is the real one.
  - `[low]` `[patch]` "the failure is logged" and "the write still succeeds" were observed on two different emissions — the added leg asserts the report at the seam and the write's 200 at the wire, in one method.
  - `[low]` `[reject]` the SQL/global half and the API half use two different principals — AC5 restates the row as a conjunction over two suites, and each principal is purpose-built for its surface.
  - `[medium]` `[reject]` (grouped with the AC1 entry above) the sweep is narrower than the intent's row and adds an exception list.
  - `[low]` `[reject]` the roster round trip calls `$System.Security.Audit` directly for the grant marker, which `Record` never names — that triple is the installer's emission and is covered by `Test/Installer`.
  - `[low]` `[reject]` (grouped with the profile-suffix entry above) `Record` ignores the suffix.
  - `[low]` `[defer]` `Test/AuditRecord` runs `Install("")` with no arming variable — nine classes already shipped in the tree do the same; the same root cause as the frontmatter entry.
  - `[low]` `[defer]` (grouped with the anchoring entry above) the redactor change reaches every structured log line, not only the audit payload.
  - `[low]` `[reject]` the switch classification change is visible on the console line Story 3.7 shipped, not only on the audit row — intended, and now pinned by the added leg.
  - `[low]` `[reject]` the diff carries scope the intent paragraphs do not derive — each item is in the spec's own Execution list or its ledger inbox (DW-44, DW-363, DW-364).

## Auto Run Result

Status: done

**Implemented.** One emitter, `Kernel/Audit/Event.cls`, owns the audit triple roster the installer
registers and the `EventData` shape every configuration change lands as; both `LogChange` seams call
it; the change record is corrected at its three faults (DW-329, DW-331, DW-358); and the gate is a
sweep over the router's own `UrlMap` and over every `Kernel/State/Base` subclass rather than a list.

**Files changed** (paths relative to this file's directory):

- [`../../src/OcuPilot/Kernel/Audit/Event.cls`](../../src/OcuPilot/Kernel/Audit/Event.cls) - new; the
  roster, the `{actor, target, verb, securityChange, changes}` payload, redaction and the `%SYS`
  emission that never fails its caller. AC3, AC2.
- [`../../src/OcuPilot/Kernel/Audit/Log.cls`](../../src/OcuPilot/Kernel/Audit/Log.cls) - suffix-or-exact
  credential-name anchoring. AC2 (DW-329).
- [`../../src/OcuPilot/Api/Definitions.cls`](../../src/OcuPilot/Api/Definitions.cls) - a create diffs
  against nothing; `SecurityFieldNames` reports completeness structurally; a Test connection that
  answered is always recorded; `LogChange` writes the row. AC2, AC6.
- [`../../src/OcuPilot/Api/Switches.cls`](../../src/OcuPilot/Api/Switches.cls) - per-field security
  flags, per-verb classification, the row against `agent-switch`/`instance`/`instance`. AC2, AC6.
- [`../../src/OcuPilot/Install/Installer.cls`](../../src/OcuPilot/Install/Installer.cls) -
  `EnsureAuditEvents` loops the roster; `EnsureGrant` gains the already-held branch;
  `AssertApplications` re-reads authentication and dispatch class; new `AssertNoForeignOcuPilotRole`
  population query; `Uninstall`, `AnyObjectExists` and `StateFingerprint` cover every roster entry.
  AC3, AC4, AC7.
- [`../../src/OcuPilot/Install/Smoke.cls`](../../src/OcuPilot/Install/Smoke.cls) - `CheckAuditEvent`
  sweeps the roster: `pass`, `fail` on the baseline, `skipped` naming the rest. AC3.
- [`../../src/OcuPilot/Kernel/State/Stamp.cls`](../../src/OcuPilot/Kernel/State/Stamp.cls) - the
  three-value grant vocabulary. AC7.
- [`../../scripts/check-objectscript.py`](../../scripts/check-objectscript.py) and
  [`../../scripts/test_check_objectscript.py`](../../scripts/test_check_objectscript.py) - a `:param`
  route keys on its own path (DW-364), with the harness case for it.
- [`../../scripts/ci-throwaway.sh`](../../scripts/ci-throwaway.sh) - `OCUPILOT_ALLOW_AUDIT_EVENTS`.
- New tests: `Test/AuditEvent.cls` (AC3, armed), `Test/AuditRecord.cls` (AC2, AC6),
  `Test/ConfigGate.cls` (AC1, AC4 floor, AC5 API half, armed), `Test/EventProbe.cls` (the drop-report
  capture seam). Extended: `Test/State.cls` (AC5 sweep), `Test/Installer.cls` (AC7),
  `Test/WebApp.cls` (AC4), `Test/InstallerProbe.cls`, `Test/SwitchState.cls`, `Test/Log.cls`,
  `Test/AgentSchema.cls`, `Test/ScreenReadWire.cls`, and the two probe headers.

**Review findings.** 66 reported across four layers: 0 high, 18 medium, 45 low, 3 false. Patched
entries by verdict: 9 medium, 14 low. Deferred: 7 new items in frontmatter `deferred:` - the faulted
Test connection, the anchored backstop's mid-name blind spot, the missing cross-language list
comparison, the route key's remaining substring match, the unreachable `pComplete` branch,
`Test/AuditRecord`'s unarmed install, and `CLAUDE.md`'s stale rule count. Rejected, with the reason
in the triage log: the unbounded-payload claim (measured false - an 18,206-character `EventData`
round-tripped intact), the order-dependent owner map and the empty-change-set row (both false), and
the low findings whose fix would add a branch, restate a by-design decision, or edit this build's
spec.

**Two spec defects the lead must settle** - both rejected here because their fix edits the
intent-contract, and the code follows the spine:

1. The matrix's first row says a create records a `ConfigChange` row. A create writes the provider,
   the endpoint and the credential reference, every one of which AD-42 makes a security change, and
   the Design Notes make the computed `securityChange` boolean select the event name. The two cannot
   both hold; `Test/AuditRecord` pins `SecurityChange`, and the row's substantive claim - the created
   defaults carried with an empty `old` - is asserted.
2. AC1 says every route the map declares is refused 403. That is false against the shipped tree:
   `/instance`, `/namespaces`, `/navigation`, `/logs/*` and `/screens/:screen/read` are gated on
   other IRIS resources and answer a `%Admin_Operate` holder. `Test/ConfigGate` sweeps the `/agent/`
   configuration routes for AC1 with the closed two-entry exception list and a zero-count guard, and
   sweeps **every** declared route for AC4's `AUTH.NOADMIN` floor.

**Follow-up review recommended: true.** Nine medium entries were patched, and the installer's roster
loops in `Uninstall` / `AnyObjectExists` / `StateFingerprint`, the manifest-bearing install seam and
the three new pinning tests were written after the four review layers had read the diff, so no layer
has seen them. That is the specific unverified risk.

**Verification performed.** Whole tree compiled into `ocupilot-iris` (284 documents, `cku`, clean; an
ERROR #1043 in a review patch was caught here and fixed). Throwaway `ocupilot-ci` brought up fresh
and torn down: `node ui/tools/ci-runner.mjs --container ocupilot-ci` reported 83 classes, 801 tests,
0 failed, 0 probe leftovers, 0 overlaps, 0 foreign runs; the `%UnitTest_Result` probe independently
confirmed 801 / 801 / 0. `smoke.sh --container ocupilot-ci`: 19 executed, 0 failed, `auditevent`
**pass**. After that run all three probe registrations were gone from the throwaway - before the
`Uninstall` fix, two survived. `uv run scripts/check-objectscript.py` 284 files / 18 rules / 0
problems; its harness 89 tests OK; `bash scripts/lint-docs.sh` clean; `cd ui && npm run build` clean
and `npm test` 783 + 379 green, `strings.ts` still 261 keys with the literal band unmoved.

**Code review pass (2026-09-16).** Sixteen patches across twelve files, all verified on the
`ocupilot-ci` throwaway.

**One HIGH, fixed.** `Event.Record` entered `%SYS` to call `$System.Security.Audit`. Entering `%SYS`
needs `%DB_IRISSYS` READ; an OcuPilot administrator built to least privilege — code-database read,
`OcuPilotAdmin`, an `%Admin_` resource — holds none, so the switch raised `<PROTECT>`, and because
AD-15 makes the emitter swallow its own failure, **every configuration change such an administrator
accepted completed with no audit row and only a log line**. That is the one property this story
exists to establish, failing silently for a plausible production principal. Measured both ways on the
throwaway: with the switch, `<PROTECT>` and 0 rows; without it, `$$$OK` and 1 row. The switch is
removed (`$System.Security.Audit` is a `%SYSTEM` method and needs no switch), and the row now records
the namespace the change was made in. Every existing audit assertion was blind to this because
`%UnitTest` runs as `%All`; `Test/State.TestTheAuditRowIsWrittenForAPrincipalThatIsNotAllPrivileged`
now pins it, with the switch restored as its mutation.

Correctness: `Smoke.CheckAuditEvent` identified the baseline triple by substring against a
comma-joined sentence, so a later roster entry whose name begins with `RoleGranted` would have been
reported as the baseline missing — it is now a `$ListFind` over the missing names. Verification, four
gaps each closed with a mutation-demonstrated test: the `AssertNoForeignOcuPilotRole` step's wiring
into `Install()`, `Uninstall`'s and `EventList`'s roster sweeps, `StateFingerprint`'s roster fold,
and DW-363's conservative fallback (new `Test/DefinitionsFieldGapProbe`, which closes DW-401).
Correctness of claims, at their origin: `EventList` wore `AnyObjectExists`'s doc comment,
`EnsureAuditEvents`'s summary comment claimed a distinction its counter cannot make,
`Stamp.GrantedUsername`'s comment said `""` on a path that sets it, `ConnectionOutcome`'s header
justified the faulted case with a reason its own `Else` branch rejects, `Test/AuditEvent` discarded
two `%Status` results, `ci-throwaway.sh`'s arming comment said one registration where the class
deletes two including the baseline, `Test/State`'s storage join took whichever row arrived first, and
`check-objectscript.py`'s rule-12 prose still described the pre-DW-364 route key. Four new ledger
entries, DW-403 through DW-406; DW-401 closes. The frontmatter's `CLAUDE.md`-rule-count entry was
removed: `CLAUDE.md:121` already reads 18 at this baseline, so the entry deferred work that does not
exist.

**Residual risks.** The live `ocupilot` container now carries **all three** OcuPilot registrations —
`RoleGranted`, `ConfigChange` and `SecurityChange` (read 2026-09-16; 2004, 4 and 14 rows written) —
so `auditevent` reads `pass` there rather than `skipped`. They were registered by the AD gate's own
runs 2167 and 2168, which ran `Test/AuditRecord` against that instance and so ran `Install("")` on
it: the exact cost DW-402 names, materialized, on the one instance this story's Boundaries said would
never be asked to register an event type. Nothing was altered to fix that, and the container still
holds 0 definitions, 0 switch rows and 0 holds. The `Mutation:` lines were **executed** in the code
review pass; `## Verification` records which.
