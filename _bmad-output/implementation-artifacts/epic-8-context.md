# Epic 8 Context: Create and import

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 5. A user creates the things the six areas administer — a web application, a user, a
role with its resource grants, a resource, a device, a wallet secret, an X.509 credential — through
medium forms that validate server-side and open the new entity on success, and every one of those
writes is also reachable by the agent as a confirmed proposal. This is the first epic whose writes
bring a new entity into existence rather than changing one that is already there, and it is the
first place the `form-page` contract is exercised on a vendor endpoint, so the answers it settles
bind Epic 9's large editors. At least one create or edit form per area from this step is part of
the 2026-09-27 floor. The epic depends on Epics 5 and 6; Story 8.9 is not a form at all but the
floor's last act.

## Stories

- Story 8.1: Create a web application
- Story 8.2: Create a user
- Story 8.3: Create a role, and manage its resource grants
- Story 8.4: The resource editor
- Story 8.5: X.509 import, edit and delete
- Story 8.6: The wallet secret form
- Story 8.8: The device editor
- Story 8.9: Plain IRIS Community verification

There is no Story 8.7: it moved to Epic 7 as Story 7.11 in the 2026-09-16 parallel-run amendment,
and takes `Security.Audit.Event` with it.

## Requirements & Constraints

These apply to every form story in the epic and are not restated per story:

- **One contract for every form.** A full-page route under the locator bar: a single column at most
  720px wide, fields no wider than 480px, fields in **the classic order**, Material outlined fields
  with the label above and helper text beneath, an asterisk plus a one-line legend for required
  fields, and a sticky 56px action bar carrying Save as the one primary, Cancel as a text button,
  and a caption slot for the dirty note or the saved confirmation. The two widths are still an
  assumption: Story 8.1 confirms them against a real field set at the longest label and value, and
  the confirmed figures bind every later form in Epics 8 and 9.
- **Validation is inline on blur and on Save**, with server rules landing on the field they name. A
  failed Save moves focus to an error summary banner listing one link per field, sets
  `aria-invalid` and `aria-describedby`, and then focuses the first invalid field. Every
  field-level sentence is authored once on the server, so a client-authored message is a second
  copy source and is refused; whether a validate-only route exists is Story 8.1's call.
- **Save destinations.** Save on a create route opens the new entity's editor; Save on an edit route
  keeps the form open and shows "Saved" in the sticky bar. Navigating away with unsaved changes
  asks first, and an agent navigation waits for and honours the same answer.
- **Every write ships with its agent write tool** over the same derived field list, and the screen
  and the tool are two callers of one operation — a story is not done when the button works. A save
  publishes to the change-event bus so an open list updates without a manual refresh.
- **Secrets are write-only end to end** — the wallet value, the X.509 private key, a new user's
  password. Sent once, returned by no read, never in a diff, a ledger row, a log line or screen
  context, and excluded by schema declaration rather than by name matching. A masked field never
  pre-fills or echoes, and after a save it is empty and captioned that a new value replaces it.
- **Privilege grants are prohibited in Release 1 through any path.** Granting `%All` or any
  `%Admin_*` role, setting application roles, or adding a role to a resource is refused on the
  instance at the write, whatever the caller; a privileged user may still do through the screen
  what the epic's acceptance criteria say they may. The prohibited set is declared once in the
  kernel and never duplicated into a screen or a descriptor.
- **Gating.** A write tool's pair set is the screen's own declared set, and an administrative
  resource is required at `USE`, never `WRITE` — the built-in `%Admin_*`, `%Service_*` and
  `%Development` resources carry no `WRITE` permission at all. A gated screen stays listed and
  focusable and names the resource it needs; the wallet screen is gated whole on the wallet
  administrative resource.
- **Deletes confirm by name**, in a dialog whose action button is the destructive treatment labelled
  with the verb and target, and a delete with a blast radius says what it is first — deleting a role
  warns with the count of users holding it. A system resource is shown but not deletable, with the
  gate stating that as its reason rather than hiding the control.
- **Story 8.9 is a verification, not a screen:** whether OcuPilot installs on a stock plain IRIS
  Community image with no `HSCUSTOM`, whether the credential ladder offers only the rungs that can
  work there, and whether `/api/admin` is present at the expected version — each either confirmed or
  documented with the README's claim corrected. The late-failure risk is accepted by owner decision.

## Technical Decisions

- **Two write shapes exist today; a create is a third.** The write path knows a merge write (fresh
  read, merge, complete body, fingerprint over the property set) and an action-style write (declared
  request type, no body, fingerprint over a declared subject). A create has no prior target to read
  fresh and no prior state to fingerprint, so the first create story settles that shape once — as a
  spine amendment, not as a per-story workaround — and the rest of the epic follows it (inference,
  from the two kinds the spine names and the write base's own defaults).
- **Field lists are derived at build time from the endpoint's own body-template method** and
  committed as source; they are never transcribed by hand, and nothing derives a schema at runtime.
  Each derived field carries a reviewed per-tool classification — `ordinary`, `secret` or `opaque` —
  and an unclassified field is emitted `secret`, so a classification miss fails the build rather
  than reaching the model. Two wrapper bodies derivation cannot see are authored as secret fields of
  the tool itself: a user create's `{User, Password}` and its change-password body.
- **Two endpoints in this epic publish no body template at all.** The wallet secret's field list is
  derived from the underlying class (one list per secret type) and pinned by a test that fails when
  the instance disagrees. `Wallet.Secret`'s PUT is an **upsert**, so a body sent against a target
  deleted since the read silently creates a stub rather than failing — which is what the fresh read
  plus fingerprint is for, and that path carries its own test.
- **Assume nothing merges.** Most of this epic's endpoints — resource, X.509 credential, wallet
  secret, user — do not merge server-side, so a save reads fresh, applies the diff and sends the
  **complete property set**. The diff is what the user reviews; the payload is the whole object.
  The X.509 edit body is narrower than its import body and they are different requests.
- **Settle the wire shape on the instance before planning a payload.** Where the class-derived rows
  and the published spec disagree — the wallet secret's `Usage` and `Secret` are the known case —
  the instance is authoritative and the disagreement is resolved first, not carried into the form.
- **Every write tool declares its port**, defaulting to the admin port, and the mint's fresh read,
  the confirm's re-read, the prohibited-set evaluation and the write itself all resolve through that
  one declaration. Nothing else about the proposal, fingerprint, atomic transition, audit marker,
  ledger row or change event varies by port.
- **Confirmation is user-originated and atomic.** The agent can reach the minting path and nothing
  else; confirm re-checks privileges and the fingerprint, executes from the stored arguments, burns
  the token and cancels sibling proposals on the same target in one transition. The only keys a
  client may supply at confirm are the fields declared secret-typed for that tool.
- **A create's screen surfaces are descriptor work.** A create form is reached from its list's
  command-bar Create and declares that rather than taking a side-bar position; a descriptor is
  write-capable when it declares a primary or row action, which is what the empty state's agent
  invitation keys off. Entity references crossing any boundary carry `(entity type, scope, id)`,
  the id percent-encoded in exactly one segment, and each entity type's canonical-spelling rule is
  added by the story that first writes that type.
- **Client shape.** The Definition form is the one existing `form-page` precedent — page plus store,
  zoneless, OnPush, tokens only — and the unsaved-changes guard is already a shared store that every
  `form-page` route registers with and that the agent's navigation tool honours. Reuse both rather
  than growing a second answer.
- **Test discipline the epic inherits.** Run the whole ObjectScript sweep on a fresh throwaway
  brought up after the last edit, never a chosen subset; a browser spec reads the deployed bundle,
  so rebuild and redeploy before believing one; a denial test needs a purpose-built least-privileged
  role, never `%Operator`; and a mutation proves nothing until the whole tree is recompiled. The
  cross-file rosters that redden on a file your story did not touch — the navigation roster's
  literal index and count, the smoke class's name list with its indexed arm and loop bound, the
  strings table's set equality — are the story's to update when it adds a screen or a string.

## UX & Interaction Patterns

- **Fields in the classic order**, sections separated with title headings, the column reflowing at
  any width; large editors put sections in tabs (Epic 9's problem, not this one's). A reduced form
  ends with a classic-link card.
- **The resource editor is a dialog, not a route** — three fields is below the threshold a full-page
  form earns.
- **Masked secret field**: a password input with a labelled show/hide toggle, write-only, empty
  after save with the "enter a new value to replace it" caption, and on a proposal card filled by
  the user at confirm with the diff showing dots on both sides.
- **The error summary is a banner in the error treatment** carrying `role="alert"`, taking focus and
  the focus ring after a failed Save, with each entry a text-button-shaped link to its field.
- **Saved confirmation** reads in the sticky bar's caption slot; a change to an entity whose screen
  is not open raises a toast naming the change with an "Open in <screen>" link.
- **Colour never carries meaning alone**, and every string the forms introduce is added to the
  published Fixed strings table and the client string source in the same pass, with values unique
  and reused rather than repeated.

## Cross-Story Dependencies

- **Upstream.** Epic 5 built the whole write model this epic calls into — the server-minted
  proposal, the instance-computed diff, the fingerprint, the single atomic confirm, the prohibited
  set, the audit marker and the ledger — plus the first write tools and the change-event bus and
  toast path. Epic 6 built the lists these forms are reached from and return to, and their
  descriptors, gates and read tools. Epic 3 built the Definition form, the shared unsaved-changes
  guard and the masked secret field.
- **Epic 7 runs concurrently and merges before Epics 9 and 12 become eligible.** It ships the row
  actions, deletes and self-protection refusals over the same lists, so both epics edit the write
  tool base, the registry, descriptors, smoke and navigation tests and the client's core and shell.
  Expect reconciliation at merge, and expect Story 7.11 to own `Security.Audit.Event`.
- **Within this epic.** Story 8.1 is first: it confirms the form widths every later form inherits,
  registers the first real screen-action handler, and decides the validate-only question. Story 8.5
  ships the first non-empty secret-argument declaration, which is what makes the settable-spelling
  drop it arms testable at all. Stories 8.5, 8.6 and 8.8 each finish a screen Epic 6 left read-only.
- **Downstream.** Epic 9's six large editors extend this epic's form contract into tabs, and Epic 12
  depends on both Epic 7 and this epic merging. Anything this epic proves about a vendor endpoint's
  merge behaviour, template absence or upsert semantics is what Epic 9 builds on rather than
  re-deriving.
