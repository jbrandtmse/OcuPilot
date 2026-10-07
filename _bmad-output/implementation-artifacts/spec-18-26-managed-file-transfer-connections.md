---
title: 'Story 18.26: Managed file transfer connections'
type: 'feature'
created: '2026-10-07'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Managed file transfer (MFT) connections are still classic-only (`%CSP.UI.Portal.MFT.ConnectionList` and `.Connection`, both `%Admin_Secure`). The admin API carries them through `Security.MFT`: `GET /security/mft/connections`, `GET`/`PUT`/`DELETE /security/mft/connection?connection=`, and `DELETE /security/mft/connection/token`. A connection names an OAuth 2.0 client configuration by `ApplicationName`, and the vendor's delete also deletes that client.

**Approach:** A Security list at position 13 and an unlisted editor form. Four tools on a small `MftPort`: create, update, delete and revoke token. The connection names an OAuth 2.0 client configuration and never creates one (Decision 1). The delete keeps the vendor's removal of the client, and says so (Decision 2). Authorizing a connection stays a classic-portal action (Decision 4).

## Boundaries & Constraints

**Always:**

- **Screens.**
  - The list and `security.mftconnections.read` use one declared read (`Security.MFT` `LIST`: `Name`, `Service`, `IsAuthorized`) (AD-36).
  - The editor reads through its own form route.
- **Tools and keys** (AD-22): `security.mftconnections.create` (AD-54, `true`), `.update` (merge, AD-4, `true`), `.delete` (`false`) and `.revoketoken` (AD-51, destructive, `false`). Each tool has two callers (AD-53, AD-55).
- **Fields.**
  - The five template fields, all `ordinary`: `Service`, `URL`, `SSLConfiguration`, `Username`, `ApplicationName`.
  - `Service` is create-only.
  - The connection name is the id.
- **Rules before any `PUT`.** Every matrix Rules row is refused before any `PUT`, on both callers, as a field violation carrying OcuPilot's own sentence. An update checks only the fields it changes, so an unchanged stored value is never refused.
- **Saves.** Each Save takes `Operation.HoldTool(<tool>, <name>)` before its fresh read (DW-1882, AD-34). Each Save reads back (AD-58) and emits a change event naming its tool (AD-14).
- **Error codes** go in `Api/MftConnectionError.cls` (prefix `MFT.`). `Api/Error.cls` gains only its two dispatch lines.
- **Probes and tests.**
  - Write only on `ocupilot-ci`.
  - Connection, client and description names start `OcuMftProbe`, and issuers use `ocumftprobe.invalid`. No other suite uses either prefix.
  - Each probe is removed by exact name.
  - One test class per call. Shared rosters take add-only edits (Epic 20 runs in parallel).

**Never:**

- No OAuth 2.0 client configuration is created by this story's tools. There is no AD-27 named case.
- No call reaches a real Box, Dropbox or Kiteworks service. Every revoke that holds a token runs through `Test/MftSeamPort`.
- No change to `Prohibited.cls` beyond the add-only type lines; AD-10 names no MFT effect.
- `$SYSTEM.Monitor.State()` is never in a before/after snapshot. No bare `git stash`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | The list, or agent `security.mftconnections.read` | The same rows from one read, with `IsAuthorized` "Authorized" or "Not Authorized" | Missing pair: 403 naming it |
| Create | `OcuMftProbeA`, `Box`, all five fields; the named client may be absent | 201, stored (measured). Read-back `matches`. The id is kept exactly | Taken name: refused by the absence fingerprint |
| Update | Probe `Username` changed | The fresh read's five fields are sent with the change. `Service` is unchanged | A moved target is refused. A held lock answers 409 `WRITE.TARGETBUSY` after 10 s |
| Delete, client present | The only connection naming a client | The connection and the client are gone. So is the client's server description when that was its last client (measured). The consequence states this | Absent: 404 `PORT.NOTFOUND` |
| Delete, client absent | The only connection naming a missing client | The vendor answers 500 #5809 and has deleted the connection (measured). `MftPort` re-reads, finds it absent, and answers the delete | Present after the 500: the fault as it is |
| Revoke, no token | `IsAuthorized` "Not Authorized" | 409 `MFT.TOKEN.NONE` from the fresh read. No `REVOKE` is sent | The confirm closes the proposal target-changed (`PRECONDITIONCODES`) |
| Revoke, token | The seam answers "Authorized" | `REVOKE` is sent through the real admin API (a no-op there, measured) | Vendor fault: the fault as it is |
| Rules | Create without a field; `Name` empty, over 64 characters or holding a control character; `Service` not `Box`, `Dropbox` or `Kiteworks`; `URL` not an absolute `http(s)://` URL ending in `/`, or over 1024 characters; `SSLConfiguration` absent or not a client (`Type` 0) configuration; `Username` empty or over 160 characters; `ApplicationName` empty or over 64 characters; a non-string value | 422 `MFT.*` on the field. Nothing is sent | The mint refuses identically |

</intent-contract>

## Code Map

Analogs: **Story 18.25's Superservers** (`git diff --stat 0a8f21b4 a2d73616` lists every file and shared roster it touched; copy its shape minus the AD-10 arm and the id rule), **Story 12.2's** token revoke (`Port/TokenPort.cls`: a port-composed read type on one endpoint, `Snippet` mirror) and **Story 18.18's** `PRECONDITIONCODES` (`Screen/Tool/JournalSwitchDirectory.cls:27-48`).

**Server:**

- New, after the 18.25 pattern:
  - `Screen/Descriptor/SuperserverList.cls` and `SuperserverForm.cls` become `MftConnectionList.cls` and `MftConnectionForm.cls`.
  - `Screen/Tool/SuperserverCreate.cls`, `Update.cls` and `Delete.cls` become `MftConnectionCreate.cls`, `Update.cls` and `Delete.cls`. Single-id create: `EcpDataServerCreate.cls`.
  - `Area/Security/SuperserverRules.cls` (`HandleForm`, `Problem`, `Gate`, `RenderRead`; SSL check `SslRules`) and `SuperserverSave.cls` become `MftConnectionRules.cls` and `MftConnectionSave.cls`.
  - `Api/SuperserverError.cls` becomes `Api/MftConnectionError.cls`.
- `Port/TokenPort.cls`: the model for `Port/MftPort.cls` (new).
- `Port/AdminPort.cls`:
  - `MUTATINGTYPES` :455: add `Security.MFT/PUT`, `/DELETE` and `/REVOKE`.
  - `BODYLESSTYPES` :471: add `Security.MFT/DELETE` and `/REVOKE`.
  - `Fail` :3134 logs every 500 before a subclass sees it (Decision 3).
- Already present:
  - `Screen/Tool/FieldLists.cls:352` (5 fields).
  - `Port/AdminRoutes.cls:163-165`.
  - `Test/AdminInventory.cls:88`.
- `Screen/Tool/Classification.cls:585` (the superserver entries' model). Then regenerate `ToolFields.cls` with `bash scripts/field-lists.sh`.
- `Api/Error.cls:1230`, `:1434`: dispatch beside `SUPERSERVER.`. `Api/Router.cls:248-250`: the three new routes beside them, sub-resource first.
- Kernel:
  - `Kernel/EntityType.cls` `TYPES` :91 (59 types; add `mft-connection`).
  - `Kernel/EntityRef.cls` `IDRULES` :59: no entry, because a type with no rule keeps its id.
  - `Kernel/Governance/Baseline.cls`: after :149.
  - `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250, the fail-closed list :1253, the field lists :1053 and :1170, the dispatch beside :1495 through `ReviewedFewOnly` :3858 (the ECP precedent at :1463).
- Vendor (read-only):
  - `irissys/%SYS/MFT/Connection/Base.cls`: `DeleteId` (deletes the client and the description), `RevokeToken`, the `List` query.
  - Each service's `RevokeToken` calls the service.
  - The endpoint `%Api.Admin.Endpoints.Security.MFT` is Hidden; read it with `GetTextAsString`.

**Client:**

- `areas/security/superserver-form.page.ts` and `.store.ts` become `mft-connection-form.page.ts` and `.store.ts`. `superserver-actions.ts` becomes `mft-connection-actions.ts`.
- `shell/screen-outlet.ts:236`.
- `shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :110.
  - `DESTRUCTIVE_ACTIONS` :395: add `revoke-token`.
  - Consequences beside :447.
- `app.ts:56,372,712`; `core/proposal-view.ts:351,453`; `core/strings.ts`.

**Pins a Security screen extends** (as 18.25 did):

- `ui/tools/navigation.test.mjs:270-290` and `:607-608`.
- `ui/tools/side-bar-pins.test.mjs:52`.
- `ui/src/app/shell/area-verdict.spec.ts:228,294`.
- `Test/Wire.cls`, `WireSecurityRead.cls`, `WireOAuthRead.cls` and `WireAreaAnyScreen.cls`.
- `scripts/ci-throwaway.sh`'s `OCUPILOT_ALLOW_PRINCIPALS` roster :233-265, with `ui/tools/ci.test.mjs`.
- EXPERIENCE.md (1039 lines): the side-bar Security row :168, the Fixed strings Security row :364.
- The Fixed strings use 2823 of 2900 (measured at plan).
- `angular.json` `maximumWarning` is 3073kB against a measured 3,072,046 bytes, so re-base it (DW-1166). Stop above 3800kB.

**Test helpers to reuse:**

- `Test/OAuthClientProbe.cls` (`AddServer`, `AddClient`, taking a caller's names).
- 18.25's `SuperserverSaveFixture`, `SuperserverActionFixture`, `SuperserverGateProbe` and `SuperserverSeamPort`, as models.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci`). Record each result in Design Notes › Measured at Task 0. Halt on any contradiction with Measured at plan, and restore S0.

1. Record S0 (Verification › S0).
2. Through `AdminPort.Invoke` in process, delete a probe connection that is the only one naming an absent client. Record:
   - its `pHttpStatus`;
   - that `GET` then answers 404;
   - the severity-2 line it logs.
   Then clear the monitor.
3. Halt if anything outside S0 remains.

**Execution (server):**

- `Kernel/EntityType.cls`: add `mft-connection`.
- `Port/MftPort.cls` (new; extends `AdminPort`; every vendor call goes through an overridable `Call`):
  - **`STATE`.** On `Security.MFT`, the type `STATE` answers `GET`'s five fields plus `IsAuthorized` from the `LIST` row whose `Name` equals the id exactly. An absent row answers 404. "Not Authorized" answers 409 `MFT.TOKEN.NONE`.
  - **`DELETE`.** A `DELETE` answered with an error is re-read by `GET`. A 404 answers 200 `{}`; anything else keeps the fault.
  - **`Snippet`** mirrors both branches (AD-59).
  - Add the three `AdminPort` type entries.
- `Screen/Tool/MftConnectionCreate.cls`, `MftConnectionUpdate.cls`, `MftConnectionDelete.cls` and `MftConnectionRevoke.cls` (new). Common: `DESCRIPTORCLASS` `MftConnectionList`, `PORTCLASS` `MftPort`.
  - **Create:** `CREATES`. It takes `Name` (the id) and all five fields. `CLASSICPAGES` `%CSP.UI.Portal.MFT.Connection`.
  - **Update:** a merge over `GET`. Its permitted fields are the five less `Service`. `CLASSICPAGES` `%CSP.UI.Portal.MFT.Connection`.
  - **Delete:**
    - `DESTRUCTIVE`; `FINGERPRINTSUBJECT` `ApplicationName`.
    - `CONSEQUENCECODE` `MFT.DELETE`.
  - **Revoke:**
    - `READTYPE` `STATE`; `WRITETYPE` `REVOKE`; no body; `DESTRUCTIVE`.
    - `FINGERPRINTSUBJECT` `ApplicationName,IsAuthorized`.
    - `PRECONDITIONCODES` `MFT.TOKEN.NONE`.
    - `CONSEQUENCECODE` `MFT.REVOKE`.
    - `SCREENACTIONS` `revoke-token`.
  - Create and update call `MftConnectionRules.Problem` from `ArgumentProblem`.
- `Screen/Descriptor/MftConnectionList.cls` (new):
  - Route `security/mft-connections`; listed at 13; `list`; scope `instance`; a single id.
  - Security's two pairs.
  - Primary action create; row actions `delete` and `revoke-token`.
  - The table: `Name` (name), `Service` and `IsAuthorized` (text).
  - Classic page `%CSP.UI.Portal.MFT.ConnectionList`; three prompts.
  - `toolIdentifier` `security.mftconnections`.
- `Screen/Descriptor/MftConnectionForm.cls` (new):
  - Route `security/mft-connections/edit`; position 0; `form-page`.
  - Classic page `%CSP.UI.Portal.MFT.Connection`; three prompts.
  - `toolIdentifier` `security.mftconnectionform`.
- `Screen/Tool/Classification.cls`: the five fields `ordinary`. `Service`'s description names its three values. `ApplicationName`'s names the OAuth 2.0 screen's Client configurations tab and `security.oauthclients.create`. Then regenerate `ToolFields.cls`.
- `Area/Security/MftConnectionRules.cls` (new):
  - `Problem` and `Validate`: the matrix Rules row. `SSLConfiguration` is read through `AdminPort` `Security.SSLConfig` `GET` only when sent and changed.
  - `HandleForm` (`GET /mft-connection/form?id=`) answers `{row}` with `Name` and the five fields.
  - `Gate`, `RenderRead`.
- `Area/Security/MftConnectionSave.cls` (new): `HandleCreate` and `HandleUpdate`. The order is `HoldTool`, then the rules, then the prohibited set through the operation, then the `PUT`, then the read-back.
- `Kernel/Proposal/Prohibited.cls`, add-only:
  - `TYPEMFTCONNECTION`; the type joins `COVEREDTYPES` and the fail-closed list.
  - Its change fields are the four updatable fields, and its create fields are the five.
  - A `ReviewedFewOnly` dispatch.
  - `Codes()` is unchanged.
- `Api/MftConnectionError.cls` (new): the codes in Design Notes. Add the two `Api/Error.cls` lines. `Api/Router.cls`: `GET /mft-connection/form`, `PUT /mft-connection/:id` and `POST /mft-connection`, with thin calls.
- `Kernel/Governance/Baseline.cls`: the four keys.

**Execution (client):**

- `areas/security/mft-connection-form.page.ts` and `.store.ts` (new):
  - The fields are `Name` and `Service` (editable on create only), `URL`, `SSLConfiguration`, `Username` ("Email address") and `ApplicationName`.
  - The SSL/TLS picker issues the SSL/TLS list's declared read and offers its `Client` rows (AD-5).
  - Hints: `URL` ("ends in /"); `ApplicationName`, naming the OAuth 2.0 Client configurations tab; a form hint that authorizing a connection is done on the classic Managed File Transfer Connections page (text, no link, AD-44).
  - A sticky Save and an unsaved-changes guard.
- `areas/security/mft-connection-actions.ts` (Create).
- Wiring: `screen-outlet.ts`; `screen-action-handler.ts` (both row actions; the typed name is the connection's name; consequences); `app.ts` (sign-out reset); `proposal-view.ts` (`MFT.DELETE`, `MFT.REVOKE`); `strings.ts`.
- EXPERIENCE.md, edited in place:
  - The side-bar entry.
  - One Fixed strings addition: labels, hints, the two consequences, six prompts, the side-bar label and the empty state. Each sentence is published once.
  - Fix every shifted `EXPERIENCE.md:n` comment.
- Regenerate `screens.generated.ts`. Re-base the bundle budget if it is crossed.

**Tests:**

- `Test/MftConnectionDescriptor.cls`:
  - both descriptors;
  - the type (`Count()` 60), and the id kept exactly (`OcuMftProbeA` and `ocumftprobea` stay distinct);
  - the classification;
  - the baseline (`true`, `true`, `false`, `false`);
  - no update permits `Service`;
  - the tools' kinds, ports, pairs and `CLASSICPAGES`.
- `Test/MftConnectionRead.cls`:
  - the screen and the tool answer one set of rows;
  - the form read answers the five fields;
  - an absent name answers 404.
- `Test/MftConnectionWrite.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS`; `OnAfterOneTest` removes every `OcuMftProbe` connection, client and description, and clears the monitor):
  - create, update and delete through both callers;
  - the Rules rows each refused with the probe unchanged and the code `MFT.*`, never `INTERNAL`;
  - the absence fingerprint, a moved target and a busy lock;
  - a delete that removes its client and description;
  - a delete over an absent client answered as deleted, with the read-back reading absent;
  - a revoke refused `MFT.TOKEN.NONE` with no `REVOKE` recorded;
  - a seam revoke that sends `REVOKE` (through `Test/MftSeamPort.cls` and `Test/SeamMftConnectionRevoke.cls`);
  - the routes over the wire.
- `Test/MftConnectionGate.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS`): a principal holding exactly Security's pairs performs every operation, including a delete that removes a client. Without `%Admin_Secure:USE`, each is refused by name before any port call.
- Rosters:
  - `Descriptor`, `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `DraftRegistry` and `ToolDispatch`;
  - `Governance`, `GovernanceBaseline`, `Prohibited` (`CoveredTypes`), `ClassicPageGate`, `PortFixture` and `PortGate` (`MftPort`);
  - the Security pins above.
- `mft-connection-form.page.spec.ts` and `.store.spec.ts`.
- `ui/tools`: `navigation`, `side-bar-pins`, `proposal-view`, `screen-mirror`, `field-lists`, `strings`, `angular-json`, `ci`.
- `ui/browser/mft-connections.browser-spec.mjs` (new):
  - the list reached from the side bar;
  - create `OcuMftProbeB` on the form, change its `Username`, and delete it with the typed name;
  - Revoke on it shows the refusal;
  - an after hook deletes `OcuMftProbe*` through the admin API.

**Acceptance Criteria:**

- **C0.** Given Task 0 on `ocupilot-ci`, when steps 1-3 run, then each result is recorded, and the throwaway reads as S0.
- **C1.** Given the Managed file transfer list and `security.mftconnections.read`, when each reads, then both answer the same rows from one read, and the editor answers the five fields.
- **C2.** Given a probe connection, when it is created, changed and deleted from the screen and from a confirmed proposal, then:
  - the instance holds each result;
  - the read-back reads `matches` (absent after a delete);
  - `Service` never changes on an update;
  - a taken name, a moved target and a held lock are refused as the matrix says.
- **C3.** Given a connection that is the only one naming a client configuration, when it is deleted by either caller, then:
  - the delete's consequence states the client and description removal;
  - the client is gone;
  - its description is gone when that was its last client;
  - with the client absent, the delete is answered as done, not as a fault.
- **C4.** Given a connection, when its token is revoked by either caller, then:
  - one that holds no token is refused `MFT.TOKEN.NONE` before any `REVOKE`;
  - one that holds a token sends `REVOKE` through the admin API.
- **C5.** Given each Rules row, when either caller sends it, then it is refused on its field before any `PUT`.
- **C6.** Given the rosters, when the suites run, then:
  - Security lists Managed file transfer at 13;
  - each screen carries three prompts;
  - the keys read `true`, `true`, `false`, `false`;
  - `mft-connection` is pinned on both sides;
  - the consequences are published once;
  - the Fixed strings stay within the bound.
- **Integration.** The page consumes `GET /mft-connection/form`, `PUT /mft-connection/:id`, `POST /mft-connection` and both row actions. The agent consumes the read tool and the four write tools. Each runs on `ocupilot-ci` (C1-C5 and the browser spec).

## Spec Change Log

- 2026-10-07, spec gate (lead): Decisions 1-6 confirmed (create names an existing OAuth 2.0 client and never makes one; the delete keeps the vendor's client removal as its stated consequence, key `false`; authorization stays on the classic portal; revoke destructive, key `false`). Spine amendments 1-7 written (AD-8, AD-13, AD-4, AD-15 and AD-53 eighteenth, AD-44, AD-51, AD-52). DW-2007 gains `Security.MFT` `DELETE` #5809. Vendor candidates DW-2154, DW-2155, DW-2156 under the owner's hold. Fixed strings stay under 2900; a bundle re-base under DW-1166 is expected.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `AdminPort` only, through `MftPort`; no named case.
- AD-3: the derived five fields, all `ordinary`.
- AD-4: merge. AD-54: create absence. AD-51: revoke and its `STATE` read.
- AD-5, AD-36, AD-44: two descriptors, one read, the classic pages.
- AD-6, AD-34, AD-40, AD-53, AD-55: two callers; `HoldTool`.
- AD-8, AD-29: Security's set (measured).
- AD-10: no MFT effect, so the type is listed only to avoid failing closed. AD-13: the id kept exactly. AD-14: change event.
- AD-15, AD-53: unaudited writes (measured).
- AD-22: keys. AD-35 and AD-56: no field is secret, and none matches the pattern. AD-39: own sentences. AD-58: read-back. AD-59: `Snippet`.

**Measured at plan** (`ocupilot-ci`, 2026-10-07, through the admin API as `_SYSTEM` unless noted; S0 re-read after):

- **Create and update.**
  - A `PUT` on an absent name answered 201 and stored all five fields. It needs all five (400 #40301 without `URL`).
  - The `ApplicationName` it stored named no client.
  - A partial `PUT` kept every key it did not send.
  - A `PUT` changing `Service` to `Dropbox` stored that name on the Box object.
  - The vendor checks only `MAXLEN`: `Name`, `ApplicationName` and `SSLConfiguration` are 64 (500 #7201).
  - Empty values, `"not a url"`, an absent SSL configuration, `"a b c"` and the number `5` were all stored.
  - `Service` `box` or `Foo` answered 500 #5002 `<CLASS DOES NOT EXIST>`. `Base` was stored.
  - An unknown key answered 400 #40307. (Read in source: `URL` 1024 and `Username` 160.)
- **Identity.** `GET ?connection=ocuprobe1826a` answered 404 for `OcuProbe1826A`. `LIST` answers `Name`, `Service` and `IsAuthorized` ("Not Authorized"); `GET` answers the five fields.
- **Delete.**
  - **Client present.** With its client present and no other connection naming it, the delete answered 200. It deleted the client, and deleted the client's server description when that was its last client.
  - **Client shared.** With a second connection naming the client, the client was kept.
  - **Client absent.** With its client absent and no other connection naming it, the delete answered 500 #5809 (`OAuth2.Client` not found), and the connection was gone.
  - **Not found.** An absent name answered 404.
- **Revoke.** With no token it answered 200 `{}` and changed nothing. An absent name answered 404.
- **Authorization.** `auth-code-url` answered a `/csp/sys/oauth2/OAuth2.Response.cls?auth=1&state=…` URL when the client existed and 500 #5809 when it did not.
- **Audit.** No vendor event records an MFT create, modify, delete or revoke with auditing on. The client removal records `%System/%Security/OAuth2` "Delete OAuth2 Client" and "Delete OAuth2 Server Definition".
- **Pairs.** A principal holding exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`:
  - listed, created, read, updated and revoked;
  - deleted a connection, which removed a client and description it could not list (`server-definitions` answered 403 to it);
  - was then deleted.
- **End state.** No MFT connection, OAuth 2.0 client, description, token, `OcuProbe1826*` principal or role. Five client SSL configurations. Monitor 0.

**Decisions** (the lead confirms them at the spec gate):

1. **The create names an OAuth 2.0 client configuration and never creates one.**
   - **Why.**
     - Least surface: no secret client id or secret, no redirect fields, no description creation, and no AD-27 case.
     - The vendor's `CreateClient` first deletes any client of the same name (read in source), which no OcuPilot write should do silently.
     - The admin API names `ApplicationName` only and stores it with no client (measured).
     - Clients come from Story 12.5's Client configurations tab, whose `security.oauthclients.create` the agent already has.
   - **No existence check:** it would need `%Admin_OAuth2_Client:USE`, which the classic page does not.
2. **The delete keeps the vendor's removal of the client**, as the classic Delete does. Its consequence states it.
   - **No extra pair:** parity with the classic page's `%Admin_Secure`. The measured principal removed a client it could not list.
   - **Alternative:** declare `%Admin_OAuth2_Client:USE` on the delete, which narrows the audience below the classic page's.
3. **A delete answered with an error is judged by a re-read**, because the vendor deletes before it fails (measured).
   - **Interim:** the 500 is still logged at severity 2, as 18.25's taken port is, until DW-2007's code-scoped list (Story 18.28) gains `Security.MFT` `DELETE` #5809.
   - **Not chosen:** a pre-check would need the OAuth pair.
4. **Authorization is a classic-portal action.**
   - **Why.**
     - It is a person's sign-in at the file service's own site: the browser leaves OcuPilot and returns through `/csp/sys/oauth2/OAuth2.Response.cls`.
     - No agent can do it.
     - Its `GET` writes OAuth state (inference: `GetAuthorizationCodeEndpoint` creates an `OAuth2.AccessToken`).
     - The acceptance criterion names list, create, edit, delete and revoke only.
   - **Where it is named:** the list shows `IsAuthorized`, and the form's hint names the classic page.
5. **Revoke is destructive, its key `false`, and refused without a token.**
   - **Precedent:** Story 12.2's revoke is destructive.
   - **Why refuse:** the classic page answers "No access token to revoke", and the vendor's 200 changes nothing.
   - **Seam:** a real revoke calls the service (read in source), so the token path runs through the seam.
6. **`Service` is create-only.** The classic editor disables it, and a change mislabels the stored object (measured).

**Codes** (`Api/MftConnectionError.cls`; sentences on the server only, as 18.25's are):

- `MFT.VALIDATION` (the envelope).
- One code per field: `MFT.NAME`, `MFT.SERVICE`, `MFT.URL`, `MFT.SSLCONFIG`, `MFT.USERNAME`, `MFT.APPLICATIONNAME`.
- `MFT.TOKEN.NONE`: "This connection holds no access token to revoke."

**Published sentences:**

| Key | Sentence |
| --- | --- |
| delete consequence (`MFT.DELETE`) | "The connection is removed. Its OAuth 2.0 client configuration is deleted with it unless another connection names it, and so is that client's server description when no other client uses it." |
| revoke consequence (`MFT.REVOKE`) | "The connection's access token is removed and the file service is asked to revoke it. The connection cannot transfer files until it is authorized again on the classic Managed File Transfer Connections page." |

**Named limits:**

1. **Read tool.** It answers the three list fields.
2. **The client-absent delete.** It logs one severity-2 line (Decision 3).
3. **A failed revoke.** When the call to the file service fails, the revoke answers the vendor's fault even where the local token went (inference from source; unmeasured, as no instance here holds a token).
4. **The OAuth 2.0 tab.** It is not re-fetched by an MFT delete's change event.

**Spine amendments** (Rule 20; the lead writes them at the spec gate):

1. **AD-8:** "**Story 18.26's MFT connections declare Security's set**, and its tools declare no pair beyond it (measured on `ocupilot-ci`, 2026-10-07; the delete also removed an OAuth 2.0 client and description the principal could not list)."
2. **AD-13:** "**An `mft-connection` id is the connection's name, kept exactly** (Story 18.26; measured: a lower-cased name did not reach the stored one)."
3. **AD-4:** "**`Security.MFT` keeps a key its body omits and is an upsert**, 201 on create, which requires all five fields; `Service` is create-only, because a `PUT` changing it relabels the stored object (Story 18.26; measured)."
4. **AD-15 and AD-53 (next ordinals):** MFT connection create, update, delete and token revoke record no vendor event with auditing on (measured). The delete's client removal records `%System/%Security/OAuth2`.
5. **AD-44:** "**Story 18.26's `CLASSICPAGES`**: create and update declare `%CSP.UI.Portal.MFT.Connection`; the delete and revoke, performed on `%CSP.UI.Portal.MFT.ConnectionList` itself, declare none."
6. **AD-51:** "Story 18.26's case: `MftPort` answers the revoke's fresh read through a port-composed `STATE` type (`GET` plus the `LIST` row's `IsAuthorized`), refusing 409 `MFT.TOKEN.NONE`, which the tool names in `PRECONDITIONCODES`."
7. **AD-2 (with AD-52's port list):** "`MftPort` (Story 18.26) re-reads a `Security.MFT` `DELETE` the vendor answered with an error: an absent connection is the delete done (measured: the vendor deletes it, then answers 500 #5809 when its OAuth 2.0 client is absent)."

**Integration ACs.** The new modules (`MftPort`, `MftConnectionRules`, `MftConnectionSave`, `MftConnectionError`) are consumed in this story by the page, both row actions and the agent (Tasks › Integration).

- **Consumes:**
  - 12.5: client configurations by name; the delete removes them.
  - 18.25: the list plus form; 12.2: the revoke port; 18.18: `PRECONDITIONCODES`.
  - 23.4: `HoldTool`. 16.17: read-back. 14.1: `Snippet`. 14.2: baseline.
- **Consumed-by:** 18.12 (the agent's grown tool set).

**Ledger inbox (Rule 17):** empty (`slice 18-26-managed-file-transfer-connections`).

**Footprint (Rule 11).**

- **Contended files, add-only:**
  - the kernel (`EntityType`, `Baseline`, `Prohibited`);
  - the registry;
  - `Error.cls` and `Router.cls`;
  - the test rosters and `ci.test.mjs`;
  - `strings.ts`, `screen-action-handler.ts` and `app.ts`;
  - EXPERIENCE.md and the spine.
- `footprint_extensions`: `Port/MftPort.cls`, `Port/AdminPort.cls` (three type lists), `Api/MftConnectionError.cls`, `scripts/ci-throwaway.sh`.

**Size (inference).** Story 18.25 without the AD-10 arm and the id rule, plus one composed read type and a revoke tool. It fits one implement pass.

**Vendor defect candidates** (owner hold; for the lead's list, not reported):

1. A `Security.MFT` `DELETE` whose OAuth 2.0 client is absent deletes the connection and answers 500 #5809.
2. `Security.MFT` `PUT` answers 500 `<CLASS DOES NOT EXIST>` for an unknown `Service`. It stores `Base`, and it relabels a stored object's `Service`.
3. `%SYS.MFT.Connection.Base.DeleteId`'s doc comment inverts `keepOAuth2`.

**For the lead (spec gate):** Decisions 1-6, spine amendments 1-7, DW-2007's scope (add `Security.MFT` `DELETE` #5809), and the three vendor candidates.

**Measured at Task 0:** (filled by the implement stage)

## Verification

**Setup (slot A):**

- Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh`, which prints `LOAD-OK` and `STARTPATH-OK`.
- One test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout.
- Before a browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**S0 for `ocupilot-ci`:**

- No MFT connection, no `OAuth2.Client`, `OAuth2.ServerDefinition` or `OAuth2.AccessToken` row.
- The SSL/TLS configurations `BFC_SSL`, `ISC.FHIRExplorer.SSL.Config`, `ISC.FeatureTracker.SSL.Config`, `OcuPilotDemoTLS` and `OcuPilotProvider`, each `Type` 0.
- No `OcuMftProbe*` or `OcuProbe1826*` object or principal. Monitor 0.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time. Expected 0 failures, with totals checked against `%UnitTest_Result`.
  - The story's classes: `MftConnectionDescriptor`, `MftConnectionRead`, `MftConnectionWrite`, `MftConnectionGate`.
  - Then the rosters in Tasks › Tests.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/mft-connections.browser-spec.mjs browser/security.browser-spec.mjs`. Expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected clean.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`;
  4. the throwaway reads as S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on `ocupilot-ci`, recompile the tree, observe red, revert byte-identical, and record `mutation: <change> -> <test> red (run n)` here:

- **C1:** the list read drops `IsAuthorized` -> `MftConnectionRead`'s one-read leg.
- **C2:** the update's permitted fields admit `Service` -> `MftConnectionDescriptor`'s field leg. The Save skips `HoldTool` -> the busy leg.
- **C3:** `MftPort`'s delete re-read removed -> the client-absent delete leg. `MFT.DELETE` unmapped in `proposal-view.ts` -> `proposal-view.test.mjs`.
- **C4:** `STATE` stops refusing "Not Authorized" -> the no-token leg.
- **C5:** `Problem` drops the `Service` rule -> the rules leg (`INTERNAL` replaces `MFT.SERVICE`).
- **C6:** `security.mftconnections.delete` set `true` -> the baseline leg.
- **Integration:** `POST /mft-connection` removed from `Api/Router.cls` -> the wire leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned:** the whole story as one implement pass.
- **Measured at plan** on `ocupilot-ci` through the admin API: probe connections `OcuProbe1826A`-`F`, two probe OAuth 2.0 clients and descriptions, and one probe principal and role. Each was removed, and S0 was re-read with the monitor at 0.
- **Spec-gate items** are in Design Notes › For the lead.
- The plan was self-reviewed against the READY-FOR-DEVELOPMENT standard.
