---
title: 'Story 9.9: A cut editor ships reduced, never half-working'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: '6f87e68d070b9aa87595da597183b8f681cde908'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-8-edit-task.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The LDAP / Kerberos list's Enabled column reads No for an enabled LDAP configuration, because the vendor's Security.LDAP LIST answers Enabled false where its own List query reports Yes.
    evidence: |-
      Measured on ocupilot-ci during 9.9's implement pass after a PUT of LDAPFlags 72 (bit 64 set): the LIST row's Enabled was false while Security.LDAPConfigs:List read Yes. Pre-existing in the list's read, not caused by 9.9; the reduced form reads the flag from GET and is correct.
    location: >-
      src/OcuPilot/Screen/Descriptor/LdapConfigList.cls
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The service editor and the LDAP and Kerberos editor were moved to Stories 16.13 and 16.14. Until those stories land, a service or an LDAP configuration can be listed but not changed, by a person or by the agent. The floor also needs a check that each area has a form and that no list links out.

**Approach:** Add two reduced edit forms. Both render one shared shell page from a per-descriptor declaration, and each ends with the existing `ClassicLinkCard`. Add two merge-write tools, `permissions.services.update` and `security.ldap.update`. A form's Save calls its tool under AD-55, and an agent proposal calls it under AD-4 and AD-6. Add a client test that pins the floor.

## Boundaries & Constraints

**Always:**

- **Service form** (`ServiceForm`, `permissions/services/edit/<name>`, opened from the Services list's name cell):
  - Fields: Service enabled (`Enabled`), then Allowed incoming connections (`ClientSystems`).
  - The connections are listed in the vendor's own spelling (`address` or `address|role,role`). Each entry has a Remove button, and an Add field takes one bare address. The client refuses a `|` in that field, so the form never edits roles.
  - Authentication methods, per-address roles and everything else are left to the card.
- **LDAP form** (`LdapConfigForm`, `security/ldap/edit/<name>`, opened from the LDAP / Kerberos list's name cell), fields in the classic order:
  - Description;
  - LDAP enabled, which is `LDAPFlags` bit 64: the client toggles that bit on the value it opened and sends `LDAPFlags`;
  - Host names (`LDAPHostNames`, a list with add and remove);
  - Search username; Base DN (`LDAPBaseDN`); Unique search attribute (`LDAPUniqueDNIdentifier`).
  - The LDAP form edits and never creates.
- **Both descriptors:**
  - `form-page`, `sideBarPosition` 0, the list's pairs.
  - `classicPage`: `%CSP.UI.Portal.Dialog.Service` for the service form and `%CSP.UI.Portal.LDAP` for the LDAP form.
  - Suggested prompts, under the 11.3 contract.
  - `classicLinkExemption` is `exempt: true` with no `rowLink`. The card's label and href:

    | Form | Label | Href |
    |---|---|---|
    | Service | "Services" | `/csp/sys/sec/%25CSP.UI.Portal.Services.zen` |
    | LDAP | "Security LDAP Configs" | `/csp/sys/sec/%25CSP.UI.Portal.LDAPs.zen` |

    Both hrefs answer 200 on slot A, and both labels are the classic pages' own `PAGENAME`.
  - The exemption's reason says the editor is reduced until Story 16.13 or 16.14, and is counted against SM-C1.
- **The shared page** (`ReducedFormPage`):
  - It is registered in `DESCRIPTOR_PAGES` and `DESCRIPTOR_EDIT_PAGES` for both descriptors. It is eager: no `@defer`, no lazy route.
  - With no id it shows one sentence that points back to its list.
  - With an id it has a form-page layout: single column, the sticky Save and Cancel bar, "Saved" after a save, the error summary with its focus order, the dirty guard (`FormDirty`), and "This … no longer exists." on 404.
  - On a successful Save it publishes `service` or `ldap-configuration` `updated` (AD-14).
  - The card is the last child of the content column.
- **Tools** (`X509Update` is the template: merge, `READTYPE GET`, `WRITETYPE PUT`, `SENDSBODY 1`, `CHANGEACTION updated`, `WRITERESOURCE %Admin_Secure:USE`):
  - `ServiceUpdate` is on `ServiceList`. `IdArgument` is `Name` and `IdParam` is `name`. `PERMITTEDFIELDS` is `AutheEnabled,ClientSystems,Enabled`. `Description` is sent back as read but is never settable, because the vendor drops it silently (measured).
  - `LdapUpdate` is on `LdapConfigList`. `PERMITTEDFIELDS` is the 30 template keys less `LDAPCACertFile` (AD-21). It has no secrets: `LDAPSearchPassword` is not in the template, and GET never answers it.
  - Classification entries (every row `ordinary`), then `node tools/field-lists.mjs`.
  - `Security.Service/PUT` and `Security.LDAP/PUT` are added to `MUTATINGTYPES`.
  - `EntityRef.IDRULES` gains `service:foldcase` and `ldap-configuration:foldcase`. Both names resolve without case on slot A (measured).
- **Rules.** `Area/Permissions/ServiceRules.cls` and `Area/Security/LdapRules.cls` are shared by the tool's `ArgumentProblem` and by the Save. Each refusal is `{field, code, reason}`:
  - `SERVICE.ADDRESS.SHAPE`: an entry that is empty or holds whitespace or `;`. The vendor splits an entry on `;` (measured).
  - `SERVICE.ADDRESS.ROLE`: a role suffix naming a role that `Security.Roles.Exists` does not know. The vendor accepts an unknown role silently (measured).
  - `SERVICE.AUTHE.UNSUPPORTED`: an `AutheEnabled` bit outside the service's `Security.Services.Capabilities`, read in `%SYS` (AD-16). The vendor masks such a bit and answers 200 (measured).
  - `LDAP.FIELD.REQUIRED`: a `Required` property of `Security.LDAPConfigs` set to `""`.
  - `LDAP.HOST.SHAPE`: an empty host entry, or one holding whitespace. The vendor joins host names with a space (read in the vendor source).
  - `LDAP.FLAGS.VALUE`: `LDAPFlags` outside the integers 0 to 255.
  - `LDAP.DESCRIPTION.LENGTH`: longer than 128.
- **Prohibited set** (`Prohibited.cls`, arms appended):
  - `COVEREDTYPES` and the dispatch gain `service` and `ldap-configuration`, and `PermittedChangeFields` gains an arm for each.
  - A `Service` arm (first hit wins): on `%Service_WebGateway`, compared without case, a change that turns `Enabled` off is refused `PROHIBITED.SERVINGSERVICE` (AD-10). A change to its `ClientSystems` or `AutheEnabled` is permitted and marked destructive, with a consequence line saying OcuPilot itself is served through this service (AD-10 as amended, ruling 2dca0322). Then the reviewed-few sweep runs.
  - `WeakensByEffect`: a service whose `AutheEnabled` gains bit 64 is marked `SERVICE.UNAUTHENTICATED`.
  - `GrantsPrivilegeByEffect`: a `ClientSystems` entry that adds a privileged role (`IsPrivilegedRole`) is marked. A marked proposal is destructive, as for web applications.
  - LDAP gets the reviewed-few sweep only.
- **Save routes**, in the order `SslSave.Update` uses:
  - `GET /services/form?name=` answers `{service, servesOcuPilot}`, and `PUT /services/:id` goes to `ServiceSave`.
  - `GET /ldap/form?name=` answers `{ldap}`, and `PUT /ldap/:id` goes to `LdapSave`.
  - An absent name answers 404 `SERVICE.ABSENT` or `LDAP.ABSENT`.
  - On `%Service_WebGateway` the service form draws Enabled `aria-disabled`, with the published sentence as the reason; its connection controls stay editable, and a change to them shows the consequence line at the field before Save.
- **Copy:** every new word goes in `strings.ts` and in EXPERIENCE.md's Fixed strings. Rows are marked `[ADDED 2026-09-24 - see the story change log]`. Use tokens and `\uXXXX` escapes only.
- **Probes.** They run on `ocupilot-ci` only, and each armed class goes on a new `OCUPILOT_ALLOW_SERVICE_CONFIG` block (`# classes:` in `ci-throwaway.sh` and `ci.test.mjs`):
  - Service tests change only `%Service_CallIn` (disabled). They snapshot its GET before the test and restore it after.
  - LDAP tests create `OcuP99*` configurations through `Security.LDAPConfigs` in `%SYS`, and delete each one after checking its exact name.

**Never:**

- A write to `%Service_WebGateway` or to any enabled service, from any test or mutation. The serving-service legs pin the refusal on the mint (which writes nothing) and on a Save whose port is `OcuPilot.Test.PortFixture` armed to record a PUT.
- Tabs, the authentication-method checkboxes, per-address role editing, LDAP create, test, search password or TLS in a reduced form. They are 16.13's and 16.14's.
- A `rowLink` or any exemption on a list descriptor.
- A third write mechanism: the Save is AD-55's.
- A new AD-27 case.
- Edits beyond appends in the shared-append files.
- A full browser-suite run locally.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add an address | `%Service_CallIn`; add `10.0.0.1`; Save | 200 and "Saved". The list's Allowed IP addresses shows it. `AutheEnabled` and `Enabled` read back unchanged | — |
| Entry with `;` | Agent sends `ClientSystems:["a;b"]` | Nothing is sent | `SERVICE.ADDRESS.SHAPE` |
| Unsupported method | Agent sends `AutheEnabled` with bit 262144 | Nothing is sent | `SERVICE.AUTHE.UNSUPPORTED` |
| Serving service | Enabled off on `%Service_WebGateway`, from either caller | The screen's Enabled control is aria-disabled. Nothing is sent | `PROHIBITED.SERVINGSERVICE` |
| Serving-service address | Agent adds an address to `%Service_WebGateway` (mint only; a Save leg only against the recording `PortFixture`) | The proposal is minted destructive and carries the consequence line; the form shows the line at the field | — |
| Privileged address role | Agent adds `10.0.0.9\|%All` on `%Service_CallIn` | The proposal is destructive and names the privilege | — |
| LDAP two-field save | `OcuP99Ldap`; change Description and host names | 200. The other 28 GET keys read back unchanged | — |
| LDAP enable | Tick LDAP enabled | `LDAPFlags` gains 64 and every other bit is kept | — |
| Deleted between mint and confirm | Mint `security.ldap.update`, then delete the configuration | The confirm is refused as target changed, and nothing is created (the PUT is an upsert) | fingerprint |
| Absent | Open or PUT a name that does not exist | "This … no longer exists." | 404 `*.ABSENT` |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at HEAD `20efd72f`.

**Measured.** On `ocupilot-ci`, over `/api/admin/v2`, every probe restored the state it found. On slot A, reads only.

- **`Security.Service`** (read with `GetTextAsString` on slot A):
  - GET answers `{AutheEnabled, ClientSystems[], Description, Enabled}`.
  - PUT keeps an omitted key, and `ClientSystems` round-trips `addr|role`.
  - A changed `Description` answers 200 and is dropped.
  - `AutheEnabled` 262176 was stored as 32.
  - An unknown role is accepted.
  - `"a;b"` became two entries.
  - An absent name answers 404.
- **Services on the instance:** 15 exist. Neither `%Service_Web` nor `%Service_CSP` exists; the web serving service is `%Service_WebGateway`, and the superserver is not a service row.
- **`Security.LDAP`:**
  - GET answers 30 keys, with no search password, and an absent name answers 404.
  - PUT keeps an omitted key, and it creates the configuration when the name is absent (an upsert).
  - The fixture `unknowndomain.com` has `LDAPFlags` 25.
  - `LDAPFlags` bit 6 (64) means enabled (`Security.LDAPConfigs` doc).
- **Classic pages:** `Services.zen`, `LDAPs.zen` and `LDAP.zen` answer 200.
- **Floor facts:**
  - The five areas other than Logs have a built `form-page`: WebAppForm; UserForm and RoleForm; Ssl, X509, WalletSecret and AuditingConfig; TaskForm; DeviceForm.
  - Logs has none. The feature catalog's section 7 lists no editor at any tier.
  - `classic-links.mjs` honors one exemption, the five OAuth `detail` tabs, and no list declares one.

**Server:**

- Templates:
  - `S/Screen/Tool/X509Update.cls` (whole) for the tools.
  - `S/Area/Security/SslSave.cls` :86-120 and :176-300 for the Save.
  - `X509Rules.HandleForm` :199 for the form read.
- `S/Screen/Descriptor/{ServiceList,LdapConfigList,SslForm}.cls`: the SslForm declaration is the form template.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250, the dispatch :692 and :704-790;
  - `PermittedChangeFields` :499, `WeakensByEffect` :1015, `GrantsPrivilegeByEffect` :1817, `IsPrivilegedRole` :1919;
  - `ReviewedFewOnly` :1513, `AddsUnauthenticated` :2669, and the `Ssl` arm :2769 as the pattern.
- `S/Port/AdminPort.cls`: `MUTATINGTYPES` :275.
- `S/Kernel/EntityRef.cls`: `IDRULES` :59.
- `S/Screen/Tool/Classification.cls`: the entry format is at :366. `ToolFields.cls` is regenerated.
- `S/Api/Router.cls`: add the routes after `/tasks`, :150-157. `S/Api/Error.cls`: add the codes and the `*ViolationCodes` lists, as at :1221-1276.
- Rules reading `Security.Roles.Exists` directly have precedents at `RoleCreateRules.cls` :340 and `Create.cls` :476.

**Rosters:**

- `Test/ToolWrite` (MUTATINGTYPES) and `Test/Prohibited` (SettableFields equal to PermittedChangeFields).
- `Test/SurfaceCoverage` (`<screen>` and `<tool>` rows, :96-123) and `Test/ToolRoundTrip` (`REFUSEEMPTY`).
- `Test/ReadTool` :94, `Test/EndpointCoverage`, `Test/Descriptor`, `Test/Wire`, `Test/RefusalCopy`.
- `scripts/ci-throwaway.sh` :190-292 and `ui/tools/ci.test.mjs`.

**Client:**

- `U/shell/classic-link-card.ts`: it renders from `classicLinkExemption` and is mounted nowhere yet.
- `U/shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :106 and `DESCRIPTOR_EDIT_PAGES` :131.
- `U/core/navigation.ts`: `editorScreenFor` :177 needs an unlisted, built, id-routed `<list>/edit`.
- `U/core/form-dirty.ts` and `U/shell/form-tabs.ts`.
- Leanest editor to mirror: `U/areas/security/wallet-secret-form.{page,store}.ts`. Its list field is `AllowedHosts` :222/:543.
- Budget: `ui/angular.json` :54 (1551kB warning); `ui/tools/build-output.test.mjs` :170-200 fails above it; 9.8 measured 1,537,954 B.
- Browser:
  - `ui/browser/ssl-editor.browser-spec.mjs` is the template, and `task-editor.browser-spec.mjs` :359 is the visual gate.
  - `structural-walk.mjs` walks every built screen at its bare route.

## Tasks & Acceptance

**Execution:**

Server:

- `S/Kernel/EntityRef.cls`, `S/Port/AdminPort.cls` -- add the two id rules and the two mutating types -- AD-13, AD-2.
- `S/Screen/Tool/ServiceUpdate.cls`, `S/Screen/Tool/LdapUpdate.cls` (new); `Classification.cls` plus the regenerated `ToolFields.cls` -- the tools as in Boundaries -- AD-3, AD-4, AD-52.
- `S/Area/Permissions/{ServiceRules,ServiceSave}.cls`, `S/Area/Security/{LdapRules,LdapSave}.cls` (new); `S/Api/Router.cls`, `S/Api/Error.cls` -- the rules, the form reads, the Saves and the codes -- AD-12, AD-39, AD-55.
- `S/Kernel/Proposal/Prohibited.cls` -- the `service` and `ldap-configuration` arms, `PROHIBITED.SERVINGSERVICE`, and the two effect markings -- AD-10.
- `S/Screen/Descriptor/{ServiceForm,LdapConfigForm}.cls` (new); the docs of `ServiceList` and `LdapConfigList` -- the descriptors and exemptions -- AD-5, AD-44.

Server tests (armed, on `ocupilot-ci`, run one class at a time):

- `Test/ServiceUpdate.cls` -- the schema; the mint's diff rows; a two-field confirm that keeps `AutheEnabled`; the three rules; the serving-service refusals on the mint; the destructive marking for bit 64 and for `|%All`.
- `Test/ServiceEdit.cls` -- the Matrix rows through `GET /services/form` and `PUT /services/:id`; the serving-service Save through `PortFixture`; a least-privileged principal holding exactly the pairs saves.
- `Test/LdapUpdate.cls`, `Test/LdapEdit.cls` -- the same for LDAP, plus the upsert row.
- `Test/ServiceLdapProbe.cls` -- the snapshot and restore of `%Service_CallIn`, and the `OcuP99*` LDAP create and delete.
- The rosters above, with names read from the instance.

Client:

- `U/shell/reduced-form.page.ts` and `U/core/reduced-form.store.ts` (new), each with its spec -- load, absent, bare route, Save, "Saved", refusal routing to a field, the dirty guard, publish, the protected controls, the card last.
- `U/areas/permissions/service-form.ts` and `U/areas/security/ldap-form.ts` (new declarations) -- the field lists, the paths and the flag-bit mapping.
- `U/shell/screen-outlet.ts` -- register both.
- `U/core/strings.ts` and the Fixed strings.
- `ui/tools/floor.test.mjs` (new) -- AC4.
- `ui/browser/reduced-editors.browser-spec.mjs` (new) -- the name-cell entry, a Save read back by `docker exec`, the serving-service controls, the card (its label, href and `target=_blank`), and the visual gate.

**Acceptance Criteria:**

- **AC1.** Given the Services list or the LDAP / Kerberos list, when a name cell is followed, then the reduced form opens with the Boundaries fields filled from the instance. There are no tabs and no half-built control, and a `classic-link-card` ends the form.
- **AC2.** Given either form, when it renders, then the card:
  - is titled "More in the classic portal" and names the classic page;
  - is an anchor with `target="_blank"` and `rel="noreferrer"`;
  - carries "The classic portal may ask you to sign in again."
- **AC3.** Given `permissions.services.update` or `security.ldap.update`, when an agent proposal changes two fields and is confirmed, then the body is the fresh read merged with the change, and every other field reads back as it was (AD-4). A form Save resolves through the same tool (AD-55).
- **AC4.** Given the built descriptors, when `floor.test.mjs` runs, then:
  - each of Web applications, Permissions, Security and secrets, Tasks and OS management has at least one built `form-page`;
  - Logs is asserted to have none, as a tripwire: the catalog has no Logs editor at any tier;
  - no `list`-class archetype declares an exemption.
- **AC5.** Given `%Service_WebGateway`, when either caller turns it off, then it is refused `PROHIBITED.SERVINGSERVICE` before any port write, and the form draws Enabled disabled with the published sentence; when either caller changes its addresses or authentication methods, then the change is permitted, the agent's proposal is minted destructive, and both surfaces carry a consequence line saying OcuPilot itself is served through this service (AD-10 as amended, ruling 2dca0322). Pinned: the disable is refused by name, and an address change mints destructive with the line - each with its own `mutation:` line. The consequence line is a new Fixed-strings row and string key.
- **Integration.** Given `ReducedFormPage`, which consumes `/services/*`, `/ldap/*` and `ChangeBus`, when a Save succeeds, then the list it came from shows the new value. The browser spec observes this.

## Spec Change Log

- 2026-09-24 spec gate (lead): orchestrator ruling 2dca0322 on the five questions: AD-44 amended to three exemptions; AD-10 names `%Service_WebGateway`, but only its disable is refused - an address or method change is permitted, destructive, with a consequence line (AC5, the matrix and the Prohibited arm narrowed here); 9.9 AC4 restated for the five administering areas; 16.13 AC2 and EXPERIENCE.md :126 amended; bundle re-base below 1580kB allowed.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 18 findings — high 1, medium 2, low 12, false 3, maybe-false 0
- findings:
  - `[high]` `[patch]` `Test/EntityRef` used `service` as its no-id-rule type, which `service:foldcase` now folds (`_SYSTEM` -> `_system`) — `KNOWNTYPE` set to `database`; EntityRef 9/9, run 10747.
  - `[medium]` `[patch]` No test refuses a caller lacking one of the forms' pairs on the two form reads and two Saves (AD-8) — added `WireSecurityRead.TestTheReducedFormsRefuseACallerWithoutTheirPairs` (absent names, so nothing can be written); green run 10751, red with the Save gate removed run 10753.
  - `[medium]` `[patch]` LDAP Save's complete body unpinned; a read-back cannot tell a narrowed body because the vendor keeps omitted keys — added `LdapSaveHeldFixture` and `LdapEdit.TestTheSaveSendsTheCompleteBody` (30 keys through `HeldPutPort`); red alone when the Save sends `tChanged`, run 10752.
  - `[low]` `[patch]` `LDAPFlags` reaching the form read as a number was unpinned — `%GetTypeOf("LDAPFlags") = "number"` added to `LdapEdit`'s form-read test.
  - `[low]` `[reject]` `WriteCount() = 0` at the mint cannot fail — guard assertions beside the load-bearing 400-and-sentence ones; no harm.
  - `[low]` `[reject]` Service read-backs cannot catch a narrowed body — the service body is pinned on `LastWriteBody` in `ServiceUpdate` and the held-port leg in `ServiceEdit`.
  - `[low]` `[reject]` AC4's mutation covers only the list bullet — Rule 19 asks one mutation per AC's pinning test, recorded.
  - `[low]` `[patch]` AC5's client half had no mutation — dropping `servingProtected` reddens the store and page AC5 specs; line added.
  - `[low]` `[reject]` The observed AC5 mutation differs from the planned one — the kernel arm is now pinned directly (run 10754) and the mint by its own legs.
  - `[false]` `[reject]` The LDAP prohibited arm is never exercised — removing it reddens `LdapUpdate.TestAConfirmedTwoFieldEditKeepsEveryOtherField` (run 10755); a direct kernel leg was added anyway (run 10756).
  - `[false]` `[reject]` `strings.test.mjs` says the table passes 900 — measured 917 literals.
  - `[low]` `[patch]` The agent's disable is refused at the mint by the published sentence (`TOOL.ARGUMENTS`, as `SslUpdate` does), and no test drove the kernel arm with the agent's tool — added `ServiceUpdate.TestTheKernelRefusesTheServingServiceDisableByName` (`PROHIBITED.SERVINGSERVICE` for `permissions.services.update`, read-only).
  - `[low]` `[reject]` The Save-side serving leg bypasses the HTTP route — by design: a route leg on the serving service writes it if the refusal breaks, which the Never list forbids; the route's gate and envelopes are pinned on `%Service_CallIn` and in `WireSecurityRead`.
  - `[false]` `[reject]` The floor is declaration-level and skips home and agent — AC4 as ruled names the five administering areas and Logs.
  - `[low]` `[reject]` The service agent path is proven on the fixture body, not an instance read-back — the body is the stronger pin.
  - `[low]` `[reject]` Matrix inputs differ from test inputs (262192 carries bit 262144; a probe name over a fixture read; enable and absent at the store and wire tiers) — every row is covered by a test that ran; the matrix names no tier.
  - `[low]` `[reject]` Rules wider than worded, per-class snapshot, prefix-scoped `RemoveAll` — each refuses only what the vendor would store wrongly, and probes stay in `ocup99*` on the throwaway.
  - `[low]` `[reject]` In-place edits in shared files — `Prohibited.cls` is not a shared-append file; the `strings.ts` `taskCreate` line reference is forced by the line-reference test after the appended rows, as in 9.8.
- implementer-reported, not a layer finding: the LDAP / Kerberos list's Enabled column reads No for an enabled configuration (vendor LIST) — deferred.

## Design Notes

**Governing ADs:**

- AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-16, AD-19, AD-21, AD-24 (a form declares no tools);
- AD-27 (containment only);
- AD-35, AD-39, AD-44, AD-52, AD-53, AD-55.

**Choices:**

- **Reduced means daily fields.**
  - A service's daily fields are its on/off and who may connect.
  - An LDAP configuration's daily fields are its on/off, where the server is and how users are found (inference: these are the classic page's first block; the group-mapping blocks are set once).
  - The agent's tools cover the whole derived list, so nothing is out of reach.
- **One shared page.** The two forms are one declaration-driven component, which keeps the added bundle small. Estimate: +14 to 20 kB, for about 1,552 to 1,558 kB (inference). That is under the 1580kB stop line and probably over the 1551kB warning; see Question 5.
- **The LDAP flag bit is computed on the client,** over the value the form opened. That is last-writer-wins on `LDAPFlags`, as with 9.8's Save (by design).
- **Test isolation.** No enabled service is written. The serving-service AC is pinned on paths that never reach a vendor write, so a mutation that removes the arm cannot disable the throwaway's gateway.

**Measured, not in scope:**

- **AC4's Logs half.** No Logs editor exists anywhere in the catalog; see Question 3.
- **The OAuth tabs.** They declare `detail` and link out by row. Story 12.9 removes them. They are not a list archetype, so the list check passes.
- **DW-1016.** The empty-cell word in the diff is owned by 16.13. An agent's first address will read `(none) -> …` (inference).

**Contention:**

- `origin/OCU-1-epic12` edits `AdminPort.cls` (`MUTATINGTYPES`), `Prohibited.cls`, `Confirm.cls`, `Screen/Tool/{Base,Registry}.cls`, and the test rosters (`PortFixture`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `Descriptor`). It also edits `ci-throwaway.sh`, `strings.ts`, `screens.generated.ts`, `_components.scss`, EXPERIENCE.md, the spine and epics.md.
- Expect one-line roster merges.
- Footprint extensions: `Kernel/EntityRef.cls`, `Kernel/Proposal/Prohibited.cls`, `ui/src/app/shell/{reduced-form.page,screen-outlet}.ts`, `ui/tools/floor.test.mjs`.

**Integration ACs:**

- **Consumes:** the Services and LDAP lists' name cells (`editorScreenFor`), `ClassicLinkCard`, `FormDirty`, `ChangeBus`, and the SSL Save's order.
- **Consumed-by:** Story 16.13, whose full service editor replaces `ServiceForm`'s page and removes its exemption. Story 16.14 does the same for `LdapConfigForm`.

**Ledger inbox:** none.

**Questions for the lead.** The spec implements each recommended answer.

1. **AD-44 (Rule 20).** It says "Release 1 has exactly one" exemption. This story adds two more, which is AC2's own requirement.
   *Recommended:* amend it to three: the OAuth 2.0 tabs (removed in Epic 12), the service editor (removed by 16.13) and the LDAP editor (removed by 16.14). SM-C1 then counts 3.
2. **AD-10 (Rule 5, apply and report).** It names "`%Service_Web` and the CSP service". Neither exists on 2026.2 (measured list of 15), and the superserver is not a `Security.Service`.
   *Recommended:* name `%Service_WebGateway`. Also record that the arm refuses turning it off and any change to its addresses or methods, since each can cut the gateway off (inference), and that no Release 1 tool reaches the superserver (SS-29, P2).
3. **9.9 AC4 and the PRD floor.** "At least one create or edit form per area" cannot hold for Logs, because the catalog has no Logs editor at any tier.
   *Recommended:* restate it as each of the five areas that administers an object, and name Logs as having no editor to build. Changing an AC is ask-first under Rule 5.
4. **Story 16.13 AC2 and EXPERIENCE.md :126** (another epic's block). They let a person disable OcuPilot's own web service after a warning, but AD-10 and AD-55 refuse it whoever the caller is.
   *Recommended:* the orchestrator amends both to "the control is drawn disabled with the published sentence".
5. **Bundle.** If the measured total exceeds 1551kB, `build-output.test.mjs` fails.
   *Recommended:* the implement stage raises `maximumWarning` and its pinned literal together to the measured total rounded up to the next kB, never above 1580kB. DW-1166's re-base at epic close follows.

## Verification

Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`, and anything that writes runs on `ocupilot-ci`. Load with `/private/tmp/claude-501/epic-9-loaders/load-ci.sh`. Run one test class per call.

**Commands:**

- `(loop)` `cd ui && node --test tools/floor.test.mjs tools/classic-links.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs tools/ci.test.mjs tools/angular-json.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `reduced-form.*`, `screen-outlet` and `classic-link-card`.
- `(loop)` `uv run scripts/test_check_objectscript.py && uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one at a time -- expected: 0 failures. X is:
  - ServiceUpdate, ServiceEdit, LdapUpdate, LdapEdit;
  - ToolWrite, Prohibited, ProhibitedByEffect, SurfaceCoverage, EndpointCoverage, ToolRoundTrip;
  - ReadTool, Descriptor, DerivedFields, Wire, WireSecurityRead, RefusalCopy.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Then run each spec file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<f>` -- expected: green. The files are reduced-editors, classic-link-card, permissions, security and a11y-structural-invariants. Report the build's initial total.
- **The DW-1337 structural gate:** `reduced-editors.browser-spec.mjs`'s visual-gate test at 1440x900 on both forms at an id route. It checks that every input has an accessible name, that no control is narrower than its declared minimum (24x24), and that no element overflows its container. `a11y-structural-invariants` covers the bare routes.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test` -- expected: 0 new failures. The full browser suite is CI's.

**Mutations (Rule 19; ObjectScript recompiled with its descendants; the client rebuilt and redeployed):**

- AC1: unregister the page from `DESCRIPTOR_EDIT_PAGES`.
- AC2: drop `target` from the card anchor.
- AC3: make `ServiceUpdate.SettableFields` send the changed fields only; separately, merge `LDAPHostNames` by concatenation.
- AC4: set `LdapConfigList`'s exemption to exempt.
- AC5: remove the `Service` arm, against the mint and the `PortFixture` Save only.
- Integration: skip the `updated` publish.

**Mutations observed (implement pass; each reverted and the file byte-identical by sha1; ObjectScript recompiled on `ocupilot-ci`, client rebuilt and redeployed before a browser result counted):**

- mutation (AC1): drop ServiceForm from `DESCRIPTOR_EDIT_PAGES` -> `screen-outlet.spec.ts` "Story 9.9" went red.
- mutation (AC2): drop `target` from the classic-link-card anchor -> `reduced-form.page.spec.ts` "AC1" and `reduced-editors.browser-spec.mjs` "AC1, AC2" went red (bundle rebuilt and redeployed).
- mutation (AC3, service): make `ServiceUpdate.MergeUpdate` send the changed fields only -> `ServiceUpdate.TestATwoFieldConfirmKeepsEveryOtherField` went red (run 10735).
- mutation (AC3, LDAP): merge `LDAPHostNames` by concatenation in `LdapUpdate.MergeUpdate` -> `LdapEdit.TestATwoFieldSaveKeepsEveryOtherField` (run 10736) and `LdapUpdate.TestAConfirmedTwoFieldEditKeepsEveryOtherField` (run 10737) went red.
- mutation (AC4): set `LdapConfigList`'s exemption to exempt and regenerate the mirror -> `tools/floor.test.mjs` "no list-class archetype declares a classic-link exemption" went red.
- mutation (AC5, disable): make `Prohibited.ServingServiceDisabled` answer 0 -> `ServiceUpdate.TestTheServingServiceIsNeverTurnedOffAndItsAddressesAreMarked` (mint, run 10738) and `ServiceEdit.TestTheServingServiceSaveIsRefusedBeforeAnyWrite` (Save through `HeldPutPort`, which never sends a PUT; run 10739) went red.
- mutation (AC5, address): drop the serving branch of `Prohibited.ServiceWeakening` -> the destructive-with-consequence legs of `ServiceUpdate.TestTheServingServiceIsNeverTurnedOffAndItsAddressesAreMarked` went red (run 10740).
- mutation (Integration): skip the `updated` publish in `ReducedFormStore.save` -> `reduced-form.store.spec.ts` and `reduced-form.page.spec.ts` "Integration" went red; the browser Integration legs re-read the list on return and stay green.
- mutation: drop `Validate` from `ServiceUpdate.ArgumentProblem` -> `ServiceUpdate.TestTheRulesRefuseAtTheMint` red (run 10741); drop the service arm of `GrantsPrivilegeByEffect` -> `ServiceUpdate.TestAWeakeningOrPrivilegedChangeIsMintedDestructive` red (run 10742); let `ServiceRules.EntryShaped` accept `;` -> `ServiceEdit.TestTheRulesRefuseTheSave` red (run 10743); drop `Validate` from `LdapUpdate.ArgumentProblem` -> `LdapUpdate.TestTheRulesRefuseAtTheMint` red (run 10744); drop the flags range check -> `LdapEdit.TestTheRulesRefuseTheSave` red (run 10745); answer a literal for `SERVINGSERVICE` in `ReasonFor` -> `RefusalCopy` red (run 10746); drop the `SERVESOCUPILOT` branch of `consequenceSentence` -> `proposal-view.test.mjs` red; drop the card from the page template -> three `reduced-form.page.spec.ts` legs red.

**Mutations observed (review pass, same discipline):**

- mutation (AC5, client): drop `servingProtected: true` from `SERVICE_FORM` -> `reduced-form.store.spec.ts` and `reduced-form.page.spec.ts` "AC5" went red.
- mutation (AC5, kernel on the agent's tool): remove the `service` branch from `Prohibited.Prohibits` -> `ServiceUpdate.TestTheKernelRefusesTheServingServiceDisableByName` went red (run 10754).
- mutation (AC3, LDAP Save body): `LdapSave.Update` sends `tChanged` -> `LdapEdit.TestTheSaveSendsTheCompleteBody` went red, alone (run 10752).
- mutation (AD-8): remove the Gate call from `ServiceSave.HandleUpdate` -> `WireSecurityRead.TestTheReducedFormsRefuseACallerWithoutTheirPairs` went red (run 10753).
- mutation (LDAP kernel arm): remove the `ldap-configuration` branch from `Prohibited.Prohibits` -> `LdapUpdate.TestTheKernelSweepsTheReviewedFew` and `TestAConfirmedTwoFieldEditKeepsEveryOtherField` went red (run 10756).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Two merge-write tools (`permissions.services.update`, `security.ldap.update`) with shared rules and AD-55 Saves (`GET /services/form`, `PUT /services/:id`, `GET /ldap/form`, `PUT /ldap/:id`); the `service` and `ldap-configuration` prohibited arms (`PROHIBITED.SERVINGSERVICE` on disabling `%Service_WebGateway`; `SERVICE.SERVESOCUPILOT` and `SERVICE.UNAUTHENTICATED` effects; an address given a privileged role marked destructive; LDAP reviewed-few); two id rules and two mutating types; two `form-page` descriptors exempt to the classic list pages (SM-C1 = 3); one `ReducedFormStore` and `ReducedFormPage` rendering `SERVICE_FORM` and `LDAP_FORM`; `floor.test.mjs`; `reduced-editors.browser-spec.mjs`.

**Files.** Server: `Area/Permissions/{ServiceRules,ServiceSave}.cls`, `Area/Security/{LdapRules,LdapSave}.cls`, `Screen/Tool/{ServiceUpdate,LdapUpdate}.cls`, `Screen/Descriptor/{ServiceForm,LdapConfigForm}.cls` (new); `Api/{Router,Error}.cls`, `Kernel/EntityRef.cls`, `Kernel/Proposal/Prohibited.cls`, `Port/AdminPort.cls`, `Screen/Tool/{Classification,ToolFields}.cls`, the two list descriptors' docs. Tests: `Test/{ServiceUpdate,ServiceEdit,LdapUpdate,LdapEdit,ServiceLdapProbe,ServiceSaveHeldFixture,LdapSaveHeldFixture}.cls` (new) and the rosters. Client: `shell/reduced-form.page.ts`, `core/reduced-form.store.ts` with specs, `areas/{permissions/service-form,security/ldap-form}.ts`, `screen-outlet.ts`, `proposal-view.ts`, `strings.ts`, `screens.generated.ts`, `_components.scss`, `angular.json`; EXPERIENCE.md six Fixed-strings rows; `ci-throwaway.sh` `OCUPILOT_ALLOW_SERVICE_CONFIG` block.

**Measured and applied.** The capability mask is `Security.Services`' `AutheEnabledCapabilities`; LDAP probe names are `ocup99*.invalid` (the vendor lower-cases a name created with `LDAPFlags`, appends `.com`, and `Modify` refuses a non-domain name, #908); the serving-service Save legs use `OcuPilot.Test.HeldPutPort` (records a PUT, never sends it), since `PortFixture` forwards one.

**Review.** 18 findings (high 1, medium 2, low 12, false 3): 6 patched (1 high, 2 medium, 3 low), 12 rejected with reasons in the Review Triage Log, 1 implementer-reported item deferred. The sweep then found `AuditingUpdate`'s prohibited-code count still at 17; patched to 18 (run 11004).

**Follow-up review recommended: true.** Patched by verdict: high 1, medium 2, low 3. Unverified risk: the review-pass tests (`WireSecurityRead.TestTheReducedFormsRefuseACallerWithoutTheirPairs`, `LdapEdit.TestTheSaveSendsTheCompleteBody`, `ServiceUpdate.TestTheKernelRefusesTheServingServiceDisableByName`, `LdapUpdate.TestTheKernelSweepsTheReviewedFew`) were written by the stage agent after the review layers ran and have had no independent review; and the new arming block has run only through the epic-9 shim on the reused `ocupilot-ci`, not on CI's fresh throwaway.

**Verification.**

- ObjectScript sweep (once, `ocupilot-ci`, one class per call): 246 classes, 2,147 tests, runs 10758-11003; `%UnitTest_Result` probe after the `AuditingUpdate` re-run: 2,146 passed, 1 failed -- `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, the known ~2,000-row task-history residue (DW-1425/DW-1468).
- Client: tool tests 1,405/1,405; component tests 1,206/1,206; `check-objectscript` 0 problems (814 files), its harness 130 OK, `lint-docs` clean.
- Browser (rebuilt, deployed to `ocupilot-ci`, each file alone): reduced-editors 5/5, classic-link-card 2/2, permissions 5/5, security 4/4, a11y-structural-invariants 10/10. `%Service_WebGateway` read back unchanged (`Enabled` true, `AutheEnabled` 32, no addresses); `%Service_CallIn` restored.
- Bundle initial total 1,560,536 B; `maximumWarning` raised from 1551kB to 1561kB with its pinned literal in `ui/tools/angular-json.test.mjs`.

**Residual risks.** During manual probing the handoff subagent sent one disable Save for `%Service_WebGateway` on `ocupilot-ci`; it was refused 403 before any port write, and the service reads back unchanged. The LDAP / Kerberos list's Enabled column is wrong for an enabled configuration (deferred). The `strings.ts` `taskCreate` line reference (`:543` -> `:549`) is an in-place edit that Epic 12's appended rows will also shift.

footprint_extensions: `src/OcuPilot/Kernel/Proposal/Mint.cls`, `src/OcuPilot/Test/{PortFixture,WireOAuthRead,WireSecurityRead,EntityRef,AuditingUpdate,ServiceSaveHeldFixture,LdapSaveHeldFixture}.cls`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/shell/screen-outlet.spec.ts`, `ui/src/styles/_components.scss`, `ui/browser/structural-baseline.json`, `ui/tools/{entity-ref,screen-mirror,navigation,strings,self-protection,proposal-view,angular-json,classic-links}.test.mjs`.
