---
title: 'Story 18.40: Proxy and custom CA configuration'
type: 'feature'
created: '2026-10-12'
status: 'blocked'
baseline_revision: '6c24da93ef31df4075e70960e276038ae068b4be'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
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
| Named one weakened | delete, or change `Type`, `VerifyPeer`, `CAFile` or `Enabled`, while named | refused, either caller, every path | 403 `PROHIBITED.PROVIDERSSL`; a failed egress read refuses |
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

**Execution:**

1. `Api/EgressError.cls` (new, `AllowListError`'s shape): `EGRESS.PROXYHOST`, `PROXYPORT`, `PROXYADDRESS`, `SSLABSENT`, `SSLUNVERIFIED`, sentences, `Codes`, `ReasonFor`; an `EGRESS.` arm in `Error.ReasonForViolation` beside `ALLOWLIST.`.
2. `Kernel/State/Egress.cls`: `GuardedVersion` as `Switch`'s; replace the :9-12 sentence with the route that writes it.
3. `Kernel/SwitchRules.cls`: `ValidateEgress` (add-only), the matrix's proxy rules (address through `AgentRules.AddressViolation(host, 0, 0)`, a bare IPv6 bracketed as `ProviderPort.ProxyHostOf` :448 does, either code mapped to `PROXYADDRESS`) and, when the name changed to a non-default one, the configuration rules over the fresh read the caller passes.
4. `Api/Switches.cls`: `EGRESSVERB` `egress`, in `IsSecurityChange`. Both handlers refuse a non-administrator first. `HandleEgressRead` answers `{proxyServer, proxyPort, sslConfiguration, rowVersion}`, the name `""` while `OcuPilotProvider` is in force. `HandleEgressUpdate`, in order: JSON object; version, then `Resolve`; merge the three keys by JSON type as `MergeBody`, `OcuPilotProvider` stored `""`, an empty server with port 0. A name changed to a non-default one then takes `SslRules.Gate`, `HoldTool("OcuPilot.Screen.Tool.SslUpdate", name)` and `SslRules.Present` (404 is `SSLABSENT`, other faults `RenderRead`). Then `ValidateEgress`, `SetGuarded` (stale 409), `LogChange`, the GET's answer; `Release` on every exit.
5. `Api/Router.cls`: `GET` and `PUT /agent/switches/egress` before :79; wrappers at the tail.
6. `Kernel/Proposal/Prohibited.cls` (add-only): `PROVIDERSSL` (`PROHIBITED.PROVIDERSSL`) with a caller-neutral reason, appended to `Codes`, a `ReasonFor` line. In `Ssl`, after the own-config block, refuse it on a delete or an `OcuPilotSslFields` change when `ProviderSsl(pId)`. At the end, `ProviderSsl(pId)`: 1 when `EgressStateClass()`'s `Resolve` names exactly `pId`, not `SSLCONFIG`, or the read fails; `EgressStateClass()` answers `OcuPilot.Kernel.State.Egress`.
7. `Screen/Tool/SslUpdate.cls` (add-only, after :152): the same refusal for `ProviderSsl(pIdValue)`, with `PROVIDERSSLREASON`.
8. Client: `switches.store.ts` loads and saves `${SWITCHES_PATH}/egress` with `rowVersion`, field violations and conflict, publishes `agent-switch` on save, and counts the edits in `FormDirty`. `switches.page.ts`: Provider connection after the holds section, three fields with hints and Save connection; a privilege refusal's action slot "change the provider connection".
9. Strings: labels, two hints, the action slot, the five `EGRESS` sentences and `PROVIDERSSL`'s, into EXPERIENCE.md in place (:151's text; :344, :349, :485; line count unchanged) and `strings.ts`. 3,316 now, plus 25 (18.46, 18.37, 18.38) and these 14, is within 50 of 3,400: raise `ui/tools/strings.test.mjs` :607-612 to 3,800 under its protocol.

**Tests** (each under 500 lines, each restoring the egress row, as no row or as it was, and removing its probe configurations):

10. `Test/EgressSettingsWire.cls` (new, HTTP, suite account): every matrix row but administrator; GET after PUT; the audit row (`AuditRecord.RowFor`); a held probe's 409; Integration. mutations: no `proxyPort` stored -> GET-after-PUT and Integration red (C1); no `VerifyPeer` rule -> the unverified leg (C2); no `LogChange` -> the audit leg (C5).
11. `Test/ProviderSslNamed.cls` (new, as `SslSave` :275-337): with a probe named, a `VerifyPeer`, `CAFile` or `Enabled` change on Save, the list's Delete, an agent change minted before the naming (at confirm) and after it (at mint) are refused `PROHIBITED.PROVIDERSSL` with its sentence; `Description` changes; cleared, the change is permitted; a `Prohibited` subclass whose `EgressStateClass` fails refuses. mutation: `ProviderSsl` answers 0 -> red.
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
- **C3.** Given a named configuration, when any caller deletes it or changes its type, peer verification, trusted certificates or enablement, then it is refused `PROHIBITED.PROVIDERSSL`; once another is named, it is not.
- **C4.** Given the agent, when its tools, reads and screen context are listed, then none reads or writes the provider connection, and only `Api/Switches.cls` writes the row.
- **C5.** Given an administrator, when a save is accepted, then a `SecurityChange` row records the values before and after.
- **C6.** Given the Switches page, when an administrator saves Provider connection, then the section shows the server's answer and a refusal on its field.
- **Integration.** Given a proxy and a probe configuration saved through the route, when `Test.ProviderPortProbe` calls, then the stub's request carries `ProxyServer`, `ProxyPort`, `ProxyTunnel` 1, `ProxyHTTPS` 1, the `SSLConfiguration` and `SSLCheckServerIdentity` 1.

## Spec Change Log

- 2026-10-13, lead spec gate: "For the lead" applied in the spine (AD-32, AD-10, AD-42). The `Prohibited.Ssl` clause and task 15's six count pins are the Rule 11 ask to the orchestrator.

## Review Triage Log

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

## Verification

**Commands** (one run per call, `timeout: 600000`; never `ocupilot`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals in `%UnitTest_Result`: tasks 10-12 and every class task 15 names.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`, the bundle measured under the 3527kB warning; `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `node --test --test-concurrency=1 browser/switches.browser-spec.mjs` with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`, 0 problems.

**Shared surfaces:** the `Kernel.State.Egress` row; `Prohibited`'s codes and count pins; the Fixed strings and bound; the route roster; the Switches page; SSL/TLS configurations (probes only).

every test added or changed passes on a fresh environment, in either order

**Mutations (Rule 19):** per test above; implement records each here as `mutation: <change> -> <test red>` once observed.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: PROHIBITED.PROVIDERSSL as planned does not cover a create under the named configuration's name (verification could be lowered through OcuPilot's own create path); no code written, Task 0 not run.

Implement pass 1 stopped at the orchestrator's verification-stays-on condition before any source edit. Task 6 puts the refusal in `Prohibited.Ssl`, but `Prohibited.Prohibits` sends every create (`CreatesOf` true) to `Created` and quits before `Ssl` is called, and `Created` has no ssl-configuration arm. Path: the named configuration X stops existing (a classic-portal delete, the operator's own named limit); OcuPilot's SSL/TLS form create (`SslSave.HandleCreate`) or an agent `security.ssl.create` then re-creates X with `VerifyPeer` 0; the egress row is unchanged, so no naming-time check runs again, and provider calls resume through X with verification off. Read-only `Prohibits` probes on `ocupilot-ci` (writes nothing): create of an absent name with `VerifyPeer` 0 answers `prohibits=0`; create of `OcuPilotProvider` with `VerifyPeer` 0 answers `prohibits=0`; update of `OcuPilotProvider` `VerifyPeer` 1 to 0 answers `PROHIBITED.OCUPILOTSSL`.

Recommended amendment (the matrix row already promises "every path"): an add-only arm in `Kernel/Proposal/Prohibited.cls` `Created` refusing `PROVIDERSSL` when `pType` is `TYPESSL` and `ProviderSsl(pId)`, whatever the payload carries (covers `SslSave` create and the agent's mint and confirm); `Test/ProviderSslNamed` gains a leg (egress row naming an absent probe name, a create refused at Save and at confirm); AD-10's new bullet and the matrix row read "delete, a create under its name, or a change to ...". The same arm also leaves `OcuPilotProvider` unguarded after an out-of-band delete (not reachable in practice: `EnsureSslConfiguration` repairs it every start).

Residual (inference, not verified): `CipherList` and `TLSMinVersion` are settable and are not among `Type`, `VerifyPeer`, `CAFile`, `Enabled`; `OcuPilotProvider` has the same exposure today, so it is not part of this stop.

Facts for the re-dispatch: `Prohibited.Codes()` holds 35 entries on this tree (so 36 after); Epic 20's diff touches `Test/Prohibited.cls`, `strings.ts`, `strings.test.mjs`, EXPERIENCE.md, `Screen/Context.cls`, `Write.cls`, `ExplorerSave.cls`, `Baseline.cls`, `panel.ts`, `screen-outlet.ts` and not `Kernel/Proposal/Prohibited.cls`, `Api/Switches.cls`, `Api/Router.cls`, `Kernel/SwitchRules.cls`, `Kernel/State/Egress.cls` or `Screen/Tool/SslUpdate.cls`; `SaveHoldCoverage`'s `PUT /agent/` exemption already covers the egress route; `ProviderPort.ProxyHostOf` is Private, so `SwitchRules` copies its bracketing. `ocupilot-ci` was only read (no probe configuration, no egress write); scratch probes are under `.coordination/carry-2026-10-10/epic-18-r/18-40/`.
