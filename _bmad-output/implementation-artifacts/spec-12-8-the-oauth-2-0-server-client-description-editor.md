---
title: 'Story 12.8: The OAuth 2.0 server client description editor'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-7-the-oauth-2-0-authorization-server-editor.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Server client descriptions tab only lists and deletes the clients this instance issues tokens to. Its name cell is the last OAuth link-out to the classic portal. Nobody can register a client, change its redirect URLs, set its client secret or update its public keys in OcuPilot.

**Approach:** Add a four-tab `form-page` editor at `security/oauth/server-clients/edit`, built on `app-form-tabs` and modeled on Stories 12.6 and 12.7. It round-trips `Security.OAuth2.ServerClients` through a new `OAuthRegisteredClientPort`:

- Save goes through the write tools (AD-55), and a create uses AD-54.
- Delete and Update JWKS are the tab's row actions (AD-53).
- The port strips the secret `Metadata` members from every read and completes the JWKS update through the vendor class, because the admin API has no JWKS type (Q1).
- The tab's classic-link exemption is dropped, so the name cell opens the editor (AD-44).

## Boundaries & Constraints

**Always:**

- **Naming.** The server-side and client-side classes use the prefix `OAuthRegisteredClient*` / `oauth-registered-client-*`. The reason: `OAuthServer*` is taken by 12.4's server description and 12.7's descriptors, `OAuthClient*` by 12.5's client configuration, and `OAuthAuthorizationServer*` by 12.7, and no `Test/<prefix>*` glob of theirs matches this one.
  - The form descriptor is `OAuthServerClientForm`, which pairs with its tab.
  - Tool wire names continue the existing `security.oauthserverclients.*`.
  - The Story 7.3 delete tool `OAuthServerClientDelete` keeps its name, because a rename would churn six rosters and change no behavior.
- **Identity.** The id is `ClientId`, which the vendor generates and a POST refuses (400 #40307). `Name` is not unique on the vendor (measured).
  - The route id and every non-create write's `TargetRef` is the `ClientId`, one segment (AD-13).
  - A create's `TargetRef` is the intended `Name` (AD-54, Q4). Its fresh read is the `LIST` with `READROWKEY` `Name`, which compares case-insensitively. A present name refuses the create on both callers with `OAUTH.SERVERCLIENTNAME.TAKEN`.
  - The port answers the generated `ClientId` from the POST's `Location` header, whose `clientId=` query names `/v1` (measured). The Save route answers it, and the editor `replaceUrl`s to it.
- **The client secret is write-only (AD-3, AD-35, AD-56 i).**
  - `ClientSecret` is masked, never pre-filled, and never appears in a read, a form read, a proposal's arguments, a diff, the ledger, screen context, a log line or a status.
  - It travels only through the endpoint's secret type, `SECRET` (`AdminPort.EndpointType` resolves it to the vendor's `TYPESECRET`, 10; `POST .../server/client/secret?clientId=`), as exactly `{ClientSecret}`, as 12.6's `OAuthResourceServerPort` `SECRETSTYPE` does.
  - An empty field means "unchanged". The port refuses an empty or missing secret with `OAUTH.SERVERCLIENTNOSECRET`, because `""` and `null` both clear the stored one (measured).
  - The vendor `GET` never answers `ClientSecret`. It does answer `Metadata.client_secret` and `Metadata.registration_access_token` unmasked when they are set (measured), so the port's `GET` removes both, and its `PUT` refuses a body carrying either.
- **The vendor-generated secret is never shown.** The vendor's `%OnNew` generates a secret for every client type, and no read may return it (epic rule, AD-35). So:
  - On a create, the editor asks for the secret. It is required unless the type is `public` (`OAUTH.SERVERCLIENTSECRET.REQUIRED`).
  - A **Generate** button fills the masked field with 48 random bytes, base64url-encoded, from the browser's `crypto.getRandomValues`, and a Show/Hide toggle reveals the field's own value. The secret therefore originates with the user, is visible only in the field the user holds, and is gone once saved, because the field is cleared and never pre-filled.
  - The create sends the POST first, then the secret type.
- **Save sends the complete property set (AD-4, amended at this plan).** It reads fresh through the port (secret members already stripped), applies the diff, and sends every template field: `Name`, `RedirectURL` (whole, as edited), `LaunchURL`, `Description`, `ClientType`, `ClientCredentials`, `DefaultScope`, and `Metadata` as the fresh read's whole object with the editor's members applied.
  - The two secret members are never sent. Metadata merges by member, so omitting a member keeps it.
  - On an update, the `PUT` is sent only when the diff is non-empty. The secret follows, and only when one was supplied. A secret failing after a saved write answers `secretRefused` `{reason}`.
  - The PUT is not an upsert: an absent client answers 404, which is `OAUTH.SERVERCLIENT.ABSENT` on the Save.
- **Form rules** are enforced identically by each tool's `ArgumentProblem` and by the Save route, and written once on the server as `detail.violations[]` (AD-39). They cover what the vendor refuses with 500 and what the classic page refuses (`doSave` :439-593):
  - `Name` is required. `ClientType` is one of `confidential`, `public`, `resource`.
  - For every type but `resource`:
    - at least one redirect URL, each an absolute URL with a scheme and a host (#8862/#8866);
    - at least one grant type and one response type;
    - the logo, home page, policy, terms-of-service and front-channel logout URLs share a scheme and host with some redirect URL (`%OnValidateObject` :538-598).
  - `grant_types` come from the five the classic page offers, and `response_types` from its four. The authentication method is one of five.
  - Algorithms come from the vendor's value lists, and each encryption/key pair is set together or empty.
  - Contacts are comma-separated emails. `default_max_age` is an integer of at least 0. `LaunchURL` is empty or an absolute URL.
  - `ClientCredentials`, when non-empty, is the stored alias or one that `X509CredentialList`'s declared read answers the caller (`ReadableNames`, as in 12.7). The least-privileged principal cannot list credentials (measured 403), so it keeps the stored value only.
  - Vendor 500s are mapped: #8863 (a grant type the authorization server does not support) to the grant-types field, #8886 to `ClientCredentials`, and the no-configuration error to `OAUTH.SERVERCLIENTCONFIG.ABSENT`. Any other 500 is `OAUTH.SERVERCLIENTVALIDATION`, with the raw text in the log only.
- **The JWT Settings tab** sets the public-key source: None, JWKS URL, or X.509 credentials.
  - JWKS URL sets `Metadata.jwks_uri` and clears `ClientCredentials`.
  - X.509 credentials sets `ClientCredentials`.
  - None clears both. The vendor keeps the previous public key set when `ClientCredentials` is cleared (measured); that is recorded, not fixed.
  - JWKS from a server file is not offered (AD-21).
- **Update JWKS** is an AD-51 action write that sends no body.
  - The port first repeats the endpoint's gate, then in `%SYS` (AD-16) opens `OAuth2.Server.Client` and calls `RefreshJWKS(<ssl>,1,1)` (Q1).
  - `<ssl>` is OcuPilot's own installer-created client SSL/TLS configuration (AD-32: `VerifyPeer` 1, `%OSCertificateStore`) for an `https` URI, and `""` for an `http` URI. Any other scheme is refused (`OAUTH.SERVERCLIENTJWKS.SCHEME`). See Q3.
  - It needs a stored `jwks_uri` (`OAUTH.SERVERCLIENTJWKS.NOURI`, 409) and answers a fetch failure by name (`OAUTH.SERVERCLIENTJWKS.FETCH`; an unreachable host takes about 10 s, measured).
  - Its read type `JWKS` answers `JwksUri`, `ClientCredentials` and `PublicKeys`, the number of keys in the stored public key set. It never reads `SymmetricJWKS`, which derives from the secret.
- **Delete** is the existing tool. It now declares the new port, so its fresh read is the stripped one. The vendor's `DeleteId` revokes the client's tokens; the existing consequence string says so, and the typed-name dialog asks for the client id as today.
- **The secret-change tool is destructive.** Its card names the effect: the client's application must use the new secret from then on. No other effect arm is added.
- **No self-protection arm.** OcuPilot's sign-in answered 200 before any client, with clients present, and after all were deleted (measured, AD-28).
- **Privileges.** Every tool, route and port call requires the tab's own pair set, `%Admin_OAuth2_Registration:USE` + `%DB_IRISSYS:READ` (AD-8, AD-29).
  - Measured with a principal holding only those two: LIST, GET, POST, PUT, the secret type, DELETE and the vendor `RefreshJWKS` all succeeded.
  - Without `%DB_IRISSYS:READ` the vendor answered 500/404/403; without the Registration pair it answered 403.
  - Screen writes emit no marker (AD-53), and agent confirms do (AD-15).
- **Change events.** Every write publishes `(oauth2-server-client, instance, <ClientId>)`. The agent's create publishes its `TargetRef` (the name), and the tab re-fetches by type (AD-14).
- **UI.** Use tokens only, and render correctly in the dark theme. The editor gets no DW-1337 allowance. Write non-ASCII in code as `\u` escapes.

**Never:**

- No third write mechanism.
- No declared pair beyond the tab's set.
- No suggested prompts, because Story 11.3's key is absent.
- No reading of `ClientSecret`, `SymmetricJWKS` or a secret `Metadata` member outside the port's strip.
- No change to the 12.4 through 12.7 editors beyond their roster rows.
- No OAuth-writing test on `ocupilot-slot-b`.
- No internet dependency in any test.
- No second tab component.
- No lazy loading or `@defer`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | A configuration exists. Confidential, two redirect URLs, a generated secret | 201. The editor reopens at the new `ClientId` reading "Saved". The tab lists it, and `GET` returns every value; the secret is stored | None |
| Create, name taken | A client with that name exists (any case) | 422 `OAUTH.SERVERCLIENTNAME.TAKEN`; nothing written | Before any port write |
| Create, no configuration | No authorization server configuration | 422 `OAUTH.SERVERCLIENTCONFIG.ABSENT`; nothing stored | Vendor error mapped |
| Edit, partial | One redirect URL removed, the client name and description changed | `GET` shows exactly that. Every other field and `Metadata` member is unchanged, and the secret members survive | None |
| Edit, bad value | No redirect URL, a relative URL, a logo on another host, an unsupported grant type | 422 on the named field; nothing sent | Form rule or mapped vendor 500 |
| Secret | Entered and saved | Stored. No read, context, ledger row or log line carries it; an empty field sends nothing | Refusal after a save → "Saved. The client secret was not stored: {reason}" |
| Update JWKS | Stored `jwks_uri` `http://localhost:52773/oauth2/jwks` | `PublicKeys` grows from 0. "Updated the client's public keys from its JWKS URL." | No URI → 409 named; unreachable → named failure |
| Delete | From the editor or the row menu, the client id typed | The client is gone and its tokens are revoked | Existing typed-name dialog |
| No privilege | Caller lacks either pair | 403 naming the pair on the form read, both Save routes, both row actions and the mint | Before any port call |

</intent-contract>

## Code Map

**Vendor (measured on `ocupilot-b-ci`, 2026-09-25).** `%Api.Admin.*` is hidden, so read it with `GetTextAsString` in `%SYS`. The exports are in the plan's scratchpad and may be re-exported.

- `%Api.Admin.Endpoints.Security.OAuth2.ServerClients`:
  - `ResourcesOR` :8-11 is `%Admin_OAuth2_Registration` for every type.
  - `ValidateQueryParams` :15-21 requires `clientId` except for LIST and POST.
  - `ObjToJson` :23-40; `TYPESECRET` :42; `NeedsRequestBody` :44-47.
  - `RunChangeSecret` :97-108; `RunPost` :120-130 (Location :126); `PutAndPost` :134-165; the template :167-184; `ValidateRequest` :186-202.
  - `ShouldRunAsync` is not overridden (AD-26).
  - v2 routes are at `Dispatch.v2` :150-155.
- `OAuth2.Server.Client`:
  - IdKey :13; `Name` :22; `ClientType` :44; `ClientCredentials` :47; the JWKS properties :52-66.
  - `%OnNew` :232-242 generates the id and secret.
  - `SetPublicJWKS` :245-283; `UpdateJWKS` :402; `RefreshJWKS` :433-478, which runs `$$$AddAllRoleTemporary` and saves.
  - `%OnAddToSaveSet` :487-536; `%OnValidateObject` :538-598; CORS :684-759; audit :762-833.
  - The class resource is `%Admin_OAuth2_Registration` (`%sySecurity.inc:445`).
- The classic page `%CSP.UI.Portal.OAuth2.Server.Client`:
  - tabs :87, General :98-127, Client Credentials :138-142, Client Information :153-170, JWT :182-218;
  - defaults :716-731/:761-765; `doSave` :439-593;
  - `UpdateJWKS` :824-863, which needs `OAuth2.Server.Configuration.Open`, that is `%Admin_OAuth2_Server`;
  - `SaveData` JWKS :940-956.

**Server models:**

- `Port/OAuthAuthorizationServerPort.cls`:
  - `CLIENTSENDPOINT` :28, `COMPOSEDTYPES` :45, `GATEPAIRS` :63;
  - `Invoke` :72-112 (gate :79, the composed guard :96), `Read` :123;
  - `Put` :188, `ChangePassword` :260, `RotateKeys` :321, `RefusedPair` :360, `Violation` :382.
- `Port/OAuthServerPort.cls` `JWKSTYPE` :45, `REFRESHTYPE` :48, `RefreshKeySet` :344 (`RefreshJWKS` :363).
- `Area/Security/OAuthAuthorizationServerRules.cls` `Validate` :165, `ReadableNames` :605, `HandleForm` :629, `Gate` :759.
- Id-keyed Save models:
  - `Area/Security/OAuthClientSave.cls`: `HandleUpdate(pId)` :121, `StoreSecrets` :288, `Answer` :396;
  - `OAuthResourceServerSave.cls` :120/:298.
- `Screen/Tool/Write.cls`:
  - parameters `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `STATEFIELD` :75, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CREATES` :141, `SCREENACTIONS` :157, `READANSWERS` :170, `READIDPARAM` :175, `READROWKEY` :181, `SECRETBODY` :191;
  - `StateDiff` :453, `IdArgument` :490.

  `Consequence` is per tool (`Mint.cls:666`; example `OAuthAuthorizationServerUpdate.cls:102`).
- `Screen/Tool/OAuthServerClientDelete.cls` (`READANSWERS` :53, `StateDiff` :120), `OAuthClientSetSecrets.cls` :23-38, `OAuthServerDescriptionUpdateJwks.cls` :26-45.
- The installer's SSL/TLS configuration: `Install/Installer.cls` :109-121/:202 (the name comes from `Kernel.State.Base.#SSLCONFIG` plus the install suffix; resolve it at call time).
- `Screen/Descriptor/OAuthServerClientTab.cls` (exemption :45-51); `OAuthServerForm.cls` is the form template.

**Shared server files (own lines only):**

- `Port/AdminPort.cls` `MUTATINGTYPES` :298, `BODYLESSTYPES` :314. The ServerClients `DELETE` is already listed.
- `Port/AuditPort.cls` `VENDORSECRETS` :118. Its longest whole-word prefix match currently resolves "Modify OAuth2 Server Client" rows to the "Modify OAuth2 Server" entry (measured).
- `Kernel/Proposal/Prohibited.cls`:
  - `TYPEOAUTHSERVERCLIENT` :277, already in `COVEREDTYPES` :250 and the guard :782; dispatch :874-877 to `OAuthEntry` :1657 (doc :1643-1656);
  - `PermittedChangeFields` :576-598, `PermittedCreateFields` :686-703, the field lists :1559-1587.
- `Api/Router.cls` 12.7 routes :175-177, `</Routes>` :178, wrappers :598-618 (12.6's `pId` wrapper :586).
- `Api/Error.cls` `ReasonForOAuthAuthorizationServer` ends `Quit ""` :2860; `OAuthAuthorizationServerViolationCodes` :2865-2868.
- `Screen/Tool/Classification.cls`: insert before `"permissions.users.create"` :696. `ToolFields.cls` is regenerated (`security.oauthserverclients.*` at :349).

**Client (current anchors):**

- `areas/security/oauth-server-form.{page,store}.ts` (912/860 lines):
  - page: `app-form-tabs` :159-264, the scope list editor :207/:214/:671/:678, `onSave` :683, `onRotate` via `handler.sendFor` :705-711, `confirmDelete` :736-740, `focusField` :752, `tabToOpen` :787, `passwordControl` :887;
  - store: field→tab map :95, `FIELD_ORDER` :135, `reset` :542, `open` :574, `save` :677.
- `oauth-client-form.page.ts` `secretControl` :879-891.
- Registrations:
  - `shell/screen-outlet.ts` :21-24/:121-124;
  - `shell/screen-action-handler.ts`: the tab is already in `SCREEN_ACTION_DESCRIPTORS` :48 and `DESTRUCTIVE_CONSEQUENCES` :200;
  - `core/screen-actions.ts` labels :112-117;
  - `areas/security/oauth-actions.ts` :8-60;
  - `app.ts` :268-275 / :566-573, pinned by `app.spec.ts` :1060-1083 / :1165-1175;
  - `core/navigation.ts` `createFormFor` :188;
  - `shell/data-table.ts` :579-616 (with the exemption gone, the name cell links `security/oauth/server-clients/edit/<ClientId>`).
- `core/proposal-view.ts` `CONSEQUENCE_*` :121-166 and `consequenceSentence` :172-192.
- `core/strings.ts`: the 12.7 block ends :2510, and `} as const` is :2512. Reuse:
  - `tableColumnName`, `tableColumnDescription`, `oauthColumnClientId`, `oauthColumnClientType`, `oauthClientType{Confidential,Public,Resource}`;
  - `oauthColumnRedirectUrls`, `oauthColumnDefaultScope`, `oauthClientFieldCredentials`, `oauthClientFieldSecret`, `oauthClientSecretHint`;
  - `oauthServerUpdateJwks`, `oauthColumnSigningAlgorithm`/`EncryptionAlgorithm`/`KeyAlgorithm`, `formSaved`, `oauthServerClientDeleteConsequence`.
- `_components.scss` ends at :6290 (12.7's block starts :6209). EXPERIENCE.md's last Fixed-strings row is :520.
- `ui/browser/structural-baseline.json`: 12.7's rows at :1301-1333 (DW-1583/DW-1584).
- Exemption pins:
  - `ui/tools/classic-links.test.mjs` :440-473 (`oauth` :449, counts :472-473), `classic-links.mjs` :18-19;
  - `browser/oauth.browser-spec.mjs` honored set :356-361;
  - `CLASSIC_TABS` in `oauth-client-editor` :65 (loop :375), `oauth-resource-server-editor` :68 (:416), `oauth-server-description-editor` :54 (:309) and `oauth-server-editor` :59 (:360-376).
- Budget: `ui/angular.json` :51-56 (1854kB), pinned at `angular-json.test.mjs` :377.

**Rosters:**

- `Test/PortGate.cls:28`, `Test/PortFixture.cls:21`, `Test/ToolRoundTrip.cls:37`
- `Test/SurfaceCoverage.cls` :77-80 and :152-173
- `Test/EndpointCoverage.cls` :158-160
- `Test/Prohibited.cls` :218/:398
- `Test/ToolWrite.cls` :1171-1274
- `Test/OAuthDelete.cls` :225-229
- `Test/ReadTool.cls:94`
- `Test/OAuthTabs.cls` :30-34, :85, :185-205 and :367
- `Test/Wire.cls:578`, `Test/WireSecurityRead.cls` and `Test/WireOAuthRead.cls` `ScreensFor` literals: the new form route sorts before `server-clients`
- `Test/AuditVendorSecrets.cls` :124: its control row must move to a genuinely undeclared event
- `scripts/ci-throwaway.sh` :206
- Probe helpers: `Test/OAuthAuthorizationServerProbe.cls` `Seed`/`SeedClient` :81/`RemoveAll` :247

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/OAuthRegisteredClientPort.cls` (new; extends `AdminPort`; `GATEPAIRS` the tab's two; add it to `Test/PortGate` `ROSTER`):
  - `GET`: removes `Metadata.client_secret` and `Metadata.registration_access_token`.
  - `POST`: answers `ClientId` from `Location`.
  - `PUT`: refuses a body carrying either secret member, and maps vendor 500s.
  - The secret type: refuses an empty or missing `ClientSecret`.
  - `JWKS` read and `REFRESHJWKS` write (both in `COMPOSEDTYPES`): the gate, then `OAuth2.Server.Client` in `%SYS`, as the Constraints say. A failure is a 422 plus `LogFault`.
  - `AdminPort`, one line each (contended):
    - `MUTATINGTYPES`: `Security.OAuth2.ServerClients/POST,/PUT,/SECRET,/REFRESHJWKS`;
    - `BODYLESSTYPES`: `/REFRESHJWKS`.
- `src/OcuPilot/Screen/Tool/OAuthRegisteredClient{Create,Update,SetSecret,UpdateJwks}.cls` (new).
  - Common to all:
    - `DESCRIPTORCLASS` is `OAuthServerClientTab`, `PORTCLASS` is the new port, and `WRITERESOURCE` is `%Admin_OAuth2_Registration:USE`.
    - Names are `security.oauthserverclients.<verb>`.
    - Every `DESCRIPTION` says nothing changes until the user confirms.
  - Per tool:
    - Create: `CREATES` 1, `READTYPE` LIST, `READROWKEY` `Name`, `WRITETYPE` POST, `CHANGEACTION` created.
    - Update: a GET/PUT merge.
    - SetSecret: `WRITETYPE` SECRET, `SENDSBODY` 0, `SECRETBODY` `ClientSecret`, subject `Name,ClientType`, precondition `ClientType`, `DESTRUCTIVE` 1, with a `Consequence` code.
    - UpdateJwks: `SCREENACTIONS` updatejwks, `READTYPE` JWKS, `WRITETYPE` REFRESHJWKS, subject `JwksUri,ClientCredentials`, precondition `JwksUri`, `STATEFIELD` `PublicKeys`. `ArgumentProblem` refuses an empty URI.
- `Screen/Tool/OAuthServerClientDelete.cls`: `PORTCLASS` becomes the new port. Nothing else changes.
- `Screen/Tool/Classification.cls`: create and update are ordinary, with `Metadata` opaque; setsecret has `ClientSecret` as authored secret. Then regenerate `ToolFields.cls`.
- `Kernel/Proposal/Prohibited.cls` (own lines):
  - `OAuthRegisteredClientFields()`, the eight template fields, returned by both Permitted methods for `oauth2-server-client`;
  - update `OAuthEntry`'s doc;
  - a setsecret consequence effect constant.
- `Screen/Descriptor/OAuthServerClientForm.cls` (new):
  - Route `security/oauth/server-clients/edit`, `form-page`, position 0.
  - The tab's pairs; `oauth2-server-client`, `instance`, id `ClientId`.
  - `context.secretFields [ClientSecret]`.
  - `classicPage` `%CSP.UI.Portal.OAuth2.Server.Client`, no exemption, `toolIdentifier` `security.oauthserverclientform`.
- `Screen/Descriptor/OAuthServerClientTab.cls`:
  - `exempt: false`, with the `rowLink` removed.
  - `primaryAction create`, `rowActions [delete, updatejwks]`, `secretArguments [ClientSecret]`.
  - Rewrite the doc comment's link and action paragraphs, then regenerate `screens.generated.ts`.
- `Area/Security/OAuthRegisteredClient{Rules,Save}.cls` (new, modeled on 12.6's and 12.7's pairs):
  - The form read, `GET /oauth/server-client/form`, answers `requiredFields`, `rules`, `credentials` (`ReadableNames` on `X509CredentialList` `Alias`), and `definition` plus `clientId` when an id is given.
  - The Save body is the changed fields plus `ClientSecret`. Any other key is refused.
  - Every rule is checked before the first write, and each write goes through `Operation.Gate`/`ApplyAt`.
- `Api/Router.cls` (after :177): `GET /oauth/server-client/form`, `PUT /oauth/server-client/:id`, `POST /oauth/server-client`, with thin wrappers.
- `Api/Error.cls`: a `ReasonForOAuthServerClient` chained from :2860, plus `OAuthServerClientViolationCodes`. The codes named above:
  - `OAUTH.SERVERCLIENTNAME.{REQUIRED,TAKEN}`, `OAUTH.SERVERCLIENTTYPE.VALUE`, `OAUTH.REDIRECTURL.{REQUIRED,SHAPE}`;
  - `OAUTH.CLIENTGRANTTYPES.{REQUIRED,VALUE,UNSUPPORTED}`, `OAUTH.RESPONSETYPES.{REQUIRED,VALUE}`, `OAUTH.AUTHMETHOD.VALUE`;
  - `OAUTH.CLIENTURL.HOST`, `OAUTH.CONTACTS.SHAPE`, `OAUTH.MAXAGE.VALUE`, `OAUTH.LAUNCHURL.SHAPE`, `OAUTH.CLIENTCREDENTIALS.ABSENT`;
  - `OAUTH.SERVERCLIENTSECRET.REQUIRED`, `OAUTH.SERVERCLIENTNOSECRET`, `OAUTH.SERVERCLIENTJWKS.{NOURI,SCHEME,FETCH}`;
  - `OAUTH.SERVERCLIENTCONFIG.ABSENT`, `OAUTH.SERVERCLIENT.ABSENT`, `OAUTH.SERVERCLIENTVALIDATION`.

  Reuse `OAUTH.ALGORITHM.VALUE`, `OAUTH.ENCRYPTION.PAIR`, `OAUTH.METADATAURL.SHAPE`, `OAUTH.DEFAULTSCOPE.SHAPE` and `OAUTH.FLAG.VALUE`.
- `Port/AuditPort.cls` `VENDORSECRETS`: append `Create OAuth2 Server Client=registration_access_token;Modify OAuth2 Server Client=registration_access_token` once the lead amends AD-35 (Q2). Add a seeded-row test on both reads, and move `AuditVendorSecrets` :124's control row to an undeclared event.
- `ui/src/app/areas/security/oauth-registered-client-form.{store,page}.ts` (+ specs):
  - The four tabs (Design Notes), with the field→tab map, `tabToOpen`, and a `focusField` that switches the tab first.
  - The redirect URL list with Add and Remove, copying 12.7's scope rows.
  - The secret control with Generate and Show/Hide.
  - The unsaved guard, "Saved", and a create followed by `replaceUrl`.
  - Update JWKS, shown only when a JWKS URL is stored, through `handler.sendFor(OAuthServerClientTab,'updatejwks')`, with its outcome line.
  - Delete through `handler.sendFor(OAuthServerClientTab,'delete')`.
  - In `app.ts`, inject the store and reset it at sign-out; pin that in `app.spec.ts`.
- `areas/security/oauth-actions.ts` (the tab's Create), `shell/screen-outlet.ts` (page entry), and `core/screen-actions.ts` (the `updatejwks` label).
- `core/proposal-view.ts` + `shell/proposal-card.spec.ts` + `tools/proposal-view.test.mjs`: the setsecret consequence code and its sentence.
- `core/strings.ts` (after :2510), EXPERIENCE.md (a row after :520: Story 12.8, FR-44) and `_components.scss` (own `ocu-oauth-registered-client-*` classes after :6290): the Design Notes strings.
- ObjectScript tests (new; each under 500 lines, one class per call, on `ocupilot-b-ci` only). Helper `Test/OAuthRegisteredClientProbe.cls` has `Seed` (a configuration through 12.7's probe), `SeedClient` (optionally with `jwks_uri` `http://localhost:52773/oauth2/jwks`), and `RemoveAll`, which leaves no configuration and no client, with `/oauth2` as found. Add `RecordPort`/`SaveFixture` helpers as 12.7 needed.

  | Class | Covers |
  | --- | --- |
  | `Test/OAuthRegisteredClientCreate` | declarations and pairs; create through the route (POST, then the secret); the name taken on both callers; no configuration; every form rule on both callers; a create taken after the mint refused at confirm |
  | `Test/OAuthRegisteredClientUpdate` | the complete set; redirect add/remove; `Metadata` members kept, the secret members neither answered nor erased; vendor 500s named; absent → 404 named |
  | `Test/OAuthRegisteredClientSecret` | stored and never read (GET, form read, context, proposal, ledger, log); empty sends nothing; empty body refused by the port; `secretRefused`; the setsecret card destructive; the audit mask on both reads |
  | `Test/OAuthRegisteredClientJwks` | the in-container URL grows `PublicKeys`; no URI → 409; scheme refused; the `https` configuration passed is OcuPilot's (through `RecordPort`); an unreachable URL named; the port gate before the vendor class |
  | `Test/OAuthRegisteredClientWire` | arms `OCUPILOT_ALLOW_PRINCIPALS`; 403s naming each pair; a two-pair principal creates, edits, sets the secret, updates JWKS and deletes; markers on confirm and none for screen writes; sign-in untouched |

- Roster updates (own rows): every file under Code Map › Rosters; `OAuthTabs` `EDITEDTABS` gains `OAuthServerClientTab`, and `EXEMPTIONREASON` goes.
- **AD-44 (implement pass).** Replace the spine's by-name sentence so that:
  - `OAuthServerClientTab` dropped its declaration at Story 12.8;
  - the OAuth exemption has no declaration and is gone;
  - two exemptions remain across two declarations, `ServiceForm` and `LdapConfigForm`.

  Then update:
  - `classic-links.test.mjs`: `oauth` becomes `[]`, the counts become 2 and 2, and the dead OAuth branch goes;
  - the `classic-links.mjs` prose;
  - `oauth.browser-spec.mjs`: the honored set becomes `['LdapConfigForm.cls','ServiceForm.cls']`;
  - the four editor specs: retire the `CLASSIC_TABS` legs;
  - `navigation.test.mjs`: the route roster :176-183 and the sentence :199.

  Append to the memlog and run `lint_spine`.
- `ui/browser/oauth-registered-client-editor.browser-spec.mjs` (new; `assertThrowaway`, `irisSession`):
  - Legs: create with a generated secret, edit, secret masked and never pre-filled, Update JWKS from the in-container URL, delete from the editor, and the tab's name cell opening the editor.
  - `detectScreen` at 1280 light, 720 light and 1280 dark on all four tabs and the delete dialog.
- `ui/browser/structural-baseline.json`: exactly three `security/oauth/server-clients/edit` shell-chrome rows mirroring :1301-1333, and nothing else.
- `ui/angular.json` + `angular-json.test.mjs`: if the initial total crosses 1854kB, apply DW-1166 (5% above the measured total). HALT at 1900kB.

**Acceptance Criteria:**

- **AC1 (create).** Given an authorization server configuration, when the user chooses Create on the Server client descriptions tab, fills General, Client Credentials (Generate) and Client Information and saves, then:
  - the editor reads "Saved" at the new client id;
  - the tab lists the client;
  - `GET` returns every entered value;
  - the secret is stored.
- **AC2 (edit; AD-4).** Given a stored client opened from its name cell, when the user removes a redirect URL, adds one and changes a Client Information member, then `GET` shows exactly that, and every other field and `Metadata` member reads as before.
- **AC3 (delete).** Given a stored client, when the user deletes it from the editor or the row menu and types its client id, then it is gone.
- **AC4 (secret).** Given the client secret field, when a value is saved, then:
  - it is masked and never pre-filled, and the instance stores it;
  - no read, form read, screen context, proposal, ledger row, OcuPilot log line or masked audit read carries it or a secret `Metadata` member;
  - an empty field leaves it unchanged.
- **AC5 (JWKS update).** Given a client with a JWKS URL, when the user or a confirmed agent proposal updates its JWKS, then the stored public key set is refreshed and the outcome is reported. Without a URL it is refused by name.
- **AC6 (agent).** Given the five tools, when each is proposed and confirmed, then:
  - each write lands and is marked (AD-15);
  - the secret is asked at confirm, never stored, and its card is destructive with the effect named;
  - a create whose name is taken after the mint is refused at confirm (AD-54).
- **AC7 (privilege).** Given a caller missing either tab pair, when they read the form, save, use a row action or mint, then they are refused with a 403 naming the pair, before any port call. A caller holding exactly the two pairs completes AC1-AC5.
- **AC8 (link-out; AD-44).** Given the OAuth 2.0 screen, when it renders, then the server-client tab's name cell opens OcuPilot's editor, no OAuth tab carries a classic link, and the check reports two exemptions across two declarations.
- **AC9 (integration).** Given a client registered through this editor, when the agent proposes an authorization-server update (Story 12.7's consumer), then the card's `Clients` row names it.
- **AC10 (DW-1337).** Given the editor on each tab and its delete dialog, when it is measured at 1280 px light, 720 px light and 1280 px dark, then there is no structural or contrast violation.

## Spec Change Log

- 2026-09-25, lead spec gate: Q1-Q4 accepted as recommended (Q3 as option B with a named-gap refusal); AD-27, AD-32 and AD-35 amended.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-21, AD-24, AD-26, AD-27, AD-28, AD-29, AD-32, AD-35, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, and Conventions › Secrets.

- No AC contradicts an AD.
- AD-8 is not widened. The measured pair set is the tab's own.
- Every type is synchronous (AD-26).
- The DW-1337 gate applies.

**Spine change made at this plan (Rule 20):** AD-4 now lists `Security.OAuth2.ServerClients` as measured to keep omitted fields: `Metadata` merges by member, `RedirectURL` is replaced whole, the secret members are never sent, and it is not an upsert. The memlog is appended, and `lint_spine` shows only the existing `{id}` note.

**Measured on `ocupilot-b-ci`, 2026-09-25.**

- **Baseline.** The instance started with no configuration, no client and `/oauth2` present. At the end there was no configuration, no client and no probe principal, `/oauth2` was as found, and sign-in answered 200. Audit rows remain.
- **POST.**
  - `{Name}` alone answered 500 (#8866, #5659).
  - `{Name, ClientType:"resource"}` answered 201.
  - A second client with the same name answered 201.
  - A body carrying `ClientId` answered 400.
  - The answer carries no `ClientId` and no secret; `Location` carries the id.
- **PUT.**
  - `{Description}` kept everything else.
  - `RedirectURL` was replaced whole.
  - `Metadata` merged by member, and `""`, `[]` or `null` cleared a member.
  - An unknown top-level key or `ClientSecret` answered 400. An unknown `Metadata` member was ignored.
  - An absent client answered 404.
  - The whole `GET` re-sent left the secret unchanged.
  - `Metadata.client_secret` and `registration_access_token`, once PUT, were read back unmasked.
- **The secret type.**
  - `{}`, an extra key and a missing `clientId` answered 400.
  - A value answered 200, was stored, and was never read.
  - `""` or `null` cleared the stored secret.
  - Each change grows `SymmetricJWKS`.
- **JWKS.**
  - The admin API has no type for it. Setting `Metadata.jwks` or `jwks_uri` through `PUT` stores metadata only and leaves the public key set unchanged.
  - `RefreshJWKS("",1,1)` against `http://localhost:52773/oauth2/jwks` updated the set in 0.01 s.
  - An `https` URI with no configuration fails at once (#6159). An unreachable host fails with #6059 after about 10 s.
- **Privilege** (as the Constraints say). The X.509 list (admin 403, `ListDetails` #822) and `OAuth2.Server.Configuration.Open` were refused to the two-pair principal.
- **Audit.** `client_secret`, `ClientSecret`, `PublicJWKS` and `SymmetricJWKS` are masked by the vendor. `registration_access_token` is in plain text in "Modify OAuth2 Server Client" rows, as a `metadata.registration_access_token modified:` block and on the `Metadata:` line. `Metadata.jwks` is unmasked, and could hold symmetric keys (inference, not declared).
- **Vendor oddities, recorded and not fixed:**
  - `UpdateServerCors` keeps a previous client's port in `/oauth2`'s allow-list (:740-743).
  - `RedirectURL modified:` audit blocks are garbled.
  - `Location` names `/v1`.

**Form: four tabs, named and ordered as the classic editor's.**

1. **General**:
   - Name*, Description, and Client type (Confidential, Public, Resource server).
   - Redirect URLs (a list with Add and Remove; hidden for a resource server).
   - Grant types (five checkboxes) and Response types (four checkboxes).
   - Authentication type (five), and Authentication signing algorithm (shown for the two JWT methods and the JWT grant).
2. **Client Credentials**: Client ID (read-only, blank on a create), then Client secret (masked, Generate, Show/Hide, the shared hint on an edit).
3. **Client Information**: Launch URL, Client name, Logo URL, Client home page, Policy URL, Terms of service URL, Contact emails, Default max age, Default scope, Front-channel logout URL, and Front-channel logout session required.
4. **JWT Settings**: Public key source (None, JWKS URL, X.509 credentials), then JWKS URL or X.509 credentials, then the signing, key and content-encryption algorithms for the ID token, userinfo, access token and request object.

The action bar has Save (primary), Update JWKS and Delete. A new client takes the classic page's defaults (:716-731).

**Strings** (`oauthRegisteredClient*`; new keys only):

- The form title "Server client description", and the tab names "Client credentials", "Client information" and "JWT settings" (reuse where equal).
- The labels above that no existing key carries, "Add redirect URL", "Generate", "Show" and "Hide", and the option words.
- "Updated the client's public keys from its JWKS URL."
- "Saved. The client secret was not stored: {reason}"
- The field hint and card sentence: "The client's application must use the new secret from now on."
- The field sentence for each code.

**Bundle.** The branch measures about 1,765,300 bytes. 12.7's editor added about 60 KB for 68.7 KB of page and store source. This editor reuses `app-form-tabs`, 12.7's list-row markup, the typed-name dialog and `handler.sendFor`, with no new component, so the estimate is 55-65 KB, or about 1,825 KB (inference). That is under the 1854kB warning and 75 KB under the 1900kB stop.

**Integration ACs.**

- Consumes:
  - Story 6.4's tab and 7.3's delete tool;
  - AD-53's route and handler, and AD-55's Save;
  - the X.509 list's declared read;
  - 12.7's probe helpers;
  - the installer's SSL/TLS configuration;
  - `app-form-tabs`.
- Introduced: `OAuthRegisteredClientPort`, the form descriptor, four tools and three routes, consumed here by the editor, the row actions and agent dispatch (AC1-AC7). Story 12.7's authorization-server tools also consume the client list it writes (AC9).
- Consumed-by: Story 12.9, which records the closed OAuth link-out risk.

**Ledger inbox:** none.

**Expected `footprint_extensions`:**

- `AdminPort.cls`, `AuditPort.cls`, `Prohibited.cls`, `Router.cls`, `Error.cls`, `Classification.cls`/`ToolFields.cls`.
- `screen-outlet.ts`, `screen-actions.ts`, `proposal-view.ts` (+ tests), `app.ts`/`app.spec.ts`, `strings.ts`, `_components.scss`, `screens.generated.ts`.
- EXPERIENCE.md; the spine (AD-4 at this plan, AD-44 at implement) and `.memlog.md`; `structural-baseline.json`; the budget pair.
- `classic-links.{mjs,test.mjs}`, `navigation.test.mjs`, the five OAuth browser specs, the roster files, and `scripts/ci-throwaway.sh`.

**What Story 12.9 is left with.** After this story no OAuth tab declares the exemption, and every name cell opens an editor. 12.9 keeps three things:

- recording the closed Release 1 risk (its AC3);
- retiring leftover exemption prose (`classic-links.mjs` :18-19 if not done here, and `OAuthTabs`' comment);
- correcting its own text. AC2's "the count returns to zero" is wrong while `ServiceForm` and `LdapConfigForm` keep their exemptions until 16.13/16.14, and DW-1643's "removes the remaining three" is stale. That is the lead's amendment to make.

**Lead answers at the spec gate (2026-09-25):**

- Q1: accepted. AD-27 names Story 12.8's case (Update JWKS through `OAuth2.Server.Client.RefreshJWKS` in `%SYS`); spine amended at the gate.
- Q2: accepted. AD-35's fourth declaration masks `registration_access_token` in "Create/Modify OAuth2 Server Client" rows; spine amended. Append the `VENDORSECRETS` entry, its seeded-row test on both reads, and move the control row to an undeclared event.
- Q3: accepted (B). AD-32 now says the installer-created configuration also serves this fetch, with a named gap: a key-set URI only the authorization server's own configuration trusts is refused by name (give it its own code and a test). No pair beyond the tab's; no caller choice.
- Q4: accepted. The create's absence fingerprint covers the intended `Name` (AD-54 as written); a registered name is refused on both callers.
- AD-44: drop `OAuthServerClientTab`'s declaration in the implement pass; the OAuth exemption then has no declarations and leaves AD-44's list (two exemptions remain, `ServiceForm` and `LdapConfigForm`, removed by 16.13/16.14). Update the spine sentence (Rule 20: replace, do not annotate) and every roster pinning the honored set or the counts.
- Bundle: re-base per DW-1166 past 1854kB; HALT at 1900kB.
- `structural-baseline.json`: only the shell-chrome rows every route carries (DW-1583/DW-1584) may be added for the new route.

**Open questions for the lead** (the spec is built on each recommendation):

- **Q1, AD-27 (Rule 20).** Name Story 12.8's case: `OAuthRegisteredClientPort` completes Update JWKS through `OAuth2.Server.Client.RefreshJWKS(<ssl>,1,1)`, and reads its result (`JwksUri`, `ClientCredentials`, a public-key count) through `OAuth2.Server.Client`. It does both in `%SYS`, after repeating the endpoint's `%Admin_OAuth2_Registration:USE` gate. The admin API has no JWKS type (measured), and a two-pair principal succeeded.
- **Q2, AD-35 (Rule 20).** Add a fourth declaration: "Create OAuth2 Server Client" and "Modify OAuth2 Server Client" rows mask `registration_access_token`. It was measured in plain text in Modify rows; the Create row is inference. Today those rows resolve to the "OAuth2 Server" entry and pass the token through unmasked (measured).
- **Q3, TLS for the JWKS fetch (AD-8 / AD-32).** The recommendation is OcuPilot's own installer-created client configuration for an `https` URI, and none for `http`. It declares no pair beyond the tab's and takes no caller choice; peer verification is on and AD-10 protects the configuration. It extends AD-32's configuration beyond `ProviderPort`, which the spine would then say.

  The alternatives:
  - (A) The vendor's own choice, the authorization server configuration's `SSLConfiguration`. This needs `%Admin_OAuth2_Server:USE` on the JWKS tool (AD-8's endpoint clause, through `Security.OAuth2.Server` `GET`), and you have reserved AD-8 widening. The classic button needs it too.
  - (C) A caller-named configuration as a declared non-secret argument, which is AD-51's third case.
- **Q4, AD-54 (create identity).** The recommendation is that a create's absence fingerprint covers the intended `Name`, so a name already registered is refused on both callers, although the vendor allows duplicates (measured). The alternative is to permit duplicates as the vendor does. That needs an AD-54 amendment, since a vendor-generated id has no absence to fingerprint and a POST can never overwrite.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. OAuth-writing tests run on `ocupilot-b-ci` only (52777/1976), one class per call, each awaited in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the deployed bundle is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth-registered-client-editor.browser-spec.mjs browser/oauth.browser-spec.mjs browser/oauth-server-editor.browser-spec.mjs browser/oauth-resource-server-editor.browser-spec.mjs browser/oauth-client-editor.browser-spec.mjs browser/oauth-server-description-editor.browser-spec.mjs browser/oauth-delete.browser-spec.mjs` (loop) -- expected: every leg passes.
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class <C>` (loop), one call each for:
  - the five `OAuthRegisteredClient*` classes (`Wire` armed);
  - `AuditVendorSecrets`, `OAuthTabs`, `OAuthDelete`, `OAuthAuthorizationServerClients`, `ToolRoundTrip`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `PortFixture`, `Prohibited`, `Descriptor`, `DerivedFields`, `Wire`, `WireOAuthRead`, `WireSecurityRead`.

  Expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, with the bundle total recorded.
- The full browser suite is CI's (Rule 29, owner instruction 2026-09-22).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

| AC | Mutation |
| --- | --- |
| AC1 | The Save's create skips the secret write |
| AC2 | The update sends `Metadata` as `{}` over the fresh read (members read back cleared) |
| AC3 | The page's delete skips the typed-name dialog |
| AC4 | The port's `GET` stops stripping `Metadata.client_secret` |
| AC5 | The port's `REFRESHJWKS` answers 200 without the vendor call |
| AC6 | `CREATES` 0 on the create tool |
| AC7 | Remove the form route's gate |
| AC8 | Restore the tab's exemption |
| AC9 | 12.7's port answers `Clients` as `[]` |
| AC10 | A 1400px `min-inline-size` on the redirect URL list |

**Measure in implement and record here:** the bundle total; how the stub `%response` exposes `Location`; whether the vendor `LIST` tolerates the create read's row-key filter; whether a "Create OAuth2 Server Client" row carries `registration_access_token`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
