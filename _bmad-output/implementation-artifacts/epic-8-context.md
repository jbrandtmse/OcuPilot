# Epic 8 Context: Create and import

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 5. A user creates what the six areas administer through medium forms that validate server-side and open the new entity on success. Stories 8.1 to 8.6 (done) settled the patterns the device editor and Epic 9's editors inherit. At least one create or edit form per area is part of the 2026-09-27 floor; Story 8.9, a verification, is the floor's last act.

## Stories

- Story 8.1: Create a web application (done)
- Story 8.2: Create a user (done)
- Story 8.3: Create a role, and manage its resource grants (done)
- Story 8.4: The resource editor (done)
- Story 8.5: X.509 import, edit and delete (done)
- Story 8.6: The wallet secret form (done)
- Story 8.8: The device editor
- Story 8.9: Plain IRIS Community verification

There is no Story 8.7: it moved to Epic 7 as Story 7.11 with `Security.Audit.Event`.

## Requirements & Constraints

- **One form contract.** A full-page route under the locator bar: one column of at most 720px, fields of at most 480px, fields in **the classic order**, outlined fields with label above and helper text beneath, an asterisk plus one-line legend for required fields, and a sticky 56px action bar with Save as the one primary and Cancel as a text button.
- **Validation** runs inline on blur and on Save. Field sentences are authored once on the server as `{field, code, reason}` violations; a failed Save runs the shared error-summary focus sequence. No validate-only route. Rule sentences ship with the form's bootstrap read, and a name-in-use check is its own read.
- **Save destinations.** Save on a create route opens the new entity's editor. Leaving unsaved changes asks first; an agent navigation waits. A save publishes to the change-event bus, so an open list updates itself.
- **Every write ships with its agent write tool.**
- **Secrets are write-only end to end:** the user's password, the X.509 certificate, private key and key password, and the wallet value. Each is sent once, returned by no read, and absent from diffs, ledger rows, logs and screen context, excluded by schema declaration, never by name matching, and never touches disk. A masked field never pre-fills or echoes; after a save it is empty and captioned that a new value replaces it.
- **Privilege grants are permitted at the strongest confirmation, whatever the caller:** `%All`, an `%Admin_*` role or a role carrying one, an escalating resource grant, a public permission adding a letter on an administrative resource, and a privileged application role go through the one tool, no caller-scoped predicate; an agent proposal confirms by typed name, its diff naming the privilege. The screen shows `privilegedGrantEffect` (or `privilegedGrantEffectUnauthenticated`) at the field while such a grant is selected. **Only OcuPilot's self-protection stays refused**, on create and change alike: application roles on its own web applications (`PROHIBITED.PRIVILEGEGRANT`, server-only) and any public permission on its own resources, `%DB_OCUPILOT` and `OcuPilotAdmin` (`PROHIBITED.OCUPILOTRESOURCE`).
- **No caller-supplied filesystem path.** Only 8.1's WSGI/ASGI create takes one directory segment, contained under `<ManagerDirectory>wsgi/`; the X.509 import takes content.
- **Gating.** An administrative resource is required at `USE`, never `WRITE`; a gated screen names it. The wallet screens are gated whole on `%Admin_Wallet:USE`.
- **Deletes confirm by name**, and a delete with a blast radius states it first. A delete ships as the agent's confirmed tool (`permissions.roles.delete`; `permissions.resources.delete`, which refuses a resource whose vendor `AllowDelete` is false and OcuPilot's own two; agent-only `security.x509.delete`). The wallet ships no delete. The list Delete row actions are Epic 9's.
- **Story 8.8** covers the fields of the classic device page, whose exported source in `irislib/` is the field list; create, edit and delete each reach the list without a refresh, and delete confirms by name.
- **Story 8.9** confirms on stock plain IRIS Community (no `HSCUSTOM`) that install falls back to `USER`, the credential ladder offers the environment-variable rung and does not offer the IRIS-credentials rung, and `/api/admin` is present with its version; a failure is documented and the README corrected.

## Technical Decisions

- **Create is a third write kind (AD-54), beside merge and action-style.** A 404 is the precondition; a present target refuses the mint. The fingerprint covers the target's **absence** under the canonical spelling, and confirm refuses if the name was taken since.
- **The screen's Save and the agent's confirm are two callers of one tool class (AD-55).** The route takes endpoint, fields, payload composition and port from the tool, evaluates the prohibited set before any port is touched, and inherits the write's gates. **Enforced read-only and the kill switch do not gate a screen Save.** A screen composing its own payload is a review failure (self-service on one's own account excepted).
- **The prohibited set is keyed by create versus change.** A field prohibited because it repoints a *serving* object is allowed on a create; one prohibited by effect (OcuPilot's self-protection) stays prohibited on both.
- **A proposal can carry a kernel `consequence` code**, stated at the field: an unauthenticated web-application create, and a privilege grant (minted destructive; `Prohibited.GrantsPrivilegeByEffect` is the one classifier).
- **Secret arguments.** Derived field lists classify each field `ordinary`, `secret` or `opaque` (unclassified emits secret); a tool can author a top-level secret the template lacks (`authored`, as 8.2's password). A secret is required unless its row declares it optional (the X.509 key and key password; the wallet value on update).
- **The admin port can wrap a POST body.** `Security.User` is sent as `{User, Password}` through the port's `WRAPPEDTYPES`. Check each new type's wire shape on the instance first.
- **Each new entity type adds its canonical-spelling rule** to the identity layer when it first writes.
- **Verified writes.** `AdminPort` re-reads after an action-style delete (`VERIFIEDDELETES`) and a `Security.Resource` PUT (`VERIFIEDWRITES`); a mismatch refuses `PORT.NOTAPPLIED`, since the vendor can answer 2xx without applying.
- **Three named port completions (AD-27), no general license.** The port goes through the vendor class only where the admin API refuses or lacks what the class supports, for a named endpoint: the `Security.Resource` PUT with an empty `PublicPermission`, through `Security.Resources`; the `Security.X509Credential` POST, completed from content through `%SYS.X509Credentials`; and the `Wallet.Secret` read, which the admin API lacks, composed by `Port/WalletPort` as `{Type, Usage, RequireTLS, AllowedHosts}` and **never the stored value**. So a value change between propose and confirm is undetectable by design; only those four fields are fingerprinted. Nothing above the port knows; a further case needs its own spine entry.
- **Assume nothing merges (AD-4).** `Security.User` and `Security.X509Credential` erase omitted fields; `Security.Resource` and `Wallet.Secret` keep them. A `Wallet.Secret` PUT is an upsert: with a value it creates an absent name, without one it answers 500; the fresh read plus fingerprint is the guard. Every edit reads fresh and sends the complete property set regardless.
- **Wallet shape (8.6, settled).** Body `{Type, WalletSecretConfig}`, one field list per `Type`, derived from the classes and pinned by a test. `Usage` is a number (HTTP 1, SQL 2, SOAP 4, Custom 8, summed); the value is a string. Only `%Wallet.KeyValue` is created and edited (`security.secrets.create`, `.update`); RSA and symmetric-key secrets open read-only with a line naming the `%Wallet` classes, since 2026.2 has no classic wallet page. Their create and edit is DW-1555 (range-end cleanup).
- **Client.** Reuse the shared unsaved-changes guard and the error-summary focus sequence. Register a command-bar Create handler tab-scoped, never from a routed page's constructor (NG0100). A form opened from its list's Create declares side-bar position 0. The bundle-size warning follows the owner's DW-1166 policy: re-base about 5% above the measured total, `angular.json` and its test pin together; 1600kB is the hard stop.
- **Test discipline.** Sweep on a throwaway started after the last edit; redeploy the bundle before trusting a browser spec. A denial test uses a purpose-built least-privileged role, never `%Operator`. The cross-file rosters are the story's to update. Test key material is generated at run time with openssl; no private-key literal enters the repository.

## UX & Interaction Patterns

- The resource editor is a dialog on the Resources list, not a route: the list's Create and a row's name cell open it, and a create switches it to edit mode in place. The role grant dialog shows the current and the resulting grant.
- **Masked secret field:** a password input with a labelled show/hide toggle. On a proposal card, the user fills it at confirm and the diff shows dots on both sides.
- "Saved" appears in the sticky bar's caption slot. A change to an entity whose screen is not open raises a toast with an "Open in <screen>" link.
- Every new string goes into the published Fixed strings table and the client string source in the same pass, reusing a key whose value and meaning match.

## Cross-Story Dependencies

- **Upstream:** Epic 5 (write model, prohibited set, ledger, change bus), Epic 6 (the lists and descriptors), Epic 3 (form precedent, unsaved-changes guard, masked field). 8.8 reuses the create kind, tool pattern, form contract, verified write and action-style delete from 8.1 to 8.6. 8.5 shipped `security/x509/edit`; 8.6 shipped `security/wallet/secrets/edit`.
- **Epic 7 runs concurrently** over the same write-path, router, descriptor and coverage-test files; reconcile carefully at merge.
- **Open at the merge gate (DW-1502):** whether a server-only refusal sentence such as `PRIVILEGEGRANT` must also be published in Fixed strings via Epic 7's `RefusalCopy`, or AD-53 amended to exempt it. Do not pre-empt it in a story.
- **Downstream:** Epic 9's editors extend this contract into tabs and take over `web-applications/list/edit/:id`; Story 9.3 owns the Roles- and Resources-list Delete row actions (DW-1513, DW-1528) and Story 9.5 the X.509-list row action (DW-1541) and the wallet delete, tool and row action (DW-1556), each on Epic 7's AD-53 row-action route. Epic 12 needs Epics 7 and 8 merged.
