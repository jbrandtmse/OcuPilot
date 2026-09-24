# Epic 12 Context: The OAuth 2.0 editors and the security-area tests

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Finish the area the contest's task statement names most directly: OAuth setup. Today the OAuth 2.0 screen has five read-only tabs, two deletes, and name cells that link out to the classic portal. This epic replaces the link-outs with five OcuPilot editors that each round-trip create, edit and delete. It also adds the security-area actions: X.509 details, OAuth token revoke, and audit-database copy and purge. The owner's re-sequence of 2026-09-21 ranked this epic first in polish week. It closes the accepted Release 1 risk that "OAuth is lists, views and deletes", and it brings the classic link-out count (SM-C1) back to zero.

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

- **Every editor** is a full-page route on the `form-page` contract, with tabs that mirror the classic editor. It round-trips create, edit and delete, ships with its agent write tool over the derived field list, publishes to the change-event bus, and declares its suggested prompts in its descriptor.
- **Secrets are write-only end to end.** A client secret, a private key or an initial access token is masked, never pre-filled, and never returned by any read, ledger row, diff, screen context or log line.
- **12.1 (done):** X.509 details show the certificate and never the private key. The SSL/TLS test (Story 9.5) and the LDAP test (Story 16.14) are built elsewhere, not here.
- **12.2 (done):** revoke is a Users row action. It runs as the administrator, and an agent proposal needs confirmation and carries the audit marker. The dialog names the user. The route is `/v2/security/oauth2/server/revoke` with a required `user` query parameter; the published spec's `/v2/security/oauth2/revoke` answers 404 on 2026.2.
- **12.3 (done):** copy to a namespace and purge by cut-off date run on the instance in the background, from the Auditing screen's Audit database group. Purge stays unadvertised to the agent; Story 14.2 advertises it with its disabled-by-default policy key and the full write model, whose card says the purge destroys the record the agent's marker lives in.
- **12.4:** Discover and Save fetches the issuer's metadata into the form for review before saving. Update JWKS reports its result.
- **12.5 and 12.7:** Rotate Keys reports its result.
- **12.7:** An agent-proposed change to the authorization server's own configuration carries the full write model, and its card states which clients the change affects.
- **12.9:** Each tab's name cell opens OcuPilot's editor, and the classic links come off all five tabs. Record SM-C1 back at zero, and record the Release 1 risk as closed.
- **New screens pass the structural gate:** accessible names, minimum control widths, no overflow and no page-level horizontal scroll. They use design tokens only and render correctly in the dark theme.

## Technical Decisions

- **Merge: read fresh, apply the diff, send the complete property set (AD-4).** The rule applies to every save in this epic, whatever an endpoint does with omitted keys.
  - All four `Security.OAuth2.*` endpoints call no merge helper. `Security.OAuth2.Client.ServerDefinition` was measured to keep omitted fields, merging `Metadata` member by member (AD-4, Story 12.4); the other three are measured by their own stories on a throwaway and recorded in AD-4.
  - `Security.X509Credential` was measured to keep omitted fields. It still receives the complete set.
- **Field lists (AD-3).** The derived list is the wire contract and carries `Metadata` as one opaque object. The `Metadata.*` member sets are derived from the vendor's `OAuth2.Server.Metadata` class (its generated `ImportJSON` is the endpoint's wire contract), not from `mainspec_v2.json`, which is not vendored.
  - `ClientId`, `JWTInterval` and `ServerDefinition` keep their template names. The spec calls the last one `OAuth2ServerDefinition`, but the endpoint rejects unknown keys.
  - Every field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted as secret. A string field with a credential-like name that is not classified secret fails the build.
- **Two write mechanisms, and no third.**
  - **Editor Save** resolves through the write tool (AD-55). A create uses AD-54: the target must be absent, and the fingerprint covers that absence. Save mints no proposal, but it inherits the prohibited set and the validation and fingerprint gates. Read-only mode and the kill switch do not gate a person's Save.
  - **Row and page actions** use AD-53's `POST /screens/:screen/action`. A screen action accepts only the values its tool declares, and secrets travel only under `secretArguments` (AD-56).
  - **Bodyless writes** (revoke, Rotate Keys, Update JWKS) are action-style (AD-51). Each declares its request type and a fingerprint subject that covers every precondition field its read answers. When a vendor body carries a caller's choice, the tool's port builds it from the tool's declared non-secret arguments, and the tool itself still sends no body. `AuditPort` is the one case today. (inference) Each story decides which mechanism carries its editor-level buttons.
- **Privileges (AD-8).** A tool's pair set is its screen's. Administrative resources are gated at `USE`. A tool may also declare a pair its screen lacks when the vendor endpoint's `ResourcesOR()` names it for that request type, measured on the instance. The mint then refuses a caller without it, by name. This also covers an endpoint the call must go through, such as the poll of its own async result. The cases today are revoke's `%Admin_OAuth2_Registration:USE` and audit copy and purge's `%Admin_Operate:USE`.
- **Audit gaps (AD-15, AD-53).** IRIS records no audit event for a token revoke. For an agent revoke, OcuPilot's marker is the only record. A revoke from the screen leaves no audit row, which AD-53 records as a named gap. Any further operation of this kind must be named in both ADs.
- **Queued writes (AD-26).** The port refuses any mutating request the vendor would queue, except the ones on its `QUEUEDWRITES` list. Today that list holds only the audit `COPY` and `PURGE`. Such a write is awaited within the normal bound. If it runs past the bound, the port answers **started** and never `PORT.TIMEOUT`, so the write is recorded as applied, and both the agent and the screen say it is still running. A test pins that every other queuing type is refused.
- **Unadvertised tools (AD-53).** A tool with `ADVERTISED = 0` is reachable only by its screen's caller. It never appears in the provider tool list, the dispatch lookup or the screen context's `tools`, and a test pins its absence from all three. `security.auditing.purge` is the only such tool.
- **Proposals (AD-6, AD-34, AD-40).** A proposal is minted on the server, used once, fingerprinted, and expires after 10 minutes. The confirm channel admits only declared secret fields. Confirm re-checks privileges and the prohibited set in one atomic transition. Agent writes emit the marker; screen writes do not.
- **Descriptors (AD-5, AD-13, AD-14).** Each OAuth tab has its own descriptor (`Screen/Descriptor/OAuth*Tab.cls`), and a tab may declare several entity types. An editor declares side-bar position 0 and is opened from its tab. Ids are percent-encoded in one path segment by the shared encoder. Tool names follow `<area>.<screen>.<verb>` and come from a stable descriptor identifier.
- **Classic link-outs (AD-44).** The OAuth tabs hold Release 1's only `classicLinkExemption`, declared by all five tab descriptors and counted once. Story 12.9 removes all five declarations.
- **Screen context (AD-24).** The kernel derives `tools` and `readOnly` for every payload, and a request that carries either key is refused. A form page declares neither a read nor row actions, so an editor's `tools` list is empty.
- **Admin API containment (AD-27).** Only `Port/AdminPort` names `%Api.Admin.*`. Completing a call through a vendor class requires a new named AD-27 case. A secret never enters a status, an exception, a log line or a temporary file (AD-35).

## UX & Interaction Patterns

- **Form page:** a single column at most 720px wide, with fields at most 480px wide, in the classic order. Validation is inline, written by the server, and lands on the named field. A failed Save moves focus to the error-summary banner. The sticky 56px action bar has Save as its only primary button. After Save, a create opens the new entity and an edit shows "Saved". The unsaved-changes guard also holds an agent navigation.
- **Tabs:** one form spans all tabs, and Save applies everything. A validation error switches to the tab that holds it. A tab with errors shows a destructive dot and adds ", N errors" to its accessible name.
- **Deletes and revoke** use a dialog that names the entry and requires the typed name. Dialogs never stack.
- **Existing OAuth labels, empty states and delete consequences** are fixed strings, as are the X.509 details, revoke and audit copy and purge copy. Reuse them without rewording.

## Cross-Story Dependencies

- **Shared tabbed form:** `ui/src/app/shell/form-tabs.ts` exists only on `OCU-1-epic9`, not on this branch. Whichever of Stories 9.1 and 12.4 lands first sets it, and the other adopts it at its merge.
- **This epic depends on Epics 6, 7 and 8** (all merged) and runs beside Epic 9.
- **12.9 depends on 12.4 through 12.8.** 12.5 configures a client against a server description from 12.4. 12.7's affected-clients line names the server client descriptions that 12.8 edits.
- **Suggested prompts:** Story 11.3 owns the descriptor contract and is still in the backlog, so each editor's prompts wait for it.
- **Story 14.2** advertises `security.auditing.purge` by removing its `ADVERTISED = 0`. It also delivers purge's disabled-by-default policy key and the agent purge card.
