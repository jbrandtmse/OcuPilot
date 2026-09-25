# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. At Release 1 the OAuth 2.0 screen was five read-only tabs with deletes, and its name cells linked out to the classic portal. This epic replaces those links with five OcuPilot editors that each round-trip create, edit and delete, and adds the security-area actions: X.509 details, token revoke, and audit copy and purge. The owner ranked it first in polish week. It closes the accepted Release 1 risk that "OAuth is lists, views and deletes", and it removes the OAuth tabs' classic link-outs from the link-out count (SM-C1).

## Stories

- Story 12.1: The security-area test and detail actions (done)
- Story 12.2: Revoke a user's OAuth 2.0 tokens (done)
- Story 12.3: Copy and purge the audit database (done)
- Story 12.4: The OAuth 2.0 client server-description editor (done)
- Story 12.5: The OAuth 2.0 client configuration editor (done)
- Story 12.6: The OAuth 2.0 resource server editor
- Story 12.7: The OAuth 2.0 authorization server editor
- Story 12.8: The OAuth 2.0 server client description editor
- Story 12.9: Removing the classic link-outs

## Requirements & Constraints

- **Every editor** is a full-page `form-page` route whose tabs mirror the classic editor's. Each one:
  - round-trips create, edit and delete;
  - ships its agent write tool over the derived field list;
  - publishes to the change-event bus;
  - declares its suggested prompts in its descriptor.
- **Secrets are write-only end to end.** This covers a client secret, a private key, and an initial or registration access token. A secret is masked and never pre-filled. No read, proposal argument, diff, ledger row, screen context, status, exception or log line ever carries one. Where the vendor GET returns a secret in plain text, the editor's port strips it from every answer.
- **12.6:** covers the resource server definition, its service mappings and its audiences.
- **12.7:** covers the issuer, scopes (with add and remove), grant types and keys. Save and delete round-trip. Rotate Keys reports its result. An agent-proposed change to the server's own configuration carries the full write model, and its card names the clients the change affects.
- **12.8:** covers redirect URLs, the client secret and JWKS update.
- **12.9:** each tab's name cell opens OcuPilot's editor, and every classic link on the OAuth screen is removed. The OAuth exemption goes to none, and SM-C1 drops by that one exemption. The Release 1 risk is recorded as closed.
- **New screens pass the structural gate:** accessible names, minimum control widths, no overflow and no page-level horizontal scroll. They use design tokens only, render correctly in the dark theme, and get no baseline allowance.

## Technical Decisions

- **Merge (AD-4): read fresh, apply the diff, send the complete property set, whatever the endpoint does with omitted keys.**
  - Each story measures its own `Security.OAuth2.*` endpoint's `RunPut` on a throwaway and records the result in AD-4.
  - So far `ServerDefinition` and `ClientConfiguration` keep omitted fields, and both merge `Metadata` member by member: `""`, `[]` or `null` clears a member, and an unknown member is ignored. The complete set therefore sends every derived member, an absent one in its empty form. It never sends a secret member, whose empty form would erase it.
  - `ClientConfiguration`'s PUT is an upsert. Where a PUT upserts, the fresh read and the fingerprint are what stop a write re-creating a deleted target.
- **Field lists (AD-3).** The derived list is the wire contract, and it carries `Metadata` as one opaque object.
  - `Metadata.*` members come from the vendor's metadata class for the entity (`OAuth2.Server.Metadata`, `OAuth2.Client.Metadata`), whose `ImportJSON` the endpoint applies. They never come from `mainspec_v2.json`.
  - Template names such as `ClientId`, `JWTInterval` and `ServerDefinition` stay as they are, because the endpoint rejects unknown keys.
  - Every field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted as secret. A credential-named string that is not classified secret fails the build.
- **Writes: two mechanisms, and no third.**
  - **Editor Save** goes through the write tool (AD-55). A create uses AD-54's absence fingerprint, even where the vendor refuses a duplicate itself.
  - **Row and page actions** use AD-53's `POST /screens/:screen/action`. That route accepts only values the tool declares, and secrets travel only under `secretArguments` (AD-56).
  - **Enforced read-only and the kill switch never gate a person's Save or action.** Screen writes emit no OcuPilot audit marker.
  - **Bodyless operations** (Rotate Keys, JWKS update, revoke) are AD-51 action writes. Each declares its request type and a fingerprint subject that covers every field its precondition reads. For example, `ClientConfiguration` Rotate Keys is refused by name while `ClientCredentials` is set.
  - A secret-only body (AD-56 i) is also an action write.
- **Ports (AD-52, AD-27).** Each editor's tools declare their own port, for example `OAuthServerPort` or `OAuthClientPort`, which extends `AdminPort`.
  - Only the port may name an `%Api.Admin.*` class.
  - A port may complete a call through a vendor class only as a named AD-27 case, when the admin API cannot carry that call. It repeats the endpoint's `%Admin_OAuth2_*:USE` gate and runs in `%SYS`.
  - The named cases today are 12.4's discovery (`GetServerMetadata`, screen-only and signature-pinned) and its Update JWKS (`RefreshJWKS(1,1)`).
  - A new case is added to AD-27 by name. It is never a general license.
- **Privileges (AD-8).** A tool's pair set is its screen's own, and administrative resources are gated at `USE`. A tool may add a pair only where the `ResourcesOR()` of the vendor endpoint its call reaches names that pair, as measured on the instance.
- **Audit (AD-15, AD-35, AD-53).**
  - IRIS writes the registration access token in plain text into its own OAuth audit rows. The audit read masks declared keys for each named vendor event, on both the screen and the agent path. A secret found in any other event needs a new declaration in AD-35.
  - The mask matches English captions (DW-1645, a named gap).
  - Avoid gratuitous vendor saves, because each save re-dumps the token.
- **Queued writes (AD-26).** The port refuses any mutating request the vendor would queue, except the audit `COPY` and `PURGE`.
- **Proposals (AD-6, AD-34).** A proposal is server-minted, used once, fingerprinted and expires after 10 minutes. Confirm re-checks state, privileges and the prohibited set in one atomic transition.
- **Descriptors (AD-5, AD-13, AD-14).**
  - The OAuth screen is one descriptor per tab, and a tab may declare secondary entity types.
  - Ids are percent-encoded in one path segment, and change events carry `(type, scope, id)`.
  - Tool names follow `<area>.<screen>.<verb>`.
- **Classic links (AD-44).** The spine names three exemptions and five declarations:
  - the OAuth exemption: `OAuthServerTab`, `OAuthResourceServerTab`, `OAuthServerClientTab`;
  - `ServiceForm`, removed by 16.13;
  - `LdapConfigForm`, removed by 16.14.

  12.4 and 12.5 each dropped their tab's declaration. Each editor story drops its own tab's declaration, and 12.9 sets the OAuth count to none in AD-44, recomputing any total from that list.

## UX & Interaction Patterns

- **Form page (UX-DR32):**
  - A single column at most 720px wide, with fields at most 480px wide, in the classic order.
  - Validation is inline and written by the server, and lands on the named field. A failed Save moves focus to the error-summary banner.
  - The sticky 56px action bar has Save as its only primary button.
  - A create opens the new entity's editor. An edit shows "Saved".
  - The unsaved-changes guard also holds an agent navigation.
- **Tabs (UX-DR33):** `app-form-tabs` (`ui/src/app/shell/form-tabs.ts`, with `core/form-tabs.ts`) is on this branch.
  - One form spans all tabs, and Save applies everything.
  - A validation error switches to the tab that holds it.
  - A tab with errors shows a destructive dot and adds ", N errors" to its accessible name.
- **Deletes and revoke** use a dialog that names the entry and requires the typed name. The delete consequence line states what the vendor blocks or leaves dangling. Dialogs never stack.
- **Fixed strings:** reuse the OAuth tab labels, empty states, and the strings for the server-description editor, the client-configuration editor and revoke as written. Masked secret fields share the hint "Leave empty to keep the stored value." Each new editor's labels and outcome lines are added as Fixed strings.

## Cross-Story Dependencies

- **DW-1644, carried by 12.6:**
  - switch 12.5's sectioned client-configuration editor to `app-form-tabs`;
  - build 12.6 to 12.8 on it directly;
  - 12.4's untabbed single form stays as it is.
- **12.9 depends on 12.4 to 12.8.** 12.7's affected-clients line names the server client descriptions that 12.8 edits. A resource server references a server description from 12.4.
- **Epic dependencies:**
  - Epics 6, 7, 8 and 9 are merged.
  - The descriptor key for suggested prompts is Story 11.3's, which is still in the backlog.
  - Story 14.2 (backlog) advertises `security.auditing.purge`, which until then is reachable from the screen only.
