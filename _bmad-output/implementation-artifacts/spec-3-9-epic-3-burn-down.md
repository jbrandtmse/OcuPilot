---
title: 'Epic 3 burn-down'
type: 'bugfix'
created: '2026-09-16'
status: 'done'
baseline_revision: 'd8999c814470be95aec9ca005e32e135cde89bd7'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings:
  - oversized
deferred:
  - summary: >-
      Four writes to OcuPilot's own state still go through the unconditional GuardedSave, so the
      Conventions row's "every write is conditional on the row version" is not literally true.
    evidence: |-
      Kernel/State/Agent.MarkRow edits DefaultMark and UpdatedAt on an existing row without raising
      RowVersion, so a definition save that read before a concurrent SetDefaultGuarded still matches
      and writes the stale marker back. GuardedCreate, State/Hold and State/WebApp are the other
      three; the first is a create and has nothing to be stale against.
    location: >-
      src/OcuPilot/Kernel/State/Agent.cls:618
    severity: medium
  - summary: >-
      The sibling query folds case and the credential store does not, so two references differing
      only in case are siblings to OcuPilot and different entries to the vendor.
    evidence: |-
      GuardedIdsByCredentialName runs SQL, which compares case-insensitively by default;
      Ens.Config.Credentials keys on SystemName as an IdKey, which %ExistsId, %OpenId and %DeleteId
      match exactly. HandleUpdate's '= comparison on the reference is exact and feeds that query, so
      a case-only rename can delete the entry the definition still points at.
    location: >-
      src/OcuPilot/Kernel/State/Agent.cls (GuardedIdsByCredentialName)
    severity: medium
  - summary: >-
      A store under a shared reference disables sibling definitions that the change record never
      names, so a configuration change reaches the instance unaudited.
    evidence: |-
      HandleStoreCredential sweeps every definition naming the reference but LogChange records only
      the posted id. Story 3.8's promise is that every configuration change is audited, and
      TestAStoreSweepsEveryDefinitionNamingTheReference asserts the sibling's flags and nothing
      about its record. A sweep that fails part-way records nothing at all, although the siblings
      cleared before the failure did transition.
    location: >-
      src/OcuPilot/Api/Definitions.cls (HandleStoreCredential)
    severity: medium
  - summary: >-
      An unreachable credential rung is reported as an absence, so the narrowed predicate disables
      every creds definition on a namespace that is not interoperability-enabled.
    evidence: |-
      Credential() leaves pTransient 0 when CredentialsRungAvailable() is false, and
      ProviderPort.FlagUnresolvedCredential clears verification on an absence. DW-350 narrowed that
      predicate, so the population of namespaces answering "unavailable" grew in the same change.
      "This namespace cannot reach the store" says nothing about whether the reference names an
      entry, which is the distinction DW-343 exists to draw.
    location: >-
      src/OcuPilot/Kernel/Secret/Ladder.cls (Credential)
    severity: medium
  - summary: >-
      Ladder.Clear answers OK when the rung is unavailable and ClearOwnedCredential logs only on an
      error, so a delete that removed nothing leaves no trace anywhere.
    evidence: |-
      Clear returns $$$OK for an unreachable rung and for an entry this instance does not hold, and
      the caller's only log line is on the error branch. "A stored key does not outlive the
      definition that named it" can therefore fail silently.
    location: >-
      src/OcuPilot/Kernel/Secret/Ladder.cls (Clear)
    severity: medium
  - summary: >-
      GuardedSaveIfCurrent leaves the in-memory RowVersion raised after a rolled-back save, so a
      caller retrying with the same object is refused permanently.
    evidence: |-
      pObject.RowVersion is set to tNext before %Save(); a failed save rolls the row back to
      pExpected while the object keeps tNext, and GuardedUpdate derives its expectation from
      +pObject.RowVersion.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls (GuardedSaveIfCurrent)
    severity: medium
  - summary: >-
      Addresses' single-form HostNameToAddr fallback sits outside the new MultiLookup seam, so a
      real resolver answer is unioned into the address set a probe supplies.
    evidence: |-
      Narrowing the seam to MultiLookup left the two HostNameToAddr calls unconditional, so an
      NXDOMAIN hijack or a search-domain wildcard can add an address and flip worst-kind-wins. The
      new structural test pins where the seam sits, not that the fallback contributes nothing.
    location: >-
      src/OcuPilot/Kernel/Egress.cls (Addresses)
    severity: medium
  - summary: >-
      The repoint half of AD-37's bounded deletion has no test in either direction.
    evidence: |-
      No test PUTs credentialName after a store, so neither ClearOwnedCredential's call from
      HandleUpdate nor the CredentialCreated reset in GuardedUpdate is driven. Dropping the reset
      would let a definition repointed at an operator's own entry claim ownership of it, which is
      the harm the ownership half exists to prevent.
    location: >-
      src/OcuPilot/Test/AgentCredential.cls
    severity: medium
  - summary: >-
      Api/Definitions.HandleUpdate's own STATE.CONFLICT branch is reached by no test.
    evidence: |-
      RenderConflict has two producers and only the Switches one is driven; the MergeBody seam that
      made that 409 observable has no counterpart on the definition path, where the read and the
      save are adjacent in one request.
    location: >-
      src/OcuPilot/Api/Definitions.cls (HandleUpdate)
    severity: medium
  - summary: >-
      scripts/check-prose.py has no test harness, so its new third check can stop checking with
      every gate green.
    evidence: |-
      check-objectscript.py has test_check_objectscript.py and client-lint.mjs has
      client-lint.test.mjs; the prose checker has neither, and every document in the set passes
      today, so making unpaired_backticks return [] leaves lint-docs.sh clean.
    location: >-
      scripts/check-prose.py
    severity: medium
  - summary: >-
      unpaired_backticks uses blank lines as its only block boundary, which is not CommonMark's
      inline context.
    evidence: |-
      Consecutive list items, table rows and headings are separate blocks in CommonMark but one
      block here, so an unpaired run in one item silently pairs with an unpaired run in the next.
      Backslash-escaped backticks are counted as delimiters too.
    location: >-
      scripts/check-prose.py (unpaired_backticks)
    severity: medium
  - summary: >-
      The British-spelling list holds base forms only, so the sweep left repaired specs internally
      inconsistent.
    evidence: |-
      behavioural, behaviours, colours, coloured, normalised and canonicalise all pass the \b-anchored
      pattern. spec-1-1 now reads "demonstrated behaviourally ... the framework behavior are real"
      in one sentence, and spec-1-10 carries "three disc colours with no word-to-color mapping".
    location: >-
      scripts/check-prose.py (BRITISH)
    severity: medium
  - summary: >-
      check_destructive_test_guard accepts any ARMINGVARIABLE, so a class running the production
      install may arm on a variable named for a narrower effect and pass.
    evidence: |-
      ARMING_GUARD_RE matches ..#ARMINGVARIABLE without checking which variable it names. Seven
      classes that run the production install are armed by OCUPILOT_ALLOW_PRINCIPALS or
      OCUPILOT_ALLOW_AUDIT_EVENTS today; they are protected, but the rule would not notice a new one
      choosing the wrong door.
    location: >-
      scripts/check-objectscript.py:1111
    severity: medium
  - summary: >-
      DW-350's license condition has no seam and is not falsified by any test.
    evidence: |-
      OcuPilot.Test.SecretNotInterop falsifies the IsEnsembleNamespace condition and
      SecretAbsentRung the compiled-class one; $System.License.GetFeature(1) reads 1 on every
      instance the suite runs on and no probe can change it, so deleting that condition reddens
      nothing.
    location: >-
      src/OcuPilot/Kernel/Secret/Ladder.cls (CredentialsRungAvailable)
    severity: medium
  - summary: >-
      Three matrix error-handling shapes are implemented and driven by no test.
    evidence: |-
      A vendor %DeleteId that refuses (ClearOwnedCredential's log branches), a sibling clear that
      fails mid-sweep (the 500 that records no transition), and %OpenId answering a non-object --
      the transient leg is driven through the rung predicate raising instead. Each would need a
      seam the intent's Never list refused, which is why they are recorded rather than patched.
    location: >-
      src/OcuPilot/Api/Definitions.cls, src/OcuPilot/Kernel/Secret/Ladder.cls
    severity: medium
  - summary: >-
      Test/Dispatch seeds the request body through %CSP.Request.InsertMimeData, which the vendor
      marks Final and Internal.
    evidence: |-
      Kernel/Utils.ReadRequestBody already falls back to %request.Content, which is public. Neither
      the harness's doc comment nor the spec notes the internal dependency.
    location: >-
      src/OcuPilot/Test/Dispatch.cls
    severity: low
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

**Mutations added by the review pass** (Rule 19 -- each applied, observed red, reverted):

- Rung predicate, the conditions DW-350 actually added: delete the `IsEnsembleNamespace` condition
  from `CredentialsRungAvailable` -> `Test/Secret`'s `OcuPilot.Test.SecretNotInterop` legs go red.
  The line above reddens only the absent-class condition, which the predicate already had. The
  license condition has no seam and is not falsified; it is recorded under `deferred`.
- Conflict copy on the screen: drop `if (this.store.conflicted())` from `switches.page.ts` and
  `definition-form.page.ts` -> the two save tests go red; drop the `STATE_CONFLICT_CODE` branch from
  `absorbTestRefusal` -> the Test-connection test goes red.
- The production-install guard, by its effect rather than by its literal: remove `OnBeforeAllTests`
  from `Test/DemoOptIn` -> `check-objectscript.py` names that file and line; remove the
  `InstallerProbe.StartPath` alternative from `DESTRUCTIVE_TEST_RE` -> the new harness case goes red.
- Filter-assertion rule: remove the bound-name loop from `checkFilterAssertions` -> the const-form
  test goes red; widen the leg regex back to the old form -> the `bytesRead` test goes red.
- Line references: restore the narrow `strings.test.mjs` pattern -> the reference-count assertion
  goes red, naming the key the pattern cannot reach.
- The spec checker, on this spec: this finalize pass split the file on the string
  `## Auto Run Result`, which `## Tasks & Acceptance` also carries inline, and so deleted
  `## Design Notes`, `## Verification` and the rest of the task list -- DW-384's own failure, on the
  story that fixes it. `check-prose.py` named both missing headings and the backtick run the cut
  left unpaired, which is the red this story's third check exists to produce.

## Auto Run Result

Status: done
Blocking condition: (none)

**Implemented.** Eleven of the twelve chartered entries are fixed with a demonstrated mutation;
DW-346 is terminal, its reason recorded on the entry and no code changed. The four secret entries
collapse onto one sibling query and one ownership mark, the two concurrency entries onto one
conditional write at `Kernel/State/Base`'s single save seam, and the three gates each gained the
check that would have caught their own incident. This story closes no ledger entry: the lead
adjudicates at the gate.

**What changed.** `Kernel/State/Base` gains `RowVersion` and `GuardedSaveIfCurrent` -- one
transaction, a conditional `UPDATE` with bound values and a table name read from the class
dictionary, `%ROWCOUNT` 0 rolling back to a named refusal -- plus `IsStaleSave`. `State/Egress`,
`State/Switch` and `State/Agent` save through it; `Api/Switches` and `Api/Definitions` render the
refusal 409 `STATE.CONFLICT`; `ConnectionOutcome` carries the version across the provider call.
`Secret/Ladder`'s rung predicate becomes the three conditions Story 3.3's AC named, `Store` reports
whether it created the entry, `Clear` removes one, and `Resolve`/`Credential` tell a store that
failed from a reference that names nothing -- which is what stops `ProviderPort` disabling a working
definition. `Agent.CredentialCreated` and `GuardedIdsByCredentialName` back one
`ClearOwnedCredential`, called from `HandleDelete` and from `HandleUpdate` on a repoint.
`Kernel/Egress.MultiLookup` narrows the probe seam so the shipped `Addresses` body runs under test.
The destructive-test pattern gains the audit-event calls, the role delete, the production install and
the suite's own `InstallerProbe.StartPath` route into it; eleven classes are armed under a new
`OCUPILOT_ALLOW_PRODUCTION_INSTALL`. `check-prose.py` takes the 42 implementation specs into its
document set and gains a spec-structure check; `client-lint.mjs` gains a sixth rule family. The
published conflict sentence reaches `strings.ts` and both agent screens.

**The prose sweep (DW-384), reported rather than narrowed.** Adding the implementation specs put 42
previously unlinted documents in front of both checkers. The residue was **205** British spellings
across 35 files and **319** markdownlint findings (255 MD032, 35 MD036, 23 MD022, 6 MD031), plus two
genuinely unpaired backtick runs. 284 structural findings were repaired by `--fix`, the 35 bold-only
pseudo-headings were made real `###` headings, and the spellings and backticks by hand. No file was
exempted and no glob was narrowed. `lint-docs.sh` now reads 61 documents and is clean.

**Verified.** `check-objectscript.py` clean over 289 files / 18 rules; `test_check_objectscript.py`
94 passing; `lint-docs.sh` clean over 61 documents; whole-tree `iris_doc_load` with `flags: "cku"`
on `ocupilot-iris` compiled 289 of 289; `ui: npm run build` (six prebuild checkers, client-lint over
6 rule families) and `npm test` green at 792 `node --test` and 382 component tests, `strings.test.mjs`
at 247 literals / 262 keys; `node ui/tools/ci-runner.mjs --container ocupilot-ci` -- 83 classes, 816
tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign runs, with each of the twelve new methods
read back from `%UnitTest_Result` by name at status 1; `smoke.sh --container ocupilot-ci` 19 executed,
19 passed, 2 pending. The arming refusal was measured on the live unarmed `ocupilot` for nine of the
eleven classes (each naming the variable and its own class, installing nothing); `Static` and
`DemoOptIn` install inside `OnBeforeAllTests` after the guard, so their refusal is left to the static
rule rather than measured where a broken guard would install.

**Review.** Four layers reported 68 findings. Forty-six carry their own row in the triage log below;
the remaining twenty-two -- lows restating a row above, or observations about the wording of one doc
comment -- share its final row rather than repeating it twenty-two times. Eleven entries were patched
(one high, eight medium, two low), nineteen deferred to `deferred` in this file's front matter, and
seventeen rejected on their refutation or as lows whose fix is larger than the defect. The high was
`Api/Switches.HandleUpdate` reading the row version *after* the values the merge is built on, which
left the window the story exists to close open on its own integration path; the version is now read
first, and the comment that claimed otherwise is replaced rather than appended to.

**Residual risk.** Three shapes the diff implements and no test drives: a vendor `%DeleteId` that
refuses, a sibling clear that fails mid-sweep, and `%OpenId` answering a non-object (the transient
leg is driven through the rung predicate instead). `MarkRow`, `GuardedCreate`, `State/Hold` and
`State/WebApp` still write through the unconditional `GuardedSave`, so the Conventions row's "every
write" is not yet literally true. Each is in `deferred` below.

Follow-up review recommended: **false**. The one patched high was a statement reorder inside a method
whose behavior the suite already covers, and the two patched mediums that changed behavior each
gained a test whose red was observed.

## Review Triage Log

### 2026-09-16 -- Review pass

- verdicts: 68 findings -- high 1, medium 23, low 33, false 8, maybe-false 3 (47 rows; the last row
  stands for 22 lows, named there rather than repeated)
- findings:
  - `[high]` `[patch]` `Api/Switches.HandleUpdate` reads the row version after `Resolve` -- a writer landing between the two leaves a version that still matches while the merge carries superseded values; patched by reading the version first, and the comment claiming the opposite replaced.
  - `[medium]` `[patch]` `ConnectionOutcome` discarded `GuardedVersion`'s `%Status` -- a failed read left `""`, which `GuardedSetVerification` treats as no expectation; patched to refuse before the provider call.
  - `[medium]` `[patch]` A Test-connection `STATE.CONFLICT` rendered the server's reason on the failure line ("the save was refused" where nobody saved); patched in `absorbTestRefusal` before the reason fallback, with a component test whose red was observed.
  - `[medium]` `[patch]` `Test/DemoOptIn` runs the production install through `InstallerProbe.StartPath` and was unarmed and invisible to the widened pattern -- the eleventh class of the ten DW-402 named; armed, the helper route added to `DESTRUCTIVE_TEST_RE`, harness case added.
  - `[medium]` `[patch]` `scripts/ci-throwaway.sh` claimed "the ten test classes that run OcuPilot's PRODUCTION install" -- eighteen do; corrected at its origin, naming the seven already armed under the two older variables.
  - `[medium]` `[patch]` `EXACT_FILTER_COUNT_RE` did not see the const-bound form that `ssl.browser-spec.mjs` was itself refactored into; the rule now follows the binding.
  - `[medium]` `[patch]` DW-350's two new conditions could not fail on any namespace the suite runs on -- `OcuPilot.Test.SecretNotInterop` now falsifies the interoperability one, with the red observed.
  - `[medium]` `[patch]` `strings.test.mjs`'s line-reference regex required the value on the key's own line, so every prettier-wrapped literal -- including this story's -- went unchecked; widened, and its floor replaced by an exact count.
  - `[low]` `[patch]` `FILTER_LEG_COMPARISON_RE` matched any identifier containing "by" (`bytesRead < bytesTotal`); narrowed to `by[A-Z]\w*`.
  - `[low]` `[patch]` `check_spec_structure` collected `## ` lines without skipping fenced blocks, so a spec quoting the template's headings could satisfy the order check; the scan now skips fences.
  - `[medium]` `[defer]` `MarkRow` and `GuardedCreate` (and `State/Hold`, `State/WebApp`) still write through the unconditional `GuardedSave`, so a concurrent marker move is not seen by the conditional write.
  - `[medium]` `[defer]` `GuardedIdsByCredentialName` matches case-insensitively (SQL) while `Ens.Config.Credentials` keys exactly, so two references differing only in case are siblings to the query and different entries to the store.
  - `[medium]` `[defer]` `HandleUpdate`'s exact `'=` reference comparison feeds that case-folding query -- same root cause as the row above, and the direction that can delete an entry the definition still names.
  - `[medium]` `[defer]` The sibling sweep disables definitions the change record never names, so a configuration change reaches the instance with no audited row (Story 3.8's promise).
  - `[medium]` `[defer]` A sweep that fails part-way records nothing although the siblings cleared before it did transition; the comment states the opposite risk.
  - `[medium]` `[defer]` `Credential`/`Resolve` report an unreachable rung as an absence, so `FlagUnresolvedCredential` disables every `creds` definition on a namespace the narrowed predicate now refuses.
  - `[medium]` `[defer]` `Ladder.Clear` answers `$$$OK` when the rung is unavailable and `ClearOwnedCredential` logs only on error, so a delete that removed nothing leaves no trace.
  - `[medium]` `[defer]` `GuardedSaveIfCurrent` leaves `pObject.RowVersion` bumped after a rolled-back save, so a caller retrying with the same object is refused permanently.
  - `[medium]` `[defer]` `Addresses`' single-form `HostNameToAddr` fallback is outside the new seam, so a real resolver answer is unioned into a probe's address set.
  - `[medium]` `[defer]` The repoint path -- `ClearOwnedCredential` from `HandleUpdate` and the `CredentialCreated` reset in `GuardedUpdate` -- has no test; no class PUTs `credentialName` after a store.
  - `[medium]` `[defer]` `check-prose.py` has no test harness at all, so its third check can stop checking with every gate green.
  - `[medium]` `[defer]` `unpaired_backticks` uses blank lines as its only block boundary, which is not CommonMark's inline context for list items, table cells and headings.
  - `[medium]` `[defer]` The British word list holds base forms only, so `behavioural`, `colours` and `normalised` survive -- two repaired specs now read inconsistently within one sentence.
  - `[medium]` `[defer]` `Api/Definitions.HandleUpdate`'s own `IsStaleSave` branch is reached by no test; the `MergeBody` seam that made the Switches 409 observable has no counterpart there.
  - `[medium]` `[defer]` `check_destructive_test_guard` accepts any `ARMINGVARIABLE`, so a class calling the production install may arm on a variable named for a narrower effect and pass.
  - `[low]` `[defer]` `Test/Dispatch` seeds the request body through `%CSP.Request.InsertMimeData`, which the vendor marks `[ Final, Internal ]`; `%request.Content` is the public path.
  - `[maybe-false]` `[defer]` Two rows in a `SELECT TOP 1` store if two requests both find none and both `%New()` -- the lowest id wins on read, so the later row is invisible rather than wrong; what would settle it is whether any caller depends on the row it wrote being the one that answers.
  - `[false]` `[reject]` "`Egress.SetGuarded`'s doc comment says `pExpectedVersion` left `""` is every production call site when there are zero" -- the empty set is what the sentence describes, and no handler calls it.
  - `[false]` `[reject]` "`Test/DemoOptIn` calls `Install("")` unguarded" as originally filed against the literal -- the only occurrence of that literal is a doc comment, which `iter_non_comment_lines` correctly skips; the real route is `InstallerProbe.StartPath`, patched above.
  - `[low]` `[reject]` Ten copies of the arming guard and its message -- the checker requires the comparison in each method's own body, so a shared helper would not satisfy it and a per-class literal is what the rule reads.
  - `[low]` `[reject]` `Test/Static` lacks the explanatory doc comment its nine siblings carry -- cosmetic, and its class header already states the guard.
  - `[low]` `[reject]` `check-prose.py`'s glob leaves `deferred-work.md`, the decision sheets, the epic contexts and the cycle logs unlinted -- DW-384's root cause is a story spec losing sections, and specs are what the glob covers.
  - `[low]` `[reject]` The ten guard messages are ~330 characters each -- they name the effect, the variable and the remedy, which is what a person hitting the refusal needs.
  - `[low]` `[reject]` `IsStaleSave` matches on substring rather than an error code -- reachable only by a status that quotes the sentence, which nothing writes.
  - `[low]` `[reject]` `ssl.browser-spec.mjs`'s two replacement assertions restate `filterToSubset`'s own postcondition -- true, and the helper is where the check lives; the assertions document the leg rather than prove it.
  - `[false]` `[reject]` "The conditional write is a no-op at the browser surface, so DW-388 is unfixed" -- the spine's Conventions row scopes the window to within a request and the intent forbids a wire token; the cross-request window is a separate root cause the intent excludes.
  - `[false]` `[reject]` "Matrix row 4 is not satisfied" -- same refutation: the row's "B reads" is the handler's read under the spine row the gate commit added.
  - `[false]` `[reject]` "`Test/SwitchesWire` gained a test that does not cross the wire, contradicting its class header" -- the header describes the class's other five route tests, which still dispatch through the shipped router; the new method says in its own comment why it cannot.
  - `[false]` `[reject]` "`Kernel/Egress.MultiLookup` is a production seam whose only consumer is a test, which the intent forbids" -- the Never bullet names `StateClass()` on `Api/Definitions`, and task 11 directs this extraction by name.
  - `[false]` `[reject]` "`GuardedCreate` creates at version 0 where `Base`'s comment promises 1" -- the comment describes `GuardedSaveIfCurrent`'s own create path; `InitialExpression` 0 and `COALESCE(...) = 0` agree.
  - `[false]` `[reject]` "The `(?:const\s+)?` group in the leg regex is dead" -- true and now removed with the narrowing patch, so it is not a standing finding.
  - `[low]` `[reject]` "Verification used `ci-runner.mjs` rather than one `iris_execute_tests` call per class" -- the runner is the project's own serializer, one class per `spawnSync`, each confirmed in `%UnitTest_Result` before the next, and it reports 0 overlaps and 0 foreign runs.
  - `[low]` `[reject]` "AC3 generalizes from one probe" -- nine of the eleven were measured individually on the live unarmed instance in this pass, which is the population minus the two that install inside the guarded method.
  - `[medium]` `[patch]` The spec's front matter and its `## Auto Run Result` disagreed on status, and the result section had grown well past the template's budget on a spec already flagged `oversized`; both fixed in this finalize.
  - `[maybe-false]` `[defer]` A sibling deleted between the id query and the clear fails the whole store with 500 although every surviving sibling was disabled; what would settle it is whether `GuardedClearVerification` distinguishes "no such row" from a read failure.
  - `[maybe-false]` `[defer]` `ConnectionOutcome` captures the version a few statements after `HandleTest` took the security-field snapshot, so a move inside that gap is judged against stale values; what would settle it is whether validation between the two can observe the row.
  - `[low]` `[reject]` Twenty-two further low observations across the four layers -- wording of individual doc comments, naming of locals, the shape of a message, repeated literals inside test classes, and restatements of rows already above -- each a direct-correction-or-nothing case whose fix is larger than the defect and which no user or developer meets in ordinary use.
