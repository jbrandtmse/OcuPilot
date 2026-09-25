# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. It replaces the OAuth 2.0 screen's five read-only tabs and their classic link-outs with five OcuPilot editors that round-trip create, edit and delete, and adds X.509 details, token revoke, and audit copy and purge. It closes the Release 1 risk "OAuth is lists, views and deletes" and the OAuth link-out exemption (SM-C1).

## Stories

- Story 12.1: The security-area test and detail actions (done)
- Story 12.2: Revoke a user's OAuth 2.0 tokens (done)
- Story 12.3: Copy and purge the audit database (done)
- Story 12.4: The OAuth 2.0 client server-description editor (done)
- Story 12.5: The OAuth 2.0 client configuration editor (done)
- Story 12.6: The OAuth 2.0 resource server editor (done)
- Story 12.7: The OAuth 2.0 authorization server editor
- Story 12.8: The OAuth 2.0 server client description editor
- Story 12.9: Removing the classic link-outs

## Requirements & Constraints

- **Every editor** is a full-page `form-page` route whose tabs mirror the classic editor's. It round-trips create, edit and delete, ships its agent write tool over the derived field list, publishes to the change-event bus, and declares suggested prompts in its descriptor once Story 11.3's key exists.
- **Secrets are write-only end to end** (client secret, private key, initial or registration access token, credential-named authenticator settings). Masked, never pre-filled, and never in a read, proposal, diff, ledger row, screen context, status or log line; where the vendor GET returns one, the port strips it.
- **12.7** covers the issuer, scopes (add and remove), grant types and keys. Save and delete round-trip, and Rotate Keys reports its result. An agent-proposed change to the server's own configuration carries the full write model, and its card names the clients the change affects.
- **12.8** covers redirect URLs, the client secret and JWKS update.
- **12.9** makes each OAuth tab's name cell open OcuPilot's editor and removes every classic link on the screen. The OAuth exemption goes to none, and the closed Release 1 risk is recorded.
- **New screens pass the structural gate** (accessible names, control widths, no overflow), use tokens only, render in the dark theme, and get no baseline allowance.

## Technical Decisions

- **Merge (AD-4):** read fresh, apply the diff, send the complete property set regardless of how the endpoint treats omitted keys. Each story measures its own `Security.OAuth2.*` `RunPut` on a throwaway and records it in AD-4.
  - `ServerDefinition`, `ClientConfiguration` and `ResourceServer` keep omitted fields. `Metadata` merges by member (`""`, `[]` or `null` clears), so the set sends every member, absent ones empty, never a secret member. `ResourceServer` replaces `Audiences` and `Authenticator` whole, so its set carries all of both.
  - `ClientConfiguration`, `ResourceServer` and `ResourceServerMapping` PUTs are **upserts**; the fresh read and fingerprint stop a write re-creating a deleted target.
- **Field lists (AD-3):** the derived list is the wire contract. It carries `Metadata` as one opaque object whose members come from the vendor's metadata class (`OAuth2.Server.Metadata`, `OAuth2.Client.Metadata`), never from `mainspec_v2.json`. Template names stay, because the endpoint rejects unknown keys. Every field is classified `ordinary`, `secret` or `opaque`; unclassified is emitted as secret, and an unclassified credential-named string fails the build.
- **Writes use two mechanisms and no third.** Editor Save goes through the write tool (AD-55), and a create uses AD-54's absence fingerprint. Row and page actions use AD-53's `POST /screens/:screen/action` (tool-declared values only; secrets only under `secretArguments`, AD-56). Read-only and the kill switch never gate a person's Save, and screen writes emit no audit marker.
- **Bodyless operations** (Rotate Keys, JWKS update, revoke, a secret-only body) are AD-51 action writes, declaring a request type and a fingerprint subject covering every field their precondition reads. Port-built bodies are named AD-51 cases (`AuditPort`; `OAuthResourceServerPort` for mapping `Service`/`Key`); a new one is added by name.
- **Ports (AD-52, AD-27):** each editor's tools declare their own port extending `AdminPort` (`OAuthServerPort`, `OAuthClientPort`, `OAuthResourceServerPort`). Only a port names an `%Api.Admin.*` class. A vendor-class call is a named AD-27 case only where the admin API cannot carry it, repeating the endpoint's gate in `%SYS`; the OAuth cases are 12.4's `GetServerMetadata` and `RefreshJWKS(1,1)`.
- **Privileges (AD-8, AD-29):** the tab, the form and every tool share one pair set. `ResourcesOR()` is only a lower bound: read the vendor class, then add what a least-privileged principal is still refused on a throwaway. The resource server needed `%Admin_OAuth2_Client:USE` on top of `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, because the vendor's `OpenByIssuer` checks it.
- **Audit masking (AD-35):** IRIS writes some secrets in plain text into its OAuth audit rows. The audit read masks keys declared per named event on screen and agent paths: server-definition and client events (`registration_access_token`), `OAuth2ResourceServerChange` (credential-named authenticator settings). Any other event needs a new AD-35 declaration. Named gap: English captions only (DW-1645).
- **Descriptors (AD-5, AD-13, AD-14):** one per OAuth tab; ids percent-encoded in one path segment; change events carry `(type, scope, id)`; tool names follow `<area>.<screen>.<verb>`. The port refuses any mutating request the vendor would queue (AD-26), except audit `COPY` and `PURGE`.
- **Classic links (AD-44):** three exemptions carry four declarations: `OAuthServerTab` and `OAuthServerClientTab` (OAuth), `ServiceForm` (removed by 16.13), and `LdapConfigForm` (removed by 16.14). 12.7 and 12.8 each drop their own tab's declaration. 12.9 sets the OAuth count to none and recomputes totals from AD-44's list.

## UX & Interaction Patterns

- **Form page (UX-DR32):** one column (max 720px, fields max 480px) in classic order; inline server-written validation on the named field; a failed Save focuses the error summary; sticky 56px action bar with Save as the only primary; the unsaved-changes guard holds agent navigation too.
- **Tabs (UX-DR33):** 12.5, 12.6, 12.7 and 12.8 use `app-form-tabs`, and there is no second tab component. One form spans all tabs; an error switches to its tab, marked with a destructive dot and ", N errors". 12.4 stays untabbed.
- **Deletes and revoke** use a typed-name dialog that names the entry. The consequence line states what the vendor blocks, cascades or leaves dangling. Dialogs never stack.
- **Fixed strings:** reuse existing OAuth strings; masked secrets share "Leave empty to keep the stored value."; each new editor adds its labels and outcome lines.
- **From Epic 15:** table columns resize and scroll sideways with a pinned row-action column; a screen with no declared read shows no filter; an editor's own Save raises no change toast.

## Cross-Story Dependencies

- 12.9 depends on 12.4 through 12.8. 12.7's affected-clients line names the server client descriptions 12.8 edits, and a resource server references a 12.4 server description.
- Epics 6, 7, 8 and 9 are merged, and so are 15.8 and 15.9. Story 11.3's suggested-prompt key is still in the backlog, so editors declare no prompts until it lands. Story 14.2 (backlog) advertises `security.auditing.purge`, which is reachable from the screen only until then.
