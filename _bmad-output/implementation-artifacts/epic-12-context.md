# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. The OAuth 2.0 screen's five read-only tabs and their classic link-outs become five OcuPilot editors that round-trip create, edit and delete, alongside X.509 details, token revoke, and audit copy and purge. The epic closes the Release 1 risk "OAuth is lists, views and deletes" and the OAuth link-out exemption (SM-C1).

## Stories

- Story 12.1: The security-area test and detail actions (done)
- Story 12.2: Revoke a user's OAuth 2.0 tokens (done)
- Story 12.3: Copy and purge the audit database (done)
- Story 12.4: The OAuth 2.0 client server-description editor (done)
- Story 12.5: The OAuth 2.0 client configuration editor (done)
- Story 12.6: The OAuth 2.0 resource server editor (done)
- Story 12.7: The OAuth 2.0 authorization server editor (done)
- Story 12.8: The OAuth 2.0 server client description editor (done)
- Story 12.9: Removing the classic link-outs

## Requirements & Constraints

- **12.9 is what remains.** Every OAuth tab's name cell already opens OcuPilot's editor, and no OAuth tab declares the classic-link exemption. 12.9 confirms that no classic link remains on the screen and retires the leftover OAuth-exemption prose. It also makes AD-44 read two exemptions throughout (DW-1643) and records the closed Release 1 risk. That risk is the PRD's accepted-risk row saying OAuth setup is lists and deletes at the deadline.
- **The OAuth exemption count goes to zero, and the total does not.** `ServiceForm` and `LdapConfigForm` stay counted until Stories 16.13 and 16.14 remove them, so the checker reports two exemptions across two declarations.
- **Every editor** is a full-page `form-page` route whose tabs mirror the classic editor's. It round-trips create, edit and delete, ships its agent write tool over the derived field list, and publishes to the change-event bus. It declares no suggested prompts until Story 11.3's key exists.
- **Secrets are write-only end to end.** They are masked, never pre-filled, and never appear in a read, proposal, diff, ledger row, screen context, status or log line. Where the vendor GET returns one, the port strips it.
- **New screens pass the structural gate** and get no baseline allowance. The bundle's `maximumWarning` (1854kB) is re-based under DW-1166 when a story's measured total crosses it.

## Technical Decisions

- **Merge (AD-4):** read fresh, apply the diff, and send the complete property set. Every `Security.OAuth2.*` endpoint was measured to keep omitted fields.
  - `Metadata` merges by member (`""` or `[]` clears one), so the set sends every member as read.
  - These arrays are replaced whole when sent: `Audiences`, `Authenticator`, `SupportedScopes`, `CustomizationRoles` and `RedirectURL`.
  - `ClientConfiguration`, `ResourceServer`, `ResourceServerMapping` and `Server` `PUT`s are **upserts**, so the fresh read plus the fingerprint stop a write from re-creating a deleted target. A `ServerClients` `PUT` is not an upsert: an absent client answers 404.
  - A secret never travels in the set. `Server`'s `ServerPassword` goes only through `CHANGEPWD`, and a server client's `ClientSecret` only through the endpoint's `SECRET` type. The server client's `GET` answers `client_secret` and `registration_access_token` unmasked, so the port strips both.
- **Field lists (AD-3):** the derived list is the wire contract, and `Metadata` is one opaque object. An unclassified credential-named string fails the build.
- **Writes use two mechanisms and no third.** Editor Save goes through the write tool (AD-55). Row and page actions use AD-53's `POST /screens/:screen/action`, with secrets only under `secretArguments` (AD-56). Screen writes emit no audit marker, but agent confirms do.
- **Creates (AD-54)** fingerprint the name's absence. For server clients, the fresh read is the `LIST` keyed by `Name`, which compares case-insensitively. A taken name refuses the create on both callers.
- **Bodyless operations** (JWKS update, Rotate Keys, revoke, a secret-only body) are AD-51 action writes. Each declares a request type and a fingerprint subject covering every field its precondition reads.
- **Ports (AD-52, AD-27):** each editor's tools declare their own port extending `AdminPort`: `OAuthServerPort`, `OAuthClientPort`, `OAuthResourceServerPort`, `OAuthAuthorizationServerPort` and `OAuthRegisteredClientPort`. Only a port names an `%Api.Admin.*` class. A vendor-class call is a named AD-27 case, used only where the admin API cannot carry the call, and it repeats the endpoint's gate in `%SYS`:
  - 12.4's `GetServerMetadata` and `RefreshJWKS(1,1)`;
  - 12.7's `RotateKeys()`;
  - 12.8's `OAuth2.Server.Client.RefreshJWKS`.
- **Outbound TLS (AD-32):** the installer-created SSL configuration also serves 12.8's JWKS fetch for an `https` URI, and an `http` URI uses no configuration. Named gap: a key-set URI trusted only by the authorization server's own configuration is refused by name.
- **Privileges (AD-8, AD-29):** the tab, the form and every tool share one pair set. `ResourcesOR()` is only a lower bound, so the pair set is measured with a least-privileged principal on a throwaway.
  - The resource server needed `%Admin_OAuth2_Client:USE`.
  - The authorization server holds with `%Admin_OAuth2_Server:USE` + `%DB_IRISSYS:READ`.
  - Server clients hold with `%Admin_OAuth2_Registration:USE` + `%DB_IRISSYS:READ`.
- **Audit masking (AD-35):** IRIS writes some OAuth secrets in plain text into its own audit rows. The audit read masks the keys declared per named event on both the screen and agent paths. There are four declarations:
  - `registration_access_token` in server-definition and client events;
  - credential-named authenticator settings in `OAuth2ResourceServerChange`;
  - `ServerPassword` in Create and Modify OAuth2 Server;
  - `registration_access_token` in Create and Modify OAuth2 Server Client.

  A vendor secret found in any other event needs a new declaration. Named gap: the mask matches English captions only (DW-1645).
- **Classic links (AD-44):** the list names two exemptions with two declarations: `ServiceForm` and `LdapConfigForm`. The OAuth exemption has no declaration left, and any total is recomputed from that list. One sentence of AD-44 still reads "exactly three … SM-C1 counts three", and fixing it is 12.9's DW-1643 work.

## UX & Interaction Patterns

- **Form page (UX-DR32, UX-DR33):** one column in classic order with server-written inline validation, a sticky action bar with Save as its only primary, and `app-form-tabs` with one form spanning all tabs.
- **Deletes** use a typed-name dialog that names the entry. The consequence line states what the vendor blocks, cascades or leaves dangling. For example, deleting a server client revokes its tokens. Dialogs never stack.
- **Fixed strings:** reuse the existing OAuth strings. Masked secrets share "Leave empty to keep the stored value." An editor's own Save raises no change toast.

## Cross-Story Dependencies

- 12.9 depends on 12.4 through 12.8, all done.
- 16.13 and 16.14 (backlog) remove the two remaining exemptions. Story 11.3's suggested-prompt key is still in the backlog.
- Epics 6, 7, 8, 9 and 15 are merged.
