---
title: 'Story 18.41: The wallet credential rung'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: 'add9961f0edccbc9b729d7ec4860332468a954ae'
baseline_commit: 'add9961f0edccbc9b729d7ec4860332468a954ae'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      No automated test runs the wallet rung's refusal as a least-privileged person through the real provider call, or in the jobbed process a turn and Test connection use.
    evidence: |-
      The ladder is pinned with real principals in a child the test logs in (WalletRung), and Base and the port with an armed two-element refusal (WalletRungWire); the chain between them rests on the documented role inheritance of Kernel/Agent/Job and Kernel/Provider/TestCall. Settle it by running Test connection and a turn as a holder-only and an outsider principal on ocupilot-ci.
    location: >-
      src/OcuPilot/Test/WalletRung.cls, src/OcuPilot/Test/WalletRungWire.cls
    severity: medium (unverified)
  - summary: >-
      The Definition form's caption for the Wallet secret field does not say that the secret's own RequireTLS and AllowedHosts decide where it may be sent, so a person who names a secret with the default RequireTLS for a marked-local plain-http model learns it from the call's WALLETRUNG.REQUIRETLS refusal.
    evidence: |-
      The refusal sentence names the setting and the remedy (WalletRungError.REASONREQUIRETLS); the caption is EXPERIENCE.md :335 and strings.ts, which Epic 20 edits.
    location: >-
      EXPERIENCE.md, ui/src/app/core/strings.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** The credential ladder (AD-42) reads a provider key from an environment variable or an `Ens.Config.Credentials` entry; a key kept in the IRIS wallet, which the Secrets screen writes, cannot be used.

**Approach:** A third rung, `credType` `wallet`: `credentialName` names an existing key-value secret (`collection.secret`), read at the point of use by `%Wallet.KeyValue.GetSecretValue` in the person's own process, after checks that read no value. The Definition form gains a checkbox and a field.

## Boundaries & Constraints

**Always:**

- The value goes from the vendor's answer straight onto `Base.ApiKey`, never a local, and is cleared on every exit (AD-35, AD-48).
- Refuse before the vendor read, naming the pair, when the caller lacks the collection's use resource and `%Admin_Wallet:USE`, or the secret's uses exclude custom and the caller lacks `%Admin_Wallet:USE`. Such a refusal leaves the definition enabled.
- Treat an absent or non-key-value secret as an absent reference: `PROVIDER.CREDENTIAL`, which disables the definition.

**Never:**

- Store or change a wallet secret from the Definition form or its routes; the Secrets screen owns that.
- Call `GetSecretValue` twice per resolve, call `%OpenId` on a wallet class, or call `UseSecret`, `ApplyHTTP` or an `[Internal]` wallet method.
- Add a tool, declared read, governance key, route, screen-context field or `Prohibited` arm; add a property to `Kernel/State/Agent.cls`; add a code to `Api/Error.cls`.
- Edit an Epic 20 file (`Screen/Tool/*`, `Api/ScreenAction.cls`, `Kernel/Agent/*`, `app.routes.ts`, `screen-outlet.ts`, `panel.ts`, `detail-page.ts`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Resolve | caller holds the use resource or `%Admin_Wallet:USE`; key-value secret; uses include custom | the stored value is the call's key | -- |
| Absent | no such secret, or not `%Wallet.KeyValue` | -- | `PROVIDER.CREDENTIAL`; definition disabled |
| No pair | caller holds neither | no vendor read; no `AccessDenied` row | `WALLETRUNG.USE`, `detail.failedPair` the use resource |
| No custom use | uses exclude custom; no `%Admin_Wallet:USE` | no vendor read | `WALLETRUNG.USAGE`, `failedPair` `%Admin_Wallet:USE` |
| Multi-member | stored value begins `{` | no request sent | `PROVIDER.KEYSHAPE` |
| Save | `credType` `wallet`, name `^[%A-Za-z][A-Za-z0-9_-]*\.[A-Za-z0-9_.-]+$`, at most 128 characters | stored; `envVarName` cleared | otherwise 422 `WALLETRUNG.NAME` on `credentialName` |
| Store a key | `POST /agent/definitions/:id/credential` on a wallet definition | nothing written | `WALLETRUNG.KEYSTORE` on `apiKey` |
| Leave `creds` | a definition owning its entry moves to `wallet` | entry removed on AD-37's terms; owns nothing | -- |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `a1bd51d3`.

- `Kernel/Secret/Ladder.cls`: `Resolve` :84, `Credential` :241 (the sibling arm: no named local, `Return`, `$Char(0)`, transient on a raise).
- `Kernel/AgentRules.cls`: `CREDTYPE*` :30-44, `Normalize` :78, the credential rules :166-181, `CredTypeAccepted` :332. `Kernel/State/Agent.cls`: `CredType` :72, `CredentialName` :81, `GuardedUpdate` ownership reset :254.
- `Kernel/Provider/Base.cls`: the resolve :208-213, the shape gate :227-232, `Fault` :698, `HttpFor` :711, `ReasonFor` :731, `CredentialReason` :781. `Port/ProviderPort.cls` :156-190 disables only on `PROVIDER.CREDENTIAL`.
- `Api/Definitions.cls`: `HandleUpdate` repoint clear :486-491, `CredentialRefusal` :1149 (env arm :1162). `Api/Error.cls` dispatch arms :1241, :1454; `REASONAGENTCREDTYPEUNKNOWN` :1641. Sibling class shape: `Api/AllowListError.cls`.
- Vendor: `irislib/%Wallet/KeyValue.cls` :125-144; `irissys/%SYS/Wallet/Secret.cls` `CheckPermission` :109, `List` :287; `.../Collection.cls` `List` :122. `Port/WalletPort.cls` :147 is the `Exists` sibling.
- Client, `ui/src/app/areas/agent/`: `definition-form.store.ts`: `CRED_TYPE_*` :88-101, `CASCADE_ONLY_FIELDS` :113, `envMode` :350, `admissibleCredType` :358, `applyProviderDefaults` :931; `definition-form.page.ts`: the no-key checkbox :238-255, the key field :275-327, `onNoKey` :1026; `ui/src/app/core/strings.ts` :618 (EXPERIENCE.md :335).
- Test seams: `Test/LicenseWriteGateProbe.cls` `Run` :22 (Login in a child job), `WalletProbe`, `ProviderPortProbe`, `ProviderStub` :33, `ProviderSecret` :163.

## Tasks & Acceptance

**Execution:**

1. `Api/WalletRungError.cls` (new, `AllowListError`'s shape): `WALLETRUNG.NAME`, `KEYSTORE`, `USE`, `USAGE`, each with a sentence; `Codes`, `ReasonFor`, `HttpFor` (`USE` 403, `USAGE` 503, others 422). `Api/Error.cls` (add-only): a `WALLETRUNG.` arm at :1241 and :1454; `REASONAGENTCREDTYPEUNKNOWN` names three rungs.
2. `Kernel/AgentRules.cls`: `CREDTYPEWALLET` `wallet`; `Normalize` clears `envVarName` for it; `CredTypeAccepted` admits it; `Validate` holds its `credentialName` to the matrix rule (`WALLETNAMEPATTERN`, 128) in place of the 50-character rule.
3. `Kernel/State/Agent.cls`: `GuardedUpdate` also resets `CredentialCreated` when `CredType` changes; the two property comments name the wallet rung.
4. `Kernel/Secret/Ladder.cls`: `Resolve` gains `Output pRefusal` (`$ListBuild(code, pair)` or `""`) and a `wallet` arm, `Wallet`, in the matrix's order: `%Wallet.Secret:List` (collection, rest of the name) for one `%Wallet.KeyValue` row; `%Wallet.Collection:List` for its use resource, then `$System.Security.Check` or `%Admin_Wallet:USE`; without `%Admin_Wallet:USE`, `%Wallet.Secret.Exists` and usage bit 8; then one `GetSecretValue`, returned straight. A raise is transient.
5. `Kernel/Provider/Base.cls`: pass `.tRefusal`; a refusal faults its code, reason naming the pair, `detail.failedPair`; the shape gate also refuses a key beginning `{`; `HttpFor` and `ReasonFor` delegate `WALLETRUNG.` to task 1.
6. `Api/Definitions.cls`: `CredentialRefusal` answers `WALLETRUNG.KEYSTORE` for a wallet row before :1162; `HandleUpdate` clears the prior owned entry also when `credType` left `creds`.
7. `definition-form.store.ts`: `CRED_TYPE_WALLET`, `walletMode()`, `setWallet(on)` holding the prior type and `credentialName` (untick restores the catalog default); in wallet mode `credentialName` is a rendered field, a provider change keeps it, and no key store is sent.
8. `definition-form.page.ts`: a checkbox shown on every family, exclusive with No API key; in wallet mode the Wallet secret field and caption replace the key field.
9. Strings: "Read the key from a wallet secret", "Wallet secret" and "The secret's full name, collection.secret, as the Secrets screen lists it. Set its value there; whoever runs a turn needs permission to use its collection." appended to EXPERIENCE.md :335 in place and to `strings.ts`. Adds 3 (3,316 at this head); no bound change.

**Tests** (each under 500 lines; each creates and removes its own collection `OcuPilotProbe1841`, resource, secrets, principals and definitions):

10. `Test/WalletRungProbe.cls` (new, as `LicenseWriteGateProbe`): logs in as a principal in a child job, resolves, signals `{matches, transient, refusal}`, never the value.
11. `Test/WalletRung.cls` (new): principals holding the use resource, nothing, or `%Admin_Wallet:USE` (each with READ on the install database); secrets key-shaped (default uses), `HTTP`-only, and a symmetric key. Legs C1, C3, C4; every code has a sentence; C6 with the event as read, then on (restored in `OnAfterOneTest`). Mutations: no use-resource check -> C3 red; `Wallet` answers `""` -> C1 red; absent read transient -> C4 red.
12. `Test/WalletRungWire.cls` (new, HTTP and `ProviderPortProbe`): C2's server half, C5's store refusal and `{` leg, Integration; `ProviderStub` gains (add-only) an armed key comparison recording a boolean. Mutation: drop the `{` term -> red.
13. `Test/ProviderSecret.cls`: an eleventh leg, the canary in a probe wallet secret (C5). `Test/CredentialOwnership.cls`: a method for the matrix's last row; mutation: drop task 6's type term -> red.
14. `definition-form.page.spec.ts` and `ui/browser/definitions.browser-spec.mjs`: tick, name, save, reload; a malformed name's reason on its field; untick restores (C2). Mutation: the store drops `credType` `wallet` -> both red.
15. Rule 30 sweep: `Test/AgentRules.cls` :239 `"wallet"` becomes `"vault"`; grep the test trees for the form's checkboxes, rung vocabularies, the changed sentence and Base's code tables; run unchanged `AgentCredential`, `CredentialRepoint`, `CredentialRungOffer`, `AgentConnection`, `ProviderPort`, `DefinitionsFaults`, `AgentViolation`.

**Acceptance Criteria** (epics.md 18.41):

- **C1.** Given a key-value secret and a caller holding its collection's use resource, when a provider call resolves a `wallet` definition naming it, then the call's key is the secret's stored value.
- **C2.** Given an OcuPilot administrator on the Definition form, when they tick Read the key from a wallet secret, name a secret and save, then the definition reads back `wallet` with that name and offers no key field; a malformed name is refused on its field.
- **C3.** Given a caller without the pair, or a secret whose uses exclude custom, when the call resolves, then it is refused `WALLETRUNG.USE` or `.USAGE` naming the pair, the definition stays enabled and no `AccessDenied` row is written.
- **C4.** Given an absent or non-key-value secret, when a call resolves it, then `PROVIDER.CREDENTIAL` and the definition is disabled.
- **C5.** Given the wallet rung, when calls fail, keys are stored or a value begins `{`, then no part of the value reaches a log, envelope or request, and the store route writes nothing.
- **C6.** Given auditing on, when the rung resolves, then no `WalletSecretUse` row is written while that event is off, and one row naming the secret and not its value while it is on.
- **Integration.** Given a wallet definition whose secret holds a key-shaped canary, when `Test.ProviderPortProbe` calls, then the stub's request carries it in the family's key header.

### Review Findings

Code review 2026-10-13 (`full-opus`: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 33 rows; 13 entries and 9 closed without one.

- [x] [Review][Patch] (med) Unticking always wrote the catalog default into `credentialName`, so a tick and untick repointed a stored `creds` definition naming its own entry, and `HandleUpdate` removed that owned entry [definition-form.store.ts `setWallet`]: fixed; the name and provider are held at the tick and the name is restored while the provider is unchanged.
- [x] [Review][Patch] (med, Rule 30) The `AccessDenied` counts in `WalletRung` (C3, C6) and `WalletRungRoles` counted every row on the instance, the control's wait stopped at the first row of any origin, and the two classes carried copies of one helper [WalletRung.cls, WalletRungRoles.cls `DeniedRows`]: fixed; `WalletRungProbe.DeniedRows` counts rows naming a probe secret, the control is a direct call on `CONTROLSECRET`, which no resolution names, and the zero is read after the control's row.
- [x] [Review][Patch] (low) A wallet definition's delete or repoint ran `ClearOwnedCredential` on the secret's name, so its audit row read `effects.credentialEntry: notOwned` [Api/Definitions.cls:490, :536]: fixed; `AuditVerbs` gains the wallet legs.
- [x] [Review][Patch] (low) `WALLETRUNG.USE` answered 403 on the `unavailable` slug [Kernel/Provider/Base.cls `FaultRefused`]: fixed; the slug is its status's own.
- [x] [Review][Patch] (low) Ticking the wallet in env mode left the hidden environment variable field's refusal in the summary [definition-form.store.ts `setWallet`]: fixed.
- [x] [Review][Patch] (low) Two untick branches had no test: `none` on a provider that does not license it, and the env default for a stored wallet definition: page-spec tests added.
- [x] [Review][Patch] (low) `WALLETNAMEPATTERN`'s doc said it is the vendor's pattern; it is an ASCII subset with a non-empty secret name [Kernel/AgentRules.cls:52]: doc corrected (the narrower rule is the matrix's).
- [x] [Review][Patch] (low) `WalletRungError.NAMEMAX` was unused beside `AgentRules.MAXWALLETNAMELENGTH`: removed.
- [x] [Review][Patch] (low) `ProviderStub.ArmKeyCompare`'s doc said "every call's key header"; it reads `x-api-key`: doc corrected.
- [x] [Review][Patch] (low) `WalletRungRoles.DirectCallRefused` read an errored step as a refusal: it now requires a boolean `opened`.
- [x] [Review][Defer] (med) The rung ignores the secret's `RequireTLS` and `AllowedHosts`, which the vendor enforces only in `ApplyHTTP`, and sends the value to the definition's endpoint [Kernel/Secret/Ladder.cls `Wallet`]: DW-2406, decision-pending, owner=burndown; recommended: honour both against the endpoint.
- [x] [Review][Defer] (low) wontfix-accepted: `Ladder.Wallet`'s two race-only transient branches (an unlisted collection; `Exists` failing for a holder) have no test; the earlier pass's patch pinned the raise alone. reopen_if: a story changes those branches, or a deleted collection is seen leaving a definition enabled.
- [x] [Review][Defer] (low) wontfix-accepted pending the lead: EXPERIENCE.md :335 says the Wallet secret field replaces the API key field; in env mode it replaces the environment variable field. Epic 20 edits that file. reopen_if: the lead approves the one-line in-place edit.

Closed without an entry:

- by-design: the caption names no custom use, and an administrator's Test connection verifies a definition others are refused `WALLETRUNG.USAGE` on: Task 9 fixes the strings, privilege is the caller's (AD-8), and the refusal names the requirement.
- by-design: a turn's sentence is recomputed from its code without the pair (AD-39); the pair is on the provider fault and Test connection's answer (Task 5), and the turn renderers are Epic 20 files.
- settled: no warning on the Secrets screen that a definition reads the secret (a named consequence).
- false: an undeclared `WALLETRUNG.*` code would get an empty reason; nothing emits one, and `Codes()` is pinned.
- false: a refused login in `WalletRungProbe.Run` lets C6 pass; every control leg asserts `opened = 0`, which an `%All` child fails, and use rows do not depend on the principal.
- false: the two non-raise transient answers contradict AD-42; "does not resolve" covers them, and `UseResource` is `Required`, so only a race reaches them.
- wontfix-theoretical: an unreadable `WalletSecretUse` state leaves C6's event on after a mid-test failure; it needs `Security.Events.Get` to fail where `Modify` succeeds.
- rejected: the `'wallet'` literal in two `Agent.cls` queries; a wire constant the tests pin, and binding it needs a signature change.
- rejected: QA's files are uncommitted and the spec's deferred item is stale; the lead commits, and spec records are not this review's to rewrite.


### Rework 1 (orchestrator ruling A on DW-2406, 2026-10-13)

- [x] [Review] DW-2406: honour the secret's own `RequireTLS` and `AllowedHosts` with the vendor's exact semantics, mirroring `%Wallet.KeyValue.ApplyHTTP` (`irislib/%Wallet/KeyValue.cls` :224-239); invent no stricter meaning. (1) `RequireTLS` set and the endpoint not https: refuse. (2) `RequireTLS` set and `AllowedHosts` non-empty: the endpoint's host must be in `AllowedHosts`, matched as the vendor matches (the server name without the port, `Headers("HOST")=server` at `%Net/HttpRequest.cls` :70, exactly, with `$ListFind`); the provider request must check server identity (`SSLCheckServerIdentity`: confirm the provider request sets it); and if the provider path can use a proxy without a CONNECT tunnel, the proxy host must also be listed, as the vendor requires (if it never proxies untunnelled, say so in one line). (3) `AllowedHosts` set without `RequireTLS`: the vendor enforces nothing, so neither do we. Run it at call time against the endpoint actually used, before `GetSecretValue`, reading only the two settings and never the value, in ONE place in the rung so Test connection, `TestCall` and the turn job all pass through it, ordered after Story 18.40's configuration check (`ProviderPort.SslConfigurationState`), both before any secret read. Refusals carry `WALLETRUNG` codes that name the setting (in `Api/WalletRungError.cls`). Tests: an http endpoint with `RequireTLS` is refused; a host not in the list is refused; a listed host is served; `AllowedHosts` without `RequireTLS` is served; on every refusal the secret is not read and no wallet use row is written (with `WalletSecretUse` on); each with its `mutation:` line.

### Review Findings (rework 1 re-review)

Code review 2026-10-14 of `add9961f..HEAD` (`full-opus`: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 20 rows, 9 entries (0 high, 1 med, 8 low), all patched; 6 rejected. DW-2406 checklist: each item confirmed (the lead adjudicates the entry). `ApplyHTTP`'s three conditions hold in `WalletTransportRefusal`. It runs in `Ladder.Wallet` after `Dispatch`'s `SslConfigurationState` and before the one `GetSecretValue`, for the turn, `TestCall` and Test connection alike. It reads the settings alone, and a refusal reads no value and writes no use row. `NewRequest` sets `SSLCheckServerIdentity`, and `Dispatch` tunnels every proxied https call. The tests and `mutation:` lines are in place.

- [x] [Review][Patch] (med, Rule 30) The use-row counts that prove no refusal read the secret were taken once any row was readable, so a later refusal's row could go uncounted and the host test's four could read short [WalletRung.cls TLS and host tests]: fixed; `ControlRow` (the outsider's `CONTROLSECRET` call, which C3 and C6 now share) is read first, and the host test derives its count from its served legs.
- [x] [Review][Patch] (low) The plain-http wire test's secret held an `sk-ant-` value on the `probe-local-` row, so dropping the scheme test ended in `PROVIDER.KEYSHAPE`; "no socket was opened" could not fail, and the test's mutation note was false [WalletRungWire.cls `TestAnEndpointThatIsNotHttpsFaultsAWalletCallThatRequiresTls`]: fixed; the test now uses its own `LOCALSECRET`, which holds a `probe-local-` value.
- [x] [Review][Patch] (low) `WalletEndpointHost` kept a query or fragment that follows the host, so a compatible endpoint `https://host?x`, posted as `https://host/chat/completions?x`, was refused `ALLOWEDHOSTS` for a listed host [Ladder.cls `WalletEndpointHost`]: fixed; it now cuts the authority at `?` and `#`, as `Base.OriginOf` does, and two legs were added to the host test.
- [x] [Review][Patch] (low) The `RequireTLS`-off test's mutation note said every leg is refused; the listed https leg is still served under that mutation [WalletRung.cls]: note corrected.
- [x] [Review][Patch] (low) `DEFAULTSECRET`, `OFFLIST` and `ONLIST` relied on the vendor's `RequireTLS` default [WalletRungProbe.cls `SeedAll`, WalletRungWire.cls]: each now sets `RequireTLS` true.
- [x] [Review][Patch] (low) `SeedAll`'s doc counted "the four secrets"; it creates seven [WalletRungProbe.cls]: doc corrected.
- [x] [Review][Patch] (low) The class headers left out what the rework added. `WalletRungWire` now sets `WalletSecretUse`, and `WalletRung` now pins the secret's settings [WalletRungWire.cls, WalletRung.cls]: both headers corrected.
- [x] [Review][Patch] (low) `PLAINENDPOINT`'s doc named the wrong rows [WalletRungWire.cls]: doc corrected.
- [x] [Review][Patch] (low) `HttpFor`'s doc said "for want of the secret's transport settings" [WalletRungError.cls]: now "by the secret's own transport settings".

Rejected:

- false: `:1209` and `:70` misplace the vendor lines. `:1209` opens the block that tests the scheme, `:70` seeds the `Host` header the doc names, and the matched host is unchanged.
- false: `DetailKeyFor` answers `failedPair` for codes with no pair. Its doc is scoped to the ladder's refusals, and only those four reach `FaultRefused`.
- false and wontfix-theoretical: the settings should be judged again before each attempt, or read from the same object as the value. `ApplyHTTP` judges once per application, as here. For the race to matter, an operator would have to change `RequireTLS` or `AllowedHosts` between two vendor calls in one process.
- wontfix-theoretical: if `UseEventEnabled` answers `-1`, `WalletRungWire` leaves the event on. That needs `Security.Events.Get` to fail where `Modify` succeeds, as round 1 ruled for `WalletRung`.
- rejected: `## Auto Run Result` still says the spine names two refusals. The fix is a spec edit, which is not this review's to make.
- rejected: the case-insensitive scheme match has no mutation of its own. Leg 5 asserts it, and Rule 19 asks for one mutation per criterion.
- Rule 31, reason stated here: `WalletEndpointIsHttps` repeats `ProviderPort.IsHttps`'s one expression, and `WalletEndpointHost` differs from `Egress.HostOf`. The rung mirrors the `Host` header `%Net.HttpRequest` sends, which keeps IPv6 brackets that `HostOf` strips. The Kernel ladder also calls no private Port helper.

## Spec Change Log

- 2026-10-13, lead, rework 1 (Rule 5 tier 1 on AD-42 and AD-35, orchestrator ruling A on DW-2406): the rung honours the secret's `RequireTLS` and `AllowedHosts` exactly as `ApplyHTTP` does, at call time, before the value is read.

- 2026-10-13, lead spec gate: "For the lead" applied in the spine (AD-42, AD-35, AD-7); the vendor candidate filed as DW-2377 (decision-pending, owner hold). The WalletSecretUse reading (an operator-enabled vendor event, not a new OcuPilot audit write) went to the orchestrator to confirm.

## Review Triage Log

### 2026-10-13 - Review pass

- verdicts: 16 findings - high 0, medium 1, low 8, false 5, maybe-false 2
- findings:
  - `[medium]` `[patch]` The wallet arm's transient answers (an unlisted collection, an unopenable secret, a raise) are pinned by no test - `WalletRung` asserts `transient=0` throughout and `WalletRungWire` has no transient leg; patched: `SecretWalletRefusal.ArmRaise` makes the shipped arm's listing raise and `WalletRungWire.TestAWalletThatCouldNotBeReadLeavesTheDefinitionEnabled` asserts `PROVIDER.CREDENTIALSTORE`, 503, no socket, definition still enabled and verified; mutation line added.
  - `[maybe-false]` `[defer]` No test runs a real ladder refusal through the real `Base.Invoke`, or the wallet arm in a jobbed process as a non-superuser - the refusal shape is asserted on both sides (`WalletRung` reads the real refusal as `code|pair`, `WalletRungWire` arms the same two-element list for the real `Base.Invoke`), and `Kernel/Agent/Job` and `Kernel/Provider/TestCall` document that the child inherits `$USERNAME` and `$ROLES`, which every gated tool already relies on; to settle it: Test connection and a turn as a holder-only and an outsider principal on `ocupilot-ci`.
  - `[low]` `[patch]` `ProviderSecret` leg nine has no standing proof the call reached the stub - patched: `Calls()` is asserted 1 after the leg; the `Ladder.Wallet` answers `""` mutation now reddens `ProviderSecret` as well.
  - `[low]` `[patch]` C6's off leg reads zero rows 1 s after the resolution, a shorter wait than the class allows a positive row - patched: a refused direct vendor call writes a control row and the zero is read once that row is readable; mutation (the event never turned off) recorded.
  - `[low]` `[patch]` The page spec's exclusivity test ends on `toHaveLength(0)` over POSTs after a sequence that never saves - patched: the line is removed, with its unused `calls` binding.
  - `[low]` `[patch]` C2's server-side name rule, its 128 bound and `Normalize`'s clear have no recorded mutation, and a refused name's reason across a provider change has no test - patched: the three server mutations were run and recorded, and a page-spec test was added for the reason, with its mutation.
  - `[low]` `[reject]` `WalletRungWire` and `ProviderSecret` leg nine create a probe resource and wallet collection without `ARMINGVARIABLE` - the sibling wallet classes that create collections arm nothing, `check-objectscript.py` reads 0 problems, and arming means a parameter, a start guard and a roster row in an Epic 20 file for probe-named objects the class removes.
  - `[low]` `[reject]` `GuardedCredentialOwned`'s wallet term is unpinned - it is reachable only by a wallet row carrying the ownership mark, which `GuardedUpdate`'s reset and the `KEYSTORE` refusal prevent.
  - `[false]` `[reject]` The `{` term in the shape gate also reaches the env, creds and body sources - Task 5 words it as the shape gate's term, and no provider key begins with `{`, so no valid key is refused.
  - `[false]` `[reject]` The auto run result section still reads `ready-for-dev` - that section is the finalize step's to write, and it is written below.
  - `[low]` `[defer]` Real refusals never reach the provider-call layer - grouped with the second row of this log (same root cause, same route); the deferred item covers both.
  - `[maybe-false]` `[defer]` Spawned-job identity: tests set roles with `Login` in a child the test starts - the second row's part (b); the same deferred item.
  - `[low]` `[reject]` The turn view names the refusal by a code-only sentence, not the specific pair - AD-39 recomputes a turn error's reason from its code; the pair is on the provider fault and Test connection's answer, which Task 5 specifies.
  - `[false]` `[reject]` The `{` gate's shared reach - the same as the ninth row.
  - `[false]` `[reject]` `Exists` opens the secret inside the vendor, and no test covers a pre-check that passes while the vendor then refuses - Task 4 prescribes `Exists` and measured it; the code names none of the banned methods; a vendor refusal after the pre-check lands in the catch the first row's test now pins.
  - `[false]` `[reject]` `Error.cls` is edited though the intent says add no code to it - the edit is dispatch arms and one reworded sentence (Task 1); no parameter or code was added, and the arm in `ReasonForTurnError` is the same kind.

### 2026-10-13 - Review pass (rework 1, DW-2406)

- verdicts: 15 findings - high 0, medium 0, low 10, false 3, maybe-false 2
- findings:
  - `[low]` `[patch]` The order of the custom-use refusal and the transport refusal is pinned by no test - patched: a holder-without-custom-use leg on an http endpoint in `WalletRung`'s RequireTLS test; mutation line added (run 416).
  - `[low]` `[patch]` The bracketed-IPv6 arm of `WalletEndpointHost` has no test - patched: `WalletRungProbe.LISTEDHOSTS` lists a literal, and `WalletRung`'s host test serves it with a port and refuses an unlisted one; mutation line added (run 417).
  - `[low]` `[reject]` The two vendor conditions the rung skips (server identity, untunnelled proxy) have no `mutation:` line in this spec - `Provider.TestTheRequestCarriesTheSettingsItWasGiven` and `ProviderProxy.TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy` pin them and carry their own mutation notes; the item asked for the statement, not a new pin.
  - `[low]` `[patch]` `WalletRungProbe.Run`'s doc says an empty `endpoint` takes the default; the code passes it through, and two legs depend on that - patched: the doc now says an empty text is an endpoint.
  - `[maybe-false]` `[reject]` The host test's exact count of four use rows has no readiness wait - two child-process logins follow the last served read and every run so far read the count; it would be settled by a red from a slow audit store, and a LOW with no named occurrence is not worth a wait loop in a shared helper.
  - `[low]` `[reject]` The diff has no spine hunk for AD-42 and AD-35 - the spine edit is the lead's (Rule 20, a contended file) and is named in the stage result.
  - `[false]` `[reject]` Legs drive `Ladder.Resolve` with endpoints `Dispatch` refuses earlier (`ftp://`, empty, no scheme) - they pin the rung's fail-closed answer for those inputs; the dispatch path is driven by `WalletRungWire`.
  - `[low]` `[reject]` No test compares the host extraction with the vendor's parsing - the vendor method is `[Internal]` and banned; the cited lines are mirrored and the legs pin case, port, userinfo, query and brackets.
  - `[low]` `[patch]` Bracketed IPv6 untested (intent layer) - the second row's root; patched there.
  - `[low]` `[reject]` Proxy and identity invariants unpinned in this story (intent layer) - the third row's root; pinned by the two named tests.
  - `[maybe-false]` `[defer]` The new refusals are not driven through the route or the turn job - the same root as the story's existing deferred item (a least-privileged person through the real call and the jobbed process); not appended again. What mutates it: `Base.Invoke` passing no endpoint reddens `WalletRungRoles`, so Test connection's child does carry the endpoint.
  - `[low]` `[reject]` Use-row evidence is uneven and `AccessDenied` rows are unasserted for the transport legs - `WalletRung` counts use rows over every refused and served leg of both settings, and a transport refusal follows a successful `Exists`, which writes no denial row.
  - `[false]` `[reject]` Gemini's `RequestUrl` could move the call after the key is read - `Attempts` refuses a built URL whose scheme or authority differs from the judged endpoint's, and an override may rewrite only the path, so the host and scheme judged are the ones used.
  - `[false]` `[reject]` An omitted endpoint is judged not https and `WalletSettings` now opens the secret for administrators too - by design: the rung fails closed, `Base.Invoke` is its only caller and passes the endpoint, and the administrator legs of `WalletRung` pin the open.
  - `[low]` `[defer]` The Definition form caption does not mention the secret's own settings - the deferred item this pass added (`EXPERIENCE.md`, `strings.ts` are Epic 20 files).


## Design Notes

**Governing ADs:** AD-7, 8, 9, 10, 22, 29, 35, 37, 39, 42, 48 and 53.

**No owner question is needed.** Measured (below): the stock event set writes no per-use row, the refusals are made before any vendor read, and the value reaches only what the env and creds rungs already reach.

**One field (Rule 31).** `credentialName` names the entry in whichever store `credType` selects, so no wire field, property or roster changes; tasks 3 and 6 keep AD-37's ownership mark from crossing stores. The name is a weak reference (AD-37); the Secrets screen holds the key, as the AC's premise says.

**Self-protection and governance.** The agent can neither read nor change a definition's rung or secret: `/agent/definitions` takes `OcuPilotAdmin:USE` and no tool (AD-1, AD-40), and the Definitions read answers neither field. It may propose a confirmed change to the secret through the Secrets tools (named consequence: a deleted secret disables the definition at its next call). No new write key (AD-22); a definition save is version-guarded own state, with no target hold (DW-1882).

**Consumes:** 3.3's ladder, the Secrets screen (8.6, 18.24), the Definitions routes and form, `Base.Invoke`. **Consumed-by:** every provider call and Test connection (Integration). **Ledger:** inbox empty.

**For the lead** (Rule 20; append each, tagged `[AMENDED <date>, Story 18.41 spec gate, Rule 20]`):

- **AD-42**, after "never returns a value into a status or an error.": **A wallet rung** (Story 18.41): `credType` `wallet` names an existing `%Wallet.KeyValue` secret in `credentialName`, its stored value the key; OcuPilot stores none. The caller's process reads it by `GetSecretValue` only once value-free reads find it (else it does not resolve), find the caller holding its collection's use resource or `%Admin_Wallet:USE` (else `WALLETRUNG.USE`), and find custom use or that pair (else `WALLETRUNG.USAGE`); a refusal names the pair and leaves the definition enabled. A value beginning `{` is not shaped like a key.
- **AD-35**, append: the wallet rung's value moves from the vendor's answer onto the adapter's key property with no local; the vendor's refusal text names the secret, never the value (measured), and reaches the log only.
- **AD-7**, append: **So is the wallet's use row** (Story 18.41): `%System/%Security/WalletSecretUse` is off in the stock event set, and a wallet read writes no row; once an operator turns it on, each read writes one naming the secret, never the value: the vendor's record of a use the operator chose to record. Cost: one row per provider call while on. The rung's refusals precede the vendor read and write no `AccessDenied` row.
- **Measured (a), audit:** `WalletSecretUse` reads off, auditing on, on `ocupilot` (`iris_audit_manage status`) and `ocupilot-ci`. There, a use-resource holder's `GetSecretValue` wrote no row with it off and one per read with it on (the name only); a refused read wrote one `AccessDenied` row.
- **Measured (b), privilege:** the read needs the use resource or `%Admin_Wallet:USE`, and custom use or `%Admin_Wallet:USE`. A use-resource holder read a custom-use secret and a Secrets-screen one (a flat `WalletPort` `PUT`: the typed string, uses 15), and was refused #26202 on an HTTP-only one, which a `%Admin_Wallet:USE` holder read; a holder of neither got #822. Both list queries answered every principal with no row; `Exists` answered the holder its uses with no row, and a non-holder #822 with an `AccessDenied` row. The turn's process is the person's (AD-8); no OcuPilot role grants a wallet resource, stock `%Manager` grants `%Admin_Wallet:USE` (read).
- **Measured (c), exposure:** none new. Vendor errors and the use row name the secret only; the definitions read and form context are unchanged; the `{` rule keeps a multi-member secret's other members unsent.
- **Vendor candidate** (never reported): a use-resource holder's `%Wallet.KeyValue.%OpenId` failed #939 writing `Protect` rows.
- **Rule 11.** Epic 20's diff and `status -s` (2026-10-12) touch none of these files but EXPERIENCE.md (:335 in place); `Test/AgentRules.cls` :239 is the one literal change.

## Verification

**Commands** (one run per call, `timeout: 600000`; never `ocupilot`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals in `%UnitTest_Result`: `WalletRung`, `WalletRungWire`, `ProviderSecret`, `CredentialOwnership`, `AgentRules`, and every class task 15 names or changes.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`, the bundle measured under the 3527kB warning; `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `node --test --test-concurrency=1 browser/definitions.browser-spec.mjs` with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`, 0 problems.

**Manual check (implement, `ocupilot-ci`):** a probe secret holding the Anthropic key from `/Users/jbrandt/git/OcuPilot/.env.local`, read at the point of use, never printed or written elsewhere; a probe `wallet` definition on `claude-haiku-5-5`; Test connection verifies; remove all; record the outcome here.

**Shared surfaces:** the rung vocabulary; the Definition form's controls; `Base`'s code tables; the Fixed strings; audit event `WalletSecretUse` (restored); wallet collections, users and roles (probes only).

every test added or changed passes on a fresh environment, in either order

**Run (implement, `ocupilot-ci`, all green on the restored tree):** `WalletRung` 5, `WalletRungWire` 7, `ProviderSecret` 1, `CredentialOwnership` 9, `AgentRules` 20; unchanged and green: `AgentCredential` 17, `CredentialRepoint` 2, `CredentialRungOffer` 8, `AgentConnection` 20, `ProviderPort` 20, `DefinitionsFaults` 3, `AgentViolation` 8. Page spec 67 (the component suite read 3,088 before the review pass added one test), `definitions.browser-spec.mjs` 11, `check-objectscript.py` 0 problems, `lint-docs.sh` 0. `npm run test:tools` 1,986 of 1,986 (`scripts/ci-throwaway.sh` gained one roster row, `# classes: WalletRung`, in the `OCUPILOT_ALLOW_PRINCIPALS` block; add-only beside Epic 20's rows).

**Sizes (fresh `npm run build`):** initial total 1.92 MB, under the 1992 kB warning; largest lazy chunk `data-browser-page` 83.32 kB, under the 88 kB cap; `definition-form-page` 28.70 kB. Fixed strings: the test's own count reads 3,375 (3,372 before this story), bound 3,800 unchanged.

**Mutations (Rule 19):** each applied on `ocupilot-ci` (the mutated class recompiled with its descendants for `Base`), observed red, reverted byte-identical.

- mutation: `Ladder.Wallet` skips the use-resource check -> `WalletRung.TestACallerWithoutThePairIsRefusedBeforeAnyRead` red.
- mutation: `Ladder.Wallet` skips the custom-use check -> the same test red, on the `AccessDenied` count.
- mutation: `Ladder.Wallet` answers `""` -> `WalletRung` C1, C3 and C6 red; `WalletRungWire` integration and brace tests red; `ProviderSecret` red (its wallet leg no longer reaches the stub).
- mutation: `Ladder.Wallet` answers an absent secret as transient -> `WalletRung.TestAnAbsentOrNonKeyValueSecretIsAnAbsentReference` red; `WalletRungWire.TestAnAbsentSecretFaultsTheCredentialAndDisablesTheDefinition` red.
- mutation: a second `GetSecretValue` in `Ladder.Wallet` -> `WalletRung.TestTheUseRowIsWrittenOnlyWhileTheEventIsOn` red (two rows).
- mutation: drop the `{` term from `Base.Invoke`'s shape gate -> `WalletRungWire.TestAValueThatOpensWithABraceSendsNoRequest` red; it is driven on the prefix-less `gemini` row, because the `sk-ant-` row refuses a brace value on its prefix alone and stayed green.
- mutation: `Base.Invoke` ignores the ladder's refusal -> `WalletRungWire.TestARefusalNamesThePairAndLeavesTheDefinitionEnabled` red.
- mutation: drop the `WALLETRUNG.KEYSTORE` arm of `CredentialRefusal` -> `WalletRungWire.TestAKeyPostedToAWalletDefinitionIsRefusedAndNothingIsWritten` red (and left a credential entry, which the teardown now removes).
- mutation: drop the `wallet` arm of `CredTypeAccepted` -> `WalletRungWire` save and store tests red.
- mutation: drop the `WALLETRUNG.` arm of `Error.ReasonForViolation` -> `WalletRung.TestEveryCodeHasASentenceAndAStatus` red.
- mutation: drop the type term from `HandleUpdate`'s clear condition -> `CredentialOwnership.TestMovingOffTheCredentialsRungRemovesTheOwnedEntryAndOwnsNothing` red.
- mutation: drop the type term from `GuardedUpdate`'s mark reset -> the same test red.
- mutation: drop the wallet exclusion from `GuardedIdsByCredentialName` -> the same test red.
- mutation: bind the resolved key to a local in `Base.Invoke` on the wallet path -> `ProviderSecret.TestNoCredentialMaterialReachesTheLogsOrTheEnvelope` red on the wallet leg's two forced entries alone.
- mutation: `setWallet` never moves `credType` to `wallet` -> five page-spec tests red and the browser spec red (bundle rebuilt and redeployed).
- mutation: drop `!this.walletMode()` from the credential post guard -> the page spec's Test connection test red.
- mutation: drop the wallet keep from `applyProviderDefaults` -> the page spec's provider-change test red.
- mutation: drop `setWallet(false)` from `onNoKey` -> the same exclusivity test red.
- mutation: the catch in `Ladder.Wallet` leaves `pTransient` 0 -> `WalletRungWire.TestAWalletThatCouldNotBeReadLeavesTheDefinitionEnabled` red.
- mutation: `AgentRules.Validate` skips the wallet name rule -> `WalletRungWire.TestASaveStoresTheRungAndTheNameAndRefusesAMalformedOne` red.
- mutation: the wallet name bound in `AgentRules.Validate` becomes 129 -> the same test red.
- mutation: `AgentRules.Normalize` stops clearing `envVarName` for `wallet` -> the same test red.
- mutation: `WalletRung`'s C6 test never turns `WalletSecretUse` off -> `WalletRung.TestTheUseRowIsWrittenOnlyWhileTheEventIsOn` red on the off leg.
- mutation: `setProvider` stops skipping `credentialName` in wallet mode -> the page spec's "a refused secret name keeps its reason across a provider change" red.
- (QA) file: `src/OcuPilot/Test/WalletRungRoles.cls` (new, 2 tests green on `ocupilot-ci`, run 84): a least-privileged person sends Test connection over HTTP on a stored `wallet` definition of the `turnprobe` row, refused without the use resource and served with it; armed by `# classes: WalletRungRoles` in the `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER` blocks of `scripts/ci-throwaway.sh` (add-only).
- (QA) mutation: `Ladder.Wallet` skips the use-resource check -> `WalletRungRoles.TestAPersonWithoutThePairIsRefusedInTheTestConnectionChild` red (503 `PROVIDER.CREDENTIALSTORE`, and the vendor's own `AccessDenied` row).
- (QA) mutation: `Ladder.Wallet` answers `""` -> `WalletRungRoles.TestAPersonWithTheUseResourceReachesTheAdapterWithTheStoredKey` red (`PROVIDER.CREDENTIAL`, no request).
- (QA) mutation: `Ladder.Wallet` appends a character to the value -> the same test red on the key header alone.
- (QA) mutation: the `OCUPILOT_ALLOW_TEST_PROVIDER` roster row of `WalletRungRoles` removed -> `ui/tools/ci.test.mjs` "each arming roster names exactly the classes that declare that variable" red.
- (CR) mutation: `Ladder.Wallet` skips the use-resource check -> `WalletRung.TestACallerWithoutThePairIsRefusedBeforeAnyRead` red, the scoped `AccessDenied` count included (run 92); `WalletRungRoles.TestAPersonWithoutThePairIsRefusedInTheTestConnectionChild` red, its scoped count included (run 93).
- (CR) mutation: `WalletRung`'s C6 test never turns `WalletSecretUse` off -> its off leg red behind the `CONTROLSECRET` control (run 92).
- (CR) mutation: drop the slug line from `Base.FaultRefused` -> `WalletRungWire.TestARefusalNamesThePairAndLeavesTheDefinitionEnabled` red on `WALLETRUNG.USE` (run 94).
- (CR) mutation: drop the wallet term from `HandleUpdate`'s and `HandleDelete`'s clear -> `AuditVerbs.TestADeleteIsRecordedWithWhatBecameOfItsCredentialEntry` red on both wallet legs (run 95).
- (CR) mutation: `setWallet(false)` always restores the catalog default name, restores the held rung unguarded, keeps `envVarName` as it is, and `setWallet(true)` clears no `envVarName` refusal -> the page spec's four new 18.41 tests red, each on its own mutation (4 of 71).
- (CR) every mutation reverted byte-identical (sha, `git status --short`, `git diff --stat`); runs 96-99 green; component suite 3,093; `definitions.browser-spec.mjs` 11 on the rebuilt, redeployed bundle; `ocupilot-ci` at S0.
- (R1) mutation: `Ladder.WalletTransportRefusal` drops the scheme test -> `WalletRung.TestASecretThatRequiresTlsIsNotReadForAnEndpointThatIsNotHttps` and `TestASecretThatListsHostsIsReadOnlyForAListedHost` red (run 383); `WalletRungWire.TestAnEndpointThatIsNotHttpsFaultsAWalletCallThatRequiresTls` red (run 384).
- (R1) mutation: it drops the host refusal -> `WalletRung.TestASecretThatListsHostsIsReadOnlyForAListedHost` red (run 385); `WalletRungWire.TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall` and `TestTheTlsConfigurationIsJudgedBeforeTheSecretsSettings` red (run 386).
- (R1) mutation: it judges the scheme and the list without `RequireTLS` -> `WalletRung.TestASecretThatDoesNotRequireTlsIsReadWhateverItsHostList` red (run 387).
- (R1) mutation: `Ladder.Wallet` reads the secret before the refusal -> `WalletRung.TestASecretThatRequiresTlsIsNotReadForAnEndpointThatIsNotHttps`, `TestASecretThatListsHostsIsReadOnlyForAListedHost` and `TestTheUseRowIsWrittenOnlyWhileTheEventIsOn` red (run 388); `WalletRungWire.TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall` red (run 389).
- (R1) mutation: the host is compared lower-cased, then the authority is compared with its port -> `WalletRung.TestASecretThatListsHostsIsReadOnlyForAListedHost` red each time (runs 390, 391).
- (R1) mutation: `Ladder.Wallet` skips the use-resource check -> `WalletRung.TestACallerWithoutThePairIsRefusedBeforeAnyRead` and the outsider leg of `TestASecretThatListsHostsIsReadOnlyForAListedHost` red (run 392).
- (R1) mutation: `Base.Invoke` passes the ladder no endpoint -> `WalletRungWire.TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall`, `TestAValueThatOpensWithABraceSendsNoRequest`, `TestTheStoredValueIsTheKeyTheRequestCarries` and `TestTheTlsConfigurationIsJudgedBeforeTheSecretsSettings`, `ProviderSecret.TestNoCredentialMaterialReachesTheLogsOrTheEnvelope` and `WalletRungRoles.TestAPersonWithTheUseResourceReachesTheAdapterWithTheStoredKey` red (runs 393-395).
- (R1) mutation: `WalletRungError.DetailKeyFor` answers `failedPair` for every code -> `WalletRungWire.TestARefusalNamesThePairAndLeavesTheDefinitionEnabled`, `TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall` and `TestAnEndpointThatIsNotHttpsFaultsAWalletCallThatRequiresTls` red (run 398); `WalletRung.TestEveryCodeHasASentenceAndAStatus` red (run 396).
- (R1) mutation: `Codes()` drops `ALLOWEDHOSTS`; `HttpFor` answers 422 for the setting codes; `ReasonFor` drops the `ALLOWEDHOSTS` arm -> `WalletRung.TestEveryCodeHasASentenceAndAStatus` red each time (runs 400-402).
- (R1) mutation: `ProviderPort.Dispatch` skips the refusal for a TLS configuration that is not usable -> `WalletRungWire.TestTheTlsConfigurationIsJudgedBeforeTheSecretsSettings` red (run 399).
- (R1) mutation: `Ladder.Wallet` judges the secret's settings before the custom-use refusal -> `WalletRung.TestASecretThatRequiresTlsIsNotReadForAnEndpointThatIsNotHttps` red on its usage leg (run 416).
- (R1) mutation: `Ladder.WalletEndpointHost` drops its bracketed-IPv6 arm -> `WalletRung.TestASecretThatListsHostsIsReadOnlyForAListedHost` red on the listed literal (run 417).
- (R1) every mutation reverted byte-identical (sha256 before and after) and the tree reloaded; final runs on `ocupilot-ci`, totals read from `%UnitTest_Result`: `WalletRung` 8 (run 418), `WalletRungWire` 10 (419), `WalletRungRoles` 2 (420), `ProviderSecret` 1 (412), `ProviderPort` 20 (413), `ProviderSslCallTime` 3 (414), all green; `check-objectscript.py` and `lint-docs.sh` 0 problems; `ocupilot-ci` at S0.
- (CR-R1) mutation: `Ladder.WalletTransportRefusal` drops the scheme test -> `WalletRungWire.TestAnEndpointThatIsNotHttpsFaultsAWalletCallThatRequiresTls` red, on "no socket was opened" as well, because its `probe-local-` value reaches the stub (run 423).
- (CR-R1) mutation: `Ladder.WalletEndpointHost` keeps a query or fragment that follows the host -> `WalletRung.TestASecretThatListsHostsIsReadOnlyForAListedHost` red on both new legs and on the derived use-row count (run 424).
- (CR-R1) mutation: `Ladder.Wallet` reads the secret before the transport refusal -> `WalletRung`'s RequireTLS and host tests red on their use-row counts, each read after `ControlRow`, and C6 red (run 425).
- (CR-R1) every mutation reverted byte-identical (sha256, `git status --short`, `git diff --stat`) and the tree reloaded; final runs, totals read from `%UnitTest_Result`: `WalletRung` 8 (426), `WalletRungWire` 10 (427), `WalletRungRoles` 2 (428), `ProviderSecret` 1 (429), all green; `check-objectscript.py` 0 problems; `ocupilot-ci` at S0.

**Manual check (implement, `ocupilot-ci`):** the Anthropic key from `.env.local`, read at the point of use and handed to the container through the environment, stored in a probe wallet secret (`OcuPilotProbe1841.live`, all uses); a probe `wallet` definition on `claude-haiku-5-5` created over the wire (201); Test connection answered 200 in 1,036 ms with no fault and left the definition `connectionVerified`; the response carried no `sk-ant` token. The definition, the secret, the collection and the probe resource were then removed, and the throwaway reads S0 (`WalletSecretUse` off, wallet collections `OcuPilotDemo` only, no 1841-named role, resource, user or definition). The key was printed and written nowhere.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented (rework 1, DW-2406):** the wallet rung refuses a secret whose own `RequireTLS` or `AllowedHosts` forbid the endpoint, before the value is read, with `ApplyHTTP`'s semantics: `RequireTLS` set and the endpoint not https is `WALLETRUNG.REQUIRETLS`; `RequireTLS` set, a non-empty list and a host no entry equals is `WALLETRUNG.ALLOWEDHOSTS`; `AllowedHosts` without `RequireTLS` enforces nothing. The one place is `Ladder.WalletTransportRefusal`, run in `Ladder.Wallet` after the pair and usage refusals and before the single `GetSecretValue`; `Base.Invoke` passes the endpoint, and both refusals answer 503 with `detail.setting` and leave the definition enabled. `NewRequest` always sets server-identity checking and the provider path never reaches a proxy without a CONNECT tunnel, so no proxy host is judged.
- **Files:** `Kernel/Secret/Ladder.cls`, `Kernel/Provider/Base.cls`, `Api/WalletRungError.cls`; tests `WalletRung`, `WalletRungWire`, `WalletRungProbe`, `SecretWalletRefusal`.
- **Review:** 15 findings: 3 low patched (the usage-before-settings order, the IPv6 arm, one probe doc), 2 deferred (the jobbed-process chain, already in `deferred:`, and the form caption), the rest rejected with reasons in the triage log.
- **Follow-up review recommended:** false (patched: 3 low).
- **Verification:** on `ocupilot-ci` after the patches `WalletRung` 8, `WalletRungWire` 10, `WalletRungRoles` 2, `ProviderSecret` 1, `ProviderPort` 20, `ProviderSslCallTime` 3, all green; `check-objectscript.py` and `lint-docs.sh` 0 problems; every mutation is in `## Verification`; the throwaway reads S0.
- **Residual risks:** a secret with the vendor-default `RequireTLS` cannot serve a marked-local plain-http model until its `RequireTLS` is cleared on the Secrets screen.
