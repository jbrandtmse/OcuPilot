---
title: 'Story 12.4: The OAuth 2.0 client server-description editor'
type: 'feature'
created: '2026-09-24'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-8-the-device-editor.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-3-copy-and-purge-the-audit-database.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Server descriptions tab is read-only. Its name cells link out to the classic Server Description page, so nobody can create, edit or delete the authorization server a client talks to inside OcuPilot. Discover and Update JWKS are also classic-only.

**Approach:** Add a `form-page` editor at `security/oauth/edit`, opened from the tab's name cell and its Create action. It round-trips create, edit and delete through five write tools over `Security.OAuth2.Client.ServerDefinition`:

- Save and the tab's row actions use the two fixed mechanisms, AD-55 and AD-53.
- The editor's Discover fetches the issuer's published metadata into the form, where the user reviews it before Save.
- Update JWKS refreshes the stored key set and reports what happened.
- A new port, `OAuthServerPort`, maps OcuPilot's id (the issuer) to the vendor's `serverId`. It also carries the two calls the admin API cannot carry, which are the two new named AD-27 cases (open questions Q2 and Q3).

## Boundaries & Constraints

**Always:**

- **Identity.** The entity id is `IssuerEndpoint`, exactly as the tab's name column shows it. It is percent-encoded in one segment by the shared encoder (AD-13). Because the vendor's issuer index is exact, the id canonicalizes to itself, so there is no `IDRULES` entry.
  - `OAuthServerPort` resolves `issuer` → `serverId` through the endpoint's own `LIST`, by exact comparison, for `GET`, `PUT`, `DELETE`, `TOKEN` and the two port types.
  - No LIST match answers 404. That 404 is what AD-54's absence read sees.
- **Save sends the complete property set (AD-4, uniform).** Save reads fresh, applies the diff, and sends every template field.
  - `Metadata` is expanded to **every** derived member (Q4), with each absent one sent in its empty form: `""` for a URI, `[]` for a list, `false` for a boolean.
  - This is needed because the vendor merges `Metadata` member by member (measured), so a member left out would survive a clear.
  - The complete set is used even though the endpoint keeps omitted fields (measured, Q1).
- **Create is `POST`, not upsert.** A vendor `PUT` on an absent row answers 404. The create tool declares AD-54's absence fingerprint anyway. The vendor's 409 on a duplicate issuer maps to a field violation on `IssuerEndpoint`.
- **Form rules.** They are enforced identically by each tool's `ArgumentProblem` and by the Save route, and written once on the server as `detail.violations[]` (AD-39):
  - `IssuerEndpoint` is required and is an absolute `http`/`https` URL.
  - `SSLConfiguration` is required.
  - `Metadata.authorization_endpoint` and `Metadata.token_endpoint` are required on create **and** update. The vendor's `PUT` accepted clearing `token_endpoint` and stored a definition that no longer validates (measured).
  - `ServerCredentials` is empty or names an existing X.509 credential. The vendor answers 500 #8886 otherwise; the port maps that to a field violation.
  - A `Metadata` key must be a derived member, and its value must have the member's shape. The vendor silently ignores an unknown member or a wrongly-shaped list (measured / read).
- **Secret.** The only secret is the registration access token, `InitialAccessToken`. It is declared in `secretArguments` on both descriptors.
  - It is masked, never pre-filled and never read back: the admin API's `GET` never returns it.
  - It is written only through the `TOKEN` type with a body of exactly `{InitialAccessToken}` (AD-56 (i), the `UserPassword` precedent).
  - An empty field on the form means "leave the stored token unchanged".
  - The token never appears in a proposal's arguments, a diff, the ledger, screen context, a log line or a status (AD-35).
- **Delete.**
  - It is refused by name before any port call while `ClientCount` > 0. The vendor refuses too (500 #5823, measured).
  - It is permitted, behind the typed issuer, while resource servers reference the description. The vendor deletes it and leaves them dangling (measured), and the consequence line says so ("developer tool first").
- **Discover (screen only).** It runs `POST /api/ocupilot/oauth/server-description/discover` `{IssuerEndpoint, SSLConfiguration}`.
  - The port first applies the endpoint's gate, `%Admin_OAuth2_Client:USE`.
  - It then calls `OAuth2.ServerDefinition.GetServerMetadata(issuer, ssl, .metadata)` in `%SYS` (AD-16) and returns `metadata`'s derived members as JSON. It **saves nothing** (Q2).
  - A failure is a named refusal with one of four causes, and the raw text goes to the log only.
- **Update JWKS.**
  - It is an action-style write (AD-51): `READTYPE` `JWKS` (port-synthesized `{JwksUri, SSLConfiguration, ServerCredentials}`) and `WRITETYPE` `REFRESHJWKS`.
  - The port calls `OAuth2.ServerDefinition.Open(id).RefreshJWKS(1, 1, .sc)` in `%SYS` after the same gate (Q3).
  - The precondition is a non-empty `JwksUri`. It is refused by name otherwise.
  - The tool description states the vendor effect: a changed key set clears `ServerCredentials`.
- **Privileges.** Every tool, route and port call requires the tab's own pair set, `%Admin_OAuth2_Client:USE` + `%DB_IRISSYS:READ` (AD-8). Screen Saves and row actions emit no OcuPilot marker (AD-53). Agent confirms do (AD-15).
- **Change events.** Every write publishes `(oauth2-server-definition, instance, <issuer>)` (AD-14). An edit that changes the issuer navigates to the new id with `replaceUrl`, as a create does.
- **UI rules.**
  - Tokens only, dark theme correct.
  - A new screen has no DW-1337 baseline allowance.
  - Non-ASCII in code is written as `\u` escapes (Rule 14).
- **Contended files.** Read `git show origin/OCU-1-epic9:<path>` first, touch only this story's own lines, and list each under `footprint_extensions:`.

**Never:**

- No third write mechanism.
- No agent Discover tool. A model-driven outbound fetch to a caller-chosen URL is not part of this story. The agent sets `Metadata` members directly.
- Never pass `?discover=1` to the admin API. It saves unreviewed, and it discards the body's `Metadata`.
- No "JWKS from file". The admin API cannot carry `SetPublicJWKS`, so that option stays classic-only (a known gap, see Design Notes).
- No tabbed form, and `form-tabs.ts` is not adopted. The classic page is a single form with fieldsets.
- No suggested prompts. Story 11.3's descriptor key does not exist on this branch.
- No change to the other four OAuth tabs' classic links (that is Story 12.9).
- No `data-table*` change beyond this tab's own declaration.
- No change to Epic 9's editors.
- No test that creates OAuth configuration on `ocupilot-slot-b`.
- No internet dependency in any test.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create | New issuer, SSL, both endpoints | 201. The page opens `security/oauth/edit/<issuer>` showing "Saved". The tab lists the row. | None expected |
| Create, duplicate | Issuer already present | 422. Violation on `IssuerEndpoint`. Nothing written. | Vendor 409 mapped |
| Create/edit, required endpoint empty | `token_endpoint` `""` | 422. Violation on that field. No port call. | Form rule |
| Edit, partial change | Userinfo changed, revocation cleared | GET shows the change and the cleared member gone. Every other member, including lists not shown on the form, is unchanged. | None expected |
| Edit, issuer renamed | New unique issuer | 200. The page navigates to the new id. Client count is unchanged. | Duplicate → as for create |
| Bad X.509 alias | `ServerCredentials` names nothing | 422. Violation on `ServerCredentials`. Nothing stored. | Vendor 500 #8886 mapped |
| Unknown or ill-shaped metadata | `Metadata.bogus` or `scopes_supported: "x"` | 422 (`TOOL.ARGUMENTS` for the agent). | Refused, never dropped |
| Discover OK | The fixture's issuer | 200. Endpoints and the metadata table fill, and the form is dirty. The vendor row is unchanged (GET 404 or equal). | None expected |
| Discover fails | Unreachable / non-200 / not JSON / issuer claim differs | A named refusal with the cause. The form is unchanged. | Raw text logged only |
| Update JWKS OK | Stored `jwks_uri` = the fixture | 200. "Updated the key set from {url}." The vendor `PublicJWKS` is non-empty. | None expected |
| Update JWKS, no URL | `jwks_uri` empty | Refused by name before the port. The editor hides the button. | Precondition |
| Update JWKS, fetch fails | Fixture stopped | A refusal banner. Nothing stored. | Vendor status mapped |
| Delete, clients use it | `ClientCount` 1 | 409, refused by name. The row remains. | Before any port call |
| Delete, resource server uses it | `ResourceCount` 1 | Deleted after the typed issuer. The consequence line said the resource server is left without one. | None expected |
| Token | Masked value on Save | The stored length is > 0. No read, context, ledger or log carries it. An empty field sends nothing. | `TOKEN` failure → a banner after "Saved" |
| No privilege | Caller lacks `%Admin_OAuth2_Client:USE` | 403 naming the pair on the Save routes, discover, row actions and mint. | Before any port call |

</intent-contract>

## Code Map

**Vendor (read on `ocupilot-slot-b`, `%SYS`, `GetTextAsString`, because the class is hidden).**

`%Api.Admin.Endpoints.Security.OAuth2.Client.ServerDefinition` answers these types:

| Type | Id | Route |
| --- | --- | --- |
| LIST | 0 | `/v2/security/oauth2/client/server-definitions` |
| GET | 1 | `…/server-definition?serverId=` |
| PUT | 2 | `…/server-definition?serverId=` |
| DELETE | 3 | `…/server-definition?serverId=` |
| POST | 5 | `…/server-definition` (create; 201 + `Location`, 409 duplicate) |
| TOKEN | 10 | `POST …/server-definition/initial-access-token?serverId=` with `{InitialAccessToken}` |

- `ResourcesOR()` is `%Admin_OAuth2_Client` for every type. `ShouldRunAsync()` is 0 for every type.
- The template `PutRequestBodySchema` is `{IssuerEndpoint, SSLConfiguration, ServerCredentials, Metadata:{}}`.
- `PutAndPost` sets each top-level field only when `%IsDefined`. `Metadata.ImportJSON` is per member. `IsDiscovery` is set from `?discover` unconditionally.
- LIST answers `ID, IssuerEndpoint, ClientCount, ResourceCount`.
- GET answers the four template fields; `Metadata` leaves out empty members.

Supporting vendor classes:

- `irissys/OAuth2/ServerDefinition.cls`:
  - `GetServerMetadata` :247 [Internal] makes one outbound GET of `<issuer>/.well-known/openid-configuration`. It requires 200, `application/json` and an `issuer` claim that matches, and it saves nothing.
  - `RefreshJWKS` :404 fetches `jwks_uri`, sets `PublicJWKS` and clears `ServerCredentials` on a change.
  - `DeleteId` :803.
  - `%OnDelete` :864 writes a vendor audit record.
  - `AuditUpdate` :1071 is called from the save path (inference). The implement stage measures it.
  - `%OnValidateObject` :718 requires both endpoints.
- `irissys/OAuth2/Server/Metadata.cls` has 44 members: 12 URIs, 26 `%List`, 6 `%Boolean`.
- `irissys/%CSP/UI/Portal/OAuth2/Client/ServerConfiguration.cls` is the classic editor.
  - Fieldsets in order: issuer, SSL, registration access token; Authorization server; JWT settings; a read-only metadata table.
  - Discover handler :638. Update JWKS handler :524. `RESOURCE` is `%Admin_OAuth2_Client`.

**Models to copy.**

- The device editor, Story 8.8:
  - `Screen/Descriptor/DeviceForm.cls` :19-49 (`form-page`, `sideBarPosition` 0, route `<list>/edit`, no tools)
  - `Screen/Tool/DeviceCreate.cls`, `DeviceUpdate.cls` and `DeviceDelete.cls`
  - `Area/OsMgmt/DeviceSave.cls`: `HandleCreate` :54, `Create` :113, `HandleUpdate` :81, `Update` :155 (`Mint.Merge`), `PortViolations` :224, `Gate` :331, `RenderViolations` :319
  - `Area/OsMgmt/DeviceRules.cls` (`HandleForm` :230, `Validate` :75)
  - `Api/Router.cls` :116-119 and :437-464
  - Client: `ui/src/app/areas/os-management/device-form.store.ts` (`open` :322, `save` :378, `publish` :544) and `device-form.page.ts` (`onSave` :528-549)
  - `device-actions.ts` (`createFormFor`) and `core/navigation.ts` :162-191 (`editorScreenFor`)
- In-area: `Area/Security/X509Save.cls`, `X509Rules.cls`, `ui/src/app/areas/security/x509-form.{page,store}.ts`.
- Tab row delete: `Screen/Tool/OAuthClientDelete.cls` (`SCREENACTIONS`, `IdArgument`/`IdParam` overrides, `StateDiff`).
- Secret-only body: `Screen/Tool/UserPassword.cls` (`SECRETBODY`), with `secretArguments` in `Screen/Descriptor/UserList.cls` :73.
- Port subclasses:
  - `Port/TokenPort.cls`: synthesized types and query rewrite; `Invoke` :55.
  - `Port/AuditPort.cls`: `COMPOSEDTYPES` :55.
  - `Port/ProcessPort.cls`: completes through a `%SYS` class after repeating the endpoint's guard; `Invoke` :41, :58, :79.
  - A tool picks its port with `PORTCLASS` (`Write.cls` :114).
- `Screen/Tool/Write.cls`: `SCREENACTIONS` :157, `IdArgument` :414, `IdParam` :421, `READANSWERS`, `PRECONDITIONFIELD`, `FINGERPRINTSUBJECT`, `SENDSBODY`.
- `Api/ScreenAction.cls` `Run` :166; `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :39-42 and `DESTRUCTIVE_CONSEQUENCES` :146-149; `sendFor` (Story 12.3).

**This story's surfaces.**

- `Screen/Descriptor/OAuthServerDescriptionTab.cls`:
  - `rowActions []`, `primaryAction ""`.
  - The exemption is declared with `rowLink PID←ID`.
  - `toolIdentifier` is `security.oauthserverdescriptions`.
- `ui/src/app/shell/data-table.ts` :494-516 lets a declared exemption with a `rowLink` win. Otherwise it links `editorScreenFor`.
- `ui/tools/classic-links.mjs` counts one exemption and five declaring descriptors. The pins are `classic-links.test.mjs` :446-460 and `Test/OAuthTabs.cls` :77.
- Field lists:
  - `Screen/Tool/FieldLists.cls` :223-228 already carries the template list, with `Metadata` an object without members.
  - `Test/FieldDerive.cls` `ClassRows` :284 is the class-source precedent (wallet `envelope`). It maps `%List` to a member-less array.
  - `Screen/Tool/Classification.cls` is keyed by tool name. Entries start at :94; the device entries are around :331-356. A member-less object must be `opaque`, and `ServerCredentials` does not match the credential pattern.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :174 lacks `oauth2-server-definition`.
  - `PermittedChangeFields` :386, `PermittedCreateFields` :458, fail-closed list :537, OAuth branch :614-617 (`OAuthEntry` → `ReviewedFewOnly` :1177), `UncoveredWriteTools` :640.
  - The type exists in `Kernel/EntityType.cls` :37.
- `Port/AdminPort.cls`: `MUTATINGTYPES` :261 and `BODYLESSTYPES` :277 have no ServerDefinition entries.
- `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :95-111.
- `ui/src/app/core/strings.ts`: OAuth block :693-735 and :1562-1572; `} as const` is at :1733.
- EXPERIENCE.md Fixed-strings: the last row is :470 (Story 12.3). The UX-DR33 tabs rule is in `epics.md` :423.
- Budget: `ui/angular.json` :53-55 (warning 1378 kB, error 1600 kB).
- Test fixtures: `Test/OAuthProbe.cls` (`ISSUERA`/`ISSUERB`, `EnsureClient` :298, the resource fixture :67-73, cleanup :120-135), `Test/OAuthDelete.cls`, `ui/browser/oauth.browser-spec.mjs`, `oauth-delete.browser-spec.mjs` and `device-editor.browser-spec.mjs`.
- **Epic 9 hunks** (`origin/OCU-1-epic9`, from the merge base):

  | File | Epic 9 changes | Where this story goes |
  | --- | --- | --- |
  | `Router.cls` | 96-102, 145, 305-342, the tail | Append after its block at merge |
  | `screen-outlet.ts` | 28-34, after 110, 302 | Mid-map entry near :108 |
  | `Classification.cls` | 268, 310, the tail | After :356 |
  | `AdminPort.cls` | `MUTATINGTYPES`/`BODYLESSTYPES` (single lines, so a union at merge), 645-753 | — |
  | `Prohibited.cls` | Whole file, including `COVEREDTYPES` :174 (one-line union at merge) | — |
  | `strings.ts` | 180 and the tail | Next to the OAuth block |
  | `_components.scss` | The tail | Own classes only |

  `navigation.ts` limits `screenForEntityType` to lists. After the merge, a change toast for this type may find no screen (inference); check it at the merge.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Test/FieldDerive.cls` (then run `scripts/field-lists.sh` and `node tools/field-lists.mjs`) -- add the class-sourced list `Security.OAuth2.Client.ServerDefinition:OAuth2.Server.Metadata` (class `OAuth2.Server.Metadata`, envelope `Metadata`), beside the template list. Regenerate `FieldLists.cls` and `ToolFields.cls` -- AD-3, Q4. The metadata member set is derived, never typed.
- `src/OcuPilot/Port/OAuthServerPort.cls` (new, extends `AdminPort`; add it to `Test/PortGate.cls` `ROSTER`). `Invoke` for `Security.OAuth2.Client.ServerDefinition` does five things:
  - It rewrites `issuer` to `serverId` through `##super(…,"LIST")`, by exact match. For `GET` it adds `ID`, `ClientCount` and `ResourceCount` from that row.
  - `JWKS` (a read): the GET, flattened to `{JwksUri, SSLConfiguration, ServerCredentials}`.
  - `REFRESHJWKS`: the gate, then `RefreshJWKS(1,1,.sc)` in `%SYS` with save and restore (AD-16). The status is normalized (AD-39).
  - `ClassMethod Discover(pIssuer, pSSL, Output pMetadata As %DynamicObject) As %Status`: the gate, then `GetServerMetadata`. It exports the derived members and returns a cause in `{unreachable, status, content, issuer}`.
  - Everything else goes to `##super`.

  Append `…ServerDefinition/POST`, `/PUT`, `/DELETE` and `/TOKEN` to `MUTATINGTYPES`, and `/DELETE` to `BODYLESSTYPES` (contended; union at merge).
- `src/OcuPilot/Screen/Tool/OAuthServerDescription{Create,Update,Delete,UpdateJwks,SetToken}.cls` (new). Common to all five: `DESCRIPTORCLASS` is the tab, `PORTCLASS` is `OAuthServerPort`, `IdArgument` is `IssuerEndpoint`, and `IdParam` is `issuer`. Tool names are `security.oauthserverdescriptions.{create,update,delete,updatejwks,settoken}`.

  | Tool | Parameters | Methods and notes |
  | --- | --- | --- |
  | Create | `CREATES` 1, `READTYPE` GET, `WRITETYPE` POST, `SENDSBODY` 1, `CHANGEACTION` created | `SettableFields`, `InputSchema` (members named from the derived list), `ArgumentProblem` (form rules), payload expansion of `Metadata` to the full member set |
  | Update | `READTYPE` GET, `WRITETYPE` PUT, `SENDSBODY` 1 | The same settable fields, the same rules and the same expansion |
  | Delete | `WRITETYPE` DELETE, `SENDSBODY` 0, `DESTRUCTIVE` 1, `SCREENACTIONS` delete | `READANSWERS`/`FINGERPRINTSUBJECT` = `IssuerEndpoint,ClientCount,ResourceCount`; `PRECONDITIONFIELD` `ClientCount` (must be 0) |
  | UpdateJwks | `READTYPE` JWKS, `WRITETYPE` REFRESHJWKS, `SENDSBODY` 0, `SCREENACTIONS` updatejwks | Subject and precondition are `JwksUri`, plus `SSLConfiguration` and `ServerCredentials` in the subject |
  | SetToken | `WRITETYPE` TOKEN, `SECRETBODY` `InitialAccessToken`, `READTYPE` GET | Subject `IssuerEndpoint` |

  Every `DESCRIPTION` says that nothing changes until the user confirms.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- create and update entries (`IssuerEndpoint`, `SSLConfiguration` and `ServerCredentials` ordinary, `Metadata` opaque) and a settoken entry (`InitialAccessToken` secret, authored). Regenerate `ToolFields.cls`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- cover `oauth2-server-definition`:
  - `COVEREDTYPES`, a `TYPE…` parameter, the :537 list, and a branch beside :614 into `ReviewedFewOnly`;
  - `PermittedChangeFields` and `PermittedCreateFields` get the four template fields.

  Nothing is self-protective: OcuPilot owns no OAuth object.
- `src/OcuPilot/Screen/Descriptor/OAuthServerDescriptionForm.cls` (new):
  - Route `security/oauth/edit`, `form-page`, position 0.
  - The tab's privileges, and `entityType` `oauth2-server-definition`, scope `instance`, `id single`.
  - `secretArguments ["InitialAccessToken"]`, `classicPage` `%CSP.UI.Portal.OAuth2.Client.ServerConfiguration`, `toolIdentifier` `security.oauthserverdescriptionform`.
- `src/OcuPilot/Screen/Descriptor/OAuthServerDescriptionTab.cls`:
  - Remove `classicLinkExemption` so the name cell opens the editor.
  - Add `primaryAction create` and `rowActions [delete, updatejwks]` and `secretArguments ["InitialAccessToken"]`.
  - Set `table.emptyNextKey` to `""` and `emptyAgentKey` to a new `oauthServerDescriptionsEmptyAgent` string, as `OAuthClientTab.cls` :78-79 does.
  - Rewrite the doc paragraph about the link.

  Then regenerate `screens.generated.ts`.
- `src/OcuPilot/Area/Security/OAuthServerRules.cls` and `OAuthServerSave.cls` (new, modeled on `DeviceRules`/`DeviceSave`):
  - The form read answers the fields, the derived member list with shapes, and the SSL and X.509 names the caller can read through their screens' own reads (AD-5), or empty.
  - Create, update and discover handlers.
  - After a successful create or update whose body carried `InitialAccessToken`, run the settoken tool's operation. A token failure answers the saved entity plus a `tokenRefused` reason.
- `src/OcuPilot/Api/Router.cls` (append) -- `GET /oauth/server-description/form`, `POST /oauth/server-description/discover`, `PUT /oauth/server-description/:id`, `POST /oauth/server-description`, with thin wrappers. The sub-resources go before `:id`.
- `src/OcuPilot/Api/Error.cls` (own entries) -- the discovery causes, `OAUTH.SERVERINUSE`, `OAUTH.NOJWKSURI`, `OAUTH.JWKSFAILED`.
- `ui/src/app/areas/security/oauth-server-description-form.{store,page}.ts` (+ specs), `oauth-actions.ts` (Create through `createFormFor`, injected in `app.ts`) -- the form in the classic order, per Design Notes:
  - Discover; Update JWKS (only when saved, not dirty, and the stored `jwks_uri` is non-empty); Delete (typed issuer). Each fires through `handler.sendFor(OAuthServerDescriptionTab, …)`.
  - The status line, the change event, the unsaved guard, "Saved", and create or rename followed by `replaceUrl`.
- `ui/src/app/shell/screen-outlet.ts`, `screen-action-handler.ts` -- the page entry, the tab in `SCREEN_ACTION_DESCRIPTORS`, and the delete consequence in `DESTRUCTIVE_CONSEQUENCES`. Own lines only.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md (append after :470, Story 12.4, FR-44), `ui/src/styles/_components.scss` -- the strings in Design Notes. Own classes only.
- `src/OcuPilot/Test/OAuthIssuerFixture.cls` (new) -- a test-only local issuer. `Start(pPort)` JOBs a TCP responder bound inside the instance that answers these paths:
  - `/.well-known/openid-configuration` (issuer `http://localhost:<port>`, both endpoints, `jwks_uri`, two lists, one boolean);
  - `/jwks` (a fixed one-key set);
  - `/wrong-issuer/.well-known/…` (a mismatched claim).

  `Stop()` ends it. No web application, and no internet.
- Tests (new, each under 500 lines, one class per call, `ocupilot-b-ci` only):
  - `Test/OAuthServerCreate` -- declarations, create through the route, duplicate, form rules.
  - `Test/OAuthServerUpdate` -- the complete set, clearing a member, rename, bad alias.
  - `Test/OAuthServerDelete` -- clients refuse, a resource server is left dangling, the row action.
  - `Test/OAuthServerDiscover` -- fixture OK, nothing saved, the four causes.
  - `Test/OAuthServerJwks` -- refresh OK, no URL, fetch fails.
  - `Test/OAuthServerToken` -- stored, never read back, not in the ledger or context.
  - `Test/OAuthServerWire` -- arms `OCUPILOT_ALLOW_PRINCIPALS`: 403s naming the pair, and an agent mint and confirm with a marker for each tool.
- Roster updates, own rows only: `ToolWrite`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortFixture`, `PortGate`, `Prohibited`, `Descriptor`, `DerivedFields`, `OAuthTabs` :77, `ClassicLinkCorpus`/`ClassicLinkRegistry`, `ui/tools/classic-links.test.mjs` :446-460, and `scripts/ci-throwaway.sh` + `ui/tools/ci.test.mjs` for `OAuthServerWire`.
- `ui/browser/oauth-server-description-editor.browser-spec.mjs` (new). It uses `assertThrowaway` and starts and stops the fixture through `irisSession`.
  - Legs: create, edit, discover then save, Update JWKS, delete from the row menu; the other four tabs keep their classic links.
  - DW-1337 `detectScreen` on the editor at 1280 light, 720 light and 1280 dark, and on the delete dialog.

**Acceptance Criteria:**

- **AC1 (create).** Given the Server descriptions tab, when the user chooses Create, enters an issuer, an SSL configuration and both endpoints, and saves, then the editor reopens on the new description reading "Saved", the tab lists it, and the admin API's GET returns every entered value.
- **AC2 (edit, AD-4).** Given an existing description opened from its name cell, when the user changes one endpoint, clears another and saves, then GET shows exactly that change and that clearance, and every other field and `Metadata` member reads as before.
- **AC3 (delete).** Given a description, when the user deletes it from the editor or the tab's row menu and types its issuer, then it is gone from the tab and the instance. A description that a client configuration uses is refused by name, and nothing is deleted.
- **AC4 (Discover).** Given the local issuer, when the user runs Discover with its issuer, then its published endpoints and metadata fill the form for review and nothing is saved until Save. After Save, GET returns the discovered members.
- **AC5 (Update JWKS).** Given a saved description whose `jwks_uri` is reachable, when the user runs Update JWKS, then the key set refreshes and the page reports it. An unreachable URL reports the failure, and a description with no `jwks_uri` offers no Update JWKS.
- **AC6 (secret).** Given the registration access token field, when a token is entered and saved, then the field is masked and never pre-filled, the instance stores the token, and no read, form read, screen context, proposal, ledger row or log line carries it.
- **AC7 (agent).** Given the agent proposes each of the five tools, when the user confirms, then the write lands and carries OcuPilot's marker (AD-15). The update's payload is the complete set. A create whose issuer was taken after the mint is refused at confirm (AD-54).
- **AC8 (privilege).** Given a caller without `%Admin_OAuth2_Client:USE`, when they save, discover, run a row action or mint, then the request is refused 403 naming that pair before any port call.
- **AC9 (link-out).** Given the OAuth 2.0 screen, when it renders, then this tab's name cell opens OcuPilot's editor, the other four tabs keep their classic links, and the classic-links check reports one exemption across four descriptors.
- **AC10 (DW-1337).** Given the editor and its delete dialog, when they are measured at 1280 px light, 720 px light and 1280 px dark, then there is no structural or contrast violation.

## Spec Change Log

- 2026-09-24, spec gate (lead). Q1-Q3 written into the spine as recommended: AD-4 moves `Security.OAuth2.Client.ServerDefinition` out of the erasing list; AD-27's reason list gains "an acceptance criterion rules out" and "has no such operation", with the discovery and Update JWKS cases named under Story 12.4 (the spine says both are measured on a throwaway by the implement stage; record each measurement in `## Verification`). Q4 applied under Rule 5 to Epic 12's preamble and the epic context. Q5 stands: a measured write with no vendor audit event is reported for an AD-53 named-gap entry, which the lead writes. The editor is untabbed because the classic page is.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-24, AD-27, AD-29, AD-35, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56. The DW-1337 gate applies. No AC contradicts an AD. The two AD-27 cases are new named entries (Q2, Q3), not widenings.

- **Measured on `ocupilot-b-ci`, 2026-09-24.** A scratch definition was created, probed and deleted, together with its scratch client and resource server; the tab reads empty again.
  - A PUT carrying only `SSLConfiguration` kept `IssuerEndpoint`, `ServerCredentials` and every `Metadata` member.
  - `""`, `[]` and `null` each clear a member. An unknown member is ignored.
  - A PUT that clears `token_endpoint` answered 200 and left the row invalid. The next `TOKEN` then failed with 500 #8875.
  - A PUT on an absent row answers 404. A POST with a duplicate issuer answers 409 #5808.
  - A PUT can change the issuer.
  - `TOKEN` stores the value (length 15) and `""` clears it. GET never shows it.
  - A PUT without `discover` leaves `IsDiscovery` 0. That flag only labels the classic page "entered manually".
  - DELETE with a client attached is refused 500 #5823. With a resource server attached it answers 200 and leaves the resource server's reference dangling.
- **Why a port.** The id is the issuer, while the vendor keys on an integer. Mapping one to the other in the port keeps every caller on AD-13's id (the TokenPort precedent), and the same port owns the two vendor-class calls (the ProcessPort precedent).
- **Discover reviews before saving.** The admin API's only discovery path saves immediately. `%SYS.OAuth2.Registration.Discover` can save through `RefreshJWKS`. `GetServerMetadata` is the one call that fetches without writing.
  - After a discovery, Save sends the complete member set, so a member the issuer no longer publishes is cleared.
  - Discovery also fetches no JWKS, as on the classic page. The user runs Update JWKS after saving.
- **Test issuer.** `OAuthIssuerFixture` is a JOBbed TCP responder inside the instance, so the instance's own fetch reaches `http://localhost:<port>` in CI with no internet and no web application.
  - First implement measurement: `%Net.HttpRequest` from a request process reaches the JOB.
  - Fallback: a test-created unauthenticated web application with an `OcuPilot.Test` dispatch class, removed in teardown.
- **Form, in the classic order, untabbed.**
  1. Issuer endpoint*, SSL/TLS configuration* (text plus a datalist of readable names), and the registration access token (masked, with the hint to leave it empty to keep the stored one).
  2. **Authorization server**: authorization*, token*, userinfo, token introspection, token revocation and end session endpoints.
  3. **JSON Web Token (JWT) settings**: None / JWKS from URL (`jwks_uri`) / X.509 certificate (`ServerCredentials`, from readable aliases). Switching the choice clears the other value.
  4. **Metadata**: a read-only table of every other derived member, where an empty value reads "(none)".

  The action bar holds Save (primary), Discover, Update JWKS and Delete.
- **Known gap.** "JWKS from file" is not offered: the admin API cannot carry `SetPublicJWKS`, and the AC does not ask for it. Adding it would be a further AD-27 case.
- **Strings** (`oauthServer*`):
  - "Server description"; "Issuer endpoint"; "SSL/TLS configuration"; "Registration access token"; "Leave empty to keep the stored token.";
  - "Authorization server"; "Authorization endpoint"; "Token endpoint"; "Userinfo endpoint"; "Token introspection endpoint"; "Token revocation endpoint"; "End session endpoint";
  - "JSON Web Token (JWT) settings"; "None"; "JWKS from URL"; "X.509 certificate"; "Metadata";
  - "Discover"; "Update JWKS";
  - "Fetched the metadata published at {issuer}. Review it, then Save.";
  - "Updated the key set from {url}.";
  - "Saved. The registration access token was not stored: {reason}";
  - delete consequence: "Deletes this server description and its metadata. A resource server that uses it is left without one. A client configuration that uses it blocks the delete.";
  - empty agent invitation (`oauthServerDescriptionsEmptyAgent`): "Ask the agent to add a server description, or choose Create.";
  - reasons: "Client configurations still use this server description. Delete them first."; "This server description has no JWKS URL."; "The key set could not be fetched from {url}.";
  - the four discovery causes: "{issuer} could not be reached."; "{issuer} answered HTTP {status}."; "{issuer} did not answer JSON."; "The document names a different issuer: {claim}."

  Refusal sentences live once on the server (AD-39, AD-53).
- **Bundle.** The initial total is about 1.34 MB. If `maximumWarning` (1378 kB) is crossed, DW-1166's policy applies: set it 5% above the measured value, with the value line and a pinned literal. Crossing 1500 kB is a stop-and-ask.
- **Integration ACs.**
  - Introduced here: `OAuthServerPort`, the form descriptor, five tools and the discover route. This story's consumers are the editor page, the tab's row actions and agent dispatch (AC1–AC8).
  - Consumes: Story 6.4's tab, Story 7.3's delete pattern, AD-53's route and handler, AD-55's Save (Stories 8.8 and 8.5), and Story 12.3's port-subclass pattern.
  - Consumed-by: Story 12.5 (a client configuration names a server description; its dynamic registration uses the token set here) and Story 12.9 (which removes the remaining four exemptions and closes SM-C1).
- **Ledger inbox:** empty.

**Open questions for the lead.** Each carries the recommendation this spec is built on. Rule 20 writes Q1–Q3 into the spine, and Rule 5 applies Q4.

- **Q1, AD-4 correction.** Move `Security.OAuth2.Client.ServerDefinition` out of the list that erases omitted fields. Measured: `RunPut` sets each top-level field only when the body defines it, and `Metadata` member by member; only the internal `IsDiscovery` is reset by a PUT without `?discover=1`. Epic 12's preamble ("all four … presumed to erase") and `epic-12-context.md` change at their origin to match.
- **Q2, AD-27 named case (fifth): server-description discovery.** The admin API has no discovery read: `?discover=1` exists only on a saving PUT/POST and discards the body's metadata. So `OAuthServerPort` completes it through `OAuth2.ServerDefinition.GetServerMetadata` (`[Internal]`) in `%SYS`, after the endpoint's `%Admin_OAuth2_Client:USE` gate, saving nothing, and screen only. A test calling it against the local issuer pins the signature.
- **Q3, AD-27 named case (sixth): Update JWKS.** The admin API has no JWKS type, so the port completes it through `OAuth2.ServerDefinition.RefreshJWKS(1,1)` in `%SYS` after the same gate, as an AD-51 action write with a port-synthesized read type. AD-27's lead sentence lists four reasons ("refuses a value… has no read… cannot pass a parameter"); recommend adding "has no such operation", or recording this as its own case.
- **Q4, Rule 5 (apply and report).** Derive `Metadata.*` from `OAuth2.Server.Metadata`, whose generated `ImportJSON` is the endpoint's actual wire contract, rather than from `mainspec_v2.json`. That file is not vendored because it has no upstream license (`ui/tools/admin-spec.mjs`). This amends Epic 12's preamble and the epic context at origin.
- **Q5 (conditional, AD-53).** The implement stage measures whether the vendor records an audit event for a save, a token write and a JWKS refresh. `AuditUpdate` is called on save (inference); `%OnDelete` audits a delete. Any write without an event becomes a named gap in AD-53, as `REVOKE` is.

## Verification

This runs on slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Every test that creates, changes or deletes OAuth configuration runs on `ocupilot-b-ci` only (web 52777, super 1976). Run one test class per call, and wait until each run lands in `%UnitTest_Result`.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth-server-description-editor.browser-spec.mjs browser/oauth.browser-spec.mjs browser/oauth-delete.browser-spec.mjs` (loop) -- expected: every leg passes.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>` (loop), one call each for:
  - `OAuthServerCreate`, `OAuthServerUpdate`, `OAuthServerDelete`, `OAuthServerDiscover`, `OAuthServerJwks`, `OAuthServerToken`, `OAuthServerWire` (armed);
  - `OAuthTabs`, `OAuthDelete`, `ToolWrite`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `PortFixture`, `Prohibited`, `Descriptor`, `DerivedFields`, `ClassicLinkCorpus`.

  Expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, a non-zero smoke count, and the bundle total recorded.
- The full browser suite is not run locally. CI's `browser` job runs it (Rule 29).

**Pinning tests and mutations (Rule 19; the implementer records each as `mutation: … → …`):**

- AC1: the create route leg. Mutation: the create tool sends no `Metadata`.
- AC2: the update leg that clears a member. Mutation: the payload expansion is skipped, so the cleared member survives.
- AC3: the delete leg. Mutation: the `ClientCount` precondition is dropped, so the vendor 500 reaches the caller.
- AC4: the discover nothing-saved leg. Mutation: the port passes `discover=1`.
- AC5: the JWKS leg. Mutation: `REFRESHJWKS` calls `RefreshJWKS(0,…)`.
- AC6: the token-absence leg. Mutation: the form read echoes `InitialAccessToken`.
- AC7: the per-tool confirm leg. Mutation: drop the create's absence read.
- AC8: the 403 leg. Mutation: remove the port's gate on `Discover`.
- AC9: `classic-links.test.mjs`. Mutation: restore the tab's exemption.
- AC10: the browser structural assertion. Mutation: a 1400px `min-inline-size` on the metadata table.

**Measurements for the implement stage, recorded here:**

- The fixture is reachable from a request process.
- A boolean member cleared with `false`.
- How `Mint.Merge` renders a `Metadata` diff.
- Q5's vendor audit rows.
- The bundle total.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
