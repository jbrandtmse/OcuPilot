---
title: 'Story 18.25: Superservers'
type: 'feature'
created: '2026-10-07'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Superservers are still classic-only (`%CSP.UI.Portal.Servers` and `.Server`, both `%Admin_Secure`). The admin API carries them through `Security.Superserver`: `GET /security/superservers` and `GET`/`PUT`/`DELETE /security/superserver?port=&bindAddress=`. One of them is the superserver the Web Gateway connects through, so a careless change cuts OcuPilot off.

**Approach:** A Security list at position 12 and an unlisted editor form. Three tools on a small `SuperserverPort` that splits the composite id `[Port, BindAddress]` into the vendor's two query parameters. A new AD-10 arm refuses, from both callers, every change that would stop the serving superserver serving the gateway.

## Boundaries & Constraints

**Always:**

- **Screens.** One declared read (`Security.Superserver` `LIST`: `Port`, `BindAddress`, `Enabled`, `SystemDefault`) serves the list and `security.superservers.read` (AD-36). The editor reads through its own form route.
- **Tools and keys.** `security.superservers.create` (AD-54, absence fingerprint; the `PUT` upserts, 201 measured), `.update` (merge, AD-4) and `.delete`. Each has two callers (AD-53, AD-55). Baseline keys: create `true`, update `true`, delete `false` (AD-22: destructive ships off).
- **`SystemDefault`** is shown and never set. It is in no tool's permitted fields, and no body ever carries it (the classic editor never sets it; AD-4's named exception).
- **Rules before any `PUT`.** Every condition in the matrix's Rules row is refused before any `PUT`, on both callers, as a field violation carrying OcuPilot's own sentence. A vendor refusal answers 500 and is logged at severity 2 (AD-2), so the rules keep every predictable one away from the vendor.
- **Saves.** Each Save takes `Operation.HoldTool(<tool>, <canonical id>)` before its fresh read (DW-1882, AD-34). Each reads back (AD-58) and emits a change event naming its tool (AD-14).
- **The arm.** It lives once in `Kernel/Proposal/Prohibited.cls` (AD-10), reads live state at the write and is pinned by tests that redden when it is removed.
- **Error codes** go in `Api/SuperserverError.cls` (prefix `SUPERSERVER.`). `Api/Error.cls` gains only its two dispatch lines.
- **Probes and tests.**
  - Every probe that writes configuration runs on `ocupilot-ci` only, on ports 21825-21829. Each restores S0 and leaves the monitor state at 0.
  - One test class per call.
  - Shared rosters take add-only edits, because Epic 20 runs in parallel.

**Never:**

- **No write to the serving superserver.** No test, probe or browser spec sends a `PUT` or `DELETE` for 1972 (the system default and the gateway's superserver on every throwaway) to the vendor. Every leg aimed at it runs through `Test/SuperserverSeamPort`, which forwards writes for ports 21825-21829 only. No browser spec presses Save or Delete on 1972.
- No AD-27 named case. No `rowGet` (the vendor `GET` needs two query parameters; a named limit). No change to the system default superserver, which the classic Memory and Startup page owns.
- No bare `git stash`. Strings stop at `strings.test.mjs`'s bound unless the lead moved it at the spec gate (Design Notes › For the lead).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | List open, or agent `security.superservers.read` | The same rows from one read; 1972 lists `BindAddress` `0.0.0.0` | Missing pair: 403 naming it |
| Create | Port 21825, `BindAddress` empty, `EnableCSP` on | 201, listening at once (measured). Read-back `matches`. The id is `21825`+`0.0.0.0` | Taken name: the absence fingerprint refuses |
| Update | Probe `Description` changed | Complete set less `SystemDefault` sent; others kept | Moved target refused; held lock 409 `WRITE.TARGETBUSY` after 10 s |
| Delete | Probe superserver | Absent after; listener closed (measured) | Absent: 404 `PORT.NOTFOUND` |
| Rules | `Port` outside 100-65535 or not a whole number; `Description` over 256; `SSLSupportLevel` not 0-2; level 1 or 2 with `SSLConfig` empty, absent or not a server configuration; a changed non-empty `SSLConfig` that is absent or not a server configuration; `EnableECP`, `EnableMirror` or `EnableSharding` on a superserver that is not the system default; `EnableSNMP` off Windows; a flag not `true`/`false` | 422 `SUPERSERVER.*` on the field. Nothing sent | Mint refuses identically |
| Port taken | Create on a port another process holds (2188, measured), or `Enabled` turned on there | 409 `SUPERSERVER.PORT.INUSE` on `Port`; nothing stored (measured) | Vendor text logged, never sent |
| Serving refused | On a serving superserver: delete, `Enabled` off, `EnableCSP` off, `SSLSupportLevel` raised to 2 | `PROHIBITED.SERVINGSUPERSERVER` from both callers before any write. The form draws `Enabled` and `EnableCSP` `aria-disabled` with the sentence | A failed target read refuses |
| Serving SSL change | Any other `SSLSupportLevel` or `SSLConfig` change on a serving superserver | Permitted. Agent: destructive proposal with consequence `SUPERSERVER.SERVESOCUPILOT`. Person: the caption at the field | None expected |
| Turn mint | The agent mints in the turn job (no gateway socket) | Judged by the system default alone; the confirm judges both | Confirm refuses what the mint let through |

</intent-contract>

## Code Map

Analogs: **18.20's ECP data servers** (a list plus an unlisted form; create, update, delete), **18.14's mappings** (a composite id, a generic list, and a port that splits the id) and **18.8's** arm, form locks and seam port.

**Server analogs:**

- Descriptors:
  - `Screen/Descriptor/EcpDataServerList.cls` and `EcpDataServerForm.cls` (routes :24/:20, positions, table, prompts).
  - `GlobalMappingList.cls:20` and `GlobalMappingForm.cls:34`: `"id": {"kind": "composite", "parts": [...]}`.
  - `Screen/Registry.cls:2603-2607` refuses a part not in `read.fields`.
- Tools:
  - `Screen/Tool/EcpDataServerCreate.cls` (`CREATES` :26, `DEFAULTS` :44, `CLASSICPAGES` :55, `ArgumentProblem` :133, `PrivilegePairs` :146).
  - `EcpDataServerUpdate.cls` (`SENDSBODY` :27).
  - `EcpDataServerDelete.cls` (`DESTRUCTIVE` :33, `FINGERPRINTSUBJECT` :43, `StateDiff` :80).
  - `Screen/Tool/MappingMint.cls`: builds the composite from two arguments and refuses `$Char(1)`. Copy it as `SuperserverMint`.
- Port: `Port/NamespacePort.cls` `Invoke` :90, `MappingQuery` :198, `Snippet` :238. It splits a composite id, sends a malformed one to 404 without a vendor call, and mirrors the split in `Snippet` (AD-59).
- Rules and Save:
  - `Area/OsMgmt/EcpRules.cls` (`Validate` :60, `Problem` :126, `HandleForm` :208, `Gate` :335).
  - `Area/OsMgmt/EcpDataServerSave.cls` (`HandleCreate` :55, `HandleUpdate` :89, `HoldTool` :71/:104).
  - Delete runs only as a row action and a confirm, as for ECP.
- Errors: copy `Api/EcpError.cls` and `Api/WebAuthError.cls`. Dispatch goes in `Api/Error.cls:1229` and `:1432`, beside `WEBAUTH.`.
- Routes: `Api/Router.cls:246-247` (place the new ones beside them): `GET /superserver/form`, `PUT /superserver/:id`, `POST /superserver`, with the sub-resource first.
- Vendor faults: `Port/AdminPort.cls` `PROPERTYFAULTS` :3302 (precedent `Security.Encryption.Settings:5001`, scoped by the port; doc :3270-3301), `PropertyViolations` :3307.

**Kernel:**

- `Kernel/EntityType.cls` `TYPES` :89 (58; add `superserver`).
- `Kernel/EntityRef.cls`:
  - `IDRULES` :59 (add `superserver:portbind`), `IDRULENAMES` :64.
  - Rule constants :67-147; `NormalizedId` :280-301.
- `Kernel/EntityId.cls` `JoinComposite` :74, `SplitComposite` :81.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250; `TYPE*` constants :253-662.
  - `SERVINGSERVICE` :719-728 (the family); `Codes()` :851 (30).
  - `Prohibits` :1201: the fail-closed list :1212 and type dispatch :1325-1450.
  - `WeakensByEffect` :1696; `AuthOptions` :2740 and `SignInLocks` :2861 (the lock idiom); `ServingSessionId` :5271 (the serving-request precedent).
- `Kernel/Proposal/Mint.cls:335-344` (effect → destructive and consequence) and `ConsequenceOf` :780.
- `Kernel/Governance/Baseline.cls`: insert after `security.ssl.update` :146. `Screen/Tool/Classification.cls`: ECP entries :840-859. Regenerate `ToolFields.cls` with `bash scripts/field-lists.sh`.
- Already present: `Screen/Tool/FieldLists.cls:596-614` (16 fields), `Port/AdminRoutes.cls:207-208`, `Test/AdminInventory.cls:103`.

**Client:**

- Form page and store:
  - `areas/os-management/ecp-data-server-form.page.ts` and `.store.ts`;
  - the composite-id form `areas/os-management/mapping-form.store.ts:489,508`;
  - the lock idiom `areas/security/auth-options.page.ts`.
- `core/entity-ref.ts` `ID_RULES` :116-183 (add `portbind`) and `ui/tools/screen-mirror.mjs` `IMPLEMENTED_ID_RULES` :162.
- `core/entity-id.ts` `joinCompositeId` :41.
- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :149 (the form only; the list is the generic `ListPage`).
- `shell/screen-action-handler.ts`: delete registration and consequence, as the mapping lists do at :89-91, :231-234, :440-442 and :504-505. The typed name is the port.
- `app.ts:696` (sign-out reset); `core/proposal-view.ts` (consequence codes); `core/strings.ts` (one key per value; reuse equal values).

**Pins a Security screen extends:**

- `ui/tools/navigation.test.mjs:268-286` and `:600-604`.
- `Test/Wire.cls:605`.
- `Test/WireSecurityRead.cls:848,999,1028,1137,1157`.
- `Test/WireOAuthRead.cls:300-379`.
- `Test/WireAreaAnyScreen.cls:289,297`.
- `ui/src/app/shell/area-verdict.spec.ts:227`.
- `scripts/ci-throwaway.sh`: the `OCUPILOT_ALLOW_SERVICE_CONFIG` roster :470-482 and the `OCUPILOT_ALLOW_PRINCIPALS` roster :345-372.

**EXPERIENCE.md** (1039 lines):

- Side-bar table, Security row :168.
- Fixed strings, Security row :364.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci`). Record each result in Design Notes › Measured at Task 0. Restore S0. Halt on any contradiction with Measured at plan.

1. Record S0 (Verification › S0).
2. A JOB'd process's `$PRINCIPAL` (the turn job's shape): a test-scope helper stores it in a scratch global, which is then killed.
   - Expected: not a `|TCP|<port>|…` device (inference at plan).
   - Halt if it names a superserver port.
3. If the vendor lets a server-type SSL/TLS configuration `OcuProbe1825TLS` be created without certificate files, do so. Then send `SSLSupportLevel` 1 with it on probe 21825, and record the answer. Restore, and delete the configuration. If the vendor refuses the configuration, record that (the success path is then a named limit).
4. Halt if anything outside S0 remains.

**Execution (server):**

- `Kernel/EntityType.cls`: add `superserver`.
- `Kernel/EntityRef.cls`: the rule `portbind` and the pair `superserver:portbind`.
  - The port in `RULEINTEGER`'s plain decimal spelling.
  - The bind address `0.0.0.0` when empty, otherwise folded to lower case.
  - A value with no separator reads as `[value, ""]`.
- `Port/SuperserverPort.cls` (new; extends `AdminPort`):
  - On `Security.Superserver`, a query without `bindAddress` has its id split into `port` and `bindAddress`. A malformed id answers 404 with no vendor call.
  - A `PUT` answered 500 #5001 is answered 409 `SUPERSERVER.PORT.INUSE` on `Port` when the write would start a listener (a create, or `Enabled` turned on). Any other #5001 keeps the port's 500. Add the `PROPERTYFAULTS` row.
  - `Snippet` mirrors every branch.
- `Screen/Tool/SuperserverMint.cls` (new): the composite id from `Port` and `BindAddress`.
- `Screen/Tool/SuperserverCreate.cls`, `SuperserverUpdate.cls` and `SuperserverDelete.cls` (new):
  - Common: `DESCRIPTORCLASS` `SuperserverList`, `PORTCLASS` `SuperserverPort`.
  - Permitted fields: the 16 template fields less `SystemDefault`; create also takes `Port` and `BindAddress` (the id).
  - Create and update: `CLASSICPAGES` `%CSP.UI.Portal.Server`. `ArgumentProblem` calls `SuperserverRules.Problem`.
  - Update: `MergeUpdate` drops `SystemDefault`. `Consequence` answers the effect.
  - Delete: `DESTRUCTIVE`; `FINGERPRINTSUBJECT` `SystemDefault`.
- `Screen/Descriptor/SuperserverList.cls` (new):
  - Route `security/superservers`; listed at 12; `list`; scope `instance`.
  - Id: composite `["Port","BindAddress"]`.
  - Security's two pairs.
  - Primary action create; row action delete.
  - The read and table: Port as the name column, then BindAddress, Enabled and SystemDefault.
  - Classic page `%CSP.UI.Portal.Servers`; three prompts.
- `Screen/Descriptor/SuperserverForm.cls` (new): route `security/superservers/edit`; position 0; `form-page`; the same id; classic page `%CSP.UI.Portal.Server`; three prompts.
- `Screen/Tool/Classification.cls`: all 16 fields `ordinary`. Then regenerate `ToolFields.cls`.
- `Area/Security/SuperserverRules.cls` (new):
  - `Validate` and `Problem`: the matrix's Rules rows. `SSLConfig` is read through `AdminPort` `Security.SSLConfig` `GET`; `Type` 1 is server (inference: `OcuPilotDemoTLS` reads 0 and lists `Client`).
  - `HandleForm` (`GET /superserver/form?id=`): `{row (with Port and BindAddress), serving, locked, windows}`, `windows` from `$SYSTEM.Version.GetOS()`. On create, it answers the vendor defaults measured at plan.
  - `Gate`.
- `Area/Security/SuperserverSave.cls` (new): `HandleCreate` and `HandleUpdate`. The order is `HoldTool`, then the rules, then the prohibited set through the operation, then the `PUT`, then the read-back, then `{readBack, consequence}`.
- `Kernel/Proposal/Prohibited.cls`:
  - `TYPESUPERSERVER`; `SERVINGSUPERSERVER` and its reason (the published sentence); `EFFECTSERVINGSUPERSERVER`.
  - `ServingSuperserverPort()`: the local port of `$PRINCIPAL` when it reads `|TCP|<digits>|`, else `""`. It is read before any port call, as `ServingSessionId` is.
  - Pure `ServingPortOf(pPrincipal)` and `IsServingSuperserver(pId, pTarget, pServingPort)`. A superserver is serving when its fresh read's `SystemDefault` is true, or its id's port equals the serving port, whatever its bind address. A create's absent target is never serving.
  - `Superserver(...)` refuses the matrix's four refusals. A failed target read refuses.
  - `WeakensByEffect`: the SSL effect.
  - `SuperserverLocks()` for the form.
  - Update `COVEREDTYPES`, the fail-closed list, the dispatch and `Codes()` (31).
- `Api/SuperserverError.cls` (new) and the two `Api/Error.cls` lines. `Api/Router.cls`: the three routes, with thin calls.
- `Kernel/Governance/Baseline.cls`: the three keys.

**Execution (client):**

- `areas/security/superserver-form.page.ts` and `.store.ts` (new):
  - Sections in the classic order: general; client connections (Clients, CSP/REST, DataCheck, SSL support level and configuration, legacy Cache Direct and Shadows); system connections (ECP, Mirroring, Sharding); other (SNMP, legacy WebLink and Node.js).
  - `Port` and `BindAddress` are editable on create only. `SystemDefault` is read-only, with a hint naming the classic Memory and Startup page.
  - ECP, Mirroring and Sharding are disabled unless the row is the system default. SNMP is disabled off Windows. Each has its hint.
  - The SSL configuration picker issues the SSL/TLS list's declared read and offers its `Server` rows (AD-5).
  - `locked` fields are `aria-disabled`, with the sentence through `aria-describedby`.
  - The consequence caption shows at a changed SSL field on a serving superserver.
  - A sticky Save and an unsaved-changes guard.
- Wiring: `screen-outlet.ts`; the delete's registration in `screen-action-handler.ts`; `app.ts`; `proposal-view.ts`; `strings.ts`; `entity-ref.ts` and `screen-mirror.mjs` (`portbind`).
- EXPERIENCE.md:
  - The side-bar entry.
  - One Fixed-strings addition to the Security row: labels, hints, the refusal, the consequence, the delete consequence, six prompts and the side-bar label. Each sentence is published once.
  - Fix every shifted `EXPERIENCE.md:n` comment.
- Regenerate `screens.generated.ts`. Re-base `angular.json` `maximumWarning` and `angular-json.test.mjs` to the measured total if crossed (DW-1166); stop above 3800kB.

**Tests:**

- `Test/SuperserverDescriptor.cls`:
  - both descriptors, the entity type and the `portbind` canonical forms (`01985`→`1985`, `""`→`0.0.0.0`, `LOCALHOST`→`localhost`);
  - the classification;
  - the baseline values;
  - no tool permits `SystemDefault`.
- `Test/SuperserverRead.cls`:
  - the screen and the tool answer one set of rows;
  - the form read answers 1972 as `serving` with `locked` `Enabled` and `EnableCSP`, and a probe as not serving.
- `Test/SuperserverWrite.cls` (armed by `OCUPILOT_ALLOW_SERVICE_CONFIG`; `OnAfterOneTest` deletes every 21825-21829 superserver; the Save reaches the seam through a fixture, as `Test/AuthOptionsSaveFixture.cls` does):
  - create, update and delete through both callers;
  - no `PUT` body carries `SystemDefault` (the seam records bodies);
  - every Rules row refused with no `PUT`;
  - the absence fingerprint;
  - moved and busy targets;
  - `PORT.INUSE` through the seam answering the measured #5001 fault, with no vendor call.
- `Test/SuperserverGate.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS`): a principal holding exactly Security's pairs does every operation on a probe; without `%Admin_Secure:USE` each is refused by name before any port call.
- `Test/SuperserverProhibited.cls`:
  - Through `Test/SeamSuperserverUpdate.cls` and `SeamSuperserverDelete.cls` (on `Test/SuperserverSeamPort.cls`), the four refusals on 1972 from both callers, with zero writes recorded.
  - The SSL change minted destructive with its consequence.
  - The pure legs: `ServingPortOf("|TCP|21825|9")` is 21825 and `"/dev/null"` is `""`; a non-default target matching the serving port is serving.
  - A JOB'd process's serving port is `""`.
- `Test/EntityRef.cls` and `ui/tools/entity-ref.test.mjs`: `portbind`.
- Rosters:
  - `Descriptor` (`EntityType.Count()` 59), `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `DraftRegistry`;
  - `Governance`, `GovernanceBaseline`;
  - `Prohibited` (`CoveredTypes`, `Codes` 31), `AuditingUpdate`, `EncryptionStartupDescriptor` (the code counts);
  - `ClassicPageGate`, `ScreenRead`;
  - the Security pins in the Code Map, and the two `ci-throwaway.sh` rosters.
- `areas/security/superserver-form.page.spec.ts` and `.store.spec.ts`.
- `ui/tools`: `navigation`, `self-protection` (`KERNEL_REFUSALS`), `proposal-view`, `screen-mirror`, `field-lists`, `strings`, `angular-json`, `ci`.
- `ui/browser/superservers.browser-spec.mjs` (new):
  - the list reached from the side bar;
  - create 21825 on the form, change its `Description`, delete it with the typed port;
  - 1972's editor draws `Enabled` and `EnableCSP` `aria-disabled` with the sentence;
  - an after hook deletes 21825 through the admin API.

**Acceptance Criteria:**

- **B0.** Given Task 0 on `ocupilot-ci`, when steps 1-4 run, then each result is recorded, and the throwaway reads as S0.
- **B1.** Given the Superservers list and `security.superservers.read`, when each reads, then both answer the same rows from one read, and the editor answers the 16 fields with `Port` and `BindAddress`.
- **B2.** Given a probe superserver, when it is created, changed and deleted from the screen and from a confirmed proposal, then the instance holds each result, the read-back reads `matches` (absent after a delete), no body carries `SystemDefault`, and a taken name, a moved target, a held lock and a taken port are refused as the matrix says.
- **B3.** Given each Rules row, when either caller sends it, then it is refused on its field before any `PUT`.
- **B4.** Given the superserver the Web Gateway connects through, when a change would delete it, disable it, turn off its web connections or require SSL/TLS, then it is refused `PROHIBITED.SERVINGSUPERSERVER` on the instance from both callers before any write, and the form draws `Enabled` and `EnableCSP` `aria-disabled` naming the sentence. An SSL change to it that is not refused mints destructive and states its consequence.
- **B5.** Given the rosters, when the suites run, then:
  - Security lists Superservers at 12;
  - each screen carries three prompts;
  - the keys read create `true`, update `true`, delete `false`;
  - `superserver` and `portbind` are pinned on both sides;
  - the refusal sentence is published once and pinned;
  - the Fixed strings stay within the bound.
- **Integration.** The page consumes `GET /superserver/form`, `PUT /superserver/:id`, `POST /superserver` and the delete row action. The agent consumes the read tool and the three write tools. Each runs on `ocupilot-ci` (B1-B4 and the browser spec).

## Spec Change Log

- 2026-10-07, spec gate (lead): Decisions 1-6 confirmed. The Fixed-strings bound moves to 2900 under the protocol (this story adds the protocol comment line in `ui/tools/strings.test.mjs`; Epic 20 may move it too, unioned at merge). Spine amendments 1-5 written (AD-10, AD-13, AD-4, AD-8, AD-44). DW-2007 gains `Security.Superserver` `PUT` #5001 as an occurrence. The two vendor candidates are DW-2146 and DW-2147, under the owner's hold.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27: `AdminPort` only, through `SuperserverPort`; no named case.
- AD-3: the derived list of 16 fields, all `ordinary`.
- AD-4: merge; `SystemDefault` omitted.
- AD-5, AD-36, AD-44: two descriptors, one read, the classic pages.
- AD-6, AD-34, AD-40, AD-53, AD-54, AD-55: two callers; HoldTool; create absence.
- AD-8, AD-29: Security's set (measured).
- AD-10: the arm. AD-13: the composite id. AD-14: the change event.
- AD-15: ordinary; the vendor records `%System/%Security/ServerChange` for create, modify and delete (measured).
- AD-22: keys. AD-39: own sentences. AD-58: read-back. AD-59: `Snippet`.

**Measured at plan** (`ocupilot-ci`, 2026-10-07, through the admin API; each probe deleted, and S0 re-read):

- **Create and modify.**
  - A minimal `PUT ?port=1985` answered 201. It stored `BindAddress` `0.0.0.0`, `Enabled` and `EnableClients` on, and every other flag off (`EnableCSP` included), and listened at once.
  - A partial `PUT` kept every key it did not send.
  - `Enabled` off closed the listener at once, and on reopened it.
- **Identity.**
  - `bindAddress` omitted, empty or `0.0.0.0` reached one record. `LOCALHOST` reached `localhost`.
  - `127.0.0.1` and `localhost` are stored as given; neither is found without its `bindAddress`.
  - LIST answers `BindAddress` `0.0.0.0`, and the `GET` answers neither key.
- **Refusals** (each 500, nothing stored, the whole body refused):
  - #1475: level 1 or 5 with no configuration, or with a client configuration.
  - #979: an absent configuration at level 1. **An absent `SSLConfig` was stored at level 0.**
  - #1478: ECP, Mirror or Sharding on a non-default superserver.
  - #1479: SNMP on Linux.
  - #7201-#7207: datatype errors (port 99, port 65536, `abc`, a 300-character `Description`, `"maybe"`).
  - #5001 "Could not start superserver N, may be in use by another instance": port 2188 (ISCAgent), and a wildcard 1986 over a `127.0.0.1` 1986.
  - An unknown body key answers 400 #40307.
- **Pairs.** A principal holding exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ` listed, read, created, changed and deleted. It was then deleted.
- **The gateway's superserver.**
  - The instance's `CSP.ini` `[LOCAL]` reads `127.0.0.1:1972`, with no TLS setting.
  - Every CSP server process (JobType 27) reads `CurrentDevice` `|TCP|1972|<pid>`.
  - A request's own `$PRINCIPAL` read `|TCP|1972|10543`, and `$SYSTEM.TCPDevice.LocalPort()` read 1972. This was measured read-only on slot A's `ocupilot`, through a request served by its gateway.
- **End state.** One record (1972, as S0), the listeners as S0, monitor 0, no `OcuProbe1825*` principal.

**Decisions** (the lead confirms them at the spec gate):

1. **Which superserver serves.** Either one is serving:
   - the system default, which the instance's own gateway configuration names and which the classic documentation keeps on for portal access;
   - the one whose port the serving request arrived through.

   A gateway that serves through another port is caught at confirm, because the confirm is itself a request through it. The turn job has no such socket. Reading the process table was rejected: the admin API's `Process` `LIST` carries `Device` (so AD-27 rules out `%SYS.ProcessQuery`) but would add `%Admin_Operate:USE`. The gateway registry was rejected: it calls the gateway and needs `%Admin_Manage:USE` or `%Admin_Operate:USE`.
2. **A new code in AD-10's serving-path family, `PROHIBITED.SERVINGSUPERSERVER`.**
   - The epic context names `SERVINGSERVICE`, but that code's sentence ("this service … Turning it off") does not describe a delete or a TLS requirement. 18.8's `OCUPILOTSIGNIN` is the precedent.
   - Reverting is one parameter and one sentence.
   - The epic context's "changing its address or authentication methods" has no subject here: the address is the id, and a superserver has no authentication methods.
3. **SSL changes are permitted, not refused,** apart from raising the level to Required. Whether the gateway connects with TLS cannot be read on the instance, so each such change is destructive and carries its consequence.
4. **The list carries the four `LIST` fields.** The classic list shows those columns.
5. **A taken port is mapped but still logged.** `Security.Superserver` `PUT` #5001 joins DW-2007's code-scoped unlogged list when 18.28 builds it (For the lead).
6. **No row-level self-protection rule.** The delete's click answers the refusal, as a database delete does. The form locks the two flags.

**Published sentences** (the server reason equals each one):

| Code | Sentence |
| --- | --- |
| `PROHIBITED.SERVINGSUPERSERVER` | "The web gateway reaches this instance through this superserver, and OcuPilot is served through it. Deleting it, disabling it, turning off its web connections or requiring SSL/TLS would cut off every user, including you." |
| `SUPERSERVER.SERVESOCUPILOT` | "OcuPilot is served through this superserver. An SSL/TLS change can stop the web gateway connecting through it, which would cut off every user, including you." |
| delete consequence | "Clients can no longer connect through this port, and the superserver stops listening at once." |

The `SUPERSERVER.*` rule sentences live on the server alone (AD-39; the 18.8 precedent).

**Named limits:**

1. A turn's mint judges by the system default alone.
2. The read tool answers the four list fields.
3. A taken port's vendor refusal is logged (Decision 5).
4. The classic editor's create defaults are not reproduced. The form starts from the API's own (inference: the classic `CreateCSPDefault` turns on CSP/REST).

**Spine amendments** (Rule 20; the lead writes them at the spec gate):

1. **AD-10.**
   - Replace "No Release 1 tool reaches the superserver, which is not a `Security.Service`" with a bullet: "**The superserver the Web Gateway connects through** (Story 18.25): on the system default superserver, or one whose port the serving request arrived through (its principal device, `|TCP|<port>|<pid>`, measured), a delete, `Enabled` or `EnableCSP` turned off, or `SSLSupportLevel` raised to 2 is refused `PROHIBITED.SERVINGSUPERSERVER` before any write, from either caller. Any other change to its `SSLSupportLevel` or `SSLConfig` is permitted at the strongest confirmation (effect `SUPERSERVER.SERVESOCUPILOT`). A turn's mint has no serving request and judges by the system default alone. The same serving-path family."
   - Keep "so is disabling the superserver".
2. **AD-13:** "**A `superserver` id is the composite `[Port, BindAddress]`** (Story 18.25). Its rule `portbind` spells the port in plain decimal, an empty bind address `0.0.0.0`, and folds the bind address to lower case (measured: empty and `0.0.0.0` reach one record; `LOCALHOST` reached `localhost`)."
3. **AD-4:** "**`Security.Superserver` keeps a key its body omits, and the merge never sends `SystemDefault`** (Story 18.25; measured). It is an upsert, 201 on create. The system default is the classic Memory and Startup page's."
4. **AD-8:** "**Story 18.25's Superservers declare Security's set**, and its tools declare no pair beyond it (measured on `ocupilot-ci`, 2026-10-07)."
5. **AD-44:** "**Story 18.25's `CLASSICPAGES`**: create and update declare `%CSP.UI.Portal.Server`; the delete, performed on `%CSP.UI.Portal.Servers` itself, declares none."

**Integration ACs.** The new modules (`SuperserverPort`, `SuperserverRules`, `SuperserverSave`, the arm, `SuperserverError`) are consumed in this story by the page, the delete row action and the agent (Tasks › Integration).

- **Consumes:**
  - 18.8: the serving-path family, form locks, the seam port.
  - 18.20: the list plus form.
  - 18.14: the composite id and the port split.
  - 23.4: HoldTool. 16.17: read-back. 14.1: `Snippet`. 14.2: baseline.
- **Consumed-by:** 18.12 (the agent's grown tool set).

**Ledger inbox (Rule 17):** empty (`slice 18-25-superservers`).

**Footprint (Rule 11).**

- Contended files are edited add-only: the kernel, the registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, `EntityRef.cls`, the test rosters, `ci.test.mjs`, `strings.ts`, `entity-ref.ts`, `screen-mirror.mjs`, EXPERIENCE.md and the spine.
- `footprint_extensions`: `Port/SuperserverPort.cls`, `Port/AdminPort.cls` (`PROPERTYFAULTS`), `Api/SuperserverError.cls`, `scripts/ci-throwaway.sh`.

**Size (inference).** About Story 18.20's size plus 18.8's arm and one id rule. It fits one implement pass.

**Vendor defect candidates** (owner hold; for the lead's list, not reported):

1. Every `Security.Superserver` validation refusal answers 500 with an empty body.
2. An `SSLConfig` naming no configuration is stored while `SSLSupportLevel` is 0.

**For the lead (spec gate):**

1. Fixed strings: 2787 of 2800 are used (measured at plan), and this story adds about 40. Move the bound to 2900 under the protocol, or the implementer stops before adding strings.
2. Decision 2 (the code).
3. Spine amendments 1-5.
4. DW-2007's scope: add `Security.Superserver` `PUT` #5001.
5. The two vendor candidates.

## Verification

**Setup (slot A):**

- Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh`, which prints `LOAD-OK` and `STARTPATH-OK`. Never use the MCP loader.
- One test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout.
- Before a browser run:
  - `cd ui && npm run build`
  - `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  - export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**S0 for `ocupilot-ci`:**

- Superservers: exactly 1972/`0.0.0.0`, as its plan `GET`: `Description` "System default port"; `Enabled`, `SystemDefault`, Clients, CSP, DataCheck, ECP, Mirror and Sharding on; the rest off; `SSLConfig` ""; level 0.
- Listeners: 1972, 2188 and 52773.
- Monitor 0. No `OcuProbe1825*` principal or SSL configuration. Nothing listens on 21825-21829.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time. Expected 0 failures, with totals checked against `%UnitTest_Result`.
  - The story's classes: `SuperserverDescriptor`, `SuperserverRead`, `SuperserverWrite`, `SuperserverGate`, `SuperserverProhibited`, `EntityRef`.
  - Then the rosters in Tasks › Tests.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/superservers.browser-spec.mjs browser/security.browser-spec.mjs`. Expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected clean.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`;
  4. the throwaway reads as S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on `ocupilot-ci`, recompile the tree, observe red, revert byte-identical, and record `mutation: <change> → <test> red (run n)` here:

- **B1:** the list read drops `SystemDefault` → `SuperserverRead`'s one-read leg. The `portbind` rule keeps `""` → `SuperserverDescriptor` and `entity-ref.test.mjs`.
- **B2:** `MergeUpdate` keeps `SystemDefault` → `SuperserverWrite`'s body leg. The Save skips `HoldTool` → its busy leg. The #5001 mapping removed → its `PORT.INUSE` leg.
- **B3:** `Problem` drops the system-only rule → its rules leg.
- **B4:**
  - The `SERVINGSUPERSERVER` dispatch removed → `SuperserverProhibited`'s refusal legs (through the seam, so no write reaches 1972).
  - The serving-port branch removed → its pure leg.
  - `SuperserverLocks` empty → `SuperserverRead`'s lock leg and the browser spec.
  - The effect removed → its destructive-mint leg.
- **B5:** `security.superservers.delete` set `true` in the baseline → `SuperserverDescriptor`'s baseline leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned:** the whole story as one implement pass (about Story 18.20's size plus an arm and an id rule; no split).
- **Measured at plan** on `ocupilot-ci`: probes on ports 1985-1988 and 2188, restored to S0 with the monitor at 0. Also a read-only `$PRINCIPAL` read on slot A.
- **Spec-gate items** are in Design Notes › For the lead: the Fixed strings bound (2787 of 2800 used), Decision 2's code, five spine amendments, DW-2007's scope and two vendor candidates.
- The plan was self-reviewed against the READY-FOR-DEVELOPMENT standard.
