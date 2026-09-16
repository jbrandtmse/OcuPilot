---
title: 'The X.509, LDAP/Kerberos and wallet lists'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
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
  - **Wallet create APIs:** `%Wallet.Collection.Create(name, {Resource})` (`irissys/%Wallet/Collection.cls:57`; name pattern `:15`) and `%Wallet.KeyValue.Create(name, {Resource, Secret})` (`irissys/%Wallet/KeyValue.cls:70`).
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

- [ ] `src/OcuPilot/Port/AdminPort.cls` -- `TYPESUFFIXES` becomes `GET,LIST,INFO,CERTINFO`, and the doc names the certificate read -- X.509's subject, issuer and validity are reachable only through `CERTINFO`.
- [ ] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/RowGetCorpus.cls`, `src/OcuPilot/Test/CriteriaCorpus.cls` -- add the `rowGet.type` rule and the parent-criteria rule (Boundaries), with the same sentences in both engines. `ReadRowGet` gains optional `type`. Add corpus cases for the Matrix's two corpus rows, and let `CriteriaCorpus` cases set `parentScope` -- one grammar, two engines.
- [ ] `src/OcuPilot/Screen/Read.cls` -- `DetailRow` invokes the declared `rowGet.type`, defaulting to `DETAILTYPE` -- CERTINFO merge.
- [ ] `src/OcuPilot/Screen/Descriptor/X509CredentialList.cls`, `LdapConfigList.cls`, `WalletCollectionList.cls`, `WalletSecretList.cls` -- create per the table. All share these settings (a doc comment follows `SslConfigList` shape, no history):
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

- [ ] `src/OcuPilot/Screen/Area.cls`, `src/OcuPilot/Test/Descriptor.cls:1067` -- append `%Admin_Wallet:USE` to `security`, with a short doc paragraph stating the false denial and its count (Design Notes); update the pin -- coverage.
- [ ] `ui/src/app/core/navigation.ts`, `ui/src/app/shell/data-table.ts`, `ui/src/app/shell/list-page.ts`, `ui/src/app/shell/locator-bar.ts` -- add `childListFor`/`parentListFor` and the parent-scoped client behavior (Boundaries). Pin them in `ui/tools/navigation.test.mjs` (the pairing, and `security/wallet/secrets/<id>` resolving to Secrets) and in `list-page.spec.ts`/`data-table.spec.ts` (criteria from the id, and link targets) -- open a collection.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, `ui/src/app/core/strings.ts` -- append rows `:350-353` in 6.2's style, with keys commented `EXPERIENCE.md:<line>`:
  - `:350` "X.509" · "Alias" · "Subject" · "Issuer" · "Valid from" · "Valid until" · "No X.509 credentials on this instance."
  - `:351` "LDAP / Kerberos" · "No LDAP / Kerberos configurations on this instance."
  - `:352` "Wallet" · "Use resource" · "Edit resource" · "No wallet collections on this instance."
  - `:353` "Secrets" · "No secrets in this collection."

  Regenerate `ui/src/app/core/screens.generated.ts`.
- [ ] `src/OcuPilot/Install/Fixture.cls` -- the following changes, all per Boundaries:
  - Add `CreateWalletCollection` and call it after `CreateX509Credential`.
  - Add the `walletcollection` arms in `RemoveOne` and `ObjectState`.
  - Header counts become six fixtures and five `%SYS`-scoped ones.
  - **DW-49:** the header and the doc comments of `DemoCertificatePem`/`DemoPrivateKeyPem` state that the pair is a disposable demo fixture, a self-signed `CN=OcuPilotDemo` prop securing nothing, never to be reused.
  - Replace `:342-347` with the verified fact: no supported API on 2026.2 creates a certificate (no `PKI.*` class exists), and `CertificateSet` fills the DN, serial and thumbprint fields.
- [ ] `src/OcuPilot/Test/Demo.cls` -- `TestDemoWalletCollectionFixtureExists`, modeled on `:581`: the probe collection exists, holds exactly one secret, and has an inventory row of kind `walletcollection` -- AD-25.
- [ ] `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls` -- add `X509LISTTOOL`, `LDAPLISTTOOL`, `WALLETLISTTOOL` and checks `x509`, `ldap`, `wallet` (13 in all; pairs named in the doc); Test/Smoke expects 13 and one live-check test reads the three.
- [ ] `src/OcuPilot/Test/ScreenRead.cls:179` -- issue the declared `rowGet.type`, and skip parent-scoped reads, which `SecurityLists` holds -- the X.509 detail fields are held to the live `CERTINFO`.
- [ ] `src/OcuPilot/Test/ReadTool.cls`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs` -- 17 tools in sorted order, 15 shipped reads, criteria count 3 (+`WalletSecretList`). The built routes after `web-applications/rest-apis` become `security/wallet/secrets`, `security/ssl`, `security/x509`, `security/ldap`, `security/wallet`.
- [ ] `src/OcuPilot/Test/Wire.cls:572`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` -- ADMINUSER's Security screens become five: the two wallet entries denied on `%Admin_Wallet:USE`, the others on `%Admin_Secure:USE`. Both `LIVE_PAYLOAD` copies equal Wire's string, with a `screenVerdict` assertion per new route.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls` -- update the Security pins and refusals of SECUREUSER, SYSREADUSER and BOTHUSER. Add WALLETUSER and WALLETNODBUSER, and the Matrix's pair rows. Update the header.
- [ ] `src/OcuPilot/Test/SecurityLists.cls` (new; needs the API app over HTTP, the demo fixture and the test account) -- the pattern is `PermissionsLists`:
  - each descriptor passes `ReadProblem`/`ClassicLinkProblem`, with route and tool resolving to it; the classic page compiles under its declared case, or is `""`; `AreaCoverageProblem("security", …)` is empty
  - the Matrix's X.509, LDAP, Wallet, Secrets, Unknown and No collection, and Tool rows
  - AC4
- [ ] `ui/browser/security.browser-spec.mjs` (new; creates a principal and refuses the live container; needs `OCUPILOT_DEMO`) -- the browser ACs below.

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

## Spec Change Log

- 2026-09-16 (spec gate, lead): AD-36 amended to name `CERTINFO`; DW-233 closed `wontfix-accepted` (no generator on the image, verified), DW-59 corrected; the union's aggregate cost filed as DW-1018 for the user.

## Review Triage Log

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-27 / AD-26:** `AdminPort` alone is used, and every call is an inventoried synchronous LIST or `CERTINFO`.
- **AD-3:** no write. `Wallet.Secret`'s missing template is Story 8.6's.
- **AD-5:** Secrets declares its parent through the existing `parentScope` key, which 6.6's per-task history reuses. That is chosen over a route-suffix convention because AD-5 names the parent declaration.
- **AD-8 / AD-29:** `ResourcesOR()` plus IRISSYS read.
  - The backing checks are `%Admin_Secure`, via `RESOURCEREQUIRED` on `%SYS.X509Credentials` and `Security.LDAPConfigs`.
  - The wallet `List` queries check nothing, so no `QUERYPAIRS` entry is expected (inference). The throwaway principals settle it.
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
- From `ui/`, `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for SecurityLists, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Navigation, Demo, Smoke and AdminPortSync -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: `x509`, `ldap` and `wallet` pass, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, with `screen-mirror --check` clean.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `security.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Planned mutations (Rule 19; record each as `mutation:` once observed, then revert and confirm the tree byte-identical):**

- AC1: `LdapConfigList` `sideBarPosition` 5, bundle rebuilt -> browser AC1 side-bar order red.
- AC2: `Read.DetailRow` back to a fixed `GET` -> `SecurityLists` X.509 row and browser AC2 red.
- AC3: `data-table.ts` drops `childListFor` from the chain -> browser AC3 red.
- AC3: `ListPage` omits the criterion -> 400 named fault, AC3 red.
- AC4: `WalletSecretList` read adds a field the vendor row lacks -> the key-set assertion red.
- AC5: `WalletCollectionList` privileges drop `%Admin_Wallet:USE` -> `WireSecurityRead` BOTHUSER wallet pin and browser AC5 red.
- Integration: `Tool.Read.View` keeps cap+1 rows (scratch copy) -> the tool test red.
- Grammar: `Registry` `rowGet.type` arm disabled -> `ReadTool` RowGetCorpus cases red, and the `screen-mirror` twin likewise.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
