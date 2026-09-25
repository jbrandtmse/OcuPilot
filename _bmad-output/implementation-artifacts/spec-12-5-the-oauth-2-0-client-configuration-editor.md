---
title: 'Story 12.5: The OAuth 2.0 client configuration editor'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-4-the-oauth-2-0-client-server-description-editor.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Client configurations tab can only list and delete. Its name cells link out to the classic Client Configuration page, so nobody can create a client, edit its settings, set its secrets, register it dynamically or rotate its keys inside OcuPilot.

**Approach:** Add a `form-page` editor at `security/oauth/clients/edit`, opened from the tab's name cell and a new Create action. It round-trips create, edit and delete over `Security.OAuth2.Client.ClientConfiguration` through the two fixed mechanisms: Save through the write tools (AD-55, create per AD-54), and Delete, Rotate Keys and Register as the tab's row actions (AD-53). The admin API carries every operation (`PUT`, `CHANGESECRET`, `ROTATEKEYS`, `REGISTERCLIENT`, `DELETE`), so no AD-27 case is added. A new `OAuthClientPort` strips the two secrets the vendor's GET returns in plain text.

## Boundaries & Constraints

**Always:**

- **Identity.** The id is `ApplicationName`, the vendor's IdKey, sent as the `applicationName` query. The vendor's lookup is exact (measured), so the id canonicalizes to itself and needs no `IDRULES` entry. The body cannot carry it, so the name is fixed after create and the editor shows it read-only.
- **Secrets are write-only (AD-3, AD-35, AD-56).** There are four, all masked, never pre-filled, never in a proposal's arguments, a diff, the ledger, screen context, a log line or a status:
  - `ClientSecret`, `ClientPassword` (the private-key password for `ClientCredentials`) and `RegistrationAccessToken` go through one `CHANGESECRET` write. Its body holds only the supplied ones. The port nests `RegistrationAccessToken` as `Metadata.registration_access_token`.
  - `InitialAccessToken` belongs to the client's server description. The client Save stores it through Story 12.4's `OAuthServerSave.StoreToken`, whose tool is `security.oauthserverdescriptions.settoken`. Dynamic registration presents it as the Bearer (Q2).
  - An empty field means "leave the stored value unchanged". Nothing is ever cleared.
- **No read returns a secret.** The vendor GET answers `Metadata.client_secret` and `Metadata.registration_access_token` in plain text (measured). `OAuthClientPort` removes both from every `GET` it answers, so the mint, the confirm, the form read and the delete tool all see a stripped read. The delete tool moves to this port.
- **Save sends the complete property set (AD-4).** It reads fresh, applies the diff and sends every template field. `Metadata` expands to every derived member, with each absent one in its empty form (`""`, `[]`), with three exceptions:
  - The two secret members are **never** sent: `""` would erase the stored secret.
  - The four registration-managed members (`client_id`, `registration_client_uri`, `client_id_issued_at`, `client_secret_expires_at`) are sent **as the fresh read has them**, whatever the arguments hold. An argument cannot clear a client's registration.
- **Create is `PUT`, an upsert (measured: 201 on an absent name).** AD-54's absence fingerprint is therefore load-bearing, and the Save's create path refuses a taken name before any port call.
- **Form rules** are enforced identically by each tool's `ArgumentProblem` and by the Save route, and written once on the server as `detail.violations[]` (AD-39). They apply every refusal the vendor would otherwise answer 500 for (measured), so no such 500 reaches a person:
  - `ApplicationName`: required, 1 to 128 characters, no control character, and not taken (on create).
  - `ServerDefinition`: required, and must be an existing server description's `ID`.
  - `ClientType`: one of `confidential`, `public`, `resource`.
  - `SSLConfiguration`: required.
  - `RedirectionEndpoint`: required unless `ClientType` is `resource`, and must be an absolute `http`/`https` URL with a host.
  - `ClientCredentials`: empty, or an X.509 credential with a private key.
  - `JWTInterval` and `Metadata.default_max_age`: integers.
  - A `Metadata` key must be a settable derived member with the member's shape. A `VALUELIST` member takes one of its values.
- **Rotate Keys** is an AD-51 action (`ROTATEKEYS`). It is refused by name while `ClientCredentials` is set: the vendor answers 200 there and changes nothing (measured).
- **Register** is an AD-51 action (`REGISTERCLIENT`). It is refused by name when the client already has a `ClientId` or a `registration_client_uri`, or when its server description has no `registration_endpoint`.
- **A Save of a registered client** makes the vendor save locally and then PUT to the registration client URI. When that PUT fails, the vendor answers 500 with the local change already stored (measured). The port recognises this case by re-reading and finding every sent field stored. It then answers success with a `registrationNotUpdated` notice, so neither the ledger nor the page reports a stored write as failed.
- **No gratuitous vendor saves.** A vendor save re-dumps the registration access token into audit (DW-1640, measured). So:
  - a secrets-only edit sends no PUT;
  - an empty `CHANGESECRET` body is refused by the port (the vendor saves on `{}`);
  - no initial-token write happens without a value.
- **Delete.** Keep Story 7.3's tool, row action and consequence string unchanged, except for the port move above.
- **Privileges.** Every tool, route and port call requires the tab's pair set, `%Admin_OAuth2_Client:USE` + `%DB_IRISSYS:READ` (AD-8). Screen writes emit no marker (AD-53), and agent confirms do (AD-15).
- **Change events.** Every write publishes `(oauth2-client-configuration, instance, <name>)`. A stored initial token also publishes the server description's event.
- **UI.** Tokens only, and the dark theme is correct. The editor's own content gets no DW-1337 allowance. Non-ASCII in code is written as `\u` escapes.

**Never:**

- No third write mechanism.
- No AD-27 vendor-class call.
- No "Get Updated Metadata" (`ReadClient`). The admin API has no such type, so it stays classic-only as a named gap.
- No second tab component. No adoption of `form-tabs` (Q1).
- No suggested prompts, because Story 11.3's key is absent.
- No change to the other three OAuth tabs' links (that is Story 12.9).
- No change to Epic 9's editors.
- No OAuth-writing test on `ocupilot-slot-b`.
- No internet dependency in any test.
- No DW-1640 fix.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | New name, a server description, `confidential`, SSL, redirect URL, grant types | 201; the editor reopens on `security/oauth/clients/edit/<name>` reading "Saved"; the tab lists it | None |
| Create, name taken | Existing name | 422 on `ApplicationName`; the existing client is unchanged | Before any port write |
| Edit, partial | Description changed, `contacts` cleared | GET shows exactly that; every other field and member is unchanged, including the vendor's algorithm defaults | None |
| Edit, bad value | `ClientType` "bogus", a bad alg, `JWTInterval` "abc", an unknown credential | 422 on the named field; nothing sent | Form rule (vendor answers 500) |
| Secrets | Secret, password, token and initial token entered | Stored (lengths > 0); no read, form read, context, ledger row or log line carries any of them; empty fields send nothing | A write failing after the save → "Saved. …: {reason}" |
| Secrets-only edit | Only the client secret entered | One `CHANGESECRET`; no `PUT` | None |
| Rotate Keys | Client without `ClientCredentials` | 200; `PublicJWKS` changed; "Rotated this client's keys." | Refused by name while `ClientCredentials` is set; the button is hidden |
| Register | Unregistered client; the server description's `registration_endpoint` points at the local fixture | 200; the page reports the issued client ID; the fixture received the initial token as Bearer | No endpoint / already registered → refused by name; fixture stopped → named refusal |
| Save, registered, server down | `registration_client_uri` unreachable | Saved; the page shows the not-updated notice; the ledger records the write as applied | Port re-read |
| Delete | From the editor or the row menu, name typed | Gone from the tab and the instance | Existing 7.3 behavior |
| No privilege | Caller lacks `%Admin_OAuth2_Client:USE` | 403 naming the pair on the form read, Save routes, row actions and mint | Before any port call |

</intent-contract>

## Code Map

**Vendor (hidden; read on `ocupilot-slot-b` in `%SYS` with `GetTextAsString`).** `%Api.Admin.Endpoints.Security.OAuth2.Client.ClientConfiguration`:

- Types:

  | Type | Id | Route | Method |
  | --- | --- | --- | --- |
  | LIST | 0 | `…/client/client-configurations?serverId=` | GET |
  | GET | 1 | `…/client-configuration?applicationName=` | GET |
  | PUT | 2 | `…/client-configuration?applicationName=` (upsert; `RunPut` :122-185) | PUT |
  | DELETE | 3 | `…/client-configuration?applicationName=` | DELETE |
  | CHANGESECRET | 10 | `…/client-configuration/secrets` (:211-234; schema :251-257 `{ClientSecret, ClientPassword, Metadata:{registration_access_token}}`; unknown keys 400) | POST |
  | ROTATEKEYS | 11 | `…/client-configuration/rotate-keys` (:98-108, `obj.RotateKeys()`) | POST |
  | REGISTERCLIENT | 12 | `…/client-configuration/register-client` (:110-120, `obj.RegisterClient()`) | POST |

- `ResourcesOR()` is `%Admin_OAuth2_Client` for every type. Every type is synchronous.
- Template (`PutRequestBodySchema` :187-209): `ServerDefinition, Enabled, Description, ClientType, SSLConfiguration, RedirectionEndpoint, JWTAudience, JWTInterval, ClientId, ClientCredentials, DefaultScope, Metadata:{}`.
- GET answers exactly the template keys: `ServerDefinition` as the row id in a string, and `Metadata` with its empty members omitted.
- After a save, PUT calls `UpdateClient()` (an outbound PUT) when `registration_client_uri` is set (:175-180).

Supporting vendor classes:

- `irissys/OAuth2/Client.cls`:
  - `RegisterClient` :362-458: saves, POSTs `Metadata` to `registration_endpoint` with `Bearer <ServerDefinition.InitialAccessToken>`, imports `client_id`/`client_secret`/`registration_access_token`, and saves again.
  - `RotateKeys` :787-806.
  - `DeleteId` :1180-1220.
  - `GetAuditMessages` :1245-1294 masks the secret, the password and the JWKS.
  - `%OnValidateObject` :1039-1062.
- `irissys/OAuth2/Client/Metadata.cls`: 42 members (uris, `%List` ×7, `%Integer` ×3, `%Boolean` ×2, `jwks` JSON, 13 `VALUELIST` algorithm strings). `OAuth2.Metadata.GetAuditMessages` masks only `client_secret`.
- Classic page `irissys/%CSP/UI/Portal/OAuth2/Client/Configuration.cls`:
  - Tabs at :81: General :90-127, Client Information :139-148, JWT Settings :160-191, Client Credentials :204-208.
  - Register :363-400/:976-1011; Rotate :835-872 (shown only when `'JWKSFromCredentials`); validation :415-545; `RESOURCE` `%Admin_OAuth2_Client`.

**Models to copy (Story 12.4).**

- `Port/OAuthServerPort.cls`: `Invoke` :69-191, `VendorBody` :279, `CredentialOk` :288, `Violation` :297, `GateRefusal` :311.
- Tools `Screen/Tool/OAuthServerDescription{Create,Update,Delete,UpdateJwks,SetToken}.cls`: `Described`, `RuleProblem`, `DerivedFields`→`Expand`, `StateDiff`.
- `Area/Security/OAuthServerRules.cls`: `Members` :62, `TemplateFields` :95, `Validate` :172, `MemberViolations` :278, `Expand` :315, `HandleForm` :349, `ReadableNames` :407.
- `Area/Security/OAuthServerSave.cls`: `HandleCreate` :75, `HandleUpdate` :116, `Create` :212, `Update` :253 (the empty-body early return), `MergedMetadata` :309, `StoreToken` :332, `TakeSecret` :451, `Answer` :425.
- Descriptors `OAuthServerDescriptionForm.cls` and `OAuthServerDescriptionTab.cls`. Router :146-149 with wrappers :474-495. `Api/Error.cls` :2266-2388, whose `OAUTH.` dispatch is at :1067.
- Client:
  - `oauth-server-description-form.store.ts`: `open` :411, `save` :523, `publish` :705, token :441/:540.
  - `…page.ts`: `onSave` :675, `onUpdateJwks` :694, delete :714-740, `controlId` :813.
  - `oauth-actions.ts`.
  - `app.ts`: injected at :256-257, reset at sign-out at :541, pinned in `app.spec.ts` :1054-1130.
- `Kernel/Proposal/Operation.cls` `SecretBody` :113 takes a comma list in `SECRETBODY`. `Api/ScreenAction.cls` :261.

**This story's surfaces.**

- `Screen/Descriptor/OAuthClientTab.cls`:
  - `primaryAction ""` and `rowActions [delete]`.
  - Exemption :47-53 with `rowLink` PID/IssuerEndpointID/IssuerEndpoint.
  - The read is LIST `forEach` over server definitions, giving `ServerDefinitionID` and `IssuerEndpoint`.
- `Screen/Tool/OAuthClientDelete.cls`: `READANSWERS` :51 excludes `Metadata`; no `PORTCLASS`; `IdArgument`/`IdParam` :74/:80.
- `Screen/Tool/FieldLists.cls` :209-222 has the client template list. `Test/FieldDerive.cls` `ClassRows` :305, with the server-metadata call at :133 as the precedent.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :174 already covers `oauth2-client-configuration`.
  - `PermittedChangeFields` :390 and `PermittedCreateFields` :463 return `""` for it (pinned by `Test/OAuthDelete.cls` :130).
  - Branch :620-627; `OAuthEntry` :1199.
- `Port/AdminPort.cls`: `MUTATINGTYPES` :261 and `BODYLESSTYPES` :277 hold only `ClientConfiguration/DELETE`.
- `ui/src/app/core/strings.ts`: the 12.4 block is :1733-1783, `} as const` is :1785, and the client strings are :1562-1572. EXPERIENCE.md Fixed strings: the last row is :471.
- `ui/src/app/core/navigation.ts` `editorScreenFor` :177 / `createFormFor` :188 pair `<list>/edit` by convention (inference).
- Tests to update:
  - `Test/OAuthTabs.cls` (`EDITEDTAB` :30, `Tabs` :82, exemption asserts :199-205);
  - `Test/OAuthDelete.cls` :193-232 (write-tool half rosters);
  - `ui/tools/classic-links.test.mjs` :439-461;
  - `ui/browser/oauth.browser-spec.mjs` :347-349;
  - `oauth-server-description-editor.browser-spec.mjs` `CLASSIC_TABS` :54.
- Fixture `Test/OAuthIssuerFixture.cls`:
  - `Start`/`Stop` :42/:61; `Serve` :86 reads only the request line.
  - `Answer` :143 serves the discovery, `/jwks` and fault paths.
- Probe helpers: `Test/OAuthServerProbe.cls` (`Add`, `AddClient` :76, `RemoveAll` :216) and `Test/OAuthProbe.cls`.
- `ui/browser/structural-baseline.json` :1323-1355 holds the three `security/oauth/edit` shell entries to mirror.
- Budget: `ui/angular.json` :53-55 (1378kB/1600kB), pinned at `ui/tools/angular-json.test.mjs` :371-372.
- **Epic 9 (`origin/OCU-1-epic9`)**:
  - Hunks: `Router.cls` +149,13 (routes appended after the OAuth routes), `screen-outlet.ts` +118,25, `Classification.cls` +339,54, and the tails of `strings.ts` and `_components.scss`.
  - `AdminPort` single lines, `Prohibited.cls` throughout.
  - `form-tabs` is at `shell/form-tabs.ts` (120 lines) and `core/form-tabs.ts` (64).
  - `Write.MergeUpdate` is at `Write.cls:317`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Test/FieldDerive.cls`:
  - Add the class-sourced list `Security.OAuth2.Client.ClientConfiguration:OAuth2.Client.Metadata` (envelope `Metadata`), beside the server list.
  - Emit each member's kind (`uri`/`text`, `list`, `integer`, `flag`) and a `VALUELIST` member's values.
  - Run `scripts/field-lists.sh` and `node tools/field-lists.mjs`, then regenerate `FieldLists.cls` and `ToolFields.cls`.
  - The member set is derived, never typed (AD-3).
- `src/OcuPilot/Port/OAuthClientPort.cls` (new, extends `AdminPort`; add it to `Test/PortGate.cls` `ROSTER`). For `Security.OAuth2.Client.ClientConfiguration`:
  - `GET`: remove `Metadata.client_secret` and `Metadata.registration_access_token`.
  - `PUT`:
    - `CredentialOk` first, as 12.4 does (a failure is a violation on `ClientCredentials`).
    - A vendor 500 on a client whose fresh read has `registration_client_uri`: re-read, and when every sent field is stored, answer 200 with `registrationNotUpdated`.
    - Any other 500 → `OAUTH.CLIENTVALIDATION`, with the raw text in the log only.
  - `CHANGESECRET`: build `{ClientSecret?, ClientPassword?, Metadata:{registration_access_token?}}` from the flat names. Refuse an empty body.
  - `REGISTRATION` (a synthesized read): `{ClientId, RegistrationClientUri, ServerDefinition, RegistrationEndpoint}`. The endpoint comes from the server definition's admin `GET` (`serverId`).
  - `REGISTERCLIENT`: the vendor's #8881 → `OAUTH.CLIENTNOREGISTRATIONENDPOINT`; any other failure → `OAUTH.CLIENTREGISTRATIONFAILED`, raw text logged only.
  - Everything else goes to `##super`.
  - Append `ClientConfiguration/PUT`, `/CHANGESECRET`, `/ROTATEKEYS` and `/REGISTERCLIENT` to `AdminPort` `MUTATINGTYPES`, and `/ROTATEKEYS` and `/REGISTERCLIENT` to `BODYLESSTYPES` (contended; single lines).
- `src/OcuPilot/Screen/Tool/OAuthClient{Create,Update,SetSecrets,RotateKeys,Register}.cls` (new). Common to all: `DESCRIPTORCLASS` is `OAuthClientTab`, `PORTCLASS` is `OAuthClientPort`, `IdArgument` is `ApplicationName`, `IdParam` is `applicationName`, and the names are `security.oauthclients.<verb>`. Every `DESCRIPTION` says nothing changes until the user confirms.

  | Tool | Parameters | Notes |
  | --- | --- | --- |
  | Create | `CREATES` 1, `READTYPE` GET, `WRITETYPE` PUT, `SENDSBODY` 1, `CHANGEACTION` created | Schema members come from the derived list, minus the secret and registration-managed members |
  | Update | `READTYPE` GET, `WRITETYPE` PUT, `SENDSBODY` 1 | The same rules; `DerivedFields` → `Expand(fresh, args)` per the Always rule |
  | SetSecrets | `WRITETYPE` CHANGESECRET, `SECRETBODY` `ClientSecret,ClientPassword,RegistrationAccessToken`, `READTYPE` GET | `READANSWERS`/`FINGERPRINTSUBJECT` are `ServerDefinition,ClientType` and `PRECONDITIONFIELD` is `ClientType`, as for the delete. The GET does not answer `ApplicationName` |
  | RotateKeys | `READTYPE` GET, `READANSWERS`/`FINGERPRINTSUBJECT`/`PRECONDITIONFIELD` `ClientCredentials`, `WRITETYPE` ROTATEKEYS, `SENDSBODY` 0, `SCREENACTIONS` rotatekeys | Precondition: `ClientCredentials` is empty |
  | Register | `READTYPE` REGISTRATION, subject `ClientId,RegistrationClientUri,RegistrationEndpoint`, `PRECONDITIONFIELD` `ClientId`, `WRITETYPE` REGISTERCLIENT, `SENDSBODY` 0, `SCREENACTIONS` register | The description says it calls the authorization server and replaces the client's ID and secret |

- `src/OcuPilot/Screen/Tool/OAuthClientDelete.cls` -- set `PORTCLASS` to `OAuthClientPort`. Nothing else changes.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add entries after :385:
  - create and update: `Metadata` opaque, the rest ordinary;
  - setsecrets: the three secrets, authored.

  Regenerate `ToolFields.cls`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `PermittedChangeFields` and `PermittedCreateFields` for `oauth2-client-configuration` answer the twelve template fields (contended, own lines). Nothing is self-protective.
- `src/OcuPilot/Screen/Descriptor/OAuthClientForm.cls` (new):
  - Route `security/oauth/clients/edit`, `form-page`, position 0.
  - The tab's pairs; `entityType` `oauth2-client-configuration`, scope `instance`, `id single`.
  - `context.secretFields` holds the four secrets; `secretArguments []`.
  - `classicPage` `%CSP.UI.Portal.OAuth2.Client.Configuration`, `toolIdentifier` `security.oauthclientform`.
- `src/OcuPilot/Screen/Descriptor/OAuthClientTab.cls`:
  - Set the exemption to `exempt: false`, as 12.4 did.
  - `primaryAction create`, `rowActions [delete, rotatekeys, register]`.
  - `secretArguments [ClientSecret, ClientPassword, RegistrationAccessToken]`.
  - Rewrite the link paragraph of the doc comment, then regenerate `screens.generated.ts`.
- `src/OcuPilot/Area/Security/OAuthClientRules.cls` and `OAuthClientSave.cls` (new, modeled on the 12.4 pair):
  - The form read answers the fields (no secret) plus these readable name lists, each through its screen's own read (AD-5): server descriptions (`ID`, `IssuerEndpoint`, `registration_endpoint` present), SSL configurations, and X.509 aliases with a private key.
  - Save order:
    1. `PUT`, only when the diff is non-empty;
    2. `SetSecrets`' operation, only when a secret was supplied;
    3. `OAuthServerSave.StoreToken` with the chosen description's issuer, only when an initial token was supplied.
  - A step failing after an earlier one succeeded answers the saved entity plus `secretsRefused`/`tokenRefused`.
  - `registrationNotUpdated` is passed through.
- `src/OcuPilot/Api/Router.cls` (append after the 12.4 block) -- `GET /oauth/client-configuration/form`, `PUT /oauth/client-configuration/:id`, `POST /oauth/client-configuration`, each with a thin wrapper. The form route goes before `:id`.
- `src/OcuPilot/Api/Error.cls` (own entries). Each code gets its reason:
  - `OAUTH.APPLICATIONNAME.{REQUIRED,SHAPE,TAKEN,ABSENT}`;
  - `OAUTH.SERVERDEFINITION.{REQUIRED,ABSENT}`, `OAUTH.CLIENTTYPE.VALUE`, `OAUTH.REDIRECTIONENDPOINT.{REQUIRED,SHAPE}`;
  - `OAUTH.CLIENTCREDENTIALS.ABSENT`, `OAUTH.JWTINTERVAL.SHAPE`, `OAUTH.METADATA.VALUE`;
  - `OAUTH.CLIENTVALIDATION`, `OAUTH.CLIENTNOSECRET`, `OAUTH.CLIENTKEYSFROMCREDENTIALS`;
  - `OAUTH.CLIENTREGISTERED`, `OAUTH.CLIENTNOREGISTRATIONENDPOINT`, `OAUTH.CLIENTREGISTRATIONFAILED`.
- `ui/src/app/areas/security/oauth-client-form.{store,page}.ts` (+ specs) and `oauth-actions.ts` (the client tab's Create through `createFormFor`):
  - The sections follow Design Notes.
  - Register is shown when the client is saved, not dirty, has no `ClientId` and no registration URI, and its description has a registration endpoint. It fires `handler.sendFor(OAuthClientTab,'register')` and reports "Registered with {issuer}. Client ID: {clientId}.".
  - Rotate Keys is shown when the client is saved, not dirty and has an empty `ClientCredentials`. It fires `'rotatekeys'`.
  - Delete takes the typed name.
  - The change event, the unsaved guard, "Saved", and a create followed by `replaceUrl`.
  - In `app.ts`, inject the store and reset it at sign-out; pin that in `app.spec.ts`.
- `ui/src/app/shell/screen-outlet.ts` (page entry), `ui/src/app/core/screen-actions.ts` (the Rotate Keys and Register labels) -- own lines only. `screen-action-handler.ts` needs no change: `OAuthClientTab` is already in `SCREEN_ACTION_DESCRIPTORS` :42 and in `DESTRUCTIVE_CONSEQUENCES` :150, and neither new action is destructive.
- `ui/src/app/core/strings.ts` (after :1783), EXPERIENCE.md (a row after :471: Story 12.5, FR-44) and `_components.scss` (own `ocu-oauth-client-*` classes) -- the Design Notes strings.
- `src/OcuPilot/Test/OAuthIssuerFixture.cls`:
  - `/register` answers 201 with synthetic `ocupilot…probe000…` `client_id`, `client_secret`, `registration_access_token` and a `registration_client_uri` of `http://localhost:<port>/register/<id>`.
  - `/register/<id>` answers 200 with the same JSON for any method.
  - The fixture drains a request body.
  - It records the last `/register` `Authorization` header's hash in `^IRIS.Temp.OcuPilotIssuer(port,"auth")`.
- Tests (new; each under 500 lines, one class per call, `ocupilot-b-ci` only; helper `Test/OAuthClientProbe.cls` with `RemoveAll`):
  - `Test/OAuthClientCreate`: declarations, create through the route, a taken name, every form rule on both callers, a create taken after the mint refused at confirm.
  - `Test/OAuthClientUpdate`: the complete set, clearing a member, algorithm defaults kept, registration-managed members kept against an agent `Metadata` without them.
  - `Test/OAuthClientSecrets`: stored, never read back through the port, form read, context, ledger or log; a secrets-only edit sends no PUT; an empty body is refused; the initial token reaches the description.
  - `Test/OAuthClientKeys`: rotate changes `PublicJWKS`; refused while credentials are set; the agent confirm.
  - `Test/OAuthClientRegister`: against the fixture, `ClientId` is set, no secret is readable, and the Bearer matches the initial token; refusals for no endpoint and already registered; a stopped fixture; the not-updated Save.
  - `Test/OAuthClientWire`: arms `OCUPILOT_ALLOW_PRINCIPALS`; 403s naming the pair; each tool minted and confirmed with a marker; screen writes leave no marker.
- Roster updates (own rows):
  - `PortGate`, `PortFixture` `MUTATINGTYPES`, `ToolRoundTrip` `REFUSEEMPTY`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `RouterFixture`, `Test/Prohibited`, `DerivedFields`;
  - `OAuthTabs` (the client tab becomes edited, with its row actions);
  - `OAuthDelete` half rosters and :130's `""`;
  - `Wire*` screen lists, `classic-links.test.mjs` (three descriptors), `navigation.test.mjs`;
  - `oauth.browser-spec.mjs` and the 12.4 editor spec's `CLASSIC_TABS`;
  - `scripts/ci-throwaway.sh` armed classes.
- `ui/browser/oauth-client-editor.browser-spec.mjs` (new; `assertThrowaway`, starts and stops the fixture through `irisSession`):
  - Legs: create, edit, secrets (masked and not pre-filled), register, rotate keys, delete from the row menu, and the other three tabs keeping classic links.
  - DW-1337 `detectScreen` at 1280 light, 720 light and 1280 dark, and on the delete dialog.
  - **Every load wait must fail while its element is absent**: `(el?.value ?? '') !== ''` or an explicit presence check, never `el?.value !== ''` (Story 12.4's CI failure).
- `ui/browser/structural-baseline.json` -- add exactly three `security/oauth/clients/edit` entries mirroring :1323-1355 (DW-1583 at 1280 and 720, DW-1584 at 720), and nothing for the editor's own content.
- `ui/angular.json` + `ui/tools/angular-json.test.mjs` -- if the initial total crosses 1378kB, apply DW-1166: 5% above the measured total, the value line and the pinned literal. Crossing 1500kB is a stop-and-ask.

**Acceptance Criteria:**

- **AC1 (create).** Given the Client configurations tab, when the user chooses Create, fills the General fields and saves, then the editor reopens on the new client reading "Saved", the tab lists it, and GET returns every entered value.
- **AC2 (edit, AD-4).** Given a client opened from its name cell, when the user changes one field, clears a `Metadata` list and saves, then GET shows exactly that, and every other field and member reads as before.
- **AC3 (delete).** Given a client, when the user deletes it from the editor or the row menu and types its name, then it is gone from the tab and the instance.
- **AC4 (secrets).** Given the client secret, key password, registration access token and initial access token fields, when values are entered and saved, then each is masked and never pre-filled, the instance stores each, and no read, form read, screen context, proposal, ledger row or OcuPilot log line carries any of them.
- **AC5 (registration).** Given an unregistered client whose server description has a registration endpoint (the local fixture), when the user runs Register, then the client is registered, the page reports its client ID, and the initial access token was presented. A registered client, or one without an endpoint, offers no Register.
- **AC6 (Rotate Keys).** Given a client without X.509 credentials, when the user runs Rotate Keys, then its public key set changes and the page reports it. A client with credentials offers no Rotate Keys and is refused by name.
- **AC7 (agent).** Given the agent proposes create, update, setsecrets, rotatekeys and register, when the user confirms, then each write lands and is marked (AD-15). Secrets are asked at confirm and never stored. A create whose name was taken after the mint is refused at confirm (AD-54).
- **AC8 (privilege).** Given a caller without `%Admin_OAuth2_Client:USE`, when they read the form, save, run a row action or mint, then the request is refused 403 naming that pair before any port call.
- **AC9 (link-out).** Given the OAuth 2.0 screen, when it renders, then this tab's name cell opens OcuPilot's editor, the other three tabs keep their classic links, and the classic-links check reports one exemption across three descriptors.
- **AC10 (DW-1337).** Given the editor and its delete dialog, when they are measured at 1280 px light, 720 px light and 1280 px dark, then there is no structural or contrast violation.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-24, AD-26, AD-27, AD-29, AD-35, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56. The DW-1337 gate applies. No AC contradicts an AD. AD-24's `tools` and `readOnly` are derived by the kernel: declare the actions in the registry and nothing else.

**Measured on `ocupilot-b-ci`, 2026-09-25.** A scratch description and client were used and then deleted; the vendor tables read 0 rows afterwards.

- **Omitted fields.** A PUT carrying only `Description` kept every other field and member.
- **Metadata.** `Metadata` merges per member: `""`, `[]` and `null` clear a member, `false` is stored, and an unknown member is ignored. Create sets 13 algorithm defaults (for example `RS256`).
- **Vendor 500s.** Each of these answers 500 and stores nothing:
  - no `ClientType` on create, and a bad `ClientType`;
  - a bad alg (`VALUELIST`), `JWTInterval` "abc" and `default_max_age` "abc";
  - an unusable credential (#8885);
  - an unparsable redirect (#8850).
- **Vendor 4xx answers.** A bad `ServerDefinition` answers 422, and an unknown top-level key answers 400.
- **GET leaks.** GET returns `Metadata.registration_access_token` after `CHANGESECRET`, and `Metadata.client_secret` after a PUT that sets it.
- **`CHANGESECRET`.** `{}` answers 200 and saves.
- **`ROTATEKEYS`.** It appended a key pair (`PublicJWKS` 7,833 → 11,749 bytes). With `ClientCredentials` set it answered 200 and changed nothing.
- **`REGISTERCLIENT`.** Without an endpoint it answers 500 #8881.
- **A registered client's save.** With `registration_client_uri` at a closed port, a PUT stored the change and then answered 500 #6059.

**Why a port.** One place strips the GET's secrets for every caller, nests the registration access token, synthesizes the registration read and distinguishes a saved-then-failed PUT. It completes nothing through a vendor class, so it adds no AD-27 case.

**Form: the classic order, in four titled sections named for the classic tabs (untabbed; Q1).**

1. **General**: Application name*, Client name (`client_name`), Description, Enabled, Client type*, SSL/TLS configuration*, Server description* (select, issuer label, `ID` value), Redirect URL, Front-channel logout URL, Front-channel session required, and Grant types. The grant types are the classic page's five checkboxes, using the values its save maps (`Configuration.cls` :90-127). Then Authentication method, Authentication signing algorithm and Audience.
2. **Client Information**: Logo, client, policy and terms-of-service URLs; Default scope; Contacts (comma-separated); Default max age.
3. **JWT Settings**: JWT interval; X.509 credentials (aliases with a private key); Private key password (masked); the ID token, userinfo, access token and request-object signing and encryption selects, using the member `VALUELIST`s.
4. **Client Credentials**: Client ID; Client secret, Registration access token and Initial access token (masked, "Leave empty to keep the stored value."); and read-only issued-at, secret-expires-at and registration URI.

Every other derived non-secret member appears in a read-only Metadata table. The action bar holds Save (primary), Register, Rotate Keys and Delete.

**Strings** (`oauthClient*`):

- Labels: "Client configuration"; the section and field labels above; "Register"; "Rotate Keys".
- Outcomes: "Registered with {issuer}. Client ID: {clientId}."; "Rotated this client's keys."
- Partial saves: "Saved. The secrets were not stored: {reason}"; "Saved. {issuer} was not updated: {reason}".
- Refusals:
  - "This client is already registered.";
  - "The server description has no registration endpoint.";
  - "{issuer} did not register this client.";
  - "This client's keys come from its X.509 credential. Rotate that credential instead.";
  - "Enter at least one secret."
- The field sentences for each code.

Reuse the existing `oauthClientDeleteConsequence` and `oauthClientsEmptyAgent`.

**Integration ACs.**

- Consumes:
  - Story 6.4's tab and Story 7.3's delete;
  - AD-53's route and handler, and AD-55's Save;
  - Story 12.4's `OAuthServerSave.StoreToken` (a real server description on `ocupilot-b-ci`), the `OAuthIssuerFixture` and the server-descriptions read.
- Introduced: `OAuthClientPort`, the form descriptor, five tools and three routes, consumed here by the editor, the row actions and agent dispatch (AC1–AC8).
- Consumed-by: Story 12.9 (it removes the remaining three exemptions).

**Ledger inbox:** empty. **Expected `footprint_extensions`:**

- `AdminPort.cls`, `Prohibited.cls`, `Router.cls`, `Classification.cls` (with `FieldLists`/`ToolFields` regenerated);
- `Test/FieldDerive.cls`;
- `Error.cls`, `strings.ts`, `_components.scss`, EXPERIENCE.md;
- `screen-outlet.ts`, `screen-actions.ts`, `app.ts`/`app.spec.ts`;
- `structural-baseline.json`, the budget pair and the roster files above;
- `OAuthClientDelete.cls` (a Story 7.3 file).

**Open questions for the lead** (the spec is built on each recommendation):

- **Q1, tabs.** The classic editor has four tabs. `form-tabs` exists only on `origin/OCU-1-epic9`. **Recommend (a):**
  - ship four sections titled with the classic tab names, in order, now;
  - convert them to `app-form-tabs` at Epic 9's merge, as a `DW-n` bullet the lead routes to the merge or to Story 12.9.

  The alternatives are rejected: (b) waiting blocks the story on another epic's merge, and a copied component is the second one the lead forbade. UX-DR33's tab behavior is deferred, not dropped. The epic preamble's "whichever lands first" is superseded.
- **Q2, the initial access token.** It belongs to the server description (12.4's `TOKEN`). **Recommend** reading AC1's "initial access token" as a masked field on the client editor, stored on the chosen description through 12.4's own operation, because dynamic registration presents it. The other reading leaves it to 12.4's editor alone.
- **Q3, AD-4 (Rule 20).** Move `Security.OAuth2.Client.ClientConfiguration` out of the erasing list, since it keeps omitted fields and merges `Metadata` per member (measured above). Add it to the upsert sentence, since `PUT` creates. State that its complete set never carries `client_secret` or `registration_access_token`, and carries the registration-managed members as read.
- **Q4, AD-44.** "four since Story 12.4" becomes "three since Story 12.5". Update `epic-12-context.md` to match.
- **Q5, Rule 5.** The epic preamble names `OAuth2.Server.Metadata` for all four editors. The client's class is `OAuth2.Client.Metadata`. Correct it at origin (apply and report).
- **Q6, DW-1640 (measured, for the orchestrator's ruling).**
  - The vendor masks `ClientSecret`, `ClientPassword`, `Metadata.client_secret` and the JWKS in its client audit rows.
  - `registration_access_token` is written in plain text into "Modify OAuth2 Client" and "Modify OAuth2 Client Metadata" `EventData` by `CHANGESECRET`. It is written again by every later save of that client: a PUT and `ROTATEKEYS` were measured.
  - Registration writes one too (inference, from `RegisterClient` importing it).
  - This story adds no save beyond the one the user asks for. It is a further occurrence of DW-1640.
- **Q7, named gaps.** "Get Updated Metadata" (`ReadClient`) has no admin type, so it stays classic-only.
- **Q8, the agent's `Metadata`.** The agent's `Metadata` still replaces the settable members whole, as 12.4's deferred item says. The registration-managed and secret members are protected regardless.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. OAuth-writing tests run on `ocupilot-b-ci` only (52777/1976), one class per call, each awaited in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the deployed bundle is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth-client-editor.browser-spec.mjs browser/oauth.browser-spec.mjs browser/oauth-delete.browser-spec.mjs browser/oauth-server-description-editor.browser-spec.mjs` (loop) -- expected: every leg passes.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>` (loop), one call each for:
  - `OAuthClientCreate`, `OAuthClientUpdate`, `OAuthClientSecrets`, `OAuthClientKeys`, `OAuthClientRegister`, `OAuthClientWire` (armed);
  - `OAuthTabs`, `OAuthDelete`, `OAuthServerToken`, `OAuthServerDiscover`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `PortFixture`, `Prohibited`, `Descriptor`, `DerivedFields`, `Wire`, `WireOAuthRead`, `WireSecurityRead`.

  Expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, and the bundle total recorded.
- The full browser suite is CI's (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

| AC | Mutation |
| --- | --- |
| AC1 | The create tool sends no `Metadata` |
| AC2 | `Expand` skips the empty members |
| AC3 | The row action's typed-name check is dropped |
| AC4 | The port stops stripping `registration_access_token` |
| AC5 | Skip the Save's initial-token step, which reddens the Bearer-hash assertion |
| AC6 | The `ClientCredentials` precondition is dropped |
| AC7 | Drop the create's absence read |
| AC8 | Remove the form route's gate |
| AC9 | Restore the exemption |
| AC10 | A 1400px `min-inline-size` on the metadata table |

Registration-managed members: an agent `Metadata` without `registration_client_uri` is sent as `""`.

**Measure in implement and record here:**

- the fixture registration round trip (what the vendor accepts back);
- the vendor audit rows for a registration;
- the bundle total.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only: nothing was implemented. The endpoint's merge behavior, its secret handling, `ROTATEKEYS` and `REGISTERCLIENT`, and the vendor audit rows were measured on `ocupilot-b-ci` (see Design Notes), and the scratch objects were deleted. Q1–Q8 are open for the lead.
