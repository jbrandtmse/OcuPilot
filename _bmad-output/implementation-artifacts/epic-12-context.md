# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. Today the OAuth 2.0 screen has five read-only tabs, two deletes, and name cells that link out to the classic portal. This epic replaces the link-outs with five OcuPilot editors that each round-trip create, edit and delete. It also adds the security-area actions: X.509 details, OAuth token revoke, and audit-database copy and purge. The owner's re-sequence of 2026-09-21 ranked this epic first in polish week. It closes the accepted Release 1 risk that "OAuth is lists, views and deletes", and it brings the classic link-out count back to zero.

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

- **Every editor** is a full-page route on the `form-page` contract, with tabs that mirror the classic editor. It round-trips create, edit and delete. It ships with its agent write tool over the derived field list, and every save publishes to the change-event bus.
- **Secrets are write-only end to end.** A client secret, a private key or an initial access token is masked, never pre-filled, and never returned by any read, ledger row, diff, screen context or log line. They are excluded by schema declaration, with the name-pattern matcher as a backstop only.
- **12.1:** X.509 details render the certificate and never the private key. The SSL/TLS test (Story 9.5) and the LDAP test (Story 16.14) are **not** built here.
- **12.2 revoke:**
  - It runs as the administrator. When the agent proposes it, it goes through a confirmed proposal, and the audit database carries the marked event.
  - The confirmation names the user whose tokens are being revoked.
  - The route is `/v2/security/oauth2/server/revoke`, with `user` as a required query parameter. This is the instance's UrlMap. The published spec's `/v2/security/oauth2/revoke` answers 404 on 2026.2. Re-measure it before designing the call.
- **12.3 copy and purge:**
  - Copy runs in the background to a chosen namespace and reports progress.
  - Purge removes records older than N days. Its confirmation names the scope and the cut-off.
  - **Purge is screen-only.** It is not registered as an agent write tool until Epic 14's governance ships, and it is registered in the same change that adds the policy. At that point it defaults to disabled as a post-freeze destructive key. When the agent proposes it, the card states that the purge destroys the record the agent marker lives in.
  - No code on this branch yet reaches an audit copy or purge operation.
- **12.4:** Discover and Save fetches the issuer's metadata into the form for review before anything is saved. Update JWKS reports its result.
- **12.5 and 12.7:** Rotate Keys reports its result.
- **12.7:** An agent-proposed change to the authorization server's own configuration carries the full write model, and its card states which clients the change affects.
- **12.9:** Each tab's name cell opens OcuPilot's editor, and the `classicLinkExemption` comes off all five tab descriptors. Record SM-C1 back at zero and record the risk as closed.
- **New screens pass the DW-1337 structural gate:** accessible names, minimum control widths, no overflow, and no page-level horizontal scroll. They use design tokens only and must render correctly in the dark theme. A component draws bare `--ocu-*` roles and never selects on the theme.

## Technical Decisions

- **The merge must be measured, not assumed (AD-4).**
  - The epics preamble says all four `Security.OAuth2.*` endpoints and `Security.X509Credential` "do not merge". Epic 8 measured X.509's `RunPut` and found that it sets only the keys the body carries, which is effectively a merge.
  - Measure each OAuth 2.0 endpoint's merge behaviour on the instance before designing its save.
  - Whatever the measurement shows, OcuPilot reads fresh, applies the diff and sends the **complete property set**.
  - Where AD-4's list is wrong, correct it at its origin in the spine.
- **Field lists (AD-3).**
  - Derived lists are the wire contract, and they carry `Metadata` as one opaque object. The published spec (`mainspec_v2.json`, upstream `intersystems-community/sysadmin-api-specification`, not vendored here) supplies only the `Metadata.*` member sets, 30 to 70 members per editor.
  - `ClientId`, `JWTInterval` and `ServerDefinition` keep the template's names. The spec's PUT names `OAuth2ServerDefinition` instead, but the endpoint rejects unknown keys (verified 2026-09-16).
  - Every derived field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted secret, and a string field whose name matches the credential pattern fails the build unless it is classified secret.
- **Exactly two write mechanisms, and no third.**
  - **Editor Save** resolves through the write tool (AD-55). Creates use AD-54's create kind: the target must be absent, and the fingerprint covers that absence. The screen mints no proposal, but the prohibited set and the write's own validation and fingerprint gates still apply. Read-only mode and the kill switch do not gate a person's Save.
  - **List row actions** go through AD-53: `POST /screens/:screen/action`, client-side `screen-action-handler.ts`. The screen action and the agent's write are one operation.
  - Actions that write with no body, such as revoke, Rotate Keys and Update JWKS, are action-style writes (AD-51). Each declares its request type and a fingerprint subject over the fresh read. A screen action accepts only the values its tool declares (AD-56) (inference: which of the two mechanisms carries each editor-level action button is the story's to settle).
- **Proposals (AD-6, AD-34, AD-40).**
  - Proposals are server-minted, single-use, fingerprinted and expire after 10 minutes.
  - The confirm channel admits only the tool's declared secret fields.
  - Confirm re-checks privileges and runs the prohibited set inside one atomic transition.
  - Agent writes emit the correlatable audit marker (AD-15). Screen writes emit no marker.
- **Privileges (AD-8).** A tool's pair set is its screen's set. Administrative resources are gated at `USE`, never `WRITE`. Extra pairs are allowed only when the vendor class writes a database the screen's read does not.
- **Prohibited set (AD-10).** Only self-protection is refused. Privilege grants proceed at the strongest (typed-name) confirmation.
- **Descriptors (AD-5, AD-13, AD-14, AD-44).**
  - The OAuth 2.0 screen is one descriptor per tab: `Screen/Descriptor/OAuth*Tab.cls`, detail archetype, several entity types. Existing tools include `security.oauthclients.delete` and `security.oauthserverclients.delete`.
  - An editor takes `sideBarPosition` 0 and is reached from its tab.
  - Ids are percent-encoded in one segment by the shared encoder. Every cross-boundary reference is the triple `(type, instance, id)`.
  - Entity types come from the kernel's closed enum.
  - Tool names follow `<area>.<screen>.<verb>`. Tool identity comes from a stable descriptor identifier.
- **Only `Port/AdminPort` names `%Api.Admin.*` (AD-27).** The admin API is experimental. A port may complete a call through a vendor class only as a new **named** AD-27 case, never under a general licence.
- **Secrets (AD-35).** A secret never enters a status, an exception, a log line or a temporary file.

## UX & Interaction Patterns

- **Form page (UX-DR32).**
  - Single column, at most 720px wide, with fields at most 480px wide. Fields follow the classic order.
  - Validation is inline and server-authored, landing on the named field. A failed Save moves focus to the error-summary banner.
  - The sticky 56px action bar has Save as its only primary.
  - Create opens the new entity. Edit shows "Saved".
  - The unsaved-changes guard also holds an agent navigation.
- **Tabs (UX-DR33).** One form spans all tabs, so Save applies everything. A validation error switches to the tab that holds it. An errored tab shows a destructive dot and adds ", N errors" to its accessible name.
- **Deletes and revoke** use a dialog that names the entry and requires the typed name. Dialogs never stack.
- **OAuth labels and empty states** are already fixed strings (the tab names in strip order, among others). Reuse them and do not reword them.

## Cross-Story Dependencies

- **The shared tabbed-form component** exists only on Epic 9's branch, as `ui/src/app/shell/form-tabs.ts` on `origin/OCU-1-epic9`. It is not on this branch. Story 12.4 decides whether to adopt it at the merge or wait for it. Whichever of 9.1 and 12.4 lands first sets the component.
- **This epic depends on Epics 6, 7 and 8** (all merged) and runs beside Epic 9.
- **12.9 depends on 12.4 to 12.8.** 12.5 configures a client against a server description from 12.4. 12.7's affected-clients line names the server client descriptions that 12.8 edits.
- **Suggested prompts** (Story 11.3) are a forward dependency: Epic 11 is dispatched after this epic, and 11.3 owns the retrofit.
- **Epic 14** registers purge as a governed agent tool.
