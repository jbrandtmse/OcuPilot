---
title: 'The OAuth 2.0 screen'
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

**Problem:** The Security area has no OAuth 2.0 screen. The instance's client server descriptions, client configurations, resource servers, authorization server and server client descriptions cannot be seen in OcuPilot, and the agent has no read tool for any of them.

**Approach:** Build one "OAuth 2.0" side-bar entry that opens five tabs. Each tab is its own hand-written `detail` descriptor, with its own read over an audited `Security.OAuth2.*` endpoint through `AdminPort`, its own table, its own derived tool, and a `classicLinkExemption` whose name cells open the classic editor in a new tab. The five are grouped by a new `tab` declaration. The reads and link-outs this needs are four grammar additions, each in both engines: a `GET` singleton source, a `forEach` per-parent list, `<object>.<member>` fields, and `classicLinkExemption.rowLink`. A shared `DetailPage` draws the tab strip over the existing list page.

## Boundaries & Constraints

**Always:**

- **The five descriptors.**
  - `security/oauth` is the listed member, at side-bar position 5. The other four take position 0.
  - All five declare archetype `detail`, `built` true, scope `instance`, id `single`, `refreshes` false, no actions and `paging` `cap`.
  - Each declares `emptyNextKey` `tableReadOnlyEmptyNext`. Its `context.fields` equal its read fields, and `secretFields` is `[]`.
  - Each declares `classicLinkExemption` with `exempt` true. The `reason` is "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1". The `label` is the editor page's own `PAGENAME`. The `href` and row params are given in the Tasks table.
- **`tab` grammar (both engines, one sentence per refusal, `Test/TabCorpus.cls`).**
  - `tab` is either absent or `{group, position, labelKey}`.
  - `group` is a route. `position` is a whole number of at least 1. `labelKey` is non-empty.
  - Position 1 holds exactly when `route` equals `group`. A member at position 2 or higher declares `sideBarPosition` 0.
  - **Roster rule** (`Registry.TabGroupProblem`, the mirror's `buildMirror`): members of one group share area and archetype; their positions run 1..n with no gap or repeat; and the group names a built member.
- **`GET` source (both engines, `Test/ReadSourceCorpus.cls`).**
  - `read.source.type` is `LIST` or `GET`. `GET` is admin-port only and declares no `rowGet`, `forEach` or `criteria`.
  - `Read.Execute` issues the `GET` and answers the object as one row.
  - A 404 answers zero rows with `truncated` false. Any other fault fails the read.
- **`forEach` source (same corpus).**
  - `read.source.forEach` is `{endpoint, key, param, fields: [{field, from}]}`. It is admin `LIST` only, with no `rowGet` or `criteria`, and every `field` is one of `read.fields`.
  - **Parents.** `Execute` lists `forEach.endpoint` with `maxRows` cap+1. A parent whose `key` is not a non-empty string or number is a 500.
  - **Children.** In parent order, it lists the source endpoint with `param` set to the parent's `key` text. Each child row gets each `from` value copied in as `field`. It stops once cap+1 rows are held.
  - **Faults and truncation.** A child 404 skips that parent. Any other fault fails the read. `truncated` is true when more than cap rows were held or the parent list itself exceeded the cap.
- **Member fields.** A declared field `<object>.<member>` that the row does not carry as a literal key is read from `<member>` of the row's object field `<object>` (`Read.CopyValue`). The row key keeps the dotted name.
- **`rowLink` (both engines, `Test/ClassicLinkCorpus.cls`).**
  - `classicLinkExemption.rowLink` is either absent or `{params: [{name, field}]}`. It is allowed only with `exempt` true on a declaration with a read.
  - `name` matches `^[A-Za-z][A-Za-z0-9]*$` and appears once. `field` is one of `read.fields` and is not secret.
  - The name cell's `href` is the exemption's `href`, followed by `?` or `&` and each `name=encodeURIComponent(text of the row's field)`. It opens with `target="_blank"` and `rel="noreferrer"`, never through the router and never through `window.open`.
- **`DetailPage`.**
  - `ARCHETYPE_PAGES.detail` renders `ListPage` for the current screen.
  - When the screen declares `tab`, the page first draws a `mat-tab-nav-bar` of the group's members, in position order, labeled by `tab.labelKey`, using the DESIGN.md `:589-597` tokens. Left and Right move between tabs.
  - A member the caller cannot open stays listed and focusable, with `aria-disabled` and "Requires <pair>", and does not navigate.
  - The side bar marks the group's entry current on every member route. The locator bar's screen segment routes to the group.
- **Pairs.**
  - Each tab declares its resource first and `%DB_IRISSYS:READ` second.
  - The `security` area appends `%Admin_OAuth2_Client:USE`, `%Admin_OAuth2_Server:USE` and `%Admin_OAuth2_Registration:USE`, in that order, after its existing three.
  - If a principal holding exactly a tab's pairs is refused, or reads fewer rows than `_SYSTEM`, find the missing pair and append it to the descriptor, the area, `AdminPort.QUERYPAIRS` if needed, the pins and a principal. Record it in Design Notes.
- **Shared files** (`Read`, `Registry`, `Descriptor/Base`, `AdminPort`, `Install/Smoke`, `Test/Descriptor`, `screen-mirror.mjs`, `strings.ts`): additive edits only. New EXPERIENCE.md Fixed strings rows go after `:353`. Non-ASCII in code is written as `\uXXXX`.

**Never:**

- **Out-of-bounds paths:** no edits under `Kernel/**`, `Screen/Tool/**` or `shell/panel/**`. Also none to `Port/ProviderPort.cls`, `scripts/check-objectscript.py` and its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json` or `README.md`.
- No write, delete or row action (7.3), no auto-refresh (AD-43), no OAuth demo fixture, and no `classic-link-card` on these tabs.
- **No secret is read.** No read, context or tool field names a client configuration's or server client's `Metadata`, `ClientSecret`, `ClientPassword`, `PrivateJWKS`, `SymmetricJWKS`, `InitialAccessToken` or `ServerPassword`. The authorization server tab names individual `Metadata.*` members, never `Metadata` itself.
- No new port, no `TYPESUFFIXES` entry, and no relaxing of `AreaCoverageProblem`.
- A denial is never an empty state and never a 500.

## I/O & Edge-Case Matrix

The throwaway has the demo fixture installed. `OcuPilot.Test.OAuthProbe.Create()` has made the following objects:

- server definitions `https://ocupilottest.invalid/a` (A) and `/b` (B)
- client configurations `OcuPilotTestA` on A and `OcuPilotTestB` on B, both using SSL configuration `OcuPilotDemo`
- resource server `OcuPilotTestResource` on A
- an authorization server configuration, created only when none exists, with scopes `openid` and `profile` and grant types `authorization_code` and `client_credentials`
- server client `OcuPilotTestRegistration`, type `resource`

Reads are `GET /screens/<tool>/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Descriptions | `security.oauthserverdescriptions` | 200. `fields` = `[ID,IssuerEndpoint,ClientCount,ResourceCount]`. A's row has ClientCount 1 and ResourceCount 1. The raw LIST row's key set equals `fields`. | No error expected |
| Clients | `security.oauthclients` | `fields` = `[ApplicationName,ClientType,DefaultScope,ServerDefinitionID,IssuerEndpoint]`. `OcuPilotTestB`'s IssuerEndpoint is B's issuer, and its ServerDefinitionID is B's `ID`. | No error expected |
| Clients cap | `maxRows=1` | 1 row, `truncated` true | — |
| Resource servers | `security.oauthresourceservers` | `fields` = `[Name,ServerDefinition]`. `OcuPilotTestResource` reads A's issuer. | No error expected |
| Authorization server | `security.oauthserver` | `fields` = `[IssuerEndpoint,Metadata.scopes_supported,Metadata.grant_types_supported,SigningAlgorithm,EncryptionAlgorithm,KeyAlgorithm,ServerCredentials]`. One row equal to the live GET projected. When the probe created the configuration, scopes include `openid` and grant types include `authorization_code`. | No error expected |
| Unconfigured | `ReadFixture`: the GET answers 404 | 200, `rows` `[]`, `truncated` false | Never 404 or 500 |
| Server clients | `security.oauthserverclients` | `fields` = `[Name,ClientId,ClientType,RedirectURL,Description]`. `OcuPilotTestRegistration` has a non-empty ClientId. | No error expected |
| forEach faults | `ReadFixture`: parents [P,Q]; P's child answers 404, Q's answers one row | 1 row, from Q | Q answering 500 instead fails the read with that fault |
| Pairs | New principals holding install-DB read and `%DB_IRISSYS:R`, plus exactly one of `%Admin_OAuth2_Client:U` (CLIENT), `%Admin_OAuth2_Server:U` (SERVER), `%Admin_OAuth2_Registration:U` (REG) or `%Admin_Secure:U` (SECURE) | Each reads its own tabs with rows equal to `_SYSTEM`'s. Every other tab answers 403 `AUTH.NOPRIVILEGE` naming that tab's first pair. The area verdict names the first area pair the principal lacks. | — |
| No system DB read | OAUTHNODB: install-DB read and `%Admin_OAuth2_Client:U` | The Descriptions and Clients reads and entries are refused naming `%DB_IRISSYS:READ` | Never 500 |
| Tool | `Screen.Tool.Read.View` per tool at cap N | Returns `fields,rows,truncated` only. Rows equal the first N of `ApplyView` over the route's rows. | — |
| Corpora | `TabCorpus`, `ReadSourceCorpus`, `ClassicLinkCorpus` | Every case receives its declared sentence in both engines | — |

</intent-contract>

## Code Map

- **Design precedent.**
  - `Screen/Descriptor/WalletSecretList.cls` and `X509CredentialList.cls` show the shape of a Security descriptor.
  - Spec 6.3's Code Map is the roster checklist.
  - `Test/SecurityLists.cls` is the pattern for the new tests, and `Test/ScreenReadRowGet.cls` with `Test/Read/ReadFixture.cls` is the pattern for faked-port tests.
- **Vendor endpoints.** These classes are hidden: read them with `iris_doc_get` in `%SYS` on `ocupilot-slot-b`. All five are inventoried synchronously at `Test/AdminInventory.cls:86-91`.
  - `Security.OAuth2.Client.ServerDefinition`: `ResourcesOR` is `%Admin_OAuth2_Client`. LIST keys are `ID, IssuerEndpoint, ClientCount, ResourceCount`.
  - `Security.OAuth2.Client.ClientConfiguration`: LIST **requires** `serverId` through `GetRequiredQueryParam` (400 without it). Keys are `ApplicationName, ClientType, DefaultScope`.
  - `Security.OAuth2.ResourceServer`: `ResourcesOR` is `%Admin_Secure`. Keys are `Name, ServerDefinition`, where `ServerDefinition` is the issuer URL.
  - `Security.OAuth2.Server`: `ResourcesOR` is `%Admin_OAuth2_Server`. It has no LIST.
    - GET answers `IssuerEndpoint` (a URL), `SupportedScopes` (an array of objects, which renders empty), `SigningAlgorithm`, `EncryptionAlgorithm`, `KeyAlgorithm`, `ServerCredentials` and `Metadata`.
    - `Metadata` comes from `OAuth2.Server.Metadata`, public discovery metadata whose `scopes_supported` and `grant_types_supported` are `%List` properties (`irissys/OAuth2/Server/Metadata.cls:60,82`). It answers them as arrays (inference).
    - Unconfigured, GET answers 404, as it does on slot B.
  - `Security.OAuth2.ServerClients`: `ResourcesOR` is `%Admin_OAuth2_Registration`. Keys are `Name, ClientId, ClientType, RedirectURL, Description`, with `RedirectURL` an array.
  - Secret risk: GET on client configurations and on server clients returns `Metadata` unmasked, which can carry `client_secret` and `registration_access_token` (`irissys/OAuth2/Metadata.cls:16`). No LIST row carries a secret.
- **Classic editors** are under `/csp/sys/sec/` (`irissys/%CSP/UI/Portal/Application.cls:298-303`).
  - The client configuration editor's `Prepare` opens its server from `IssuerEndpointID`, and an empty value becomes `%New()` (`irissys/%CSP/UI/Portal/OAuth2/Client/Configuration.cls:1027-1033`). That is why its link carries three params.
  - The list pages' `doEdit` lines confirm each param: `Client/ServerList.cls:134`, `Client/ConfigurationList.cls:137`, `ResourceServer/ConfigurationList.cls:231`, `Server/ClientList.cls:131`.
- **Create APIs (for `OAuthProbe`):**
  - `irissys/OAuth2/ServerDefinition.cls:1131`. Metadata needs `authorization_endpoint` and `token_endpoint`.
  - `Client.cls:1356`. Needs ClientType, SSLConfiguration, ServerDefinition and a redirect host. Saving creates or enables `/csp/sys/oauth2`.
  - `ResourceServer.cls:452`. Needs ServerDefinition and Audiences.
  - `Server/Configuration.cls:1052`. Saving creates `/oauth2`. `Delete` (`:340-370`) deletes every server client.
  - `Server/Client.cls:862`. A non-`resource` client needs the configuration.
- **Stock roles (observed on slot B):** `%Manager` and `%SecurityAdministrator` hold all three `%Admin_OAuth2_*` resources.
- **Grammar.**
  - `Screen/Registry.cls`: `:288` `DECLARATIONKEYS`; `:617` `ReadProblem` (`:647` source keys, `:659` the `LIST` rule); `:1312` `ClassicLinkProblem`; `:1372` `ClassicHrefProblem`; `:263-268` the roster route check in `Validate`.
  - `ui/tools/screen-mirror.mjs`: `:378` `DECLARATION_KEYS`; `:489`/`:522` `readProblem`; `:1092` `buildMirror`; types `:1277` `ClassicLinkExemption`, `:1316` `ReadSource`, `:1449` `ScreenDeclaration`.
  - `ui/tools/classic-links.mjs`: `:102` `classicLinkProblem`; `:332-346` report.
  - Corpus runners: `screen-mirror.test.mjs:393` (RowGetCorpus pattern); `Test/ReadTool.cls` corpus tests; `Test/Descriptor.cls:788`; `classic-links.test.mjs:152`.
- **Read:** `Screen/Read.cls`: `:48` `READTYPE`; `:171-173` type refusal; `:202-213` admin invoke; `:215` the array check; `DetailRow` `:439`; `Project` and `CopyValue` near `:560`. `Api/ScreenRead.cls:48` and `Screen/Tool/*` need no change: they key off `toolIdentifier` and `Read()`.
- **Client:**
  - `shell/screen-outlet.ts:49-56` `ARCHETYPE_PAGES` (a built `detail` needs an entry or `ng build` fails).
  - `shell/list-page.ts` resolves its screen from the URL, so it renders embedded.
  - `shell/data-table.ts`: `:238` anchor, `:404-431` `linkTarget`, `:711` `onLinkClick`.
  - `core/table-model.ts:68` `cellView`; `core/screen-read.ts:64` `textOf`.
  - `core/navigation.ts`: `:216` `childListFor`, `:226` `parentListFor`, `:359` `screenForUrl`.
  - `shell/side-bar.ts:151`; `shell/locator-bar.ts:220`.
  - `core/refresh.ts:236`, `:609-616` (entity types include the secondaries).
- **Area:** `Screen/Area.cls:100` and its doc `:63-72`. `Test/Descriptor.cls:1067` is the pin.
- **Rosters after 6.3:**
  - `Test/ReadTool.cls:93-94,100` (17 tools) and `:312` (criteria 3).
  - `screen-mirror.test.mjs:455` (15 reads).
  - `navigation.test.mjs:122-145,251`.
  - `Test/Wire.cls:576-577`.
  - `navigation-wire.test.mjs:38,167-214,274-279` and `rail-wire.spec.ts:37,166-213`.
  - `Test/WireSecurityRead.cls` pins `:490,516,544,643,662`.
  - `Install/Smoke.cls:46-94,515-520,546` (13 checks; each expects exactly one row unless skipped).
  - `Test/Smoke.cls:490-553,591`.
  - `Test/ScreenRead.cls:179-244` (each admin LIST needs one or more live rows).
  - `classic-links.test.mjs:437` pins 0 honored and names 6.4.
- **UX:**
  - EXPERIENCE.md: `:144-146` (IA rows), `:168` (side-bar order), `:393` (tabs), `:563`/`:573` (detail archetype), `:603` (new tab), `:353` (last Fixed strings row).
  - `strings.ts:701` (last key). `strings.test.mjs:321` (band 150-300, about 288 used).
- **Browser:**
  - `ui/browser/security.browser-spec.mjs` (`:107` guard and principal, `:236-240` side-bar pin).
  - `iris-session.mjs`.
  - `rest-apis.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/tools/classic-links.mjs` -- make these grammar changes in both engines with identical sentences:
  - add `tab` to the declaration keys, with `TabProblem`, and the roster `TabGroupProblem`, which `Validate` calls after its route check
  - add the `GET` type and `forEach` to `ReadProblem`
  - add `rowLink` to `ClassicLinkProblem`
  - add the generated types `TabDeclaration`, `ReadForEach`, `ClassicRowLink`, `'LIST' | 'GET'`

  Every rule is in Boundaries. One grammar, two engines.
- [ ] `src/OcuPilot/Test/TabCorpus.cls`, `ReadSourceCorpus.cls` (new), `ClassicLinkCorpus.cls` -- write cases covering every Boundaries rule: sound, each refusal, and an unknown key. Run them from `Test/ReadTool.cls`, `Test/Descriptor.cls`, `screen-mirror.test.mjs` and `classic-links.test.mjs`, with a roster case for `TabGroupProblem` in both.
- [ ] `src/OcuPilot/Screen/Read.cls` -- `Execute` handles `GET` and `forEach`, and `CopyValue` resolves member fields (Boundaries). Update the class doc.
- [ ] `src/OcuPilot/Screen/Descriptor/Base.cls` -- name `tab` in the declared-fields doc.
- [ ] `src/OcuPilot/Screen/Descriptor/OAuth{ServerDescription,Client,ResourceServer,Server,ServerClient}Tab.cls` (new) -- the declarations below.
  - `read.fields` are the Matrix's.
  - `filter` is every `name`, `identifier` and `text` column's field.
  - `sort.fields` are the column fields, with the default the `name` column, ascending.

  | Class | route · pos · tool (`security.<id>`) · entity + secondaries | first pair | source | columns (field:kind:labelKey) | `tab` pos · labelKey · emptyStateKey | classicPage · editor href · rowLink params |
  | --- | --- | --- | --- | --- | --- | --- |
  | ServerDescription | `security/oauth` · 5 · `oauthserverdescriptions` · `oauth2-server-definition` + `oauth2-client-configuration`, `oauth2-resource-server`; labelKey `oauthLabel`; aliases `["oauth"]` | `%Admin_OAuth2_Client` | `Security.OAuth2.Client.ServerDefinition` LIST | IssuerEndpoint:name:x509ColumnIssuer · ClientCount:number:oauthTabClients · ResourceCount:number:oauthTabResourceServers | 1 · `oauthTabServerDescriptions` · `oauthServerDescriptionsEmpty` | `%CSP.UI.Portal.OAuth2.Client.ServerList` · `Client.ServerConfiguration.zen` · PID←ID |
  | Client | `security/oauth/clients` · 0 · `oauthclients` · `oauth2-client-configuration` + `oauth2-server-definition` | same | `Security.OAuth2.Client.ClientConfiguration` LIST, `forEach {endpoint: Security.OAuth2.Client.ServerDefinition, key: ID, param: serverId, fields: [ServerDefinitionID←ID, IssuerEndpoint←IssuerEndpoint]}` | ApplicationName:name:tableColumnName · IssuerEndpoint:text:x509ColumnIssuer · ClientType:text:oauthColumnClientType · DefaultScope:text:oauthColumnDefaultScope | 2 · `oauthTabClients` · `oauthClientsEmpty` | `…Client.ConfigurationList` · `Client.Configuration.zen` · PID←ApplicationName, IssuerEndpointID←ServerDefinitionID, IssuerEndpoint←IssuerEndpoint |
  | ResourceServer | `security/oauth/resource-servers` · 0 · `oauthresourceservers` · `oauth2-resource-server` + `oauth2-server-definition` | `%Admin_Secure` | `Security.OAuth2.ResourceServer` LIST | Name:name:tableColumnName · ServerDefinition:text:x509ColumnIssuer | 3 · `oauthTabResourceServers` · `oauthResourceServersEmpty` | `…ResourceServer.ConfigurationList` · `ResourceServer.Configuration.zen` · PID←Name |
  | Server | `security/oauth/server` · 0 · `oauthserver` · `oauth2-server` | `%Admin_OAuth2_Server` | `Security.OAuth2.Server` GET | IssuerEndpoint:name:x509ColumnIssuer · Metadata.scopes_supported:text:oauthColumnScopes · Metadata.grant_types_supported:text:oauthColumnGrantTypes · SigningAlgorithm:text:oauthColumnSigningAlgorithm · EncryptionAlgorithm:text:oauthColumnEncryptionAlgorithm · KeyAlgorithm:text:oauthColumnKeyAlgorithm · ServerCredentials:text:oauthColumnServerCredentials | 4 · `oauthTabServer` · `oauthServerEmpty` | `…Server.Configuration` · `Server.Configuration.zen` · `[]` |
  | ServerClient | `security/oauth/server-clients` · 0 · `oauthserverclients` · `oauth2-server-client` + `oauth2-server` | `%Admin_OAuth2_Registration` | `Security.OAuth2.ServerClients` LIST | Name:name:tableColumnName · ClientId:identifier:oauthColumnClientId · ClientType:text:oauthColumnClientType · RedirectURL:text:oauthColumnRedirectUrls · Description:text:tableColumnDescription | 5 · `oauthTabServerClients` · `oauthServerClientsEmpty` | `…Server.ClientList` · `Server.Client.zen` · ClientId←ClientId |

  Members 2-5 take their tab labelKey as `labelKey`, and every `tab.group` is `security/oauth`. Each editor href is `/csp/sys/sec/%25CSP.UI.Portal.OAuth2.<page>`. Each classicPage is `%CSP.UI.Portal.OAuth2.<…>`.
- [ ] `src/OcuPilot/Screen/Area.cls`, `src/OcuPilot/Test/Descriptor.cls:1067` -- append the three OAuth pairs to `security`, extend its doc paragraph with the cost (Design Notes), and update the pin.
- [ ] `ui/src/app/core/navigation.ts`, `core/table-model.ts`, `shell/detail-page.ts` (new), `shell/screen-outlet.ts`, `shell/data-table.ts`, `shell/side-bar.ts`, `shell/locator-bar.ts` -- make these client changes, each per Boundaries:
  - `tabMembersFor` and `tabGroupFor` in `navigation.ts`, and `classicRowHref` in `table-model.ts`
  - `DetailPage`, registered as `ARCHETYPE_PAGES.detail`
  - the `rowLink` name-cell anchor first in the `linkTarget` chain, with `aria-description` `classicRowLinkDescription` naming `label`
  - the current side-bar entry and the locator's group route

  Pin them in `navigation.test.mjs`, `table-model.test.mjs`, `detail-page.spec.ts`, `data-table.spec.ts`, `side-bar.spec.ts` and `locator-bar.spec.ts`.
- [ ] `ui/tools/refresh.test.mjs` -- bound to the generated `security/oauth` declaration, a bus event for `oauth2-client-configuration` or `oauth2-resource-server` re-reads, and one for `oauth2-server-client` does not (AC3).
- [ ] EXPERIENCE.md, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- append rows `:354-356` in 6.3's style. Each key is commented `EXPERIENCE.md:<line>`.
  - `:354` "OAuth 2.0" · "Client server descriptions" · "Client configurations" · "Resource servers" · "Authorization server" · "Server client descriptions".
  - `:355` "Client type" · "Default scope" · "Scopes" · "Grant types" · "Signing algorithm" · "Encryption algorithm" · "Key algorithm" · "Server credentials" · "Client ID" · "Redirect URLs" · "Opens <page> in the classic portal in a new tab.".
  - `:356` "No client server descriptions on this instance." · "No client configurations on this instance." · "No resource servers on this instance." · "No authorization server is configured on this instance." · "No server client descriptions on this instance.".

  Widen the band's upper bound to 330 with a one-line reason. Regenerate `screens.generated.ts`.
- [ ] `src/OcuPilot/Test/OAuthProbe.cls` (new) -- `Create()` and `Remove()` for the Matrix objects, in `%SYS` by explicit save and restore (AD-16).
  - A pre-existing authorization server configuration is used and never modified or deleted.
  - `Remove` deletes only what `Create` made, and each vendor failure is returned in the status.
- [ ] `src/OcuPilot/Test/OAuthTabs.cls` (new; needs the API app over HTTP, `_SYSTEM`, and the demo's `OcuPilotDemo` SSL configuration; it creates and removes its objects in the before-all and after-all hooks) -- covers these rows, on the `SecurityLists` pattern:
  - each descriptor passes `ReadProblem`, `ClassicLinkProblem` and `TabProblem`
  - the classic page compiles
  - `AreaCoverageProblem` is empty
  - the Matrix rows for Descriptions, Clients, Clients cap, Resource servers, Authorization server, Server clients and Tool
  - every row's keys equal the declared fields, and none is a Never-list secret
- [ ] `src/OcuPilot/Test/ScreenReadSource.cls` (new) -- the Unconfigured and forEach-faults rows through `ReadFixture`, plus one member-field projection case.
- [ ] `src/OcuPilot/Test/WireOAuthRead.cls` (new; principals on the `WireSecurityRead` pattern) -- the Pairs and No-system-DB-read rows, with route and navigation verdicts.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls`, `Test/Wire.cls:576`, `navigation-wire.test.mjs`, `shell/rail-wire.spec.ts` -- every Security screens and area pin gains the five OAuth screens and the new area pairs. Both `LIVE_PAYLOAD` copies equal Wire's string.
- [ ] `src/OcuPilot/Test/ReadTool.cls`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs` -- rosters become 22 tools, 20 shipped reads and criteria 3. The five routes are added, and Security's listed routes become `ssl, x509, ldap, wallet, oauth`.
- [ ] `src/OcuPilot/Test/ScreenRead.cls:179` -- skip `tab` members (`OAuthTabs` holds them).
- [ ] `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls` -- add 5 checks (`oauthdescriptions`, `oauthclients`, `oauthresourceservers`, `oauthserver`, `oauthserverclients`), 18 in all. Each passes on a 200 answer holding 0 or 1 rows. Test/Smoke gets its count and one live-check test.
- [ ] `ui/tools/classic-links.test.mjs:437` -- the honored set is exactly the five OAuth tab files, and the report reads "5 exemption(s) honored (SM-C1)".
- [ ] `ui/browser/oauth.browser-spec.mjs` (new; refuses the live container; needs `OCUPILOT_DEMO`; runs `OAuthProbe.Create`/`Remove` through `iris-session.mjs`; creates a principal) -- the browser ACs.

**Acceptance Criteria:**

- **AC1.** Given `_SYSTEM`, when the Security area opens, then all of the following hold:
  - the side bar reads SSL/TLS, X.509, LDAP / Kerberos, Wallet, OAuth 2.0
  - OAuth 2.0 opens `security/oauth` with a tab strip reading the five labels in order, the first selected
  - Right arrow then Enter, and a click on each tab, move to that tab's route, which renders its declared headers from exactly one read of its own tool
- **AC2.** Given the probe's authorization server, when its tab renders, then the Issuer, Scopes, Grant types and Signing algorithm cells equal the read's row, Scopes contains `openid`, and the row's keys are exactly the declared fields.
- **AC3.** Given `security/oauth`'s descriptor, when it is declared, then its primary type is `oauth2-server-definition`, it declares `oauth2-client-configuration` and `oauth2-resource-server` as secondaries, and a change event of either secondary type re-reads the bound tab.
- **AC4.** Given the Client configurations tab, when `OcuPilotTestB`'s name cell is activated, then all of the following hold:
  - it is an anchor with `target="_blank"` and `rel="noreferrer"`
  - its href is `/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen?PID=OcuPilotTestB&IssuerEndpointID=<B id>&IssuerEndpoint=<encoded B issuer>`
  - a new browser target opens at that URL while the OcuPilot tab's URL is unchanged
  - `classic-links.mjs` honors exactly the five OAuth descriptors
- **AC5 (gating).** Given a throwaway principal holding install-DB read, `%Admin_Secure:USE` and `%DB_IRISSYS:READ` only, when the shell loads, then all of the following hold:
  - the Security rail item is gated naming `%Admin_Wallet:USE`
  - a deep link to `security/oauth/resource-servers` reads, and its tab strip shows the other four tabs gated with "Requires <pair>" and focusable
  - a deep link to `security/oauth/server-clients` renders "You need %Admin_OAuth2_Registration:USE to open Server client descriptions." with no table and no read
- **Integration.** Given consumer `Screen.Tool.Read.View`, when it reads the five `security.oauth*.read` tools live, then it returns each route's fields and rows narrowed by its cap.

## Spec Change Log

## Review Triage Log

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-27:** only `AdminPort` is used, and all five endpoints are inventoried and synchronous.
- **AD-3 / AD-35:** nothing is written, and no secret is read (Never).
- **AD-5:** five descriptors, grouped by `tab`, several of them declaring more than one entity type.
- **AD-8 / AD-29:** pairs are established on the throwaway by `WireOAuthRead`.
- **AD-11:** entity names render as text.
- **AD-13 / AD-14:** all five types exist in `Kernel/EntityType.cls:28`, with scope `instance`.
- **AD-19:** helpers live in `core/`, and `DetailPage` is OnPush over signals.
- **AD-21 / AD-47:** no path is accepted, and row links are root-relative with percent-encoded values.
- **AD-24 / AD-36:** one capped read per tab, shared by screen and tool.
- **AD-43:** no refresh.
- **AD-44:** each tab names the classic page it replaces.

**Why five descriptors.** One descriptor with five reads would need five tools from one descriptor, and `Screen/Tool/Registry.cls:108-119` with `Api/ScreenRead.cls:48` map one `toolIdentifier` to one read. That is in `Screen/Tool/**`, which is out of bounds. A single union read would share one cap, field set and privilege set across five entity kinds, against AD-24 and AD-36. The ACs also word it per tab: "each tab ... declared as a detail view archetype" and "each declares `classicLinkExemption`". Per-tab pairs and classic pages also keep AD-44's custom-resource union per classic key.

**Spine (lead, spec gate, Rule 20).** Three clarifications, each apply-and-report:

- **AD-5:** "A screen of several tabs is one descriptor per tab, grouped by `tab`; its listed member is the side-bar entry."
- **AD-36:** the source may be a singleton `GET` (404 is no rows); `forEach` is a per-parent list (a child 404 skips that parent, and truncation counts the parent list); a field may be `<object>.<member>`.
- **AD-44:** "the OAuth 2.0 tabs" are one exemption declared by each of the five tab descriptors, so the check reports five honored declarations.

**Choices.**

- **Client configurations are listed instance-wide** with their issuer, rather than per server description. EXPERIENCE `:144` calls the tabs "five lists", and a per-server list would need a server chosen first.
- **Secondaries follow what a tab shows.**
  - Descriptions count clients and resource servers.
  - Clients and resource servers show the issuer.
  - A configuration delete removes every server client (`Configuration.cls:348-356`), so Server clients take `oauth2-server`.
  - The authorization server tab reads its own object only and declares none.
- **Why the probe objects are test-made.** Rows come from `OAuthProbe` on the throwaway, not from a demo fixture. The authorization server is a singleton with no nameable prefix, its save creates the `/oauth2` web application, and a client save enables the vendor's `/csp/sys/oauth2`; a fixture would own neither (AD-25). Removal may leave `/oauth2` on the throwaway (inference). A fresh throwaway holds no OAuth objects (inference, from slot B's zero counts), so smoke passes on an empty answer.
- **Gating cost.**
  - **Security rail.** The area union now gates the rail for a holder of the Secure, IRISSYS and Wallet pairs who lacks any OAuth resource: 6 of 10 built Security screens would serve that caller. `%Manager` and `%SecurityAdministrator` hold all three OAuth resources (observed), so DW-1018's stock-role finding is unchanged. This is a DW-1018 occurrence for the lead.
  - **Side-bar entry.** The OAuth 2.0 entry itself is gated on `%Admin_OAuth2_Client:USE`, so a Registration-only holder reaches Server clients by deep link.

**Ledger inbox:** none owned by this story. DW-1001 and DW-1018 are not re-litigated.

**Integration ACs:** the Integration AC (tool), AC1 (`DetailPage` through the tab helpers), AC4 (`rowLink` through the data table) and the smoke checks.

**Consumes:**

- `AdminPort` (2.1)
- `Screen.Read` and `rowGet` (2.3, 6.3)
- `ListPage` and the data table (2.4)
- navigation and the gate (1.9)
- the refresh framework (1.14)
- `classicLinkExemption` and its check (1.15)
- the area union (6.3)

**Consumed-by:**

- 4.2: tool registry.
- 4.4: screen context.
- 6.7, 6.8, 6.11: the `detail` page.
- 7.3: deletes on the Clients and Server clients tabs.
- 12.4–12.8: the editors take over the name cells.
- 12.9: removes the five exemptions and `rowLink`.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Every OAuth object, principal and mutation these tests create lives on this throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, run `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for:
  - OAuthTabs, ScreenReadSource, WireOAuthRead, WireSecurityRead, Wire
  - ReadTool, ScreenRead, Descriptor, Navigation, SecurityLists, Smoke, AdminPortSync

  Expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the five `oauth*` checks pass, with no failures.
- `cd ui && npm run build && npm test` -- expected: green. `screen-mirror --check` is clean, and `classic-links` reports 5 honored.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `oauth.browser-spec.mjs` and `security.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations (Rule 19).** Record each as `mutation:` once observed, then revert and confirm the tree byte-identical.

- AC1: swap `tab.position` of ResourceServer and Server -> `navigation.test.mjs` tab order red; browser AC1 red after rebuild and redeploy.
- AC2: `Metadata.grant_types_supported` becomes `Metadata.grant_types` -> `OAuthTabs` grant types red; browser AC2 red.
- AC3: drop `oauth2-client-configuration` from `security/oauth`'s secondaries -> `refresh.test.mjs` red.
- AC4: `data-table.ts` ignores `rowLink` -> `data-table.spec.ts` red; browser AC4 red. Remove one tab's exemption -> `classic-links.test.mjs` red.
- AC5: `OAuthServerClientTab` drops `%Admin_OAuth2_Registration:USE` -> `WireOAuthRead` red.
- Integration: `Tool.Read.View` keeps cap-1 rows -> `OAuthTabs` tool test red.
- Matrix: `Execute` fails on a `GET` 404 -> `ScreenReadSource` unconfigured red. `forEach` stops skipping a child 404 -> forEach-faults red. Truncation ignores the held rows -> Clients cap red.
- Grammar: disable each new rule arm in `Registry` and in `screen-mirror.mjs` / `classic-links.mjs` -> its corpus test red in that engine.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
