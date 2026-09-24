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

- **Every editor** is a full-page route on the `form-page` contract, with tabs that mirror the classic editor. It round-trips create, edit and delete, ships with its agent write tool over the derived field list, publishes to the change-event bus, and declares its suggested prompts in its descriptor.
- **Secrets are write-only end to end.** A client secret, a private key or an initial access token is masked, never pre-filled, and never returned by any read, ledger row, diff, screen context or log line. Exclusion is by schema declaration; the name-pattern matcher is only a backstop.
- **12.1:** X.509 details render the certificate and never the private key. The SSL/TLS test (Story 9.5) and the LDAP test (Story 16.14) are **not** built here.
- **12.2 revoke:** runs as the administrator; an agent proposal goes through confirmation and the audit database carries the marked event. The confirmation names the user. The route is `/v2/security/oauth2/server/revoke` with `user` as a required query parameter (the instance's UrlMap); the published spec's `/v2/security/oauth2/revoke` answers 404 on 2026.2.
- **12.3 copy and purge:**
  - Copy runs in the background to a chosen namespace and reports progress.
  - Purge removes records older than N days; its confirmation names the scope and the cut-off. An agent-proposed purge carries the full write model, and its card states that it destroys the record the agent marker lives in.
  - **Purge is screen-only** until Epic 14's governance ships. It is registered as an agent write tool in the same change that adds the policy, and then defaults to disabled as a post-freeze destructive key.
- **12.4:** Discover and Save fetches the issuer's metadata into the form for review before saving. Update JWKS reports its result.
- **12.5 and 12.7:** Rotate Keys reports its result.
- **12.7:** An agent-proposed change to the authorization server's own configuration carries the full write model, and its card states which clients the change affects.
- **12.9:** Each tab's name cell opens OcuPilot's editor and the classic links come off all five tabs. Record SM-C1 back at zero and record the Release 1 risk as closed.
- **New screens pass the structural gate** (accessible names, minimum control widths, no overflow, no page-level horizontal scroll), use design tokens only, and render correctly in the dark theme.

## Technical Decisions

- **Merge: read fresh, apply the diff, send the complete property set (AD-4).** This rule is uniform, whatever an endpoint does with omitted keys.
  - All four `Security.OAuth2.*` endpoints call no merge helper and are presumed to erase omitted fields. Each OAuth story measures its own endpoint's `RunPut` on a throwaway and records the result in AD-4.
  - `Security.X509Credential` also calls no merge helper, but a measurement on 2026-09-24 showed it keeps omitted fields: its `RunPut` sets each field only when the body defines it. AD-4 now records this. It still gets the complete set.
- **Field lists (AD-3).** Derived lists are the wire contract and carry `Metadata` as one opaque object. The published spec (`mainspec_v2.json`) supplies only the `Metadata.*` member sets, 30 to 70 members per editor. `ClientId`, `JWTInterval` and `ServerDefinition` keep the template names. The spec's PUT says `OAuth2ServerDefinition`, but the endpoint rejects unknown keys (verified 2026-09-16). Every derived field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted secret, and a credential-named string field that is not classified secret fails the build.
- **Two write mechanisms, no third.**
  - **Editor Save** resolves through the write tool (AD-55). Creates use AD-54's create kind: the target must be absent, and the fingerprint covers that absence. Save mints no proposal but inherits the prohibited set and the write's validation and fingerprint gates. Read-only mode and the kill switch do not gate a person's Save.
  - **Row and page actions** use AD-53: `POST /screens/:screen/action`, with `screen-action-handler.ts` on the client. The screen's action and the agent's write are one operation. A screen action accepts only the values its tool declares, and a secret travels only under the descriptor's `secretArguments` (AD-56).
  - **Bodyless writes** (revoke, Rotate Keys, Update JWKS) are action-style (AD-51). Each declares its request type and a fingerprint subject covering every precondition field its read answers.
  - (inference) Which mechanism carries each editor-level action button is the story's to settle.
- **Proposals (AD-6, AD-34, AD-40).** Proposals are server-minted, single-use and fingerprinted, and expire after 10 minutes. The confirm channel admits only declared secret fields. Confirm re-checks privileges and the prohibited set in one atomic transition. Agent writes emit the audit marker (AD-15); screen writes do not.
- **Privileges (AD-8).** A tool's pair set is its screen's. Administrative resources are gated at `USE`. The prohibited set refuses only self-protection (AD-10).
- **Descriptors (AD-5, AD-13, AD-14).** The OAuth 2.0 screen is one descriptor per tab (`Screen/Descriptor/OAuth*Tab.cls`), and a tab may declare several entity types. An editor takes side-bar position 0 and is reached from its tab. Ids are percent-encoded in one segment by the shared encoder. Tool names follow `<area>.<screen>.<verb>`, and a tool's identity comes from a stable descriptor identifier.
- **Screen context (AD-24, amended by Story 11.9).** The kernel adds `tools` and `readOnly` to every screen-context payload, derived on the instance. A request that carries either is refused. A form page declares neither a read tool nor row actions, so an editor's `tools` list is empty. Tabs with row actions list their read tool and write tools.
- **Admin API confinement (AD-27).** Only `Port/AdminPort` names `%Api.Admin.*`. A call completed through a vendor class needs a new named AD-27 case.
- **Secrets (AD-35).** A secret never enters a status, an exception, a log line or a temporary file.

## UX & Interaction Patterns

- **Form page:** single column, at most 720px wide, fields at most 480px wide and in classic order. Validation is inline, server-authored and lands on the named field. A failed Save moves focus to the error-summary banner. The sticky 56px action bar has Save as its only primary. Create opens the new entity; edit shows "Saved". The unsaved-changes guard also holds an agent navigation.
- **Tabs:** one form spans all tabs and Save applies everything. A validation error switches to the tab that holds it. An errored tab shows a destructive dot and adds ", N errors" to its accessible name.
- **Deletes and revoke** use a dialog that names the entry and requires the typed name. Dialogs never stack.
- **Existing OAuth labels and empty states** are fixed strings. Reuse them and do not reword them.

## Cross-Story Dependencies

- **Shared tabbed-form component:** `ui/src/app/shell/form-tabs.ts` exists only on `origin/OCU-1-epic9`, not on this branch. Whichever of 9.1 and 12.4 lands first sets it, and the other adopts it at its merge.
- **This epic depends on Epics 6, 7 and 8** (all merged) and runs beside Epic 9.
- **12.9 depends on 12.4 through 12.8.** 12.5 configures a client against a server description from 12.4. 12.7's affected-clients line names the server client descriptions that 12.8 edits.
- **Suggested prompts:** Story 11.3 owns the descriptor contract and is still backlog on this branch, so an editor's prompts wait for that contract.
- **Epic 14** registers purge as a governed agent tool.
