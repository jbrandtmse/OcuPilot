---
title: 'Story 12.6: The OAuth 2.0 resource server editor'
type: 'feature'
created: '2026-09-25'
status: 'in-progress'
baseline_revision: '4a9f50377e9ace4d2aa8fa5d9380a7318c199909'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-5-the-oauth-2-0-client-configuration-editor.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The editor's and the tools' declared pairs (%Admin_Secure:USE, %DB_IRISSYS:READ) do not suffice to create or edit a resource server: the vendor resolves the issuer through OAuth2.ServerDefinition.OpenByIssuer, which needs %Admin_OAuth2_Client:USE (AD-8, AD-29 intent gap).
    evidence: |-
      Measured on ocupilot-b-ci over HTTP with a principal holding the tab's pairs alone: a create answers 422 (issuer not found), the GET answers IssuerEndpoint "", and a Description-only PUT answers 500 (<INVALID OREF> in %OnBeforeSave). Recommended amendment: declare %Admin_OAuth2_Client:USE on the six tools and the form as a measured AD-8 case.
    location: >-
      src/OcuPilot/Screen/Descriptor/OAuthResourceServerForm.cls, OAuthResourceServerTab.cls privileges; src/OcuPilot/Screen/Tool/OAuthResourceServer*.cls WRITERESOURCE
    severity: high
  - summary: >-
      The vendor writes a custom authenticator's credential-named setting in plain text into its own audit row, so a setting the port never reads back is readable through Logs > Audit and logs.audit.read.
    evidence: |-
      Measured on ocupilot-b-ci: a vendor save of a server whose authenticator holds ApiKey logs OAuth2ResourceServerChange (%System/%Security) with EventData "Authenticator: {...,"ApiKey":"<value>",...}". Same shape as 12.4's token finding; settle by the same AD-35 ruling.
    location: >-
      vendor OAuth2.ResourceServer audit; src/OcuPilot/Screen/Descriptor/AuditList.cls read fields (EventData)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Resource servers tab can only list. Its name cells link out to the classic page, so nobody can create, edit or delete a resource server, set its audiences or authenticator, or map a web application or a namespace to it inside OcuPilot. Story 12.5's client editor is a sectioned form, because `app-form-tabs` was not on the branch when it was built (DW-1644).

**Approach:** Add a tabbed `form-page` editor at `security/oauth/resource-servers/edit`, built on `app-form-tabs`. It round-trips create, edit and delete of `Security.OAuth2.ResourceServer`, its audiences, its authenticator and its service mappings (`Security.OAuth2.ResourceServerMapping`). It uses the two fixed mechanisms: Save goes through six write tools (AD-55, create per AD-54), and Delete is the tab's row action (AD-53). A new `OAuthResourceServerPort` carries the mapping calls and the authenticator checks. The admin API carries every write, so no AD-27 case is added. Story 12.5's client editor moves onto `app-form-tabs` (DW-1644).

## Boundaries & Constraints

**Always:**

- **Identity.** The id is `Name`, the vendor's IdKey, sent as the `name` query. The vendor's lookup is exact (measured), so the id needs no `IDRULES` entry. The body cannot carry the name, so it is fixed after create and the editor shows it read-only.
- **The secret is write-only (AD-3, AD-35, AD-56).** `ClientSecret` (for the introspection endpoint) is masked, never pre-filled, and never in a proposal's arguments, a diff, the ledger, screen context, a log line or a status. The GET never answers it, the PUT refuses it (measured), and the vendor's audit rows do not carry it (measured).
  - It travels only through `CHANGESECRET`.
  - An empty field means "leave the stored value unchanged". The port refuses an empty or missing secret, because `{"ClientSecret":""}` clears the stored one (measured).
- **Save sends the complete property set (AD-4, amended at this plan).** It reads fresh, applies the diff, and sends every template field:
  - `Audiences` is sent whole, as the edited list.
  - `Authenticator` is replaced whole by the vendor. When `Namespace` and `Implementation` are unchanged, every setting the caller did not send is filled from the fresh read. When either changes, only the sent settings go, and the rest take the new class's defaults. The card and the form say so.
- **Create is `PUT`, an upsert (measured: 201 on an absent name).** AD-54's absence fingerprint is load-bearing. The Save's create path refuses a taken name before any port call.
- **Service mappings are two action writes on the resource server** (AD-51, AD-56 ii): `addmapping` and `removemapping`. Each takes the declared non-secret arguments `Service` and `Key`. The port builds the `ResourceServerMapping` call from them, with `{"Resource": <name>}` as the body for an add.
  - The fresh read is the port's `MAPPINGS` read: `{IssuerEndpoint, Mappings: ["<Service>/<key>", ...], Held: {"<Service>/<key>": "<resource server>", ...}}`. `Mappings` is this server's rows and `Held` is every mapping on the instance, from both services' LISTs.
  - The fingerprint subject is `Mappings,Held`, so a mapping moved by anyone between mint and confirm refuses the confirm.
  - The mapping's target is the resource server. The change event is the server's.
- **Adding a mapping another resource server holds moves it, with the effect named ("developer tool first").** The vendor's PUT moves it (measured).
  - For an agent proposal, `Prohibited.WeakensByEffect` names the effect `OAUTH.MAPPINGMOVE` for `oauth2-resource-server` when the payload's key is in `Held` under another server. The proposal is then minted destructive, and its card carries the consequence sentence and a row naming the previous holder.
  - For a person's Save, the Mappings tab shows the same sentence at the Add row, naming the holder from the form read's `held`.
- **Form rules** are enforced identically by each tool's `ArgumentProblem` and by the Save route, and written once on the server as `detail.violations[]` (AD-39). They apply every refusal the vendor would answer 500 or 422 for (measured), so none reaches a person:
  - `Name`: required, 1 to 128 characters, no control character, and not taken (on create).
  - `IssuerEndpoint`: required, and must be an existing server description's issuer.
  - `Audiences`: at least one. Each is 1 to 256 characters with no control character, and no two are the same.
  - `Description` and `ScopeRequiredToConnect`: at most 256 characters.
  - `IntrospectionAuthMethod`: one of `""`, `client_secret_post`, `client_secret_basic`, `none`.
  - The four flags are booleans.
  - `Authenticator`:
    - `Namespace` must be a namespace the shell's namespace list names.
    - `Implementation` must be a compiled subclass of `%OAuth2.ResourceServer.Authenticator` visible in that namespace.
    - Each setting must be one its `DescribeSettings()` names, with that setting's type.
  - A mapping:
    - `Service` is `%Service_WebGateway` or `%Service_Bindings`.
    - `Key` is `*`, or an existing web application (Web Gateway) or namespace (Bindings), at most 64 characters, compared lower-cased as the vendor stores it.
    - A remove's key is held by this server. An add's key may be held by another server (see the move bullet above).
- **Authenticator settings that are credentials.** A custom authenticator's setting whose name matches the Conventions › Secrets pattern is removed by the port from every read. A Save or tool that omits it keeps it (the port fills it from the fresh read). A caller that sends one is refused (`OAUTH.AUTHENTICATOR.SECRET`), and such a setting stays a classic-portal edit. The stock `SimpleAuthenticator` has none.
- **Delete** removes the server. The vendor also deletes its mappings (measured), and the consequence line says so.
- **A new server on an instance with none** starts its Mappings tab with the two `*` default mappings as unsaved rows, which the user can remove. This matches the classic editor, which creates them for the first server.
- **Privileges.** Every tool, route and port call requires the tab's pair set, `%Admin_Secure:USE` + `%DB_IRISSYS:READ` + `%Admin_OAuth2_Client:USE` (AD-8, AD-29) [AMENDED 2026-09-25, lead ruling at the implement halt: a principal holding only the first two cannot create or edit a resource server, because the vendor resolves the issuer through `OAuth2.ServerDefinition.OpenByIssuer`, which checks `%Admin_OAuth2_Client:USE`; AD-29 adds what the instance still refuses, so the tab, the form and the six tools declare three pairs and AD-8's text is unchanged]. Both vendor endpoints' `ResourcesOR()` is `%Admin_Secure`. Screen writes emit no marker (AD-53), and agent confirms do (AD-15).
- **Change events.** Every write publishes `(oauth2-resource-server, instance, <name>)`.
- **UI.** Use tokens only, and render correctly in the dark theme. The editor's own content gets no DW-1337 allowance. Write non-ASCII in code as `\u` escapes.

**Never:**

- No third write mechanism.
- No AD-27 vendor-class call.
- No mapping update tool: a move is a remove followed by an add.
- No second tab component.
- No suggested prompts, because Story 11.3's key is absent.
- No change to the OAuth server and server-client tabs' links (Story 12.9).
- No change to Story 12.4's untabbed editor.
- No change to Epic 9's editors.
- No OAuth-writing test on `ocupilot-slot-b`.
- No internet dependency in any test.
- No enabling of OAuth 2.0 authentication on any web application.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | New name, a server description's issuer, two audiences, one Web Gateway mapping | 201. The editor reopens on `security/oauth/resource-servers/edit/<name>` reading "Saved". The tab lists it, and the mapping is stored | None |
| Create, first server | No resource server on the instance | The Mappings tab opens with both `*` defaults, and Save stores them | Removing a default before Save stores nothing for it |
| Create, name taken | Existing name | 422 on `Name`. The existing server is unchanged | Before any port write |
| Edit, partial | Description changed, one audience removed, `UserClaim` changed | GET shows exactly that. `RoleClaim`, `Prefix` and every other field are unchanged | None |
| Edit, bad value | Empty audience list, bad auth method, unknown issuer, unknown implementation or namespace, a 300-character description | 422 on the named field; nothing sent | Form rule (vendor answers 500 or 422) |
| Secret | Client secret entered | Stored (length > 0). No read, form read, context, ledger row or log line carries it. An empty field sends nothing | A secret write failing after the save → "Saved. The client secret was not stored: {reason}" |
| Mappings | One Web Gateway mapping removed and one Bindings mapping added | The removed mapping is gone and the added one is held by this server | A port refusal after the save → "Saved. {count} service mappings were not changed: {reason}" |
| Mapping move | Add a key another server holds | The Add row shows the move sentence naming the holder, and Save moves it. An agent proposal is destructive and names the effect | A move made by someone else between mint and confirm → the fingerprint refuses the confirm |
| Authenticator secret | A probe authenticator with an `ApiKey` setting | No read answers `ApiKey`; a Save leaves it stored; sending it is refused by name | Named refusal |
| Delete | From the editor or the row menu, name typed | Gone from the tab and the instance, with its mappings | Existing typed-name dialog |
| No privilege | Caller lacks `%Admin_Secure:USE` or `%Admin_OAuth2_Client:USE` | 403 naming the pair on the form read, the Save routes, the row action and the mint | Before any port call |
| DW-1644 | Client editor Save refused on a JWT Settings field | The JWT Settings tab opens, shows ", 1 error", and focus lands on the field | None |

</intent-contract>

## Code Map

**Vendor (hidden; read on `ocupilot-b-ci` in `%SYS` with `GetTextAsString`).**

- `%Api.Admin.Endpoints.Security.OAuth2.ResourceServer`:
  - `ResourcesOR` is `%Admin_Secure`, and every type is synchronous.
  - Types: LIST, GET, PUT (upsert; `RunPut` and `MergeJsonAndObj` set only the keys the body defines), DELETE, and CHANGESECRET (10, `POST …/resource-server/secret`, schema `{ClientSecret}`, strict).
  - The PUT template is `Enabled, Description, IssuerEndpoint, ScopeRequiredToConnect, Audiences:[""], AccessTokenIsJWT, AlwaysCallIntrospection, ClientId, IntrospectionAuthMethod, UseOIDC, Authenticator:{Namespace, Implementation}`. `Authenticator` allows unrecognized members.
  - `ObjToJson` answers the template keys (no `Name`, no `ClientSecret`) and the authenticator's `DescribeSettings()` members.
- `%Api.Admin.Endpoints.Security.OAuth2.ResourceServerMapping`:
  - Query `service` + `key`; LIST requires `service` (`ListByService` → `{Service, Key, Resource}`).
  - PUT is an upsert with body `{Resource}` (422 when the resource is absent), and DELETE answers 404 when absent.
- `irissys/OAuth2/ResourceServer.cls`: properties :21-77, `Delete` :535, `%OnBeforeSave` :565 (the audit text has no secret), and `%OnDelete` :655, which cascades the mappings.
- `irissys/OAuth2/ResourceServer/Mapping.cls`: `KeySet` lower-cases the key; `%OnValidateObject` checks the app, namespace or `*`.
- `irislib/%OAuth2/ResourceServer/Authenticator.cls` (`GetInstance` :99, `DescribeSettings` :136) and `SimpleAuthenticator.cls` (`UserClaim`, `RoleClaim`, `Prefix`).
- Classic pages:
  - `irissys/%CSP/UI/Portal/OAuth2/ResourceServer/Configuration.cls` is untabbed. It has fields :84-121, a JWT/introspection toggle :157-174, the implementation list `GetImpl` :238, settings controls `ChangeImpl` :268-335, and default mappings on the first server :474-486.
  - `ConfigurationList.cls` has the Mappings tab :99-155.

**Models to copy (Story 12.5; distilled anchors):**

- `Port/OAuthClientPort.cls`: `Invoke` :77 (a foreign endpoint goes to `##super`; branch on type), `Stripped` :132, `CredentialUsable` :145 (a vendor read inside a port), `Registration` :313 (a synthesized read), `Violation` :374.
- `Area/Security/OAuthClientRules.cls`:
  - `Validate` :204, `Expand` :362;
  - `HandleForm` :401, `ServerDescriptions` :472;
  - `Present` :496, `Gate` :563.
- `Area/Security/OAuthClientSave.cls`:
  - `HandleCreate` :77 and `HandleUpdate` :121;
  - `Create` :169 and `Update` :211 (empty body :231, empty diff :247);
  - `StoreSecrets` :288, which runs a tool through `Operation.Gate`/`ApplyAt` (:307/:318);
  - `Answer` :396, `TakeSecrets` :424, `StrayKey` :447.
- Tools `Screen/Tool/OAuthClient{Create,Update,SetSecrets,Delete}.cls`. For the argument-carrying action write, `Screen/Tool/AuditCopy.cls`: `SettableFields` :80, `InputSchema` :87, `PortQuery` :111, no Classification entry.
- `Screen/Tool/Write.cls`:
  - parameters :38-201;
  - `IdArgument`/`IdParam` :490/:497 (defaults `Name`/`name`);
  - `PortQuery` :407. It is not called by the mint read (`Kernel/Proposal/Mint.cls:165`), so `MAPPINGS` takes only `name`.
- `Area/Security/OAuthServerRules.cls` `ReadableNames` :407 gives the web-application names through `Screen/Descriptor/WebAppList.cls`. `Kernel/Shell/Namespaces.cls` `Payload` :109 gives the namespaces, as `Area/Task/TaskRules.cls:1077` does.
- `Screen/Tool/FieldLists.cls` :319 and :335 already derive both templates. `FieldRows` (`Write.cls:624`) skips object paths, so `Authenticator` is admitted like 12.5's `Metadata` (opaque; the tool adds it in `SettableFields`).

**Shared files (own lines only):**

- `Port/AdminPort.cls`: `MUTATINGTYPES` :298, `BODYLESSTYPES` :314.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250, type constants :275-281;
  - the fail-closed chain :735, dispatch :827/:831;
  - `PermittedChangeFields` :533 / `PermittedCreateFields` :641;
  - `OAuthClientFields` :1473.
- `Api/Router.cls`: 12.5 routes :169-171, `</Routes>` :172, call methods end :568.
- `Api/Error.cls`: `ReasonForViolation` :1065 → `ReasonForOAuth` :2414 → `ReasonForOAuthClient` :2548 (ends `Quit ""`); `OAuthClientViolationCodes` :2573.
- `Screen/Descriptor/OAuthResourceServerTab.cls`: exemption :38-44, no actions; table `emptyNextKey` `tableReadOnlyEmptyNext`.

**Client:**

- `ui/src/app/shell/form-tabs.ts`: `FormTabs` :53, inputs `tabs`/`selected` :88/:91, `selectedChange` :94, body directive `ocuFormTab` :27.
- `ui/src/app/core/form-tabs.ts`: `tabErrorCounts` :30, `tabToOpen` :45, `tabAccessibleName` :60.
- Model consumer: `areas/security/ssl-form.page.ts` (tabs :686-694, `tabToOpen` :1066, `focusField` :1032) and `ssl-form.store.ts` `SSL_FIELD_TABS` :72. `areas/permissions/user-editor.page.ts` :145/:494/:562/:807-822/:883-901 has the refusal pattern.
- DW-1644, the client editor:
  - `oauth-client-form.page.ts` has sections :212-255, metadata table :257-269, controls getters :395-471, `focusField` :713 (no tab switch), and `focusRefusal` :754 (server order).
  - `oauth-client-form.page.spec.ts` :151-171 asserts "untabbed".
  - `browser/oauth-client-editor.browser-spec.mjs` has the section asserts at :7, :208-224, and fills other-section fields at :232/:253/:272.
  - `ui/src/styles/_components.scss` has its section comment at :5876-5879.
- Registrations:
  - `shell/screen-outlet.ts` :120;
  - `core/screen-actions.ts` :114-116;
  - `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :43-62 and `DESTRUCTIVE_CONSEQUENCES` :193-209 (the resource-server tab is in neither);
  - `app.ts` :266-269 and sign-out :561-563, pinned by `app.spec.ts` :1056-1067 and :1144-1151;
  - `areas/security/oauth-actions.ts` :8-47.
- `ui/src/app/core/strings.ts`: the 12.5 block ends :2368, and `} as const` is :2370. The hint `oauthClientSecretHint` is :2346 (EXPERIENCE.md:517). EXPERIENCE.md's last Fixed-strings row is :517.
- `ui/browser/structural-baseline.json` has the three `security/oauth/clients/edit` entries at :1279-1311.
- The `CLASSIC_TABS` resource-servers row appears in `oauth-client-editor.browser-spec.mjs` :66 and `oauth-server-description-editor.browser-spec.mjs` :55. `oauth.browser-spec.mjs` has it at :70-75 and in the honored roster :354. `ui/tools/classic-links.test.mjs` has it at :449 and :472-473.
- Budget: `ui/angular.json` :54-55 (1745kB/2000kB), pinned at `ui/tools/angular-json.test.mjs` :377/:379.

**Rosters:**

- `Test/PortGate.cls:28`
- `Test/PortFixture.cls:21`
- `Test/ToolRoundTrip.cls:37`
- `Test/SurfaceCoverage.cls` :75-78 and :149-160
- `Test/EndpointCoverage.cls` :152-154
- `Test/Prohibited.cls:218`
- `Test/OAuthTabs.cls` :30, :83, :185-186, :271
- `Test/WireOAuthRead.cls` :275-321
- `Test/WireSecurityRead.cls` `ScreensFor` literals
- `scripts/ci-throwaway.sh` :204 (the arming line)

## Tasks & Acceptance

**Rework after the implement halt (lead, 2026-09-25) -- work these first; the rest of the story is implemented in the tree at `wip` commit and is re-verified, not redone:**

- [ ] [Lead] Pairs (AD-29): add `%Admin_OAuth2_Client:USE` to `OAuthResourceServerTab`'s and `OAuthResourceServerForm`'s `privileges` and to the six tools' declared set (`WRITERESOURCE` or however the tools declare it), and to every route and port gate this story adds. Update the rosters that pin the tab's pair set (`WireSecurityRead`, `WireOAuthRead`, `Wire`, `screens.generated.ts` via `screen-mirror`, any other the test run names). `OAuthResourceServerWire` gains the second denial leg (a principal with `%Admin_Secure:USE` and `%DB_IRISSYS:READ` but not `%Admin_OAuth2_Client:USE` is refused 403 naming `%Admin_OAuth2_Client:USE` on the form read, the Save routes, the row action and the mint), and a least-privileged principal holding all three pairs creates, edits and deletes a resource server end to end on `ocupilot-b-ci` (AD-29's real-principal check). Mutation line for each.
- [ ] [Lead] AD-35 (spine already amended): the audit read masks, on both paths (Logs > Audit and `logs.audit.read`), the custom authenticator's secret-classified settings in the vendor's `OAuth2ResourceServerChange` rows -- the settings this story's classification marks `secret` (the credential-named ones, Conventions > Secrets), declared for that event beside 12.5's OAuth declarations in the same mask. A test seeds a row carrying a probe value (e.g. `ApiKey`) and pins that it reads masked through both reads. Mutation line.
- [ ] [Lead] Remove the two `deferred:` entries from the frontmatter once each is worked (they are this rework's scope, not deferrals).

**Execution:**

- `src/OcuPilot/Port/OAuthResourceServerPort.cls` (new; extends `AdminPort`; add it to `Test/PortGate.cls` `ROSTER`).
  - `Security.OAuth2.ResourceServer`:
    - `GET` and `PUT` answers: remove the credential-pattern authenticator settings.
    - `PUT`:
      1. Fill an omitted credential-pattern setting from the fresh unstripped read when `Namespace` and `Implementation` are unchanged.
      2. Refuse a sent one (`OAUTH.AUTHENTICATOR.SECRET`).
      3. Check the authenticator with `AuthenticatorUsable` (a `%Dictionary.CompiledClass` read in the target namespace, AD-16), mapping a failure to its violation.
      4. Map any other vendor 500 to `OAUTH.RESOURCESERVERVALIDATION`, with the raw text in the log only.
    - `CHANGESECRET`: refuse an empty or missing `ClientSecret` (`OAUTH.RESOURCESERVERNOSECRET`).
    - `MAPPINGS` (synthesized read): the fresh GET's `IssuerEndpoint`, this server's rows from both services' mapping LISTs as `Service/Key`, and `Held`, the whole table. An absent server answers 404.
    - `ADDMAPPING`: mapping `PUT` `{Resource: name}`, which creates or moves it.
    - `REMOVEMAPPING`: GET the mapping; if absent or held by another server, refuse `OAUTH.MAPPINGABSENT`; else mapping `DELETE`.
    - `AUTHENTICATORS` (synthesized read, `namespace` query): the compiled subclasses of `%OAuth2.ResourceServer.Authenticator` visible there, each with its `DescribeSettings()` minus credential-pattern settings. A namespace the caller cannot read answers only `%OAuth2.ResourceServer.SimpleAuthenticator`.
  - Append to `AdminPort`'s lists (contended; single lines):
    - `MUTATINGTYPES`: `ResourceServer/PUT`, `/CHANGESECRET`, `/DELETE`, `/ADDMAPPING`, `/REMOVEMAPPING`, and `ResourceServerMapping/PUT`, `/DELETE`;
    - `BODYLESSTYPES`: `ResourceServer/DELETE`, `/ADDMAPPING`, `/REMOVEMAPPING`, and `ResourceServerMapping/DELETE`.

    This follows 12.5's `ROTATEKEYS`/`REGISTERCLIENT`.
- `src/OcuPilot/Screen/Tool/OAuthResourceServer{Create,Update,SetSecret,Delete,AddMapping,RemoveMapping}.cls` (new). Common to all: `DESCRIPTORCLASS` is `OAuthResourceServerTab`, `PORTCLASS` is `OAuthResourceServerPort`, `WRITERESOURCE` is `%Admin_Secure:USE`, the id defaults (`Name`/`name`), and the names are `security.oauthresourceservers.<verb>`. Every `DESCRIPTION` says nothing changes until the user confirms.

  | Tool | Parameters | Notes |
  | --- | --- | --- |
  | Create | `CREATES` 1, `READTYPE` GET, `WRITETYPE` PUT, `SENDSBODY` 1, `CHANGEACTION` created | The schema comes from the derived list plus the opaque `Authenticator`. `DerivedFields` → `Expand(,0)` |
  | Update | GET/PUT merge | `DerivedFields` → `Expand(fresh, args)` per the Always rule |
  | SetSecret | `WRITETYPE` CHANGESECRET, `SENDSBODY` 0, `SECRETBODY` `ClientSecret`, `READANSWERS`/`FINGERPRINTSUBJECT` `IssuerEndpoint,ClientId`, `PRECONDITIONFIELD` `ClientId` | |
  | Delete | `SCREENACTIONS` delete, `WRITETYPE` DELETE, `SENDSBODY` 0, `READTYPE` MAPPINGS, `READANSWERS`/`FINGERPRINTSUBJECT` `IssuerEndpoint,Mappings`, `PRECONDITIONFIELD` `IssuerEndpoint`, `DESTRUCTIVE` 1, `CHANGEACTION` deleted | `StateDiff` lists the mappings removed with it |
  | AddMapping | `READTYPE` MAPPINGS, `WRITETYPE` ADDMAPPING, `SENDSBODY` 0, `READANSWERS`/`FINGERPRINTSUBJECT` `Mappings,Held`, `PRECONDITIONFIELD` `Held` | `SettableFields`/`InputSchema`/`PortQuery` carry `Service` (enum) and `Key`, as `AuditCopy` does. The diff rows are `Mappings` before → after and, for a move, the previous holder. A `Consequence` method answers `OAUTH.MAPPINGMOVE` |
  | RemoveMapping | As AddMapping, with `WRITETYPE` REMOVEMAPPING and `PRECONDITIONFIELD` `Mappings` | The precondition is that the key is in `Mappings`; no consequence |

- `src/OcuPilot/Screen/Tool/Classification.cls` (after :532): create and update have `Authenticator` opaque and the rest ordinary; setsecret has `ClientSecret` as authored secret. Then regenerate `ToolFields.cls`. The mapping tools have no entry, as for `AuditCopy`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (contended; own lines):
  - Add `TYPEOAUTHRESOURCESERVER`, add it to `COVEREDTYPES`, to the :735 chain and to the :827/:831 dispatch, and add `OAuthResourceServerFields()`. That list holds the eleven template fields and is returned by both Permitted methods.
  - Add `EFFECTMAPPINGMOVE` (`OAUTH.MAPPINGMOVE`) and a `WeakensByEffect` branch (:1070) for the type: the effect when the payload's `Service/Key` is in the target's `Held` under another server. Nothing is self-protective: a mapping only chooses which server validates a token on an application that already accepts OAuth 2.0 (`$$$AutheOAuth2`), which is the web application's own setting (inference).
- `src/OcuPilot/Screen/Descriptor/OAuthResourceServerForm.cls` (new):
  - Route `security/oauth/resource-servers/edit`, `form-page`, position 0.
  - The tab's pairs; `entityType` `oauth2-resource-server`, scope `instance`, `id single`.
  - `context.secretFields [ClientSecret]`, `secretArguments []`.
  - `classicPage` `%CSP.UI.Portal.OAuth2.ResourceServer.Configuration`, no exemption, `toolIdentifier` `security.oauthresourceserverform`.
- `src/OcuPilot/Screen/Descriptor/OAuthResourceServerTab.cls`:
  - Set the exemption to `exempt: false`.
  - `primaryAction create`, `rowActions [delete]`, `secretArguments [ClientSecret]`.
  - Table `emptyNextKey ""`, `emptyAgentKey oauthResourceServersEmptyAgent`.
  - Rewrite the doc comment's link and action paragraphs, then regenerate `screens.generated.ts`.
- `src/OcuPilot/Area/Security/OAuthResourceServerRules.cls` and `OAuthResourceServerSave.cls` (new, modeled on the 12.5 pair).
  - The form read, `GET /oauth/resource-server/form[?name=][&namespace=]`, answers:
    - `requiredFields`, `rules`;
    - `serverDescriptions` (issuers, through the server-descriptions screen read);
    - `webApplications` (`ReadableNames` on `WebAppList`) and `namespaces` (`Kernel/Shell/Namespaces`);
    - `authenticators` for the requested namespace (default: the definition's, else `%SYS`);
    - `held`, the `MAPPINGS` read's whole-table map, for the move sentence;
    - `resourceServerCount`;
    - with `name`: `definition` (the stripped GET) and `mappings` (the `MAPPINGS` read).
  - The Save body is the changed fields, plus `ClientSecret`, `mappingsAdded` and `mappingsRemoved` (`[{Service, Key}]`). Any other key is refused (`StrayKey`).
  - Every form rule, including every mapping row's, is checked before the first write.
  - Order:
    1. create or `PUT` (update only on a non-empty diff);
    2. the secret, only when supplied;
    3. each removal;
    4. each addition.

    Each tool's operation goes through `Operation.Gate`/`ApplyAt`.
  - A step failing after an earlier one succeeded answers the saved entity plus `secretRefused` or `mappingsRefused` (`{count, reason}`).
- `src/OcuPilot/Api/Router.cls` (append after :171) -- `GET /oauth/resource-server/form`, `PUT /oauth/resource-server/:id`, `POST /oauth/resource-server`, each with a thin wrapper after :568. The form route goes before `:id`.
- `src/OcuPilot/Api/Error.cls` (own entries; a `ReasonForOAuthResourceServer` chain off `ReasonForOAuthClient`'s final `Quit`, plus `OAuthResourceServerViolationCodes`). Each code gets its reason:
  - `OAUTH.RESOURCESERVERNAME.{REQUIRED,SHAPE,TAKEN}`, `OAUTH.ISSUERENDPOINT.{REQUIRED,ABSENT}`, `OAUTH.AUDIENCES.{REQUIRED,SHAPE,DUPLICATE}`;
  - `OAUTH.DESCRIPTION.LENGTH`, `OAUTH.SCOPEREQUIRED.LENGTH`, `OAUTH.INTROSPECTIONAUTHMETHOD.VALUE`, `OAUTH.FLAG.VALUE`;
  - `OAUTH.AUTHENTICATOR.{NAMESPACE,IMPLEMENTATION,SETTING,SECRET}`;
  - `OAUTH.MAPPINGSERVICE.VALUE`, `OAUTH.MAPPINGKEY.ABSENT`, `OAUTH.MAPPINGABSENT`;
  - `OAUTH.RESOURCESERVERVALIDATION`, `OAUTH.RESOURCESERVERNOSECRET`.
- `ui/src/app/areas/security/oauth-resource-server-form.{store,page}.ts` (+ specs), `oauth-actions.ts` (the tab's Create through `createFormFor`) -- the tabs, fields and actions in Design Notes, on `app-form-tabs`:
  - The field→tab map, `tabErrorCounts`, `tabToOpen` over the form order, and `focusField` that switches the tab first, as `user-editor.page.ts` does.
  - The unsaved guard, "Saved", a create followed by `replaceUrl`, and the change event.
  - Delete via `handler.sendFor(OAuthResourceServerTab,'delete')` with the typed name.
  - In `app.ts`, inject the store and reset it at sign-out; pin that in `app.spec.ts`.
- `ui/src/app/areas/security/oauth-client-form.page.ts` (+ page spec, browser spec, and the `_components.scss` comment) -- DW-1644:
  - Replace the four sections with four `app-form-tabs` tabs of the same names and order, and put the read-only metadata table on Client Information.
  - Add `CLIENT_FIELD_TABS` and a form order; `afterRefusal` uses `tabToOpen`, and `focusField` switches the tab first.
  - The "untabbed" assertions become tab assertions (four tabs, and a refusal on a JWT Settings field opens that tab with ", 1 error"). The browser `fill` opens a field's tab first.
- `ui/src/app/shell/screen-outlet.ts` (page entry), `ui/src/app/shell/screen-action-handler.ts` (+ spec: `OAuthResourceServerTab` in `SCREEN_ACTION_DESCRIPTORS` and `DESTRUCTIVE_CONSEQUENCES`), `ui/src/app/core/proposal-view.ts` (a `CONSEQUENCE_MAPPINGMOVE` code in `consequenceSentence` :157, pinned beside `NOPEERCHECK` in `shell/proposal-card.spec.ts` :767) -- own lines only.
- `ui/src/app/core/strings.ts` (after :2368), EXPERIENCE.md (a row after :517: Story 12.6, FR-44), `_components.scss` (own `ocu-oauth-resource-server-*` classes) -- the Design Notes strings.
- Tests (new; each under 500 lines, one class per call, on `ocupilot-b-ci` only; helpers `Test/OAuthResourceServerProbe.cls` with `RemoveAll`, and `Test/OAuthProbeAuthenticator.cls`, a `%OAuth2.ResourceServer.Authenticator` subclass with `ApiKey` and `Claim` settings):

  | Class | Covers |
  | --- | --- |
  | `Test/OAuthResourceServerCreate` | declarations; create through the route with default mappings; a taken name; every form rule on both callers; a create taken after the mint refused at confirm |
  | `Test/OAuthResourceServerUpdate` | the complete set; an audience removed; authenticator settings kept, and reset on an implementation change |
  | `Test/OAuthResourceServerSecret` | stored, and never in the port's read, the form read, context, ledger or log; an empty field sends nothing; an empty body is refused; `secretRefused` |
  | `Test/OAuthResourceServerMappings` | add and remove through the Save and the tools; a move minted destructive with `OAUTH.MAPPINGMOVE` and the previous holder, and applied at confirm; a move by someone else after the mint refused at confirm; bad key and service; `mappingsRefused`; delete cascades |
  | `Test/OAuthResourceServerAuthenticator` | the implementation list; the probe's `ApiKey` never read, kept across a Save, and refused when sent |
  | `Test/OAuthResourceServerWire` | arms `OCUPILOT_ALLOW_PRINCIPALS`; 403s naming the pair; each tool minted and confirmed with a marker; screen writes leave no marker |

- Roster updates (own rows): `PortGate`, `PortFixture` `MUTATINGTYPES`, `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage` (the form and six tools), `EndpointCoverage` (three routes), `Test/Prohibited` `CoveredTypes`, `OAuthTabs` (the resource-server tab becomes edited, with create and delete), `WireOAuthRead`/`WireSecurityRead` literals, `classic-links.test.mjs` (three exemptions across four declarations), `navigation.test.mjs`, `oauth.browser-spec.mjs`, the two OAuth editor specs' `CLASSIC_TABS`, and the `scripts/ci-throwaway.sh` armed classes.
- `ui/browser/oauth-resource-server-editor.browser-spec.mjs` (new; `assertThrowaway`, probes through `irisSession`):
  - Legs: create with default mappings, edit, secret (masked and not pre-filled), mappings add/remove and a move showing its sentence, authenticator change, delete from the row menu, and the other two tabs keeping classic links.
  - DW-1337 `detectScreen` at 1280 light, 720 light and 1280 dark, on every tab and on the delete dialog.
  - Every load wait fails while its element is absent.
- `ui/browser/structural-baseline.json` -- add exactly three `security/oauth/resource-servers/edit` entries mirroring :1279-1311, and nothing for the editor's own content.
- `ui/angular.json` + `ui/tools/angular-json.test.mjs` -- if the initial total crosses 1745kB, apply DW-1166: 5% above the measured total, the value line and the pinned literal. Crossing 2000kB is a stop-and-ask.
- DW-1644 (routed to this story) is carried by the client editor task above and pinned by AC10.

**Acceptance Criteria:**

- **AC1 (create).** Given the Resource servers tab, when the user chooses Create, fills the General tab, keeps the default mappings on an instance with no server, and saves, then:
  - the editor reopens on the new server reading "Saved";
  - the tab lists it;
  - GET returns every entered value;
  - both `*` mappings are held by it.
- **AC2 (edit, AD-4).** Given a server opened from its name cell, when the user changes the description, removes one audience, changes one authenticator setting and saves, then GET shows exactly that, and every other field and authenticator setting reads as before.
- **AC3 (delete).** Given a server with mappings, when the user deletes it from the editor or the row menu and types its name, then it and its mappings are gone from the tab and the instance.
- **AC4 (secret).** Given the client secret field, when a value is entered and saved, then:
  - it is masked and never pre-filled, and the instance stores it;
  - no read, form read, screen context, proposal, ledger row or OcuPilot log line carries it;
  - an empty field leaves the stored secret unchanged.
- **AC5 (mappings).** Given the Mappings tab, when the user removes one mapping and adds a Web Gateway application and a namespace, then:
  - the Save leaves exactly those held by this server;
  - adding a key another server holds shows the move sentence naming that server before Save, and moves it on Save;
  - an agent proposal for such a key is destructive and names the effect.
- **AC6 (authenticator).** Given the Authenticator tab, when the user picks a namespace, then:
  - the implementations and their settings are the ones that namespace offers;
  - a custom authenticator's credential-named setting is never shown or read back;
  - a Save keeps that setting stored.
- **AC7 (agent).** Given the agent proposes create, update, setsecret, addmapping, removemapping and delete, when the user confirms, then each write lands and is marked (AD-15), and the secret is asked at confirm and never stored. A create whose name was taken after the mint is refused at confirm (AD-54).
- **AC8 (privilege).** Given a caller without `%Admin_Secure:USE`, or without `%Admin_OAuth2_Client:USE`, when they read the form, save, delete from the row menu or mint, then the request is refused 403 naming the pair it lacks before any port call.
- **AC9 (link-out).** Given the OAuth 2.0 screen, when it renders, then:
  - the Resource servers tab's name cell opens OcuPilot's editor;
  - the server and server-client tabs keep their classic links;
  - the classic-links check reports the OAuth exemption across those two descriptors.
- **AC10 (DW-1644).** Given the client configuration editor, when it opens, then it shows four tabs named and ordered as before, and a Save refused on a field of another tab opens that tab, marks it ", 1 error" and focuses the field.
- **AC11 (DW-1337).** Given the resource server editor on each tab and its delete dialog, and the client editor on each tab, when they are measured at 1280 px light, 720 px light and 1280 px dark, then there is no structural or contrast violation.

## Spec Change Log

- 2026-09-25, lead ruling at the implement halt (re-dispatch): the pair set becomes three pairs under AD-29 (Privileges bullet, the no-privilege matrix row and AC8 amended); AD-35 gains the `OAuth2ResourceServerChange` declaration (spine amended); both are worked as the `[Lead]` items under Tasks & Acceptance.

- 2026-09-25, lead spec gate: Q1-Q3 answered as recommended; AD-51 amended; structural-baseline and bundle notes added under Design Notes.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-24, AD-26, AD-27, AD-29, AD-35, AD-36, AD-39, AD-42, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56.

- The DW-1337 gate applies.
- No AC contradicts an AD.
- Neither vendor endpoint queues (AD-26).
- AD-8 is not widened: both endpoints' `ResourcesOR()` is `%Admin_Secure`, and `%Admin_OAuth2_Client:USE` joins the tab's own set under AD-29 (measured at the implement halt), so every tool's set is still its screen's.

**Measured on `ocupilot-b-ci`, 2026-09-25.** Scratch servers, mappings and a server description were used; the vendor tables read 0 rows afterwards. AD-4 was amended at its origin with these measurements (Rule 20; memlog appended; lint clean apart from the existing `{id}` note at :169).

- **PUT.**
  - A PUT carrying only `Description` kept every field.
  - An `Authenticator` naming only `UserClaim` reset `RoleClaim` and `Prefix` to their defaults, and an unknown setting is ignored.
  - `Audiences:[]` answered 500 (#5659) and stored nothing.
  - A create without the issuer or the audiences answered 500.
  - The PUT is an upsert (201).
- **Other PUT refusals.**
  - An unknown issuer answered 422.
  - A bad `IntrospectionAuthMethod`, a non-boolean flag, a 257-character description, a 129-character name, an unknown implementation, a non-authenticator class and an unknown namespace each answered 500.
  - `Foo`, `ClientSecret` and `Name` in a PUT each answered 400.
  - The name lookup is exact.
- **GET** never answers `ClientSecret` or `Name`.
- **CHANGESECRET.** `{ClientSecret:x}` stored it (length 19). `{}` answered 400, `{ClientSecret:""}` answered 200 and cleared it, an extra key answered 400, and an absent server answered 404.
- **Audit.** The vendor's `OAuth2ResourceServerChange` rows (create, modify, and mapping create/modify/delete; enabled) carry no secret.
- **Mappings.**
  - A PUT created a mapping (201), and a PUT on a key another server held moved it (200).
  - Keys are stored lower-cased and read case-insensitively.
  - An unknown application, namespace or service answered 500, and an absent resource answered 422.
  - LIST needs `service`, and DELETE of an absent mapping answered 404.
  - Deleting the server removed its mappings.

**Why a port.** One place carries the mapping calls and the synthesized `MAPPINGS` and `AUTHENTICATORS` reads, checks an authenticator class, and strips credential-named authenticator settings. The class check reads `%Dictionary` (12.5's `CredentialUsable` precedent) and completes no operation, so it adds no AD-27 case.

**Why a move is permitted.** The owner's "developer tool first" direction (2026-09-23): the vendor allows the move, so OcuPilot permits it, names the effect, and confirms it as destructive. `Held` in the fingerprint keeps the other server's side inside the reviewed state.

**Why mappings are action writes on the server.** A mapping's own entity would need a new entity type, a descriptor and a two-parameter id, and `AdminPort.SPLITQUERIES` splits on `/`, which web application names contain. Adding and removing a member of a server's mapping set over a fresh read is AD-56 (ii)'s delta. It is also AD-51's port-built body from declared non-secret arguments, which becomes a second named case (Q1).

**Form: four tabs on `app-form-tabs`.** The classic editor is one untabbed page whose field sets are Audiences, Access Token Validation and Authenticator. Its mappings are the classic list page's Mappings tab. The tabs are named for those groups:

1. **General**: Name*, Description, Enabled, Server description* (a select of issuers), Audiences* (a list with Add and a Remove per item), Required scope.
2. **Access token validation**: JWT, Call introspection (checked and disabled while JWT is off, as the classic page does), OpenID Connect, Client ID, Client secret (masked, with the shared hint), Authentication method (HTTP Basic, Form post, none). The last three are disabled unless Call introspection is on.
3. **Authenticator**: Namespace, Implementation, and one control per setting from `DescribeSettings()`: a checkbox for a boolean, a number for an integer or double, text for a string, and JSON text for an object (a parse failure is `OAUTH.AUTHENTICATOR.SETTING`).
4. **Mappings**: Web Gateway mappings (Application) and ODBC/JDBC mappings (Namespace), each row with Remove, and an Add row: Service, Key (a select of applications or namespaces, plus "* (Default)").

The action bar has Save (primary) and Delete.

**Strings** (`oauthResourceServer*`):

- Labels:
  - "Resource server", with the tab names above;
  - "Server description", "Audiences", "Add audience", "Required scope";
  - "JWT", "Call introspection", "OpenID Connect", "Client ID", "Authentication method", "HTTP Basic", "Form post";
  - "Authenticator", "Implementation";
  - "Web Gateway mappings", "ODBC/JDBC mappings", "Application", "Service", "Key", "* (Default)", "Add mapping".
- Consequence and empty states: "This also deletes the resource server's service mappings." and `oauthResourceServersEmptyAgent` "create an OAuth 2.0 resource server".
- Partial saves: "Saved. The client secret was not stored: {reason}" and "Saved. {count} service mappings were not changed: {reason}".
- The move: "Moves this mapping from {server}." at the Add row, and the card's consequence "Moves this service mapping from the resource server that holds it."
- Refusal: "Set this setting in the classic portal."
- The field sentences for each code.
- Reuse "Leave empty to keep the stored value." (`oauthClientSecretHint`), `processDetailsGroupGeneral` and `oauthTabResourceServers`.

**Integration ACs.**

- Consumes:
  - Story 6.4's tab;
  - AD-53's route and handler, and AD-55's Save;
  - Story 12.4's server descriptions (a real one on `ocupilot-b-ci`), `WebAppList`'s read and `Kernel/Shell/Namespaces`;
  - Epic 9's `app-form-tabs` (both editors).
- Introduced: `OAuthResourceServerPort`, the form descriptor, six tools and three routes, consumed here by the editor, the row action and agent dispatch (AC1-AC8).
- Consumed-by: Stories 12.7 and 12.8 (they build on `app-form-tabs` and this port pattern), and Story 12.9 (it removes the last two exemptions).

**Ledger inbox:** DW-1644 is addressed (the client editor task, AC10, AC11).

**Expected `footprint_extensions`:**

- Contended files: `AdminPort.cls`, `Prohibited.cls`, `Router.cls` and `Classification.cls` (with `ToolFields` regenerated), and `screen-outlet.ts`.
- Shared-append files: `Error.cls`, `strings.ts`, `_components.scss` and EXPERIENCE.md.
- Other files: `screen-action-handler.ts` (+ spec), `proposal-view.ts` and `proposal-card.spec.ts`, `app.ts`/`app.spec.ts`, `structural-baseline.json`, the budget pair, the roster files above, and the spine's AD-4.

**Lead answers at the spec gate (2026-09-25):**

- Q1: accepted. AD-51 now names `OAuthResourceServerPort` as its second port-built case (spine amended at the gate, memlog appended).
- Q2: accepted. The implement pass updates AD-44's by-name list in the spine in the same pass that drops `OAuthResourceServerTab`'s declaration (the OAuth exemption then has two declaring tabs; the three exemptions and four declarations are recomputed from the list). The epic context is recompiled by the lead before 12.7's plan.
- Q3: accepted: the two `*` default mappings are offered as removable unsaved rows on the first server, as the classic page does.
- `structural-baseline.json`: the new editor enters with no allowance of its own. The one exception is the shell-chrome rows every route carries (the panel resize handle and the status-bar connection line, DW-1583/DW-1584, Epic 15's), which a new route inherits; nothing else may be added.
- Bundle: if the measured initial total crosses 1745kB, re-base `maximumWarning` per DW-1166 (5% above the measured bytes, only the value line and the pinned literal); if it crosses 1900kB, HALT.

**Open questions for the lead** (the spec is built on each recommendation):

- **Q1, AD-51 (Rule 20).** Name `OAuthResourceServerPort` as AD-51's second port-built case. It builds `ResourceServerMapping`'s query and body from `addmapping`/`removemapping`'s declared `Service` and `Key`.
- **Q2, AD-44.** The declaring list becomes `OAuthServerTab` and `OAuthServerClientTab`, with "`OAuthResourceServerTab` at Story 12.6". Update `epic-12-context.md`. The spine change also makes the context cache stale, so re-run the pre-warm.
- **Q3, default mappings.** The editor offers the classic page's two `*` defaults as removable unsaved rows on the first server. Leaving them out is the alternative.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. OAuth-writing tests run on `ocupilot-b-ci` only (52777/1976), one class per call, each awaited in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the deployed bundle is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth-resource-server-editor.browser-spec.mjs browser/oauth-client-editor.browser-spec.mjs browser/oauth.browser-spec.mjs browser/oauth-server-description-editor.browser-spec.mjs` (loop) -- expected: every leg passes.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>` (loop), one call each for:
  - `OAuthResourceServerCreate`, `OAuthResourceServerUpdate`, `OAuthResourceServerSecret`, `OAuthResourceServerMappings`, `OAuthResourceServerAuthenticator`, `OAuthResourceServerWire` (armed);
  - `OAuthTabs`, `OAuthDelete`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `PortFixture`, `Prohibited`, `Descriptor`, `DerivedFields`, `Wire`, `WireOAuthRead`, `WireSecurityRead`.

  Expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, and the bundle total recorded.
- The full browser suite is CI's (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

| AC | Mutation |
| --- | --- |
| AC1 | The Save drops `mappingsAdded` on create |
| AC2 | `Expand` stops filling unsent authenticator settings |
| AC3 | The row action's typed-name check is dropped |
| AC4 | The Save sends `CHANGESECRET` for an empty field (the stored length reads 0) |
| AC5 | `WeakensByEffect` stops naming `OAUTH.MAPPINGMOVE` |
| AC6 | The port stops stripping a credential-named setting |
| AC7 | Drop the create's absence read (`CREATES` 0) |
| AC8 | Remove the form route's gate |
| AC9 | Restore the exemption |
| AC10 | The client page's `afterRefusal` stops calling `tabToOpen` |
| AC11 | A 1400px `min-inline-size` on the mappings table |

**Measure in implement and record here:** the bundle total, and the vendor audit rows for a mapping add and remove made through the port.

**Recorded:**

- Bundle initial total 1,704,116 bytes (main 1,558,498 + styles 145,618); under the 1745kB warning, no re-base.
- Vendor audit rows through the port (ocupilot-b-ci): ADDMAPPING logs one `%System/%Security/OAuth2ResourceServerChange` "Create Resource Server Mapping (%Service_Bindings||%sys)" with Service, Key and Resource; REMOVEMAPPING logs one "Delete Resource Server Mapping (%Service_Bindings||%sys)" carrying only its JSONData. Neither carries a secret.
- mutation: `HandleCreate` sets the added rows to `[]` → OAuthResourceServerCreate `TestACreateThroughTheRouteStoresTheDefaultMappings` red (AC1).
- mutation: `Expand` quits before filling → OAuthResourceServerUpdate `TestAnEditSendsTheCompleteSet`, `TestTheAgentsEditKeepsTheUnsentSettings` red (AC2).
- mutation: the page's `onDelete` calls `confirmDelete` without the typed-name dialog → page spec "AC3: Delete sends nothing until the stored name is typed" red (AC3).
- mutation: `HandleUpdate` stores the secret when the field is empty → OAuthResourceServerSecret `TestTheSaveStoresTheSecretAndNoReadCarriesIt` red (AC4).
- mutation: `WeakensByEffect` never calls `MovesMapping` → OAuthResourceServerMappings `TestAMoveIsMintedDestructiveAndAppliedAtConfirm` red (AC5).
- mutation: `Stripped` removes nothing → OAuthResourceServerAuthenticator `TestTheProbesKeyIsNeverReadAndKeptAcrossASave` red (AC6).
- mutation: `CREATES` 0 on the create tool → OAuthResourceServerCreate three tests red, the confirm-time absence test among them (AC7).
- mutation: `HandleForm` clears the gate's refusal → OAuthResourceServerWire `TestACallerWithoutTheResourceIsRefusedEverywhere` red (AC8).
- mutation: the tab's exemption restored → classic-links.test.mjs "the shipped descriptor roster passes" red (AC9).
- mutation: the client page's `afterRefusal` drops `tabToOpen` → oauth-client-form.page.spec "DW-1644: a refusal on a JWT Settings field" red; the same on the resource server page reddens its AC10 test (AC10).
- mutation: `.ocu-oauth-resource-server-mappings` 1400px `min-inline-size`, rebuilt and redeployed → oauth-resource-server-editor.browser-spec AC1 red on overflow at 1280 and 720 (AC11).
- Every mutation reverted byte-identically (md5 checked), recompiled with its descendants or rebuilt and redeployed, and its test re-run green.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- AD-29 against the frozen pair set. The Always bullet "Privileges" and AC8 fix every tool, route and port call at `%Admin_Secure:USE` + `%DB_IRISSYS:READ`. Run as a real least-privileged principal on `ocupilot-b-ci` (AD-29), those pairs alone cannot create or edit a resource server: create answers 422 (issuer not found), the GET answers `IssuerEndpoint ""`, and a Description-only PUT answers 500 (`<INVALID OREF>` in `%OnBeforeSave`). The cause is that `OAuth2.ServerDefinition.OpenByIssuer` runs `$$$CheckForClassResourceReturnNullAndStatus` against `RESOURCEREQUIRED = "%Admin_OAuth2_Client"` (`irissys/OAuth2/ServerDefinition.cls:11,226`).

Recommended amendment: under AD-29, the resource-server screen's declared set becomes three pairs: add `%Admin_OAuth2_Client:USE` to `OAuthResourceServerTab`, `OAuthResourceServerForm` and the six tools. AC8 then reads "without `%Admin_Secure:USE` or `%Admin_OAuth2_Client:USE`", and `OAuthResourceServerWire` gets a second denial leg. AD-8's text is unchanged. Alternative: form and tools only, which is a new named AD-8 case (a vendor class the call reaches checks a resource its endpoint's `ResourcesOR()` omits), and the lead has reserved that decision. Resuming at `in-progress` re-enters implement; the delta is about 10 files.

- **Also for the lead:** the second `deferred:` entry. The vendor writes a custom authenticator's credential-named setting in plain text into `OAuth2ResourceServerChange` audit rows, and AD-35 requires a new named declaration for a vendor secret found in another event.
- **Implementation state:** complete in the working tree, uncommitted, baseline `4a9f5037`. The handoff reports every targeted check green on `ocupilot-b-ci`:
  - the 20 story and roster classes, one run per class, 0 failed;
  - `npm test`: 1409 tool tests and 1305 component tests, 0 failed;
  - `screen-mirror` and `field-lists` checks: no drift;
  - `check-objectscript`: 42 classes, clean;
  - `lint-docs`: clean;
  - smoke: 49/49.
  The stage agent has not verified this list yet: step-03 Verify and step-04 review did not run.
- **Browser specs:** `oauth-resource-server-editor` 6/6, `oauth-client-editor` 6/6, `oauth-server-description-editor` 5/5, `oauth` 4/4 (handoff run, deployed bundle).
- **Full ObjectScript sweep:** not run, because the stage halted before dev_complete.
- **Bundle initial total:** 1,704,116 bytes. No re-base.
- **Deviations for review:**
  - The mapping tools' fingerprint subject is `Mappings,Held,Service,Key`; the spec says `Mappings,Held`.
  - `Classification` lists `Audiences[]`, `Authenticator.Namespace` and `Authenticator.Implementation`, not an opaque `Authenticator`.
- **Paths edited outside the footprint:**
  - `Port/AdminPort.cls`, `Kernel/Proposal/Prohibited.cls`, `Api/Router.cls`, `Api/Error.cls`
  - `Screen/Tool/Classification.cls`, `Screen/Tool/ToolFields.cls` (regenerated)
  - `ui/src/app/app.ts`, `ui/src/app/app.spec.ts`, `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`
  - `ui/src/app/shell/screen-outlet.ts`, `shell/screen-action-handler.ts` and its spec, `core/proposal-view.ts`, `shell/proposal-card.spec.ts`, `core/screens.generated.ts`
  - EXPERIENCE.md, the spine (AD-44) and `.memlog.md`, `scripts/ci-throwaway.sh`, `ui/browser/structural-baseline.json`
  - `ui/tools/classic-links.test.mjs`, `ui/tools/navigation.test.mjs`
  - `ui/browser/oauth{,-client-editor,-server-description-editor}.browser-spec.mjs`
  - roster test classes `EndpointCoverage`, `OAuthDelete`, `OAuthTabs`, `PortFixture`, `PortGate`, `Prohibited`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `Wire`, `WireOAuthRead`, `WireSecurityRead`
