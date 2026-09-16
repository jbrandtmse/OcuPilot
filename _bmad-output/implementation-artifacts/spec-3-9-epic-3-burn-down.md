---
title: 'Epic 3 burn-down'
type: 'bugfix'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings:
  - oversized
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 3's own gates chartered twelve ledger entries and none of them can end this story
still `routed`. Four are secret-lifecycle holes on the one surface that holds keys, two are the same
lost-update shape in three stores, three are gates that stayed green while a defect walked past them,
and three are code a named mutation cannot redden today.

**Approach:** Eleven are fixed, one is made terminal. The four secret entries collapse onto one
sibling query plus one ownership marker; the two concurrency entries onto one conditional write at
the single save seam; the three gates each gain the check that would have caught their own incident.

## Boundaries & Constraints

**Always:**

- Every entry ends fixed with a demonstrated mutation, or terminal with its reason recorded on the
  entry. `routed` is not an ending. The lead adjudicates at the gate; this story does not close
  ledger entries itself.
- OcuPilot removes a credential entry only where it **created** it and no surviving definition names
  that reference (AD-25's own test, made checkable). Never the key's value in a status, a log line or
  a trap (AD-35, AD-42).
- A stale save is refused, never taken. The refusal is an ordinary envelope with a stable machine
  code (AD-12, AD-39) and is evaluated inside the guarded frame, which spawns nothing and re-enters
  nothing (AD-9).
- Storage stays compiler-managed: new properties are declared, no `Storage` XData is written.

**Never:**

- No real outbound provider call, and no paid API.
- Nothing on the live `ocupilot` container: no principal, no audit event type registered or deleted,
  no SSL configuration, no `docker compose up`/`down`. Test classes run on a throwaway
  (`sh scripts/ci-throwaway.sh up|down`, torn down by whoever started it).
- No client-supplied version token on the wire. The window these two entries name opens and closes
  inside one request; a browser-level token is a separate root cause and is not invented here.
- No `StateClass()` seam on `Api/Definitions` whose only consumer is a test (DW-352's own finding).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Delete a definition that stored its own key | `credType=creds`, `CredentialCreated=1`, no sibling names the reference | definition row deleted **and** the credential entry removed | vendor refuses the delete: definition still deleted, refusal logged by code, no key text |
| Delete a definition whose reference a sibling names | two definitions, one `credentialName` | definition deleted, credential entry **kept** | none |
| Store a key under a shared reference | two definitions name `R`, key posted to A | both A and B lose verification and are disabled | a failed sibling clear renders 500 and records no transition |
| Two writers, one Switches field each | B reads, A saves, B saves | B is refused `STATE.CONFLICT` (409); A's write survives | client renders the published conflict literal, not the raw envelope reason |
| Security fields change during the provider call | snapshot taken, row updated mid-call | verification is **not** recorded | `STATE.CONFLICT`; the definition stays unverified |
| Credential read fails transiently | row locked / `%OpenId` answers non-object | `PROVIDER.CREDENTIAL` fault, definition **stays enabled** | absent entry still disables, as today |
| A host resolving to two records | multi form answers public + loopback | `Classify` reports loopback (worst kind wins) | a family that raises contributes nothing |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Definitions.cls` -- `HandleDelete` :390, `HandleStoreCredential` :485 (arm (a)
  clear :526-534, arm (b) re-read :536-546), `OpenDefinition` :944 (public, `..`-dispatched at both
  call sites), `SecretClass()` :860 (the seam already overridden by `DefinitionsProbe`), `HandleTest`
  :681, `HandleUpdate` :333-385.
- `src/OcuPilot/Kernel/Secret/Ladder.cls` -- `Resolve` :50, `CredentialsRungAvailable` :76 (predicate
  is `%ExistsId` alone, :78), `Credential` :98 (six `""` exits, :101-113), `Store` :131. Header :3-8
  states the empty-string contract; :81-82 states "or any failure at all". No clear/delete exists.
- `src/OcuPilot/Kernel/State/Base.cls` -- `GuardedSave` :88 is the **one** write seam Egress, Switch
  and Agent all funnel through. `GuardedIdsWhere` :390 is the ready-made one-parameter query seam.
  No lock, version or timestamp anywhere.
- `src/OcuPilot/Kernel/State/Egress.cls` -- `SetGuarded` :99-119 (read :103, merge :106-112, write
  :113); no timestamp property. `src/OcuPilot/Kernel/State/Switch.cls` -- `SetGuarded` :87-105, the
  same shape line for line.
- `src/OcuPilot/Kernel/State/Agent.cls` -- `CredentialName` :68, `ConnectionVerified` :99,
  `GuardedClearVerification` :224 (clears `Enabled` too), `GuardedSetVerification` :257,
  `GuardedDeleteId` :280, `GuardedList` :297. No index on `CredentialName`.
- `src/OcuPilot/Kernel/Egress.cls` -- `Addresses` :150-170, public ClassMethod with no return type;
  `HostNameToAddrMulti` :155 and `HostNameToAddr` :165 union by subscript; `Classify` :86-111 and
  `Rank` :219-226 are worst-kind-wins.
- `src/OcuPilot/Kernel/Provider/Base.cls` :114-118 -- `""` becomes `PROVIDER.CREDENTIAL`.
  `src/OcuPilot/Port/ProviderPort.cls` :120-136 -- `FlagUnresolvedCredential` is what turns that
  fault into a disable.
- `scripts/check-objectscript.py` -- `DESTRUCTIVE_TEST_RE` :1104-1109, `check_destructive_test_guard`
  :1162-1194, `guarded_before_all_tests` :1138-1159, `CHECKS` :1560-1579. Harness shape:
  `scripts/test_check_objectscript.py` :1359-1377.
- `scripts/check-prose.py` -- `DEFAULT_GLOBS` :32-44; implementation-artifacts absent by omission.
  `scripts/lint-docs.sh` :18-21 reads the set from `--list`, :29-30 runs the two checkers.
- `ui/tools/client-lint.mjs` -- rule shape :408-427, `lintClient()` :454-508 (it already walks
  `ui/browser/*.mjs` at :492-498 for one rule), `RULE_FAMILIES` :516-522. Tests:
  `ui/tools/client-lint.test.mjs` :37-43, :63-72.
- `ui/browser/ssl.browser-spec.mjs` :134-136 -- the last exact-count filter assertion.
  `processes` :256-265 and `tasks` :212-221 were already repaired.
- `ui/src/app/core/strings.ts` (261 keys) and EXPERIENCE.md Fixed strings table (:252 header, rows
  :254-343, **246 literals**, band 150-260 asserted at `ui/tools/strings.test.mjs` :319, exact-count
  closure :359-361). Read-only evidence for the conflict copy: nothing exists today for a stale save,
  a reload prompt or a credential read failure.
- Probes, read-only on `ocupilot` HSCUSTOM 2026-09-16: `IsEnsembleNamespace()`=1,
  `$System.License.GetFeature(1)`=1, `Ens.Config.Credentials` compiled=1 -- so the vendor's
  `SecondaryDelete` (stricter `BasicChecks`, `irislib/%SYS/Ensemble.cls` :543 against `SecondarySet`'s
  :524) can run here, and narrowing the rung predicate does not switch the rung off on this instance.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/State/Base.cls` -- add `Property RowVersion As %Integer [ InitialExpression = 0 ]`
   and `GuardedSaveIfCurrent(pObject, pExpected)`: inside one `TSTART`/`TCOMMIT`, a conditional
   `UPDATE ... SET RowVersion = ? WHERE ID = ? AND RowVersion = ?` with bound parameters; `%ROWCOUNT`
   of 0 rolls back and answers a distinct refusal status, otherwise `%Save()` and commit. Normalize a
   stored `""` to 0 (existing rows predate the property). Declare the property only -- no `Storage`.
2. `src/OcuPilot/Kernel/State/Egress.cls`, `Switch.cls` -- `SetGuarded` captures the version read at
   `GuardedCurrent` and saves through `GuardedSaveIfCurrent`. Add optional `pExpectedVersion` so a
   caller (and the pinning test) can supply the snapshot it actually holds.
3. `src/OcuPilot/Kernel/State/Agent.cls` -- `GuardedSetVerification(pId, pExpectedVersion)` refuses
   when the row moved. `src/OcuPilot/Api/Definitions.cls` `ConnectionOutcome` :657-725 captures the
   version beside the security-field snapshot and passes it across the provider call.
4. `src/OcuPilot/Api/Error.cls` -- add `Parameter STATECONFLICT = "STATE.CONFLICT"` with a
   server-authored reason, rendered 409 by `Api/Switches.cls` and `Api/Definitions.cls`.
5. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- **append one row after line 343**
   (nothing below it, so no `/** EXPERIENCE.md:n */` renumbering) with the conflict literal
   `"Someone else changed this while you were here. Reload to see the current values, then save again."`;
   add the matching key to `ui/src/app/core/strings.ts`. 246 -> 247 literals, 261 -> 262 keys.
6. `ui/src/app/areas/agent/switches.store.ts`, `switches.page.ts`, `definition-form.page.ts` --
   render the new literal when the refusal code is `STATE.CONFLICT`, **before** the raw
   `envelopeReason` fallback, so the server's words never reach the screen on this path.
7. `src/OcuPilot/Kernel/Secret/Ladder.cls` -- (a) `CredentialsRungAvailable` also requires
   `##class(%Library.EnsembleMgr).IsEnsembleNamespace()` and `$System.License.GetFeature(1)`, which is
   what Story 3.3's AC already says and what `SecondaryDelete` requires; (b) `Store` gains
   `Output pCreated`; (c) new `Clear(pCredentialName)` deleting the entry through the vendor's own
   `%DeleteId`, naming the reference and never the value; (d) `Credential(pName, Output pTransient)`
   and `Resolve(..., Output pTransient)` -- 1 on the failure exits (:102, :105, the `Catch`), 0 on the
   absence exits (:101, :103, :110). Replace the header's "or any failure at all" sentence with the
   one that is true; do not append a correction.
8. `src/OcuPilot/Kernel/State/Agent.cls` -- add `Property CredentialCreated As %Boolean` and
   `GuardedIdsByCredentialName(pName, pExceptId, Output pIds)` over the existing `GuardedIdsWhere`
   seam.
9. `src/OcuPilot/Api/Definitions.cls` -- one `ClearOwnedCredential(pName, pExceptId)` helper called
   from `HandleDelete`, and from `HandleUpdate` when the reference changes. `HandleStoreCredential`
   sets `CredentialCreated` from `Store`'s new output and clears verification on **every** definition
   naming the reference, not only the posted id.
10. `src/OcuPilot/Kernel/Provider/Base.cls`, `src/OcuPilot/Port/ProviderPort.cls` --
    `FlagUnresolvedCredential` does not disable the definition when the resolution was transient.
11. `src/OcuPilot/Kernel/Egress.cls` -- extract `MultiLookup(pHost, pFamily)` out of `Addresses` as
    one overridable ClassMethod; `Addresses` keeps its union loop.
12. `scripts/check-objectscript.py` -- widen `DESTRUCTIVE_TEST_RE` with
    `Security.Events.(Create|Delete|Modify)`, `Security.Roles.Delete`, and
    `##class(OcuPilot.Install.Installer).Install("")` -- the third is the one that would have caught
    DW-402, since `Test/AuditRecord` never names `Security.Events`. Add paired cases to
    `scripts/test_check_objectscript.py` in the :1359-1377 shape.
13. Arm the ten unarmed classes with `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL"`
    and the `OnBeforeAllTests` refusal idiom: `Test/AuditRecord`, `Static`, `InstallNamespaceSource`,
    `GatewayGapIpmPath`, `Manifest`, `WebApp`, `UninstallGuard`, `GrantReadBack`, `Provenance`,
    `Installer`. Set the variable in `scripts/ci-throwaway.sh` beside the other five, with its own
    comment naming what a production install does.
14. `scripts/check-prose.py` -- add `_bmad-output/implementation-artifacts/spec-*.md` to
    `DEFAULT_GLOBS`, and add a third check: a spec's required headings are present and in order, and
    its backticks and fences balance. Run the sweep; repair the residue with `--fix` and by hand, and
    report the count in `## Auto Run Result`.
15. `ui/browser/ssl.browser-spec.mjs` :134-136 -- assert the expected row survives and the filter
    narrowed, never an exact count. `ui/tools/client-lint.mjs` -- new rule over
    `ui/browser/*.browser-spec.mjs` refusing an exact-count assertion on a filter result and refusing
    one filter leg compared against another; add its slug to `RULE_FAMILIES` and paired tests to
    `client-lint.test.mjs`.
16. Tests: `Test/State.cls` (two-writer refusal), `Test/SwitchesWire.cls` (the 409 over HTTP, which is
    this story's integration AC), `Test/AgentConnection.cls` (verification refused
    after a mid-call move), `Test/AgentCredential.cls` (delete removes the key; sibling keeps it;
    store sweeps siblings), `Test/Secret.cls` (update :110's rung-predicate test for the widened
    predicate; transient vs absent), `Test/Egress.cls` + `Test/EgressProbe.cls` (a `MultiLookup`
    toggle so the real `Addresses` body runs), `Test/DefinitionsProbe.cls` +
    `Test/RouterFixture.cls` (a credential route and an `OpenDefinition` call counter).

**Entry to task, so the gate can check each of the twelve:** DW-345 -> 7c, 8, 9 · DW-346 -> terminal,
no task · DW-350 -> 7a · DW-353 -> 8, 9 · DW-362 -> 1, 3, 4 · DW-388 -> 1, 2, 4, 5, 6 · DW-384 -> 14 ·
DW-368 -> 15 · DW-396 -> 12, 13 · DW-338 -> 11 · DW-343 -> 7d, 10 · DW-352 -> 16.

**Acceptance Criteria:**

- Given the twelve chartered entries, when this story ends, then each is fixed with a mutation
  recorded in `## Verification` or terminal with its reason -- and DW-346 is the only terminal one.
- Given a burn-down that touches shipped, tested code in three stores, when the suite runs on a
  throwaway, then every previously green class is still green and the new refusals are the only
  behavior change.
- Given the ten newly armed classes, when the suite is pointed at an instance without
  `OCUPILOT_ALLOW_PRODUCTION_INSTALL`, then each refuses by name and installs nothing.
- Given a reviewer reading `EXPERIENCE.md`, when they look for the conflict copy, then it is a
  published row and `node --test tools/strings.test.mjs` is green at 247 literals / 262 keys.

## Design Notes

**Governing ADs (Rule 6):** AD-9 (the guarded frame spawns and re-enters nothing -- the conditional
write stays inside it), AD-12/AD-39 (one envelope, stable machine code), AD-25 (remove only what
OcuPilot created), AD-34 (the idiom: a conditional update exactly one caller wins, the loser refused
and not retried), AD-35/AD-42 (no key text in a status; the ladder returns no value into an error),
AD-36, AD-37.

**Two spine amendments for the lead (Rule 20 -- not applied here).** (1) No AD governs optimistic
concurrency on OcuPilot's own stores; AD-34 covers only the confirm path. Epics 4 and 5 add
transcripts, the ledger and proposals to the same `Kernel/State/Base` and would each answer this
differently -- a Consistency Conventions row, or an AD, is the right home. (2) AD-37 says every
stored reference is weak and says nothing that authorizes deleting one; DW-345's fix deletes a
credential entry OcuPilot itself created. The epics AC already decided the product question ("a
stored key does not outlive the definition that named it"), so this is a decision to record, not to
re-take.

**DW-343 -- the contract changes.** `Credential()`'s empty-string contract exists so that no
credential *text* reaches a status or a log (AD-35, AD-42). An `Output %Boolean` carries no text, so
the purpose survives and only the incidental "one answer" phrasing goes. The alternative -- leaving a
locked row indistinguishable from a deleted one -- disables a working definition on a transient
fault, which is the reachable harm DW-22's flag created.

**DW-396 -- widening and arming are one decision.** Widening alone reddens `Test/Installer` at line
41 and nine siblings; arming alone leaves the pattern blind. A new variable rather than
`OCUPILOT_ALLOW_AUDIT_EVENTS`: the guarded effect is a whole production install -- a database, a
resource, a role, three web applications, the audit registrations and the `_SYSTEM` unexpire --
and naming it after one side effect would mislead the next reader. Consequence, stated plainly:
after this, those ten classes run on a throwaway and on CI, never on the local `ocupilot` container.

**DW-346 is terminal.** QA already added the assertion and it is green; the cleanup it observes is
the vendor's `%OnClose`, so no OcuPilot mutation can redden it. It stays as a vendor-behavior
regression pin, which is the same doctrine AD-27's inventory fixture uses. Its one reachable hole --
a namespace where `SecondarySet` succeeds and `SecondaryDelete` cannot -- is DW-350's and closes
there.

**Consumes / Consumed-by (Rules 1-2).** `GuardedSaveIfCurrent` is introduced here and consumed in
this story by `Kernel/State/Egress`, `Kernel/State/Switch` and `Kernel/State/Agent`; its integration
AC is the Switches HTTP 409 above, observed through `Test/SwitchesWire`, not by inspecting
`Base`. `Ladder.Clear` is consumed by `Api/Definitions.HandleDelete` and `HandleUpdate`. Later
consumers: Epic 4's transcript and ledger stores inherit `RowVersion` from `Base`.

## Verification

**Commands:**

- `mcp__iris-dev__iris_doc_load` -- `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"`,
  `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`, `baseDir: "/Users/jbrandt/git/OcuPilot/src"`,
  `compile: true`, `flags: "cku"` -- expected: whole tree compiles clean.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected:
  clean, and the new cases pass.
- `bash scripts/lint-docs.sh` -- expected: clean over the widened document set.
- `cd ui && npm run build && npm test` -- expected: prebuild's six checkers pass including the new
  client-lint rule; `strings.test.mjs` green at 247 / 262.
- `sh scripts/ci-throwaway.sh up`, then one `iris_execute_tests` call per class, each read back from
  `%UnitTest_Result` before the next is sent, then `sh scripts/ci-throwaway.sh down`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` (the throwaway the
  script brings up by default) -- expected: non-zero executed checks, all passing.

**Mutations (Rule 19) -- one per acceptance group:**

- Concurrency: drop `AND RowVersion = ?` from `GuardedSaveIfCurrent` -> the two-writer refusal test in
  `Test/State` goes red. The second writer is the same process: establish version 1, hold that
  snapshot, call `SetGuarded` again to reach version 2, then save the held snapshot with
  `pExpectedVersion` 1.
- Verification write: make `GuardedSetVerification` ignore `pExpectedVersion` -> the mid-call-move
  test in `Test/AgentConnection` goes red.
- Secret lifecycle: make `ClearOwnedCredential` ignore the sibling query -> the sibling-keeps-its-key
  test goes red; make `HandleDelete` skip the clear -> the orphan-key test goes red
  (`Test/CredentialFixture.Exists` after a delete).
- Rung predicate: make `CredentialsRungAvailable` answer 1 unconditionally -> `Test/Secret` :110's
  legs go red.
- Transient credential: make `pTransient` always 0 -> the definition-stays-enabled test goes red.
- Egress: delete the `HostNameToAddrMulti` branch from `Addresses` -> the two-record worst-kind test
  goes red (it must run through a probe that overrides `MultiLookup` only, so the real `Addresses`
  body executes).
- `HandleStoreCredential` arms: let the `$$$ISERR(tClearSC)` branch fall through -> the arm (a) test
  goes red; make the probe's second `OpenDefinition` succeed -> the arm (b) test goes red. Arm (a) is
  driven through the existing `SecretClass()` seam by a probe whose `Store` deletes the row on its way
  out, so no production seam is added.
- Guards: restore `assert.equal(await filterToSubset(...), 1, ...)` in a client-lint fixture -> the
  new rule's test goes red; remove `Install("")` from `DESTRUCTIVE_TEST_RE` -> the new
  `test_check_objectscript` case goes red; delete a required heading from a fixture spec -> the new
  prose check goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: (none)

Planning only; halt after planning was directed, so nothing was implemented and no ledger entry was
closed. Eleven of the twelve are planned as fixes and DW-346 is planned terminal; the mapping from
entry to task is under Tasks & Acceptance and the mutation per acceptance group is under Verification.
Three decisions were taken here rather than left open: DW-343 amends `Credential()`'s contract with an
`Output` boolean that carries no text; DW-396's pattern widening and DW-402's arming are settled
together under one new `OCUPILOT_ALLOW_PRODUCTION_INSTALL`; the concurrency fix is a conditional write
at `Kernel/State/Base`'s single save seam, pinned by two writers in one process. Verified by probe on
`ocupilot` HSCUSTOM rather than recalled: `IsEnsembleNamespace()` and `$System.License.GetFeature(1)`
both read 1, which is what lets DW-350 narrow the rung predicate without switching the rung off.
`bash scripts/lint-docs.sh`'s two checkers were run against this file directly and report no issues.
The spec exceeds the template's token budget, so `oversized` is set: twelve root causes is the story.
