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
- Story 12.8: The OAuth 2.0 server client description editor
- Story 12.9: Removing the classic link-outs

## Requirements & Constraints

- **Every editor** is a full-page `form-page` route whose tabs mirror the classic editor's. It round-trips create, edit and delete, ships its agent write tool over the derived field list, and publishes to the change-event bus. It declares no suggested prompts until Story 11.3's key exists.
- **Secrets are write-only end to end.** Masked, never pre-filled, and never in a read, proposal, diff, ledger row, screen context, status or log line. Where the vendor GET returns one, the port strips it.
- **12.8** covers redirect URLs, the client secret and JWKS update. The client secret is masked, write-only and never returned.
- **12.9** makes each OAuth tab's name cell open OcuPilot's editor and removes every classic link on the screen. The OAuth exemption count goes to none, and the closed Release 1 risk is recorded.
- **New screens pass the structural gate**, use tokens only, render in the dark theme, and get no baseline allowance. `structural-baseline.json` gains only a new route's shell-chrome rows.
- **Bundle:** `maximumWarning` is 1854kB, re-based under DW-1166 when a story's measured total crosses it.

## Technical Decisions

- **Merge (AD-4):** read fresh, apply the diff, and send the complete property set. Each story measures its own `Security.OAuth2.*` `PUT` on a throwaway and records the result in AD-4.
  - Every endpoint measured so far keeps omitted fields. `Metadata` merges by member (`""` or `[]` clears one), so the set sends every member as read. Arrays are replaced whole when sent: `Audiences`, `Authenticator`, `SupportedScopes` and `CustomizationRoles`.
  - `ClientConfiguration`, `ResourceServer`, `ResourceServerMapping` and `Server` `PUT`s are **upserts**. The fresh read plus AD-54's absence fingerprint stop a write from re-creating a deleted target.
  - A secret never travels in the set: `Server`'s `ServerPassword` goes only through `CHANGEPWD`.
- **Field lists (AD-3):** the derived list is the wire contract. `Metadata` is one opaque object whose members come from the vendor's metadata class, never from `mainspec_v2.json`. Every field is classified `ordinary`, `secret` or `opaque`, and an unclassified credential-named string fails the build. The credential pattern's one named exception is `ReturnRefreshToken`, and a new one is named in the Secrets convention by the story that needs it.
- **Writes use two mechanisms and no third.** Editor Save goes through the write tool (AD-55), and a create uses AD-54. Row and page actions use AD-53's `POST /screens/:screen/action` (secrets only under `secretArguments`, AD-56). Screen writes emit no audit marker, but agent confirms do.
- **Bodyless operations** (JWKS update, Rotate Keys, revoke, a secret-only body) are AD-51 action writes. Each declares a request type and a fingerprint subject covering every field its precondition reads.
- **Ports (AD-52, AD-27):** each editor's tools declare their own port extending `AdminPort` (`OAuthServerPort`, `OAuthClientPort`, `OAuthResourceServerPort`, `OAuthAuthorizationServerPort`). Only a port names an `%Api.Admin.*` class. A vendor-class call is a named AD-27 case, used only where the admin API cannot carry it and repeating the endpoint's gate in `%SYS`: 12.4's `GetServerMetadata` and `RefreshJWKS(1,1)`, and 12.7's `OAuth2.Server.Configuration.RotateKeys()`.
- **Privileges (AD-8, AD-29):** the tab, the form and every tool share one pair set. `ResourcesOR()` is only a lower bound, so measure a least-privileged principal on a throwaway.
  - The resource server needed `%Admin_OAuth2_Client:USE`.
  - The authorization server holds with `%Admin_OAuth2_Server:USE` + `%DB_IRISSYS:READ`.
  - `Security.OAuth2.ServerClients` `LIST` is gated by `%Admin_OAuth2_Registration`, and that two-pair principal was refused it.
- **Audit masking (AD-35):** IRIS writes some OAuth secrets in plain text into its own audit rows. The audit read masks the keys declared per named event on both screen and agent paths. There are three declarations:
  - `registration_access_token` in server-definition and client events;
  - credential-named authenticator settings in `OAuth2ResourceServerChange`;
  - `ServerPassword` in Create and Modify OAuth2 Server.

  A vendor secret found in any other event needs a new declaration. Named gap: the mask matches English captions only (DW-1645).
- **Descriptors (AD-5, AD-13, AD-14):** ids are percent-encoded in one path segment, change events carry `(type, scope, id)`, and tool names follow `<area>.<screen>.<verb>`. The port refuses a mutating request the vendor would queue (AD-26).
- **Classic links (AD-44):** there are three exemptions with three declarations: `OAuthServerClientTab` (OAuth), `ServiceForm` (removed by 16.13) and `LdapConfigForm` (removed by 16.14). The spine assigns the removal of the last OAuth declaration to 12.9, which sets the OAuth count to none and recomputes any total from AD-44's list. The epics file's DW-1643 line still says "the remaining three", which is stale.

## UX & Interaction Patterns

- **Form page (UX-DR32):** one column (max 720px, fields max 480px) in classic order, with inline server-written validation on the named field. A failed Save focuses the error summary. The sticky 56px action bar has Save as its only primary, and the unsaved-changes guard also holds agent navigation.
- **Tabs (UX-DR33):** tabbed editors use `app-form-tabs`, and there is no second tab component. One form spans all tabs. An error switches to its tab, which is marked with a destructive dot and ", N errors".
- **Deletes** use a typed-name dialog that names the entry. The consequence line states what the vendor blocks, cascades or leaves dangling: deleting a server client description revokes its tokens, and deleting the authorization server deletes every server client. Dialogs never stack.
- **Fixed strings:** reuse existing OAuth strings. Masked secrets share "Leave empty to keep the stored value.", and each new editor adds its own labels and outcome lines to the EXPERIENCE strings table. An editor's own Save raises no change toast.

## Cross-Story Dependencies

- 12.9 depends on 12.4 through 12.8.
- 12.8's entities are the clients that 12.7's proposals name. 12.7 fingerprints the client list, so a client registered or removed between mint and confirm refuses an authorization-server confirm.
- Epics 6, 7, 8, 9 and 15 are merged. Story 11.3's suggested-prompt key is still in the backlog.
