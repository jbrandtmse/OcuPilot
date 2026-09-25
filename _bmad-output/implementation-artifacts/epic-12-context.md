# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. At the start of this epic the OAuth 2.0 screen had five read-only tabs, two deletes, and name cells that linked out to the classic portal. This epic replaces those link-outs with five OcuPilot editors that each round-trip create, edit and delete. It also adds the security-area actions: X.509 details, OAuth token revoke, and audit-database copy and purge. The owner's re-sequence of 2026-09-21 ranked this epic first in polish week. It closes the accepted Release 1 risk that "OAuth is lists, views and deletes", and it brings the classic link-out count (SM-C1) back to zero.

## Stories

- Story 12.1: The security-area test and detail actions
- Story 12.2: Revoke a user's OAuth 2.0 tokens
- Story 12.3: Copy and purge the audit database
- Story 12.4: The OAuth 2.0 client server-description editor
- Story 12.5: The OAuth 2.0 client configuration editor
- Story 12.6: The OAuth 2.0 resource server editor
- Story 12.7: The OAuth 2.0 authorization server editor
- Story 12.8: The OAuth 2.0 server client description editor
- Story 12.9: Removing the classic link-outs

## Requirements & Constraints

- **Every editor** is a full-page route on the `form-page` contract. Where the classic editor has tabs, the editor's tabs mirror them. It round-trips create, edit and delete, ships with its agent write tool over the derived field list, publishes to the change-event bus, and declares its suggested prompts in its descriptor.
- **Secrets are write-only end to end.** A client secret, a private key or an initial access token is masked, never pre-filled, and never returned by any read, proposal argument, ledger row, diff, screen context or log line.
- **12.1 (done):** X.509 details show the certificate and never the private key. The SSL/TLS test (Story 9.5) and the LDAP test (Story 16.14) are built elsewhere, not here.
- **12.2 (done):** revoke is a Users row action that runs as the administrator. An agent proposal needs confirmation and carries the audit marker. The route is `/v2/security/oauth2/server/revoke` with a required `user` query parameter.
- **12.3 (done):** copy and purge run on the instance in the background, from the Auditing screen. Purge stays unadvertised to the agent until Story 14.2.
- **12.4 (done):** the server-description editor. Its pattern is the model for 12.5 to 12.8:
  - the id is the entity's display name, resolved to the vendor id by a story-owned port through the endpoint's own `LIST`;
  - create is `POST`, and a duplicate maps to a field violation;
  - a secret-only vendor type (`TOKEN`, body `{InitialAccessToken}`) carries the registration token, and an empty field leaves the stored token unchanged;
  - a delete is refused by name while dependents block it, and allowed with a consequence line where the vendor leaves references dangling.
- **12.5 and 12.7:** Rotate Keys reports its result.
- **12.7:** an agent-proposed change to the authorization server's own configuration carries the full write model, and its card states which clients the change affects.
- **12.9:** each tab's name cell opens OcuPilot's editor. The three remaining classic links come off, and the spine's exemption count goes to none. Record SM-C1 back at zero, and record the Release 1 risk as closed.
- **New screens pass the structural gate:** accessible names, minimum control widths, no overflow and no page-level horizontal scroll. They use design tokens only, render correctly in the dark theme, and get no baseline allowance.

## Technical Decisions

- **Merge: read fresh, apply the diff, send the complete property set (AD-4).** The rule is uniform, whatever an endpoint does with omitted keys.
  - All four `Security.OAuth2.*` endpoints call no merge helper. Each story measures its own endpoint on a throwaway and records the result in AD-4.
  - `Security.OAuth2.Client.ServerDefinition` keeps omitted fields, and it merges `Metadata` member by member. Its complete set therefore sends every derived member, with an absent one in its empty form (`""`, `[]`, `false`). Otherwise a cleared member would survive.
  - `Security.X509Credential` keeps omitted fields. It still receives the complete set.
- **Field lists (AD-3).** The derived list is the wire contract. It carries `Metadata` as one opaque object.
  - The `Metadata.*` member sets come from the vendor's metadata class for the entity (`OAuth2.Server.Metadata`, `OAuth2.Client.Metadata` for a client configuration), whose generated `ImportJSON` is what the endpoint applies. They do not come from `mainspec_v2.json`, which is not vendored.
  - `ClientId`, `JWTInterval` and `ServerDefinition` keep their template names, because the endpoint rejects unknown keys.
  - A `Metadata` key must be a derived member with the member's shape. The vendor silently ignores anything else, so OcuPilot refuses it.
  - Every field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted as secret. A string field with a credential-like name that is not classified secret fails the build.
- **Two write mechanisms, and no third.**
  - **Editor Save** resolves through the write tool (AD-55). A create uses AD-54's absence fingerprint. Read-only mode and the kill switch do not gate a person's Save.
  - **Row and page actions** use AD-53's `POST /screens/:screen/action`. Secrets travel only under `secretArguments` (AD-56).
  - **Bodyless writes** (revoke, Rotate Keys, Update JWKS) are action-style (AD-51). Each declares its request type and a fingerprint subject that covers every precondition field.
- **Vendor-class completions (AD-27).** Only `Port/AdminPort` names `%Api.Admin.*`. A call completed through a vendor class needs a new **named** AD-27 case; it is never a general license.
  - Story 12.4 added two, in `Port/OAuthServerPort`, after it repeats the endpoint's `%Admin_OAuth2_Client:USE` gate and runs in `%SYS`.
  - **Discovery** calls `OAuth2.ServerDefinition.GetServerMetadata`, which saves nothing. It is screen-only with no agent tool, and a test pins its signature because the method is `[Internal]`. Never pass `?discover=1`: it saves unreviewed metadata and discards the body's `Metadata`.
  - **Update JWKS** calls `RefreshJWKS(1,1)` as an AD-51 action write, because the admin API has no JWKS type.
  - A secret never enters a status, an exception, a log line or a temporary file (AD-35).
- **Privileges (AD-8).** A tool's pair set is its screen's. Administrative resources are gated at `USE`. A tool may also declare an extra pair that the vendor endpoint's `ResourcesOR()` names for that request type, as measured on the instance.
- **Audit gaps (AD-15, AD-53).** IRIS records no audit event for a token revoke, so an agent revoke's marker is the only record. Screen writes emit no marker.
- **Queued writes (AD-26).** The port refuses any mutating request the vendor would queue, except the audit `COPY` and `PURGE`.
- **Proposals (AD-6, AD-34, AD-40).** A proposal is minted on the server, used once, fingerprinted, and expires after 10 minutes. Confirm re-checks privileges and the prohibited set atomically.
- **Descriptors (AD-5, AD-13, AD-14).** Each OAuth tab has its own descriptor, and a tab may declare several entity types. An editor declares side-bar position 0, no tools and no row actions, and it is opened from its tab. Ids are percent-encoded in one path segment. Tool names follow `<area>.<screen>.<verb>`.
- **Classic link-outs (AD-44).** The OAuth tabs hold Release 1's only `classicLinkExemption`, counted once. Three tab descriptors still declare it (`OAuthServerTab`, `OAuthResourceServerTab`, `OAuthServerClientTab`). Story 12.9 removes them, and the automated check then reports none.

## UX & Interaction Patterns

- **Form page:** a single column at most 720px wide, with fields at most 480px wide, in the classic order. Validation is inline, written by the server, and lands on the named field. A failed Save moves focus to the error-summary banner. The sticky 56px action bar has Save as its only primary button. After Save, a create or an id change opens the entity with `replaceUrl`, and an edit shows "Saved". The unsaved-changes guard also holds an agent navigation.
- **Tabs (UX-DR32/33), where the classic editor has them:** one form spans all tabs, and Save applies everything. A validation error switches to the tab that holds it. A tab with errors shows a destructive dot and adds ", N errors" to its accessible name. A classic single form with fieldsets stays untabbed, as 12.4's did.
- **Deletes and revoke** use a dialog that names the entry and requires the typed name. Dialogs never stack.
- **Fixed strings:** existing OAuth labels, empty states, delete consequences, and the X.509, revoke, audit and server-description copy. Reuse them without rewording.

## Cross-Story Dependencies

- **Shared tabbed form:** `ui/src/app/shell/form-tabs.ts` exists only on `OCU-1-epic9`, not here. Story 12.4 did not adopt it. The first tabbed editor, from either Story 9.1 or 12.5 to 12.8, sets it, and the other adopts it at its merge. Contended files are read from `origin/OCU-1-epic9` first, and each story touches only its own lines.
- **This epic depends on Epics 6, 7 and 8** (all merged) and runs beside Epic 9.
- **12.9 depends on 12.4 through 12.8.** 12.5 configures a client against a server description from 12.4. 12.7's affected-clients line names the server client descriptions that 12.8 edits.
- **Suggested prompts:** Story 11.3 owns the descriptor key. It is still in the backlog, so every editor's prompts wait for it.
- **Story 14.2** advertises `security.auditing.purge` and delivers its disabled-by-default policy key and the agent purge card.
