---
title: 'Epic 3 deferred cleanup'
type: 'bugfix'
created: '2026-09-16'
status: 'done'
baseline_revision: '11b79606913713a60ab16debe63eff8b8a4207ec'
baseline_commit: '11b79606913713a60ab16debe63eff8b8a4207ec'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings:
  - multiple-goals
  - oversized
deferred:
  - summary: >-
      AGENT.CREDENTIAL.NOPRIVILEGE checks %Ens_Credentials:WRITE only, so an administrator granted that pair but only read on the install namespace's globals database still gets the opaque 500 from POST /agent/definitions/:id/credential.
    evidence: |-
      AD-29 probe on the slot-A throwaway: a principal holding %Ens_Credentials:W, OcuPilotAdmin:U, %Admin_Operate:U and %DB_HSCUSTOM:R got 500 (vendor status 5002); with %DB_HSCUSTOM:RW the store answered 200 (CredentialPrivilege's permitted leg now grants both). The intent's DW-349 row fixes the checked pair, so extending the refusal and its sentence is a product call.
    location: >-
      src/OcuPilot/Api/Definitions.cls CredentialRefusal
    severity: medium
  - summary: >-
      A configured proxy is applied to every provider call, including a marked-local plain-http endpoint, which is then requested from the proxy host (its own loopback) in cleartext.
    evidence: |-
      Kernel/Provider/Base.cls NewRequest sets ProxyServer/ProxyPort/ProxyHTTPS/ProxyTunnel from State.Egress for every call; ProviderPort.Dispatch now judges the proxy host but never bypasses it for a local endpoint (Test/ProviderProxy.cls plain-http leg records the proxy). Predates this story; unreachable in Release 1 because no shipped route writes the State.Egress row.
    location: >-
      src/OcuPilot/Kernel/Provider/Base.cls NewRequest
    severity: medium
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

**Review patches (pass 1; triage rows under `## Review Triage Log`):**

- RP1 `Port/ProviderPort.cls` `Dispatch` -- for an https endpoint through a permitted proxy, force `proxyHttps` 1 as well as `proxyTunnel` 1. The vendor decides TLS inside a CONNECT tunnel from `ProxyHTTPS` alone (`irislib/%Net/HttpRequest.cls` :1261), so tunnel 1 with a stored `proxyHttps` 0 sends the key in cleartext. A plain-http endpoint keeps both stored values. `Test/ProviderProxy.cls`: the https leg stores `proxyHttps` 0 and asserts both recorded 1; the plain-http leg stores both 1 and asserts both kept.
- RP2 `Port/ProviderPort.cls` `Dispatch` -- bracket a bare IPv6 proxy literal (two or more `:`, no leading `[`) before `IsPermitted`, since `Egress.HostOf` cuts a bare host at its first `:`. Add a `ProviderProxy` leg only if a probe shows this build classifies an IPv6 documentation literal public; otherwise report that.
- RP3 `Api/Definitions.cls` `KeySourceFor` -- `stored` also requires `credType`, `envVarName` and `credentialName` to equal the stored values (AD-42: a stored credential goes only to the stored endpoint); otherwise `none`. `Test/ConnectionKey.cls`: a body changing only `credentialName` answers `none` with no key header; a body changing another security field at the same endpoint answers `stored`, `testedAsStored` 0, row unverified. Correct the stale "drop the comparison" mutation note on `Test/AgentConnection.cls` `TestOnlyASecurityEditStopsTheRowBeingWritten`.
- RP4 `Test/AgentConnection.cls` -- a wire leg through the shipped `HandleTest` posting `{"apiKey": <shaped probe key>}` with the stored reference resolving to nothing: `keySource` `body`, `testedAsStored` false, row unverified.
- RP5 `Test/CredentialOwnership.cls` -- `GuardedCredentialOwned`'s `%EXACT`: A owns `OcuPilotProbeCaseCredential`, an operator entry `ocupilotprobecasecredential` exists, B names the lowercase one; B's store answers 422 `NOTOWNED` and the operator's value stays.
- RP6 `Test/CredentialOwnership.cls` `TestTheMarkMovesWhenTheOwnerLeaves` -- assert the repointed former owner reads `CredentialCreated` 0.
- RP7 `Test/AuditVerbs.cls` -- a repoint leg reading the `update` row's `effects.credentialEntry`.
- RP8 `Test/ConnectionKey.cls` -- the answered not-as-stored records carry `"effects":{"keySource":"none"}` (other endpoint) and `"effects":{"keySource":"body"}` (body key).
- RP9 `Test/CredentialPrivilege.cls` -- setup checks the literal `%Ens_Credentials`/`WRITE`, not `Definitions`' parameters. The violation assertion reads the sentence off the response and requires it to name `%Ens_Credentials:WRITE`. Add a leg where the stripped principal posts a wrong-shape key and still gets `NOPRIVILEGE`. Add a permitted leg: grant the role `%Ens_Credentials:W` plus write on the install namespace's globals database, and the store answers 200. Teardown removes the entry.
- RP10 `Test/CredentialOwnership.cls` -- a wrong-shape key posted over a not-owned entry answers `AGENT.KEY.SHAPE`, not `NOTOWNED`.
- RP11 `Test/ProviderProxy.cls` -- replace `$$$AssertTrue(1, "skipped ...")` with an assertion that the instance reports an interface address.
- RP12 `Test/Secret.cls` `TestAStoreDeclinesAnExistingEntryItMayNotOverwrite` -- replace the skip branch with an assertion that the rung is available.
- RP13 `Test/FakeCredentialRow.cls` gains a `%DeleteId` answering an error. `CredentialOwnership`'s `failed` leg drives `Ladder.Clear`'s refused-delete branch through `Test/SecretFakeRung.cls`.
- RP14 `Test/ProviderPortProbe.cls` captures `LogRaw` (still calling the shipped one), so `ProviderProxy` asserts the refused proxy's kind reaches the log and `ProviderPort`'s rung test asserts the reference-naming line does.
- RP15 Doc corrections: the `ConnectionOutcome` comment claims "the call left the instance either way", but a faulted not-as-stored test is recorded whether the fault came before or after the call, and `faultCode` says which. `Test/AuditRecord.cls` :289-293 still says "a call carrying this definition's credential". `Test/AgentConnection.cls` :163 still says "six keys".
- RP16 Rule 19 lines in `## Verification`, each demonstrated. RP1 (drop the `proxyHttps` force), RP3, RP4 (pass `""` for the body), RP5, RP6 (drop `Kernel/State/Agent.cls` :219), RP7, RP8, RP9 (misspell `CREDENTIALSRESOURCE`), RP13 (drop `CLEARFAILED` in the refused-delete branch). AC3: record on the as-stored faulted path, and `ConnectionKey`'s as-stored leg goes red. AC4: remove `AuditVerbs`' arming guard, and `check-objectscript.py` names it (static only, never run on live).

**Acceptance Criteria:**

- Given the four merge-gate decisions, when the suite runs on the throwaway, then each I/O row above tagged DW-337/342/349/357 is observed by a test through the route or port it names, and DW-349's is observed as the stripped principal over HTTP.
- Given the nine configuration write verbs (create, update, delete, default, credential, test, switches, hold, release), when each lands, then a test reads its row back from `%SYS.Audit`. `default` is read back as `SecurityChange`.
- Given a reachable rung whose entry exists, when a definition resolves, then nothing about today's success path changes: no new answer key besides `keySource`, no new record on as-stored paths, and every previously green class stays green.
- Given the armed classes on an unarmed instance, when run, then each refuses by name in `OnBeforeAllTests` and creates nothing.

### Review Findings

Code review 2026-09-16, full-opus tier: 39 rows, 18 entries (high 0, medium 7, low 11), 11 rejected. Dispositions follow Rule 15; ledger ids are named where one was written.

- [x] [Review][Patch] DW-440: NOPRIVILEGE checked `%Ens_Credentials:WRITE` only, so a principal holding it with read on the store's database got a 500 (medium, fix-risk med) [src/OcuPilot/Kernel/Secret/Ladder.cls StoreDatabaseWritable, src/OcuPilot/Api/Definitions.cls CredentialRefusal] -- the refusal now names the database resource the vendor class's globals map to, resolved as the caller (`GetGlobalPermission`, `GetNSInfo`); ledger DW-440 resolved.
- [x] [Review][Patch] Disabling or deleting the marked default moved the marker under a `ConfigChange` row (medium) [src/OcuPilot/Api/Definitions.cls ClassifyChange] -- a change set naming `default` is a security change.
- [x] [Review][Patch] A non-owner leaving could hand the mark on with no test to notice (medium, Rule 19) [src/OcuPilot/Test/CredentialOwnership.cls TestANonOwnerLeavingHandsOnNoMark]
- [x] [Review][Patch] `KeySourceFor`'s `envVarName` comparison was unpinned (medium, Rule 19) [src/OcuPilot/Test/ConnectionKey.cls TestTheStoredKeyGoesOnlyUnderTheStoredReference]
- [x] [Review][Patch] The plain-http proxy leg stored 1/1, the forced value, so it could not fail (medium, Rule 19) [src/OcuPilot/Test/ProviderProxy.cls TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy]
- [x] [Review][Patch] The body-key path was absent from the AD-48 leak proof (medium) [src/OcuPilot/Test/ProviderSecret.cls leg six]
- [x] [Review][Patch] The proxy judgement's allows-local input was unpinned (low) [src/OcuPilot/Test/ProviderProxy.cls TestALoopbackProxyNeedsTheDefinitionsOwnLocalEscape]
- [x] [Review][Patch] `ConnectionOutcome` doc claimed every faulted unstored test is recorded; the version-read 500 is not (low) [src/OcuPilot/Api/Definitions.cls ConnectionOutcome]
- [x] [Review][Patch] Two assertion messages described `ProxyHTTPS` as the proxy leg's encryption (low) [src/OcuPilot/Test/ProviderPort.cls, src/OcuPilot/Test/Provider.cls]
- [x] [Review][Patch] `InvokeDraft` doc still said `maxAttempts` is the only caller key (low) [src/OcuPilot/Port/ProviderPort.cls]
- [x] [Review][Patch] `PROVIDERCREDENTIALSTORE` doc promised "try again"; `PROVIDEREGRESS` doc omitted the proxy (low) [src/OcuPilot/Api/Error.cls]
- [x] [Review][Patch] Stale refusal counts in `AgentCredential` comments (low) [src/OcuPilot/Test/AgentCredential.cls]
- [x] [Review][Patch] `AuditVerbs` default leg doc said "moving" for a verb-only classification (low) [src/OcuPilot/Test/AuditVerbs.cls]
- [x] [Review][Patch] `CredentialOwnership` leg message said the delete raised; the rung check does (low) [src/OcuPilot/Test/CredentialOwnership.cls]
- [x] [Review][Defer] A stored `proxyHttps` 1 makes a marked-local plain-http call through the proxy ask for TLS (medium) [src/OcuPilot/Port/ProviderPort.cls Dispatch] -- deferred: same root cause as DW-441 (the proxy applies to a local endpoint at all); occurrence appended, owner 4-8.
- [x] [Review][Defer] The `PROVIDER.CREDENTIALSTORE` sentence reads "left enabled" on a Test connection of a disabled definition (low) [src/OcuPilot/Kernel/Provider/Base.cls ReasonFor] -- deferred: by-design, the spec fixes the sentence; DW-442.
- [x] [Review][Defer] `AgentConnection`, `ProviderPort` and `AgentCredential` test classes exceed 500 lines and grew (low) -- deferred: wontfix-accepted with reopen_if; DW-443.

**Rejected:**

- low: the ownership move names no survivor in `effects` and bumps its row version (a concurrent test may 409) -- the row did change, 409 is the designed answer, and the entry is still removed with the last definition.
- low: `KeySourceFor` compares effective endpoints while `MatchesStoredSecurityFields` compares raw ones -- no key goes elsewhere, and the client posts `{}`.
- low: CR/LF in a body `apiKey` reaches `SetHeader` raw -- the caller already chooses an egress-judged endpoint and the key; a header cannot change the connected address.
- low: an undeclared `keySource` sends no key -- the only producer is `KeySourceFor`'s three constants, and the doc states it.
- low: a proxy stored with a scheme is refused as unresolvable -- the vendor cannot use that value either, and no shipped route writes it.
- low: DW-357's body-endpoint row and fault `detail` are driven in process, not over the wire -- the body pass-through (RP4) and `detail` rendering (`TestTheShippedHandlerRendersTheProviderTextOverTheWire`) are wire-pinned.
- low: a whitespace-only `apiKey` falls back to the stored key -- it goes only to the stored endpoint, labeled `stored`.
- low: refusal order is pinned on two of five adjacencies -- the unpinned ones order two refusals of the same unwritten store.
- low: `ProviderProxy` deletes the outbound-settings row -- adjudicated in pass 1; live holds none.
- low: new doc comments cite DW ids -- used as requirement labels, as 568 sites already do.
- spec edit: the residual-risk list, the status fields, and the Never-versus-Verification wording -- each fix edits this spec.

## Spec Change Log

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 83 findings — high 1, medium 25, low 46, false 11, maybe-false 0
- findings:
  - Blind hunter:
    - `[high]` `[patch]` An https call through a proxy sends the key in cleartext: the tunnel is forced but `ProxyHTTPS` stays at its stored 0. The vendor negotiates TLS inside a tunnel only on `ProxyHTTPS` (`%Net/HttpRequest.cls` :1261). Fixed by RP1: both flags are forced, and the https leg asserts both.
    - `[medium]` `[defer]` A configured proxy also carries a marked-local plain-http call, which then reaches the proxy host's loopback in cleartext. `Base.NewRequest` applies the proxy to every call; this predates the story.
    - `[low]` `[patch]` A bare IPv6 proxy is judged by the text before its first colon. Fixed by RP2 (bracketed before judgement, with an IPv6 leg).
    - `[medium]` `[patch]` `keySource` `stored` was decided by the endpoint alone, so a body naming another reference got that reference's secret under the stored label. Fixed by RP3: the credential fields must also match, otherwise `none`, with a new `ConnectionKey` leg.
    - `[low]` `[patch]` The `ConnectionOutcome` comment claims the call left the instance, but pre-call refusals are recorded too. Fixed by RP15 (the comment now says `faultCode` tells them apart).
    - `[medium]` `[defer]` NOPRIVILEGE covers `%Ens_Credentials:WRITE` only. A principal holding that but only read on the namespace's globals database still gets a 500 (vendor 5002). The intent's DW-349 row fixes the checked pair; the residual predates the story.
    - `[low]` `[reject]` A delete by an administrator without `%Ens_Credentials:W` orphans the entry, and later stores are refused NOTOWNED. It needs an unprivileged administrator deleting an owning definition, and the refusal's sentence gives the working remedy.
    - `[low]` `[reject]` The mark goes stale when OcuPilot's entry is deleted outside OcuPilot and recreated under the same name. It cannot be detected without an entry identity the vendor does not expose.
    - `[medium]` `[patch]` Dropping the security-field comparison from `tTestedAsStored` reddened nothing, and `AgentConnection`'s mutation note had gone stale. Fixed by RP3 (marked-local leg, note corrected; red at live 2241).
    - `[medium]` `[patch]` `HandleTest` passing its body was untested. Fixed by RP4 (wire leg through the shipped handler).
    - `[low]` `[reject]` The stub's `HeaderNames` skips empty headers, so the `ApplyAuth` guard cannot be falsified. An empty header carries no key, and reading the raw header block would bind the key the stub refuses to hold.
    - `[low]` `[patch]` `Ladder.Clear`'s refused-delete branch was untested. Fixed by RP13 (`FakeCredentialRow.%DeleteId` refuses).
    - `[low]` `[reject]` "Failed sibling clears are not listed" is untested. The branch is a `Continue` beside its comment, and failing one sibling's clear needs a seam no fixture has.
    - `[medium]` `[patch]` The repoint record's `effects.credentialEntry` was never read back. Fixed by RP7.
    - `[medium]` `[patch]` `%EXACT` in `GuardedCredentialOwned` was untested. Fixed by RP5.
    - `[low]` `[reject]` `CredentialPrivilege` leaks its principal when setup fails partway. It is armed for throwaways only, which are discarded, and `AgentWireSecurity` shares the pattern.
    - `[low]` `[patch]` `ProviderProxy` counted a skipped instance leg as a pass. Fixed by RP11.
    - `[low]` `[reject]` `ProviderProxy` deletes the outbound-settings row. This is the fixture discipline `ProviderPort` already has on live, and live holds no such row (reads 0).
    - `[low]` `[patch]` Stale `AuditRecord` comment ("a call carrying this definition's credential"). Fixed by RP15.
    - `[low]` `[patch]` Stale `AgentConnection` comment ("six keys"). Fixed by RP15.
    - `[low]` `[reject]` Body-key refusals are worded as the definition's credential. Only API callers send a body key, and the empty-key branch is unreachable behind `KeySourceFor`.
    - `[low]` `[reject]` The spec is out of step with its status and carries appended narrative. The fix edits this build's spec.
    - `[false]` `[reject]` "No green full sweep of the final tree." The parent's sweep of the reviewed tree read 88 classes, 839 tests, 0 failed.
  - Edge case hunter:
    - `[medium]` `[patch]` Body changes the reference at the stored endpoint (same root cause as the blind hunter's `keySource` row). Fixed by RP3.
    - `[low]` `[reject]` A non-string `apiKey` falls back to the stored key. The answer truthfully says `stored`, and the key still goes only to the stored endpoint.
    - `[low]` `[reject]` Whitespace around a body key. It is the caller's own key on the caller's own request, and the shape gate refuses a leading pad.
    - `[low]` `[patch]` Pre-call refusals are recorded as calls. Fixed by RP15 (doc).
    - `[low]` `[reject]` A failed sibling read answers `failed` for an unowned entry. Reachable only on a failed SQL read of OcuPilot's own table; the entry is untouched and the log says so.
    - `[low]` `[reject]` A failed mark move is recorded as `kept`. Rare (a stale save), and it is logged naming the survivor.
    - `[low]` `[reject]` A failed mark write after the store leads to a later NOTOWNED. Rare, it predates the story, and it is logged.
    - `[low]` `[reject]` Stale mark on a recreated entry (same as the blind hunter's stale-mark row).
    - `[false]` `[reject]` A permanently unreachable rung never disables. The intent's DW-410/424 row specifies exactly this outcome.
    - `[low]` `[reject]` A sibling that was already disabled is still listed. Telling "cleared" from "changed" needs a read before every clear, for a record word.
    - `[medium]` `[defer]` A marked-local http call goes through the proxy (same as the blind hunter's proxy row).
    - `[low]` `[patch]` Bare IPv6 proxy. Fixed by RP2.
    - `[false]` `[reject]` `Secret`'s absent leg goes red where the rung is unreachable. The suite runs only in interop-enabled HSCUSTOM, and the class's other legs already require the rung.
    - `[low]` `[reject]` `CredentialPrivilege` setup leak (same as the blind hunter's row).
    - `[low]` `[reject]` `ProviderProxy` egress-row deletion (same as the blind hunter's row).
  - Verification gap:
    - `[medium]` `[patch]` Body `apiKey` untested through the handler. Fixed by RP4 (red at throwaway 202).
    - `[medium]` `[patch]` `GuardedCredentialOwned` `%EXACT` untested. Fixed by RP5 (red at 203).
    - `[medium]` `[patch]` Repointed owner losing its mark untested. Fixed by RP6 (red at 204).
    - `[medium]` `[patch]` Update-record `effects` never read. Fixed by RP7 (red at 205).
    - `[medium]` `[patch]` Answered not-as-stored `effects.keySource` never read. Fixed by RP8 (red at live 2239).
    - `[medium]` `[patch]` NOPRIVILEGE setup reads the parameter under test, and no permitted case exists. Fixed by RP9 (literal pair, permitted leg; red at 206).
    - `[low]` `[reject]` Failed sibling clears (same as the blind hunter's row).
    - `[low]` `[patch]` Clear's refused-delete branch. Fixed by RP13 (red at 207).
    - `[medium]` `[patch]` The NOPRIVILEGE sentence was compared with itself. Fixed by RP9 (read off the response).
    - `[low]` `[patch]` `AssertTrue(1)` skip in `ProviderProxy`. Fixed by RP11.
    - `[low]` `[patch]` `Secret`'s skip branch could not fail. Fixed by RP12.
    - `[medium]` `[patch]` `CredentialPrivilege` asserted the parameter, not the response (same as the sentence row). Fixed by RP9.
    - `[medium]` `[patch]` `CredentialPrivilege` setup agreed with the parameter (same as the setup row). Fixed by RP9.
    - `[false]` `[reject]` Some AC1 rows carry no mutation. Rule 19 asks one demonstrated mutation per AC, and AC1 carries several.
    - `[false]` `[reject]` Hold and release carry no mutation. AC2 carries the delete, default, credential, faulted-test and repoint lines.
    - `[low]` `[patch]` AC3 had no mutation. RP16 line (live 2240).
    - `[low]` `[patch]` AC4 had no mutation. RP16 line (static `check-objectscript.py`).
    - `[low]` `[patch]` The six-outcome test had no mutation. RP16 line (throwaway 207).
    - `[low]` `[reject]` Epic 3 data can hold orphaned marks. Nothing has been released, and live holds 0 definitions.
    - `[low]` `[patch]` `ConnectionOutcome` comment (same as the blind hunter's comment row). Fixed by RP15.
    - `[low]` `[patch]` `AuditRecord` stale claim (same as the blind hunter's row). Fixed by RP15.
  - Intent alignment:
    - `[medium]` `[defer]` DW-349 covers one of the two checks (same as the blind hunter's NOPRIVILEGE row).
    - `[medium]` `[patch]` NOPRIVILEGE sentence not read off the wire. Fixed by RP9.
    - `[low]` `[patch]` Refusal order untested. Fixed by RP9 (wrong shape without privilege gives NOPRIVILEGE) and RP10 (wrong shape over an unowned entry gives KEYSHAPE).
    - `[medium]` `[patch]` DW-357 rows drove the method, not the route. Fixed by RP4.
    - `[false]` `[reject]` Header names, not values. The body-key leg makes the stored reference resolve to nothing, so only the body key can have been sent.
    - `[medium]` `[patch]` Body naming another reference is labeled `stored`. Fixed by RP3.
    - `[false]` `[reject]` A body key at the stored endpoint writes a security record instead of a verification. The intent says a body key is never recorded as verified.
    - `[low]` `[reject]` Proxy judgement is tested through `InvokeDraft` only. `Dispatch` is the one method both entries call.
    - `[low]` `[patch]` Plain-http "keeps" was tested only with 0. Fixed by RP1 (stores 1s and asserts they are kept).
    - `[low]` `[patch]` Instance-address skip. Fixed by RP11.
    - `[low]` `[reject]` Two EGRESS sentences. The proxy sentence is a `Base` parameter beside `ReasonFor`, in the one provider-sentence class.
    - `[low]` `[reject]` Pre-disabled sibling listed (same as the edge case hunter's row).
    - `[low]` `[reject]` Failed clears untested (same as the blind hunter's row).
    - `[low]` `[reject]` Only `removed` is read back from a record. `EntryEffects` carries `ClearOwnedCredential`'s word unchanged, and the delete and repoint legs read it back.
    - `[medium]` `[patch]` Repoint effects never read. Fixed by RP7.
    - `[low]` `[patch]` The `failed` leg went through a raise, not a refusal. Fixed by RP13.
    - `[low]` `[reject]` The credential record written when the definition cannot be disabled is not read back. It passes the same `tEffects` as the success record, which is read back.
    - `[medium]` `[patch]` Update `effects` (same as the repoint row). Fixed by RP7.
    - `[medium]` `[patch]` Answered `keySource` effects. Fixed by RP8.
    - `[false]` `[reject]` DW-404 sits outside the intent block. It is carried by the ACs and by AD-42's amended text, and no defect was named.
    - `[low]` `[patch]` "Reason to the log" and "Kind goes to the log" were not asserted. Fixed by RP14.
    - `[false]` `[reject]` Non-interop gives 503 forever (same as the edge case hunter's rung row).
    - `[false]` `[reject]` Armed classes were submitted on live. The spec's Verification requires it, to observe the refusal, and no method ran.
    - `[false]` `[reject]` An object reference sits in a local. The body object is held and the key string never is (AD-48).

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

**Mutations (Rule 19), each reverted and reloaded before the next:**

- mutation: `KeySourceFor` answers `stored` when the body has no key -> `Test.ConnectionKey` 3 of 4
  red, including the no-key-header assertion (live 2210); reverted green (2211).
- mutation: proxy judgement removed from `ProviderPort.Dispatch` -> `Test.ProviderProxy`
  `TestAProxyThePolicyRefusesIsNeverCalledThrough` red on all four proxies (live 2212).
- mutation: https `proxyTunnel` override removed -> `TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy`
  red (live 2213); reverted green (2214).
- mutation: `Ladder.Credential`'s unreachable-rung arm sets `pTransient` 0 -> `Test.Secret` rung legs
  red (live 2215) and `Test.ProviderPort`
  `TestACredentialStoreThatCouldNotBeReadLeavesTheDefinitionEnabled` red on the `SecretNotInterop` and
  `SecretRaisingRung` legs (2216); reverted green (2217, 2218).
- mutation: fault-branch record removed from `ConnectionOutcome` -> `Test.ConnectionKey`
  `TestAFaultedTestOfUnstoredValuesIsRecorded` red (live 2219) and `Test.AuditVerbs` faulted leg red
  (throwaway 101).
- mutation: `AnnotateCallFault` call removed -> `Test.ConnectionKey` fault-detail and body-key legs red
  (live 2220).
- mutation: `tTestedAsStored` ignores the key source -> `TestABodyKeyIsSentShapeGatedAndNeverVerifies`
  red (live 2221); reverted green (2222).
- mutation: `Ladder.Store` opens an existing entry whatever `pMayOverwrite` says -> `Test.Secret`
  `TestAStoreDeclinesAnExistingEntryItMayNotOverwrite` red (live 2223); reverted green (2224).
- mutation: the handler passes may-overwrite 1 unconditionally -> `Test.CredentialOwnership`
  `TestAStoreOverAnEntryNoDefinitionOwnsIsRefused` red (throwaway 93) and `Test.AgentCredential`
  `TestAStoreOverAnOperatorsOwnEntryIsRefused` red (94).
- mutation: NOPRIVILEGE arm removed from `CredentialRefusal` -> `Test.CredentialPrivilege` red, 500
  `INTERNAL` (throwaway 96).
- mutation: `%EXACT` dropped from `GuardedIdsByCredentialName` -> `Test.CredentialOwnership`
  `TestReferencesDifferingOnlyInCaseAreNotSiblings` red on the sweep and entry assertions (97).
- mutation: mark move removed from `ClearOwnedCredential` -> `TestTheMarkMovesWhenTheOwnerLeaves` red,
  the entry surviving the second delete (98).
- mutation: `HandleDelete` records no effects -> `Test.AuditVerbs` delete leg red (99).
- mutation: the store's success record carries no effects -> `Test.AuditVerbs` credential leg red (100).
- mutation: `default` arm removed from `ClassifyChange` -> `Test.AuditVerbs` default leg red, the row
  under `ConfigChange` (102).
- mutation: `proxyHttps` force removed from `ProviderPort.Dispatch` -> `Test.ProviderProxy`
  `TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy` red on the TLS flag (live 2236).
- mutation: bare-IPv6 bracketing removed from `ProviderPort.Dispatch` -> `Test.ProviderProxy`
  `TestABareIpv6ProxyIsJudgedAsOneAddress` red, the proxy judged loopback (live 2237).
- mutation: credential-field comparison removed from `KeySourceFor` -> `Test.ConnectionKey`
  `TestTheStoredKeyGoesOnlyUnderTheStoredReference` red, `PROVIDER.CREDENTIAL` with `keySource`
  stored (live 2238).
- mutation: `MatchesStoredSecurityFields` dropped from `tTestedAsStored` -> `Test.ConnectionKey`
  marked-local leg red (live 2241); `Test.AgentConnection` stays 18/18 (throwaway 201).
- mutation: `HandleTest` passes `""` for the body -> `Test.AgentConnection`
  `TestTheShippedHandlerSendsABodyKeyAndRecordsNoVerification` red, 503 `PROVIDER.CREDENTIAL`
  (throwaway 202).
- mutation: `%EXACT` dropped from `GuardedCredentialOwned` -> `Test.CredentialOwnership`
  `TestOwningAnEntryDoesNotLicenseOneDifferingOnlyInCase` red at 200 (throwaway 203).
- mutation: `Kernel/State/Agent.cls` :219 mark reset removed -> `Test.CredentialOwnership`
  `TestTheMarkMovesWhenTheOwnerLeaves` red on the repointed former owner (throwaway 204).
- mutation: `HandleUpdate` records no effects -> `Test.AuditVerbs`
  `TestARepointIsRecordedWithWhatBecameOfItsCredentialEntry` red (throwaway 205).
- mutation: the answered not-as-stored record in `ConnectionOutcome` carries no effects ->
  `Test.ConnectionKey` other-endpoint and body-key legs red (live 2239).
- mutation: `CREDENTIALSRESOURCE` misspelt `%Ens_Credential` -> `Test.CredentialPrivilege`
  `TestAStoreWithTheResourceIsAccepted` red at 422 (throwaway 206).
- mutation: `CLEARFAILED` dropped from `Ladder.Clear`'s refused-delete branch ->
  `Test.CredentialOwnership` `TestClearingAnEntryAnswersWhatBecameOfIt` red, answering `absent`
  (throwaway 207).
- mutation: the fault-branch record in `ConnectionOutcome` made unconditional -> `Test.ConnectionKey`
  `TestAFaultedTestOfUnstoredValuesIsRecorded` as-stored leg red (live 2240).
- mutation: `AuditVerbs`' arming guard removed -> `check-objectscript.py` names
  `Test/AuditVerbs.cls:64` (static, never loaded).
- After the last revert, `diff -r src /tmp/ocupilot-ci/src` was empty and `git diff --stat` matched
  the pre-mutation tree.
- mutation: `CredentialRefusal` checks `KeyShapeAccepted` before `NOPRIVILEGE` (order swapped) ->
  `Test.CredentialPrivilege` `TestAWrongShapeKeyWithoutTheResourceIsStillRefusedByName` red,
  answering `AGENT.KEY.SHAPE` instead of `AGENT.CREDENTIAL.NOPRIVILEGE` (throwaway 5); reverted
  green (6) (QA).
- mutation: `Event.Record` drops the `effects` member from the payload entirely -> `Test.AuditVerbs`
  red on all four legs that read `effects` back (`TestACredentialStoreIsRecordedNamingTheSiblingsItDisabled`,
  `TestADeleteIsRecordedWithWhatBecameOfItsCredentialEntry`, `TestAFaultedTestOfUnstoredValuesIsRecorded`,
  `TestARepointIsRecordedWithWhatBecameOfItsCredentialEntry`), throwaway 8; reverted green (9) (QA).
- mutation: `ConnectionOutcome`'s success answer carries an extra `keySourceEcho` key ->
  `Test.AgentConnection` `TestATestOfTheStoredValuesAnswersAndRecordsVerification` and
  `TestTheShippedHandlerAnswersTheSuccessBodyOverTheWire` red on the exact-key-list assertion,
  throwaway 11; reverted green (12) (QA).
- mutation: `Test/CredentialPrivilege.cls`'s arming guard inverted (`= 1` for `'= 1`) ->
  `check-objectscript.py` names `Test/CredentialPrivilege.cls:132` (static, never loaded); reverted
  clean (QA).
- After each QA mutation, `diff -rq src /tmp/ocupilot-ci/src` was empty and `git diff --stat` /
  `git status --short` matched the pre-mutation tree.
- mutation: the store-database arm removed from `CredentialRefusal` -> `Test.CredentialPrivilege`
  `TestAStoreWithoutWriteOnTheStoresDatabaseIsRefusedByName` red, 500 `INTERNAL` (throwaway 14);
  reverted green (32) (CR).
- mutation: the not-owned exit dropped ahead of the mark move in `ClearOwnedCredential` ->
  `Test.CredentialOwnership` `TestANonOwnerLeavingHandsOnNoMark` red, the operator's entry overwritten
  and removed (throwaway 20); reverted green (21) (CR).
- mutation: `envVarName` dropped from `KeySourceFor`'s comparison -> `Test.ConnectionKey`
  `TestTheStoredKeyGoesOnlyUnderTheStoredReference` red on the environment-variable leg (throwaway
  23); reverted green (24) (CR).
- mutation: the https condition around `Dispatch`'s proxy overrides made unconditional ->
  `Test.ProviderProxy` `TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy` red on the plain-http TLS
  flag (throwaway 16) (CR).
- mutation: `Dispatch` passes 1 for the row's local escape to the proxy judgement -> `Test.ProviderProxy`
  `TestALoopbackProxyNeedsTheDefinitionsOwnLocalEscape` red on the `probe-canary` leg (throwaway 17);
  reverted green (18) (CR).
- mutation: the change-set `default` arm removed from `ClassifyChange` -> `Test.AuditVerbs`
  `TestDisablingTheDefaultRecordsTheMarkerMoveAsASecurityChange` red, the update under
  `ConfigChange` (throwaway 26); the default-verb arm removed instead -> the default leg still red
  (27); reverted green (28) (CR).
- mutation: `Base.Invoke`'s body branch binds the member to a local -> `Test.ProviderSecret` red on
  leg six's forced entries (throwaway 30); reverted green (31) (CR).
- After each CR mutation, `diff -rq src /tmp/ocupilot-ci/src` was empty; the worktree was never
  mutated.

## Auto Run Result

Status: done
Blocking condition: none

**Summary:**

- **DW-342:** a store overwrites only an entry some definition owns, matched exactly; otherwise it is refused `AGENT.CREDENTIAL.NOTOWNED`.
- **DW-349:** a store without `%Ens_Credentials:WRITE` is refused `AGENT.CREDENTIAL.NOPRIVILEGE`.
- **DW-357:** Test connection sends the stored key only to the stored endpoint and under the stored reference. Otherwise it sends the body's own key or none, and says which in `keySource`.
- **DW-337:** a configured proxy is judged like the endpoint, and an https call CONNECT-tunnels with TLS inside the tunnel.
- **DW-410/424:** an unreadable credential store faults `PROVIDER.CREDENTIALSTORE` and leaves the definition enabled.
- **DW-408/409/411/428/397/404:** change records carry `effects` (`disabledSiblings`, `credentialEntry`, `keySource`, `faultCode`). The ownership mark moves to the lowest-id survivor. `default` is a security change.

**Files:**

- `Api/Definitions.cls`: the two refusals, ownership-aware store, `KeySourceFor`, faulted-test record, `ClearOwnedCredential` outcomes and mark move, `default` classification.
- `Api/Error.cls`: NOTOWNED, NOPRIVILEGE and CREDENTIALSTORE codes and sentences.
- `Kernel/Secret/Ladder.cls`: transient unreachable rung, `Store` may-overwrite, `Clear` outcome.
- `Kernel/State/Agent.cls`: `%EXACT` sibling query and `GuardedCredentialOwned`.
- `Kernel/Audit/Event.cls`: `effects`.
- `Kernel/Provider/Base.cls` and `Anthropic.cls`: key source, CREDENTIALSTORE, no empty key header.
- `Port/ProviderPort.cls`: proxy judgement, IPv6 bracketing, forced tunnel and TLS, disable only on CREDENTIAL.
- `scripts/ci-throwaway.sh`: arming comments.
- New tests: `CredentialOwnership`, `ConnectionKey`, `ProviderProxy`, `AuditVerbs`, `CredentialPrivilege`, `RaisingEnsembleNamespace`, `SecretRaisingRung`.
- Updated tests: `AgentConnection`, `AgentCredential`, `AgentViolation`, `AuditRecord`, `FakeCredentialRow`, `ProviderPort`, `ProviderPortProbe`, `Secret`, `SecretDeletingStore`.

**Review:** 83 findings.

- 43 rows patched, in 16 fixes (RP1-RP16 under Tasks & Acceptance), done by a fresh subagent. One row was high: https through a proxy sent the key in cleartext.
- 4 rows deferred, as 2 frontmatter items: the database-write residual of NOPRIVILEGE, and the proxy applied to marked-local http.
- 36 rows rejected (11 false, 25 low), each with its reason in the Review Triage Log.
- Patched at entry verdict: 1 high, 7 medium groups.

**Follow-up review recommended: true.** RP1's TLS-inside-the-tunnel is asserted on the request flags the stub records. No test drives a real CONNECT proxy, so end-to-end TLS is taken from the vendor source (inference).

**Verification (patched tree):**

- Live `ocupilot`:
  - load and compile clean (296 classes);
  - `Secret` 10/10 (run 2244), `ProviderPort` 20/20 (2245), `ProviderProxy` 4/4 (2246), `ConnectionKey` 5/5 (2247), `AgentViolation` 8/8 (2248);
  - `AuditVerbs` (2249) and `CredentialPrivilege` (2250) refused by name, and afterwards 0 test principals, definitions, probe entries and egress rows.
- Static: `check-objectscript.py` 0 problems, harness 97 OK, `lint-docs.sh` clean, `ci`/`shell-scripts`/`compose` node tests 92/92.
- Fresh slot-A throwaway, in CI's order: up, then `ci-runner.mjs` 88 classes and 846 tests with 0 failed, 0 leftovers and 0 overlaps, then `smoke.sh` 19/19. It was torn down afterwards.
- Each Rule 19 mutation is recorded under Verification.

**Residual risks:**

- `Test/AgentConnection.cls` (827 lines) and `Test/ProviderPort.cls` (621) were already over the 500-line guideline and grew.
- On one throwaway that had run three full sweeps plus single classes, `/api/ocupilot/readiness` answered 401 to anonymous and 404 to authenticated calls, so smoke failed there. A fresh throwaway in CI's order passed. The cause was not isolated (inference: install/uninstall classes re-run on one instance).
- The patch subagent once sent a live load and a test run in the same message. The run showed the loaded mutation, and nothing was left behind.
