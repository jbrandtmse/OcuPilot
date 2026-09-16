# Epic 3 Context: Configure the agent, and hold the switches that restrain it

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An administrator picks a provider, pastes a key, proves the definition works before enabling it,
and from then on holds two switches — the kill switch and enforced read-only — that restrain or
silence the agent instance-wide without any screen losing function, while a user with no agent
configured still gets every screen plus a panel showing what a proposal would look like.
Definitions and Switches are ordinary screens that must work **before** any agent does, which makes
this epic standalone and a prerequisite for every turn in Epics 4 and 5. It opens by closing the
Epic 2 work that epic's burn-down could not finish, and ends by closing its own residue before it
merges — this is the surface that holds secrets, so it does not ship with known holes.

## Stories

- Story 3.0: Epic 2 deferred cleanup
- Story 3.1: Agent definitions, and the rules that keep them honest
- Story 3.2: The provider contract and the Anthropic adapter
- Story 3.3: Credentials resolve at call time and are never stored where OcuPilot can show them
- Story 3.4: Test connection
- Story 3.5: The Definition form
- Story 3.6: The first-login gate and the configuration-empty state
- Story 3.7: Switches — the kill switch and enforced read-only
- Story 3.8: Every configuration change is resource-gated and audited
- Story 3.9: Epic 3 burn-down

## Requirements & Constraints

- **The definition's schema invariant is an absence**: no key property at all. Eleven server-side
  rules and the XOR credential invariant accumulate into one response rather than one violation at a
  time, and any provider, endpoint or credential change disables the definition until Test
  connection passes again — one minimal call on the definition **as edited**, over the path a real
  turn takes, so a TLS fault surfaces at setup. Exactly one definition is default; every user sees
  definitions for selection and only administrators edit them.
- **Credentials are referenced, never held**: only the type and the variable or credential name are
  stored, and no API call ever returns a key. The environment-variable rung resolves in any
  namespace but is not writable from OcuPilot, so that save is refused with a code naming the
  reason; the IRIS-credentials rung needs an interoperability-enabled install namespace.
- **A stored key's lifetime is the definition's.** Deleting a definition removes the secret it
  named, a refused create leaves nothing behind in the secondary store, OcuPilot does not write
  where it cannot later clean up, and clearing one definition's credential never leaves a sibling
  verified against a key it was not tested with.
- **Enforced read-only has exactly one enforcement point, Story 3.7's.** While it or a definition's
  own read-only flag is in force, every write tool returns a structured "blocked by read-only mode"
  result, the agent states what it would have changed and where, **no proposal is minted**, and a
  write in flight is abandoned at the next step boundary rather than half-applied.
- **The kill switch is off by default**, global or per user, carries a reason, refuses turns
  server-side and blocks confirmation of a pending proposal. Every screen keeps working in both
  states, and the unconfigured state stays distinct: it is not a switch anyone has to clear.
- **Every configuration change is resource-gated server-side and audited** — actor, target, old and
  new values, an endpoint change as old and new endpoint. Event types unregistered at install drop
  silently, so registration is part of the contract. No OcuPilot web application carries an
  application role at all, and no application outside the roster carries an OcuPilot role; the only
  matching roles permitted are the purpose-built read-only floor the unauthenticated applications
  need, asserted per application by the installer's own test.
- A promised verification is a test or it is struck with its reason; Epic 2's open one closes as a
  real least-privileged principal observing a port's named 403 over HTTP.

## Technical Decisions

- **Egress is an allow-list, not a free-text URL**: absolute HTTPS, or a declared local address for
  the OpenAI-compatible adapter; link-local metadata refused with no escape; loopback or the
  instance itself only where the definition is marked local and its provider's catalog row admits
  it; private networks allowed outright. One judgment binds write time and call time, and the
  endpoint write is audited as a security change.
- **One provider base, adapters behind one contract**, Anthropic's message shape canonical, so a new
  family is an adapter plus a form entry with no change to the loop, the tools or the screens. TLS
  uses a named SSL configuration the installer creates if absent, identity checking on, never the
  instance's default; proxy is configuration. Calls are timeout-bounded, retry only on a retryable
  status with the delay the greater of the provider's hint and a backoff, and **one that threw
  mid-flight is never retried**. A failure is a turn error, not an exception to the client.
- **Secrets never reach a surface OcuPilot itself displays** — it renders the error log and
  messages.log. The key is fetched at the point of use, cleared before return, and never reaches a
  URL, message, status, log line or trap; a test proves a forced failure leaves none behind.
- **Configuration state is singleton state, and concurrent writers must not silently win.** The
  egress and switch singletons and the definition's verification write all share one shape: a save
  over a stale snapshot is refused rather than taken, so two administrators saving concurrently do
  not lose a write and a definition is never marked verified against values it was not tested with.
- **One envelope, two renderings**: slug, human reason, stable machine code, optional detail — and a
  validation refusal carries that same trio per field, written once on the server. Vendor text is
  normalized at the port boundary. A screen over OcuPilot's own configuration is an **ordinary
  declared read**, resolved against a kernel store's guarded list rather than a port, and otherwise
  bounded and shared between screen and tool like any other.
- **Switch state is instance state in the protected database**, reached only through the privileged
  routine application inside a role frame that spawns nothing and re-enters nothing, and evaluated
  at the point of effect — re-read between steps, never cached for a turn, never only in the client.
- Privilege is the calling process's, checked at call time against declared (resource, permission)
  pairs, a denial naming the pair that failed. References to objects OcuPilot does not own are
  **weak** — scoped identity data, never a foreign key, rendering as "no longer present".

## UX & Interaction Patterns

- **The `form-page` contract** governs both screens: full-page route, one column, sticky Save/Cancel
  bar, validation on blur and on Save, required-field asterisks with a legend, an error summary
  banner that takes focus on a failed Save and links to each invalid field, and an unsaved-changes
  guard **agent navigation waits on too**. Create opens the new editor; edit stays open showing
  "Saved". A refusal names the resource and the action, so each screen needs its own published
  action phrase, not the envelope's generic reason.
- **Surfaces and gating.** Agent co-pilot has exactly two side-bar entries, Definitions and
  Switches, both gated naming the administrative resource; the Definition form is routable but
  declares **no side-bar position**, reached from the Definitions name cell, that list's Create and
  the first-login gate, as every later editor will be. Definitions is the first write-capable list —
  enable, disable and set-default act on the row in place — and Switches adds the kill switch with
  its reason field, enforced read-only, the context-sharing default and a per-user switched-off
  section.
- **The rail item never gates, and its attention dot means exactly two things**: the agent is
  unconfigured, or the kill switch is on. A failed Test connection is deliberately **not** a third,
  because nothing stores one. Its reason reaches **both** the accessible name and the rail tooltip.
- **Three agent-off states stay distinct.** A non-administrator sees a panel naming who can
  configure it; an administrator who left the gate sees a persistent, non-dismissible reminder on
  every screen, having been redirected there on every login until one definition is enabled. Both
  carry the same **static example proposal card** — the live card's anatomy and colors with no
  countdown, no buttons, nothing focusable — over three sentences on privileges, confirmation and
  the audit marker, with no context chip. The kill switch instead shows a banner naming who and why
  over a read-only transcript.
- Throughout, a blocked composer and Send stay focusable and `aria-disabled` with the reason rather
  than natively disabled, the read-only footer line shows in **both** read-only states, the key
  field is write-only (empty after save, reveal toggle, pastes untrimmed), and every user-facing
  literal must already be published.

## Cross-Story Dependencies

- 3.0 closes first; 3.5 and 3.6 build on 3.1–3.4; 3.8's gating and audit cover what 3.1, 3.4 and 3.7
  write; 3.9 closes last and merges the epic. 3.7 is the single enforcement point Epic 4's turn loop
  and Epic 5's confirm path read, and the later per-user read-only toggle sits over that gate rather
  than adding a second one.
- 3.6's example proposal card is the component Story 5.2 makes live, written once; retention renders
  disabled and captioned until Story 14.4 enables it and creates the task Story 13.1's uninstall
  hook expects.
- Switches is the **second** form-page screen and the second set of row actions, so the archetype
  page mapping and action labeling Definitions established must generalize rather than stay keyed to
  that first screen.
- Protected storage, the resource and role, the SSL configuration and registered audit events come
  from Epic 1's installer; 3.8 adds the endpoint-level half of Story 1.3's storage-protection test
  and corrects its role-grant audit claim to the granting run only.
- 3.9 also repairs the gates that let this epic's own defects through — the documentation linter
  that never read these specs, browser list specs asserting accidents of the corpus, and the
  destructive-test guard blind to audit-event registration — so the next epic inherits gates that
  would have caught them.
- Each ledger entry routed onto a story binds: addressed there, or declined with a written reason.
