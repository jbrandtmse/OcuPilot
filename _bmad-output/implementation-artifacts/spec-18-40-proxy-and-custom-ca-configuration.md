---
title: 'Story 18.40: Proxy and custom CA configuration'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: 'f2b40cd5c7666a2fc632079efe9739baaa77c652'
baseline_commit: 'f2b40cd5c7666a2fc632079efe9739baaa77c652'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The call-time check (ruling B) runs in the caller's process, so it does not run for a caller who cannot read Security.SSLConfigs, and that caller's provider call goes through a named configuration or OcuPilotProvider whatever the classic portal has set on it.
    evidence: |-
      Probed on ocupilot-ci with throwaway users: a %Developer user gets <PROTECT> entering %SYS, and a %Operator user's Security.SSLConfigs.Exists answers 0 with ERROR #822 Access Denied, which SslConfigurationMissing already reads as not missing. Both are admitted by ProviderPort's INVOKEPAIRS floor. Closing it needs an elevation to read a configuration, which AD-8 and this story's Never list refuse, or refusing every such caller's turn; the orchestrator's call.
    location: >-
      src/OcuPilot/Port/ProviderPort.cls SslConfigurationUnverified
    severity: high
  - summary: >-
      PROHIBITED.PROVIDERSSL leaves a create of OcuPilotProvider's own name unrefused, so after an out-of-band delete OcuPilot's SSL/TLS form or the agent can re-create it with VerifyPeer 0 until the next start repairs it.
    evidence: |-
      ProviderSsl answers 0 for SSLCONFIG by design, as ruling A states, and OCUPILOTSSL has no create arm (Prohibits answered 0 for a create of OcuPilotProvider with VerifyPeer 0 on ocupilot-ci). The call-time check refuses a call through it for a caller who can read it, and Installer.EnsureSslConfiguration repairs it at every start.
    location: >-
      src/OcuPilot/Kernel/Proposal/Prohibited.cls Created
    severity: medium
  - summary: >-
      Install/Fixture.cls re-creates the demo SSL/TLS configuration with the vendor's default VerifyPeer 0 when it is absent, and a naming of that name made while it was verifying would then read an unverified configuration.
    evidence: |-
      CreateSslConfig sets only Description, so the vendor defaults apply (inference; the fixture was read, not run against a named demo configuration). It leaves an existing configuration untouched, so the path needs the demo configuration deleted while the egress row names it, then a demo start. The call-time check refuses the call for a caller who can read it.
    location: >-
      src/OcuPilot/Install/Fixture.cls CreateSslConfig
    severity: low
  - summary: >-
      ARCHITECTURE-SPINE.md AD-10 still names two routine applications and omits the create refusal under OcuPilotProvider's own name.
    evidence: |-
      AD-10's routine-application sentence reads "Every write to OcuPilotState or OcuPilotIdentity" and its PROVIDERSSL bullet covers only a configuration the egress row names, while this story adds OcuPilotSslRead and refuses a create of OcuPilotProvider itself PROVIDERSSL. The spine is contended with Epic 20, so the in-place edit is the lead's (Rule 20).
    location: >-
      _bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md AD-10
    severity: low
---

<intent-contract>

## Intent

**Problem:** Provider calls read a proxy and an SSL/TLS configuration name from `Kernel.State.Egress`, but no route renders or writes that row, so an operator behind a proxy or a custom CA must edit it from a session.

**Approach:** Switches gains a Provider connection section over `GET`/`PUT /agent/switches/egress`: proxy server and port, and an existing SSL/TLS configuration's name. A named configuration must be an enabled client requiring the server's certificate, so verification stays on and its CA is the operator's own choice, made in that configuration. While named, the kernel protects it as it protects `OcuPilotProvider` (AD-10).

## Boundaries & Constraints

**Always:**

- Merge over the stored row, conditional on `rowVersion`, gated by `OcuPilotAdmin:USE` as every Switches route; an omitted key keeps its value.
- Read a configuration being named in the caller's process, holding its `ssl-configuration` target (AD-34) through the store.
- Judge the proxy host at the write as the call does (AD-42).
- Audit each accepted change (`SecurityChange`, verb `egress`) before and after; no sentence echoes a value.

**Never:**

- A proxy credential: no user name, password or `Proxy-Authorization`.
- Offer `ProxyHttps` or `ProxyTunnel` (the port forces both for https), the timeout or the attempts; each keeps its stored value.
- Set a CA file or any SSL/TLS field from Switches, a per-definition configuration, or move the JWKS fetch off `OcuPilotProvider` (`Port/OAuthRegisteredClientPort.cls` :412).
- A tool, declared read, governance key, screen-context field, page or descriptor for these settings; an elevation to read a configuration (AD-8).
- An edit to `Api/ScreenAction.cls`, `Screen/Tool/Write.cls`, `Screen/Tool/Registry.cls`, `Kernel/Agent/*`, `app.routes.ts`, `screen-outlet.ts`, `panel.ts` or `detail-page.ts` (Epic 20); a code in `Api/Error.cls`.

## I/O & Edge-Case Matrix

Every refusal stores nothing.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Proxy set | `proxyServer` a host name, IPv4 or bare IPv6 address; `proxyPort` 1-65535 | stored; GET answers it | scheme, `/`, `:port`, `@`, space or over 253 characters: 422 `EGRESS.PROXYHOST`; port absent or outside: 422 `EGRESS.PROXYPORT`; resolves to loopback, link-local or this instance: 422 `EGRESS.PROXYADDRESS` (an unresolvable name is stored, as an endpoint is) |
| Proxy cleared | `proxyServer` `""` | `""` and port 0 stored | -- |
| Name a configuration | changed to an enabled client with `VerifyPeer` 1 | stored | absent: 422 `EGRESS.SSLABSENT`; a server, disabled, or `VerifyPeer` not 1: 422 `EGRESS.SSLUNVERIFIED`; held: 409 `WRITE.TARGETBUSY`; without the SSL form's pairs: 403 naming the first, before any read |
| Default | `""` or `OcuPilotProvider` | `""` stored, no Security pair asked | -- |
| Named one weakened | delete, a create under its name, or a change to `Type`, `VerifyPeer`, `CAFile` or `Enabled`, while named [AMENDED 2026-10-13 - see the Spec Change Log] | refused, either caller, every path | 403 `PROHIBITED.PROVIDERSSL`; a failed egress read refuses |
| Call in use | the configuration a provider call would use (the named one, or `OcuPilotProvider`) is absent, disabled, not a client, or `VerifyPeer` below 1, by any path, the classic portal included, for every caller (read through AD-9's SSL-read application) [AMENDED 2026-10-13 - see the Spec Change Log] | the call is refused before any request is sent; nothing reaches the provider [AMENDED 2026-10-13 - see the Spec Change Log] | a provider fault naming the configuration and its remedy (re-enable peer verification on it, or clear the name / restart for `OcuPilotProvider`) |
| Not administrator | no `OcuPilotAdmin:USE` | -- | 403 `AUTH.NOPRIVILEGE` |
| Stale | older `rowVersion` | -- | 409 `STATE.CONFLICT` |

</intent-contract>

## Code Map

Under `src/OcuPilot/`, `54228e70`.

- `Kernel/State/Egress.cls`: header :9-12 (no route renders it), `Resolve` :77, `SetGuarded` :115; `GuardedVersion` sibling `Kernel/State/Switch.cls` :193.
- Call path, unchanged: `Port/ProviderPort.cls` `Dispatch` :261 (settings :301, proxy :307-324, `SslConfigurationMissing` :334, :641); `Kernel/Provider/Base.cls` `NewRequest` :493-518; `Test/ProviderProxy.cls` drives it through `Test.ProviderPortProbe`, whose `Test.ProviderStub` records the request, no socket.
- `Install/Installer.cls` `EnsureSslConfiguration` :3197 (client, `VerifyPeer` 1, `%OSCertificateStore`, enabled, repaired every start); `Kernel/State/Base.cls` `SSLCONFIG` :95.
- Siblings (Rule 31): `Api/Switches.cls` verbs :44-50, `HandleHoldCreate` :202, `MergeBody` :524, `RenderViolations` :594, `LogChange` :606, `IsSecurityChange` :649; `Kernel/SwitchRules.cls` :44; `Kernel/AgentRules.cls` `AddressViolation` :286; `Area/Security/SslRules.cls` `Present` :456, `Gate` :537; `Kernel/Proposal/Operation.cls` `HoldTool` :77, `Release` :100; `Api/AllowListError.cls`.
- `Kernel/Proposal/Prohibited.cls` `OCUPILOTSSL` :245, `Codes` :1005, `ReasonFor` :1013, `Ssl` :5591 (own block :5599), `OcuPilotSslFields` :5622; `Screen/Tool/SslUpdate.cls` own block :152; `Api/Error.cls` :1454.
- `Api/Router.cls` :77-80; `ui/src/app/areas/agent/switches.store.ts` :15-18, `switches.page.ts` holds :214-299, `strings.ts` :704-733; `Test/AuditRecord.cls` `RowFor` :139.

## Tasks & Acceptance

**Task 0** (implement, on `ocupilot-ci` once loaded; halt on a contradiction): as `_SYSTEM`, record what `SslRules.Present` answers for `Type`, `Enabled` and `VerifyPeer` on `OcuPilotProvider` and on probes made in `%SYS`: `OcuProbe1840Server` (server), `…NoVerify` (client, `VerifyPeer` 0), `…Untrusted` (client, `VerifyPeer` 1, no `CAFile`). With the row naming each probe, then a proxy `192.0.2.10:3128` (timeout 5, one attempt), send one `ProviderPort.InvokeDraft` to `https://example.com/` (no provider) with body key `probe`. Record each fault, status and duration, or no outbound route. Remove the probes, restore the row, record under "For the lead".

**Pass 3 state:** everything below is built in the working tree (uncommitted, baseline above) except 7c, 7d and 11b, which this pass adds on top; nothing built is undone.

**Execution:**

1. `Api/EgressError.cls` (new, `AllowListError`'s shape): `EGRESS.PROXYHOST`, `PROXYPORT`, `PROXYADDRESS`, `SSLABSENT`, `SSLUNVERIFIED`, sentences, `Codes`, `ReasonFor`; an `EGRESS.` arm in `Error.ReasonForViolation` beside `ALLOWLIST.`.
2. `Kernel/State/Egress.cls`: `GuardedVersion` as `Switch`'s; replace the :9-12 sentence with the route that writes it.
3. `Kernel/SwitchRules.cls`: `ValidateEgress` (add-only), the matrix's proxy rules (address through `AgentRules.AddressViolation(host, 0, 0)`, a bare IPv6 bracketed as `ProviderPort.ProxyHostOf` :448 does, either code mapped to `PROXYADDRESS`) and, when the name changed to a non-default one, the configuration rules over the fresh read the caller passes.
4. `Api/Switches.cls`: `EGRESSVERB` `egress`, in `IsSecurityChange`. Both handlers refuse a non-administrator first. `HandleEgressRead` answers `{proxyServer, proxyPort, sslConfiguration, rowVersion}`, the name `""` while `OcuPilotProvider` is in force. `HandleEgressUpdate`, in order: JSON object; version, then `Resolve`; merge the three keys by JSON type as `MergeBody`, `OcuPilotProvider` stored `""`, an empty server with port 0. A name changed to a non-default one then takes `SslRules.Gate`, `HoldTool("OcuPilot.Screen.Tool.SslUpdate", name)` and `SslRules.Present` (404 is `SSLABSENT`, other faults `RenderRead`). Then `ValidateEgress`, `SetGuarded` (stale 409), `LogChange`, the GET's answer; `Release` on every exit.
5. `Api/Router.cls`: `GET` and `PUT /agent/switches/egress` before :79; wrappers at the tail.
6. `Kernel/Proposal/Prohibited.cls` (add-only): `PROVIDERSSL` (`PROHIBITED.PROVIDERSSL`) with a caller-neutral reason, appended to `Codes`, a `ReasonFor` line. In `Ssl`, after the own-config block, refuse it on a delete or an `OcuPilotSslFields` change when `ProviderSsl(pId)`. At the end, `ProviderSsl(pId)`: 1 when `EgressStateClass()`'s `Resolve` names exactly `pId`, not `SSLCONFIG`, or the read fails; `EgressStateClass()` answers `OcuPilot.Kernel.State.Egress`.
7. `Screen/Tool/SslUpdate.cls` (add-only, after :152): the same refusal for `ProviderSsl(pIdValue)`, with `PROVIDERSSLREASON`.
7a. `Kernel/Proposal/Prohibited.cls` (add-only), orchestrator ruling A: an arm in `Created` refusing `PROVIDERSSL` for an `ssl-configuration` create whose name `ProviderSsl(pId)` answers 1, whatever the payload carries (the SSL/TLS form's create, the agent's mint and confirm) [AMENDED 2026-10-13 - see the Spec Change Log].
7b. `Port/ProviderPort.cls`, orchestrator ruling B: before each provider call (every turn and Test connection), read the configuration in use (the named one, else `OcuPilotProvider`) and refuse the call, sending nothing, unless it exists, is enabled, is a client and has `VerifyPeer` 1 or more; extend `SslConfigurationMissing`'s existing check (its sibling, Rule 31) and its fault, or add one code beside it in a sibling error class, with a sentence naming the configuration and the remedy. One cheap read per call; no cache that a classic-portal edit could leave stale [AMENDED 2026-10-13 - see the Spec Change Log].
7c. Orchestrator ruling B, option 3 (AD-9's third purpose): the call-time read runs for every caller through a third privileged routine application, the identity read's shape (`Kernel/State/Base.cls` `GuardedUserEnabled`, `Install/Installer.cls` `EnsureIdentityApplication`). Task 0 measures on `ocupilot-ci` the least the role needs to read a configuration's `Type`, `Enabled` and `VerifyPeer` in `%SYS` (`%DB_IRISSYS:R`; add `%Admin_Secure:USE` only if the read demonstrably refuses without it) and records it; the role grants nothing more. `Routines` admits only the one class that does the read. The privileged method takes only the configuration name, shape-validated before the frame, and returns only exists, `Type`, `Enabled` and `VerifyPeer`; no other field leaves the frame. `New $ROLES`, unwound before the provider call; no spawn, no re-entry, no caller-supplied code inside; the application's name read from the instance after install, never recalled. A missing, disabled or no-longer-granting application is handled exactly as the identity read handles its own (`pUnavailable`): the call is refused with a sentence naming the repair, run install again. Lifecycle: an installer ensure step (guard-then-act with drift repair) and the uninstall's removal, its row in OcuPilot's own routine-application roster, and `PROHIBITED.OCUPILOTROUTINEAPP` coverage so no agent edits or deletes it (Story 18.10's). It is created on an upgrade's start like the others [AMENDED 2026-10-13 - see the Spec Change Log].
7d. `Kernel/Proposal/Prohibited.cls` (add-only), condition 8: if the 7a arm in `Created` can also refuse a create of `OcuPilotProvider` itself `PROVIDERSSL` as one more add-only clause, add it with one leg in `ProviderSslNamed.cls` and a `mutation:` line; if it needs more, change nothing and say so, the deferred entry for it then stands.
8. Client: `switches.store.ts` loads and saves `${SWITCHES_PATH}/egress` with `rowVersion`, field violations and conflict, publishes `agent-switch` on save, and counts the edits in `FormDirty`. `switches.page.ts`: Provider connection after the holds section, three fields with hints and Save connection; a privilege refusal's action slot "change the provider connection".
9. Strings: labels, two hints, the action slot, the five `EGRESS` sentences and `PROVIDERSSL`'s, into EXPERIENCE.md in place (:151's text; :344, :349, :485; line count unchanged) and `strings.ts`. 3,316 now, plus 25 (18.46, 18.37, 18.38) and these 14, is within 50 of 3,400: raise `ui/tools/strings.test.mjs` :607-612 to 3,800 under its protocol.

**Tests** (each under 500 lines, each restoring the egress row, as no row or as it was, and removing its probe configurations):

10. `Test/EgressSettingsWire.cls` (new, HTTP, suite account): every matrix row but administrator; GET after PUT; the audit row (`AuditRecord.RowFor`); a held probe's 409; Integration. mutations: no `proxyPort` stored -> GET-after-PUT and Integration red (C1); no `VerifyPeer` rule -> the unverified leg (C2); no `LogChange` -> the audit leg (C5).
11. `Test/ProviderSslNamed.cls` (new, as `SslSave` :275-337): with the egress row naming an absent probe name, a create under that name refused `PROHIBITED.PROVIDERSSL` at Save and at confirm (ruling A) [AMENDED 2026-10-13 - see the Spec Change Log]; with a probe named, a `VerifyPeer`, `CAFile` or `Enabled` change on Save, the list's Delete, an agent change minted before the naming (at confirm) and after it (at mint) are refused `PROHIBITED.PROVIDERSSL` with its sentence; `Description` changes; cleared, the change is permitted; a `Prohibited` subclass whose `EgressStateClass` fails refuses. mutation: `ProviderSsl` answers 0 -> red.
11a. The call-time check (ruling B), through `Test.ProviderPortProbe` and its stub: a named probe configuration flipped to `VerifyPeer` 0 outside OcuPilot (`Security.SSLConfigs` directly, in `%SYS`), and `OcuPilotProvider` flipped likewise, each refuse the call with the fault and send no request; restored after (`OcuPilotProvider` to its installer values), with a `mutation:` line (the check skipped -> red) [AMENDED 2026-10-13 - see the Spec Change Log].
11b. Option 3's legs, against a configuration at `VerifyPeer` 0: a `%Developer`-only caller, an `%Operator` caller and a `%All` caller are each refused before any request; a good configuration serves the `%Developer` caller; the missing-application branch refuses with the repair sentence. mutation: the elevation dropped -> the `%Developer` leg red [AMENDED 2026-10-13 - see the Spec Change Log].
12. `Test/AgentWireSecurity.cls` (a method at the end): a non-administrator is refused both routes, nothing changed; an administrator without `%Admin_Secure:USE` naming a probe is refused 403 naming it and may clear the name. mutation: `SslRules.Gate` skipped -> red.
13. `ui/tools/self-protection.test.mjs`: `KERNEL_REFUSALS` gains `PROVIDERSSL`; `EGRESS_SENTENCES` as `ALLOWLIST_SENTENCES` :858; `Egress).SetGuarded(` in no `src/OcuPilot` class but `Api/Switches.cls` and `Test/`. mutation: the call added to a `Screen/Tool` class -> red.
14. `switches.page.spec.ts` and `ui/browser/switches.browser-spec.mjs`: stored values render, Save connection sends the three keys and `rowVersion`, an `EGRESS.SSLABSENT` reason lands on its field, a reload shows the stored values; the spec restores what it read. mutation: the store drops `proxyPort` -> both red.
15. Rule 30 sweep; run each class changed:
    - Literal changes, 35 to 36 codes: `Test/Prohibited` :766, `AuditingUpdate` :505, `AuthOptionsDescriptor` :166, `EncryptionStartupDescriptor` :138, `SqlPrivilegeDescriptor` :374, `SuperserverDescriptor` :173 (`36 31`).
    - Add-only: `RefusalCopy` :109 (`PROVIDERSSL`); `EndpointCoverage` after :82 (`GET` and `PUT` probes, the `PUT` with `refusal="1"`).
    - Unchanged, run: `SwitchesWire`, `SwitchState`, `SaveHoldCoverage`, `GuardrailsWire`, `SslSave`, `SslUpdate`, `ProviderProxy`, `ProviderSsl`, `DeveloperFloorRoutes`, `InteropFloorRoutes`.

**Acceptance Criteria** (epics.md 18.40):

- **C1.** Given an OcuPilot administrator, when they save a proxy and a configuration name, then `GET /agent/switches/egress` answers them: configuration, not code.
- **C2.** Given a configuration that is not an enabled client requiring the server's certificate, when it is named, then it is refused on its field.
- **C3.** Given a named configuration, when any caller deletes it, creates one under its name, or changes its type, peer verification, trusted certificates or enablement [AMENDED 2026-10-13 - see the Spec Change Log], then it is refused `PROHIBITED.PROVIDERSSL`; once another is named, it is not.
- **C4.** Given the agent, when its tools, reads and screen context are listed, then none reads or writes the provider connection, and only `Api/Switches.cls` writes the row.
- **C5.** Given an administrator, when a save is accepted, then a `SecurityChange` row records the values before and after.
- **C6.** Given the Switches page, when an administrator saves Provider connection, then the section shows the server's answer and a refusal on its field.
- **C7.** Given the configuration a provider call would use, whether named or `OcuPilotProvider`, when it is no longer an enabled client with `VerifyPeer` 1 or more, by any path, the classic portal included, for every caller, then the call is refused before any request is sent, naming the configuration and the remedy [AMENDED 2026-10-13 - see the Spec Change Log].
- **Integration.** Given a proxy and a probe configuration saved through the route, when `Test.ProviderPortProbe` calls, then the stub's request carries `ProxyServer`, `ProxyPort`, `ProxyTunnel` 1, `ProxyHTTPS` 1, the `SSLConfiguration` and `SSLCheckServerIdentity` 1.

## Spec Change Log

- 2026-10-13, lead, second implement halt (B's read needs the security database), orchestrator ruling option 3: the call-time read runs for every caller through AD-9's third privileged routine application (task 7c, test 11b, C7 and the matrix row); condition 8, the `OcuPilotProvider` create after an out-of-band delete, folds into 7a's `Created` arm if it is one more add-only clause, with one test leg, else it waits for the burn-down. AD-9, AD-10 and AD-32 amended.

- 2026-10-13, lead, implement halt (the orchestrator's verification condition), orchestrator ruling A and B: (A) a create under the named configuration's name is refused `PROVIDERSSL` (task 7a, the matrix row, C3); (B) every provider call checks the configuration in use, named or `OcuPilotProvider`, at call time and refuses rather than send without peer verification (task 7b, a matrix row, C7, test 11a). CipherList and TLSMinVersion are out of scope (ledger, burn-down). AD-10 and AD-32 amended in the spine.

- 2026-10-13, lead spec gate: "For the lead" applied in the spine (AD-32, AD-10, AD-42). The `Prohibited.Ssl` clause and task 15's six count pins are the Rule 11 ask to the orchestrator.

## Review Triage Log

### 2026-10-13 — Review pass

- verdicts: 23 findings — high 0, medium 3, low 13, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` no test for a configuration turned into a server at call time (verification-gap) — `ProviderSslCallTime` gains a `Type` leg through a shared `RefusedThenRestored` helper; mutation recorded (run 314, the `Type` leg alone red).
  - `[low]` `[patch]` `ProxyHostShaped`'s group rules had no refusing case (verification-gap) — six refusing inputs and one IPv4-tail acceptance added to `EgressSettingsWire`; mutation `cafe:3128` (run 315).
  - `[low]` `[patch]` proxy host and port refusals rendered by no client test (verification-gap) — one spec asserts both reasons, `aria-invalid` and `aria-describedby`; mutation recorded.
  - `[medium]` `[patch]` a refused connection read on open had no test (verification-gap) — a spec asserts no section, no Save connection and the banner; mutation recorded.
  - `[low]` `[patch]` TLS read pair's uninstall message and residue unpinned (verification-gap, proposed defer) — the message naming both objects is pinned in `SslReadInstall` with its mutation (run 317); the `AnyObjectExists` residue half is rejected: it needs a partly installed fixture and the identity pair shares it.
  - `[medium]` `[patch]` Switches browser spec restored the egress row only in the second block's `finally` (verification-gap) — one outer `try/finally` now restores after a failure in either block.
  - `[low]` `[patch]` mutation lines missing (verification-gap) — `AgentWireSecurity`'s clear-the-name leg recorded (run 316); the Type and host-shape ones are the rows above; the `EndpointCoverage` GET row and `IsSecurityChange`'s arm are not separate ACs (one mutation per AC, already recorded for the PUT row and the audit leg), so no line.
  - `[false]` `[reject]` `TestTheReadLeavesTheCallersRolesAndNamespaceAlone` compares roles in a `%All` process (verification-gap) — `AddRoles` appends the role name to `$ROLES` for `%All` too, so a dropped `New $ROLES` still differs, and the child's `rolesKept` plus the namespace-restore mutation (run 233) carry the rest.
  - `[low]` `[patch]` `PROVIDERSSL` sentence said "while Switches names it" for a create under the default name (verification-gap) — reworded in `Prohibited.cls`, `strings.ts` and EXPERIENCE.md (line count unchanged).
  - `[false]` `[reject]` the Never line "an elevation to read a configuration (AD-8)" against the call-time application (intent-alignment) — the Never line is the naming read in the caller's process; the matrix row "Call in use" names AD-9's SSL-read application itself.
  - `[false]` `[reject]` "Named one weakened, every path" against the classic portal (intent-alignment) — OcuPilot's paths are the kernel's; the classic portal is the "Call in use" row, which the call-time check covers.
  - `[low]` `[defer]` AD-10's text omits the third application and the create refusal under `OcuPilotProvider` (intent-alignment) — recorded in `deferred:`; the spine is the lead's under Rule 20.
  - `[false]` `[reject]` the check runs only for https (intent-alignment) — a plain-HTTP call carries no TLS configuration and the marked-local escape predates the story.
  - `[false]` `[reject]` an unreadable configuration now refuses where the old check proceeded (intent-alignment) — task 7c and the ruling require it, with the repair sentence.
  - `[false]` `[reject]` the name is checked only when changed, the port after the merge, a separate Save connection (intent-alignment) — each is the matrix and tasks 4 and 8 as written.
  - `[false]` `[reject]` the write judges the proxy address with no local escape (intent-alignment) — the auditor found it agrees in effect: the call blanks the proxy for a marked-local definition.
  - `[low]` `[reject]` Type and CAFile changes asserted only at the kernel, the agent's delete only at the list, a failed read only at the kernel (intent-alignment) — every path calls the one kernel `Ssl` arm; one mutation per AC is recorded, so a path-by-path matrix is not worth the lines.
  - `[low]` `[reject]` the call-time legs use a stub transport (intent-alignment) — `Dispatch` is the one seam both entries share, `ProviderStub.Calls()` proves nothing is sent, and the Switches routes have real HTTP legs.
  - `[low]` `[reject]` the TLS fault is asserted on the fault object, not through a turn route (intent-alignment) — same seam, same reason.
  - `[low]` `[patch]` the absent refusal named the configuration but gave no remedy, and the unavailable sentence is a fifth (intent-alignment) — the absent sentence now carries a remedy (`REMEDYTLSABSENT`, `REMEDYTLSABSENTOWN`), mutation recorded (run 344); the unavailable sentence is task 7c's.
  - `[low]` `[patch]` `EgressMerge`'s comment said every non-conforming type becomes `""` (intent-alignment) — a string field ignores another type, as `MergeBody` does; the comment now says so.
  - `[low]` `[reject]` an accepted save that changes nothing still audits and bumps the version (intent-alignment) — the spec audits each accepted change and `SetGuarded` bumps for every save, as the switches save does.
  - `[low]` `[reject]` the browser spec names no real verifying configuration (intent-alignment) — the refusal leg covers the field and `EgressSettingsWire` stores a verifying one over real HTTP.

## Design Notes

**Governing ADs:** AD-8, 9, 10, 12, 14, 15, 19, 20, 21, 32, 34, 35, 39, 42 and 53.

**Trust scope: no owner choice is needed.** OcuPilot never chooses or places a CA: CA files stay "shown, never set" (AD-21), so the operator makes the custom-CA configuration outside OcuPilot and names it. Its trust is theirs; verification stays on because only a client with `VerifyPeer` 1 is accepted. The scope stays AD-32's: provider calls, instance-wide, as the row already is. A per-definition configuration, or JWKS following the named one, would each be a trust-scope choice; neither is built.

**Self-protection (AD-10).** The agent neither reads nor writes its egress: the Switches descriptor declares no read or context field, no tool reaches `/api/ocupilot` (AD-1, AD-40), and task 13 pins the row's one writer. `PROVIDERSSL` stops OcuPilot's paths weakening a named configuration; a classic-portal change is the operator's own (named limit).

**Governance (AD-22):** own configuration, like Switches: no key. **Secrets:** none; an authenticating proxy is a named limit, its credential never in this row.

**Consumes:** `Kernel.State.Egress`, `ProviderPort`, the Switches routes, the SSL/TLS tools and `OCUPILOTSSL` (9.5), `HoldTool` (23.4). **Consumed-by:** every provider call and Test connection, through `ProviderPort.Dispatch` (Integration). **Ledger:** inbox empty.

**For the lead** (Rule 20; append each, tagged `[AMENDED <date>, Story 18.40 spec gate, Rule 20]`):

- **AD-32**, after "Proxy settings are configuration, not code.": **Switches sets the proxy and may name another configuration** (`PUT /agent/switches/egress`): a named one must be an enabled client with `VerifyPeer` 1, read in the caller's process under the SSL form's pairs; a custom CA is such a configuration, its trusted certificates the operator's own; `OcuPilotProvider` stays the installer's and serves the JWKS fetch.
- **AD-10**, a bullet: **The configuration provider calls are made through**: while the egress row names one other than `OcuPilotProvider`, its delete or a change to `Type`, `VerifyPeer`, `CAFile` or `Enabled` is refused `PROHIBITED.PROVIDERSSL` from either caller; a failed read refuses.
- **AD-42**, after "judged by the same policy as the endpoint": and at its write, where a loopback, link-local or own-instance host is refused and an unresolvable one is not.
- **Rule 11.** At plan time Epic 20's diff and `status -s` touch none of these ObjectScript files. The inserted `Prohibited.Ssl` clause is the orchestrator ask; Router rows, count pins, the strings bound and EXPERIENCE.md are unions or in-place edits. No vendor defect candidate found.
- **Task 0 (implement, `ocupilot-ci`, as `_SYSTEM`, 2026-10-13).** `SslRules.Present` answers `Type` as the number 0 or 1, `Enabled` as a boolean and `VerifyPeer` as a number: `OcuPilotProvider` 0, true, 1 (`CAFile` `%OSCertificateStore`); `OcuProbe1840Server` 1, true, 0; `OcuProbe1840NoVerify` 0, true, 0; `OcuProbe1840Untrusted` 0, true, 1.
- The vendor refused two probes as specified: a server without Certificate and Private Key files (#982) and a verifying client with neither `CAFile` nor `CAPath` (#986). They were made with `CipherList` `ADH:@SECLEVEL=0`, empty `Ciphersuites` and TLS 1.2 only (a server needing no file), and with `CAPath` `/etc/ssl/certs` (so the "untrusted" client does verify example.com).
- `InvokeDraft` to `https://example.com/` (`compatible` row, no key, timeout 5, one attempt, body `probe`), no proxy: `OcuPilotProvider`, NoVerify and Untrusted each 502 `PROVIDER.REFUSED` in 0.10 to 0.13 s, example.com having answered with a 4xx, so the route is open and a client with `VerifyPeer` 0 sends; Server 502 `PROVIDER.TRANSPORT` after 15.07 s (a raw `%Net.HttpRequest` GET: #6085, `SSL_accept()` unexpected eof, 15.05 s). With proxy 192.0.2.10:3128 all four were 502 `PROVIDER.TRANSPORT` after 5.01 to 5.02 s, no route to the TEST-NET proxy. A raw GET with no proxy: 200 in 0.11 to 0.12 s for `OcuPilotProvider`, NoVerify and Untrusted.
- The probes, a temporary class and two throwaway users were removed; the egress row was absent before and after; `OcuPilotProvider` read Type 0, VerifyPeer 1, Enabled 1, `CAFile` `%OSCertificateStore` before and after.
- Probed before 7c: a `%Developer` user cannot enter `%SYS` (`<PROTECT>`) and a `%Operator` user's `Security.SSLConfigs.Exists` answers 0 with #822 Access Denied, so the call-time read goes through 7c's application for every caller.
- This pass added 13 strings, not 14: the configuration field reuses `sslFormLabel`. Fixed strings 3,375 to 3,388 on this tree, the bound 3,800 untouched. `Prohibited.Codes()` 35 to 36.
- **Task 0 for 7c (implement, `ocupilot-ci`, 2026-10-13, as principals holding exactly the listed resources; users and roles since removed).** `%DB_IRISSYS:R` alone enters `%SYS`, and `Security.SSLConfigs.Exists` answers 0 with #822 Access Denied (`Get` the same); `%DB_IRISSYS:R` with `%Admin_Secure:U` answers 1 with `Type` 0, `Enabled` 1, `VerifyPeer` 1 for `OcuPilotProvider` and, for an absent name, 0 with #979; `%Admin_Secure:U` alone is `<PROTECT>` entering `%SYS`; `%Admin_Manage:U` or `%Admin_Operate:U` in place of `%Admin_Secure:U` is #822. The least the role needs is `%DB_IRISSYS:R` and `%Admin_Secure:U` (`SSLREADRESOURCES`). Read from the instance after install: the application `OcuPilotSslRead`, `Type` 4, `Enabled` 1, `MatchRoles` `:OcuPilotSslRead`, `Routines` `OcuPilot.Kernel.State.Base:HSCUSTOM:1`, and its role of the same name holding those two resources and no granted role.
- **7c design.** The read, `Base.GuardedSslConfigRead`, lives in `Kernel/State/Base.cls` because `check-objectscript.py` rule 6 confines `New $ROLES` and `AddRoles` there, so the application admits that one class as the identity one does; the identity ensure step became the shared `Installer.EnsureReadApplication` and `GrantsInEffect(pResources)` the shared oracle (Rule 31). `ProviderPort.SslConfigurationMissing` and `SslConfigurationUnverified` are one `SslConfigurationState`; a read that did not answer is `PROVIDER.TLS` with `Provider.Base.REASONTLSUNAVAILABLE`, which names the repair. Rule 30 hits fixed in place: the own-application loops, names and counts in 10 test classes and the client roster `OCUPILOT_ROUTINE_APPLICATIONS` with its pin, specs and browser spec; the own-role list in `Prohibited.OcuPilotRoles` and `RoleDelete`; README. Not changed here, for the lead (Rule 20; the spine is contended with Epic 20): AD-10's sentence naming `OcuPilotState` or `OcuPilotIdentity` also names `OcuPilotSslRead`, and its `PROVIDERSSL` bullet adds a create under `OcuPilotProvider`'s own name.

## Verification

**Commands** (one run per call, `timeout: 600000`; never `ocupilot`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals in `%UnitTest_Result`: tasks 10-12 and every class task 15 names.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`, the bundle measured under the 3527kB warning; `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `node --test --test-concurrency=1 browser/switches.browser-spec.mjs` with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`, 0 problems.

**Shared surfaces:** the `Kernel.State.Egress` row; `Prohibited`'s codes and count pins; the Fixed strings and bound; the route roster; the Switches page; SSL/TLS configurations (probes only).

every test added or changed passes on a fresh environment, in either order

**Mutations (Rule 19):** per test above; implement records each here as `mutation: <change> -> <test red>` once observed.

**Results (final tree, `ocupilot-ci`, 2026-10-14; load LOAD-OK, STARTPATH-OK).** Latest run per class from `%UnitTest_Result`, run index and total/pass/fail:

- The story's classes: `EgressSettingsWire` 319, 6/6/0; `ProviderSslNamed` 312, 5/5/0; `ProviderSslCallTime` 345, 2/2/0 (11a); `ProviderSslCallers` 343, 5/5/0 (11b); `SslReadInstall` 320, 4/4/0; `AgentWireSecurity` 321, 5/5/0.
- Pins and rosters: `Prohibited` 313, 15/15/0; `AuditingUpdate` 328, 11/11/0; `AuthOptionsDescriptor` 329, 10/10/0; `EncryptionStartupDescriptor` 330, 10/10/0; `SqlPrivilegeDescriptor` 331, 11/11/0; `SuperserverDescriptor` 332, 7/7/0; `RefusalCopy` 311, 8/8/0; `EndpointCoverage` 333, 2/2/0.
- Unchanged surfaces: `SwitchesWire` 322, 24/24/0; `SwitchState` 323, 13/13/0; `SaveHoldCoverage` 324, 2/2/0; `GuardrailsWire` 325, 2/2/0; `SslSave` 334, 8/8/0; `SslUpdate` 335, 7/7/0; `ProviderSsl` 336, 7/7/0; `ProviderProxy` 338, 4/4/0; `DeveloperFloorRoutes` 326, 1/1/0; `InteropFloorRoutes` 327, 1/1/0; on the dispatch path `ProviderPort` 341, 20/20/0; `EgressLine` 340, 13/13/0; `AgentConnection` 342, 20/20/0; `Egress` 306, 23/23/0.
- Identity read, installer and own-application roster: `IdentityInstall` 277, 6/6/0; `Disabled` 291, 4/4/0; `UserSignIn` 292, 5/5/0; `State` 293, 12/12/0; `Installer` 297, 27/27/0; `UninstallResidue` 298, 4/4/0; `UninstallSurvival` 294, 2/2/0; `OwnRoutineApplication` 303, 13/13/0; `OwnRoutineApplicationWire` 286, 3/3/0; `RoutineAppWebAppGuard` 287, 2/2/0; `RoutineAppRead` 288, 4/4/0; `RoutineAppWrite` 295, 15/15/0; `RoutineAppMembers` 296, 7/7/0; `RoleDelete` 289, 11/11/0. Run before the last edits, none of which touched their code: `SslWire` 270, `SslSecret` 271, `SslTest` 272, `ProhibitedRoute` 274.
- Client: `npm run test:tools` 1988/1988; `npm run test:components` 245 files, 3,100/3,100; `npm run build` green, initial 1.92 MB (warning 1,992 kB), largest lazy chunk 83.32 kB (`data-browser-page`; cap 88 kB); `switches.browser-spec.mjs` 5/5 on the redeployed bundle; `routine-applications.browser-spec.mjs` 4/4 on the bundle before the review patches. `check-objectscript.py` 0 problems; `lint-docs.sh` 0 issues.

**Mutations observed** (each reverted; `git status --short` and the tree hash identical afterwards; compiled with every descendant):

- mutation: no `proxyPort` stored in `HandleEgressUpdate` -> `EgressSettingsWire` run 131, the GET-after-PUT and Integration legs red.
- mutation: `EnabledVerifyingClient` skips the `VerifyPeer` rule -> run 133, the named-configuration leg red; no `LogChange` -> run 135, the audit leg red; `ValidateEgress` skips the address judgement -> run 137, the refusals leg red; the body's `rowVersion` ignored -> run 139, the stale leg red; the hold dropped -> run 141, the busy leg red; the port 0 for an empty proxy dropped from `EgressMerge` -> run 167, the cleared-proxy leg red.
- mutation: `SslRules.Gate` skipped in `HandleEgressUpdate` -> `AgentWireSecurity` run 143 red; the `IsAdministrator()` arm skipped on the `PUT` -> run 145 red.
- mutation: `ProviderSsl` answers 0 -> `ProviderSslNamed` run 147, 4 of 4 red; the `Created` arm deleted -> run 149, the create leg red; a failed read answers 0 -> run 151, the failed-read leg red; the `Ssl` arm deleted -> run 153; the `SslUpdate.ArgumentProblem` refusal deleted -> run 155, the mint leg red; the names compared case-blind -> run 169, the exact-name leg red.
- mutation: the absent refusal built with the unverified sentence -> `ProviderSslCallTime` run 165 red.
- mutation: the egress `PUT` probe row removed -> `EndpointCoverage` run 159 red alone; `ReasonFor` without `PROVIDERSSL` -> `RefusalCopy` run 161 red; `Codes()` without it -> `Prohibited` run 163 red (the five other count pins share its literal and were not mutated).
- mutation: `Egress).SetGuarded(` added to `Screen/Tool/SslUpdate.cls` -> the writer pin in `self-protection.test.mjs` red; one word of `REASONSSLABSENT` changed, or a sixth code added to `EgressError.Codes()` -> the `EGRESS_SENTENCES` pin red; one word of `PROVIDERSSLREASON` changed -> the kernel-refusals pin red.
- mutation: `proxyPort` dropped from `connectionBody()` in the store -> `switches.page.spec.ts` C1 red, and, after a rebuild and redeploy, the browser leg red on its sent keys; a stored port 0 shown as `0` -> C1 red; the configuration field bound to another violation name -> the C6, C1 and SSLABSENT legs red; the switches phrase used for a connection refusal -> the action leg red; a switches save clearing the one dirty flag -> the shared-flag leg red.

**Pass 4 mutations observed** (each reverted, `git status --short` and the tree hash identical afterwards; compiled with every descendant):

- mutation: a failed `AddRoles` answering instead of quitting unanswered -> `ProviderSslCallers` run 300, the missing- and disabled-application legs red.
- mutation: `AddRoles` of `SSLREADAPPLICATION` replaced by `$$$OK` -> `ProviderSslCallers` run 229, the `%Developer`/`%Operator` refusal leg, the serving leg and the disabled-application leg red (11b's `%Developer` leg); the shape check skipped -> run 231, the disabled-application leg red; the `New $ROLES` frame dropped -> run 238, the refusal leg red on the child's `rolesKept`; the namespace restore after the read dropped -> run 233 red and `ProviderSsl` run 234 `TestThePortsOwnTlsReadAnswersTheInstance` red.
- mutation: the `SslConfigurationState` check skipped in `Dispatch` -> `ProviderSslCallTime` run 240 both legs red, `ProviderSslCallers` run 241 two legs red; an absent configuration read as ok -> `ProviderSsl` run 243 and the `ProviderSslCallTime` absent leg run 244 red.
- mutation: `SSLREADRESOURCES` widened with `%DB_OCUPILOT:RW` -> `SslReadInstall` run 246 shape leg red; the application repair arm of `EnsureReadApplication` skipped -> `SslReadInstall` 248 and `IdentityInstall` 249 red; its role repair arm skipped -> 251 and 252 red; the pair left out of `StateFingerprint` -> 254 oracle leg red; the uninstall's deletion block deleted -> 256 red.
- mutation: `OwnRoutineApplication` without `SSLREADAPPLICATION` -> `OwnRoutineApplication` run 258 (`TestSslReadApplicationRefused`, `TestAnyOtherWriteIsRefused`), `OwnRoutineApplicationWire` 259 (3 of 3), `RoutineAppWrite` 260 (`TestTheOwnApplicationsAreRefusedEveryWrite` and one more), `RoutineAppMembers` 261 (7 of 7) red; `OcuPilotRoles` without the TLS read role -> `RoleDelete` run 263 red.
- mutation: the own-name clause after the `ProviderSsl` arm in `Prohibited.Created` deleted (7d) -> `ProviderSslNamed` run 266, `TestACreateUnderOcuPilotsOwnProviderNameIsRefused` red.
- mutation: `OcuPilotSslRead` dropped from `OCUPILOT_ROUTINE_APPLICATIONS` -> `self-protection.test.mjs` "Story 18.31" leg red; `screen-action-handler.spec.ts` and `routine-app-form.page.spec.ts` three legs red.
- Condition 8 (7d) is done: one more add-only clause in `Created`, refusing a create of `OcuPilotProvider` itself `PROVIDERSSL`, with its leg.

**Review-pass mutations observed** (each reverted, tree hash identical afterwards; the whole tree loaded each time):

- mutation: the `Type` condition dropped from `ProviderPort.SslConfigurationState` -> `ProviderSslCallTime` run 314, the `Type` leg alone red.
- mutation: the group-count floor dropped from `SwitchRules.ProxyHostShaped` -> `EgressSettingsWire` run 315, the `cafe:3128` refusal leg red.
- mutation: `SslRules.Gate` run whenever the name changes, clearing included, in `HandleEgressUpdate` -> `AgentWireSecurity` run 316, the "may clear the name and set a proxy" leg red.
- mutation: the TLS read role's name dropped from `Uninstall`'s "would destroy" message -> `SslReadInstall` run 317, the naming leg red.
- mutation: the remedy dropped from the absent sentence in `Provider.Base.TlsReason` -> `ProviderSslCallTime` run 344, the remedy assertion red.
- mutation: the `@if (proxyPortField.invalid)` reason paragraph deleted from the page -> `switches.page.spec.ts` "proxy host and port refusals" red; `connectionLoadedValue` set on a refused read in the store -> "a connection that cannot be read" red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Story 18.40 as a whole: Switches' Provider connection section over `GET` and `PUT /agent/switches/egress` (proxy server and port, an existing SSL/TLS configuration's name), `Api/EgressError.cls`, `SwitchRules.ValidateEgress`, `PROHIBITED.PROVIDERSSL` (delete, create and the four fields of the configuration the egress row names, plus a create under `OcuPilotProvider`'s own name), and the client section. The last pass added the call-time verification read for every caller (task 7c), condition 8 (7d) and test 11b:

- `Kernel/State/Base.cls` `GuardedSslConfigRead`, through a third privileged routine application `OcuPilotSslRead` (type 4, `Routines` `OcuPilot.Kernel.State.Base:HSCUSTOM:1`, role of the same name). The measured minimal grant is `%DB_IRISSYS:R` and `%Admin_Secure:U`: `%DB_IRISSYS:R` alone gives #822, `%Admin_Secure:U` alone `<PROTECT>`, `%Admin_Manage:U` or `%Admin_Operate:U` in its place #822. Four values leave the frame (exists, `Type`, `Enabled`, `VerifyPeer`); `ProviderPort.SslConfigurationState` refuses absent, unverified and unavailable states before any request.
- Installer: shared `EnsureReadApplication` (the identity step now calls it) with drift repair, the fingerprint fold, `AnyObjectExists`, the uninstall removal and its confirmation text; the application joins `Prohibited`'s own-application roster, `OcuPilotRoles` and the client roster.
- Tests: `ProviderSslCallers` (a `%Developer`, an `%Operator` and a `%All` principal, each refused; a good configuration served; the missing and disabled application refused with the repair sentence) and `SslReadInstall`; `ProviderSslNamed` gains the `OcuPilotProvider` create leg.

**Files.** 60 changed besides this spec, 10 of them new: the API (`Switches`, `Router`, `EgressError`, `Error`), the kernel (`State.Egress`, `State.Base`, `SwitchRules`, `Proposal.Prohibited`, `Provider.Base`), `Port/ProviderPort.cls`, `Install/Installer.cls`, `Screen/Tool/SslUpdate.cls`; the client (`switches.page.ts`, `switches.store.ts`, `strings.ts`, `_components.scss`, `self-protection.ts`); EXPERIENCE.md (in place, line count unchanged), README, `scripts/ci-throwaway.sh` (arming rosters); and the tests, specs and browser specs above and the Rule 30 sweep over the count pins and own-application loops.

**Review (2026-10-13).** 23 findings: 3 medium, 13 low, 7 false. Patched: the call-time `Type` leg, the proxy host-shape cases, the proxy field refusals and the refused-read case in the Switches spec, the browser spec's restore, the uninstall message pin, the `AgentWireSecurity` mutation line, the `PROVIDERSSL` sentence ("while Switches names it, or while it is OcuPilot's own"), a remedy on the absent TLS sentence, and `EgressMerge`'s comment. Deferred: the spine's AD-10 wording (the lead's, Rule 20). Rejected with reasons in the triage log: the `AnyObjectExists` residue leg, path-by-path coverage, the stub transport, and the intent-alignment readings the ruling and the matrix settle. `followup_review_recommended` false: each patch has its demonstrated mutation and none leaves a risk I can name.

**For the lead.** `deferred:` entries 1 (the call-time read for a caller who cannot read the configuration) and 2 (a create of `OcuPilotProvider`) are closed by 7c and 7d; entry 3 (the demo fixture's default `VerifyPeer`) stands. The spine's AD-10 text is the one open edit. Vendor candidate: none.

**Verification.** Every class and mutation is under `## Verification`; the lead re-ran the story's classes on the final tree, `npm run test:tools` 1988/1988, `npm run test:components` 3,100/3,100, `npm run build` (initial 1.92 MB under the 1,992 kB warning, largest lazy chunk 83.32 kB under the 88 kB cap), `switches.browser-spec.mjs` 5/5, `check-objectscript.py` 0 problems and `lint-docs.sh` 0 issues. `ocupilot-ci` reads S0: `OcuPilotProvider` Type 0, Enabled 1, `VerifyPeer` 1, `CAFile` `%OSCertificateStore`; no probe configuration, user or role; no egress row. Residual risk: the call-time read adds a `%SYS` frame to every https provider call (one read, no cache); a start whose install step fails leaves `OcuPilotSslRead` missing and every https call refused with the repair sentence, which is the intended outcome.
