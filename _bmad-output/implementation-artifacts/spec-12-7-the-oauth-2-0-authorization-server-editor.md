---
title: 'Story 12.7: The OAuth 2.0 authorization server editor'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: 'ce6620536add7ddc131af754d4696d1b17047130'
baseline_commit: 'ce6620536add7ddc131af754d4696d1b17047130'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-6-the-oauth-2-0-resource-server-editor.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Authorization server tab can only show this instance's one authorization server configuration. Its name cell links out to the classic page, so nobody can create, edit or delete the configuration, change its scopes or grant types, set its key password, or rotate its keys in OcuPilot. An agent change to it gives no warning that every registered client depends on it.

**Approach:** Add a tabbed `form-page` editor at `security/oauth/server/edit`, built on `app-form-tabs` and modeled on Story 12.6. It round-trips the singleton `Security.OAuth2.Server` configuration and uses the two fixed write mechanisms:

- Save goes through the write tools (AD-55), and a create uses AD-54.
- Delete and Rotate Keys are the tab's row actions (AD-53).

A new `OAuthAuthorizationServerPort` does four things:

- carries the calls;
- rotates keys through the vendor class, because the admin API has no such request type (a new AD-27 case, Q1);
- reads the registered clients, so an agent proposal names the clients it affects;
- strips nothing secret, because the vendor `GET` answers no secret.

## Boundaries & Constraints

**Always:**

- **Identity.** There is one configuration per instance. Its id is folded to the singleton constant: `EntityRef.IDRULES` gains `oauth2-server:singleton`, which answers `RULESINGLETONID`, as `auditing-configuration` does. The editor route works with or without an id, and it always opens the stored configuration if one exists. The tab's Create, which the command bar draws whatever the row count, opens the same editor, so a create is offered only while no configuration exists.
- **The key password is write-only (AD-3, AD-35, AD-56 i).**
  - `ServerPassword` is masked, never pre-filled, and never appears in a read, a proposal's arguments, a diff, the ledger, screen context, a log line or a status. The vendor `GET` never answers it, and the `PUT` refuses it with 400 (measured).
  - It travels only through `CHANGEPWD` as `{ServerPassword}`.
  - An empty field means "unchanged". The port refuses an empty or missing password, because `{"ServerPassword":""}` clears the stored one (measured).
  - The vendor writes it in plain text into its audit rows, which is Q2's new AD-35 declaration.
- **Save sends the complete property set (AD-4, amended at this plan).** It reads fresh, applies the diff, and sends every template field:
  - `SupportedScopes` and `CustomizationRoles`, whole, as edited.
  - `Metadata`, as the fresh read's whole object with the editor's members applied: `grant_types_supported`, `frontchannel_logout_supported`, `frontchannel_logout_session_supported`, `service_documentation`, `op_policy_uri` and `op_tos_uri`.
  - A create composes every template field (the vendor refuses a partial create with 400).
- **Create is a `PUT` upsert (measured: 201).** AD-54's absence fingerprint is load-bearing. The Save's create path refuses a present configuration (`OAUTH.SERVERCONFIG.TAKEN`) before any port write.
- **Affected clients (AC3).** The port's `GET` adds two members, both fingerprinted, and removes both from any `PUT` body, as `OAuthServerPort.ROWFIELDS` does:
  - `Clients`: `[{ClientId, Name}]`, read through `Security.OAuth2.ServerClients` `LIST` under that endpoint's own gate (`%Admin_OAuth2_Registration`);
  - `ClientsHidden`: true when that gate refuses the caller.

  For type `oauth2-server`, `Prohibited.WeakensByEffect` names `OAUTH.SERVERCLIENTS` on update, setpassword, rotatekeys and delete when `Clients` is non-empty or `ClientsHidden` is true. The proposal is then minted destructive.
  - The delete tool's `Consequence` answers `OAUTH.SERVERCLIENTSDELETED` instead.
  - The card carries a `Clients` row: every `Name (ClientId)`, with `after` equal to `before`, or `""` for a delete. No row is added when the list is hidden.
  - A client registered or removed between mint and confirm refuses the confirm.
  - No tool declares `%Admin_OAuth2_Registration` (Q3).
- **Form rules** are enforced identically by each tool's `ArgumentProblem` and by the Save route, and written once on the server as `detail.violations[]` (AD-39). They cover every value the vendor refuses with 500, and every value it silently accepts that the classic page cannot enter (measured):
  - `IssuerEndpoint`: required. It must be `https://host[:port][/prefix]` with no query or fragment. The vendor keeps `https` whatever is sent (`UseSSL` is internal), and stores garbage for a bad URL.
  - Intervals: integers. Access token, authorization code and refresh token are at least 1; session and client secret are at least 0.
  - `SupportedScopes`: at least one. Each scope is non-empty with no whitespace or control character, and no two are the same.
  - `DefaultScope`: space-separated, with no control character.
  - `Description`: at most 1024 characters.
  - `ReturnRefreshToken`: one of `""`, `a`, `c`, `f`.
  - The six top-level flags and the two front-channel `Metadata` members are booleans.
  - `Metadata`:
    - `grant_types_supported` names at least one of `authorization_code`, `implicit`, `password`, `client_credentials`, `jwt_authorization`, and nothing outside those plus `refresh_token`. `refresh_token` is always sent, as the vendor's own setter does.
    - The three URLs are empty or absolute `http(s)`.
  - `SigningAlgorithm`, `EncryptionAlgorithm` and `KeyAlgorithm` are empty or from the vendor's value lists (`Configuration.cls` :201-213). Encryption and key algorithms are both empty or both set.
  - `CustomizationNamespace` must be in `Kernel/Shell/Namespaces`.
  - The five customization classes are required, at most 256 characters, and compiled in that namespace (a `%Dictionary.CompiledClass` read, as 12.6's `AuthenticatorUsable`).
  - `CustomizationRoles` needs at least one role. Each role, like `SSLConfiguration` and `ServerCredentials` (when non-empty), must be either the stored value or a name the Roles, SSL/TLS or X.509 list's own declared read answers the caller (`OAuthServerRules.ReadableNames`, AD-5). A caller who cannot read the list can keep stored values only (the classic page's own behavior, measured: all three vendor list queries refuse the least-privileged principal).
  - A vendor 500 on a `PUT` that changes `ServerCredentials` is `OAUTH.SERVERCREDENTIALS.KEY`. The vendor refuses a credential without a private key (#8885), and a key needing a password not yet stored is refused the same way (inference). Any other vendor 500 is `OAUTH.SERVERVALIDATION`, with the raw text in the log only.
- **Rotate Keys** (AD-51 action write, bodyless; Q1) runs `OAuth2.Server.Configuration.Open(.sc).RotateKeys()` in `%SYS` (AD-16).
  - The port first repeats the endpoint's `%Admin_OAuth2_Server:USE` gate.
  - It refuses when the stored `ServerCredentials` is non-empty (`OAUTH.SERVERKEYS.CREDENTIALS`). With credentials set, the next save rebuilds the key set from them, and the classic page hides the button.
  - An absent configuration answers 404.
  - The result is reported as an outcome line on the screen and as an applied write to the agent (measured: the public key set went from 11 keys to 22).
- **Delete** removes the configuration, and the vendor also deletes every server client and every session (measured). The typed-name dialog asks for the stored issuer endpoint, and its consequence line says so.
- **Save order.** On an update, the configuration `PUT` is sent only when the diff is non-empty. The password follows, and only when one was supplied. A password failing after a saved configuration answers `passwordRefused` `{reason}`.
- **Privileges.** Every tool, route and port call requires the tab's own pair set, `%Admin_OAuth2_Server:USE` + `%DB_IRISSYS:READ` (AD-8, AD-29).
  - Measured with a principal holding only those two: `GET`, `PUT`, `CHANGEPWD`, the endpoint's `DELETE` and the vendor `RotateKeys` all succeeded.
  - The vendor endpoint's `ResourcesOR()` is `%Admin_OAuth2_Server`. Screen writes emit no marker (AD-53), and agent confirms do (AD-15).
- **No self-protection arm.** OcuPilot's sign-in is the web application's own JWT (AD-28). It answered 200 with no configuration, after a create and a key rotation, and after a delete (measured).
- **Change events.** Every write publishes `(oauth2-server, instance, <singleton id>)`.
- **UI.** Use tokens only, and render correctly in the dark theme. The editor gets no DW-1337 allowance. Write non-ASCII in code as `\u` escapes.

**Never:**

- No third write mechanism.
- No declared pair beyond the tab's set.
- No suggested prompts, because Story 11.3's key is absent.
- No change to the server-client tab's link (Stories 12.8 and 12.9).
- No change to the 12.4, 12.5 or 12.6 editors.
- No OAuth-writing test on `ocupilot-slot-b`.
- No internet dependency in any test.
- No second tab component.
- No reading of `PrivateJWKS`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | No configuration. The form's defaults (the classic page's), one role, an issuer, two scopes | 201. The editor reopens reading "Saved", the tab shows the row, and `GET` returns every value | None |
| Create, present | A configuration appears after the form opened | 422 `OAUTH.SERVERCONFIG.TAKEN`; nothing written | Before any port write |
| Edit, partial | One scope removed, one added, description and `AccessTokenInterval` changed | `GET` shows exactly that. Every other field and `Metadata` member is unchanged | None |
| Edit, bad value | Empty scopes, `http://` issuer, an unknown namespace, class or role, interval 0, grant types none | 422 on the named field; nothing sent | Form rule |
| Password | Entered and saved | Stored (length > 0). No read, context, ledger row or log line carries it; an empty field sends nothing | Refusal after a save → "Saved. The key password was not stored: {reason}" |
| Rotate Keys | Stored configuration with no credentials | Key count grows. "Rotated the authorization server's keys." | Credentials set → named refusal; absent → 404 |
| Agent change with clients | One probe server client registered | Destructive card with `OAUTH.SERVERCLIENTS` and a `Clients` row naming it | A client registered after the mint → the confirm is refused |
| Agent change, clients hidden | Caller lacks `%Admin_OAuth2_Registration:USE` | Destructive card with the sentence and no `Clients` row | None |
| Delete | From the editor or the row menu, issuer typed | The configuration and its clients are gone | Existing typed-name dialog |
| No privilege | Caller lacks `%Admin_OAuth2_Server:USE` | 403 naming the pair on the form read, both Save routes, both row actions and the mint | Before any port call |

</intent-contract>

## Code Map

**Vendor (measured on `ocupilot-b-ci`; `%Api.Admin.*` is hidden, so read it with `GetTextAsString` in `%SYS`).**

- `%Api.Admin.Endpoints.Security.OAuth2.Server`:
  - `ResourcesOR` is `%Admin_OAuth2_Server`, or `%Admin_OAuth2_Registration` for `REVOKE`.
  - Types: `GET` (404 when absent), `PUT`, `DELETE` (calls `Configuration.Delete()`), `REVOKE` (10) and `CHANGEPWD` (11, strict `{ServerPassword}`).
  - `RunPut` sets only the keys the body defines. It sets the issuer's host, port and prefix, but never the scheme. `SupportedScopes` goes through a new array and `Metadata` through `ImportJSON`.
  - `ValidateRequest` sets `AllRequired` when absent. `ObjToJson` answers the template keys, which are `FieldLists.cls` :338-372.
- `Security.OAuth2.ServerClients` `LIST` → `[{Name, ClientId, ClientType, RedirectURL, Description}]`, gated `%Admin_OAuth2_Registration` (403 for the probe).
- `irissys/OAuth2/Server/Configuration.cls`:
  - properties :20-226;
  - `Delete` :340, which cascades clients and sessions;
  - `RotateKeys` :567;
  - `%OnAddToSaveSet` :595, which builds the key set from credentials plus `ServerPassword`;
  - `%OnAfterSave` :713, which creates `/oauth2` when absent (present on the throwaway already);
  - the audit generator :934-993. `ServerPassword` is not masked; `PublicJWKS` and `PrivateJWKS` are.
- The classic page `irissys/%CSP/UI/Portal/OAuth2/Server/Configuration.cls`:
  - tabs General, Scopes, Intervals, JWT Settings, Customization :93-216;
  - new-configuration defaults :738-760;
  - `validatePage` :340;
  - Rotate shown only when `jwksAvailable` :753/:957.

**Server models (current anchors):**

- `Port/OAuthResourceServerPort.cls`:
  - `Invoke` :103, with the gate at :108 through `RefusedPair` :522, `GATEPAIRS` :97 and `HoldsPair`;
  - `DELEGATEDTYPES` :41, `COMPOSEDTYPES` :75;
  - `AuthenticatorUsable` :202, `Violation` :544.
- `Port/OAuthServerPort.cls` for the AD-27 shape and the added GET members:
  - `ROWFIELDS` :41, `GATERESOURCE` :56;
  - the gate repeated at :98-101, then `GateRefusal` :311;
  - `RefreshKeySet` :344 (`%SYS` save and restore).
- `Area/Security/OAuthResourceServerRules.cls`:
  - `Validate` :114, `Namespaces` :325, `Expand` :372;
  - `HandleForm` :440, `Present` :510, `Gate` :594.
- `Area/Security/OAuthServerRules.cls` `ReadableNames` :407.
- `Area/Security/OAuthResourceServerSave.cls`:
  - `HandleCreate` :78, `HandleUpdate` :120;
  - `StoreSecret` :298, `Answer` :434, `StrayKey` :491.
- `Screen/Tool/Write.cls` parameters :38-201:
  - `CREATES` :141, `SECRETBODY` :191, `STATEFIELD` :75;
  - `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `READANSWERS` :170;
  - `IdArgument`/`IdParam` :490/:497, `StateDiff` :453.

  `Consequence(payload, privileged, effect)` is optional (`Kernel/Proposal/Mint.cls:666`). With none, the effect is the code. A merge payload is the whole fresh read (`Mint.cls:467`), fingerprinted at :286.
- The singleton models:
  - `Screen/Tool/AuditingUpdate.cls` :16-22 and :101-110, which sends the literal singleton id;
  - `Kernel/EntityRef.cls` `IDRULES` :59 and `RULESINGLETONID` :111.
- `Screen/Tool/OAuthClientRotateKeys.cls`:
  - `SCREENACTIONS` :21, `WRITETYPE` :25;
  - the subject :31-35, `STATEFIELD` :39;
  - `ArgumentProblem` :77, `StateDiff` :100.
- `Screen/Tool/OAuthResourceServerAddMapping.cls` `MergeUpdate`/`MappingRows` :97-137, which adds a card row, and `Consequence` :168.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250, the `TYPEOAUTH*` and `EFFECT*` constants :275-297;
  - the chain :742/:753, dispatch :845-852;
  - `PermittedChangeFields` :549 / `PermittedCreateFields` :658, `OAuthResourceServerFields` :1539;
  - `WeakensByEffect` :1091, whose resource-server arm is :1104-1110.
- `Port/AuditPort.cls`:
  - `VENDORSECRETS` :116 (format `Event words=key[:key];...`), whose source `%System/%Security/OAuth2` matched these rows (measured);
  - `SecretKeys` :163, which uses the longest whole-word prefix;
  - `MaskedEventData` :186, which already masks both `<key> modified:` blocks and `<key>:` lines.

  Pinned by `Test/AuditVendorSecrets.cls` :52-62 and :115-128 (the "Modify OAuth2 Server Client" row must stay unchanged).

**Shared server files (own lines only):**

- `Port/AdminPort.cls` `MUTATINGTYPES` :298, `BODYLESSTYPES` :314.
- `Api/Router.cls`: 12.6 routes :172-174, `</Routes>` :175, wrappers :573-592.
- `Api/Error.cls`: `ReasonForOAuthResourceServer` ends `Quit ""` :2694, `OAuthResourceServerViolationCodes` :2699.
- `Screen/Tool/Classification.cls`: 12.6 entries end ~:586. `FieldLists.cls` already derives `Security.OAuth2.Server`.
- `ReturnRefreshToken` fails the build unless secret: `ui/tools/field-lists.mjs` :268-270, `ui/tools/credential-pattern.mjs`, `Kernel/Audit/Log.cls`, `ui/tools/field-lists.test.mjs` :264.

**Client (current anchors):**

- `areas/security/oauth-resource-server-form.page.ts`:
  - `app-form-tabs` :184-330, list editor :190-219;
  - `tabs` :456, `status` :674;
  - `onSave` :778, `confirmDelete` via `handler.sendFor` :813-826;
  - `focusField` :829, `tabToOpen` :893.
- `oauth-resource-server-form.store.ts`:
  - field→tab map :59-78, order :81;
  - `reset` :465, `open` :500, `save` :624.
- `shell/form-tabs.ts` :18/:27/:86; `core/form-tabs.ts` :30/:45/:60.
- Registrations:
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :107-132;
  - `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :44-64 and `DESTRUCTIVE_CONSEQUENCES` :195-212;
  - `areas/security/oauth-actions.ts` :8-53;
  - `app.ts` inject :272 and sign-out reset :568, pinned by `app.spec.ts` :1073-1075/:1161-1163;
  - `core/navigation.ts` `createFormFor` :188.
- Singleton rendering:
  - `shell/data-table.ts` :593-632. With the exemption gone, the name cell links `security/oauth/server/edit/<issuer>`, which folds to the singleton.
  - `shell/command-bar.ts` :163-171 draws Create whenever it is declared. The editor then opens the stored configuration.
- `core/proposal-view.ts` `CONSEQUENCE_*` :121-151 and `consequenceSentence` :157-168, pinned in `shell/proposal-card.spec.ts` :767-790.
- `core/strings.ts`: the 12.6 block ends :2428, and `} as const` is :2430. Reuse:
  - `oauthTabServer`, `oauthServerFieldIssuer`, `oauthClientSecretHint`, `oauthClientRotateKeys`, `oauthClientSectionJwt`;
  - `oauthColumn{Scopes,GrantTypes,DefaultScope,SigningAlgorithm,EncryptionAlgorithm,KeyAlgorithm,ServerCredentials}`;
  - `processDetailsGroupGeneral`, `tableColumnDescription`, `formSaved`.

  EXPERIENCE.md's last Fixed-strings row is :519, and `_components.scss` ends :6207 (the 12.6 block starts :6137).
- `ui/browser/structural-baseline.json` has 12.6's three shell-chrome rows at :1268-1300 (DW-1583/DW-1584).
- `security/oauth/server` classic rows:
  - `browser/oauth-resource-server-editor.browser-spec.mjs` :69, `oauth-client-editor` :66 and `oauth-server-description-editor` :55;
  - `browser/oauth.browser-spec.mjs` :80-92 and the honored set :357;
  - `tools/classic-links.test.mjs` :449 and the counts :472-473;
  - `tools/navigation.test.mjs` :174-184 and `navigation-wire.test.mjs` :309/:457.
- Budget: `ui/angular.json` :54-55, pinned at `ui/tools/angular-json.test.mjs` :377-378.

**Rosters:**

- `Test/PortGate.cls:28`, `Test/PortFixture.cls:21`, `Test/ToolRoundTrip.cls:37`
- `Test/SurfaceCoverage.cls` :75-82 and :150-167, `Test/EndpointCoverage.cls` :148-157
- `Test/Prohibited.cls` :218 and :398
- `Test/OAuthTabs.cls` :30, :84, :186-189 and :284-302
- `Test/WireOAuthRead.cls` :273-342 and `Test/WireSecurityRead.cls` :787-1081 (`ScreensFor` literals)
- `Test/ToolWrite.cls` :1169-1275: every `MUTATINGTYPES` pair is reached by a tool, and body status equals `SendsBody`
- `scripts/ci-throwaway.sh` :201-205

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/OAuthAuthorizationServerPort.cls` (new; extends `AdminPort`; `GATEPAIRS` the tab's two; add it to `Test/PortGate` `ROSTER`).
  - `GET` adds `Clients` and `ClientsHidden`.
  - `PUT`:
    - removes those two members;
    - checks each customization class with a `ClassUsable` (%Dictionary) read;
    - maps a vendor 500 to `OAUTH.SERVERCREDENTIALS.KEY` when `ServerCredentials` changed, and otherwise to `OAUTH.SERVERVALIDATION`.
  - `CHANGEPWD` refuses an empty or missing password (`OAUTH.SERVERNOPASSWORD`).
  - `ROTATEKEYS` (in `COMPOSEDTYPES`): the gate, then a `GET`. It answers 409 `OAUTH.SERVERKEYS.CREDENTIALS` when credentials are set, and otherwise calls the vendor `RotateKeys` in `%SYS`. A failure is a 422 plus `LogFault`.
  - `AdminPort`, one line each (contended):
    - `MUTATINGTYPES`: `Security.OAuth2.Server/PUT,/DELETE,/CHANGEPWD,/ROTATEKEYS`;
    - `BODYLESSTYPES`: `/DELETE,/ROTATEKEYS`.
- `src/OcuPilot/Screen/Tool/OAuthAuthorizationServer{Create,Update,SetPassword,RotateKeys,Delete}.cls` (new).
  - Common to all:
    - `DESCRIPTORCLASS` is `OAuthServerTab`, `PORTCLASS` is the new port, and `WRITERESOURCE` is `%Admin_OAuth2_Server:USE`.
    - Names are `security.oauthserver.<verb>`, and the id is the singleton literal, as in `AuditingUpdate`.
    - Every `DESCRIPTION` says nothing changes until the user confirms.
  - Per tool:
    - Create: `CREATES` 1, `READTYPE` GET, `WRITETYPE` PUT, `CHANGEACTION` created.
    - Update: a GET/PUT merge. `MergeUpdate` appends the `Clients` row.
    - SetPassword: `WRITETYPE` CHANGEPWD, `SENDSBODY` 0, `SECRETBODY` `ServerPassword`, subject `IssuerEndpoint,ServerCredentials,Clients,ClientsHidden`, precondition `IssuerEndpoint`.
    - RotateKeys: `SCREENACTIONS` rotatekeys, `WRITETYPE` ROTATEKEYS, subject `ServerCredentials,Clients,ClientsHidden`, precondition `ServerCredentials`, `STATEFIELD` `Keys`. `ArgumentProblem` refuses stored credentials.
    - Delete: `SCREENACTIONS` delete, `DESTRUCTIVE` 1, subject `IssuerEndpoint,Clients,ClientsHidden`, precondition `IssuerEndpoint`, `CHANGEACTION` deleted. `Consequence` maps the effect to `OAUTH.SERVERCLIENTSDELETED`.
  - Action tools' `StateDiff` carries the `Clients` row.
- `src/OcuPilot/Screen/Tool/Classification.cls` (after 12.6's entries): create and update are ordinary, with `Metadata` opaque; setpassword has `ServerPassword` as authored secret. Then regenerate `ToolFields.cls`.
- The credential-pattern exception `ReturnRefreshToken` (Conventions › Secrets, amended at this plan) goes into both copies:
  - `ui/tools/credential-pattern.mjs` + `field-lists.mjs`;
  - `Kernel/Audit/Log.cls`.

  Keep the pin test that holds them equal. `field-lists.test.mjs` :264 moves `ReturnRefreshToken` to the "is not" list.
- `src/OcuPilot/Kernel/EntityRef.cls` `IDRULES`: add `oauth2-server:singleton`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (own lines):
  - `TYPEOAUTHAUTHSERVER`, added to `COVEREDTYPES`, the chain and the dispatch;
  - `OAuthAuthorizationServerFields()`, the 29 template fields, returned by both Permitted methods;
  - `EFFECTSERVERCLIENTS` and `EFFECTSERVERCLIENTSDELETED`;
  - a `WeakensByEffect` arm.
- `src/OcuPilot/Screen/Descriptor/OAuthServerForm.cls` (new):
  - Route `security/oauth/server/edit`, `form-page`, position 0.
  - The tab's pairs; `oauth2-server`, `instance`, `id single`.
  - `context.secretFields [ServerPassword]`, `secretArguments []`.
  - `classicPage` `%CSP.UI.Portal.OAuth2.Server.Configuration`, no exemption, `toolIdentifier` `security.oauthserverform`.
- `src/OcuPilot/Screen/Descriptor/OAuthServerTab.cls`:
  - `exempt: false`, `primaryAction create`, `rowActions [delete, rotatekeys]`, `secretArguments [ServerPassword]`.
  - Table `emptyNextKey ""`, `emptyAgentKey oauthAuthServerEmptyAgent`.
  - Rewrite the doc comment's link and action paragraphs, then regenerate `screens.generated.ts`.
- `src/OcuPilot/Area/Security/OAuthAuthorizationServer{Rules,Save}.cls` (new, modeled on 12.6's pair).
  - The form read, `GET /oauth/authorization-server/form`, answers:
    - `requiredFields`, `rules`;
    - `namespaces`, `roles`, `sslConfigurations`, `credentials` (`ReadableNames` on `RoleList` `Name`, `SslConfigList` `Name`, `X509CredentialList` `Alias`);
    - `clients` and `clientsHidden`;
    - `definition` when present.
  - The Save body is the changed fields plus `ServerPassword`. Any other key is refused.
  - Every rule is checked before the first write, and each write goes through `Operation.Gate`/`ApplyAt`.
- `src/OcuPilot/Api/Router.cls` (append after :174): `GET /oauth/authorization-server/form`, `PUT /oauth/authorization-server`, `POST /oauth/authorization-server` (the form route first), each with a thin wrapper.
- `src/OcuPilot/Api/Error.cls`: a `ReasonForOAuthAuthorizationServer` chained from :2694's `Quit`, plus `OAuthAuthorizationServerViolationCodes`. Codes:
  - `OAUTH.SERVERCONFIG.TAKEN`, `OAUTH.SERVERISSUER.{REQUIRED,SHAPE}`, `OAUTH.INTERVAL.VALUE`;
  - `OAUTH.SCOPES.{REQUIRED,SHAPE,DUPLICATE}`, `OAUTH.DEFAULTSCOPE.SHAPE`, `OAUTH.SERVERDESCRIPTION.LENGTH`, `OAUTH.RETURNREFRESHTOKEN.VALUE`, `OAUTH.GRANTTYPES.{REQUIRED,VALUE}`, `OAUTH.METADATAURL.SHAPE`;
  - `OAUTH.ALGORITHM.VALUE`, `OAUTH.ENCRYPTION.PAIR`;
  - `OAUTH.CUSTOMIZATIONNAMESPACE.ABSENT`, `OAUTH.CUSTOMIZATIONCLASS.{REQUIRED,ABSENT}`, `OAUTH.CUSTOMIZATIONROLES.{REQUIRED,ABSENT}`, `OAUTH.SSLCONFIGURATION.ABSENT`;
  - `OAUTH.SERVERCREDENTIALS.{ABSENT,KEY}`, `OAUTH.SERVERNOPASSWORD`, `OAUTH.SERVERKEYS.CREDENTIALS`, `OAUTH.SERVERVALIDATION`.

  Reuse `OAUTH.FLAG.VALUE`.
- `src/OcuPilot/Port/AuditPort.cls` `VENDORSECRETS`: append `Create OAuth2 Server=ServerPassword;Modify OAuth2 Server=ServerPassword` once the lead amends AD-35 (Q2). Add a seeded-row test on both reads. `AuditVendorSecrets` :115-128 must stay green.
- `ui/src/app/areas/security/oauth-server-form.{store,page}.ts` (+ specs):
  - Five tabs on `app-form-tabs`, each with its fields (Design Notes).
  - The field→tab map, `tabToOpen`, and `focusField` that switches the tab first.
  - The scopes list with Add and Remove.
  - The unsaved guard, "Saved", a create followed by `replaceUrl`.
  - Rotate Keys, shown only for a stored configuration with no credentials, through `handler.sendFor(OAuthServerTab,'rotatekeys')`, with its outcome line.
  - Delete through `handler.sendFor(OAuthServerTab,'delete')` with the issuer typed.
  - In `app.ts`, inject the store and reset it at sign-out; pin that in `app.spec.ts`.
- `ui/src/app/areas/security/oauth-actions.ts` (the tab's Create), `shell/screen-outlet.ts` (page entry), and `shell/screen-action-handler.ts` (+ spec: the tab in both maps, with the delete consequence).
- `core/proposal-view.ts` + `shell/proposal-card.spec.ts`: two consequence codes and sentences, pinned beside `AUTHENTICATORRESET`.
- `core/strings.ts` (after :2428), EXPERIENCE.md (a row after :519: Story 12.7, FR-44) and `_components.scss` (own `ocu-oauth-server-*` classes after :6207): the Design Notes strings.
- ObjectScript tests (new; each under 500 lines, one class per call, on `ocupilot-b-ci` only). Helper `Test/OAuthAuthorizationServerProbe.cls` has `RemoveAll` (deletes the configuration if present, leaving `/oauth2` as found), `Seed` and `SeedClient`.

  | Class | Covers |
  | --- | --- |
  | `Test/OAuthAuthorizationServerCreate` | declarations and pairs; create through the route; taken; every form rule on both callers; a create taken after the mint refused at confirm |
  | `Test/OAuthAuthorizationServerUpdate` | the complete set; scopes add/remove; grant types; `Metadata` members kept; `ReturnRefreshToken` round-trips; vendor 500s named |
  | `Test/OAuthAuthorizationServerSecret` | stored and never read; empty sends nothing; empty body refused; `passwordRefused`; the audit mask on both reads |
  | `Test/OAuthAuthorizationServerKeys` | rotate grows the key count; refused with credentials or absent; the port gate before the vendor |
  | `Test/OAuthAuthorizationServerClients` | the effect and the `Clients` row on each tool; hidden; a client registered after the mint refused at confirm; delete cascades |
  | `Test/OAuthAuthorizationServerWire` | arms `OCUPILOT_ALLOW_PRINCIPALS`; 403s naming the pair; a two-pair principal edits, sets the password, rotates and deletes a seeded configuration; markers on confirm and none for screen writes |

- Roster updates (own rows):
  - the ObjectScript rosters listed in the Code Map;
  - `classic-links.test.mjs` (OAuth declarations become `OAuthServerClientTab` only: three exemptions across three declarations), `navigation.test.mjs`, `navigation-wire.test.mjs`;
  - `oauth.browser-spec.mjs`, and the three editor specs' `CLASSIC_TABS` (drop `security/oauth/server`);
  - `scripts/ci-throwaway.sh` (a classes line).
- The spine's AD-44 by-name list: drop `OAuthServerTab` in the same pass (12.6's Q2 precedent).
- `ui/browser/oauth-server-editor.browser-spec.mjs` (new; `assertThrowaway`, `irisSession`):
  - Legs: create, edit with scopes, password masked, rotate, delete from the row menu with a seeded client, and the server-client tab keeping its classic link.
  - `detectScreen` at 1280 light, 720 light and 1280 dark on all five tabs and the delete dialog.
- `ui/browser/structural-baseline.json`: exactly three `security/oauth/server/edit` shell-chrome rows mirroring :1268-1300, and nothing else.
- `ui/angular.json` + `angular-json.test.mjs`: if the initial total crosses 1745kB, apply DW-1166 (5% above the measured total). HALT at 1900kB.

**Acceptance Criteria:**

- **AC1 (create).** Given no configuration, when the user chooses Create on the Authorization server tab, fills the General, Scopes and Customization tabs and saves, then:
  - the editor reads "Saved";
  - the tab shows the configuration;
  - `GET` returns every entered value.
- **AC2 (edit, scopes, grant types; AD-4).** Given a stored configuration opened from its name cell, when the user removes one scope, adds one, changes a grant type and an interval and saves, then `GET` shows exactly that, and every other field and `Metadata` member reads as before.
- **AC3 (delete).** Given a stored configuration with one registered client, when the user deletes it from the editor or the row menu and types the issuer, then the configuration and the client are gone.
- **AC4 (password).** Given the key password field, when a value is saved, then:
  - it is masked and never pre-filled, and the instance stores it;
  - no read, form read, screen context, proposal, ledger row, OcuPilot log line or masked audit read carries it;
  - an empty field leaves it unchanged.
- **AC5 (Rotate Keys).** Given a stored configuration without server credentials, when the user or a confirmed agent proposal rotates keys, then the key set grows and the outcome is reported. With credentials set, it is refused by name.
- **AC6 (affected clients).** Given a registered client, when the agent proposes an update, a password, a rotation or a delete, then the proposal carries the full write model and is minted destructive, and its card names the effect and the client. A client registered after the mint refuses the confirm.
- **AC7 (agent).** Given the five tools, when each is proposed and confirmed, then each write lands and is marked (AD-15), and the password is asked at confirm and never stored. A create taken after the mint is refused at confirm (AD-54).
- **AC8 (privilege).** Given a caller without `%Admin_OAuth2_Server:USE`, when they read the form, save, use a row action or mint, then they are refused with a 403 naming the pair, before any port call.
- **AC9 (link-out).** Given the OAuth 2.0 screen, when it renders, then the Authorization server tab's name cell opens OcuPilot's editor, the server-client tab keeps its classic link, and the check reports the OAuth exemption on `OAuthServerClientTab` alone.
- **AC10 (DW-1337).** Given the editor on each tab and its delete dialog, when it is measured at 1280 px light, 720 px light and 1280 px dark, then there is no structural or contrast violation.

### Review Findings

Code review 2026-09-25 (four layers, full-opus; blind and edge-case split server/client). 0 high, 6 medium and 6 low patched; 2 medium to the decision sheet; 5 low ledgered; the rest rejected.

- [x] [Review][Patch] (med) Blurring an empty issuer on a create showed `OAUTH.SERVERCONFIG.TAKEN`'s sentence (the rules list it first), and four class fields had no blur rule -- the store now takes the field's `.REQUIRED` rule, the five classes sharing `AuthenticateClass`'s [`oauth-server-form.store.ts` onBlur]
- [x] [Review][Patch] (med) `OAUTH.SERVERCREDENTIALS.KEY` told a user who had typed the password to enter it; it now says to save the key password first, without the credential [`Api/Error.cls`]. Save order itself is by-design (spec Save order), and QA's `TestNewCredentialsAndTheirPasswordAreRefusedTogether` pins the right invariant.
- [x] [Review][Patch] (med) A scope's description-only change drew identical before/after card text -- `CardRows` draws descriptions when the names match [`OAuthAuthorizationServerRules.cls`]
- [x] [Review][Patch] (med) Grant types named without `refresh_token` showed it removed on the card though the write re-adds it -- `WithRefreshGrant` now runs in the merge and the composition [`OAuthAuthorizationServer{Rules,Update,Create}.cls`]
- [x] [Review][Patch] (med) The log half of `TestNoContextOrLogLineCarriesThePassword` could not fail: the canned refusal quoted no password and bypassed the body mask -- it now quotes it and logs with the body [`Test/OAuthAuthorizationServerRecordPort.cls`]
- [x] [Review][Patch] (med) AC6's four-tool loop had a mutation for its Delete leg only -- Update, SetPassword and RotateKeys legs proven (run 808)
- [x] [Review][Patch] (low) AC8's mint refusal was never observed in the principal's own process -- `MintedAs` leg added [`Test/OAuthAuthorizationServerWire.cls`]
- [x] [Review][Patch] (low) Numbers passed the text-field rules (`ReturnRefreshToken`, algorithms) -- `PORTFIELDSHAPE`; a scope entry with extra members passed -- `OAUTH.SCOPES.SHAPE` [`OAuthAuthorizationServerRules.cls`]
- [x] [Review][Patch] (low) The issuer hint rendered under Return refresh token -- now under the issuer; `onRotate`'s comment claimed a re-read [`oauth-server-form.page.ts`]
- [x] [Review][Patch] (low) QA's two tests' mutations recorded in `## Verification` (runs 807, 809)
- [ ] [Review][Decision] (med) A two-pair principal cannot create (roles unreadable), and the form pre-checks defaults it refuses -- DW-1662 decision-pending; QA's Wire create test pins the spec as written
- [ ] [Review][Defer] (med) Privileged customization role is name-only (`%Manager` not destructive) -- DW-1663 escalated
- [ ] [Review][Defer] (low) DW-1664..DW-1667 wontfix-accepted; DW-1668 open (the Recorded #8887 line cites a no-key test)
- Rejected: AD-27 "second vendor-class use" (`Refresh` completes no call and writes nothing; AD-27's named-case clause governs completing a call); `REFRESHPOLICIES` single values, `Description`/`DefaultScope` rules, the shared password hint, reused algorithm labels, Create opening the stored configuration (spec-bound); create/update `Prohibited` order, `REQUIREDFIELDS` comment, unused `clients()` (no harm); 404 from the clients list, non-string `ServerPassword`, `Expand` without status, `definition` deny-list, PUT upsert race (theoretical); stale "Rotated" line, empty-choice wording, `before` shadowing, duplicated route constants, refusal wording, raw action reason, unknown stored grants, empty namespace select, same-URL create, re-read focus (low, no practical harm); per-leg mutations beyond one per AC.

## Spec Change Log

- 2026-09-25, lead spec gate: Q1-Q4 answered (Q3 with the no-silence requirement, Q4 as a named destructive effect for `%All`/`%Admin_*`); AD-27 and AD-35 amended.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 23 findings — high 0, medium 7, low 8, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` Delete, SetPassword and RotateKeys confirms not pinned against a client registered after the mint — test now loops all four tools; mutation line recorded (run 491).
  - `[medium]` `[patch]` Password-only Save (CHANGEPWD only, no configuration PUT) untested — `TestAPasswordOnlySaveSendsNoConfigurationWrite` added.
  - `[medium]` `[patch]` Page status line "key password was not stored" untested across the post-Save re-read — page spec case added.
  - `[medium]` `[patch]` Least-privileged "keep stored values only" never exercised in update mode — Wire `TestACallerWhoCannotReadTheRolesKeepsOnlyStoredRoles`; mutation line recorded.
  - `[low]` `[patch]` CHANGEPWD vendor-500 mapping to `OAUTH.SERVERCREDENTIALS.KEY` untested — `TestAPasswordRefusalIsNamedAgainstTheCredentials`; mutation line recorded.
  - `[medium]` `[patch]` Log-line half of `TestNoContextOrLogLineCarriesThePassword` vacuous (no line written, count discarded) — now drives a refused write, asserts the log grew, then the absence.
  - `[low]` `[patch]` Store spec's clients test had no hidden case — hidden fixture case added.
  - `[false]` `[reject]` AC5 refusal sub-clause lacks its own mutation line — Rule 19 asks one mutation per AC; AC5 has one (run 470).
  - `[false]` `[reject]` AC7 confirm marker lacks its own mutation line — AC7 has its mutation (`CREATES` 0, run 472).
  - `[false]` `[reject]` AC8 Save routes/row actions lack their own mutation lines — AC8 has its mutation (run 473), and the port-gate mutations (runs 478-479).
  - `[medium]` `[patch]` AC6 confirm refusal pinned for Update only (same root as the first row) — grouped; fixed there.
  - `[false]` `[reject]` Store's `clients()`/`clientsHidden()` never reach the page — the intent names the clients on the proposal card, not the editor; the form read carries them per Tasks; no bad outcome.
  - `[false]` `[reject]` `Save.Update` asks the prohibited set before `DerivedFields` — mirrors 12.6's `OAuthResourceServerSave` :251/:253 and the mint's order; no divergence.
  - `[false]` `[reject]` Hidden clients answer `OAUTH.SERVERCLIENTSHIDDEN` rather than `OAUTH.SERVERCLIENTS` — the lead's Q3 answer requires the fixed can-not-list sentence, which needs its own code; the proposal stays destructive and named.
  - `[false]` `[reject]` Delete with no clients carries no client consequence — "instead" replaces the clients effect when one exists; the tool is destructive regardless.
  - `[low]` `[patch]` No end-to-end hidden-clients mint as a real principal — Wire `TestAHiddenClientsProposalIsMintedAsThePrincipal`.
  - `[low]` `[patch]` Route envelope for a create while a configuration is present untested — `TestAPresentConfigurationIsRefusedTakenOverTheWire`.
  - `[medium]` `[patch]` Matrix row "Edit, bad value" covered in create mode only — `TestEveryBadValueRefusesAnEditOnBothCallers` over both callers; mutation line recorded (run 498).
  - `[medium]` `[patch]` Client removed between mint and confirm untested (same root as the first row) — grouped; `TestAClientRemovedAfterTheMintRefusesTheConfirm`.
  - `[low]` `[patch]` The tab's Create with a configuration present opening the edit untested — page spec id-less route case added.
  - `[low]` `[patch]` Id-less route opening the stored configuration untested (same root as the previous row) — grouped; same case.
  - `[low]` `[patch]` Sign-in with no configuration not asserted — `TestSignInIsUntouched` now logs in before seeding.
  - `[low]` `[patch]` Row action's change-event target id not asserted — `TestRotatingGrowsTheKeySet` asserts `(oauth2-server, instance, SYSTEM)`.
- Patches applied by a fresh subagent (Rule 18: no re-engagement); two literal U+2019 in the page spec escaped by the stage agent (client-lint).

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-24, AD-26, AD-27, AD-28, AD-29, AD-35, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, and Conventions › Secrets.

- No AC contradicts an AD.
- AD-8 is not widened. The measured pair set is the tab's own.
- Every type is synchronous (AD-26).
- The DW-1337 gate applies.

**Measured on `ocupilot-b-ci`, 2026-09-25.** The baseline had no configuration and `/oauth2` present. A probe principal, role and server client were used. At the end there was no configuration, no client and no probe principal. Audit rows remain.

- **PUT.**
  - A partial create answered 400 (#40301) for every template key, and a complete one answered 201.
  - `{Description}` kept every field. `SupportedScopes` was replaced whole. `Metadata` merged by member, where `[]` or `""` cleared one.
  - `ServerPassword` and `Foo` each answered 400. The whole `GET` re-sent answered 200.
- **PUT refusals and acceptances.**
  - Refused with 500: `SigningAlgorithm` "XX", `AccessTokenInterval` 0 or "abc", `CustomizationRoles` [], `SupportedScopes` [], `ServerCredentials` unknown (#8885), a 1025-character description, a non-boolean flag, and `AuthenticateClass` "" (`<LIST>`).
  - Accepted: an unknown namespace, class, role or SSL configuration, `ReturnRefreshToken` "zz", a bogus grant type, `IssuerEndpoint` "" or "not a url" (stored as `https:///ot a url`), and a bogus `token_endpoint_auth_methods_supported`, which then made every later save 500 (#8907).
- **CHANGEPWD.** `{}` and an extra key answered 400; a value stored it (length 3); `""` cleared it; an absent configuration answered 404.
- **Audit.** The vendor wrote the password in plain text into `%System/%Security/OAuth2` "Modify OAuth2 Server" rows, as a `ServerPassword modified:` block and as a `ServerPassword:` line in every later Modify row.
- **Privilege.** A principal holding only `%Admin_OAuth2_Server:USE` and `%DB_IRISSYS:READ`:
  - succeeded on `GET`, `PUT`, `CHANGEPWD`, `DELETE` and the vendor `RotateKeys`;
  - was answered 403 on `ServerClients` `LIST`;
  - was answered Access Denied on `%SYS.X509Credentials:ListPrivateKey`, `Security.SSLConfigs:List` and `Security.Roles:ListAll`.
- **Delete** removed the client (the `LIST` read `[]`). A second one answered 404.
- **Sign-in:** `POST /api/ocupilot/login` answered 200 before, with a rotated configuration, and after the delete.

**Form: five tabs, named and ordered as the classic editor's.**

1. **General**:
   - Issuer endpoint*, with the hint that the issuer is it plus `/oauth2`, and Description.
   - Audience required, Support user session, Allow public client refresh, the two PKCE flags, Front-channel logout, and Send session ID.
   - Return refresh token (a select of four).
   - Grant types (five checkboxes, at least one).
   - Service documentation, Policy and Terms of service URLs, and SSL/TLS configuration.
2. **Scopes**: supported scopes (Scope and Description rows with Remove, and Add), Allow unsupported scope, and Default scope.
3. **Intervals**: the five, in seconds.
4. **JWT Settings**: Server credentials (none, or a listed credential), Private key password (masked, with the shared hint), Signing algorithm, Key management algorithm and Content encryption algorithm.
5. **Customization**: the five classes, Namespace, and Roles (checkboxes over the readable roles plus the stored ones).

The action bar has Save (primary), Rotate Keys and Delete. A new configuration takes the classic page's defaults.

**Strings** (`oauthAuthServer*`; new keys only):

- The form title "Authorization server", and the tab names Scopes, Intervals and Customization.
- The field labels above that no existing key carries, "Add scope", and the grant-type and refresh-token option words.
- "Rotated the authorization server's keys."
- "Saved. The key password was not stored: {reason}"
- The delete consequence: "This also deletes every client registered with this authorization server."
- The two card sentences:
  - "Every client registered with this authorization server gets its tokens from it, so this change reaches each of them."
  - "Deleting the authorization server configuration also deletes every client registered with it."
- The empty-state agent phrase "configure this instance's OAuth 2.0 authorization server".
- The field sentence for each code.

**Integration ACs.**

- Consumes:
  - Story 6.4's tab;
  - AD-53's route and handler, and AD-55's Save;
  - the Roles, SSL/TLS and X.509 lists' declared reads, and `Kernel/Shell/Namespaces`;
  - the `ServerClients` endpoint;
  - Epic 9's `app-form-tabs`.
- Introduced: `OAuthAuthorizationServerPort`, the form descriptor, five tools and three routes, consumed here by the editor, the row actions and agent dispatch (AC1-AC8).
- Consumed-by:
  - Story 12.8, whose clients are what AC6 names;
  - Story 12.9, which removes the last OAuth exemption.

**Ledger inbox:** none.

**Expected `footprint_extensions`:**

- `AdminPort.cls`, `AuditPort.cls`, `Prohibited.cls`, `Router.cls`, `Error.cls`, `EntityRef.cls`, `Classification.cls`/`ToolFields.cls`, `Kernel/Audit/Log.cls`.
- `ui/tools/credential-pattern.mjs`, `field-lists.mjs` (+ test).
- `screen-outlet.ts`, `screen-action-handler.ts` (+ spec), `proposal-view.ts`, `proposal-card.spec.ts`, `app.ts`/`app.spec.ts`, `strings.ts`, `_components.scss`.
- EXPERIENCE.md, the spine (AD-44 at implement; AD-4 and Conventions › Secrets at this plan), `structural-baseline.json`, the budget pair, and the roster files.

**Lead answers at the spec gate (2026-09-25):**

- Q1: accepted. AD-27 now names Story 12.7's case (Rotate Keys through `OAuth2.Server.Configuration.RotateKeys()` in `%SYS`), spine amended at the gate.
- Q2: accepted. AD-35's third declaration masks `ServerPassword` in "Create OAuth2 Server" and "Modify OAuth2 Server" rows, spine amended; append the `AuditPort` `VENDORSECRETS` entry and its seeded-row test on both reads.
- Q3: accepted, with one requirement: without `%Admin_OAuth2_Registration:USE` the card still says the change affects every client registered with this server and that this account cannot list them (a fixed string), so AC3's "which clients" is answered as far as the caller's privilege reaches; it never falls silent. No tool declares the Registration pair.
- Q4: `CustomizationRoles` is permitted as the vendor allows, but a change that adds `%All` or an `%Admin_*` role to it is minted destructive with its own named effect (the customization code then runs with that privilege), the way 12.6's authenticator reset and Epic 9's web-application role grants are -- "developer tool first": permitted, confirmed, effect named. It is not a strongest-confirmation refusal.
- AD-44: drop `OAuthServerTab` from the by-name list in the implement pass (OAuth exemption then declared by `OAuthServerClientTab` alone; three exemptions, three declarations).
- Bundle: re-base per DW-1166 if the measured total crosses 1745kB; HALT at 1900kB.
- `structural-baseline.json`: only the shell-chrome rows every route carries (DW-1583/DW-1584) may be added for the new route.

**Open questions for the lead** (the spec is built on each recommendation):

- **Q1, AD-27 (Rule 20).** Name Story 12.7's case: `OAuthAuthorizationServerPort` completes Rotate Keys through `OAuth2.Server.Configuration.RotateKeys()` in `%SYS`, after the endpoint's `%Admin_OAuth2_Server:USE` gate. This is needed because the admin API has no rotate type for `Security.OAuth2.Server` (measured: `GET`, `PUT`, `DELETE`, `REVOKE` and `CHANGEPWD` only). A two-pair principal succeeded.
- **Q2, AD-35 (Rule 20).** Add a declaration: "Create OAuth2 Server" and "Modify OAuth2 Server" rows mask `ServerPassword` (measured in Modify rows; the Create row lists every property, which is inference).
- **Q3, AD-8/AD-29.** The card names clients only when the caller holds `%Admin_OAuth2_Registration:USE`, through that endpoint's own gate. Otherwise it names the effect without the names, fail-closed. The alternative is adding that pair to the tab's own set, which would bar a caller the classic page admits.
- **Q4, AD-10.** `CustomizationRoles` are roles the vendor's `/oauth2` customization code runs with. They are recommended as not an AD-10 privilege-grant arm, and permitted as the vendor allows (inference). The alternative is the strongest confirmation when they name `%All` or an `%Admin_*` role.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. OAuth-writing tests run on `ocupilot-b-ci` only (52777/1976), one class per call, each awaited in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the deployed bundle is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth-server-editor.browser-spec.mjs browser/oauth.browser-spec.mjs browser/oauth-resource-server-editor.browser-spec.mjs browser/oauth-client-editor.browser-spec.mjs browser/oauth-server-description-editor.browser-spec.mjs` (loop) -- expected: every leg passes.
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class <C>` (loop), one call each for:
  - the six `OAuthAuthorizationServer*` classes (`Wire` armed);
  - `AuditVendorSecrets`, `OAuthTabs`, `ToolRoundTrip`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `PortFixture`, `Prohibited`, `Descriptor`, `DerivedFields`, `Wire`, `WireOAuthRead`, `WireSecurityRead`.

  Expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, with the bundle total recorded.
- The full browser suite is CI's (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

| AC | Mutation |
| --- | --- |
| AC1 | The create composes no `CustomizationRoles` |
| AC2 | The update drops the fresh `Metadata` before sending (members read back cleared) |
| AC3 | The row action's typed-name check is dropped |
| AC4 | The Save sends `CHANGEPWD` for an empty field |
| AC5 | The port skips `RotateKeys` and answers 200 |
| AC6 | The port's `GET` stops adding `Clients` |
| AC7 | `CREATES` 0 on the create tool |
| AC8 | Remove the form route's gate |
| AC9 | Restore the exemption |
| AC10 | A 1400px `min-inline-size` on the scopes table |

**Measure in implement and record here:** the bundle total; the vendor answer for a credential whose key needs a password not stored; whether a "Create OAuth2 Server" row lists `ServerPassword`.

**Recorded:**

- Bundle initial total 1,764,919 bytes (main 1,614,024 + styles 150,895), over the 1745kB warning: re-based per DW-1166 to 1854kB in `ui/angular.json` and its pin in `angular-json.test.mjs`.
- A credential whose private key needs a password the configuration does not hold: the vendor `PUT` answers 500 with `ERROR #8887` (RSA key parsing error); the port names it `OAUTH.SERVERCREDENTIALS.KEY` on `ServerCredentials` (measured at the plan; `OAuthAuthorizationServerUpdate` `TestAVendorRefusalIsNamed` pins the same mapping for a credential with no private key, not #8887 itself).
- A "Create OAuth2 Server" audit row carries the password on a plain `ServerPassword:` line, so both events are declared in `AuditPort.VENDORSECRETS` (`OAuthAuthorizationServerSecret` `TestTheAuditReadsMaskThePassword`).
- mutation: `ComposeCreate` skips `CustomizationRoles` → OAuthAuthorizationServerCreate `TestACreateThroughTheRouteStoresEveryValue`, `TestACreateTakenAfterTheMintIsRefusedAtConfirm` red (run 467) (AC1); the store's `createBody` drops the roles → store spec AC1 red.
- mutation: `MergedMetadata` starts from `{}` → OAuthAuthorizationServerUpdate `TestAnEditSendsTheCompleteSet` red (run 468) (AC2).
- mutation: the page's `onDelete` calls `confirmDelete` without the typed-name dialog → page spec AC3 red; the tab's `DESTRUCTIVE_CONSEQUENCES` entry removed → screen-action-handler.spec "registers delete on the four tabs" red (AC3).
- mutation: `HandleUpdate` stores the password for an empty field → OAuthAuthorizationServerSecret `TestTheSaveStoresThePasswordAndNoReadCarriesIt` red (run 469); the store sends `ServerPassword` whatever the field holds → store spec AC4 red (AC4).
- mutation: the port's `RotateKeys` answers `$$$OK` without the vendor call → OAuthAuthorizationServerKeys `TestRotatingGrowsTheKeySet` red (run 470) (AC5).
- mutation: the port's `GET` answers `Clients` as `[]` → OAuthAuthorizationServerClients three tests red (run 471) (AC6).
- mutation: `CREATES` 0 → OAuthAuthorizationServerCreate three tests red (run 472) (AC7).
- mutation: `HandleForm` skips `Gate` → OAuthAuthorizationServerWire `TestACallerWithoutTheResourceIsRefusedEverywhere` red (run 473) (AC8).
- mutation: the tab's classic-link exemption restored → classic-links.test.mjs "the shipped descriptor roster passes" red (AC9).
- mutation: `.ocu-oauth-server-scopes` 1400px `min-inline-size`, rebuilt and redeployed → oauth-server-editor.browser-spec AC1 red, the table 920px past its block at 1280 and 720 (AC10).
- mutation: `VENDORSECRETS` without the two server events → `TestTheAuditReadsMaskThePassword` red (run 474); `OAuthServerForm` `secretFields` emptied → `TestNoContextOrLogLineCarriesThePassword` red (run 475); `Answer` drops `passwordRefused` → `TestAPasswordRefusedAfterTheSaveIsAnswered` red (run 476).
- mutation: `GrantsPrivilegeByEffect`'s authorization server arm answers 0 → OAuthAuthorizationServerUpdate `TestAPrivilegedCustomizationRoleIsMintedDestructive` red (run 477); `Put` returns the vendor 500 unmapped → `TestAVendorRefusalIsNamed` red (run 480).
- mutation: the port's `RefusedPair` check removed → OAuthAuthorizationServerKeys `TestThePortGateComesBeforeTheVendorClass` (run 478) and OAuthAuthorizationServerCreate `TestThePortRefusesACallerWithoutAPairBeforeTheVendor` (run 479) red.
- mutation: the delete tool's `SCREENACTIONS` emptied → OAuthAuthorizationServerClients `TestADeleteCascadesTheClients` red (run 481); `HandleUpdate` records an agent-write marker → OAuthAuthorizationServerWire `TestTheDeclaredPairsDoEveryScreenWrite` red (run 483).
- mutation: the page follows the whole URL rather than its id segment → page spec "a query-only change of the URL is no new arrival" red; the page's `afterRefusal` drops `tabToOpen` → page spec "a refusal on a Customization field" red.
- Every mutation reverted byte-identically, recompiled with its subclasses or rebuilt and redeployed; the six story classes re-ran green (runs 484-489).
- mutation: drop `Clients` from the delete tool's `FINGERPRINTSUBJECT` → OAuthAuthorizationServerClients `TestAClientRegisteredAfterTheMintRefusesTheConfirm`, `TestAClientRemovedAfterTheMintRefusesTheConfirm` red (run 491) (AC6).
- mutation: `CustomizationViolations` reads the stored roles from `Defaults()` rather than `pFresh` → OAuthAuthorizationServerWire `TestACallerWhoCannotReadTheRolesKeepsOnlyStoredRoles` red (run 495).
- mutation: `Rules.Changes` answers `pCreates` alone → OAuthAuthorizationServerUpdate `TestEveryBadValueRefusesAnEditOnBothCallers` red (run 498).
- mutation: the port's `ChangePassword` skips its credentials arm → OAuthAuthorizationServerSecret `TestAPasswordRefusalIsNamedAgainstTheCredentials` red (run 493).
- Each reverted byte-identically and recompiled with RecordPort where the port changed; Clients, Secret, Wire, Create, Update and Keys re-ran green (runs 500, 501, 502, 496, 503, 499).
- mutation: Clients dropped from SetPassword's and RotateKeys' `FINGERPRINTSUBJECT` and stripped from Update's merged payload → OAuthAuthorizationServerClients `TestAClientRegisteredAfterTheMintRefusesTheConfirm` red on the Update, SetPassword and RotateKeys legs (run 808) (AC6).
- mutation: `CustomizationViolations` reads a create's stored roles from `Defaults()` → OAuthAuthorizationServerWire `TestALeastPrivilegedPrincipalCannotCreateWithCustomizationRoles` red, the principal creating (run 807).
- mutation: `HandleUpdate` stores the password whatever the configuration write answered → OAuthAuthorizationServerSecret `TestNewCredentialsAndTheirPasswordAreRefusedTogether` red; `AdminPort.LoggedStatus` returns the status unmasked (compiled with subclasses) → `TestNoContextOrLogLineCarriesThePassword` red (run 809).
- mutation: `CardRows` draws scopes by name alone, and `MergeUpdate` skips `WithRefreshGrant` → OAuthAuthorizationServerUpdate `TestTheCardShowsWhatTheWriteSends` red on both assertions (run 806).
- mutation: the store's `onBlur` takes the field's first rule → store spec "a create's blur on an empty required field" red.
- Code review: each reverted byte-identically and recompiled (AdminPort and the Save with subclasses); Update 801, Secret 810, Wire 803, Create 804, Clients 805 green; components 1352/0; `oauth-server-editor` browser spec 5/5 on the rebuilt bundle (1,765,295 bytes); throwaway left with no configuration, no client, sign-in 200.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The Authorization server tab gets a five-tab `form-page` editor at `security/oauth/server/edit` on `app-form-tabs`, over a new `OAuthAuthorizationServerPort` (GET adds `Clients`/`ClientsHidden`; PUT; CHANGEPWD; ROTATEKEYS through the vendor class in `%SYS`, AD-27), five `security.oauthserver.*` tools, the form read and two Save routes, and the tab's Create, Delete and Rotate Keys. Lead decisions applied: AD-44 names `OAuthServerClientTab` alone (three exemptions, three declarations; spine sentence replaced, memlog appended); the two-pair set holds with a real least-privileged principal; a hidden client list is never silent (`OAUTH.SERVERCLIENTSHIDDEN`); adding `%All` or an `%Admin_` customization role mints destructive with its own effect; `ReturnRefreshToken` is the credential-pattern exception in both copies; `VENDORSECRETS` masks `ServerPassword` in Create and Modify OAuth2 Server rows.

**Files.** New: `Port/OAuthAuthorizationServerPort.cls`, `Area/Security/OAuthAuthorizationServer{Rules,Save}.cls`, `Screen/Descriptor/OAuthServerForm.cls`, `Screen/Tool/OAuthAuthorizationServer{Create,Update,SetPassword,RotateKeys,Delete}.cls`, `Test/OAuthAuthorizationServer{Create,Update,Secret,Keys,Clients,Wire,Probe,RecordPort,SaveFixture,Confirm}.cls`, `ui/src/app/areas/security/oauth-server-form.{store,page}{,.spec}.ts`, `ui/browser/oauth-server-editor.browser-spec.mjs`. Changed in footprint: `Screen/Descriptor/OAuthServerTab.cls`. Outside the footprint (all shared-append or rosters): `Api/Error.cls`, `Api/Router.cls`, `Kernel/Audit/Log.cls`, `Kernel/EntityRef.cls`, `Kernel/Proposal/Prohibited.cls`, `Port/AdminPort.cls`, `Port/AuditPort.cls`, `Screen/Tool/Classification.cls`, `Screen/Tool/ToolFields.cls` (regenerated); test rosters `AuditVendorSecrets`, `EndpointCoverage`, `OAuthDelete`, `OAuthTabs`, `PortFixture`, `PortGate`, `Prohibited`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `Wire`, `WireOAuthRead`, `WireSecurityRead`; `ui/src/app/{app.ts,app.spec.ts}`, `areas/security/oauth-actions.ts`, `core/{proposal-view,screen-actions,screens.generated,strings}.ts`, `shell/{proposal-card.spec,screen-action-handler,screen-action-handler.spec,screen-outlet}.ts`, `styles/_components.scss`; `ui/angular.json`, `ui/tools/{angular-json.test,classic-links.test,credential-lists.test,credential-pattern,field-lists,field-lists.test,navigation.test,proposal-view.test,screen-mirror.test}.mjs`; `ui/browser/{oauth,oauth-client-editor,oauth-resource-server-editor,oauth-server-description-editor}.browser-spec.mjs`, `ui/browser/structural-baseline.json` (three shell-chrome rows); `EXPERIENCE.md` (one row), `ARCHITECTURE-SPINE.md` (AD-44 sentence), `.memlog.md`, `scripts/ci-throwaway.sh` (one classes line).

**Review.** Two layers (verification-gap, intent-alignment), 23 findings: 15 patched (7 medium, 8 low; all test gaps, no product defect found), 8 rejected as false (see the triage log), 0 deferred. Patches by a fresh subagent; two literal U+2019 escaped by the stage agent.

**Verification (ocupilot-b-ci).** Full ObjectScript sweep once after the review patches and a whole-tree recompile: 281 classes, 2352 tests, 0 failed, runs 504-784, totals confirmed in `%UnitTest_Result`. Five OAuth browser specs on the freshly built and deployed bundle (`main-CWVJPMVO.js`): 26/26. `npm run build` green, initial total 1,764,919 bytes (warning re-based per DW-1166 to 1854kB); `npm test` tools 1424/0, components 1351/0; screen-mirror and field-lists no drift; check-objectscript 0; lint-docs clean; lint_spine only the existing `{id}` note; smoke 49/49. Throwaway left with no configuration, no server client, sign-in 200.

**Follow-up review recommended: true** (7 medium patched). Unverified risk: the post-review test legs (the four-tool fingerprint loop, update-mode rules, least-privileged stored roles, the principal-scoped hidden-clients mint) are green with mutations recorded but were not themselves reviewed.

**Residual risks.** Saving new server credentials and their key password together is refused `OAUTH.SERVERCREDENTIALS.KEY` (configuration is written before the password); the password must be saved first. The port re-reads the vendor configuration after every refusal because a refused vendor save leaves it changed in process memory (measured). A principal with the two pairs alone cannot create while the role list is unreadable to it (only stored roles pass).
