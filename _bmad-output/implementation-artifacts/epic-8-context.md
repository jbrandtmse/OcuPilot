# Epic 8 Context: Create and import

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 5. A user creates the things the six areas administer (a web application, a user, a role with its resource grants, a resource, a device, a wallet secret, an X.509 credential) through medium forms that validate server-side and open the new entity on success. Every one of those writes is also reachable by the agent as a confirmed proposal. Stories 8.1 and 8.2 (done) settled the create write kind, the `form-page` contract, secret-argument handling and privilege-grant refusal that the rest of this epic and Epic 9's editors inherit. At least one create or edit form per area from this step is part of the 2026-09-27 floor. Story 8.9 is the floor's last act, a verification rather than a form.

## Stories

- Story 8.1: Create a web application (done)
- Story 8.2: Create a user (done)
- Story 8.3: Create a role, and manage its resource grants
- Story 8.4: The resource editor
- Story 8.5: X.509 import, edit and delete
- Story 8.6: The wallet secret form
- Story 8.8: The device editor
- Story 8.9: Plain IRIS Community verification

There is no Story 8.7. It moved to Epic 7 as Story 7.11 and took `Security.Audit.Event` with it.

## Requirements & Constraints

- **One form contract.** A full-page route under the locator bar: one column of at most 720px, fields of at most 480px (pinned by a design-token test), fields in **the classic order** (read it from the classic page on the instance), Material outlined fields with the label above and helper text beneath, an asterisk plus a one-line legend for required fields, and a sticky 56px action bar with Save as the one primary and Cancel as a text button.
- **Validation** runs inline on blur and on Save. Every field-level sentence is authored once on the server and travels as `{field, code, reason}` violations. A failed Save moves focus to an error-summary banner with one link per field, sets `aria-invalid` and `aria-describedby`, then focuses the first invalid field. There is no validate-only route. Rule sentences ship with the form's bootstrap read, and a name-in-use check is its own read.
- **Save destinations.** Save on a create route opens the new entity's editor. Leaving with unsaved changes asks first, and an agent navigation waits for the same answer. A save publishes to the change-event bus, so an open list updates without a manual refresh.
- **Every write ships with its agent write tool.** A story is not done when the button works.
- **Secrets are write-only end to end:** the user's password, the X.509 private key and the wallet value. Each is sent once and returned by no read. None appears in a diff, a ledger row, a log line or screen context, and exclusion is by schema declaration, never by name matching. A masked field never pre-fills or echoes. After a save it is empty and captioned that a new value replaces it.
- **Privilege grants are refused on the instance whatever the caller, the screen included:** `%All` or any `%Admin_*` role on a user or role, application roles on a web application, and a resource grant that escalates privilege. The refusal is one caller-neutral sentence (`Prohibited.RoleGrantsAdministrativePrivilege`, code `PRIVILEGEGRANT`), and the same server sentence lands on the Roles field as a violation and pre-marks unavailable roles in the picker. The client holds no copy. These grants stay a classic-portal action in Release 1.
- **No caller-supplied filesystem path.** A WSGI/ASGI create names one directory segment, resolved under `<ManagerDirectory>wsgi/` at call time and contained there (done in 8.2). No other story in this epic accepts a path.
- **Gating.** An administrative resource is required at `USE`, never `WRITE`. A gated screen names the resource it needs. The wallet screen is gated whole.
- **Deletes confirm by name**, and a delete with a blast radius states it first: a role delete warns with the count of its holders. A system resource is listed but not deletable, and the gate says why.
- **Story 8.9** confirms or documents three things on a stock plain IRIS Community image: install falls back to `USER`, the credential ladder offers only the rungs that work there, and `/api/admin` is present at the expected version. Where it fails, the README is corrected. The late-failure risk is accepted.

## Technical Decisions

- **Create is a third write kind (AD-54), beside merge and action-style.** The fresh read inverts: a 404 is the precondition, and a present target refuses the mint. The fingerprint covers the target's **absence** under the entity type's canonical spelling, and confirm refuses if the name was taken after the mint. The payload is composed from the arguments over the derived field list, so every supplied field is a diff row. The absence fingerprint is required even where the vendor refuses duplicates, because some PUTs are silent upserts.
- **The screen's Save and the agent's confirm are two callers of one tool class (AD-55).** The route takes endpoint, request type, settable fields, payload composition and port from the tool, evaluates the prohibited set before any port is touched, and inherits the write's validation and fingerprint gates. It mints no proposal and takes no confirm token. **Enforced read-only and the kill switch do not gate a screen Save.** A screen that composes its own payload is a review failure; the one exception is a self-service action on the user's own account.
- **The prohibited set's per-type field lists are keyed by create versus change.** A field prohibited because it repoints a *serving* object is allowed on a create; a field prohibited by effect stays prohibited on both.
- **A proposal can carry a kernel `consequence` code**, rendered on the card. The unauthenticated web-application create uses it; the form states the same consequence at the field, because the screen has no confirmation dialog.
- **Secret arguments.** Field lists are derived at build time and committed, each field classified `ordinary`, `secret` or `opaque`, an unclassified field emitted secret. A tool can also author a top-level secret field the template lacks (classification `authored`, as 8.2's password), and `secretArguments` accepts it; the Registry and screen-mirror were widened additively for this. 8.5 declares `X509Credential`'s `PrivateKeyPassword` and owns DW-1456 (bind the settable spelling to `Write.FieldRows`' drop).
- **The admin port can wrap a POST body.** `Security.User` is sent as `{User, Password}`, declared through the port's `WRAPPEDTYPES`. Check each new type's wire shape on the instance before assuming a flat body; 8.1 also found `Type` and `Name` refused in the body and some enumerations sent as display strings.
- **Each new entity type adds its own canonical-spelling rule** in the identity layer when it first writes. Entity references carry `(entity type, scope, id)`, with the id percent-encoded in one segment.
- **`Wallet.Secret` publishes no body template.** Its body is `{Type, WalletSecretConfig}`, one list per `Type`, derived from the underlying classes and pinned by a test that fails when the instance disagrees. Its PUT is an upsert that the fresh read and fingerprint guard, with a test. Settle `Usage` and `Secret` on the instance first: the class rows and the published spec disagree.
- **Assume nothing merges.** `Security.User`, `Security.Resource`, `Security.X509Credential` and `Wallet.Secret` do not merge server-side. An edit reads fresh and sends the complete property set. The X.509 edit body carries only `OwnerList`, `CAFile` and `PeerNames`; certificate, key and password travel only in the separate import request.
- **Client.** Pages are zoneless and OnPush, keep state in a store and use design tokens only. Reuse the shared unsaved-changes guard and the error-summary focus sequence. Register a command-bar Create handler tab-scoped, not from a routed page's constructor (NG0100). A form reached from its list's Create declares side-bar position 0. The bundle-size warning threshold is 1185kB.
- **Test discipline.** Run the full ObjectScript sweep on a throwaway brought up after the last edit. Rebuild and redeploy before trusting a browser spec. A denial test uses a purpose-built least-privileged role, never `%Operator`. The cross-file rosters (strings table, navigation, smoke, surface and endpoint coverage) are the story's to update.

## UX & Interaction Patterns

- The resource editor is a dialog, not a route, because three fields do not justify a full-page form. The role grant dialog shows the current and the resulting grant.
- **Masked secret field:** a password input with a labelled show/hide toggle. On a proposal card, the user fills it at confirm and the diff shows dots on both sides.
- "Saved" appears in the sticky bar's caption slot. A change to an entity whose screen is not open raises a toast with an "Open in <screen>" link.
- Every new string goes into the published Fixed strings table and the client string source in the same pass.

## Cross-Story Dependencies

- **Upstream:** Epic 5 (the write model, prohibited set, marker, ledger and change bus), Epic 6 (the lists and descriptors these forms start from and return to), and Epic 3 (the form precedent, unsaved-changes guard and masked field). Stories 8.3 to 8.8 reuse the create kind, tool pattern, form contract, secret handling and privilege-grant sentence from 8.1 and 8.2 instead of re-deriving them. 8.3's Roles and grant fields reuse `PRIVILEGEGRANT` rather than authoring a new sentence.
- **Epic 7 runs concurrently.** It edits the same write-path, router, descriptor and coverage-test files, so reconcile carefully at merge. Story 7.11 owns `Security.Audit.Event`.
- **Open at the merge gate (DW-1502, decision pending):** whether a server-shipped refusal sentence such as `PRIVILEGEGRANT` must also be published in Fixed strings and pinned through Epic 7's `RefusalCopy`, or AD-53 amended to exempt a sentence the client never holds. Decided on the Epic 8 merge-gate sheet after both epics merge; do not pre-empt it in a story.
- **Downstream:** Epic 9's editors extend this contract into tabs and take over `web-applications/list/edit/:id`. Epic 12 needs Epics 7 and 8 merged.
