---
title: 'Epic 3 deferred cleanup'
type: 'bugfix'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings:
  - multiple-goals
  - oversized
deferred: []
---

<intent-contract>

## Intent

**Problem:** At Epic 3's merge gate the owner made four decisions about credentials and egress. None of them is implemented yet, and eight related gaps are still open. Today a stored key can travel to an endpoint named in a request body or through a proxy nobody judged. A store can overwrite another production's credential entry, and a store without the resource it needs answers an opaque 500. A credential store that cannot be read disables working definitions. Several configuration writes change or remove things their change record never names. The turn (Story 4.1) is the first code that sends a stored key on every call, so all of this has to close first.

**Approach:** Implement the four decisions (DW-337, DW-342, DW-349, DW-357) exactly as recorded. Make an unreadable credential store its own failure, one that leaves the definition enabled. Add an `effects` member to the change record so a write can name what it disabled or removed. Read back the audit row of every configuration write verb. A least-privileged principal on the throwaway proves the one behavior that `%All` hides.

## Boundaries & Constraints

**Always:**

- A key moves from a body member to the adapter's property and never passes through a local. It never appears in a status, a log line, a change record or an answer (AD-35, AD-48).
- Refusals use the existing envelopes. A credential-store refusal is a 422 `AGENT.VALIDATION` violation on `apiKey`, and its sentence is written once in `Api/Error.cls` (AD-39). A call failure is a `PROVIDER.*` fault.
- Audit emission never fails the write it records (AD-15).
- The credential reference stays redacted in records. `effects` values are ids and outcome words, never a reference or a value.
- SQL binds every value, and a case-sensitive match uses `%EXACT`.
- Write tests on the throwaway, using a real principal wherever `%All` would hide the behavior (AD-29's method: read the checks, then add whatever the instance still refuses).

**Never:**

- Grant `%Ens_Credentials` (or anything else) at install time.
- Special-case an on-host proxy.
- Read `^Ens.SecondaryData` directly (AD-7).
- Change the client. The form's Test connection posts `{}` and renders server reasons verbatim.
- Move `SCHEMAVERSION` or add a stored property.
- Run an armed or principal-creating class on the live `ocupilot` instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-342 reference only | Create/update a `creds` definition naming an entry OcuPilot did not create | 201/200. The entry's password is unchanged, and `CredentialCreated` reads 0 | No error expected |
| DW-342 store refused | `POST /:id/credential` where the entry exists and no definition naming it exactly carries `CredentialCreated` | 422 violation `AGENT.CREDENTIAL.NOTOWNED` on `apiKey`, with a sentence telling the operator to choose an unused reference or manage the entry where it was created. Entry, row flags and siblings are unchanged | Store refuses before any write |
| DW-342 owned overwrite | Same, but this definition or a sibling carries the mark | 200 `{"stored":true}` | No error expected |
| DW-349 no resource | Stripped principal (OcuPilotAdmin:USE, no `%Ens_Credentials:WRITE`) stores a well-formed key | 422 violation `AGENT.CREDENTIAL.NOPRIVILEGE` whose reason names `%Ens_Credentials:WRITE`. No entry is written, not a 500 | Order: REQUIRED, ENVUNWRITABLE, RUNGUNAVAILABLE, NOPRIVILEGE, KEYSHAPE, then the store's NOTOWNED |
| DW-357 stored endpoint | `POST /:id/test` with `{}` | As today. Answer carries `keySource:"stored"`, and verification is recorded as today | As today |
| DW-357 body endpoint | Body `endpointUrl` differs from the stored effective endpoint (empty = the provider row's default), no `apiKey` | Call proceeds with no key header. Answer or fault `detail` carries `keySource:"none"` and `testedAsStored:false` | Provider refusal is the usual `PROVIDER.REFUSED` |
| DW-357 body key | Body carries a non-empty string `apiKey` | That key is sent (shape-gated), `keySource:"body"`, never recorded as verified | `PROVIDER.KEYSHAPE` as today |
| DW-397 faulted unstored test | Not-as-stored test whose call faults | One `test` SecurityChange record, with `effects.keySource` and `effects.faultCode` | Emission swallowed |
| DW-337 proxy | Stored `ProxyServer` resolves to loopback, link-local, the instance, or nothing | `PROVIDER.EGRESS`, reason naming the proxy, no socket. The proxy is judged with the definition's own marked-local and allows-local inputs | Kind goes to the log |
| DW-337 tunnel | Permitted proxy, https endpoint, stored `ProxyTunnel` 0 | Request carries `ProxyTunnel` 1. Plain-http endpoint keeps the stored value | No error expected |
| DW-410/424 rung (Integration: consumer `ProviderPort.Invoke`, Story 4.1's entry) | Stored `creds` definition. Rung predicate answers 0, or raises inside its own Try | Fault `PROVIDER.CREDENTIALSTORE` (503), reason naming the reference. Row still reads Enabled 1 / Verified as before | Reason to the log |
| Absent entry | Rung reachable, no such entry | `PROVIDER.CREDENTIAL`, definition disabled (unchanged) | As today |
| DW-409 sweep | Store under a reference two siblings share | Posted definition's `credential` record carries `effects.disabledSiblings`, the ids actually cleared | Failed clears are not listed |
| DW-411/428 delete or repoint | Owned entry; outcomes: removed / siblings remain / not owned / already absent / rung unreachable / store refused | Record carries `effects.credentialEntry` = `removed`/`kept`/`notOwned`/`absent`/`unreachable`/`failed`. On `kept` from an owner, the mark moves to the lowest-id surviving sibling | Never fails the write |
| DW-408 case | Definitions naming `ProbeCred` and `probecred` | Not siblings: a store through one does not clear the other, and neither counts as a surviving definition of the other's entry. The test first shows the vendor holds two distinct entries | No error expected |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Definitions.cls` -- `HandleStoreCredential` :512 (sweep :575-619), `HandleTest` :646, `ConnectionOutcome` :728 (fault return :763 above both records), `CredentialRefusal` :868, `ClearOwnedCredential` :963, `LogChange` :1252, `ClassifyChange` :1273 (the `default` verb is config today).
- `src/OcuPilot/Kernel/Secret/Ladder.cls` -- `CredentialsRungAvailable` :110 (Catch answers 0), `Clear` :135 (OK on unavailable or absent), `Credential` :173 (unavailable, non-transient :178), `Store` :221 (opens any existing entry :239).
- `src/OcuPilot/Kernel/Provider/Base.cls` -- `Invoke` :102 resolves onto `ApiKey` :117, faults CREDENTIAL :120. `HttpFor` :375 and `ReasonFor` :389 are the one home of provider sentences. `NewRequest` :237 passes the proxy settings through.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` :83 -- `ApplyAuth` writes the key header unconditionally.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Dispatch` :199 judges only the endpoint (:229). It resolves settings at :238. `FlagUnresolvedCredential` :127 disables on CREDENTIAL unless the call was transient.
- `src/OcuPilot/Kernel/Egress.cls` :121 `IsPermitted(url, markedLocal, allowsLocal, .kind)`. `HostOf` accepts a bare host.
- `src/OcuPilot/Kernel/State/Agent.cls` -- `GuardedIdsByCredentialName` :360 (folds case, and its comment is wrong), `GuardedMarkCredentialCreated` :311, `GuardedClearVerification` :244.
- `src/OcuPilot/Kernel/Audit/Event.cls` :131 `Record` payload (actor, target, verb, securityChange, changes). `Kernel/Audit/Log.cls` :53/:63 redacts keys ending `credential` and the exact name `credentialname`.
- `src/OcuPilot/Api/Error.cls` -- `AGENTCREDENTIAL*` :460-482, `ReasonForViolation` :594, `ViolationCodes` :629, `PROVIDER*` :194-242.
- Vendor, read-only: `irislib/%SYS/Ensemble.cls` :517-532 (`SecondarySet` requires `%Ens_Credentials:W`, skipped under `%All`). `irislib/Ens/Config/Credentials.cls` (IdKey `SystemName`; `GetCredentialsObj` resolves the case before `%OpenId`).
- Tests to change: `Test/AgentCredential.cls` :378 `TestAStoreOverAnOperatorsOwnEntryDoesNotClaimIt` (now a refusal). `Test/Secret.cls` :217 (second store must declare ownership). `Test/ProviderPort.cls` :227 (proxy `proxy.probe.invalid` is now unresolvable, so use a TEST-NET literal) and :425 (expect the new code). `Test/AgentConnection.cls` :183/:590 (exact answer key list gains `keySource`) and `Outcome` :135 (forwards the body). `Test/AgentViolation.cls` :47 (count 27 -> 29). `Test/SecretDeletingStore.cls`, `SecretProbe.cls`, `SecretAbsentRung.cls` (Store signature).
- Patterns: `Test/AgentWireSecurity.cls` :59-156 (armed principal, HTTP as that user). `Test/AuditRecord.cls` (`RowFor`, armed install). `Test/DefinitionsProbe.cls` (secret, port and log seams). `Test/ProviderStub.cls` (`Recorded`, `HeaderNames`). `Test/SecretNotInterop.cls` (override `ENSEMBLEMGRCLASS`). `Test/CredentialFixture.cls`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Api/Error.cls` -- DW-342, DW-349, DW-410.
  - Add `AGENT.CREDENTIAL.NOTOWNED` ("OcuPilot did not create this credential entry, so it will not overwrite it. Choose an unused reference, or change the entry where it was created.") and `AGENT.CREDENTIAL.NOPRIVILEGE` ("Storing a key needs %Ens_Credentials:WRITE, which this account does not hold. Ask an administrator to grant it."). Each gets its `ReasonForViolation` arm and its `ViolationCodes` entry.
  - Add `PROVIDER.CREDENTIALSTORE`. Its sentence ("The credential store this definition's reference lives in could not be read; the definition was left enabled") and its 503 go in `Base.ReasonFor`/`HttpFor`.
- `src/OcuPilot/Kernel/Secret/Ladder.cls` -- `Credential` reports an unavailable rung as transient. `Store` takes a may-overwrite argument that defaults to refusing, and reports an existing entry it declined to open, having written nothing. `Clear` reports its outcome (removed/absent/unreachable/failed). Correct the three doc comments -- DW-342, DW-410, DW-411, DW-424.
- `src/OcuPilot/Kernel/State/Agent.cls` -- `%EXACT` in the sibling query, with a corrected comment. Add a guarded "some definition naming this reference exactly carries the mark" query -- DW-408, DW-342, DW-428.
- `src/OcuPilot/Kernel/Audit/Event.cls` -- optional `effects` object on `Record`'s payload, present only when supplied and redacted with the rest -- DW-409, DW-411, DW-397.
- `src/OcuPilot/Kernel/Provider/Base.cls`, `Anthropic.cls` -- DW-357, DW-410.
  - Honour a key source on the values: `stored` resolves as today; `body` moves the body member onto `ApiKey`; `none` skips resolution and the shape gate.
  - `ApplyAuth` sends no key header without a key.
  - A transient resolve faults `PROVIDER.CREDENTIALSTORE`.
- `src/OcuPilot/Port/ProviderPort.cls` -- judge the proxy host after resolving settings (refuse `PROVIDER.EGRESS` with the reason "The proxy this instance's provider calls go through resolves to an address OcuPilot will not call"). Force `proxyTunnel` 1 for https. Disable only on `PROVIDER.CREDENTIAL` -- DW-337, DW-410.
- `src/OcuPilot/Api/Definitions.cls`:
  - `CredentialRefusal` adds NOPRIVILEGE (`$System.Security.Check("%Ens_Credentials","WRITE")`). The store passes ownership and renders a declined overwrite as NOTOWNED -- DW-342, DW-349.
  - The sweep's record carries `disabledSiblings` -- DW-409.
  - `ClearOwnedCredential` checks siblings first, moves the mark when the owner leaves, and returns the outcome that delete and update put in `effects.credentialEntry` -- DW-411, DW-428.
  - `HandleTest` passes its body to `ConnectionOutcome`. That method decides `keySource` (a body `apiKey`, otherwise stored only at the stored effective endpoint, otherwise none). It requires `stored` for as-stored and records not-as-stored tests on the faulted path too. `keySource` goes on the answer and on the call fault's `detail` -- DW-357, DW-397.
  - `ClassifyChange` treats `default` as a security change -- DW-404.
- Tests (new classes, each under 500 lines):
  - `Test/CredentialOwnership.cls`, HTTP and in-process, self-cleaning -- DW-342, DW-408, DW-411, DW-428.
  - `Test/ConnectionKey.cls`, in-process through the stub -- DW-357, DW-397.
  - `Test/ProviderProxy.cls` -- DW-337.
  - `Test/AuditVerbs.cls`, armed `OCUPILOT_ALLOW_PRODUCTION_INSTALL`: rows for delete, default, credential, hold and release, plus `disabledSiblings`, `credentialEntry` and the faulted test -- DW-404, DW-409, DW-411, DW-397.
  - `Test/CredentialPrivilege.cls`, armed `OCUPILOT_ALLOW_PRINCIPALS` -- DW-349.
  - Rung legs in `Test/Secret.cls` and `Test/ProviderPort.cls` -- DW-410, DW-424.
  - The test updates listed in the Code Map.

**Acceptance Criteria:**

- Given the four merge-gate decisions, when the suite runs on the throwaway, then each I/O row above tagged DW-337/342/349/357 is observed by a test through the route or port it names, and DW-349's is observed as the stripped principal over HTTP.
- Given the nine configuration write verbs (create, update, delete, default, credential, test, switches, hold, release), when each lands, then a test reads its row back from `%SYS.Audit`. `default` is read back as `SecurityChange`.
- Given a reachable rung whose entry exists, when a definition resolves, then nothing about today's success path changes: no new answer key besides `keySource`, no new record on as-stored paths, and every previously green class stays green.
- Given the armed classes on an unarmed instance, when run, then each refuses by name in `OnBeforeAllTests` and creates nothing.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-7: the migration exception, and the named refusal for the missing resource.
- AD-8: the refusal names the pair.
- AD-9: storage methods spawn and re-enter nothing.
- AD-12/AD-39: envelopes and stable codes.
- AD-15: emission never fails a write.
- AD-21: secrets are write-only.
- AD-29: the least-privileged principal method.
- AD-32: the proxy is configuration.
- AD-35, AD-48: no key in a local, status or log.
- AD-37: bounded deletion of what OcuPilot created.
- AD-42: the egress policy, and a write that decides where data goes is a security change. This is also why `default` becomes a security change: it selects the endpoint and credential a turn uses.

**Decisions made in planning:**

- **DW-410/424 get their own code.** The AC asks for a named reason. A machine code lets 4.1's turn tell "try again" from "reconfigure". One fix in `Credential` serves both entries, and DW-424's test must raise inside the predicate's own Try, through an `ENSEMBLEMGRCLASS` override.
- **DW-409 names the siblings in the posted record's `effects`.** The alternative, one record per sibling, doubles the rows, while the AC asks the change record to name them.
- **The count is nine verbs, not ten.** The ledger's "ten" counts `test`'s two call sites.

**Integration:** no new service. Consumes: Epic 3's `Secret.Ladder`, `ProviderPort`, `Audit.Event`. Consumed-by: 4-1-the-turn-runs-in-a-background-job-and-returns-immediately (resolves through `ProviderPort.Invoke`; relies on CREDENTIALSTORE not disabling and on the proxy judgement).

**Spine (Rule 20, for the lead, not applied here):** DW-337 (the proxy is judged with the endpoint's inputs; https tunnels), DW-342 (a store never overwrites an entry OcuPilot did not create) and DW-357 (a stored key goes only to the stored endpoint) constrain later stories. They belong in AD-42 and AD-37.

## Verification

**Commands (live dev instance `ocupilot`, profile `ocupilot-slot-a`; compile, lint and self-cleaning in-process classes only):**

- `iris_doc_load` with `server: "ocupilot-slot-a"`, `namespace: "HSCUSTOM"`, `path: "/Users/jbrandt/git/OcuPilot/.worktrees/epic-4/src/**/*.cls"`, `compile: true` -- expected: clean.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean, including the destructive-test guard on the two armed classes.
- `iris_execute_tests`, one class per call, each read back from `%UnitTest_Result` before the next: `Test.Secret`, `Test.ProviderPort`, `Test.ProviderProxy`, `Test.ConnectionKey`, `Test.AgentViolation` -- expected: green.
- `Test.AuditVerbs` and `Test.CredentialPrivilege` on the live instance -- expected: refused by name, nothing created.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Commands (slot-A throwaway only; everything HTTP, armed or principal-creating):**

- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 node ui/tools/ci-runner.mjs --container ocupilot-ci` -- expected: every class green, including `AgentCredential`, `AgentConnection`, `CredentialOwnership`, `AuditVerbs`, `AuditRecord` and `CredentialPrivilege`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: non-zero checks, all pass.
- `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, only for an `up` this run made.

**Planned mutations (Rule 19; record the observed red next to each):**

- DW-342: the handler passes may-overwrite unconditionally -> NOTOWNED test red (the operator's entry is overwritten).
- DW-349: NOPRIVILEGE arm removed -> `CredentialPrivilege` sees a 500.
- DW-357: stored resolution regardless of endpoint -> `ConnectionKey` header assertion red.
- DW-337: proxy judgement removed -> `ProviderProxy` loopback leg red.
- DW-410/424: `Credential` unavailable arm non-transient -> both rung legs red.
- DW-408: `%EXACT` dropped -> case test red.
- DW-428: mark move removed -> entry survives the second delete.
- DW-411: `effects.credentialEntry` omitted -> `AuditVerbs` delete leg red.
- DW-409: `disabledSiblings` omitted -> sweep leg red.
- DW-397: faulted-path record removed -> `AuditVerbs` faulted leg red.
- DW-404: `default` classification reverted -> `AuditVerbs` default leg red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned; halted after planning as instructed. All twelve inbox entries are addressed (none declined).
