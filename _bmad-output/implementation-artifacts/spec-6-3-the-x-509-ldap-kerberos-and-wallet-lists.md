---
title: 'The X.509, LDAP/Kerberos and wallet lists'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: '1700db037bb34af62f48a664d0f20c4ddec21ce5'
baseline_commit: '1700db037bb34af62f48a664d0f20c4ddec21ce5'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The derived read tool describes every text criterion as a comma-separated name list with a * wildcard that may be omitted, which is wrong for the Secrets tool's required single collection name.
    evidence: |-
      src/OcuPilot/Screen/Tool/Read.cls:103 emits that description for every text criterion and never marks one required; Wallet.Secret answers 400 without `collection` and takes one name. Screen/Tool/** is outside this story's edits (Boundaries), and the OpenAPI viewer's criterion has the same text.
    location: >-
      src/OcuPilot/Screen/Tool/Read.cls:103
    severity: medium
  - summary: >-
      Demo-fixture counts and the inventory kind vocabulary are stale outside Fixture.cls after the wallet fixture landed.
    evidence: |-
      README.md:244 and src/OcuPilot/Install/Installer.cls:11 and :958 still say five demo fixtures, and src/OcuPilot/Kernel/State/Demo.cls:19-26 lists the Kind vocabulary without walletcollection. README and Kernel/** are excluded by the Boundaries and Installer.cls takes additive edits only.
    location: >-
      README.md:244; src/OcuPilot/Install/Installer.cls:11,958; src/OcuPilot/Kernel/State/Demo.cls:19
    severity: low
  - summary: >-
      The Secrets screen's route id is a wallet collection name while the screen declares entity type wallet-secret, so a screen-context reader could label the collection as a secret.
    evidence: |-
      Unverified: depends on how Story 4.4's screen context reads a parent-scoped screen's route id; settle it by rendering 4.4's context at security/wallet/secrets/OcuPilotDemo.
    location: >-
      src/OcuPilot/Screen/Descriptor/WalletSecretList.cls
    severity: medium (unverified)
  - summary: >-
      Principal-creating browser specs refuse only the live `ocupilot` container, so pointing OCUPILOT_BROWSER_CONTAINER at an owner-managed slot instance would create and delete a probe role and user there.
    evidence: |-
      ui/browser/security.browser-spec.mjs copies the LIVE_CONTAINER guard every existing principal-creating spec uses (ui/browser.config.mjs); ocupilot-slot-* is not refused.
    location: >-
      ui/browser.config.mjs
    severity: low
---

<intent-contract>

## Intent

**Problem:** The Security area lists SSL/TLS configurations only. X.509, LDAP / Kerberos and Wallet have no screen, a wallet collection's secrets cannot be opened, and the agent has no read tool for any of them.

**Approach:** Add four hand-written descriptors over the audited `Security.X509Credential`, `Security.LDAP`, `Wallet.Collection` and `Wallet.Secret` LISTs, read through `AdminPort`, rendered by `ListPage`, with derived tools. Two grammar additions cover what the vendor rows lack. An optional `rowGet.type` lets the X.509 read merge the endpoint's `CERTINFO` subject, issuer and validity. A parent-scoped list fills its one criterion from its route id and opens from the Wallet name cell. The opt-in demo fixture gains a wallet collection holding one secret, and DW-49's marking lands.

## Boundaries & Constraints

**Always:**

- **Nothing secret is read.** No read, context, table or tool field carries a private key, password, certificate body or secret value, so `context.secretFields` is empty everywhere. X.509 leaves out `HasPrivateKey` too: it matches the Conventions credential pattern that `ui/tools/screen-mirror.test.mjs:705-728` enforces.
- **Pairs.**
  - X.509 and LDAP declare `%Admin_Secure:USE`, then `%DB_IRISSYS:READ`.
  - Wallet and Secrets declare `%Admin_Wallet:USE`, then `%DB_IRISSYS:READ`, so a caller without the wallet resource is refused naming it.
  - The `security` area appends `%Admin_Wallet:USE` (`AreaCoverageProblem`; DW-278 accepted the union).
  - If a principal holding a screen's declared pairs is refused, or reads fewer rows than the test account, find the missing pair and append it to the descriptor, the area, `AdminPort.QUERYPAIRS`, the area pin and a principal. Record it under Design Notes.
- **`rowGet.type`.** It is optional, one of `GET`, `INFO` or `CERTINFO`, and absent means `GET`. Both engines refuse any other value with one sentence. `Screen.Read.DetailRow` issues the declared type, and `AdminPort.TYPESUFFIXES` gains `CERTINFO`.
- **Parent-scoped list.**
  - A descriptor with a non-empty `parentScope` and a `read` declares exactly one `read.criteria` field. Both engines refuse anything else with one sentence.
  - In the client, a list's child is the built, unlisted, id-keyed screen whose `parentScope` is that list's route. The list's name cell links to its child, checked after the editor and the document viewer.
  - `ListPage` fills the child's criterion with the decoded route id.
  - A parent-scoped screen's own name cell is not a link unless it pairs an editor or viewer.
  - The locator bar's screen segment routes to the parent.
- **Demo wallet fixture (AD-25, AD-35).**
  - `Fixture` creates collection `<prefix>` with Resource `%Admin_Wallet:USE`, and one `%Wallet.KeyValue` secret `<prefix>.Sample` whose value is generated at create time from `$System.Encryption.GenCryptRand`.
  - The value is never checked in, reported, logged or put in a status.
  - Guard-then-act as `CreateX509Credential` does: an existing collection is left untouched and not recorded.
  - Inventory kind `walletcollection`. `RemoveOne` deletes the collection and its secrets, and `ObjectState` reports it.
- **Shared files.** Edits to Epic 4's shared files are additive. New EXPERIENCE.md Fixed strings rows go after `:349`. Non-ASCII in code is written as `\uXXXX`.

**Never:**

- **No new machinery beyond the two additions above:** no port, endpoint type other than `CERTINFO`, column kind, archetype or client page.
- **No edits** under `Kernel/**` or `Screen/Tool/**`, nor to `scripts/check-objectscript.py`, `app.ts`, `shell/panel/**`, `README.md`, `ui/package*.json` or `angular.json`.
- **No product changes outside the lists:** no classic link-out, auto-refresh, write or row action (those are Stories 8.5, 8.6 and 9.6), and no relaxing of `AreaCoverageProblem`.
- **Nothing generated at install:** no certificate generation, external process or install-time file write (DW-233 is declined).
- A denial is never an empty state and never a 500.

## I/O & Edge-Case Matrix

The throwaway has the demo fixture installed. The test account is `_SYSTEM`. "Install-DB read" is read on the install database.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| X.509 | `GET /screens/security.x509/read?maxRows=1000` | 200. `fields` = `[Alias,OwnerList,PeerNames,CAFile,SubjectDN,IssuerDN,ValidityNotBefore,ValidityNotAfter]`. The `OcuPilotDemoCert` row's `SubjectDN` and `IssuerDN` contain `CN=OcuPilotDemo`, and both validity values are non-empty. | No error expected |
| LDAP | `security.ldap` | `fields` = `[Name,Enabled,Description,LDAPCACertFile]`. At least one row, and `Enabled` is boolean. | No error expected |
| Wallet | `security.wallet` | `fields` = `[Name,EditResource,UseResource]`. Rows include `OcuPilotDemo`. | No error expected |
| Secrets | `security.secrets`, `collection=OcuPilotDemo` | `fields` = `[Name,Type]`. `OcuPilotDemo.Sample` reads `%Wallet.KeyValue`. | No error expected |
| Unknown collection | `collection=NoSuchCollection` | 404 named fault, no `rows` | Never 500 |
| No collection | Secrets read with no `collection` | 400 named fault, no `rows` | Never 500 |
| Secure pairs | BOTHUSER: install-DB read, `%Admin_Secure:U`, `%DB_IRISSYS:R` | X.509 and LDAP answer 200, rows equal to the test account's. Wallet and Secrets answer 403 `AUTH.NOPRIVILEGE` naming `%Admin_Wallet:USE`. Navigation: X.509 and LDAP allowed, the two wallet entries denied on that pair, and the area reads `false:%Admin_Wallet:USE`. | — |
| Wallet pairs | WALLETUSER (new): install-DB read, `%Admin_Wallet:U`, `%DB_IRISSYS:R` | Wallet and Secrets (`OcuPilotDemo`) answer 200, rows equal to the test account's. X.509 and LDAP answer 403 naming `%Admin_Secure:USE`, and so does the area. | — |
| No system DB read | SECUREUSER; WALLETNODBUSER (new: install-DB read, `%Admin_Wallet:U` only) | SECUREUSER's X.509 and LDAP reads and entries, and WALLETNODBUSER's Wallet and Secrets reads and entries, are refused naming `%DB_IRISSYS:READ` | Never 500 |
| Tool | `Screen.Tool.Read.View` for each tool (Secrets with `collection`) at cap N | Returns `fields,rows,truncated` only. Rows equal the first N of `ApplyView` over the route's rows. | — |
| `rowGet.type` corpus | absent, `GET`, `INFO`, `CERTINFO` / `certinfo`, `LIST`, `1` | The first four are sound; the rest are refused with the one sentence | — |
| Parent criteria corpus | `parentScope` with 0, 1 or 2 criteria | Only 1 is sound | — |

</intent-contract>

## Code Map

- **Precedents.**
  - `src/OcuPilot/Screen/Descriptor/SslConfigList.cls` is the Security-area template.
  - `UserList.cls:56` is the only `rowGet`.
  - `OpenApiViewer.cls` is the criteria-on-an-unlisted-screen precedent.
  - Spec 6.2's Code Map is the roster checklist.
- **Vendor endpoints** (hidden, so read them with `iris_doc_get` in `%SYS`).
  - **`Security.X509Credential`:** `ResourcesOR` `%Admin_Secure`. LIST (`%SYS.X509Credentials:ListDetails`) keys are `Alias,OwnerList,PeerNames,HasPrivateKey,CAFile`. It overrides `Run`, and `TYPECERTINFO=10` → `RunCertInfo(alias)` answers `HasPrivateKey,SerialNumber,IssuerDN,SubjectDN,ValidityNotBefore,ValidityNotAfter`.
  - **`Security.LDAP`:** LIST/GET `ResourcesOR` `%Admin_Secure` or `%Admin_Operate`. LIST (`Security.LDAPConfigs:List`) keys are `Name,Enabled,Description,LDAPCACertFile`, and no password is in it.
  - **LDAP / Kerberos:** there is no Kerberos endpoint. Kerberos is `LDAPFlags` bit 128, and the classic page is `%CSP.UI.Portal.LDAPs`.
  - **`Wallet.Collection`:** `ResourcesOR` `%Admin_Wallet`. LIST (`%SYS.Wallet.Collection:List`) keys are `Name,EditResource,UseResource`, from the query's ROWSPEC (`irissys/%SYS/Wallet/Collection.cls:122`); slot B has no live row.
  - **`Wallet.Secret`:** `ResourcesOR` `%Admin_Wallet`. LIST requires `collection`: a missing value answers 400 (`GetRequiredQueryParam`) and an unknown one answers 404. Keys are `Name,Type`, from the ROWSPEC (`irissys/%SYS/Wallet/Secret.cls:287`), and there is no GET route.
  - **Wallet create APIs:** `%Wallet.Collection.Create(name, {Resource})` (`irissys/%Wallet/Collection.cls:57`; name pattern `:15`) and `%Wallet.KeyValue.Create(name, {Secret})` (`irissys/%Wallet/KeyValue.cls:70`); a secret carries no `Resource`, and the generated `ModifyInternal` refuses any key it does not declare (`irissys/%Wallet/Secret.cls:276`; a `Resource` key answered error 26218 on `ocupilot-b-ci`).
  - **Classic pages:** X.509 `%CSP.UI.Portal.X509Credentials` (`RESOURCE` `%Admin_Secure`). No classic wallet page exists.
- **Live on slot B (2026-09-16):** one X.509 credential (`OcuPilotDemoCert`, SubjectDN `OU=Demo Fixture,O=OcuPilot,CN=OcuPilotDemo`), one LDAP configuration (`unknowndomain.com`), and zero wallet collections.
- **Inventory:** `src/OcuPilot/Test/AdminInventory.cls:84,103,107,108` covers all four endpoints; the LIST paths are synchronous.
- **Port:** `src/OcuPilot/Port/AdminPort.cls:92` `TYPESUFFIXES`. `:683` `ImplementsRead` trusts a class that overrides `Run`. `:121` `QUERYPAIRS`.
- **Read:** `src/OcuPilot/Screen/Read.cls:48` `DETAILTYPE`, and `:447` `DetailRow`'s `Invoke`.
- **Grammar:**
  - `Screen/Registry.cls:1018` `RowGetProblem` and `:829` `CriteriaProblem`.
  - `ui/tools/screen-mirror.mjs:902` `rowGetProblem`, `:746` `criteriaProblem`, `:1275` `ReadRowGet`, `:1437` `parentScope`.
  - Corpora: `Test/RowGetCorpus.cls`; `Test/CriteriaCorpus.cls`, whose cases may already set `refreshes` or `port`.
- **Client:**
  - `ui/src/app/core/navigation.ts:165-205`: `editorScreenFor`, `documentScreenFor`, `listForDocumentScreen`.
  - `ui/src/app/shell/data-table.ts:408`: the `linkTarget` chain.
  - `ui/src/app/shell/list-page.ts:85-92`: `createScreenRead` with no criteria. `core/screen-read.ts:190` accepts criteria.
  - `shell/locator-bar.ts:218`.
  - `shell/rail.ts:225`: a gated rail item opens no side bar.
- **Area:** `src/OcuPilot/Screen/Area.cls:90` Security pairs, with the OS-management paragraph as the cost-note model. `Test/Descriptor.cls:1067` is the area pin.
- **Fixture:** `src/OcuPilot/Install/Fixture.cls`.
  - Header `:1-56` ("five" fixtures, "four" `%SYS`-scoped ones).
  - `Create` `:143` is the call list.
  - `CreateX509Credential` `:337-382`. `:342-347` wrongly says `PKI.CAServer.Configure` generates a certificate.
  - `NoteRow` `:771`, `RemoveOne` `:905-930`, `ObjectState` `:1047`.
  - PEM literals `:1072-1138`.
  - `Test/Demo.cls:581` is the X.509 existence test.
- **Rosters:**
  - `Test/ReadTool.cls:93-94,100` (13 tools), `:234` (11 shipped reads), `:307` (criteria count 2).
  - `ui/tools/screen-mirror.test.mjs:445` (11 names), `:571-575` (criteria descriptors).
  - `ui/tools/navigation.test.mjs:117-134` (built routes; position-0 screens sort first).
  - `Test/Wire.cls:572` (ADMINUSER Security screens).
  - `ui/tools/navigation-wire.test.mjs:168-183` and `ui/src/app/shell/rail-wire.spec.ts:167-182` (`LIVE_PAYLOAD`).
  - `Test/WireSecurityRead.cls`: `:458-467` SECUREUSER, `:482-491` SYSREADUSER, `:505-508` BOTHUSER, `:288` `AssertReadRefused`, principals `:46-104`.
  - `Install/Smoke.cls:44-82,477-535` (10 checks). `Test/Smoke.cls:411-429,444-463,477`.
  - `Test/ScreenRead.cls:179-239`: every admin LIST with an empty query; the detail call is hard-coded `GET`.
- **UX:**
  - EXPERIENCE.md `:137-142` (screen rows), `:168` (side-bar order), `:221` and `:478` (Wallet gating), `:349` (last Fixed strings row).
  - `ui/src/app/core/strings.ts:598` is the last key. `ui/tools/strings.test.mjs:321` is the band, 150-300 with 273 used.
  - `privilegeDeniedScreen` `:219`.
- **Browser patterns:** `ui/browser/permissions.browser-spec.mjs` (principal, `signedInAtList`, deep-link denial `:358-377`), `ssl.browser-spec.mjs`, `rest-apis.browser-spec.mjs:104` (name cell into an unlisted screen), and `list-spec.mjs`.

## Tasks & Acceptance

**Execution:**

- [x] `src/OcuPilot/Port/AdminPort.cls` -- `TYPESUFFIXES` becomes `GET,LIST,INFO,CERTINFO`, and the doc names the certificate read -- X.509's subject, issuer and validity are reachable only through `CERTINFO`.
- [x] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/RowGetCorpus.cls`, `src/OcuPilot/Test/CriteriaCorpus.cls` -- add the `rowGet.type` rule and the parent-criteria rule (Boundaries), with the same sentences in both engines. `ReadRowGet` gains optional `type`. Add corpus cases for the Matrix's two corpus rows, and let `CriteriaCorpus` cases set `parentScope` -- one grammar, two engines.
- [x] `src/OcuPilot/Screen/Read.cls` -- `DetailRow` invokes the declared `rowGet.type`, defaulting to `DETAILTYPE` -- CERTINFO merge.
- [x] `src/OcuPilot/Screen/Descriptor/X509CredentialList.cls`, `LdapConfigList.cls`, `WalletCollectionList.cls`, `WalletSecretList.cls` -- create per the table. All share these settings (a doc comment follows `SslConfigList` shape, no history):
  - area `security`, archetype `list`, scope `instance`, id `single`
  - `refreshes` false, no actions
  - `emptyNextKey` `tableReadOnlyEmptyNext`, `classicLinkExemption` not exempt
  - `paging` `cap`
  - `context.fields` = read fields, sort default = the name field, ascending

  | Descriptor | route / pos / tool / entity | privileges | read (source extras) | filter · sort | columns (field:kind:labelKey) | label / empty / aliases / classicPage |
  | --- | --- | --- | --- | --- | --- | --- |
  | X509CredentialList | `security/x509` / 2 / `security.x509` / `x509-credential` | Secure, IRISSYS | Matrix fields; `rowGet {key: Alias, param: alias, type: CERTINFO, fields: [SubjectDN,IssuerDN,ValidityNotBefore,ValidityNotAfter], derived: []}` | Alias, SubjectDN, IssuerDN · same + ValidityNotAfter | Alias:name:x509ColumnAlias · SubjectDN:text:x509ColumnSubject · IssuerDN:text:x509ColumnIssuer · ValidityNotBefore:text:x509ColumnValidFrom · ValidityNotAfter:text:x509ColumnValidUntil | `x509ListLabel` / `x509ListEmpty` / `["x509"]` / `%CSP.UI.Portal.X509Credentials` |
  | LdapConfigList | `security/ldap` / 3 / `security.ldap` / `ldap-configuration` | Secure, IRISSYS | Matrix fields | Name, Description · same | Name:name:tableColumnName · Enabled:status:tableColumnEnabled · Description:text:tableColumnDescription | `ldapListLabel` / `ldapListEmpty` / `["kerberos"]` / `%CSP.UI.Portal.LDAPs` |
  | WalletCollectionList | `security/wallet` / 4 / `security.wallet` / `wallet-collection` | Wallet, IRISSYS | Matrix fields | Name, UseResource, EditResource · same | Name:name:tableColumnName · UseResource:text:walletColumnUseResource · EditResource:text:walletColumnEditResource | `walletListLabel` / `walletListEmpty` / `["secrets"]` / `""` |
  | WalletSecretList | `security/wallet/secrets` / 0 / `security.secrets` / `wallet-secret`, `parentScope` `security/wallet` | Wallet, IRISSYS | Matrix fields; `criteria.fields [{param: collection, labelKey: tableColumnName, kind: text, maxLength: 64}]` | Name, Type · same | Name:name:tableColumnName · Type:text:tableColumnType | `walletSecretListLabel` / `walletSecretListEmpty` / `[]` / `""` |

- [x] `src/OcuPilot/Screen/Area.cls`, `src/OcuPilot/Test/Descriptor.cls:1067` -- append `%Admin_Wallet:USE` to `security`, with a short doc paragraph stating the false denial and its count (Design Notes); update the pin -- coverage.
- [x] `ui/src/app/core/navigation.ts`, `ui/src/app/shell/data-table.ts`, `ui/src/app/shell/list-page.ts`, `ui/src/app/shell/locator-bar.ts` -- add `childListFor`/`parentListFor` and the parent-scoped client behavior (Boundaries). Pin them in `ui/tools/navigation.test.mjs` (the pairing, and `security/wallet/secrets/<id>` resolving to Secrets) and in `list-page.spec.ts`/`data-table.spec.ts` (criteria from the id, and link targets) -- open a collection.
- [x] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, `ui/src/app/core/strings.ts` -- append rows `:350-353` in 6.2's style, with keys commented `EXPERIENCE.md:<line>`:
  - `:350` "X.509" · "Alias" · "Subject" · "Issuer" · "Valid from" · "Valid until" · "No X.509 credentials on this instance."
  - `:351` "LDAP / Kerberos" · "No LDAP / Kerberos configurations on this instance."
  - `:352` "Wallet" · "Use resource" · "Edit resource" · "No wallet collections on this instance."
  - `:353` "Secrets" · "No secrets in this collection."

  Regenerate `ui/src/app/core/screens.generated.ts`.
- [x] `src/OcuPilot/Install/Fixture.cls` -- the following changes, all per Boundaries:
  - Add `CreateWalletCollection` and call it after `CreateX509Credential`.
  - Add the `walletcollection` arms in `RemoveOne` and `ObjectState`.
  - Header counts become six fixtures and five `%SYS`-scoped ones.
  - **DW-49:** the header and the doc comments of `DemoCertificatePem`/`DemoPrivateKeyPem` state that the pair is a disposable demo fixture, a self-signed `CN=OcuPilotDemo` prop securing nothing, never to be reused.
  - Replace `:342-347` with the verified fact: no supported API on 2026.2 creates a certificate (no `PKI.*` class exists), and `CertificateSet` fills the DN, serial and thumbprint fields.
- [x] `src/OcuPilot/Test/Demo.cls` -- `TestDemoWalletCollectionFixtureExists`, modeled on `:581`: the probe collection exists, holds exactly one secret, and has an inventory row of kind `walletcollection` -- AD-25.
- [x] `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls` -- add `X509LISTTOOL`, `LDAPLISTTOOL`, `WALLETLISTTOOL` and checks `x509`, `ldap`, `wallet` (13 in all; pairs named in the doc); Test/Smoke expects 13 and one live-check test reads the three.
- [x] `src/OcuPilot/Test/ScreenRead.cls:179` -- issue the declared `rowGet.type`, and skip parent-scoped reads, which `SecurityLists` holds -- the X.509 detail fields are held to the live `CERTINFO`.
- [x] `src/OcuPilot/Test/ReadTool.cls`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs` -- 17 tools in sorted order, 15 shipped reads, criteria count 3 (+`WalletSecretList`). The built routes after `web-applications/rest-apis` become `security/wallet/secrets`, `security/ssl`, `security/x509`, `security/ldap`, `security/wallet`.
- [x] `src/OcuPilot/Test/Wire.cls:572`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` -- ADMINUSER's Security screens become five: the two wallet entries denied on `%Admin_Wallet:USE`, the others on `%Admin_Secure:USE`. Both `LIVE_PAYLOAD` copies equal Wire's string, with a `screenVerdict` assertion per new route.
- [x] `src/OcuPilot/Test/WireSecurityRead.cls` -- update the Security pins and refusals of SECUREUSER, SYSREADUSER and BOTHUSER. Add WALLETUSER and WALLETNODBUSER, and the Matrix's pair rows. Update the header.
- [x] `src/OcuPilot/Test/SecurityLists.cls` (new; needs the API app over HTTP, the demo fixture and the test account) -- the pattern is `PermissionsLists`:
  - each descriptor passes `ReadProblem`/`ClassicLinkProblem`, with route and tool resolving to it; the classic page compiles under its declared case, or is `""`; `AreaCoverageProblem("security", …)` is empty
  - the Matrix's X.509, LDAP, Wallet, Secrets, Unknown and No collection, and Tool rows
  - AC4
- [x] `ui/browser/security.browser-spec.mjs` (new; creates a principal and refuses the live container; needs `OCUPILOT_DEMO`) -- the browser ACs below.

**Acceptance Criteria:**

- Given `_SYSTEM` on HSCUSTOM, when the Security area opens, then its side bar reads SSL/TLS, X.509, LDAP / Kerberos, Wallet, and each new list renders under its declared headers from exactly one read.
- Given the X.509 list, when `OcuPilotDemoCert` renders, then its Subject, Issuer, Valid from and Valid until cells equal that row of the read response, and Subject contains `CN=OcuPilotDemo`.
- Given the Wallet list, when the `OcuPilotDemo` name cell is activated, then all of the following hold:
  - the URL becomes `security/wallet/secrets/OcuPilotDemo`
  - exactly one read carrying `collection=OcuPilotDemo` is issued
  - the table lists `OcuPilotDemo.Sample` as `%Wallet.KeyValue`, and its name cell is not a link
  - the locator bar's screen segment links to `security/wallet`
- Given every row the four reads and the four tools return, when their keys are inspected, then each row's keys are exactly the declared fields, and no key is `PrivateKey`, `PrivateKeyPassword`, `Certificate`, `HasPrivateKey`, `LDAPSearchPassword`, `Secret`, `Secret64` or `Value`. For LDAP, Wallet and Secrets, the raw port LIST row's key set equals the declared fields.
- Given a throwaway principal holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` without `%Admin_Wallet:USE`, when the shell loads, then all of the following hold:
  - the Security rail item and the command box's Wallet entry are gated with "Requires %Admin_Wallet:USE"
  - deep links to `security/wallet` and `security/wallet/secrets/OcuPilotDemo` each render the title and "You need %Admin_Wallet:USE to open <title>." with no table and no read
  - a deep link to `security/x509` reads
- Integration: given consumer `Screen.Tool.Read.View`, when it reads `security.x509.read`, `security.ldap.read`, `security.wallet.read` and `security.secrets.read` (with `collection`) live, then it returns the route's fields and rows narrowed by its cap.

### Review Findings

Code review 2026-09-16, tier `full-opus`, four layers (blind, edge, verification-gap, acceptance). 45 raw findings: 16 entries after grouping (0 high, 5 medium, 11 low), 11 patched or closed in-pass, 5 deferred with an owner or a terminal status, 23 rejected.

- [x] [Review][Patch] (medium) A parent-scoped list opened for another parent showed the previous parent's rows and selection until its read answered, and kept them if that read failed, because every parent shares the descriptor's store [ui/src/app/shell/list-page.ts:100]. The page now drops the store's answers when it opens, pinned by a new `list-page.spec.ts` case.
- [x] [Review][Patch] (medium) Nothing checked that the demo wallet secret's generated value stays out of the fixture reports (AD-35) [src/OcuPilot/Test/Demo.cls]. `TestDemoWalletSecretValueIsInNoReport` reads the value back and scans every report message and data field.
- [x] [Review][Patch] (low) The demo collection's `%Admin_Wallet:USE` use and edit resource was never asserted [src/OcuPilot/Test/Demo.cls]. Now asserted in `TestDemoWalletCollectionFixtureExists`.
- [x] [Review][Patch] (low) The Integration AC's only `mutation:` line did not go red [spec `## Verification`]. The over-narrowing mutation is observed red and replaces it. A tool that keeps too many rows is still invisible at one row per list; `PermissionsLists` pins that cut over the same `View`.
- [x] [Review][Patch] (low) `list-page.spec.ts` "a list with no parent sends no criterion" declared no criterion, so it could not fail on the `parentScope` guard [ui/src/app/shell/list-page.spec.ts]. It now declares one.
- [x] [Review][Patch] (low) DW-1019: `Installer.cls` still said five demo fixtures [src/OcuPilot/Install/Installer.cls:11,958]. Now six. `README.md:244` is contended and is closed `wontfix-accepted` on DW-1019; `Kernel/State/Demo.cls` lists kinds as examples ("e.g."), so it is not stale.
- [x] [Review][Patch] (low) `Fixture.cls` and `FixtureFault.cls` headers still counted three `Delete` calls and three warns [src/OcuPilot/Install/Fixture.cls:40; src/OcuPilot/Test/FixtureFault.cls:12]. Now four.
- [x] [Review][Patch] (low) `Screen.Read.Execute`'s doc still said a row whose `GET` answers 404 is dropped [src/OcuPilot/Screen/Read.cls:137]. Now "detail call".
- [x] [Review][Patch] (low) `TestTheSecurePairsReadX509AndLdapAndNotTheWallet`'s mutation note named wallet pins that live in `TestBothPairsReadEveryList` [src/OcuPilot/Test/WireSecurityRead.cls:622]. Corrected.
- [x] [Review][Patch] (low) The smoke skip for an empty X.509 or Wallet list was exercised only by `SmokeListFault`'s faked answer [src/OcuPilot/Install/Smoke.cls:546]. Observed on a real instance with the demo fixture removed (`## Verification`).
- [x] [Review][Patch] (low) Removing a wallet collection that holds a secret was never observed to remove the secret [src/OcuPilot/Install/Fixture.cls:989]. Observed on the throwaway's real demo fixture (`## Verification`); the vendor's `%Wallet.Collection.%OnDelete` deletes a collection's secrets.
- [x] [Review][Defer] (medium) The area union gates the Security rail for the stock `%SecurityAdministrator` role, which lacks `%Admin_Wallet` (observed on slot B), and EXPERIENCE.md `:221`/`:482` still describe screen-level Wallet gating [src/OcuPilot/Screen/Area.cls:100] — deferred: the Boundaries mandate the union; DW-1018, `decision-pending`, with the observation appended.
- [x] [Review][Defer] (medium) The Secrets read tool describes its required single `collection` as an optional comma list with a wildcard [src/OcuPilot/Screen/Tool/Read.cls:103] — deferred: `Screen/Tool/**` is contended; DW-1001, routed to 7-1.
- [x] [Review][Defer] (medium) `security.browser-spec.mjs` refuses only the `ocupilot` container [ui/browser/security.browser-spec.mjs] — deferred: harness-wide; DW-1015, escalated.
- [x] [Review][Defer] (low) A Secrets URL for a deleted or unknown collection reads the generic "request refused" with a Retry that cannot clear it [ui/src/app/shell/data-table.ts:150] — deferred: distinct copy needs an EXPERIENCE.md row; DW-1021, `wontfix-accepted`.
- [x] [Review][Defer] (low) The wallet fixture's create-side branches (a secret failing after `NoteRow`, a pre-existing collection) are driven by no test [src/OcuPilot/Install/Fixture.cls:405] — deferred: needs a create seam; DW-1022, `wontfix-accepted`.

**Rejected:**

- low: WALLETUSER's row equality cannot detect a vendor filter by collection resource. The vendor `ListFetch` filters nothing (`$$$AddSecurityRoleTemporary`); this becomes real only if a build starts filtering wallet LISTs.
- by-design: the locator's "Secrets" segment routes to the Wallet list. The Boundaries and AC3 require it.
- false: the one-criterion rule conflicts with 6.6. Per-task history takes one criterion, across-tasks history is not parent-scoped, and DW-1020 already takes the parent-scoped question to 6.6.
- low: an empty LDAP list fails smoke. The image ships `unknowndomain.com` (observed on a fresh throwaway), and skipping adds a branch; reopen if smoke `ldap` fails on an instance whose LDAP LIST is empty.
- low: the demo-flag resolution is duplicated in `Smoke`. The fix edits Epic 4's shared `CheckDemoFixture`.
- low: the failed-secret warn drops its status. The failure is unlikely, and error data would widen an AD-35 report.
- low: `ScreenRead` needs the demo wallet collection. This is a documented environment need, met on every demo throwaway.
- by-design: validity dates are shown without a time zone. The Design Notes fix the vendor text.
- low: a boolean `rowGet.type` gets different sentences in the two engines. No author writes one, and unifying adds a branch to both.
- false: `INFO` is allowed but never exercised. The Boundaries require it, and `ScreenRead` issues every shipped declared type live.
- false: the Registry criteria and `rowGet` sentences are stale. The criteria paragraph reads correctly as a whole, the `rowGet` sentence names the required keys, and the refusal sentences are corpus-pinned.
- false: `parentCriteria` decodes twice. The two decodes stand for the router's pass and the codec's, pinned by the `%Demo_1` round trip and browser AC3.
- low: SECUREUSER asserts no wallet refusal. That refusal is not a Matrix row, and BOTHUSER and SYSREADUSER assert it.
- low: the run numbers in `## Verification` repeat. Each set belongs to one throwaway incarnation.
- rejected: the spec's prose and size. The fix edits the spec.
- low (theoretical): a parent-scoped read declared at side-bar position above 0 or with id kind `none`, a parent criterion of kind `choice` or `datetime`, and a `parentScope` naming an unbuilt route. None of these is declared.
- by-design: the two `LIVE_PAYLOAD` copies are held by hand. The epic context names them a tripwire pair.
- false: the AC1, AC3 and AC5 clauses lack mutation lines. Rule 19 needs one observed mutation per AC, and each AC has one.
- low: the `ObjectState` wallet arm is asserted only as "already removed". The `x509credential` row has the same shape, and the regression is unlikely.
- rejected (edits the spec): `## Auto Run Result`'s "the first two skipped" means `x509` and `wallet`, which is what `Smoke.cls:546` skips.
- low: the PEM lines carry no inline marker. DW-49 asks for the class header and beside the literal, and both are present.

## Spec Change Log

- 2026-09-16 (spec gate, lead): AD-36 amended to name `CERTINFO`; DW-233 closed `wontfix-accepted` (no generator on the image, verified), DW-59 corrected; the union's aggregate cost filed as DW-1018 for the user.

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 47 findings — high 0, medium 9, low 32, false 4, maybe-false 2
- findings:
  - `[low]` `[patch]` Blind: a Secrets page whose id changes in place keeps the previous collection's rows, selection and scroll — reachable only by an in-place id change no control issues today; `list-page.ts` now calls `refresh.noteScopeChanged()` on the id change, pinned by the `list-page.spec.ts` selection assertion.
  - `[low]` `[reject]` Blind: `security/wallet/secrets` with no id issues a read that answers 400 — the screen is unlisted and never linked without an id; the named 400 fault is an honest answer and a skip branch adds client machinery.
  - `[medium]` `[defer]` Blind: the Secrets tool's schema text describes a comma-separated optional name list — confirmed at `Screen/Tool/Read.cls:103`; the file is excluded by the Boundaries, recorded in `deferred`.
  - `[low]` `[patch]` Blind: `Registry` still says a criteria-bearing screen renders nothing until Search, untrue for Secrets — appended to the parent-scoped paragraph that such a read runs on open and never auto-refreshes; the 6.6 conflict is an inference about an unplanned shape.
  - `[low]` `[reject]` Blind: nothing validates `parentScope` against other declarations — the one shipped parent-scoped screen is correctly declared and pinned by `navigation.test.mjs`; cross-declaration rules are new grammar the Boundaries exclude.
  - `[low]` `[reject]` Blind: the locator bar's parent route has no unit pin — browser AC3 asserts the locator link lands on `security/wallet`; `parentListFor` itself is now pinned (row below).
  - `[medium]` `[patch]` Blind: smoke fails `x509` and `wallet` on an instance without the demo fixture — confirmed (`CheckAreaLists` ignored `pDemo`; slot B has no wallet collection); an empty X.509 or Wallet list is now `skipped` when the demo was not requested, pinned by `Test.Smoke.TestAnEmptyDemoListIsSkippedWithoutTheDemo`.
  - `[low]` `[patch]` Blind: `Test/ScreenRead.cls` header omits the new environment needs — header now names `%Admin_Wallet:U`, an LDAP configuration and the demo's X.509 credential and wallet collection.
  - `[low]` `[patch]` Blind: the tool cap test cannot fail for these screens — confirmed (one row each; the cap is pinned by `PermissionsLists` over the same `View`); the test doc now says so. Adding rows would contradict the one-secret fixture.
  - `[medium]` `[patch]` Blind: wallet fixture removal is untested — confirmed; `FixtureFault.DeleteWalletCollection` seam, `DemoFaults.TestRemoveReportsAFailedWalletCollectionDelete` and a `walletcollection` row in `UninstallGuard` added, each observed red under its mutation.
  - `[low]` `[patch]` Blind: the wallet fixture's catch drops the error — the warn now carries the exception's name and location, never its data (AD-35).
  - `[low]` `[patch]` Blind: "five fixtures" counts are stale elsewhere — `DemoAppProbe.cls` corrected; README, Installer and `Kernel/State/Demo` are outside the allowed edits, recorded in `deferred`.
  - `[low]` `[patch]` Blind: `ProcessList.cls:21` lists `TYPESUFFIXES` without `CERTINFO` — corrected.
  - `[low]` `[reject]` Blind: `CERTINFO` is admitted port-wide — the Boundaries require `TYPESUFFIXES` to gain it; only `Security.X509Credential` declares the type.
  - `[low]` `[reject]` Blind: the engines render a boolean `rowGet.type` differently (`'1'` vs `'true'`) — both refuse it; unifying adds a branch to both engines for a declaration no author writes.
  - `[low]` `[reject]` Blind: validity is UTC shown without a zone — the spec's Design Notes fix validity as the vendor text and EXPERIENCE rows fix the labels.
  - `[maybe-false]` `[defer]` Blind: the Secrets route id is typed as `wallet-secret` — depends on Story 4.4's context reader, not built; recorded in `deferred` as medium (unverified).
  - `[medium]` `[reject]` Blind: area gating contradicts EXPERIENCE.md :221/:482 — real drift, but the Boundaries mandate the area union (DW-278) and DW-1018 holds the decision; noted in Auto Run Result for the lead.
  - `[low]` `[reject]` Blind: the LDAP list shows no Kerberos flag — Design Notes fix the table to the classic columns.
  - `[false]` `[reject]` Blind: `## Auto Run Result` is still the template — it is written at finalize, after this triage.
  - `[low]` `[reject]` Blind: the LDAP stock-row note still reads (inference) — the fix edits this spec; the observation is recorded in Auto Run Result.
  - `[low]` `[patch]` Blind: three test doc mutation claims were unobserved — each observed red on `ocupilot-b-ci` (Verification mutation lines added).
  - `[false]` `[reject]` Blind: `ScreenRead.cls:223` hard-codes `GET` — the test holds the spec's stated default independently of the product parameter, which is the discriminating posture.
  - `[low]` `[defer]` Blind: the browser spec's guard refuses only `ocupilot` — pre-existing pattern shared by every principal-creating spec; recorded in `deferred`.
  - `[low]` `[patch]` Edge: stale rows when the same Secrets page changes id — same root cause as the first Blind row; patched there.
  - `[medium]` `[patch]` Edge: smoke fails on an instance without the demo or LDAP row — same as the smoke row; `ldap` stays asserted like `ssl`, whose rows also come from the image (residual risk).
  - `[low]` `[reject]` Edge: `parentScope` names no built route or a listed child — same as the validation row.
  - `[low]` `[reject]` Edge: a collection whose secret once failed is never completed on later runs — the Boundaries mandate guard-then-act, leaving an existing collection untouched.
  - `[low]` `[reject]` Edge: a `rowGet.type` the endpoint does not declare answers 501 at runtime — `ScreenRead.TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` issues every shipped descriptor's declared detail type live.
  - `[low]` `[reject]` Edge: boolean or array `type` sentences differ between engines — same as the boolean row.
  - `[low]` `[patch]` Verification gap: the Integration AC's cap check cannot fail here — same as the cap row; doc corrected.
  - `[medium]` `[patch]` Verification gap: the wallet arms of `RemoveOne` and `ObjectState` are untested — same as the removal row; patched there.
  - `[low]` `[patch]` Verification gap: `parentListFor`'s inverse check is unpinned — `navigation.test.mjs` asserts a screen naming a parent it is not the child of resolves none; observed red with the check removed.
  - `[low]` `[patch]` Verification gap: no test builds a no-parent list that declares one criterion — `navigation.test.mjs` asserts `parentCriteria` fills nothing for it; observed red with the guard removed.
  - `[medium]` `[patch]` Verification gap (other): smoke fails without the demo fixture — same as the smoke row.
  - `[low]` `[patch]` Verification gap (other): stale rows on an in-place id change — same as the first Blind row.
  - `[low]` `[patch]` Intent: tool narrowing is never visible at cap 1 — same as the cap row.
  - `[low]` `[reject]` Intent: pair-row equality is shown on one-row populations — the vendor queries do not filter by caller (`irissys/%SYS/X509Credentials.cls:836`, `Wallet/Collection.cls:122`, `Wallet/Secret.cls:287`).
  - `[medium]` `[patch]` Intent: fixture removal and secrecy are untested — removal patched with the removal row; the generated value is unknown to any test, and the code passes it only to `KeyValue.Create` before clearing it.
  - `[medium]` `[patch]` Intent: smoke checks ignore the demo flag — same as the smoke row.
  - `[low]` `[reject]` Intent: a Secrets URL with no id reads 400 untested — same as the no-id row.
  - `[low]` `[reject]` Intent: the locator bar's parent route has no unit test — same as the locator row.
  - `[low]` `[reject]` Intent: a parent-scoped screen with its own child would link to it — no such screen exists, and a nested child is the plausible link target.
  - `[low]` `[reject]` Intent: boolean `type` parity, and `criteria: {fields: []}` on a parent-scoped read getting the empty-fields sentence — both engines refuse identically; the shape rules precede the count rule in both.
  - `[false]` `[reject]` Intent: shared files carry line-level edits — every such edit is one the Boundaries require (`TYPESUFFIXES`, `DetailRow`, the smoke loop, the area pin), and existing declarations behave as before.
  - `[false]` `[reject]` Intent: DW-49's ledger entry is not closed in the diff — the ledger is the lead's to adjudicate (Rule 15); this run marks the literals as the task requires.
  - `[maybe-false]` `[defer]` Intent: the Secrets URL id names a collection under entity type `wallet-secret` — same as the entity-type row.

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-27 / AD-26:** `AdminPort` alone is used, and every call is an inventoried synchronous LIST or `CERTINFO`.
- **AD-3:** no write. `Wallet.Secret`'s missing template is Story 8.6's.
- **AD-5:** Secrets declares its parent through the existing `parentScope` key, which 6.6's per-task history reuses. That is chosen over a route-suffix convention because AD-5 names the parent declaration.
- **AD-8 / AD-29:** `ResourcesOR()` plus IRISSYS read.
  - The backing checks are `%Admin_Secure`, via `RESOURCEREQUIRED` on `%SYS.X509Credentials` and `Security.LDAPConfigs`.
  - The wallet `List` queries check nothing, so no `QUERYPAIRS` entry is needed: WALLETUSER, holding only the declared pairs, reads both wallet lists at the test account's rows (`WireSecurityRead`, observed).
- **AD-13 / AD-14:** instance scope, and all four entity types already exist in `Kernel/EntityType.cls:28`.
- **AD-17 / AD-25:** the wallet fixture is opt-in, prefixed, and removed on uninstall.
- **AD-21:** no endpoint takes a path. `CAFile` and `LDAPCACertFile` are vendor values displayed, never accepted.
- **AD-24 / AD-36:** one capped read shared by screen and tool.
  - **Spine (lead, spec gate):** AD-36's detail-type sentence now names `CERTINFO`, the X.509 endpoint's certificate detail. `rowGet.type` is how a read declares it.
- **AD-35:** nothing secret is read; the fixture's generated value never reaches a report or status.
- **AD-43:** no refresh.
- **AD-44:** X.509 and LDAP name their classic pages. Wallet and Secrets have none, and say so with `""`.

**Choices:**

- **The Security area's union.**
  - A caller holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` without `%Admin_Wallet:USE` sees the Security rail item gated on the wallet pair, and a gated rail item opens no side bar (`rail.ts:225`). SSL/TLS, X.509 and LDAP stay reachable by command box and deep link.
  - The false-denial cost is 3 of 5 built Security screens. The stock `%Manager` role holds both resources (observed on slot B).
  - DW-278 declined relaxing coverage, so the AC's "by side bar" half is observed on the gated rail item and the command box entry.
  - The aggregate cost of the union across Logs, OS management and Security is DW-1018, `decision-pending` for the user at the merge gate; this story builds on the union as it stands.
- **Validity is text,** the vendor's `YYYY-MM-DD HH:MM:SS`, because no column kind is a date (the Task schedule's precedent).
- **LDAP's table** mirrors the classic columns: Name, Enabled, Description.
- **The LDAP row on a fresh throwaway** is the image's stock `unknowndomain.com` (inference). Its `LDAPInstanceId` host `ac2063550c46` differs from slot B's `a9e7629b1bdc`, and all 189 audit events on slot B's volume carry the latter. If the fresh throwaway's LDAP LIST is empty, the fixture also creates a `<prefix>` LDAP configuration under the wallet fixture's rules.

**Ledger inbox:**

- **DW-49:** addressed in the `Fixture.cls` task.
- **Declined DW-233:**
  - No supported API on IRIS 2026.2 generates a certificate. No `PKI.*` class exists in `%SYS` on slot B, and `%SYSTEM.Encryption` has only `X509GetField` and `X509VerifyCertChain`.
  - Its stated benefit is already delivered: `CertificateSet` fills `SubjectDN`, `IssuerDN`, `SerialNumber` and `Thumbprint`, and `PrivateKeySet` fills `HasPrivateKey`, on the direct-set path. Slot B's `OcuPilotDemoCert` reads all of them, with validity 2026-09-10 to 2036-09-07.
  - The owner's fallback, the checked-in pair, stands. AD-21 is moot because no file is involved.
  - The lead verified both facts on `ocupilot-slot-b` at the spec gate, closed DW-233 `wontfix-accepted` with a reopen probe, appended the correction to DW-59, and amended the `epics.md` bullet.

**Integration ACs:** the tool AC, the smoke checks, and the browser ACs.

**Consumes:**

- `AdminPort` (2.1)
- `Screen.Read` (2.3)
- `ListPage` and the data table (2.4)
- the gate and navigation (1.9)
- criteria (2.10, 6.1)
- the demo fixture (1.4)

**Consumed-by:**

- 4.2: tool registry.
- 4.4: screen context.
- 6.6: parent-scoped per-task history.
- 8.5: X.509 import, edit and delete from the X.509 list.
- 8.6: the wallet secret form from the Secrets list.
- 9.6: the LDAP and Kerberos editor.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Every principal, wallet collection, secret and fixture these tests create or remove lives on this throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for SecurityLists, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Navigation, Demo, DemoFaults, UninstallGuard, Smoke and AdminPortSync -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: `x509`, `ldap` and `wallet` pass, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, with `screen-mirror --check` clean.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `security.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations (Rule 19; record each as `mutation:` once observed, then revert and confirm the tree byte-identical):**

- mutation: `LdapConfigList` `sideBarPosition` 5, mirror regenerated, bundle rebuilt and redeployed -> browser AC1 red, the side bar reading SSL/TLS, X.509, Wallet, LDAP / Kerberos (observed).
- mutation: `Read.DetailRow` issues a fixed `GET`, loaded into `ocupilot-b-ci` -> `SecurityLists.TestTheX509ListReadsItsCertificateFieldsOverTheWire` red on subject, issuer, both validity dates and their equality to `CERTINFO` (run 16); browser AC2 red, the four cells reading `(none)` (observed).
- mutation: `data-table.ts` drops `childListFor` from the `linkTarget` chain -> `data-table.spec.ts` Story 6.3 case red; bundle rebuilt and redeployed -> browser AC3 red, the URL never reaching the Secrets route (observed).
- mutation: `ListPage` binds `createScreenRead` without the criteria -> `list-page.spec.ts` parent-scoped case red; bundle rebuilt and redeployed -> browser AC3 red, the read answering 400 and no secret row rendering (observed).
- mutation: `WalletSecretList` read and context fields add `Value`, loaded -> `SecurityLists.TestEveryRowCarriesTheDeclaredFieldsAndNoSecret` red on the route, tool and raw-row key sets (run 18), with the declaration and Secrets field pins (observed).
- mutation: `WalletCollectionList` privileges drop `%Admin_Wallet:USE`, loaded -> `WireSecurityRead` red on the SECUREUSER, SYSREADUSER and BOTHUSER Security pins and the BOTHUSER and SYSREADUSER wallet refusals (run 19); browser AC5 red, the command box Wallet entry no longer gated (observed).
- mutation: `Tool.Read.View` stops at cap-1 rows, loaded into `ocupilot-b-ci` only -> `SecurityLists.TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` red on the rows assertion for all four tools (code review, run 5; reverted, run 6 green). Keeping cap+1 rows stays green here, because each list answers one row, and `PermissionsLists` pins that cut over the same `View` (observed).
- mutation: `Registry.RowGetProblem`'s `type` arm disabled, loaded -> `ReadTool.TestEveryRowGetCorpusCaseGetsItsSentence` red on the `certinfo`, `LIST` and `1` cases (run 20); the same arm disabled in `screen-mirror.mjs` -> `screen-mirror.test.mjs` RowGetCorpus case red (observed).
- mutation: `Registry.CriteriaProblem`'s parent test forced false, loaded -> `ReadTool.TestEveryCriteriaCorpusCaseGetsItsSentence` red on the zero- and two-criteria parent cases (run 21); the same in `screen-mirror.mjs` -> `screen-mirror.test.mjs` CriteriaCorpus case red (observed).
- mutation: `Smoke.CheckAreaLists` loses its empty-list skip arm, loaded into `ocupilot-b-ci` -> `Test.Smoke.TestAnEmptyDemoListIsSkippedWithoutTheDemo` red on the X.509 and Wallet skips (run 14) (observed).
- mutation: `Smoke.WALLETLISTTOOL` set to `security.nosuch`, loaded -> `Test.Smoke.TestTheSecurityListsAreLiveChecks` red on the wallet check's 404 (run 14, same load as the line above; each mutation reddens only its own test) (observed).
- mutation: `Fixture.RemoveOne`'s `walletcollection` arm deleted, loaded with `FixtureFault` recompiled -> `DemoFaults.TestRemoveReportsAFailedWalletCollectionDelete` red on the warn, kept row and retry (run 15) (observed).
- mutation: `Fixture.Create`'s `CreateWalletCollection` call deleted, same load -> `Demo.TestDemoWalletCollectionFixtureExists` red on existence, secrets list and inventory row (run 16) (observed).
- mutation: `Fixture.ObjectState`'s `walletcollection` arm deleted, same load -> `UninstallGuard.TestUninstallStopsWhileAFixtureCannotBeRemoved` red, the row reading `(unrecognized kind)` (run 17) (observed).
- mutation: `WalletSecretList` privileges drop `%DB_IRISSYS:READ`, loaded -> `WireSecurityRead.TestWalletWithoutTheSystemReadIsDenied` red on the pin and the Secrets refusal (run 18) (observed).
- mutation: `ListPage` re-reads with `readNow()` instead of `noteScopeChanged()` on an id change -> `list-page.spec.ts` parent-scoped case red, the selection kept (observed).
- mutation: `parentListFor` returns the parent without the inverse check -> `navigation.test.mjs` "a screen naming a parent it is not the child of resolves none" red (observed).
- mutation: `parentCriteria` drops the `parentScope === ''` guard -> `navigation.test.mjs` "a list with no parent fills no criterion, whatever it declares" red (observed).

**QA independent falsification (2026-09-16, `ocupilot-b-ci`), one new mutation per falsifiable AC, none reusing a mutation already recorded above. Every mutation was applied to the running throwaway only (`docker cp` + `%SYSTEM.OBJ.Load`), never to the worktree; `git status --short` and `git diff --stat` were empty before, during and after (QA):**

- mutation (AC1): `WalletCollectionList`'s `area` changed `security` -> `logs`, loaded -> `SecurityLists.TestEachListIsDeclaredAsTheSecurityAreaEntryItReplaces` red on "in the Security and secrets area" (run 2); reverted, run 3 green (observed).
- mutation (AC2): `X509CredentialList`'s `rowGet.fields` drops `IssuerDN`, loaded -> `SecurityLists.TestTheX509ListReadsItsCertificateFieldsOverTheWire` red on the IssuerDN assertion and its equality to the live `CERTINFO` (run 4); reverted, run 5 green (observed).
- mutation (AC3): `WalletSecretList`'s `parentScope` changed `security/wallet` -> `""`, loaded -> `SecurityLists.TestEachListIsDeclaredAsTheSecurityAreaEntryItReplaces` red on "declaring its parent, or none" (run 6); reverted, run 7 green (observed).
- mutation (AC4): `LdapConfigList`'s `read.fields`/`context.fields` drop `LDAPCACertFile`, loaded -> three `SecurityLists` methods red at once (declared-fields pin, route/tool/raw key-set parity, and the LDAP Matrix row's own field count) (run 8); reverted, run 9 green (observed).
- mutation (AC5): `Area.cls`'s `security` entry drops its `%Admin_Wallet:USE` pair, loaded -> `SecurityLists.TestEachListIsDeclaredAsTheSecurityAreaEntryItReplaces` red on `AreaCoverageProblem` for both wallet screens (run 10); reverted, run 11 green (observed).

**Code review (2026-09-16, `ocupilot-b-ci`, up and down by the review; mutations to the throwaway or the local client only, restored byte-identical):**

- mutation: `Fixture.CreateWalletCollection` reports the secret's value in its success data, and `WALLETRESOURCE` becomes `%Admin_Secure:USE`, one load -> `Demo.TestDemoWalletSecretValueIsInNoReport` red on the scan, and `Demo.TestDemoWalletCollectionFixtureExists` red on the use and edit resource, nothing else (run 2; reverted, run 3 green, 11 tests) (observed).
- mutation: `ListPage` no longer drops a parent-scoped store's answers when it opens -> `list-page.spec.ts` "opened for another parent" red, still holding `OcuPilotDemo.Sample` (observed).
- mutation: `parentCriteria` loses its `parentScope === ''` guard -> `list-page.spec.ts` "a list with no parent sends no criterion" red, reading `&collection=A` (observed).
- observed, real instance: after `Fixture.Remove("")` removed the throwaway's demo fixture (the collection, its secret and the X.509 credential all gone, 0 `%Wallet.Secret` rows left), `Smoke.Run` with the flag `0` skipped `x509` and `wallet` on genuinely empty lists and passed (22 executed, 0 failed, `ssl` and `ldap` passing). With the flag `1` it failed `x509`, `wallet` and `demofixture`.
- Gates this pass: `check-objectscript` 0; `npm run build` and `npm test` green (802 tool, 399 component); `Demo` 11 and `SecurityLists` 7 green; browser 90/90 on the patched bundle.

Residual, not closed by a test: a tool that keeps more rows than its cap is invisible to `SecurityLists`, where each list answers one row; `PermissionsLists` pins that cut over the same `View`. The smoke skip without the demo is closed by the code review's real-instance observation above.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Four descriptors (X.509, LDAP / Kerberos, Wallet, Secrets) over `AdminPort` LISTs, with derived tools; `rowGet.type` (`GET`/`INFO`/`CERTINFO`) and the parent-scoped one-criterion rule in both engines; `CERTINFO` in `TYPESUFFIXES` and `Read.DetailRow`; the `security` area's `%Admin_Wallet:USE`; the client child-list link, parent criterion from the route id and locator parent; the demo wallet collection with one generated secret; DW-49's marking.

**Files.**

- `src/OcuPilot/Screen/Descriptor/{X509CredentialList,LdapConfigList,WalletCollectionList,WalletSecretList}.cls` (new) -- the four screens.
- `src/OcuPilot/Port/AdminPort.cls`, `Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/screens.generated.ts` -- `CERTINFO`, `rowGet.type`, the parent-criteria rule.
- `src/OcuPilot/Screen/Area.cls`, `Screen/Descriptor/ProcessList.cls` -- the area pair; a `TYPESUFFIXES` doc correction.
- `src/OcuPilot/Install/Fixture.cls`, `Install/Smoke.cls` -- the wallet fixture; `x509`, `ldap`, `wallet` checks, `x509` and `wallet` skipped on an empty list without the demo.
- `ui/src/app/core/navigation.ts`, `core/strings.ts`, `shell/{data-table,list-page,locator-bar}.ts`, EXPERIENCE.md `:350-353` -- client pairing and strings.
- Tests: `Test/SecurityLists.cls` and `ui/browser/security.browser-spec.mjs` (new); `Test/{CriteriaCorpus,RowGetCorpus,Demo,DemoFaults,DemoAppProbe,Descriptor,FixtureFault,ReadTool,ScreenRead,Smoke,UninstallGuard,Wire,WireSecurityRead}.cls`, `ui/tools/{navigation,navigation-wire,screen-mirror}.test.mjs`, `shell/{data-table,list-page,rail-wire}.spec.ts`, `ui/browser/ssl.browser-spec.mjs`.

**Review.** 47 findings (Review Triage Log): 12 entries patched (medium 2: smoke demo gating, wallet removal tests; low 10), 4 deferred (frontmatter), the rest rejected with reasons in the log.

**Follow-up review recommended: true** (patched medium 2, low 10). The smoke skip for an empty X.509 or Wallet list was later observed on a real instance with the demo fixture removed (code review, `## Verification`).

**Verification (this pass).** `check-objectscript` 0; `lint-docs` clean; full load to `ocupilot-slot-b` and compile clean; on `ocupilot-b-ci` (up and down by this run) SecurityLists 7, WireSecurityRead 9, Wire 20, ReadTool 25, ScreenRead 22, Descriptor 32, Navigation 11, Demo 10, DemoFaults 4, UninstallGuard 3, Smoke 28, AdminPortSync 6, all green in `%UnitTest_Result` after the patches; smoke passed with `x509`, `ldap`, `wallet` passing; `npm run build` and `npm test` green (802 tool, 398 component); browser 90/90 on the rebuilt, redeployed bundle. Nine new mutation lines observed and reverted, tree byte-identical.

**Notes for the lead.** EXPERIENCE.md `:221` and `:482` still describe screen-level Wallet gating while the area union gates the Security rail item (DW-1018). The fresh throwaway's LDAP LIST carries the stock `unknowndomain.com` row (observed), so no LDAP fixture was added. `%Wallet.KeyValue.Create` takes no `Resource` (error 26218, observed), so the Code Map line was corrected. Residual: the `ldap` smoke check, like `ssl`, relies on a row the image supplies.
