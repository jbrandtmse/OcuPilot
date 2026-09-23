# Epic 8 Context: Create and import

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 5. A user creates the things the six areas administer (a web application, a user, a role with its resource grants, a resource, a device, a wallet secret, an X.509 credential) through medium forms that validate server-side and open the new entity on success. Every one of those writes is also reachable by the agent as a confirmed proposal. This is the first epic whose writes bring an entity into existence, and Story 8.1 (done) has already settled the create write kind and the `form-page` contract that the rest of this epic and Epic 9's large editors inherit. At least one create or edit form per area from this step is part of the 2026-09-27 floor. Story 8.9 is the floor's last act, a verification rather than a form.

## Stories

- Story 8.1: Create a web application (done)
- Story 8.2: Create a user
- Story 8.3: Create a role, and manage its resource grants
- Story 8.4: The resource editor
- Story 8.5: X.509 import, edit and delete
- Story 8.6: The wallet secret form
- Story 8.8: The device editor
- Story 8.9: Plain IRIS Community verification

There is no Story 8.7. It moved to Epic 7 as Story 7.11 and took `Security.Audit.Event` with it.

## Requirements & Constraints

- **One form contract.** A full-page route under the locator bar: one column of at most 720px, fields of at most 480px (both measured in 8.1 and pinned by a design-token test, so they bind every later form), fields in **the classic order**, Material outlined fields with the label above and helper text beneath, an asterisk plus a one-line legend for required fields, and a sticky 56px action bar with Save as the one primary and Cancel as a text button. The classic order is read from the classic page's own layout on the instance, because no project artifact records it.
- **Validation** runs inline on blur and on Save. Every field-level sentence is authored once on the server and travels as `{field, code, reason}` violations. A failed Save moves focus to an error-summary banner with one link per field, sets `aria-invalid` and `aria-describedby`, then focuses the first invalid field. There is no validate-only route. Rule sentences ship with the form's bootstrap read, and a check for a name already in use is its own read.
- **Save destinations.** Save on a create route opens the new entity's editor. Leaving with unsaved changes asks first, and an agent navigation waits for the same answer. A save publishes to the change-event bus, so an open list updates without a manual refresh.
- **Every write ships with its agent write tool.** A story is not done when the button works.
- **Secrets are write-only end to end:** the new user's password, the X.509 private key and the wallet value. Each is sent once and returned by no read. None appears in a diff, a ledger row, a log line or screen context, and exclusion is by schema declaration, never by name matching. A masked field never pre-fills or echoes. After a save it is empty and captioned that a new value replaces it.
- **Privilege grants are prohibited through the agent in Release 1.** That covers granting `%All` or any `%Admin_*` role, setting application roles, and adding a role to a resource. The prohibition is refused on the instance at the write. A privileged user may still do through the screen what a story's acceptance criteria allow.
- **Gating.** An administrative resource is required at `USE`, never `WRITE`. A gated screen names the resource it needs. The wallet screen is gated whole.
- **Deletes confirm by name**, and a delete with a blast radius states it first: a role delete warns with the count of its holders. A system resource is listed but not deletable, and the gate says why.
- **Story 8.9** confirms or documents three things on a stock plain IRIS Community image: install falls back to `USER`, the credential ladder offers only the rungs that work there, and `/api/admin` is present at the expected version. Where it fails, the README is corrected. The late-failure risk is accepted.

## Technical Decisions

- **Create is a third write kind (AD-54), beside merge and action-style.** A tool declares that it creates its target. It reaches that target through the same declared port, endpoint and read type as the other writes. The fresh read inverts: a 404 is the precondition, and a present target refuses the mint. The fingerprint covers the target's **absence** under the entity type's canonical spelling, and confirm refuses if the name was taken after the mint. The payload is composed from the arguments over the derived field list, so every supplied field is a diff row and the unchanged count is zero. The lock, sibling cancel, marker, ledger row and change event are unchanged. The absence fingerprint is required even where the vendor refuses duplicates itself. `WebApp.App`'s PUT is a silent upsert.
- **The screen's Save and the agent's confirm are two callers of one tool class (AD-55).** The route takes endpoint, request type, settable fields, payload composition and port from the tool. It evaluates the prohibited set before any port is touched. It mints no proposal and takes no confirm token. A screen that composes its own payload is a review failure. The one exception is a self-service action on the user's own account.
- **The prohibited set's per-type field lists are keyed by create versus change.** A field that is prohibited because it repoints a *serving* object is allowed on a create. A field prohibited by effect, such as application roles, stays prohibited on both.
- **Each new entity type adds its own canonical-spelling rule** in the identity layer when it first writes. Entity references carry `(entity type, scope, id)`, with the id percent-encoded in one segment.
- **Field lists are derived at build time and committed.** Each field is classified `ordinary`, `secret` or `opaque`, and an unclassified field is emitted secret. A user create's `{User, Password}` wrapper is authored as the tool's own secret fields. `X509Credential`'s `PrivateKeyPassword` is a template credential field, and 8.5 ships the first non-empty secret-argument declaration.
- **`Wallet.Secret` publishes no body template.** Its body is `{Type, WalletSecretConfig}`, with one list per `Type`, derived from the underlying classes and pinned by a test that fails when the instance disagrees. Its PUT is an upsert, and the fresh read plus fingerprint guards that path, with its own test. Settle `Usage` and `Secret` on the instance before planning the payload, because the class rows and the published spec disagree.
- **Assume nothing merges.** `Security.User`, `Security.Resource`, `Security.X509Credential` and `Wallet.Secret` do not merge server-side. An edit reads fresh and sends the complete property set. The X.509 edit body carries only `OwnerList`, `CAFile` and `PeerNames`. Certificate, key and password travel only in the separate import request.
- **Settle the wire on the instance before guessing.** 8.1 found that `Type` and `Name` are refused in the body and that some enumerations travel as display strings. The next endpoint will have its own surprises.
- **Client.** Pages are zoneless and OnPush, keep state in a store and use design tokens only. Reuse the shared unsaved-changes guard and the error-summary focus sequence. Register a command-bar Create handler tab-scoped, not from a routed page's constructor, which risks an NG0100 error. A form reached from its list's Create declares side-bar position 0.
- **Test discipline.** Run the full ObjectScript sweep on a throwaway brought up after the last edit. Rebuild and redeploy before trusting a browser spec. A denial test uses a purpose-built least-privileged role, never `%Operator`. The cross-file rosters (strings table, navigation, smoke, surface and endpoint coverage) are the story's to update.

## UX & Interaction Patterns

- The resource editor is a dialog, not a route, because three fields do not justify a full-page form. The role grant dialog shows the current and the resulting grant.
- **Masked secret field:** a password input with a labelled show/hide toggle. On a proposal card, the user fills it at confirm and the diff shows dots on both sides.
- "Saved" appears in the sticky bar's caption slot. A change to an entity whose screen is not open raises a toast with an "Open in <screen>" link.
- Every new string goes into the published Fixed strings table and the client string source in the same pass.

## Cross-Story Dependencies

- **Upstream:** Epic 5 (the write model, prohibited set, marker, ledger and change bus), Epic 6 (the lists and descriptors these forms start from and return to), and Epic 3 (the form precedent, unsaved-changes guard and masked field). Stories 8.2 to 8.8 reuse 8.1's create kind, tool pattern and form contract instead of re-deriving them.
- **Epic 7 runs concurrently.** It edits the same write-path, router, descriptor and coverage-test files, so reconcile carefully at merge. Story 7.11 owns `Security.Audit.Event`.
- **Two decisions are pending the owner's Epic 8 merge gate:**
  - Whether read-only and the kill switch also bar a person's own Save. The 8.1 route checks only the prohibited set.
  - Whether a WSGI/ASGI create's caller-supplied `WSGIAppLocation` gets an exception to the no-caller-path rule or is contained under a fixed root.

  Follow the current behaviour until then, and do not re-decide either.
- **Downstream:** Epic 9's editors extend this contract into tabs and take over `web-applications/list/edit/:id`. Epic 12 needs Epics 7 and 8 merged.
