---
title: 'Story 16.13: The service editor'
type: 'feature'
created: '2026-09-30'
status: 'done'
baseline_revision: '0c6af680bfacfb01f868bf0a60407fc48ec56ca7'
baseline_commit: '0c6af680bfacfb01f868bf0a60407fc48ec56ca7'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-9-a-cut-editor-ships-reduced-never-half-working.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A service can be turned on or off and given bare addresses only through Story 9.9's reduced form. Its authentication methods and per-address roles are still left to the classic page, and the form ends with a classic-portal card that counts against SM-C1. Separately, an agent proposal that restricts an unrestricted service shows its empty address list as `[]` on the card, not "Unrestricted" (DW-1016).

**Approach:**

- Replace the reduced form with a full tabbed service editor. It covers enabled state, allowed addresses with add and delete, per-address roles and authentication methods, drawn from an extended form read.
- Keep one write path: the Save and the agent's `permissions.services.update` stay two callers of one tool (AD-55). The tool gains the classic page's refusals, a canonical spelling for the entries a write adds or changes, and the classic Edit Service dialog as a `CLASSICPAGES` page.
- Remove `ServiceForm`'s classic-link exemption (SM-C1 counts one).
- Let a tool declare the word an empty field reads on the proposal card (`EMPTYKEYS`), so an empty address list reads "Unrestricted".

## Boundaries & Constraints

**Always:**

- **The screen and route are unchanged.** `ServiceForm` stays a built `form-page` at `permissions/services/edit/<name>`, reached from the Services name cell, with the list's pairs and its three prompts (11.3).
  - It now declares `classicLinkExemption` `{"exempt": false, "reason": "", "label": "", "href": ""}` and draws no classic-portal card.
  - `ServiceEditorPage` serves both its bare route (`serviceFormBare`) and its id route; an absent service reads `serviceGone` (404 `SERVICE.ABSENT`).
- **Tabs are the classic page's groups** (`%CSP.UI.Portal.Dialog.Service`, the SSL form's precedent). A tab is drawn only where the service has that group:
  - **General**, always drawn (`processDetailsGroupGeneral`): Name and Description as read-only text (the vendor drops a changed description, measured in 9.9), then Service enabled.
  - **Authentication methods** (`serviceColumnAuthentication`), drawn when the read's `authenticationMethods` is non-empty. It has one checkbox per method. Each one sets or clears its bit over the mask the form opened, so a bit that is not offered keeps its value.
  - **Allowed incoming connections** (`serviceFieldClientSystems`), drawn when the read's `clientSystems` is true or the service already holds entries.
    - Each entry shows its address, a Remove button and, when `clientRoles` is true, its roles (`tableEmptyValue` for none) and an Edit roles button.
    - The add field (`serviceAddressField`) and button (`serviceAddressAdd`) are drawn only when `clientSystems` is true. They take one bare address: the client refuses a `|` with `serviceAddressNoRoles`.
    - An empty list shows `serviceAddressAnyCaption`.
  - One Save applies every tab. A refused field opens its tab, and each tab's accessible name counts its errors (`core/form-tabs.ts`).
- **Edit roles** opens `ServiceRolesDialog`, titled `serviceAddressRolesTitle` with `<address>` filled in. It shows one checkbox per role option from the read, in the read's order. Apply (`actionApply`) writes the ticked roles into that entry in the form buffer; Cancel (`actionCancel`) changes nothing. Only Save sends anything.
- **Entries on the wire.**
  - An entry the form did not touch is sent exactly as read.
  - An entry it adds or whose roles it changes is composed `address` or `address|role,role`.
  - The Save body is still `PUT /services/:id` carrying only the changed fields among `Enabled`, `AutheEnabled` (the whole mask) and `ClientSystems` (the whole list).
- **Consequence lines, drawn while the change stands** (EXPERIENCE.md :507, AD-10):
  - On the serving service, a changed `ClientSystems` or `AutheEnabled` shows `serviceEffectServesOcuPilot` under that field.
  - On any other service, newly ticking Unauthenticated (bit 64) shows `serviceEffectUnauthenticated` under the methods.
  - An entry that gains a role the read marks `privileged` shows `privilegedGrantEffect` under the connection list.
- **The serving service** (`%Service_WebGateway`): Service enabled is drawn `aria-disabled`, with `serviceRefusalServing` as its described reason. Its methods and addresses stay editable. A Save that turns it off is refused 403 `PROHIBITED.SERVINGSERVICE` before any port write, as in 9.9.
- **The form read** `GET /services/form?name=` keeps `{service, servesOcuPilot}` and adds:
  - `authenticationMethods`: `[{bit, label}]`. It lists every bit that is in both the service's `AutheEnabledCapabilities` and the instance's `Security.System` `AutheEnabled`, in the classic page's `AuthList` order: 64, 16, 131072, 32, 128, 4, 2, 1, 512, 256, 8, 8192, 2048, 2097152, 1048576, 33554432, 67108864.
    - Each label is the instance's own message from domain `%SECURITY.Services`, read with `$$FormatMessage^%occMessages` as `Area/WebApp/FormRules.Methods` does.
    - The array is empty when the service's `Capabilities` lacks bit 2 (value 4).
  - `clientSystems`: the service's `Capabilities` bit 3 (value 8).
  - `clientRoles`: the service's `Capabilities` bit 4 (value 16).
  - `connections`: `[{entry, address, roles[]}]`, one per stored entry, parsed by the shared entry rule below.
  - `roles`: `[{name, privileged}]` from `Security.Role` `LIST` through the tool's port (the `FormRules.Roles` precedent). It is present only when `clientRoles` is true; otherwise it is `[]`.
    - `privileged` is the kernel's own verdict for that role on a service address: `Prohibited.GrantsPrivilegeByEffect("service", {"ClientSystems": ["0.0.0.0|<role>"]}, {"ClientSystems": []}, .g)`. The form's line and the agent's destructive card therefore cannot disagree.
- **The shared entry rule** (`ServiceRules.EntryParts`) splits an entry the way the classic page reads it (`DrawConnectionTable`):
  - The separator is `|` when the entry holds a `|` or more than one `:`, and `:` otherwise.
  - The address is the part before the separator. The roles are the comma-separated part after it, with empty names dropped.
  - `ServiceRules.Canonical(entry)` answers `address` or `address|role,role`.
  - Rules, form read and canonicalization all use this one rule.
- **The tool's merge** (`ServiceUpdate.MergeUpdate`, both callers) rewrites to `Canonical` every `ClientSystems` entry that is not exactly an entry of the fresh read, then delegates to the kernel merge. An entry the vendor's own editor wrote as `10.0.0.6:%Manager` and nobody touched is sent unchanged.
- **Rules**, shared by the mint's `ArgumentProblem` and the Save (AD-55). Each is a `{field: ClientSystems, code, reason}` violation. The existing three rules stay. The existing role check now also reads roles written after `:`. The three new rules judge only **added or changed** entries (those not exactly in the fresh read):
  - `SERVICE.ADDRESS.INVALID`: `Security.Services.ValidateClientSystemsIP(address)` answers 1, 2 or 3. It answers 0 and 4 for addresses the classic page accepts, as `ValidateIP` does.
  - `SERVICE.ADDRESS.UNSUPPORTED`: the service is held and its `Capabilities` lacks bit 3.
  - `SERVICE.ADDRESS.ROLEUNSUPPORTED`: the entry carries roles, the service is held, and its `Capabilities` lacks bit 4.
  - A capability rule is not judged for a service the instance does not hold, as the existing method rule is not.
  - The codes and their sentences live in a new `Api/ServiceError.cls`, because `Api/Error.cls` is at its 1,000-parameter limit. `Error.ReasonForService` and `ServiceViolationCodes` resolve and list them through it.
- **Pairs.**
  - `ServiceUpdate` declares `CLASSICPAGES` `%CSP.UI.Portal.Dialog.Service`, and its `PrivilegePairs` unions it through `Screen.Gate.WithClassicPages`, as `LockRemove` does.
  - `ServiceSave.Gate` then evaluates the tool's own `PrivilegePairs` after the form's gate (the `LanguageServerSave.Gate` pattern). The mint, Confirm and the Save refuse alike (AD-44).
- **DW-1016.**
  - The write-tool base declares `Parameter EMPTYKEYS = ""`: comma-separated `Field=stringKey` pairs. `ServiceUpdate` declares `ClientSystems=serviceAllowedUnrestricted`.
  - When the mint builds a proposal's diff, a row whose field is declared has any empty value (`""` or `[]`) sent as `""`, and the row carries `emptyKey`. `Kernel/Proposal/Disclosure.Rows` does the same for an unchanged row.
  - The card's `shown(value, emptyKey)` reads `STRINGS[emptyKey]` for an empty value when that key exists, and `tableEmptyValue` otherwise.
- **Probes.**
  - Every service a test writes is disabled, snapshotted first and restored in teardown that also runs on failure:
    - `%Service_CacheDirect` for addresses and methods (capabilities 911: methods, addresses, no roles);
    - `%Service_ECP` for roles (921: addresses with roles, no methods);
    - `%Service_CallIn`, as today, for refusals.
  - `ServiceLdapProbe` refuses any other name, and any enabled service.
  - `%Service_WebGateway` is never written by any test, mutation or browser leg: its legs mint, save through `HeldPutPort`, or only draw.
- **Shared files.** Changes are add-only, apart from the declared edits named in Tasks.
  - EXPERIENCE.md stays at 993 lines; its rows are edited in place, and `npm run test:tools` stays green.
  - `Prohibited.cls`, `Screen/Registry.cls`, `Test/Descriptor.cls`, `screen-mirror.mjs`, `Api/ScreenAction.cls`, `Confirm.cls` and `Screen/Tool/Registry.cls` are not edited: Epic 23 holds them.
  - `Write.cls` is also held by Epic 23; it gets one parameter appended at its end.
  - Check Epic 23's footprint before each edit (spawn prompt).

**Never:**

- Write, enable, disable or re-address `%Service_WebGateway`, or any enabled service, from a test, mutation, probe or browser leg. Never touch `ocupilot`.
- Add a write tool, a governance key, a route or an entity type. Add a parameter to `Api/Error.cls`. Hand-edit `screens.generated.ts`, `FieldLists.cls` or `ToolFields.cls`.
- Edit `Kernel/Proposal/Prohibited.cls` (see Design Notes, Named limits).
- Compute a changed service's `ClientSystems` from a delta route. The Save sends the list whole over a fresh-read merge (Design Notes).
- Draw the classic-link card, or keep `service-form.ts`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Open a methods-and-addresses service | `%Service_CacheDirect` | General, Authentication methods (one box per offered bit, labels from the instance) and Allowed incoming connections with an add field and no Edit roles. No classic card. | none |
| Open a roles service | `%Service_ECP` | General and Allowed incoming connections, each entry with its roles and Edit roles. No methods tab. | none |
| Add, then delete, an address | CacheDirect: add `10.0.0.1`, Save; then Remove it, Save | 200 "Saved" each time. The list shows `10.0.0.1`, then "Unrestricted". `AutheEnabled` and `Enabled` read back unchanged. | none |
| Give an address a role | ECP holds `10.0.0.5`; Edit roles, tick `%Operator`, Apply, Save | Stored `10.0.0.5\|%Operator`; the editor re-reads it with that role | none |
| Classic spelling | ECP holds `10.0.0.6:%Manager` | The editor shows address `10.0.0.6` and role `%Manager`. A Save that changes another entry sends it unchanged. | none |
| Agent writes the classic spelling | Agent: ECP `ClientSystems: ["10.0.0.9:%All"]` | The payload carries `10.0.0.9\|%All`. The proposal is destructive with the privilege-grant consequence. | none |
| Invalid address | Add `999.1.1.1` (Save or agent) | Nothing is sent. The Save opens the connections tab on the field. | 422 / 400 `SERVICE.ADDRESS.INVALID` |
| Address on a service that checks none | Agent or Save: `%Service_CallIn` `ClientSystems: ["10.0.0.1"]` | Nothing is sent | `SERVICE.ADDRESS.UNSUPPORTED` |
| Role on a service that gives none | CacheDirect `["10.0.0.5\|%Operator"]` | Nothing is sent | `SERVICE.ADDRESS.ROLEUNSUPPORTED` |
| Methods | CacheDirect: tick Unauthenticated | The line `serviceEffectUnauthenticated` appears. Save stores the mask with bit 64 and keeps every bit not offered. | none |
| Serving service, screen | `%Service_WebGateway` | Enabled is `aria-disabled` with the published sentence. Changing methods or addresses shows `serviceEffectServesOcuPilot` (drawn only; never saved). | A direct disable Save: 403 `PROHIBITED.SERVINGSERVICE` via `HeldPutPort`, nothing sent |
| Serving service, agent | Agent turns it off | The mint refuses with the published sentence; the kernel refuses at Confirm | `TOOL.ARGUMENTS` / `PROHIBITED.SERVINGSERVICE` |
| DW-1016 | Agent restricts an unrestricted service; separately changes only `Enabled` | The card reads `ClientSystems: Unrestricted → ["10.0.0.1"]`, and an unchanged empty list reads "Unrestricted" under the disclosure | none |
| Classic page resource | A custom resource on `%CSP.UI.Portal.Dialog.Service` | A caller lacking it is refused by name at the mint, at Confirm and on the Save, before any port call | 403 |
| Least privilege | A principal with exactly the form's two pairs | It reads the form and saves an address on CacheDirect | none |
| Absent | Open or PUT an unknown name | "This service no longer exists." | 404 `SERVICE.ABSENT` |

</intent-contract>

## Code Map

Anchors are at `8ca52993`. S = `src/OcuPilot/`, U = `ui/src/app/`.

**Measured on `ocupilot-ci`, 2026-09-30** (the transcript is in the session scratchpad, `epic-16/16-13/`; every probe restored what it found):

- **Capabilities** (`Security.Services.Get`), with bit 2 = methods, bit 3 = addresses and bit 4 = roles:

  | Service | Capabilities | What it has |
  |---|---|---|
  | `%Service_WebGateway` | 911 | methods and addresses, no roles; offered methods 32, 64, 128, 256, 512, 33554432 |
  | `%Service_CacheDirect` | 911 | methods and addresses, no roles |
  | `%Service_ECP` | 921 | addresses with roles, no methods |
  | `%Service_CallIn` | 903 | methods only |
  | `%Service_Terminal` | 775 | methods only |
  | `%Service_Login` | 901 | methods only |
  | `%Service_DocDB`, `%Service_Mirror` | 897 | nothing but Enabled |
  | `%Service_DataCheck`, `%Service_Monitor`, `%Service_Shadow`, `%Service_Sharding`, `%Service_Weblink` | 905 | addresses only |

  The system `AutheEnabled` is 33556471.
- **`%Api.Admin.Endpoints.Security.Service`** source (read with `GetTextAsString`):
  - GET answers `{AutheEnabled, ClientSystems[], Description, Enabled}`.
  - PUT merges through its own `MergeJsonAndProperties`, which sets only the keys the body defines, joins `ClientSystems` with `;`, and calls `Security.Services.Modify`.
  - Measured through `AdminPort`: a PUT carrying only `ClientSystems`, then only `AutheEnabled`, kept the other fields.
- **`Modify` stores whatever it is given**, silently, including `999.1.1.1`, `no-such-host.invalid`, and `10.0.0.5|%Operator` on CacheDirect, which has no roles. `ValidateClientSystemsIP` answers:
  - 0 for `10.0.0.1`, `10.0.0.1-20`, `10.0.0.*`, `localhost`, `::1` and `fe80::1`;
  - 1 for `999.1.1.1` and `10.0.0.0/24`;
  - 2 for `a b`;
  - 4 for `no-such-host.invalid`.
- **Audit.** Each `Modify` records `%System/%Security/ServiceChange` (registered, enabled). This is not a new AD-15/AD-53 case.
- **Labels** (`%SECURITY.Services`): 64 "Unauthenticated", 16 "Operating System", 32 "Password", 128, 4 and 2 each "Kerberos", 512 "Kerberos with Packet Integrity", 256 "Kerberos with Encryption", 8192 "Delegated", 2048 "LDAP", 33554432 "Mutual TLS" and 67108864 "OAuth2".

**Server:**

- **`S/Screen/Descriptor/ServiceForm.cls:1-52`**: the declaration and doc. `:47` is the exemption.
- **`S/Screen/Descriptor/ServiceList.cls:26-29`**: its doc names the reduced form and card.
- **`S/Screen/Tool/ServiceUpdate.cls`**:
  - `InputSchema` is `:66-81`, and its descriptions name the entry grammar.
  - `ArgumentProblem` `:88-110`, `Consequence` `:118`, `PrivilegePairs` `:128-135`.
  - It has no `MergeUpdate` override yet; the base is `S/Screen/Tool/Write.cls:350`. The base's `CLASSICPAGES` is at `:124`, and the class ends at `:830`.
- **`S/Screen/Tool/LockRemove.cls:71,130-138`**: the `CLASSICPAGES` and `PrivilegePairs` pattern.
- **`S/Area/Permissions/ServiceRules.cls`**:
  - `Validate` `:35`, `AddressViolations` `:80` (splits on `|` only), `EntryShaped` `:130`;
  - `Capabilities` `:149` (reads `AutheEnabledCapabilities`; extend it to return `Capabilities`), `Changed` `:187`, `HandleForm` `:227-262`, `Gate` `:307`.
- **`S/Area/Permissions/ServiceSave.cls`**: `Update` `:84-135` (rules, then the tool's `MergeUpdate`, then prohibited, then the port) and `Gate` `:205-218`.
- **`S/Area/OsMgmt/LanguageServerSave.cls:325-341`**: the Gate-with-tool-pairs pattern.
- **`S/Area/WebApp/FormRules.cls`**: `SERVICESDOMAIN` `:29`, `AUTHEMETHODS` `:51`, `Methods` `:248-274`, `Roles` `:405-430` (`Security.Role` `LIST` through the tool's port).
- **`S/Api/Error.cls`**: the service codes are at `:4044-4069`, `ReasonForService` at `:4104-4110`, and `ServiceViolationCodes` at `:4114-4117`. Delegate from these two. The model is `S/Api/LockError.cls` and its callers at `S/Api/Error.cls:1512-1543`.
- **`S/Kernel/Proposal/Mint.cls`**:
  - the diff is final after `:242-257`, and is stored at `:303` and returned at `:362`;
  - `Display` `:879` renders an array as compact JSON.
- **`S/Kernel/Proposal/Disclosure.cls:45-81`** builds the unchanged rows. `S/Kernel/State/Propose.cls:746` passes stored diff rows to the wire verbatim.
- **`S/Kernel/Proposal/Prohibited.cls`** (read only, not edited):
  - `ServingServiceDisabled` `:4071`, `ServiceWeakening` `:4083`;
  - `AddressGrantsPrivilege` `:4103` (splits on `|`, judges roles with `IsPrivilegedRole` `:3123`);
  - `GrantsPrivilegeByEffect` `:3013`, whose service branch is at `:3036`.
- **Tests:**
  - `S/Test/ServiceUpdate.cls`: its seams are `Fresh` `:226`, `Mint` `:232` and `Stored` `:255`. The descriptor test is `:200-221` and must be rewritten. `PROBE` is an absent name, so the capability rules skip it.
  - `S/Test/ServiceEdit.cls` (armed `OCUPILOT_ALLOW_SERVICE_CONFIG`) writes `%Service_CallIn` at `:81,104,135,141,163,186,192`. It snapshots one service in `OnBeforeAllTests` `:50-60` and restores it in `OnAfterOneTest` `:65-67` and `OnAfterAllTests` `:70-72`.
  - `S/Test/ServiceLdapProbe.cls:27,43-74`: `SERVICE`, `Snapshot` and `Restore`.
  - `S/Test/ClassicPageGate.cls:62,131` (`OWNPAIRS` and the "thirty" message); `S/Test/SurfaceCoverage.cls:138`; `S/Test/ProposalWire.cls:193-277` (disclosure rows).
- **Arming.** `scripts/ci-throwaway.sh:352-359` is the `OCUPILOT_ALLOW_SERVICE_CONFIG` block; its comment names `%Service_CallIn` only.

**Client:**

- **Registration:**
  - `U/shell/screen-outlet.ts:159,192` register ServiceForm to `ReducedFormPage`; the pattern is `:185-189` (WebAppForm to `WebAppEditorPage`).
  - `U/shell/screen-outlet.spec.ts:431-439`.
- **The reduced form:**
  - `U/shell/reduced-form.page.ts:15,29-31,240` (the import, `REDUCED_FORMS`, the `?? SERVICE_FORM` fallback) and its serving options at `:155-179,343,408-413`;
  - `U/core/reduced-form.store.ts:48-71,209-219`;
  - `U/areas/permissions/service-form.ts` is deleted;
  - the specs that use `SERVICE_FORM` or the ServiceForm screen are `U/shell/reduced-form.page.spec.ts:23,27,114,147-177,220-257` and `U/core/reduced-form.store.spec.ts:4,17,51-150`.
- **Editor pattern** (`U/areas/web-applications/web-app-editor.{page,store}.ts`):
  - tabs: page `:193-194,658-666`, store `:23-25,105-108`;
  - method checkboxes: page `:220-233,1039-1045,878`, store `setAuthe` `:521-526`;
  - effect lines: `:736,984-989`;
  - the Save: store `:408-426,550-597`;
  - `FormDirty`, "Saved" and the summary: page `:169-180,841-850,922-937,1003-1019`.
  - The role options are `U/areas/web-applications/create-form.store.ts:64-78,678-700`.
- **Dialog pattern.** `U/areas/permissions/role-grant-dialog.ts:67-120,176,243` and `U/shell/dialog.ts:50-84`.
- **Strings.** In `U/core/strings.ts`, the service block is `:2224-2275` and `} as const` is at `:4027`. The keys reused are `processDetailsGroupGeneral` `:1020`, `tableColumnName` `:359`, `tableColumnDescription` `:385`, `userColumnRoles` `:379`, `actionRemove` `:1569`, `actionApply` `:1827`, `privilegedGrantEffect` `:1575` and `serviceAllowedUnrestricted` `:782`. The literal bound is `ui/tools/strings.test.mjs:572`.
- **DW-1016.**
  - `U/core/turn.ts:180-205,531-560`;
  - `U/core/proposal-view.ts:35-50,470-495`;
  - `U/shell/proposal-card.ts:137,152,157,191,541`;
  - `U/shell/proposal-card.spec.ts:164-235`;
  - `ui/tools/turn.test.mjs`, and `ui/tools/proposal-view.test.mjs:439-460` (the `optional` pass-through precedent).
  - `ui/tools/proposal.test.mjs:415-462` is a literal scan. It forbids a literal after `before|after|unchanged|consequence…:`, and a `method: 'PUT'` with `changed|diff|payload` within 200 characters. Keep the store's publish more than 200 characters from its PUT, as `web-app-editor.store.ts` does.
- **Rosters that pin the exemption:**
  - `ui/tools/classic-links.test.mjs:445-458` (count 2);
  - `ui/tools/floor.test.mjs:53-56,86-94`;
  - `ui/browser/oauth.browser-spec.mjs:370-374`.
  - `ui/tools/classic-links.mjs:410` computes the count and pins nothing.
- **Browser.**
  - `ui/browser/reduced-editors.browser-spec.mjs`: the service legs are `:195,221,286` and the service half of `:304`. The `%Service_CallIn` snapshot is at `:43-114`.
  - The structural pattern is `ui/browser/background-tasks.browser-spec.mjs:29,87`, using `structural-walk.mjs:531` `detectScreen`.
- **Bundle.** `ui/angular.json:54-55` holds 2346kB and 4000kB, pinned at `ui/tools/angular-json.test.mjs:390-391`.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`): rows `:126`, `:503`, `:505`, `:507`, `:614` and `:729`.

## Tasks & Acceptance

**Execution:**

Server:

- **`S/Api/ServiceError.cls` (new)**: the `LockError` pattern.
  - Codes: `ADDRESSINVALID` = `SERVICE.ADDRESS.INVALID`, `ADDRESSUNSUPPORTED` = `SERVICE.ADDRESS.UNSUPPORTED`, `ADDRESSROLEUNSUPPORTED` = `SERVICE.ADDRESS.ROLEUNSUPPORTED`.
  - Sentences:
    - "Use an IP address, a range such as 10.0.0.1-20, a wildcard such as 10.0.0.*, or a host name."
    - "This service does not check the address a connection comes from, so it takes no allowed address."
    - "This service gives a connection no roles by its address, so an address here takes no roles."
  - `ViolationCodes()` and `ReasonFor()`.
- **`S/Api/Error.cls`**: two declared edits. `ReasonForService` falls through to `ServiceError.ReasonFor`, and `ServiceViolationCodes` appends `ServiceError.ViolationCodes()`. No parameter is added.
- **`S/Area/Permissions/ServiceRules.cls`**:
  - add `EntryParts` and `Canonical` (Boundaries);
  - `AddressViolations` reads roles through `EntryParts`;
  - `Validate` adds the three rules over the added or changed entries against `pFresh`;
  - `Capabilities` also answers the service's `Capabilities`;
  - `HandleForm` answers the five new members.
  - `ValidateClientSystemsIP` and `Security.System` are read in `%SYS` with the restore first in each `Catch` (AD-16).
- **`S/Screen/Tool/ServiceUpdate.cls`**:
  - `MergeUpdate` canonicalizes the added or changed entries, then calls `##super`;
  - add `CLASSICPAGES` and `EMPTYKEYS`;
  - `PrivilegePairs` goes through `WithClassicPages`;
  - the `InputSchema` descriptions name the entry grammar and the capability refusals.
- **`S/Area/Permissions/ServiceSave.cls`**: `Gate` also evaluates `ServiceUpdate.PrivilegePairs`.
- **`S/Screen/Tool/Write.cls`**: append `Parameter EMPTYKEYS = "";` with its doc, at the class's end (add-only).
- **`S/Kernel/Proposal/Mint.cls`**: one private helper, called on the final diff before `:303`, applies the tool's `EMPTYKEYS` to diff rows (Boundaries).
- **`S/Kernel/Proposal/Disclosure.cls`**: `Rows` applies the same declaration to unchanged rows, through the tool its registry lookup already resolves.
- **`S/Screen/Descriptor/ServiceForm.cls`, `ServiceList.cls`**: the exemption becomes `exempt: false`, and the doc comments are rewritten for the full editor. Then regenerate `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`, never by hand.

Server tests (one class per run, on `ocupilot-ci`):

- **`S/Test/ServiceLdapProbe.cls`**: add `SnapshotOf(name)` and `RestoreOf(name, snapshot)` over an allow-list of `%Service_CallIn`, `%Service_CacheDirect` and `%Service_ECP`. Each refuses an enabled service. `SERVICE`, `Snapshot` and `Restore` keep their meaning.
- **`S/Test/ServiceUpdate.cls`** (unarmed, fixture port):
  - rename the descriptor test to `TestTheFormDescriptorIsBuiltUnlistedAndLinksNowhere`. It asserts `exempt` 0, `ClassicLinkProblem` "", and a sentence for every `ServiceViolationCodes` code;
  - add these legs:
    - the `EntryParts`/`Canonical` corpus (`a`, `a|r1,r2`, `a:r`, `::1`, `fe80::1|r`);
    - canonicalization in the stored payload for `10.0.0.9:%All`, minted destructive with `GRANT.PRIVILEGED`;
    - the three rules at the mint against held services (CallIn and CacheDirect are read, never written);
    - `ValidateClientSystemsIP` pinned on the corpus above (0/1/2/4);
    - the DW-1016 rows: a `ClientSystems` row `before` "" with `emptyKey` `serviceAllowedUnrestricted`, and an `Enabled`-only proposal whose `Disclosure.Rows` carries an unchanged `ClientSystems` `{value: "", emptyKey}`;
    - `PrivilegePairs` equal to `WithClassicPages(<list pairs>, "%CSP.UI.Portal.Dialog.Service")`.
  - Keep it under 500 lines; split into `Test/ServiceUpdateRules.cls` if it passes that.
- **`S/Test/ServiceEdit.cls`** (armed):
  - every leg that writes an address moves to `%Service_CacheDirect`, including the `HeldPutPort` canary;
  - add these legs:
    - the form read for CacheDirect, ECP and the serving service (read only). The expected methods are computed from `Security.Services`/`Security.System` on the instance, not transcribed;
    - a stored `10.0.0.6:%Manager` on ECP, parsed by the form read and kept verbatim by a Save that adds another entry;
    - an ECP role Save read back as `10.0.0.5|%Operator`;
    - a CacheDirect method Save that keeps bits not offered;
    - the three rules on the Save as 422 with their `field` and `reason`.
  - The least-privileged leg adds its address on CacheDirect.
  - The class snapshots CallIn, CacheDirect and ECP in `OnBeforeAllTests` through `SnapshotOf`. `OnAfterOneTest` restores each through `RestoreOf` and asserts that it reads back as its snapshot (the residue assertion AC11 names). `OnAfterAllTests` restores again.
  - Split into `Test/ServiceEditRoles.cls` if it passes 500 lines. Any new armed class joins a new `# classes:` line in the `OCUPILOT_ALLOW_SERVICE_CONFIG` block, with `ui/tools/ci.test.mjs` kept equal.
- **`S/Test/ClassicPageGate.cls`**: `OWNPAIRS` gains `permissions.services.update=`, and the "thirty" message is bumped by one.
- **`S/Test/SurfaceCoverage.cls:138`**: a declared edit. The `ServiceForm` row's `method` becomes the renamed test.
- **`scripts/ci-throwaway.sh`**: append a comment line under the service block naming `%Service_CacheDirect` and `%Service_ECP`, each disabled, snapshotted and restored.

Client:

- **`U/areas/permissions/service-editor.store.ts`, `service-editor.page.ts` (new)**: the editor under Boundaries, mirroring the web-application editor's tabs, dirty guard, summary, "Saved", `ChangeBus` publish (`service`/`updated`/`readBack`) and field-to-tab map.
- **`U/areas/permissions/service-roles-dialog.ts` (new)**: the Edit roles dialog.
- **`U/shell/screen-outlet.ts`**: register `ServiceEditorPage` for ServiceForm in both maps.
- **`U/shell/reduced-form.page.ts`, `U/core/reduced-form.store.ts`**: drop the service declaration; the fallback becomes `LDAP_FORM`. Delete **`U/areas/permissions/service-form.ts`**. The serving options stay, still exercised by the specs.
- **`reduced-form.page.spec.ts`, `reduced-form.store.spec.ts`**: move each service case to a spec-local `ReducedFormDeclaration` fixture keeping its assertion, so the generic page keeps its serving and list coverage.
- **`U/core/turn.ts`, `U/core/proposal-view.ts`, `U/shell/proposal-card.ts`**: `emptyKey` on the diff and unchanged row types, copied when it is a non-empty string, and `shown(value, emptyKey)`.
- **`U/core/strings.ts`**:
  - append `serviceAddressRolesEdit: 'Edit roles'` and `serviceAddressRolesTitle: 'Roles for <address>'`, each cited `/** EXPERIENCE.md:503 */`;
  - declared edit: `serviceAddressNoRoles` becomes 'Enter one address, with no roles.'
- **EXPERIENCE.md, in place** (still 993 lines):
  - `:126`: the tabs are the classic page's groups, each drawn where the service has it; no classic card.
  - `:503`: rewritten for the service editor, carrying every string above (`[AMENDED 2026-09-30 - Story 16.13]`).
  - `:505`: "the service editor and the reduced LDAP form at their bare route".
  - `:507`: "shown under the field that changes it".
  - `:614`: "empty values read "(none)", or the word the tool declares for that field: an empty allowed-address list reads "Unrestricted" (DW-1016)".
  - `:729`: drop "Service editor" and "disable OcuPilot's web service" (AD-10 governs; the epic context's stale row).
- **Client tests:**
  - `service-editor.store.spec.ts`, `service-editor.page.spec.ts` and `service-roles-dialog.spec.ts` (new);
  - `screen-outlet.spec.ts` (a ServiceForm leg to `ServiceEditorPage`; LDAP alone stays on `ReducedFormPage`);
  - `proposal-card.spec.ts` ("Unrestricted" on a changed and an unchanged row, "(none)" without a key);
  - `ui/tools/turn.test.mjs` (`emptyKey` survives both parsers);
  - `ui/tools/proposal-view.test.mjs` (every `Parameter EMPTYKEYS` in `src/OcuPilot/Screen/Tool/*.cls` names an existing `STRINGS` key);
  - `ui/tools/classic-links.test.mjs` (`LdapConfigForm.cls` alone; `1 exemption(s)`, `1 descriptor(s)`);
  - `ui/tools/floor.test.mjs` (the LDAP form ends with its exemption, and `ServiceForm` declares none);
  - `ui/tools/strings.test.mjs` (the literal bound and the 9.9 row count if crossed, with a comment).
- **`ui/browser/service-editor.browser-spec.mjs` (new; legs guarded to `-ci` containers; each restores in `finally`)**:
  1. the name cell opens the editor, the CacheDirect tabs and labels, and no classic card;
  2. add, Save, list, Remove, Save, "Unrestricted";
  3. ECP Edit roles, Apply, Save, read back through `docker exec`;
  4. the serving service's Enabled `aria-disabled` with its sentence, and the consequence line on a drawn change, which is then discarded (Cancel), never saved;
  5. the DW-1337 structural walk of the editor at an id route, in both themes.
- **`ui/browser/reduced-editors.browser-spec.mjs`**: remove the service legs and the CallIn snapshot, keeping the LDAP legs and the LDAP half of the visual gate.
- **`ui/browser/oauth.browser-spec.mjs:372`**: a declared edit; the roster becomes `['LdapConfigForm.cls']`.
- **Bundle.** If `npm run build` crosses `maximumWarning`, raise it and its `angular-json.test.mjs` literal to the measured total rounded up to the next kB (DW-1166). HALT `blocked` above 3800kB.

- **Fix pack (routed by the orchestrator at the 1.0.4 candidate review; lead edit at the spec gate):**
  - **DW-1879** -- `ui/src/app/shell/` side bar: a gated entry (the Logs side bar's "Interoperability event log", `%Ens_EventLog:USE`) draws its "Requires <pair>" reason as a second column that wraps the label onto two lines. Render the reason inline after the name, per UX-DR22 and EXPERIENCE.md's Privilege Gating row, keeping it the entry's described reason. Pin it in the side bar's component spec and in the structural walk of an existing browser spec that already shows a gated entry (both themes); record the mutation.
  - **DW-1880** -- Database details' "Volume files" table (the database details page under `ui/src/app/areas/`) is unstyled, with a browser-default serif bold header. Draw it with the shared data-table styling so its header takes the shell font, as DW-1837 did for its table. Pin it with a browser assertion on the header's computed `font-family` (jsdom computes no style) and record the mutation.

**Acceptance Criteria:**

- **AC1 (coverage).** Given the Services list, when a service's name cell is followed, then the editor opens with General (name, description, Service enabled), Authentication methods (the offered methods, with the instance's labels) and Allowed incoming connections (each address with Remove and, where the service gives roles, its roles and Edit roles). Each tab is drawn only where the service has that group, and no classic-portal card is drawn. Pinned by the browser legs 1 and 3 and by `service-editor.page.spec.ts`.
- **AC2 (add and delete).** Given `%Service_CacheDirect`, when an address is added and saved and then removed and saved, then each Save answers "Saved" and the Services list shows the address, then "Unrestricted", with every other field unchanged. Pinned by `ServiceEdit` and browser leg 2.
- **AC3 (roles).** Given `%Service_ECP`, when Edit roles ticks `%Operator` for an address and the form is saved, then the instance holds `address|%Operator`. A role the kernel marks privileged shows `privilegedGrantEffect` before Save. A stored `address:role` entry reads with its roles and is sent back verbatim. Pinned by `ServiceEdit`, `service-roles-dialog.spec.ts` and browser leg 3.
- **AC4 (methods).** Given `%Service_CacheDirect`, when Unauthenticated is ticked and saved, then `serviceEffectUnauthenticated` shows before Save, and the stored mask gains 64 and keeps every bit the form did not offer. Pinned by `ServiceEdit` and `service-editor.store.spec.ts`.
- **AC5 (serving service, screen).** Given `%Service_WebGateway`, when the editor opens, then Service enabled is `aria-disabled` with "OcuPilot is served through this service. Turning it off would cut off every user, including you.", its methods and addresses stay editable, and a change to either shows the served-through line. A disable Save is refused 403 `PROHIBITED.SERVINGSERVICE` before any port write. Pinned by browser leg 4 (drawn only), `service-editor.page.spec.ts`, and `ServiceEdit`'s `HeldPutPort` leg.
- **AC6 (serving service, agent).** Given the agent proposes turning `%Service_WebGateway` off, when it reaches the write path, then the mint refuses with the published sentence and the kernel refuses `PROHIBITED.SERVINGSERVICE` at Confirm. No tool turns it off. Pinned by `ServiceUpdate`'s existing serving legs, re-run.
- **AC7 (the refusals).** Given an added invalid address, an address on a service that checks none, or a role on a service that gives none, when either caller sends it, then nothing is sent and the refusal names `ClientSystems` with its sentence: 400 at the mint, and 422 on the Save, whose editor opens the connections tab. An agent's `address:role` entry is sent as `address|role` and judged by the kernel. Pinned by `ServiceUpdate` and `ServiceEdit`.
- **AC8 (DW-1016).** Given an agent proposal that restricts an unrestricted service, when its card renders, then the `ClientSystems` row reads "Unrestricted" before the arrow, and an unchanged empty list under the disclosure reads "Unrestricted". Every other field's empty value still reads "(none)". Pinned by `ServiceUpdate` (the wire rows), `proposal-card.spec.ts` and `turn.test.mjs`.
- **AC9 (the exemption).** Given the built descriptors, when `classic-links.mjs` runs, then it honors exactly one exemption, declared by `LdapConfigForm`, and `ServiceForm` declares none. Pinned by `classic-links.test.mjs`, `floor.test.mjs`, `ServiceUpdate`'s descriptor test and the OAuth roster.
- **AC10 (the classic page resource).** Given a custom resource assigned to `%CSP.UI.Portal.Dialog.Service`, when a caller lacking it calls the tool or the Save, then it is refused 403 naming that pair before any port call. Pinned by `ClassicPageGate`.
- **Integration.** Given `ServiceEditorPage`, which reads `GET /services/form` and saves through `PUT /services/:id`, when a Save succeeds, then the Services list re-reads (`ChangeBus` `service` `updated`) and shows the new value. The browser observes this.
- **AC11 (hygiene).** Given any test in this story, when it ends, pass or fail, then every service it wrote reads as its snapshot, and `%Service_WebGateway` was never written.

### Review Findings

Code review 2026-09-30 (full-opus, four layers): 50 rows, 17 entries after grouping (0 high, 4 medium, 13 low), 22 rows rejected.

- [x] [Review][Patch] (med) The Save gate's new tool-pairs check had no test: the AC10 Save leg assigned `%CSP.UI.Portal.Dialog.Service`, which `ServiceForm`'s own classic page already gated [src/OcuPilot/Test/ClassicPageGate.cls:260] -- the leg, renamed `TestAnAssignedPageGatesTheServiceSave`, also assigns `%CSP.UI.Portal.Services`; its `OWNPAIRS` doc names the service update.
- [x] [Review][Patch] (med) The tab-name assertion held with no error count [ui/src/app/areas/permissions/service-editor.page.spec.ts:242] -- now `tabAccessibleName(label, 1)`.
- [x] [Review][Patch] (med) DW-1016's after side (a restriction removed) was unpinned [src/OcuPilot/Test/ServiceUpdate.cls:333, ui/src/app/shell/proposal-card.spec.ts:251] -- a mint leg and a card row.
- [x] [Review][Patch] (low) `:%Operator` passed the shape rule, and the mint and the Save answered 500 from `Prohibited.AddressGrantsPrivilege` on its empty address [src/OcuPilot/Area/Permissions/ServiceRules.cls:279] -- `EntryShaped` refuses an empty address in either spelling; a mint leg.
- [x] [Review][Patch] (low) `Validate`'s doc said a held entry is never refused; the shape and role rules still judge it (spec-bound) [src/OcuPilot/Area/Permissions/ServiceRules.cls:74] -- doc corrected.
- [x] [Review][Patch] (low) The add field took `10.0.0.6` beside a held `10.0.0.6:%Manager` [ui/src/app/areas/permissions/service-editor.store.ts:423] -- compares addresses; a store spec leg.
- [x] [Review][Patch] (low) ECP's role options were never read by the least-privileged principal [src/OcuPilot/Test/ServiceEdit.cls:352] -- a read leg.
- [x] [Review][Patch] (low) EXPERIENCE.md :503 named only the `|` refusal [EXPERIENCE.md:503] -- names `address:role` too, in place (993 lines).
- [x] [Review][Patch] (low) A tautological "offers no box" assertion [src/OcuPilot/Test/ServiceEdit.cls:252] -- deleted (pinned by `TestTheFormReadNamesEachServicesGroups`).
- [x] [Review][Patch] (low) AC8's disclosure half had no recorded mutation -- recorded under Verification.
- [x] [Review][Patch] (low) The browser spec header claimed a methods change in the AC5 leg [ui/browser/service-editor.browser-spec.mjs:15] -- corrected.
- [x] [Review][Patch] (low) `ServiceEdit.Unchanged()` answered the services that moved [src/OcuPilot/Test/ServiceEdit.cls:387] -- renamed `Moved()`.
- [x] [Review][Patch] (low) `OnAfterOneTest`'s mutation note named `RestoreOf` for `RestoreAll` [src/OcuPilot/Test/ServiceEdit.cls:85] -- corrected.
- [x] [Review][Patch] (low) The budget test quoted 2,349,229 bytes [ui/tools/angular-json.test.mjs:378] -- the review build's 2,349,256.
- [x] [Review][Defer] (med) No control for `%Service_WebGateway`'s `HttpOnlyCookies`, which the classic dialog draws and the admin API cannot write -- deferred: DW-1883, decision-pending for the decision sheet.
- [x] [Review][Defer] (low) README still calls the service editor reduced with a classic link [README.md:491] -- deferred: DW-1884, wontfix-accepted (outside Epic 16's footprint).

Rejected:

- low: `ValidateClientSystemsIP` answers other than 0-4 pass -- none observed; the spec names 1, 2 and 3.
- low: a host-name check may resolve DNS per added entry -- the classic page makes the same call per add.
- low (x2): Edit roles back to the held roles respells a colon entry -- rare, harmless, and the fix adds a branch.
- low: no focus target for a refusal on a no-address service holding entries -- the sentence still draws; narrow case.
- low: the structural walk skips the roles dialog -- it is the shared `app-dialog` with shared checkbox fields.
- false: the absent leg stubs 200 null -- the store spec pins the real 404.
- low: `ci-throwaway.sh`'s comment reads twice -- add-only file, contended by Epic 23 now.
- low: `ServiceViolationCodes` redundant branch -- cosmetic, shared-append file.
- low: the `EMPTYKEYS` parser exists twice -- merging edits `Write.cls` (Epic 23) and recompiles every tool.
- low: the empty-list word is declared twice -- spec-bound (`EMPTYKEYS`); `proposal-view.test.mjs` pins the key.
- low: the reduced form keeps test-only branches -- spec-bound Task.
- low: the Auto Run Result misstates the Epic 23 overlap -- a spec narrative edit.
- low: the side-bar rules sit apart from the old block -- appended by the shared-append rule.
- low: `reduced-editors` leftovers; DW-1880 compares to the heading's font -- cosmetic; the mutation is recorded.
- low: a failed role read renders 500 -- its only gate is the form's own pair.
- low: the change event is not observed in the browser -- pinned in two component specs with a recorded mutation.
- false: DW-1879 lets the reason wrap under the name -- the name stays one line, the defect pinned.
- false: DW-1880 restyles other tables -- they already carried the unstyled class.
- false: `MappingDescriptor` roster edit undeclared -- an add-only row, reported outside the Code Map.
- low: `ServiceLdapProbe`'s allow-list refusal never runs -- a `RestoreOf` refusal leg would write the serving service if the guard broke.

## Spec Change Log

- 2026-10-01, lead, after code review (tier 1): the Named limit on `HttpOnlyCookies` said the CSP service does not exist on this build; it is `%Service_WebGateway`'s field, which the admin API cannot write (DW-1883).
- 2026-10-01, lead: the implement stage re-based the bundle's `maximumWarning` from 2346kB to 2350kB under DW-1166 (bundle 2,349,254 bytes); accepted by the orchestrator as a warning re-base, the 4000kB error limit unchanged.
- 2026-09-30, lead, spec gate: the fix pack's DW-1879 and DW-1880 (orchestrator-routed after planning) added under Tasks & Acceptance; the planner's four spine amendments written into the spine; the prohibited-set gap in its Named limits filed as DW-1881 for range-end cleanup.

## Review Triage Log

### 2026-09-30 — Review pass

- verdicts: 24 findings — high 0, medium 5, low 11, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` The form read's `roles[].privileged` is never checked on the instance (verification-gap) — `ServiceEdit.TestTheFormReadNamesEachServicesGroups` asserts ECP's `%All` 1 and `%Operator` 0; mutation run 22399.
  - `[low]` `[patch]` Which bit each method label toggles is checked only against `AUTHEMETHODS` itself (verification-gap) — the same test asserts the literal AuthList order and bits 64 and 32 against the instance's own messages; mutation run 22399.
  - `[medium]` `[patch]` The unknown-role rule for the `address:role` spelling is untested (verification-gap) — `ServiceUpdate.TestTheRulesRefuseAtTheMint` gains a `10.0.0.1:OcuPilotNoSuchRole99` leg; mutation run 22398.
  - `[medium]` `[patch]` The held-entry exemption of the added-entry rules is untested (verification-gap) — `ServiceEdit.TestTheAddressRulesRefuseTheSave` saves an address beside a held `10.0.0.5|%Operator` on CacheDirect (the tool's rules read the live service, so the leg is armed); mutation run 22399.
  - `[low]` `[patch]` The connections tab for a service that checks no address is untested (verification-gap) — store spec leg for CallIn with and without a held entry; mutation observed.
  - `[low]` `[patch]` The privilege-denial banner on a refused Save is untested (verification-gap) — page spec leg with a 403 `AUTH.NOPRIVILEGE`; mutation observed.
  - `[low]` `[patch]` The Integration AC has no `mutation:` line (verification-gap) — `save` without `publishUpdated` reddens the store and page Integration legs; line written.
  - `[low]` `[reject]` `ServiceUpdate.TestThePairsUnionTheClassicDialogsResource` compares values equal by construction on a default instance (verification-gap) — it still pins the list-pairs half; the union is pinned by `ClassicPageGate`'s AC10 mutation, and a stronger leg needs a custom-resource write this unarmed class must not make.
  - `[low]` `[patch]` `ServiceEdit`'s expected bits mirror the code under test (verification-gap) — grouped with the label finding; same fix.
  - `[medium]` `[patch]` AC3's privileged half is pinned only against client fixtures (verification-gap) — grouped with the `privileged` finding; same fix and mutation line.
  - `[medium]` `[patch]` The add field accepts `address:role`, granting a role past Edit roles with no privilege line (verification-gap, other) — `addAddress` also refuses an entry with exactly one `:`, as `EntryParts` reads it; store spec leg; mutation observed.
  - `[low]` `[patch]` `familyOf`'s doc comment sat above `gatedLayout` in `permissions-effective.browser-spec.mjs` (verification-gap, other) — moved back.
  - `[false]` `[reject]` DW-1016 has no end-to-end test from server output to the card (intent-alignment) — `Propose.cls:746` passes the stored diff verbatim and `:748` calls the `Disclosure.Rows` the test calls; every hop is pinned.
  - `[low]` `[reject]` The editor and the kernel read a held `address:role` entry differently, so a card can be destructive where the editor draws no line (intent-alignment) — the kernel's `|`-only split in `Prohibited.cls`, which the intent excludes; filed as DW-1881.
  - `[false]` `[reject]` No test sends a client-composed mask to the instance (intent-alignment) — the store spec pins the mask the client composes and `ServiceEdit` pins that a sent mask is stored; the labels half is grouped above.
  - `[false]` `[reject]` The classic-spelling server leg adds an entry rather than changing one (intent-alignment) — `MergeUpdate` keeps any held entry exact whatever else changes, and the page spec re-roles the other entry and sends the held one as read.
  - `[false]` `[reject]` Opening the connections tab on a server 422 is not joined in one test (intent-alignment) — the page spec pins it on a 422 of the shape `ServiceEdit` pins.
  - `[false]` `[reject]` The serving-consequence ordering moved from the mint to `Consequence()` (intent-alignment) — the intent's `ROLEUNSUPPORTED` rule now refuses that mint input; the order is still pinned.
  - `[false]` `[reject]` The AC10 Save leg uses an absent name (intent-alignment) — the lacking principal's 403 on an absent name shows the gate precedes the read, and the holder's 404 shows it passed.
  - `[low]` `[reject]` `RestoreOf` refuses an enabled snapshot but does not re-read the live service (intent-alignment) — every caller snapshots first, which refuses an enabled service; the gap is a throwaway-only race and the fix adds a read and a branch.
  - `[low]` `[reject]` The roles dialog also draws a held role the read does not list (intent-alignment) — each listed option is drawn once in order; the extra box keeps Apply from silently dropping a role nobody unticked.
  - `[false]` `[reject]` The fix pack, the budget and `REDUCED_FORM_DECLARATIONS` exceed the intent (intent-alignment) — all are the spec's Tasks; the token is the seam the Task's spec-local fixture needs.
  - `[low]` `[patch]` EXPERIENCE.md's confirm-dialog row still lists a "disable OcuPilot's web service" warning (intent-alignment) — phrase removed at origin (`:173` already says there is none); 993 lines, `test:tools` green.
  - `[false]` `[reject]` Whether `screens.generated.ts` was regenerated is undecidable (intent-alignment) — `screen-mirror.mjs --check` passes in the prebuild.

## Design Notes

**Governing ADs:**

- AD-3: no new field; the field lists and the classification are unchanged.
- AD-4: the merge; see the amendment.
- AD-5: the descriptor, and tabs as groups.
- AD-6: diff rows and `emptyKey`.
- AD-8 and AD-29: pairs; the Save's gate follows the tool.
- AD-10: the serving-service arm, unchanged.
- AD-13: `service:foldcase`, unchanged.
- AD-14.
- AD-15 and AD-53: the vendor audits `ServiceChange`, so this is not a new case.
- AD-16.
- AD-19: the store.
- AD-22: no new key; the baseline is untouched.
- AD-24: the form declares no context.
- AD-39: `ServiceError`.
- AD-43: it does not refresh.
- AD-44: the exemption is removed, and `CLASSICPAGES` is added.
- AD-55 and AD-56 (ii).
- AD-58: the read-back.
- AD-59: the `Snippet` is unchanged; the port is `AdminPort`.

**Decisions:**

- **The Save sends `ClientSystems` whole.** AD-56 (ii) binds AD-53's screen-action route. A form Save (AD-55) merges changed fields over its own fresh read, as 9.9's reduced form and the web-application editor's list fields already do. A delta route would need new write tools and keys. The last-writer window is every form field's. The epic context's "Lists (AD-56)" line paraphrases (ii); the spine governs.
- **The capability rules** refuse what the vendor stores and never uses (measured). The editor's person and the agent then see one population. A service already holding such entries can still have them removed.
- **Canonicalization closes the kernel's `:` blindness** for any entry a write adds or changes. `Prohibited.AddressGrantsPrivilege` splits on `|` only, and the vendor's own editor writes `address:roles` for IPv4 (inference from `saveRoles` and `DrawConnectionTable`).
- **The form's `privileged` mark is the kernel's own service verdict**, so the line and the card agree.

**Named limits:**

- **The kernel judges a service address's role by name.** `AddressGrantsPrivilege` uses `IsPrivilegedRole`, which matches `%All` or `%Admin_*`. A role that grants administrative privilege under another name (`%Manager`) is minted without the destructive treatment, and the form's line follows the kernel. Epic 23's batch c moved the OAuth arm to `RoleGrantsAdministrativePrivilege` (DW-1663). The service arm needs the same change, plus `EntryParts` for held entries. That is an in-place edit of `Prohibited.cls`, which Epic 23 holds. Recommended ledger entry for the lead: `routed owner=range-end-cleanup` (or the next story to own `Prohibited.cls`).
- **The superserver is not a `Security.Service`.** No tool reaches it (AD-10), and this editor edits only service rows.
- **`HttpOnlyCookies`** is a field of `%Service_WebGateway` (`$$$ServiceCSP`) that the classic dialog draws and saves and the admin API's `Security.Service` PUT cannot carry; the editor draws no control for it (DW-1883, decision-pending).
- **`ValidateClientSystemsIP` under the form's two pairs is unmeasured.** It is `[Internal]`, and it reads no protected global (inference). The least-privileged Save leg settles it. A refusal there is a HALT to the lead, never a new pair taken by the implement stage (AD-8).

**Spine amendments for the lead (Rule 20):**

- (a) **AD-44**, replacing "Release 1 has exactly two: ... so SM-C1 counts two. Each is declared once, by `ServiceForm` and `LdapConfigForm`.":

  > Release 1 has exactly one: the reduced LDAP editor, removed by Story 16.14, counted against SM-C1, so SM-C1 counts one. It is declared once, by `LdapConfigForm`. The reduced service editor's exemption closed with Story 16.13's full editor [AMENDED 2026-09-30, Story 16.13 spec gate, Rule 20: was "exactly two ... SM-C1 counts two"].
- (b) **AD-44**, a paragraph:

  > **Story 16.13's `CLASSICPAGES`** [AMENDED 2026-09-30, Story 16.13 spec gate, Rule 20]: the service update declares the classic Edit Service dialog `%CSP.UI.Portal.Dialog.Service`, whose Save it performs beyond the Services list's own page.
- (c) **AD-4**, appended to its first paragraph:

  > `Security.Service` keeps a field its body omits and replaces `ClientSystems` whole when sent (its `RunPut` merges through its own `MergeJsonAndProperties` before `Security.Services.Modify`; measured on `ocupilot-ci` 2026-09-30: a `PUT` carrying only `ClientSystems`, then only `AutheEnabled`, kept the other fields), so its complete set carries every allowed connection as read [AMENDED 2026-09-30, Story 16.13 spec gate, Rule 20].
- (d) **Conventions › Screen archetype**, appended:

  > A write tool may declare that word for a field of its diff (`EMPTYKEYS`, Story 16.13, DW-1016): the instance sends an empty value there as `""` with the row's `emptyKey`, on a changed and an unchanged row alike, and the proposal card reads that word in place of "(none)" [AMENDED 2026-09-30, Story 16.13 spec gate, Rule 20].

**Integration:**

- **Consumes:** 9.9's `ServiceUpdate`, `ServiceRules`, `ServiceSave`, prohibited arm and routes; 6.2's `serviceAllowedUnrestricted`; the web-application editor's tab, checkbox and role-option patterns; `LockRemove`'s `CLASSICPAGES`; `ChangeBus`.
- **Consumed-by:** the Services list and the proposal card, both in this story. `EMPTYKEYS` has no later consumer planned.
- **Integration ACs:** the Integration AC and AC8.

**Ledger:** DW-1016 is addressed by AC8 and the `EMPTYKEYS` tasks.

## Verification

Slot A. Everything that writes a service or creates a principal runs on `ocupilot-ci`, one test run at a time.

- **Loading.** From the worktree root, `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `sh <scratchpad>/epic-16/compile.sh <changed paths>`. Read every line of the result.
- **Browser runs** first rebuild and redeploy (`cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`), then export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- **Armed classes** use the lead's shim, with `OCUPILOT_ALLOW_SERVICE_CONFIG` added to its four names: `EPIC16_ARM="OCUPILOT_ALLOW_PRINCIPALS OCUPILOT_ALLOW_PRODUCTION_INSTALL OCUPILOT_ALLOW_TASK_CONTROL OCUPILOT_ALLOW_NAMESPACE_CONFIG OCUPILOT_ALLOW_SERVICE_CONFIG" PATH=<scratchpad>/epic-16-recover/shim:$PATH`.

**Commands:**

- `(loop)` `cd ui && npm run test:tools`. Expected green, covering classic-links, floor, strings, citations, turn, proposal-view, proposal and ci.
- `(loop)` Component specs, expected green:

  ```sh
  cd ui && npx ng test \
    --include src/app/areas/permissions/service-editor.store.spec.ts \
    --include src/app/areas/permissions/service-editor.page.spec.ts \
    --include src/app/areas/permissions/service-roles-dialog.spec.ts \
    --include src/app/shell/reduced-form.page.spec.ts \
    --include src/app/core/reduced-form.store.spec.ts \
    --include src/app/shell/screen-outlet.spec.ts \
    --include src/app/shell/proposal-card.spec.ts
  ```

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call. Expected green. `<C>` is each of:
  - `ServiceUpdate` (and `ServiceUpdateRules` if split);
  - `ServiceEdit`, armed (and `ServiceEditRoles` if split);
  - `ClassicPageGate`, armed;
  - `SurfaceCoverage`, `ProposalWire`, `RefusalCopy`, `LdapEdit` (armed), `LdapUpdate` (armed), `WireSecurityRead` (armed), `ToolWrite`, `DraftRegistry`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/service-editor.browser-spec.mjs browser/reduced-editors.browser-spec.mjs browser/oauth.browser-spec.mjs`. Expected green within the structural baseline. Report the build's initial total.
- `(once, before dev_complete)` `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md. Expected green, and 993 lines.
- `(once, before dev_complete)` The full ObjectScript sweep on `ocupilot-ci`, one class at a time. Expected green apart from the spawn prompt's named residue. The full browser suite is CI's (Rule 29).

**Mutations (Rule 19, one per AC; each reverted, with the tree byte-identical afterward; ObjectScript recompiled with its descendants, and the client rebuilt and redeployed before a browser result counts):**

- AC1: the page draws the methods tab regardless of `authenticationMethods` → `service-editor.page.spec.ts` (ECP) red.
  - mutation: `tabs` pushes the methods tab whatever `hasMethodsTab()` answers → `service-editor.page.spec.ts` "AC1: a roles service draws no methods tab" red alone.
  - mutation (review pass): swap the message keys of bits 64 and 32 in `ServiceRules.AUTHEMETHODS` → `ServiceEdit.TestTheFormReadNamesEachServicesGroups` red on its label assertion, run 22399.
  - mutation (review pass): `hasConnectionsTab` answers `clientSystems` alone → `service-editor.store.spec.ts` "a service that checks no address" red alone.
- AC2: `ServiceSave.Update` drops `ClientSystems` from the changed set → `ServiceEdit`'s add leg red.
  - mutation: `ServiceSave.Update` removes `ClientSystems` from the changed set after its rules pass → `ServiceEdit.TestAnAddressIsAddedAndRemovedKeepingEveryOtherField` red (with the classic-spelling, role and least-privileged Save legs), run 22381.
- AC3: `ServiceRules.EntryParts` ignores `:` → `ServiceEdit`'s classic-spelling leg red.
  - mutation: `ServiceRules.EntryParts` always splits on `|` → `ServiceEdit.TestAClassicSpellingIsReadAndKeptVerbatim` red alone, run 22382.
  - mutation (review pass): `ServiceRules.RoleOptions` answers the negation of the kernel's verdict → `ServiceEdit.TestTheFormReadNamesEachServicesGroups` red on its privileged-mark assertion, run 22399.
  - mutation (review pass): `ServiceEditor.addAddress` refuses only `|` → `service-editor.store.spec.ts` "an address with roles in the instance's own address:role spelling" red alone.
- AC4: `setAuthe` replaces the mask with the offered bits alone → `service-editor.store.spec.ts` red.
  - mutation: `ServiceEditor.setAuthe` masks the held value to the offered bits → `service-editor.store.spec.ts` "AC4" red alone.
- AC5: the page drops `aria-disabled` on the serving service's Enabled → `service-editor.page.spec.ts` red.
  - mutation: drop `[attr.aria-disabled]` from Service enabled → `service-editor.page.spec.ts` "AC5" red alone.
- AC6: `ServiceUpdate.ArgumentProblem` skips `ServingServiceDisabled` → `ServiceUpdate`'s serving leg red (kernel leg still green).
  - mutation: `ServiceUpdate.ArgumentProblem` never asks `ServingServiceDisabled` → `ServiceUpdate.TestTheServingServiceIsNeverTurnedOffAndItsAddressesAreMarked` red alone; `TestTheKernelRefusesTheServingServiceDisableByName` green, run 22385.
- AC7: `Validate` skips the `ADDRESSUNSUPPORTED` rule → `ServiceUpdate`'s and `ServiceEdit`'s CallIn legs red.
  - mutation: `ServiceRules.AddedViolations` never adds `ADDRESSUNSUPPORTED` → `ServiceUpdate.TestTheAddressRulesRefuseAtTheMint` red alone (run 22383) and `ServiceEdit.TestTheAddressRulesRefuseTheSave` red alone (run 22384).
  - mutation (review pass): `ServiceRules.AddedViolations` judges held entries too → `ServiceEdit.TestTheAddressRulesRefuseTheSave` red on its held-entry leg, run 22399.
  - mutation (review pass): `ServiceRules.AddressViolations` reads roles after `|` only → `ServiceUpdate.TestTheRulesRefuseAtTheMint` red on its `address:role` leg, run 22398.
- AC8: the Mint helper skips `emptyKey` → `ServiceUpdate`'s DW-1016 leg red; `shown()` ignores the key → `proposal-card.spec.ts` red.
  - mutation: `Mint.ApplyEmptyKeys` sets no `emptyKey` → `ServiceUpdate.TestAnEmptyAddressListReadsUnrestricted` red alone, run 22388.
  - mutation: `ProposalCard.shown` ignores a non-empty key → `proposal-card.spec.ts` "renders an empty value as the word its row declares" red alone.
- AC9: `ServiceForm`'s exemption set back to exempt → `classic-links.test.mjs` and `floor.test.mjs` red.
  - mutation: `ServiceForm`'s exemption restored to exempt and the mirror regenerated → `classic-links.test.mjs` "the shipped descriptor roster passes" and `floor.test.mjs` "AC2, AD-44" red.
- AC10: `ServiceUpdate.CLASSICPAGES` emptied → `ClassicPageGate` red.
  - mutation: `ServiceUpdate.CLASSICPAGES` emptied → `ClassicPageGate.TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` and `TestAnAssignedPageGatesEveryDeclaringToolOnTheAgentsCaller` red, run 22386.
  - mutation (review pass): drop the `AUTH.NOPRIVILEGE` branch of the page's `reason` → `service-editor.page.spec.ts` "a Save refused for a privilege" red alone.
- AC11: `ServiceEdit` teardown skips `RestoreOf` → the class's own residue assertion red.
  - mutation: `ServiceEdit.OnAfterOneTest` skips `RestoreAll` → the residue assertion ("reads back as its snapshot after the test") red on every test, run 22389; `OnAfterAllTests` restored all three services.
- mutation (DW-1879): drop the `.ocu-side-bar-item-gated` rules, rebuild and redeploy → `permissions-effective.browser-spec.mjs` "AC7 (DW-1018), AC3" red (OAuth 2.0 and Allowed directories names on two lines).
- mutation (DW-1880): drop the `.ocu-details-volumes-table` rules, rebuild and redeploy → `databases.browser-spec.mjs` "DW-1880" red (header and cells `Times`).
- Integration: mutation (review pass): `ServiceEditor.save` skips `publishUpdated` → `service-editor.store.spec.ts` "AC2, Integration" and `service-editor.page.spec.ts` "Integration" red.
- mutation (code review, AC10): drop the tool's `PrivilegePairs` check from `ServiceSave.Gate` -> `ClassicPageGate.TestAnAssignedPageGatesTheServiceSave` red on its `%CSP.UI.Portal.Services` leg alone, run 22797.
- mutation (code review, AC8): `Mint.ApplyEmptyKeys` rewrites `before` only -> `ServiceUpdate.TestAnEmptyAddressListReadsUnrestricted` red on its removal leg alone, run 22793; `Disclosure.Rows` sets no `emptyKey` -> red on its disclosure leg alone, run 22794; the card binds `after` without its key -> `proposal-card.spec.ts` DW-1016 leg red alone.
- mutation (code review, AC7): `EntryShaped` without its `EntryParts` empty-address check (the implement-stage code) -> `ServiceUpdate.TestTheRulesRefuseAtTheMint` red on its `:%Operator` leg alone, run 22791.
- mutation (code review, Boundaries' tab names): the connections tab's count fixed at 0 -> `service-editor.page.spec.ts` "a refused Save opens the tab ..." red alone.
- mutation (code review, AC2): `addAddress` compares whole entries -> `service-editor.store.spec.ts` "an address already listed with roles ..." red alone.
- mutation (code review, Matrix "Least privilege"): `RoleOptions` answers `[]` without `%Admin_Manage:USE` -> `ServiceEdit.TestALeastPrivilegedPrincipalSaves` red alone, run 22798.
- Code review re-runs, final code: `ServiceUpdate` 13/13 (22801), `ServiceEdit` 10/10 (22799), `ClassicPageGate` 4/4 (22800); seven component specs 118/118; tools 1,747/1,747; bundle 2,349,256 bytes, redeployed; `service-editor` 5/5, `reduced-editors` 2/2, `permissions-effective` 5/5, `databases` 4/4.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented.** A tabbed service editor (`ServiceEditorPage`, `ServiceEditor` store, `ServiceRolesDialog`) replaces the reduced service form at the same route, drawing General, Authentication methods and Allowed incoming connections from the extended form read (`ServiceRules.FormMembers`: methods with the instance's labels, capabilities, parsed connections, role options marked by the kernel's verdict). One write path: `ServiceUpdate.MergeUpdate` canonicalizes added or changed entries through `ServiceRules.EntryParts`/`Canonical`; three added-entry rules in `Api/ServiceError.cls` (two pure line insertions in `Error.cls`); `CLASSICPAGES` `%CSP.UI.Portal.Dialog.Service`, which `ServiceSave.Gate` now evaluates. `ServiceForm`'s exemption is removed (SM-C1 counts one). `Write.EMPTYKEYS` (appended), applied by `Mint.ApplyEmptyKeys` and `Disclosure.Rows`, and the card's `shown(value, emptyKey)` read an empty address list "Unrestricted" (DW-1016). Fix pack: DW-1879 (gated side-bar reason inline) and DW-1880 (Volume files table styled).
- **Files.** Server: `Api/ServiceError.cls` (new), `Api/Error.cls`, `Area/Permissions/ServiceRules.cls`, `ServiceSave.cls`, `Screen/Tool/ServiceUpdate.cls`, `Write.cls`, `Kernel/Proposal/Mint.cls`, `Disclosure.cls`, `Screen/Descriptor/ServiceForm.cls`, `ServiceList.cls`. Tests: `ServiceUpdate`, `ServiceEdit`, `ServiceLdapProbe`, `ClassicPageGate`, `SurfaceCoverage`, `MappingDescriptor`. Client: the three new editor files and their specs, `screen-outlet.ts`, `reduced-form.page.ts`/`.store.ts` (+specs; spec-local service fixture through a `REDUCED_FORM_DECLARATIONS` token), `service-form.ts` deleted, `turn.ts`, `proposal-view.ts`, `proposal-card.ts` (+spec), `strings.ts`, `screens.generated.ts` (regenerated), `_components.scss`, `angular.json` (`maximumWarning` 2350kB, DW-1166), tool tests (`angular-json`, `classic-links`, `floor`, `proposal-view`, `turn`). Browser: `service-editor` (new), `reduced-editors`, `oauth`, `permissions-effective`, `databases`. Docs: EXPERIENCE.md rows 126, 503, 505, 507, 614, 617, 729 in place (993 lines); `scripts/ci-throwaway.sh` one comment line. Outside the Code Map: `Test/MappingDescriptor.cls` (classic-page roster row), `side-bar.spec.ts`, `permissions-effective.browser-spec.mjs`, `databases.browser-spec.mjs`, `_components.scss` (fix pack), EXPERIENCE.md :617 (review patch). Only `Api/Error.cls` overlaps Epic 23's footprint, as two add-only insertions.
- **Review.** 24 findings: 12 rows patched (10 entries: 4 medium, 6 low), each new pin with an observed mutation recorded under `## Verification`; 0 deferred; 12 rejected (8 false, 4 low) with reasons in the triage log, the held `address:role` kernel split under DW-1881. Follow-up review: `false` -- four medium entries were patched, but each closed with a demonstrated mutation (runs 22398, 22399 and the component specs), and no unverified risk can be named.
- **Verification** (slot A, `ocupilot-ci`, one run at a time, full arming list): `ServiceUpdate` 13/13 (run 22396), `ServiceEdit` 10/10 (22397), `ClassicPageGate` 4/4 (22394); full sweep 384 classes, 3,174 tests, 6 failed, all named residue (`PathPortInstance` 1, `Retention` 1, `TaskHistory` 3, `WireSecurityRead` task history 1), 0 probe leftovers, 0 overlaps. `npm test` 1,747 tools and 2,013 component tests green; `check-objectscript` 0 problems; `lint-docs` clean; EXPERIENCE.md 993 lines. Browser, bundle rebuilt and redeployed: `service-editor` 5/5, `reduced-editors` 2/2, `oauth` 6/6, `permissions-effective` 5/5, `databases` 4/4; initial total 2,349,254 bytes. `%Service_CallIn`, `%Service_CacheDirect` and `%Service_ECP` read back disabled with no address; `%Service_WebGateway` was never written.
- **Residual risks.** Bundle headroom is 746 bytes under 2350kB, so the next story re-bases (DW-1166). `TestTheVendorsAddressCheckAnswersAsMeasured` expects `no-such-host.invalid` to answer 4, which depends on name resolution failing in CI (inference). The handoff subagent ran `git rm --cached` on `service-form.ts`, an index operation outside its prohibitions' letter; it staged only that intended deletion, and no commit or push was made.
