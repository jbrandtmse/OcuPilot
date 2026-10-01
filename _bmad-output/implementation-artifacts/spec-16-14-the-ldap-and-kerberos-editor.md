---
title: 'Story 16.14: The LDAP and Kerberos editor'
type: 'feature'
created: '2026-09-30'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-16-13-the-service-editor.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-9-a-cut-editor-ships-reduced-never-half-working.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 9.9's reduced form is the only way to change an LDAP configuration, and it covers only enabled state, host names and user lookup. Creating and deleting a configuration, the Kerberos choice, TLS, groups, attributes, the search password and a test of authentication are still left to the classic page. The form's classic-link card is SM-C1's last exemption. Separately, the LDAP / Kerberos list shows every configuration as disabled (DW-1639).

**Approach:**

- Replace the reduced form with a tabbed editor over every field of `%CSP.UI.Portal.LDAP`. It also creates a configuration (the list's command-bar Create), and the list gains Delete (FR-45).
- Keep one write path per operation (AD-55). A Save and the agent both reach `security.ldap.update` and the new `security.ldap.create`, `security.ldap.password` (the vendor's `CHANGEPWD`) and `security.ldap.delete`.
- Add Test authentication: a dialog on the editor that runs the vendor's `TEST` through `AdminPort` and shows the instance's own output.
- Remove `LdapConfigForm`'s exemption, so SM-C1 counts zero.
- Read the list's Enabled column from `LDAPFlags` bit 64.

## Boundaries & Constraints

**Always:**

- **Screens.** `LdapConfigForm` stays a built `form-page` at `security/ldap/edit[/<name>]`, with the list's pairs and its three prompts (11.3).
  - The id route edits a configuration; the bare route creates one, following the SSL editor.
  - It declares `classicLinkExemption` `{"exempt": false, "reason": "", "label": "", "href": ""}` and draws no classic card.
  - `LdapConfigList` gains:
    - `primaryAction` `create`;
    - `rowActions` `[{"id": "delete", "selfProtection": ""}]`;
    - `secretArguments` `["LDAPSearchPassword"]`;
    - `emptyNextKey` `""` and `emptyAgentKey` `ldapListEmptyAgent`.
- **Tabs** (EXPERIENCE.md :140, :625). The classic page has no tabs, so the editor keeps the classic page's order and splits it at the classic page's own captions:
  - **General** (`processDetailsGroupGeneral`):
    - Name (editable when creating, read-only text otherwise), Copy settings from (creating only) and Description.
    - Kerberos configuration and LDAP configuration, drawn only when the instance's Kerberos authentication is on.
    - LDAP enabled, Active Directory server, Host names, Search username and Search password.
    - Base DN, Base DN for nested groups, Unique search attribute, Server timeout and Client timeout.
    - Use TLS/SSL, CA certificate file and Allow ISC_LDAP_CONFIGURATION.
  - **Groups:**
    - Use LDAP groups, Search nested groups and Organization ID prefix.
    - An Advanced settings disclosure holding the Group, Instance, Role, Escalation role, Namespace and Routine ID prefixes and the Delimiter.
    - Allow universal groups, Authorization group ID, Authorization instance ID and the three examples.
  - **Attributes:** the nine user-attribute fields, then the list of attributes to retrieve, with add and remove like Host names.
  - One Save applies every tab. A refused field opens its tab, and each tab's accessible name counts its errors (`core/form-tabs.ts`).
- **Flag bits** (`irissys/%sySecurityMacros.inc:43-50`): 1 Active Directory, 2 TLS, 4 Allow ISC_LDAP_CONFIGURATION, 8 use groups, 16 nested groups, 32 universal groups, 64 enabled, 128 Kerberos only.
  - Each checkbox sets or clears its own bit over the value the form opened. A bit the form does not draw keeps its value, and the Save sends `LDAPFlags` whole when it changed.
  - **The classic page's couplings:**
    - Unticking Use LDAP groups clears 16 and 32 and disables the Groups fields. It enables the four role, namespace and routine attribute fields, which stay disabled while it is ticked.
    - Nested groups is enabled only while Active Directory and Use LDAP groups are both ticked; unticking either clears 16.
  - **Kerberos:**
    - Kerberos configuration is drawn checked and disabled.
    - Unticking LDAP configuration sets 128 and clears 64. The editor then draws only Name, Description and the two checkboxes.
    - Ticking LDAP configuration clears 128.
    - The instance clears 64 whenever 128 is set (192 is stored as 128, measured), so 64 sent together with 128 is refused (`LDAP.FLAGS.KERBEROS`).
    - On a Kerberos-only configuration, the rules' compose, for both callers, sends an empty `LDAPHostNames` as `["UNKNOWNHOST"]` and an empty `LDAPSearchUsername` as `"UNKNOWNUSER"`. These are the classic page's own values (`LDAP.cls:507-512`).
- **Fields that are not inputs.**
  - `LDAPCACertFile` is shown as read-only text and never set (AD-21); there is no Browse button.
  - `LDAPDomainName` is hidden and unused on the classic page, and is not drawn.
- **Search password** (AD-35, AD-56 (i)):
  - It is a radio group with three options: Leave as is (the default), Enter a new password, and Clear the password.
  - Enter a new password draws Password and Confirm password, and the client refuses a mismatch.
  - No password is ever read.
  - The Save body carries `LDAPSearchPassword` only for Enter (the value) or Clear (`""`).
  - The store clears the value on Save, Cancel, leaving the page, and sign-out (`app.ts`'s reset, as for `sslForm`).
- **Form read.**
  - `GET /ldap/form?name=` keeps `{ldap}` and adds `kerberos`: whether the instance's `Security.System` `AutheEnabled` has bit 128.
  - `GET /ldap/form?new=1` answers `{ldap, kerberos}` with a new configuration's values (`LdapRules.Defaults`).
- **Name** (creating only):
  - `GET /ldap/name?name=` answers `{name, canonical, baseDN, taken}` from `Security.LDAPConfigs.FormatName` in `%SYS`.
  - On blur the editor replaces Name with `canonical`, and fills Base DN and Base DN for nested groups with `baseDN` when each is empty.
- **Copy settings from** (creating only):
  - It lists the names the LDAP list's declared read answers (AD-5).
  - Choosing one reads that configuration's form and copies every field except Name, Description and the two Base DNs.
  - The password option becomes Enter a new password, because no password is ever read.
- **Examples:**
  - `GET /ldap/examples` takes the eleven group inputs as query parameters and answers `{universal, group, instance}` from `Security.LDAPConfigs.FormatExample` modes 1 to 3, in `%SYS`.
  - The Groups tab re-reads them when a group input changes and draws them as read-only text.
- **Write tools.** All four are on `LdapConfigList` and require `%Admin_Secure:USE`, as today. Update, create and password declare `CLASSICPAGES` `%CSP.UI.Portal.LDAP` through `Screen.Gate.WithClassicPages`. The delete runs on the list's own page, so it declares none.
  - **`security.ldap.update`** (existing): its fields are unchanged; it gains `CLASSICPAGES` and the new rules.
  - **`security.ldap.create`** (new, AD-54):
    - `CREATES` 1 and `WRITETYPE` `PUT`: the vendor's PUT is an upsert, answering 201 on a create (measured).
    - Its body is the complete set: the caller's fields over `LdapRules.Defaults`, a new `Security.LDAPConfigs` object's values. The vendor refuses a partial body on an absent name (#1482, measured).
    - Its fresh read must find the name absent.
  - **`security.ldap.password`** (new, AD-51, AD-56 (i)):
    - `WRITETYPE` `CHANGEPWD`, `SENDSBODY` 0, `SECRETBODY` `LDAPSearchPassword`, `FINGERPRINTSUBJECT` `LDAPSearchUsername`.
    - The agent's card asks for the value at confirm and refuses an empty one (`proposal-card.ts` `secretsFilled`).
  - **`security.ldap.delete`** (new): an action-style `DELETE`, with a destructive confirm that requires typing the name, as `security.ssl.delete`. The vendor answers 404 for an absent name (measured).
  - **Clearing the password:**
    - `Write.cls` gains `Parameter CLEARABLESECRETS = ""`, appended to the class.
    - `Operation.SecretBody` keeps an explicitly supplied `""` for a name listed there; today it drops it.
    - `security.ldap.password` lists `LDAPSearchPassword`, so `""` clears it, because the vendor's `CHANGEPWD` clears on `""` (measured).
  - Each new key joins `Kernel/Governance/Baseline.cls`, enabled.
- **The Save** (`LdapSave`, AD-55, in `SslSave`'s order) answers `PUT /ldap/:id`, and `POST /ldap` for a create (201). In order:
  1. The Gate also evaluates the tool's `PrivilegePairs`, as 16.13's `ServiceSave.Gate` does.
  2. It takes `LDAPSearchPassword` out of the body.
  3. It sends the merge (update) only when a field changed, or the complete set on a create.
  4. It then sends the password through `security.ldap.password`'s operation, following `OAuthClientSave`'s `TakeSecrets`/`StoreSecrets` sequence and its answer when that second write fails.
  5. The read-back reports the password `written` and never reads it (AD-58).
- **Rules** (`LdapRules`, both callers). The existing four stay. New:
  - `LDAP.FLAGS.KERBEROS`: 64 sent together with 128.
  - `LDAP.NAME.FORM`: a name whose `FormatName` differs from it other than by case. It is refused on every LDAP tool and route. The instance stores only the canonical form, and `Exists` also finds a configuration by its short name (measured), so this keeps every target key equal to the stored name (AD-13).
  - `LDAP.NAME.TAKEN`: a create whose name already exists.
  - `LDAP.HOST.REQUIRED`: no host on a configuration that is not Kerberos-only (the vendor's #1482).
  - The codes and their sentences live in a new `Api/LdapError.cls`. `Error.cls`'s `ReasonForLdap` and `LdapViolationCodes` delegate to it, and `Error.cls` gains no parameter (it holds 989 of the compiler's 1,000).
- **Test authentication** (the recommended answer to the blocking question in Design Notes):
  - **Route.** `POST /ldap/:id/test` takes `{Username, Password}`. Its gate is the form's pairs plus `WithClassicPages(..., "%CSP.UI.Portal.LDAPTest")`.
  - **Refusals.** It answers 422 for an empty user name or password (`LDAP.TEST.REQUIRED`) and for a user name containing `@` (`LDAP.TEST.USERNAME`). It answers 404 `LDAP.ABSENT` for an absent configuration.
  - **What it sends.** The vendor `TEST` gets `Username` `<user>@<name>`, because the vendor's routine picks the configuration by the domain part (measured).
  - **The port runs `Security.LDAP/TEST` in process and never queues it:**
    - It joins `CONNECTIONTESTTYPES`, and `Sequence` skips the `ShouldRunAsync()` hand-off for a connection-test pair.
    - Its outcome is the captured console lines: `{lines}`, with no `passed`, because the vendor answers `{}` and OK whatever happened (measured).
    - Nothing logs the body or the lines (AD-39).
  - **The dialog:**
    - It opens from the editor of a saved configuration. While the form holds unsaved changes, the button is `aria-disabled`, with `ldapTestSaveFirst` as its reason.
    - It shows the lines under `ldapTestOutput`.
    - A request that the gateway ends shows `ldapTestNoAnswer`.
    - It clears the password on close.
- **DW-1639.**
  - `LdapConfigList`'s read adds `LDAPFlags` to `read.fields`, plus this `rowGet`: `{"key": "Name", "param": "name", "fields": ["LDAPFlags"], "derived": [{"field": "Enabled", "rule": "bit64", "from": "LDAPFlags"}]}`.
  - The rule `bit64` joins `Screen.Registry.ROWGETRULES`, `Screen.Read.Derive`, and `screen-mirror.mjs` `ROW_GET_RULES` with its type.
- **Probes and tests:**
  - They create `ocup99*.invalid` configurations through `Test/ServiceLdapProbe.CreateLdap`, and delete each one after checking its exact stored name.
  - They delete any vendor task row they create, as an object.
  - A test's probe password is found nowhere afterwards.
- **Shared files:**
  - Edits are add-only, apart from the declared edits in Tasks.
  - EXPERIENCE.md stays at 993 lines, and `npm run test:tools` stays green.
  - Epic 23 holds `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs`, so their edits are add-only. Re-check Epic 23's footprint before each edit (spawn prompt).

**Never:**

- Queue `Security.LDAP/TEST` through the vendor's async task, or write its body anywhere.
- Admit `Security.LDAP/POST`. Set `LDAPCACertFile` or any other path.
- Read, return, diff or log any search or test password, or place one in context.
- Add a parameter to `Api/Error.cls`.
- Hand-edit `screens.generated.ts`, `FieldLists.cls` or `ToolFields.cls`.
- Parse the test's output lines into a pass or fail verdict.
- Touch `ocupilot`, or any LDAP configuration a test did not create.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Open | A probe configuration on `ocupilot-ci`, where Kerberos is on | General, Groups and Attributes, in the classic order. Kerberos configuration (checked, disabled) and LDAP configuration are drawn. The CA file is text. There is no classic card. | none |
| Group coupling | Untick Use LDAP groups | The Groups fields are disabled and bits 16 and 32 are cleared. The four attribute fields are enabled. | none |
| Kerberos only | Untick LDAP configuration, then Save | `LDAPFlags` gains 128 and loses 64. Only Name, Description and the two checkboxes are drawn. An empty host and user are stored as `UNKNOWNHOST` and `UNKNOWNUSER`. | none |
| 64 with 128 | Agent sends `LDAPFlags` 192 | Nothing is sent. | 400 / 422 `LDAP.FLAGS.KERBEROS` |
| Password: enter | Enter a new password, matching, then Save | 200. The read-back's `written` includes `LDAPSearchPassword`, and the instance holds a password. | none |
| Password: clear | Clear the password, then Save | The instance holds no password. | none |
| Password: leave | The default option | No `CHANGEPWD` is sent. | none |
| Password: mismatch | Two different values | Nothing is sent. | Client: `ldapPasswordMismatch` |
| Agent password | `security.ldap.password` on a probe configuration | The card asks for the value, and Confirm sets it. The ledger, payload, diff and logs hold no value. | none |
| Create | List Create, name `ocup99new.invalid`, a host, then Save | 201 "Saved". The list re-reads and shows the new configuration. | none |
| Short name | Create `OcuP99New` | On blur Name becomes `ocup99new.com`, and the Base DNs fill. An agent create named `OcuP99New` is refused. | `LDAP.NAME.FORM` |
| Name taken | Create an existing name | Nothing is sent. | `LDAP.NAME.TAKEN` |
| Created between mint and confirm | An agent create, after which someone creates that name | The confirm is refused, and nothing is overwritten. | fingerprint |
| Copy from | Create, then Copy settings from the probe | Every field except Name, Description and the Base DNs is copied. The password option becomes Enter a new password. | none |
| Examples | Change Group ID prefix | The three examples are re-read from the instance. | none |
| Delete | Row Delete on a probe, with the name typed | The configuration is gone, and the list re-reads. | Absent: 404 |
| Test | Probe with host `127.0.0.1:1`, user `u` and a password | 200 `{lines}` with the instance's own text (for example "Can't contact LDAP server" and "Test completed"). No vendor task row is created, and the password is in no global, log or journal. | none |
| Test user with a domain | `u@x.com` | Nothing is sent. | 422 `LDAP.TEST.USERNAME` |
| Test while unsaved | An unsaved change | The button is `aria-disabled`, with `ldapTestSaveFirst`. | none |
| DW-1639 | Probes with `LDAPFlags` 72 and 8 | The list shows Enabled as Yes, then No, and the read tool answers the same. | none |
| Classic page resource | A custom resource on `%CSP.UI.Portal.LDAP` (and on `LDAPTest`) | A caller lacking it is refused by name at the mint, Confirm, Save (and the test route), before any port call. | 403 |
| Absent | Open, PUT or test an unknown name | "This LDAP configuration no longer exists." | 404 `LDAP.ABSENT` |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at `ad1c21ff`.

**Measured on `ocupilot-ci`, 2026-09-30.** Transcripts are in the session scratchpad, `epic-16/16-14/`. Every probe deleted what it created.

- **`%Api.Admin.Endpoints.Security.LDAP`** (source in `vendor-ldap-src.txt`):
  - **Types.** LIST 0, GET 1, PUT 2 and DELETE 3. CHANGEPWD 10 is `POST …/configuration/search-password?name=` with body `{LDAPSearchPassword}`; `""` clears the password, and an absent name answers 404. TEST 11 is `POST /security/ldap/test` with body `{Username, Password}`; both are required and extra keys are refused. There is no POST type.
  - **`ResourcesOR`.** LIST and GET accept `%Admin_Secure` or `%Admin_Operate`; every other type needs `%Admin_Secure`.
  - **`ShouldRunAsync`** is true for TEST only.
  - **DW-1639.** `RunList` applies `TreatColumnAsBoolean` to a Yes/No column, so every row's `Enabled` reads false.
  - **GET** answers the 30 template keys, with no `Name` and no password.
  - **PUT:**
    - It keeps any key the body omits.
    - On an absent name it is an upsert: a complete body answers 201, and a partial one answers 500 #1482.
    - It refuses `LDAPSearchPassword` with 400 `PORT.FIELD.UNEXPECTED`.
    - It accepts `LDAPFlags` 256 and -1 with no check, and stores 192 as 128.
- **`RunTest`:**
  - It locks `^LDAPTEST`, JOBs `TESTBACKGROUND1^%SYS.LDAP(user,pw,idx)`, hangs 5 s, locks again with no timeout, and writes the `^IRIS.Temp(idx,*)` lines.
  - It answers `{}` with an OK status whether the test passes or fails, and names no configuration.
  - Run in process against `127.0.0.1:1`, it took 5,004 ms. Its lines included "SearchExts error: -1 - Can't contact LDAP server" and "Test completed".
  - It records no audit event, and `^IRIS.Temp` never holds the password.
- **Queued (the reason for the blocking question):**
  - The vendor saves the body, in plain text, in `%Api.Admin.Util.AsyncTask`'s `RequestBody` stream. That stream is in `IRISLOCALDATA`, whose public `READ` lets any user read it (a probe user read another user's queued password).
  - The body is also journaled twice per request, by the save and by the delete, inside a transaction, even though the database is not journaled.
  - OcuPilot's `ForgetTask` deletes the row only for a caller holding `%DB_IRISLOCALDATA:WRITE`, which the LDAP pairs do not include.
- **`Security.LDAPConfigs`** (`irissys/Security/LDAPConfigs.cls`):
  - `AutheKB` is 128.
  - `Required` covers the Base DNs, both timeouts, `LDAPFlags`, the seven prefixes and the delimiter (`- _ ^ . ~`), the search username and the unique attribute. A host is required too (#1482).
  - `FormatName` lower-cases a name, adds `.com` to a bare name, and strips `@`, `\` and `,`. `FormatExample(mode, …)` answers one text block per mode. Both exist only in `%SYS` and are pure (inference).
  - Create, modify and delete each record `%System/%Security/LDAPConfigChange`, with the password shown as `*****`.
  - On `ocupilot-ci`, `AutheEnabled` 33556471 has Kerberos (128) on and LDAP (2048) off. Auditing is on.

**Server:**

- **Descriptors:**
  - `S/Screen/Descriptor/LdapConfigForm.cls`: the doc is at `:1-15`, the exemption at `:49`.
  - `S/Screen/Descriptor/LdapConfigList.cls`: the doc is at `:1-26`, the actions and secrets at `:47-49`, the read at `:59-65` and the table at `:66-74`.
  - The precedents are `SslConfigList.cls:54-57,81-82` (create, delete and secret) and `UserList.cls:88-96` (`rowGet` with `derived`).
- **Tools:**
  - `S/Screen/Tool/LdapUpdate.cls`: `PERMITTEDFIELDS` `:32`, `SecretArguments` `:57` (keep `""`), the `LDAPFlags` description at `:70` (name bit 4), `ArgumentProblem` `:88`, `PrivilegePairs` `:106`.
  - Precedents:
    - `SslCreate.cls`: `CREATES`, `REQUIREDFIELDS`, `ArgumentProblem` in create mode, and `PrivilegePairs`.
    - `TaskCreate.ComposeCreate` `:176` → `Area/Task/TaskRules.Compose` `:614` and `Defaults`: the complete-body create.
    - `UserPassword.cls:19-80`: the `CHANGEPWD` secret body.
    - `SslDelete.cls`: `DESTRUCTIVE`, `SCREENACTIONS`, `READANSWERS`, `FINGERPRINTSUBJECT` and `StateDiff`.
    - `LockRemove.cls:71,130-138`: `CLASSICPAGES` and `PrivilegePairs`.
- **Saves:**
  - `S/Area/Security/LdapSave.cls`: `Update` `:86-134`, `Gate` `:207`.
  - Precedents:
    - `SslSave.cls`: `HandleCreate` `:57`, `Create` `:121`, and the password taken out and re-added at `:205-224`.
    - `OAuthClientSave`: `TakeSecrets` `:458`, `StoreSecrets` `:303`, and `ReadBack.ForSave(..., pStoredApart)` `:106/:158`.
    - `Area/Permissions/ServiceSave.Gate`, which adds the tool's pairs.
- **`S/Area/Security/LdapRules.cls`:** `Validate` `:45`, `Changed` `:152`, `HandleForm` `:190`, `Present` `:228`, `Gate` `:269`.
  - Precedents: `SslRules.HandleName` `:335`, `HandleTest` `:373` and `Test` `:410`. `Area/Permissions/ServiceRules.cls` reads `Security.System` `AutheEnabled`.
- **`S/Api/Router.cls`:** the LDAP routes are at `:183-184` and their targets at `:1500-1512`. The SSL create, name and test routes are at `:172-176` and `:1437`.
- **`S/Api/Error.cls`:** the LDAP codes are at `:4073-4101`, the `ReasonForViolation` arm at `:1411`, `ReasonForLdap` at `:4127` and `LdapViolationCodes` at `:4135`.
  - The model is `S/Api/ServiceError.cls` (`:33`, `:40`), with its delegation at `Error.cls:4107-4122`.
- **`S/Port/AdminPort.cls`:**
  - Parameters: `MUTATINGTYPES` `:402`, `BODYLESSTYPES` `:418`, `CONNECTIONTESTTYPES` `:440-450`, `ASYNCTIMEOUT` `:735`.
  - The test branch `:1014` runs before the async branch `:1018`.
  - Methods: `IsConnectionTest` `:2237`, `TestOutcome` `:2249`, `EndpointType` `:2345`, `Sequence` `:2452`. In `Sequence`, the `ShouldRunAsync` hand-off is at `:2497-2519`, and the output capture at `:2523-2533` drops `tLines`.
  - `S/Port/AdminRoutes.cls`: CHANGEPWD is at `:159`, PUT at `:161` and TEST at `:162`.
- **`S/Kernel/Proposal/Operation.cls:139-162`:** `SecretBody` drops `""` at `:155`.
- **`S/Screen/Tool/Write.cls`:** `CLASSICPAGES` is at `:124`, `SecretArguments` and `ChannelSecretNames` at `:558-625`. Append to the class's end.
- **`S/Kernel/Proposal/Prohibited.cls`:** `COVEREDTYPES` `:250` already holds `ldap-configuration`. `PermittedChangeFields` is at `:772`. `PermittedCreateFields` (`:889-910`) has no LDAP arm, so a create would be refused `UNCOVERED` (`Created` `:1235`). `LdapFields` is at `:4162`.
- **`S/Kernel/Governance/Baseline.cls:74`.**
- **`bit64`:**
  - `S/Screen/Registry.cls`: `ROWGETRULES` `:2201`, `RowGetProblem` `:2224`, and the write-capable table check at `:2417-2420`.
  - `S/Screen/Read.cls`: `DetailRow` `:1105-1180`, `Derive` `:1189`.
  - `S/Test/RowGetCorpus.cls`.
- **Tests:**
  - `S/Test/LdapUpdate.cls`, armed `OCUPILOT_ALLOW_SERVICE_CONFIG`. The settable-field check is at `:71`, the absent target is not recreated at `:146`, and the exemption is pinned at `:194-219`.
  - `S/Test/LdapEdit.cls`, armed `OCUPILOT_ALLOW_SERVICE_CONFIG` and `OCUPILOT_ALLOW_PRINCIPALS`. The least-privileged principal is at `:56`, the form read has no password at `:86`, 30 keys at `:130`, and an absent name is 404 with nothing created at `:173-174`.
  - `S/Test/LdapSaveHeldFixture.cls`; `S/Test/ServiceLdapProbe.cls` (`CreateLdap` `:126`, `RemoveAll` `:174`); `S/Test/SecurityLists.cls:58,207-213`; `S/Test/Descriptor.cls:85`; `S/Test/SslTest.cls:79-107` (the test text is never logged).
  - Rosters:
    - `S/Test/SurfaceCoverage.cls:139`: the form row's method.
    - `S/Test/ReadTool.cls:93-94`: 188 tools.
    - `S/Test/ToolRoundTrip.cls` `REFUSEEMPTY` `:50`.
    - `S/Test/EndpointCoverage.cls:222-223,466`.
    - `S/Test/ToolWrite.cls:1306,1323`.
    - `S/Test/PortFixture.cls:21`, which mirrors `MUTATINGTYPES`.
    - `S/Test/ClassicPageGate.cls`: `OWNPAIRS`.
  - Arming: `scripts/ci-throwaway.sh:229` (`PRINCIPALS`: `LdapEdit`) and `:359` (`SERVICE_CONFIG`: `ServiceEdit`, `LdapEdit`, `LdapUpdate`, `ServiceLdapProbe`), mirrored in `ui/tools/ci.test.mjs`.
- **Generators:** `cd ui && node tools/field-lists.mjs` regenerates `ToolFields.cls`, and `node tools/screen-mirror.mjs` regenerates the mirror. The LDAP template does not change, so `FieldLists.cls` is not regenerated.

**Client:**

- **Removed:**
  - `U/areas/security/ldap-form.ts`.
  - `U/shell/reduced-form.page.ts` and `U/core/reduced-form.store.ts`, with their specs and the `REDUCED_FORM_DECLARATIONS` token. The form's registrations are at `U/shell/screen-outlet.ts:71,162,192-195` and `screen-outlet.spec.ts:24,432-441`.
  - `ui/browser/reduced-editors.browser-spec.mjs`, which is LDAP-only.
  - `U/shell/classic-link-card.ts` is kept, with its spec, its browser spec, `_components.scss:2087-2140` and the strings on EXPERIENCE.md rows 305 and 306. It renders AD-44's exemption, which a later detail view may declare.
- **Patterns:**
  - Create at the bare route: `U/areas/security/ssl-form.store.ts:446-456,472,524-538,546-590` and `ssl-form.page.ts:161-182,667,1031-1034`.
  - Tabs: `U/core/form-tabs.ts:29,45,58` and `U/shell/form-tabs.ts:86`, with the field map at `ssl-form.store.ts:54-90`.
  - From `U/areas/permissions/service-editor.store.ts`: a checkbox over a mask `:236,398`, list add and remove `:412,429`, and the publish `:505-514`.
  - `U/core/form-dirty.ts:30` and `U/core/read-back.ts:56,109`.
  - A disclosure: `U/areas/agent/definition-form.page.ts:346-357,541,1064`.
  - A radio group: `U/areas/os-management/device-form.page.ts:292-305`.
  - The masked secret: `formSecretStored` (`strings.ts:273`), `ssl-form.page.ts:348-375`, and its store `:493,580,688-705`.
  - The dialog: `U/shell/dialog.ts:50-84` and `U/areas/permissions/service-roles-dialog.ts:28-62`.
  - SSL's test: `ssl-form.page.ts:499-557` and store `test()` `:596-621`.
- **List actions:**
  - `U/areas/security/ssl-actions.ts`, injected at `U/app.ts:25,330`. The sign-out reset is at `U/app.ts:645` and `app.spec.ts:1266-1272`.
  - `U/core/navigation.ts:212,222-226` and `U/core/table-model.ts:244`.
  - In `ui/tools/screen-mirror.mjs`, a write-capable table needs `emptyAgentKey` (`:2709-2721`), and `ROW_GET_RULES` is at `:2531` with its type at `:3145`.
- **Exemption rosters:** `ui/tools/classic-links.test.mjs:430-458` ("1 exemption(s)", "1 descriptor(s)"), `ui/tools/floor.test.mjs:57-60,86-107`, `ui/browser/oauth.browser-spec.mjs:369-374`, and `ui/tools/navigation.test.mjs:220,363` (messages naming the reduced form).
- **Strings** (`U/core/strings.ts`):
  - The LDAP keys are at `:800-802`, `:2239-2263`, `:2277-2281` and `:2390-2394`, and `} as const` is at `:4031`.
  - `formTypedNameMismatch` and `agentDefinitionAdvanced` ("Advanced") already exist; a value has one key.
  - In `ui/tools/strings.test.mjs`, the bound is `:572` (1900, about 1,831 keys), the exact count `:606-610` and the citations `:796-838`.
- **Bundle:** `ui/angular.json:51-57` sets 2350kB and 4000kB, pinned at `ui/tools/angular-json.test.mjs:392-393`, and `ui/tools/build-output.test.mjs:168-201` enforces it. The current total is 2,349,256 bytes, which leaves 744 bytes of headroom.
- **Browser:**
  - `ui/browser/service-editor.browser-spec.mjs`: guards `:193-197`, structural walk `:165-191`.
  - `structural-walk.mjs`: `detectScreen` `:531`, `assertThrowaway` `:744`.
  - `turnprobe-spec.mjs` `runIris` `:52`.
- **EXPERIENCE.md** rows `:140`, `:148`, `:173` (the dialog list names no LDAP test), `:363`, `:504`, `:505`, `:508` and `:625`. Rows `:633`, `:691` and `:730` mention the reduced form; check each one.

## Tasks & Acceptance

**Execution:**

- **Task 0 (orchestrator condition, do first, before building on the synchronous test):** on `ocupilot-ci`, run `Security.LDAP` `TEST` on `AdminPort`'s synchronous path with a known probe password (a probe-named configuration pointing at an unreachable host is enough) and measure, the way the planner measured the queued path, that the password is left in **no** `%SYS.Task` or async task row (the vendor's `%Api.Admin` async task table included), **no** journal record you can find (search the current journal file for the probe password after the call), **no** `messages.log` line and no audit row, and **no** OcuPilot ledger or transcript row. Record the measurement under `## Design Notes`. **If the synchronous path also persists the password anywhere, HALT `blocked` with blocking condition `intent gap -- synchronous LDAP test persists the password: <where>`** -- option (c), leaving the test for a later story, becomes the fallback and is the orchestrator's call.

Server:

- `S/Api/LdapError.cls` (new), following the `ServiceError` pattern. Codes and their sentences:
  - `LDAP.FLAGS.KERBEROS`: "A Kerberos-only configuration cannot also be LDAP enabled."
  - `LDAP.NAME.FORM`: "Use the full name the instance stores, such as example.com."
  - `LDAP.NAME.TAKEN`: "An LDAP configuration with this name already exists."
  - `LDAP.HOST.REQUIRED`: "Enter at least one host name."
  - `LDAP.TEST.REQUIRED`: "Enter a user name and a password to test with."
  - `LDAP.TEST.USERNAME`: "Enter the user name without a domain; the test uses this configuration."
  - It provides `ViolationCodes()` and `ReasonFor()`.
- `S/Api/Error.cls` -- two declared edits. `ReasonForLdap` falls through to `LdapError.ReasonFor`, and `LdapViolationCodes` appends `LdapError.ViolationCodes()`.
- `S/Area/Security/LdapRules.cls`:
  - Add the new rules, plus `Defaults`, `Compose` (the Kerberos-only fill) and `Canonical`, each `%SYS` call with its restore first in `Catch` (AD-16).
  - Add the `HandleForm` `kerberos` and `new=1` branch, `HandleName`, `HandleExamples` and `HandleTest` (Boundaries).
- `S/Area/Security/LdapSave.cls`:
  - Add `CREATETOOL`, `PASSWORDTOOL`, `HandleCreate` (201) and the password sequence.
  - `Gate` adds the tool's pairs.
- `S/Screen/Tool/LdapUpdate.cls` -- add `CLASSICPAGES`, `PrivilegePairs` through `WithClassicPages`, the `LDAP.NAME.FORM` check in `ArgumentProblem`, and bit 4 in the `LDAPFlags` description.
- New tools in `S/Screen/Tool/`, as described in Boundaries:
  - `LdapCreate.cls`, following the `SslCreate` pattern, with `ComposeCreate` → `LdapRules.Compose`.
  - `LdapPassword.cls`, following `UserPassword`, with no `AfterWrite`.
  - `LdapDelete.cls`, following `SslDelete`.
- `S/Screen/Tool/Classification.cls` -- add an entry for each new tool, following `SslCreate`'s, `UserPassword`'s and `SslDelete`'s. Then regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.
- `S/Screen/Tool/Write.cls` -- append `Parameter CLEARABLESECRETS = "";` with its doc. `S/Kernel/Proposal/Operation.cls` gets a declared edit at `:153-155`: keep `""` for a listed name.
- `S/Port/AdminPort.cls`:
  - Add `Security.LDAP/CHANGEPWD` and `Security.LDAP/DELETE` to `MUTATINGTYPES`, `Security.LDAP/DELETE` to `BODYLESSTYPES`, and `Security.LDAP/TEST` to `CONNECTIONTESTTYPES`, with docs.
  - Declared edits:
    - `Sequence` never hands a connection-test pair to the queue and passes its captured lines out.
    - `TestOutcome` answers `{lines}` from those lines, with no `passed`, for a pair whose vendor answer carries no verdict (a new `CONSOLETESTS` parameter naming `Security.LDAP/TEST`).
  - The AD-59 `Snippet` covers the new types.
- `S/Kernel/Proposal/Prohibited.cls` -- add an LDAP arm to `PermittedCreateFields` (the 29 `LdapFields`, plus `Name`). The delete is permitted, with no arm refusing it. Check Epic 23's footprint first.
- `S/Api/Router.cls` -- append these routes in prefix order, with thin targets:
  - `GET /ldap/name`, `GET /ldap/examples`, `POST /ldap`;
  - `POST /ldap/:id/test`, placed before `PUT /ldap/:id`.
- `S/Screen/Registry.cls`, `S/Screen/Read.cls` -- add `bit64` (Boundaries).
- `S/Screen/Descriptor/LdapConfigList.cls`, `LdapConfigForm.cls` -- add the declarations in Boundaries, and rewrite the doc comments for the full editor. Then regenerate `U/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `S/Kernel/Governance/Baseline.cls` -- add three keys, enabled.

Server tests (on `ocupilot-ci`, one class per run). New armed classes join a new `# classes:` line under `OCUPILOT_ALLOW_SERVICE_CONFIG` in `scripts/ci-throwaway.sh`, with `ui/tools/ci.test.mjs` kept equal.

- `S/Test/LdapUpdate.cls`:
  - The exemption test becomes `TestTheFormDescriptorIsBuiltUnlistedAndLinksNowhere`, asserting `exempt` 0, `ClassicLinkProblem` "" and a sentence for every LDAP violation code.
  - Add legs for `LDAP.FLAGS.KERBEROS` (192 refused, 128 accepted), `LDAP.NAME.FORM` on the update id, and `PrivilegePairs` equal to `WithClassicPages(<list pairs>, "%CSP.UI.Portal.LDAP")`.
- `S/Test/LdapEdit.cls`:
  - Update the form-read key count. Add `kerberos` from the instance's `Security.System`, the `new=1` defaults, `name` (`FormatName` corpus `Corp.Example.COM`, `corp`, `""`) and `examples` (modes 1-3 equal `FormatExample`).
  - Add the Kerberos-only Save (128 set, 64 clear, `UNKNOWNHOST`).
  - DW-1639: on probes with `LDAPFlags` 72 and 8, the list's screen read and its read tool answer `Enabled` true, then false.
  - The least-privileged principal Saves and reads the form.
- `S/Test/LdapCreate.cls` (new, armed):
  - The create's mint finds the name absent and composes the complete set; the confirm is refused once the name is created.
  - `NAME.FORM`, `NAME.TAKEN` and `HOST.REQUIRED` are refused at the mint and on the Save (422).
  - The Save create answers 201, and the configuration is read back.
  - The delete tool's mint, confirm and Save remove the configuration, which is then absent, and an absent name answers 404.
- `S/Test/LdapPassword.cls` (new, armed):
  - Each of Enter, Clear and Leave on the Save is read back by presence through `Security.LDAPConfigs.Get` in `%SYS`, never printed.
  - The agent's tool: the mint holds no secret, the confirm supplies it, and the ledger row, payload, diff and draft hold only the placeholder.
  - `CLEARABLESECRETS`: `""` reaches the body for `security.ldap.password`, and is still dropped for `permissions.users.password`.
- `S/Test/LdapTest.cls` (new, armed) -- on a probe configuration with host `127.0.0.1:1`:
  - 200 `{lines}`, non-empty and holding "Test completed" (measured).
  - The caller's `%Api.Admin.Util.AsyncTask` row count is unchanged, and the unique probe password is absent from that class's data and stream globals, `^ERRORS` and messages.log.
  - 422 for each test refusal, 404 for an absent name, and 403 for a caller lacking the pairs.
  - The connection-test pair never reaches `SaveRequestBody`.
- `S/Test/SecurityLists.cls` -- the LDAP list's field list gains `LDAPFlags` and its `rowGet` (`:58`, `:207-213`).
- `S/Test/RowGetCorpus.cls` -- the `bit64` corpus: 64 and 72 true, 8 and 128 false, `""` unreadable.
- `S/Test/ClassicPageGate.cls`, `SurfaceCoverage.cls`, `EndpointCoverage.cls`, `ReadTool.cls` (188 → 191), `ToolRoundTrip.cls`, `PortFixture.cls`, `ToolWrite.cls`, `Descriptor.cls` -- the roster rows for the three tools, four routes and two types.

Client:

- `U/areas/security/ldap-editor.store.ts`, `ldap-editor.page.ts` (new):
  - The editor in Boundaries, mirroring the SSL editor's create at the bare route, tabs, `FormDirty`, summary, "Saved" and the `ChangeBus` publish (`ldap-configuration`, `created` or `updated`, with `readBack`).
  - The flag couplings, the password radio group, Copy settings from, the examples and the name check.
- `U/areas/security/ldap-test-dialog.ts` (new): the Test authentication dialog.
- `U/areas/security/ldap-actions.ts` (new), as `ssl-actions.ts`: Create (`createFormFor`) and Delete. It is injected in `U/app.ts`, which also resets the editor store on sign-out.
- `U/shell/screen-outlet.ts` -- register `LdapEditorPage` for `LdapConfigForm` in both maps. Delete the reduced form files listed in the Code Map.
- `U/core/strings.ts` -- append each new label, sentence and dialog string, citing its EXPERIENCE.md row. The labels are the classic captions in sentence case; reuse an existing key where the value matches. Bump the bound in `strings.test.mjs` with a comment if it is crossed.
- EXPERIENCE.md, edited in place (993 lines):
  - `:504` becomes the full editor's labels, tabs and password options.
  - `:505` becomes the create, name, copy and absent copy, replacing the bare-route sentence.
  - `:173` names the LDAP test dialog.
  - `:363` gains `ldapListEmptyAgent`.
  - `:508` keeps the prompts.
  - Rows `:633`, `:691` and `:730` drop the reduced LDAP form where they name it.
- Client tests:
  - New: `ldap-editor.store.spec.ts`, `ldap-editor.page.spec.ts`, `ldap-test-dialog.spec.ts` and `ldap-actions.spec.ts`.
  - `screen-outlet.spec.ts`; and `app.spec.ts`, for the sign-out reset.
  - `ui/tools/classic-links.test.mjs`: `{}`, `0 exemption(s)` and `0 descriptor(s)`.
  - `ui/tools/floor.test.mjs`: `LdapConfigForm` declares none.
  - `ui/tools/screen-mirror.test.mjs`: `bit64`.
  - `ui/tools/navigation.test.mjs`: messages.
- `ui/browser/ldap-editor.browser-spec.mjs` (new) -- its legs are guarded to `-ci` containers and each restores in `finally`:
  1. The name cell opens the editor, showing the three tabs, the Kerberos pair and no classic card.
  2. A field and a flag are saved and read back through `docker exec`.
  3. The password is entered, then cleared, and each is read back by presence.
  4. Create from the command bar, then Delete from the row.
  5. Test authentication shows the instance's lines.
  6. DW-1639: the list shows Enabled Yes.
  7. The DW-1337 structural walk at an id route, in both themes.
- `ui/browser/oauth.browser-spec.mjs:372` -- a declared edit: the roster becomes `[]`.
- Bundle: re-base `maximumWarning` and its `angular-json.test.mjs` literal to the measured total, rounded up to the next kB (DW-1166). HALT `blocked` above 3800kB.

**Acceptance Criteria:**

- **AC1 (coverage).** Given the LDAP / Kerberos list, when a name cell is followed, then the editor opens on General, Groups and Attributes. It covers every input of `%CSP.UI.Portal.LDAP` in the classic order: the Kerberos pair where the instance has Kerberos, the couplings, the examples, and the CA file as text. No classic card is drawn. Pinned by browser leg 1 and `ldap-editor.page.spec.ts`.
- **AC2 (sync, recommended wording).** Given the vendor's `TEST`, which the admin API would queue and which carries the tested user's password, when the editor is built, then list, get and put stay synchronous and the test runs on `AdminPort`'s synchronous path, never the vendor's queue. Pinned by `LdapTest`'s no-row and no-password legs.
- **AC3 (the instance's text).** Given a configuration, when the user runs Test authentication, then the dialog shows the instance's own lines. Pinned by `LdapTest` and browser leg 5.
- **AC4 (an ordinary call).** Given the test runs, when it answers, then the port exposes it as an ordinary call, the slice writes no polling logic, and the password reaches no task row, journal, log line or ledger row. Pinned by `LdapTest` and the journal check under Verification.
- **AC5 (search password).** Given the editor, when Enter, Clear or Leave as is is saved, then the instance holds the new password, none, or the old one. The agent's `security.ldap.password` sets it from the card. No password is ever read or recorded. Pinned by `LdapPassword` and browser leg 3.
- **AC6 (create).** Given the list's Create, when a configuration is saved, then it is created under the name the instance stores (`LDAP.NAME.FORM`). The agent's create fingerprints the name's absence (AD-54) and composes the complete set. Pinned by `LdapCreate` and browser leg 4.
- **AC7 (delete).** Given a configuration row, when Delete is confirmed with the typed name, then the configuration is removed by either caller. Pinned by `LdapCreate` and browser leg 4.
- **AC8 (rules).** Given 64 sent together with 128, a short name, a taken name or no host, when either caller sends it, then nothing is sent and the refusal names its field with the published sentence. Pinned by `LdapUpdate`, `LdapCreate` and `LdapEdit`.
- **AC9 (DW-1639).** Given an enabled configuration, when the list or its read tool reads it, then Enabled reads true. Pinned by `LdapEdit` and browser leg 6.
- **AC10 (the exemption).** Given the built descriptors, when `classic-links.mjs` runs, then it honors no exemption. Pinned by `classic-links.test.mjs`, `floor.test.mjs`, `LdapUpdate`'s descriptor test and the OAuth roster.
- **AC11 (the classic pages' resources).** Given a custom resource on `%CSP.UI.Portal.LDAP` or `%CSP.UI.Portal.LDAPTest`, when a caller lacking it uses the tools, the Save or the test, then it is refused 403 naming the pair, before any port call. Pinned by `ClassicPageGate` and `LdapTest`.
- **Integration.** Given `LdapEditorPage`, which reads `GET /ldap/form` and saves through `PUT /ldap/:id` or `POST /ldap`, when a Save succeeds, then the list re-reads (`ChangeBus` `ldap-configuration`) and shows the change. The browser observes this.
- **AC12 (hygiene).** Given any test in this story, when it ends, pass or fail, then no `ocup99*` configuration, probe principal or probe task row remains, and `ocupilot` was never touched.

## Spec Change Log

- 2026-10-01, lead, spec gate (orchestrator merge gate 2026-10-01, Rule 5): the plan's intent gap answered with option (a) -- epics.md 16.14 criteria 2 and 4 amended at origin as written under Design Notes (the test runs on `AdminPort`'s synchronous path, never the vendor's queue), and a new criterion added at origin for create, search password and delete (approved; FR-45; delete takes the typed-name confirmation; their governance keys enabled); spine amendments (a)-(g) written; Task 0 added (measure the synchronous path first; HALT if it persists the password). Status reset from `blocked`.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-26 and AD-39: the test (see the blocking question).
- AD-3: no template change. `ToolFields` is regenerated for the three tools.
- AD-4: the merge, and the measured upsert.
- AD-5: tabs; the list's actions.
- AD-6, AD-51 and AD-56 (i): the password tool and `CLEARABLESECRETS`.
- AD-8 and AD-29: no extra pair. `%Admin_Secure:USE` covers TEST and CHANGEPWD; the synchronous test polls nothing, so it needs no `%Admin_Operate`.
- AD-10: no arm refuses any LDAP effect.
- AD-13: `foldcase` stays, and `LDAP.NAME.FORM` keeps keys canonical.
- AD-14; AD-15 and AD-53: `LDAPConfigChange` records each write, and the test is not a write, so there is no new case.
- AD-16; AD-19; AD-21: the CA file is shown and never set.
- AD-22: three keys are added.
- AD-24: the form declares no context.
- AD-35; AD-36: `bit64`.
- AD-44: zero exemptions, plus `CLASSICPAGES`.
- AD-54; AD-55; AD-58: the password is reported as written.
- AD-59: `Snippet` for `CHANGEPWD` and `DELETE`.

**Blocking question (intent gap; Rule 5 and Rule 6).**

- **The conflict.** AC2 and AC4 (epics.md `:6518-6528`) route the test through `AdminPort`'s async path. On `ocupilot-ci`, that path stores the test body — the tested user's password, in plain text — in two places: the vendor's task row, which any user can read, and the journal, where no delete reaches it. AD-26's queued-write refusal and AD-35 exist to prevent exactly this ("where a secret could never be taken back").
- **Why the port cannot avoid it.** It cannot keep the password out of the row. The poller deletes the row only for a holder of `%DB_IRISLOCALDATA:WRITE`. Even a delete on every exit leaves the journal copy.
- **Recommended.** The planning-artifact and spine amendments below. This spec implements them.
- **Alternatives:**
  - Keep the async path, accept the exposure, and amend AD-26 to say so.
  - Defer the test to a later story, and ship the editor without it.

**Other decisions for the lead** (the spec implements each one as recommended):

- **Tabs.** General, Groups and Attributes, cut at the classic page's own captions (the epic context's open question).
- **Delete.** It is included. FR-45 lists delete, EXPERIENCE.md `:173` lists an LDAP configuration delete confirmation, and no other story owns it.
- **`LDAP.NAME.FORM` refuses rather than rewrites.** The instance resolves `corp` to `corp.com`. A rule refusing short names keeps `foldcase` as the identity rule, so AD-13's identity layer is not edited.

**Named limits:**

- The test output carries no verdict, and the dialog shows only the instance's lines.
- A test that outruns the gateway answers `ldapTestNoAnswer`. The run then completes in its own process and stores nothing (inference; checked by the journal measurement).
- The agent cannot clear the password: its card requires a value. Clearing is the editor's. A crafted confirm sending `""` clears the password as the user's own act.
- Copying settings never copies the password.

**Planning-artifact amendment for the lead** (Rule 5; epics.md `:6518-6528`; record it in this spec's change log when applied):

- The second criterion becomes:
  - **Given** the `Security.LDAP` endpoint's test request type, which the admin API would queue, carries the tested user's password
  - **When** this editor is built
  - **Then** list, get and put stay synchronous, and the test runs on `AdminPort`'s synchronous path, never the vendor's queue.
- The fourth criterion becomes:
  - **Given** the test runs
  - **When** it answers
  - **Then** the port exposes it as an ordinary call -- the slice writes no polling logic -- and the password reaches no task row, journal, log line or ledger row.

**Spine amendments for the lead (Rule 20):**

- (a) **AD-26.** Remove `Security.LDAP (test connection only, …)` from "the other five", and recount it as four. Then add this paragraph:

  > **Story 16.14's test** [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20]: `Security.LDAP` `TEST` runs on the synchronous path by decision, although its `ShouldRunAsync()` is true. Its body carries the tested user's password, and the vendor's queue writes a body in plain text into its task row, which `IRISLOCALDATA`'s public `READ` lets any user read, and into the journal inside the save's transaction, where no delete reaches it (measured on `ocupilot-ci`, 2026-09-30). So the port runs a `CONNECTIONTESTTYPES` pair in process and never queues it; its outcome is its captured console lines.

  In the Deferred row "Stage 2+ async endpoint paths", drop "LDAP test" so the remaining types read "four".
- (b) **AD-39**, a paragraph:

  > **A fourth: the LDAP test's output** (Story 16.14): `Security.LDAP` `TEST` answers `{}` and OK whatever happened, so its captured console lines are its result. They reach the screen only, as text, and never the model, a tool result, a ledger row, an audit payload or a log line [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20].
- (c) **AD-36**, after "the first rule, `beforeToday`, …":

  > the second, `bit64`, answers whether a whole number has bit 6 (64) set, which the LDAP / Kerberos list's Enabled reads from `LDAPFlags` because the vendor's LIST answers false for every configuration (DW-1639, Story 16.14) [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20]
- (d) **AD-44.** Replace "Release 1 has exactly one: … It is declared once, by `LdapConfigForm`." with:

  > Release 1 has none, so SM-C1 counts zero: the reduced service and LDAP editors' exemptions closed with Stories 16.13 and 16.14 [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20: was "exactly one … SM-C1 counts one"].

  Then add this paragraph:

  > **Story 16.14's `CLASSICPAGES`** [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20]: the LDAP update, create and password tools declare the classic editor `%CSP.UI.Portal.LDAP`, and the test route unions `%CSP.UI.Portal.LDAPTest`'s resource; the delete, performed on the list's own page, declares none.
- (e) **AD-4**, appended to its first paragraph, with `Security.LDAP` added to the upsert sentence:

  > `Security.LDAP` keeps a field its body omits and is an upsert (measured on `ocupilot-ci` 2026-09-30: a `PUT` carrying only `Description` kept every other field; a complete `PUT` on an absent name answered 201, a partial one 500 #1482); its `PUT` refuses `LDAPSearchPassword`, which travels only by `CHANGEPWD` [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20].
- (f) **AD-56 (i)**, appended:

  > An explicitly supplied empty secret clears the stored one where the tool declares it (`CLEARABLESECRETS`, Story 16.14's LDAP search password, whose `CHANGEPWD` clears on `""`); elsewhere an empty secret is not a secret supplied [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20].
- (g) **AD-13**, appended:

  > `ldap-configuration` keeps `foldcase`, and a name the instance would store differently (`Security.LDAPConfigs.FormatName`: lower case, `.com` added to a bare name) is refused by every LDAP tool and route (`LDAP.NAME.FORM`, Story 16.14), so a key is always the stored name [AMENDED 2026-09-30, Story 16.14 spec gate, Rule 20].

**Integration (Rules 1 and 2):**

- **Consumes:** 9.9's `LdapUpdate`, `LdapSave`, `LdapRules` and routes; the SSL editor's create, test and password patterns; 16.13's tabs and `CLASSICPAGES`; `OAuthClientSave`'s secret sequencing; `ChangeBus`.
- **Consumed-by:** the LDAP editor (the in-process connection test, `CLEARABLESECRETS`) and the LDAP list (`bit64`), all in this story. No later consumer is planned.
- **Integration ACs:** the Integration AC, AC3 and AC9.

**Ledger:**

- DW-1639 is addressed by AC9 and the `bit64` tasks.
- Declined DW-118: Story 15.6 resolved it (epic context).

## Verification

This runs on slot A. Every probe and test runs on `ocupilot-ci`, one test run at a time.

- **Loading.** From the worktree root, run `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `sh <scratchpad>/epic-16/compile.sh <changed paths>`. Read every line of the result.
- **Browser.** Rebuild and redeploy first (`cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`). Then export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- **Armed classes.** Use the lead's shim, with `OCUPILOT_ALLOW_SERVICE_CONFIG` added to its four names.

**Commands:**

- `(loop)` `cd ui && npm run test:tools` -- expected: green.
- `(loop)` `cd ui && npx ng test --include src/app/areas/security/ldap-editor.store.spec.ts --include src/app/areas/security/ldap-editor.page.spec.ts --include src/app/areas/security/ldap-test-dialog.spec.ts --include src/app/areas/security/ldap-actions.spec.ts --include src/app/shell/screen-outlet.spec.ts --include src/app/app.spec.ts` -- expected: green.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call -- expected: green. `<C>` is each of these:
  - armed: `LdapUpdate`, `LdapEdit`, `LdapCreate`, `LdapPassword`, `LdapTest`, `ClassicPageGate`;
  - unarmed: `SecurityLists`, `RowGetCorpus`, `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `DraftRegistry`, `SslTest`, `ProposalConfirm`, `ReadBack`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/ldap-editor.browser-spec.mjs browser/oauth.browser-spec.mjs` -- expected: green within the structural baseline. Report the build's initial total.
- `(once, before dev_complete)` The journal check: after one `LdapTest` run with a fresh unique probe password, `docker exec ocupilot-ci sh -c 'grep -c <password> /durable/iris/mgr/journal/<current file>'` -- expected: 0.
- `(once, before dev_complete)` `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md -- expected: green, and 993 lines.
- `(once, before dev_complete)` The full ObjectScript sweep on `ocupilot-ci`, one class at a time -- expected: green, apart from the residue the spawn prompt names. The full browser suite runs in CI only (Rule 29).

**Mutations** (Rule 19, one per AC; each reverted with the tree byte-identical afterwards; ObjectScript recompiled with its descendants; the client rebuilt and redeployed before a browser result counts):

- AC1: the page draws Groups whatever `kerberos` answers → `ldap-editor.page.spec.ts`; drop the 16/32 coupling → store spec.
- AC2: `Sequence` hands `Security.LDAP/TEST` to the queue → `LdapTest`'s no-row leg.
- AC3: `TestOutcome` drops the captured lines → `LdapTest` and the dialog spec.
- AC4: `TestOutcome` passes the captured lines to `LogFault` → `LdapTest`'s messages.log and `^ERRORS` absence leg.
- AC5: `Operation.SecretBody` drops `""` for listed names → `LdapPassword`'s Clear leg.
- AC6: `LdapCreate` reads present as absent → `LdapCreate`'s taken leg; `Canonical` answers its input → the `NAME.FORM` leg.
- AC7: `LdapDelete` sends no `DELETE` → `LdapCreate`'s delete leg.
- AC8: `Validate` skips `LDAP.FLAGS.KERBEROS` → `LdapUpdate`.
- AC9: `bit64` answers the LIST's value → `LdapEdit`'s DW-1639 leg.
- AC10: `LdapConfigForm` set back to exempt and the mirror regenerated → `classic-links.test.mjs` and `floor.test.mjs`.
- AC11: `LdapUpdate.CLASSICPAGES` emptied → `ClassicPageGate`.
- Integration: `save` skips the publish → store and page specs.
- AC12: `LdapCreate.OnAfterOneTest` skips `RemoveAll` → its residue assertion.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned.**
  - A tabbed editor (General, Groups, Attributes) over every input of `%CSP.UI.Portal.LDAP`.
  - Create from the list's command bar, and Delete from a row (FR-45).
  - A write-only search password through the vendor's `CHANGEPWD`, with Enter, Clear and Leave as is.
  - Test authentication, run in process.
  - DW-1639 through a `bit64` `rowGet` rule.
  - `LdapConfigForm`'s exemption removed, so SM-C1 counts zero.
  - Three new write keys, which join the baseline enabled.
- **Measured on `ocupilot-ci`** (transcripts in `scratchpad/epic-16/16-14/`):
  - The vendor endpoint's request types, bodies and gates.
  - The upsert, and the `LDAPFlags` normalization.
  - `FormatName` and `FormatExample`.
  - The test's in-process run: 5 s, with its output lines and no audit event.
  - The queued body in the task row and the journal.
  - The task row's public read.
  - Every probe configuration, principal and task row was deleted. Only the journal copies of two probe passwords remain, and no API removes them.
- **Lead decisions besides the blocker:**
  - The tab grouping.
  - Including Delete.
  - `LDAP.NAME.FORM` refusing a short name, rather than an AD-13 rule rewriting it.
- **Ledger.** DW-1639 is addressed; DW-118 is declined (resolved by 15.6).
- **Edits.** Only this spec was written; `bash scripts/lint-docs.sh` reports 0 issues.
