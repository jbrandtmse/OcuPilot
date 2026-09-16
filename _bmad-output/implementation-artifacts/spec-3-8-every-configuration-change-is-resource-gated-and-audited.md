---
title: 'Story 3.8: Every configuration change is resource-gated and audited'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
baseline_revision: '38aef4423ed8048a1b0a860daa070241bcf66317'
review_loop_iteration: 0
followup_review_recommended: false
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
  `Kernel.Audit.Log.Redact`, and calls `$System.Security.Audit` in `%SYS` under AD-16 save/restore.
  Never throws; an error status is logged through `Kernel/Audit/Log` and swallowed.
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
length check against `Agent.SecurityFields()` driving both readers conservatively. DW-364:
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

**For the lead — a spine amendment.** AD-21's last paragraph says the static application's matching
role is *"the only application or matching role **either** OcuPilot application carries"*. There are
three applications (shell, api, readiness) and **two** carry a purpose-built matching role, so the
sentence is false against the shipped tree and against `Test/WebApp.cls`'s three methods. This story
implements AC4 against the true state and does not edit the spine.

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
`Mutation:` line in source.

- AC1 — `Test/ConfigGate`'s route sweep. mutation: delete the `IsAdministrator()` arm from any one
  handler → the sweep goes red naming that route.
- AC2 — `Test/AuditRecord`. mutation: restore `IsCredentialName`'s substring match → the
  `maxTokens`-in-clear assertion goes red; restore `HandleCreate`'s `%New()` before-row → the five
  default fields go red; restore `ConnectionOutcome`'s `If tTestedAsStored` guard → the unsaved-test
  row goes red.
- AC3 — `Test/AuditEvent`'s round trip. mutation: drop one triple from
  `Installer.EnsureAuditEvents`'s roster loop → the emission for it returns an error status and no
  row is found, red. The negative leg is what makes the positive one non-vacuous.
- AC4 — `Test/WebApp` for the assertion, `Test/ConfigGate`'s no-`%Admin_*` sweep for the floor.
  mutation: put a matching role on the `api` roster entry → the install-time assertion refuses;
  delete the floor from `OnPreDispatch` → the sweep goes red on every route.
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

## Auto Run Result

Status: ready-for-dev

Planning only, halted at the invocation's direction; nothing implemented and no source touched.
Investigation reached the spine's 48 ADs, the six routed ledger entries, both `LogChange` seams,
the installer's registration and application assertions, the two wire-security suites, Story 1.3's
denial suite, the strings pipeline and the ObjectScript checker. Four live read-only probes on
`ocupilot-iris` confirmed DW-329 (`IsCredentialName("maxTokens")` = 1), DW-363's list lengths (6 and
6), that `Security.Applications` carries exactly one role property (`MatchRoles`), and that
`OcuPilot/Security/ConfigChange` is not registered on that instance. No literal is missing: this
story adds no user-facing copy on either side.
