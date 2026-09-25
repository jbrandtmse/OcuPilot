---
title: 'Story 12.4: The OAuth 2.0 client server-description editor'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: '749740fe4f2888fb92a5f0e2c301377cfcf9b4dc'
baseline_commit: '749740fe4f2888fb92a5f0e2c301377cfcf9b4dc'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-8-the-device-editor.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-3-copy-and-purge-the-audit-database.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The vendor writes the registration access token in plain text into its own audit row, and OcuPilot's audit viewer and its read tool show that row's EventData, so the token AC6 keeps out of every OcuPilot read is readable through Logs > Audit and logs.audit.read.
    evidence: |-
      Measured on ocupilot-b-ci: a TOKEN write logs "Modify OAuth2 Server Definition" (%System/%Security) whose EventData carries "New value: <token>" and a property dump holding it; every later save of that definition dumps it again. Settle by an AD-35/AD-53 ruling: mask EventData for this event in the audit read, or name the gap.
    location: >-
      vendor OAuth2.ServerDefinition.AuditUpdate; src/OcuPilot/Screen/Descriptor/AuditList.cls read fields (EventData)
    severity: high
  - summary: >-
      The agent's update replaces Metadata whole: the tool's argument is the complete member set, because Mint.Merge carries an object argument as one value. The screen route merges member by member before it calls the tool.
    evidence: |-
      Pinned in OcuPilot.Test.OAuthServerUpdate TestTheAgentsEditSendsTheCompleteSet (one diff row, field Metadata). Epic 9's Write.MergeUpdate hook is not on this branch; settle at the merge by merging the agent's Metadata over the fresh read there.
    location: >-
      src/OcuPilot/Screen/Tool/OAuthServerDescriptionUpdate.cls ArgumentProblem, src/OcuPilot/Kernel/Proposal/Mint.cls Merge
    severity: medium
  - summary: >-
      An unreachable issuer holds the editor's Discover for the vendor's own connect timeout, about 30 seconds, before the named refusal.
    evidence: |-
      Measured: GetServerMetadata against a closed port or a .invalid host answered #6059 after ~30 s. The port passes no timeout; GetServerMetadata takes none.
    location: >-
      src/OcuPilot/Port/OAuthServerPort.cls Discover
    severity: low
footprint_extensions:
  - 'src/OcuPilot/Port/AdminPort.cls (contended: five MUTATINGTYPES entries -- the four the spec names and ServerDefinition/REFRESHJWKS, which the ToolWrite roster requires of every reached pair -- and one BODYLESSTYPES entry; single-line union at merge)'
  - 'src/OcuPilot/Kernel/Proposal/Mint.cls (contended: Compose carries an object argument whole, so an agent create can set Metadata; outside Epic 9 hunks)'
  - 'src/OcuPilot/Kernel/Proposal/Prohibited.cls (contended: COVEREDTYPES and the fail-closed type chain are single lines Epic 9 also extends, one-line unions at merge; the rest outside Epic 9 hunks)'
  - 'src/OcuPilot/Api/Router.cls (contended: four routes appended at the UrlMap tail, which Epic 9 also appends to -- append after its block at merge -- and four thin handlers)'
  - 'src/OcuPilot/Screen/Tool/Classification.cls (contended: three entries after the device entries); FieldLists.cls and ToolFields.cls regenerated'
  - 'src/OcuPilot/Api/Error.cls, ui/src/app/core/strings.ts, ui/src/styles/_components.scss, EXPERIENCE.md (shared-append, own entries)'
  - 'ui/src/app/shell/screen-outlet.ts, ui/src/app/shell/screen-action-handler.ts (contended: own entries, placed outside Epic 9 hunks)'
  - 'ui/src/app/core/screen-actions.ts (the Update JWKS label); ui/src/app/app.ts (OAuthActions and the form store injected, the store reset at sign-out)'
  - 'src/OcuPilot/Test/PortFixture.cls, ToolRoundTrip.cls, ReadTool.cls, SurfaceCoverage.cls, EndpointCoverage.cls, PortGate.cls, Prohibited.cls, OAuthDelete.cls, OAuthTabs.cls, DerivedFields.cls, Wire.cls, WireOAuthRead.cls, WireSecurityRead.cls (own roster rows; the three Wire classes and Prohibited.cls share single literal lines with Epic 9, unions at merge)'
  - 'ui/tools/classic-links.test.mjs, ui/tools/navigation.test.mjs, ui/browser/oauth.browser-spec.mjs (the tab left the exemption and gained row actions); scripts/ci-throwaway.sh (the seven new armed classes)'
  - 'src/OcuPilot/Test/RouterFixture.cls (one fixture route and handler for the edit route; merges cleanly with Epic 9)'
  - 'ui/src/app/app.spec.ts (the sign-out leg for the form store''s token; one hunk conflicts with Epic 9''s own sign-out legs, a union at merge)'
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

**Review patches (2026-09-24):** P1-P9 applied; each row is in `## Review Triage Log`.

### CI rework (run 36078446863 on c3d8979d, job browser)

- [x] [CI] `a11y-structural-invariants.browser-spec.mjs` AC5 "no violation outside the baseline" -- the new route `security/oauth/edit` shows the shell chrome's known overflows (panel resize handle 4px at 1280 and 720, DW-1583; status-bar connection 28px at 720, DW-1584), which every existing editor route carries as baseline entries -- https://github.com/jbrandtmse/OcuPilot/actions/runs/36078446863 -- append exactly those three entries to `ui/browser/structural-baseline.json` with their `dw` ids, in the file's existing shape (as Epic 7/8/9's editor routes did), and nothing for the editor's own content, which must stay violation-free; the lead appends the ledger occurrences.
- [x] [CI] `oauth-server-description-editor.browser-spec.mjs` AC2 "the tab's name cell opens the editor, and an endpoint changed and one cleared reach the instance exactly" -- `failed to find element matching selector "#ocu-oauth-server-InitialAccessToken"` in CI's full-suite run on a fresh throwaway (it passes alone locally) -- same run -- find the cause (state left by an earlier spec in alphabetical order, a fresh-instance difference, a timing wait, or the review patches since c3d8979d) and fix the product or the spec so it holds in the full suite; reproduce it the way CI runs it (a fresh throwaway, or the preceding spec files in order) before claiming the fix.

### Review Findings

Code review 2026-09-24 (four layers, all on Opus): 12 entries (high 1, med 7, low 4); 11 patched, 1 deferred, 27 rejected.

- [x] [Review][Patch] (high, AD-3) The body's field list was typed by hand twice, in the port's `TEMPLATEFIELDS` and in `Expand`'s keep list. `Expand` now keeps the derived template list (`OAuthServerRules.TemplateFields`), and the port strips only the `ROWFIELDS` its own GET adds (`VendorBody`). [src/OcuPilot/Area/Security/OAuthServerRules.cls, src/OcuPilot/Port/OAuthServerPort.cls]
- [x] [Review][Patch] (med, AD-55) A create's Save read through the port (the issuer look-up and the credential check) before it asked AD-10's set. That contradicted its own doc and the device and X.509 model. The order is now: the issuer's presence and shape, then the prohibited set, then the rules. The edit's documented order is corrected too. [src/OcuPilot/Area/Security/OAuthServerSave.cls:Create]
- [x] [Review][Patch] (med) A token-only edit Save sent a full no-op PUT before the TOKEN write. That PUT is one more vendor save, which writes the stored token into another audit row (DW-1640 occurrence) and resets `IsDiscovery`. `Update` now returns on an empty body. [src/OcuPilot/Area/Security/OAuthServerSave.cls:Update, Test/OAuthServerToken.cls]
- [x] [Review][Patch] (med, Rule 19) The form read's SSL/TLS and X.509 name lists had no test. Added `OAuthServerWire.TestTheFormReadOffersOnlyTheNamesTheCallerCanRead`. [src/OcuPilot/Test/OAuthServerWire.cls]
- [x] [Review][Patch] (med, Rule 19) Discover's route rules and the stray-key 400 had no test. Added `OAuthServerDiscover.TestTheRouteRefusesItsRulesAndAStrayKeyBeforeTheFetch`. [src/OcuPilot/Test/OAuthServerDiscover.cls]
- [x] [Review][Patch] (med, Rule 19) Two page behaviours had no test: the rename's `replaceUrl` navigation, and "Saved" plus a refused token kept across a create's route replacement. Added two page-spec legs. [ui/src/app/areas/security/oauth-server-description-form.page.spec.ts]
- [x] [Review][Patch] (med, Rule 19) The editor's privilege-denied sentence (AC8's user-facing half) had no test. Added a page-spec leg. [ui/src/app/areas/security/oauth-server-description-form.page.spec.ts]
- [x] [Review][Patch] (low) The metadata-table test's title claims flags, but its fixture rendered none. It now stores a flag and expects "Yes". [ui/src/app/areas/security/oauth-server-description-form.page.spec.ts]
- [x] [Review][Patch] (low) The issuer shape rule accepted a query or fragment, which RFC 8414 forbids and the discovery path would break on. The regex, the sentence and the tool description now say so, and the rule gained two cases. [src/OcuPilot/Area/Security/OAuthServerRules.cls:IssuerShaped, Api/Error.cls, Test/OAuthServerCreate.cls]
- [x] [Review][Patch] (low) `MergedMetadata`'s doc said `null` clears a member, but `MemberViolations` refuses `null` before that point. Doc corrected. [src/OcuPilot/Area/Security/OAuthServerSave.cls:MergedMetadata]
- [x] [Review][Patch] (low) `navigation.test.mjs`'s message listed four OAuth tabs and left out the editor. [ui/tools/navigation.test.mjs:187]
- [x] [Review][Defer] (med) AD-44 and `epic-12-context.md:52` still say five descriptors declare the exemption; four do now (AC9). [ARCHITECTURE-SPINE.md AD-44] — deferred: DW-1643, routed to 12-9, spine text for the lead (Rule 20).
- Stage verification: mutation M4 left a `https://…invalid#f` description behind, and `OAuthServerProbe.RemoveAll` did not match it. It now compares the probe host by URL component.

Rejected:

- Spec edits. The fix for each of these would edit the spec under review:
  - the AD-48/AD-53 name in Residual risks;
  - the Auto Run Result tally;
  - the intent's `false`/`secretArguments` wording (the triage log already closed it);
  - the spec's growth while `oversized`;
  - the empty-agent string (it follows EXPERIENCE `:315`);
  - the matrix's "banner" for the token refusal (the Design Notes sentence is the status line's);
  - `status` beside the escalated DW-1640, which is the lead's.
- `false`:
  - `Expand` silent when `Members` fails: every path that changes `Metadata` runs `MemberViolations` first and fails loudly.
  - A rename's old row lingering: `refresh.ts` re-reads on any event of the type.
  - The shape sentence reading as a fact: it follows the house style ("An alias has no control character and no slash.").
  - AD-19 component fields: they hold transient action state, as the reviewed Story 12.3 auditing page does.
- By design:
  - The SSL name is not checked for existence or `MAXLEN`: the spec's closed rule set.
  - Endpoint members are held to text: the member-shape rule.
  - Update JWKS clearing the credential without saying so on the card: the spec puts that in the tool description and fixes the success sentence.
  - Discover as a network probe: an AD-27 named case, screen only, behind the gate; the classic page offers the same.
  - No token-present indicator (AD-35).
  - The typed token forgotten after a refused Save: documented in the store.
- `low`:
  - `Mint.Compose`'s object carry: schema-held, and the vendor's validator refuses a wrong shape.
  - `DiscoveryCause` mapping 5002/5035: 5035 is the `%FromJSON` failure.
  - The update fingerprint and unchanged count include `ClientCount`/`ResourceCount`: excluding them would contradict the delete's subject. reopen_if a TARGETCHANGED is reported where only the counts moved.
  - The JWT choice showing an empty URL.
  - A no-cache JWKS (the vendor's own semantics).
  - A credential hidden behind the URL choice.
  - Update JWKS's notice over a failed re-read.
  - The probe's unchecked `%SQLCODE`.
  - The remaining page-spec gaps (`STATE_CONFLICT`, the 404 state, the discovery subset).
  - The `Prohibited` test's exact id skip.
  - AC8's mint leg: the five tools' pairs equal the tab's, and `DenialParity` pins the dispatch refusal.

### Review Findings (CI rework)

Code review 2026-09-24 of the rework `749740fe..34cd6812` (four layers, all on Opus): 1 entry (low), patched; 14 rejected. Checklist: the three `security/oauth/edit` entries equal the shell-chrome set every `*/edit` route carries (DW-1583 at 1280 and 720, DW-1584 at 720), and baseline matching is exact-key, so nothing admits the editor's own content. The AC2 wait holds until the form read renders, because the endpoint and token fields share one `@if (loadedFlag)`. No other wait in the story's browser specs has the `undefined !== ''` shape.

- [x] [Review][Patch] (low, Rule 19) The AC2 `mutation:` line did not name the latency injection, so it could not be re-run. The line now names it. Re-observed on `ocupilot-b-ci`: the mutant is red with CI's error, the fix passes 5/5 under latency, and the scratch copies are deleted. [spec `## Verification`]

Rejected:

- Spec edits. The fix for each of these would edit the spec under review:
  - `(inference)` on the CI root cause, and the reproduction scope (CI's `browser` job on `34cd6812` confirms it);
  - the root cause said three times;
  - the growth while `oversized`;
  - the unnamed deferred items;
  - the "Follow-up review" fragment.
- `false`:
  - The Boundaries line "no DW-1337 baseline allowance": the entries are shell chrome that the `[CI]` item directs, and nothing is on the editor's content.
  - The stale key counts in the DW-1583/DW-1584 headings: a ledger body is written once, and occurrences are trailer lines.
- Outside the rework, not high:
  - the matrix's member pair against the AC2 leg;
  - no full ObjectScript sweep after `bfdb266c` (CI's `instance` job on `34cd6812` is the sweep);
  - `barButton`'s disabled match;
  - the AC3 filter's `length === 1`;
  - AC5's non-empty `PublicJWKS`;
  - the `stored()` null dereference.
- `low`: the wait's bare timeout message when `token_endpoint` is absent. The fixture always publishes it.

## Spec Change Log

- 2026-09-24, spec gate (lead). Q1-Q3 written into the spine as recommended: AD-4 moves `Security.OAuth2.Client.ServerDefinition` out of the erasing list; AD-27's reason list gains "an acceptance criterion rules out" and "has no such operation", with the discovery and Update JWKS cases named under Story 12.4 (the spine says both are measured on a throwaway by the implement stage; record each measurement in `## Verification`). Q4 applied under Rule 5 to Epic 12's preamble and the epic context. Q5 stands: a measured write with no vendor audit event is reported for an AD-53 named-gap entry, which the lead writes. The editor is untabbed because the classic page is.
- 2026-09-24, CI rework 1. AC2's CI failure was the spec's own wait: `querySelector(…)?.value !== ''` is true while the field is absent, so on a slow runner it passed before the form read rendered the form; the wait now reads `?? ''` (reproduced with 1 s of injected request latency).

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 20 findings — high 1, medium 10, low 4, false 5, maybe-false 0
- findings:
  - `[low]` `[reject]` verification-gap 1: `Mint.Compose` now carries an object argument for every create — the agent path is held by `Registry.ValidateArguments` (JSON types against each tool's schema, `Screen/Tool/Registry.cls:561`); a screen route is reachable with an object only through a hand-built body, and a guard adds a parameter.
  - `[medium]` `[patch]` verification-gap 2: AC5's "no `jwks_uri`, no Update JWKS" and the page's refusal report were unpinned — P1, two page-spec legs, mutation lines added.
  - `[medium]` `[patch]` verification-gap 3: the editor's own Delete was never exercised — P2, a page-spec leg.
  - `[medium]` `[patch]` verification-gap 4: the sign-out reset of the form's typed token was unpinned — P3, `app.spec.ts`.
  - `[medium]` `[patch]` verification-gap 5: two AC6 legs in `OAuthServerToken` could not fail — P4, context leg asserts identity alone, log scan after the refused write.
  - `[medium]` `[patch]` verification-gap 6: the edit route's `issuer` and `tokenRefused` answers were never read over the route — P5, `TestTheEditRouteAnswersARenameAndARefusedToken` (rename over real HTTP; `tokenRefused` through the router with a failing fixture port, since no shipped path saves while its token write fails).
  - `[medium]` `[patch]` verification-gap 7: update-mode SSL and issuer-shape rules were untested — P6, screen and agent cases, nothing sent.
  - `[medium]` `[patch]` verification-gap other 1: a flag the issuer stops publishing was sent `false` and stored `false` — P7, an absent flag reads `''` on the client and the flag rule accepts `""`.
  - `[low]` `[patch]` verification-gap other 2: the AC9 leg's comment said four tabs and listed three — P8, `security/oauth/server` added.
  - `[medium]` `[defer]` intent-alignment 1: the agent's update replaces `Metadata` whole while the screen merges by member — already `deferred:` item 2; the fix needs Epic 9's `Write.MergeUpdate` hook in contended `Kernel/Proposal`.
  - `[false]` `[reject]` intent-alignment 2: delete refused "after the port's LIST" — the `ClientCount` it tests is itself a port read; the refusal precedes any vendor `DELETE` on both callers.
  - `[high]` `[defer]` intent-alignment 3: the vendor's `Modify OAuth2 Server Definition` audit row dumps `InitialAccessToken` in plain text, and Logs > Audit and `logs.audit.read` render `EventData` — re-verified on `ocupilot-b-ci` (row of 23:58:39 carries the probe token); already `deferred:` item 1. Root cause is Story 2.10's audit read and AD-35's scope ("covers only what OcuPilot writes"); needs a lead ruling (mask or named gap).
  - `[low]` `[reject]` intent-alignment 4: the form declares `secretFields` rather than `secretArguments`, and a dropped flag is sent `""` rather than `false` — both serve the intent (the registry refuses a secret argument no tool of the screen declares; `false` is stored, measured); the fix is an intent edit.
  - `[medium]` `[patch]` intent-alignment 5: update-mode rules not shown on both callers — grouped with verification-gap 7, P6.
  - `[medium]` `[patch]` intent-alignment 6: no test asserted AD-53's "screen writes emit no marker" — P9, zero-marker assertion beside the agent leg that shows markers appear.
  - `[false]` `[reject]` intent-alignment 7: the privilege test's principal holds `%Admin_Secure` — one with no `%Admin_` resource is refused 403 `AUTH.NOADMIN` by the pre-existing API gate, still before any port call.
  - `[false]` `[reject]` intent-alignment 8: Update JWKS does not say whether the key set changed — the matrix fixes the sentence "Updated the key set from {url}.", which is what ships.
  - `[low]` `[reject]` intent-alignment 9: the kernel `Mint.Compose` change — grouped with verification-gap 1.
  - `[false]` `[reject]` intent-alignment 10: Discover answers the vendor object's whole export — that object is `OAuth2.Server.Metadata`, the class the derived member list comes from.
  - `[false]` `[reject]` intent-alignment 11: Save chains the token write as a second mechanism — the spec's task names that chain, and it runs the SetToken tool's own operation (AD-53).
- stage verification, outside the count: a P6 mutation run left `ftp://ocupilotprobe124.invalid/renamed` behind, which `OAuthServerProbe.RemoveAll` (https prefix only) missed and which reddened `OAuthServerCreate`'s count; `RemoveAll` now matches the probe host under any scheme. The intent-alignment layer received a misaligned copy of the intent block (it read the spec for the rest).

### 2026-09-24 — Review pass (CI rework 1, follow-up)

- verdicts: 2 findings — high 0, medium 0, low 1, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` intent-alignment 1: under a strict reading of "a new screen has no DW-1337 baseline allowance", the three `security/oauth/edit` baseline entries are an allowance — they carry `dw` DW-1583/DW-1584 on shell-chrome elements (`app-panel-resize-handle`, `app-status-bar`), not DW-1337 and nothing the editor draws; every `*/edit` route carries the same three, and the editor's own `assertStructure` pass is unchanged.
  - `[low]` `[reject]` intent-alignment 2: the AC2 browser leg changes `token_endpoint` and clears `userinfo_endpoint`, not the matrix row's userinfo/revocation pair — predates this pass; the row's behavior (one changed, one cleared, the rest and an unshown list unchanged) is what the leg and `OAuthServerUpdate.TestAnEditSendsTheCompleteSetAndClearsAMember` assert, and re-pairing the members fixes nothing a user meets.

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

**Measured on `ocupilot-b-ci`, 2026-09-24 (implement):**

- AD-27 (a): `GetServerMetadata` is a class method, `[Internal]`, `issuerEndpoint:%String,sslConfiguration:%String,*metadata:OAuth2.Server.Metadata`, answering `%Status`. Against the fixture it answered the members and saved nothing (no definition or metadata row, `%Id` empty). Causes: #8880 `Unexpected status code=503`, `Unexpected content-type: text/html`, `Unexpected issuer claim: …`; unreachable #6059 after ~30 s. Consistent with the spine.
- AD-27 (b): `RefreshJWKS` is an instance method `force:%Boolean=0,save:%Boolean=1,*sc:%Status` answering `%Boolean`. `RefreshJWKS(1,1)` stored the fixture's key set and cleared `ServerCredentials` (`OcuPilotDemoCert` before); a second call with the same set answered 1 and saved nothing. Consistent with the spine.
- The fixture is reachable from a request process: `POST /api/ocupilot/oauth/server-description/discover` answered 200 with the members.
- A boolean member set to `false` is stored `false`, not cleared; `""` and `null` clear it. The expansion therefore sends `""` for an absent flag (the spec said `false`).
- `Mint.Merge` renders a `Metadata` change as one row, field `Metadata`, before and after the compact JSON of the whole member set (pinned in `OAuthServerUpdate.TestTheAgentsEditSendsTheCompleteSet`).
- Q5: a create logs "Create OAuth2 Server Metadata" and "Create OAuth2 Server Definition <issuer>"; a metadata-only PUT "Modify OAuth2 Server Metadata"; a token write "Modify OAuth2 Server Definition" whose EventData carries the token in plain text (see `deferred`); a JWKS refresh "Modify OAuth2 Server Definition" when the key set changed and nothing when it did not; a delete "Delete OAuth2 Server Definition" and "Delete OAuth2 Server Metadata". Every write has an event, except a refresh that changes nothing.
- A PUT carrying `ID` is refused 400 `PORT.FIELD.UNEXPECTED`; a bad X.509 alias through the vendor is a 500. The admin API's `POST ?discover=1` answered 500 `INTERNAL`.
- `OAuthServerWire`: a principal holding the install code read, `%DB_IRISSYS:READ` and `%Admin_OAuth2_Client:USE` alone discovered, created with a token, edited, refreshed and deleted (AD-29). A principal without the resource is refused `AUTH.NOADMIN` unless it holds some `%Admin_` resource; the test's holds `%Admin_Secure:USE`.
- The form descriptor keeps `secretArguments []`: the registry refuses a secret argument no tool of the screen declares; `context.secretFields` carries `InitialAccessToken`.
- Bundle initial total 1,369,863 bytes (main 1,233,050 + styles 136,813), below 1378 kB; no DW-1166 change.
- DW-1337: the editor and its delete dialog carry no entry of their own; the shell's DW-1583 and DW-1584 entries are the only allowance, re-keyed to the route.

**Runs:** full sweep on `ocupilot-b-ci`, runs 570-804: 235 classes, 2,046 tests, 1 failed (`Wire.TestTheSslConfigurationsListIsDeniedToAPrincipalWithoutAdminSecure`, a navigation literal without the editor's entry; fixed, `Wire` 20/20 in run 805). `%UnitTest_Result`, latest run per class: 2,046 methods, 2,046 passed, 0 failed. Own classes: `OAuthServerCreate` 7, `OAuthServerUpdate` 5, `OAuthServerDelete` 4, `OAuthServerDiscover` 4, `OAuthServerJwks` 4, `OAuthServerToken` 4, `OAuthServerWire` 5. Browser: `oauth-server-description-editor` 5/5, `oauth` 4/4, `oauth-delete` 2/2. `npm test` 1,375 tool tests and 1,093 component tests, 0 failed; smoke 49/49.

- mutation: `OAuthServerDescriptionCreate.DerivedFields` removes `Metadata` → `OAuthServerCreate.TestACreateThroughTheSaveSendsTheCompleteSet` red, 500 `INTERNAL` (AC1)
- mutation: `OAuthServerRules.Expand` returns before adding the empty members → `OAuthServerUpdate.TestAnEditSendsTheCompleteSetAndClearsAMember` and `TestTheAgentsEditSendsTheCompleteSet` red (AC2)
- mutation: `OAuthServerPort.Invoke` drops the `ClientCount` refusal → `OAuthServerDelete.TestADescriptionAClientUsesIsRefusedByName` red on the 409, the reason and the port leg (AC3)
- mutation: `OAuthServerPort.Discover` saves the discovered definition (the admin API's `discover=1` POST answers 500 here, so the save is made directly) → `OAuthServerDiscover.TestADiscoveryAnswersThePublishedMembersAndSavesNothing` red on both nothing-saved assertions (AC4)
- mutation: `RefreshJWKS(0, 1, .sc)` → `OAuthServerJwks.TestTheRowActionStoresTheKeySetAndClearsTheCredentials` and `TestAFetchThatFailsIsRefusedAndStoresNothing` red (AC5)
- mutation: `OAuthServerRules.HandleForm` adds the stored `InitialAccessToken` to `definition` → `OAuthServerToken.TestTheSaveStoresTheTokenAndNoReadCarriesIt` red on the form read (AC6)
- mutation: `OAuthServerDescriptionCreate.CREATES` 0 → `OAuthServerCreate.TestACreateTakenAfterTheMintIsRefusedAtConfirm` red at the mint, and `TestEveryFormRuleRefusesOnBothCallers` red on six cases (AC7)
- mutation: `OAuthServerPort.Discover` loses its resource check → `OAuthServerWire.TestThePortRefusesDiscoverAndRefreshWithoutTheResource` red (AC8)
- mutation: the tab's `classicLinkExemption` restored → `classic-links.test.mjs` "the shipped descriptor roster passes" red (AC9)
- mutation: `.ocu-oauth-server-metadata-table { min-inline-size: 1400px }`, rebuilt and redeployed → the editor browser spec's AC1 leg red, 920px overflow at 1280 and 720 (AC10)
- mutation: `offersUpdateJwks` drops `&& this.store.storedJwksUri() !== ''` → page spec "AC5: a saved description with no JWKS URL offers no Update JWKS" red (AC5, P1)
- mutation: `onUpdateJwks` no longer sets `actionRefusal` on a refused send → page spec "AC5: an Update JWKS the instance refuses shows the refusal's own sentence" red (AC5, P1)
- mutation: `confirmDelete` no longer navigates to the tab → page spec "AC3: Delete types the stored issuer, posts the one declared delete and returns to the tab" red (AC3, P2)
- mutation: `this.oauthServerDescriptionForm.reset()` removed from `App.verifyWhenSignedIn` → `app.spec.ts` "AD-8: leaving the signed-in state drops this principal's namespace list" red on the token (AD-35, P3)
- mutation: `OAuthServerDescriptionForm` declares `secretFields []` → `OAuthServerToken.TestNoContextOrLogLineCarriesTheToken` red, "as identity alone" (AC6, P4)
- mutation: `OAuthServerSave.StoreToken` logs the token when its write is refused → `OAuthServerToken.TestNoContextOrLogLineCarriesTheToken` red, "no OcuPilot line there carries either token" (AC6, P4)
- mutation: `OAuthServerSave.HandleUpdate` answers the route's issuer, not `$Get(tNewIssuer, tIssuer)` → `OAuthServerUpdate.TestTheEditRouteAnswersARenameAndARefusedToken` red on the wire rename (P5)
- mutation: `OAuthServerSave.Answer` drops `tokenRefused` → `OAuthServerUpdate.TestTheEditRouteAnswersARenameAndARefusedToken` red (P5)
- mutation: `OAuthServerRules.Validate` requires `SSLConfiguration` on a create alone → `OAuthServerUpdate.TestAnEditThatEmptiesTheSslOrRenamesToAMalformedIssuerIsRefused` red on the Save and the agent's mint (AD-39, P6)
- mutation: `OAuthServerRules.Validate` skips a rename's issuer rules → the same test red on `OAUTH.ISSUERENDPOINT.SHAPE`, and `TestAnEditRenamesTheIssuerAndKeepsItsClients` on the taken issuer (AD-39, P6)
- mutation: `memberOf` reads a flag as `value === true` → store spec "a flag the wire does not carry reads as absent" red (P7)
- mutation: `OAuthServerRules.MemberViolations` holds a flag to a boolean alone → `OAuthServerUpdate.TestAnEditSendsTheCompleteSetAndClearsAMember` red, the flag's `""` refused (P7)
- mutation: the Authorization server tab's generated classic `href` changed, rebuilt and redeployed → the editor browser spec's AC9 leg red on `security/oauth/server` (AC9, P8)
- mutation: `OAuthServerSave.HandleUpdate` emits the agent-write marker after its write → `OAuthServerWire.TestTheDeclaredPairsAloneDoEveryWrite` red on the zero-marker assertion (AD-53, P9)

**Matrix-row mutations (QA, Rule 19).** Six I/O & Edge-Case Matrix rows had a real pinning test but no
recorded mutation; each is demonstrated on `ocupilot-b-ci`, confirmed red, reverted, and confirmed
byte-identical (`git status --short` and `git diff --stat` both empty) before the next:

- mutation: `OAuthServerPort.Invoke`'s POST branch maps the vendor's `409` at `+pHttpStatus = 4090`
  instead → `OAuthServerCreate.TestADuplicateIssuerIsRefusedOnItsField` red on the port's 422 and its
  field (matrix: Create, duplicate)
- mutation: `OAuthServerPort.Invoke`'s DELETE branch also refuses when `ResourceCount` > 0 →
  `OAuthServerDelete.TestADescriptionAResourceServerUsesIsDeletedAndLeftDangling` red on all three
  assertions (matrix: Delete, resource server uses it)
- mutation: `OAuthServerPort.DiscoveryCause` matches `tCode = 88800`, never the vendor's real `8880` →
  `OAuthServerDiscover.TestEachCauseIsRefusedByName` red on the status, content and issuer cases
  (matrix: Discover fails)
- mutation: `OAuthServerPort.RefreshKeySet`'s empty-URL guard tests an unmatched literal instead of
  `""` → `OAuthServerJwks.TestADescriptionWithNoJwksUrlIsRefusedByName` red (matrix: Update JWKS, no
  URL)
- mutation: `OAuthServerSave.StoreToken` never reports a refused write (`If 0` for
  `If $$$ISERR(tWriteSC)`) → `OAuthServerToken.TestARefusedTokenIsAnsweredBesideTheSavedDescription`
  red (matrix: Token, a TOKEN failure answered beside "Saved")
- mutation: `OAuthServerPort.Invoke`'s PUT branch skips its `CredentialOk` check (`If 0` for
  `If '..CredentialOk(tBody)`) → `OAuthServerUpdate.TestAnUnusableCredentialIsRefusedOnItsField` red
  on the port's 422 (matrix: Bad X.509 alias)

**Code review mutations, 2026-09-24, on `ocupilot-b-ci`.** Each was applied alone, went red, and was reverted; `src/` is byte-identical to `/tmp/ocupilot-b-ci/src`.

- mutation: `OAuthServerSave.HandleDiscover`'s `SSLConfiguration` check `If 0` → `OAuthServerDiscover.TestTheRouteRefusesItsRulesAndAStrayKeyBeforeTheFetch` red on case 1 (run 871)
- mutation: `OAuthServerSave.Update`'s empty-body return `If 0 Quit` → `OAuthServerToken.TestATokenOnlyEditSendsNoDescriptionWrite` red (run 872)
- mutation: `OAuthServerRules.ReadableNames` answers `[]` for every caller → `OAuthServerWire.TestTheFormReadOffersOnlyTheNamesTheCallerCanRead` red on the test account's leg (run 874). With only its gate removed the test stays green (run 873), because the admin port's `ResourcesOR()` gate refuses the least principal too.
- mutation: `IssuerShaped` back to `([/?#]\S*)?` → `OAuthServerCreate.TestEveryFormRuleRefusesOnBothCallers` red on cases 5 and 6 (run 875)
- mutation: `onSave` navigates only `if (id !== '' && creating)` → page spec "an edit that renames the issuer replaces the route" red
- mutation: `open()` drops its `if (arriving)` block → page spec "a create whose token was refused says so" red
- mutation: the `reason` getter skips its `NO_PRIVILEGE_CODE` branch → page spec "AC8: a form read refused for the editor's pair" red
- mutation: `displayOf` answers `String(value)` for a flag → page spec "the metadata table reads every other member" red

Final runs after the review patches: `OAuthServerCreate` 7, `Token` 5, `Discover` 5, `Wire` 6 (runs 876-879); `Update` 7, `Jwks` 4, `Delete` 4 (runs 868-870); all 0 failed. `test:tools` 1,375 and `test:components` 1,101 tests, 0 failed. The editor browser spec passed 5/5 against the deployed bundle, which these patches leave unchanged.

**CI rework 1, on `ocupilot-b-ci`.** Each applied alone, red, reverted, byte-identical (`cmp`).

- mutation: drop the `security/oauth/edit|overflow|720|app-status-bar…` entry from `structural-baseline.json` → `a11y-structural-invariants` "AC5: no violation outside the baseline" red naming that key; restored, 203 found, 203 held, 0 stale
- mutation: the AC2 wait back to `?.value !== ''`, in a scratch copy of the spec that, right after AC2's `waitForRows`, opens a CDP session and sends `Network.emulateNetworkConditions` with `latency: 1000` → AC2 red with CI's `failed to find element matching selector "#ocu-oauth-server-InitialAccessToken"`; with `?? ''` the copy passes 5/5, and the real spec passes 7/7 after `oauth-delete` in CI's command form

## Auto Run Result

Status: done
Blocking condition: none

**Change (CI rework 1, run 36078446863).** Only the two `[CI]` items; no product code changed.

- `ui/browser/structural-baseline.json`: three shell-chrome entries for `security/oauth/edit` (panel resize handle at 1280 and 720, DW-1583; status-bar connection at 720, DW-1584), in the shape every `*/edit` route uses. Nothing for the editor's own content.
- `ui/browser/oauth-server-description-editor.browser-spec.mjs`: AC2's load wait reads `(…?.value ?? '') !== ''`. Root cause: `?.value !== ''` is true while the field is absent, so on CI's slower runner the wait passed before the form read had rendered the form (reproduced with 1 s of injected request latency; one line in `## Spec Change Log`).
- This spec: both `[CI]` items ticked, the change-log line, and two `mutation:` lines under `## Verification`.

**Review.** Two layers (verification-gap, intent-alignment), 2 findings: 0 patched, 0 deferred, 2 rejected (1 false: the baseline entries are shell findings, not a DW-1337 allowance; 1 low: the AC2 leg's member pair predates this pass and the row's behavior is asserted).

**Follow-up review: not recommended.** A follow-up pass that patched no `high`.

**Verification** (on `ocupilot-b-ci`, deployed bundle current: no `ui/src` change):

- `oauth-server-description-editor.browser-spec.mjs` 5/5; after `oauth-delete` in CI's `node --test --test-concurrency=1` form, 7/7.
- `a11y-structural-invariants.browser-spec.mjs` 10/10 (203 found, 203 held, 0 stale).
- `node --test tools/structural-baseline.test.mjs` 9/9; `npm run test:tools` 1,375/1,375; `bash scripts/lint-docs.sh` 0 issues.
- `src/` byte-identical to `/tmp/ocupilot-b-ci/src` (no `.cls` touched).

**Residual risks.** The full browser suite was not run locally (Rule 29); CI's next `browser` job is the confirmation. The earlier deferred items stand unchanged.
