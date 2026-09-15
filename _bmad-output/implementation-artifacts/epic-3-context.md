# Epic 3 Context: Configure the agent, and hold the switches that restrain it

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An OcuPilot administrator picks a provider, pastes a key, proves the definition works before
enabling it, and from then on holds two switches — the kill switch and enforced read-only — that
restrain or silence the agent instance-wide without any screen losing function. A user with no
agent configured still gets every screen plus a panel showing what a proposal would look like.
Definitions and Switches are ordinary screens that must work **before** any agent does, which is
what makes this epic standalone and a prerequisite for every turn in Epics 4 and 5.

## Stories

- Story 3.0 (done): Epic 2 deferred cleanup
- Story 3.1 (done): Agent definitions, and the rules that keep them honest
- Story 3.2 (done): The provider contract and the Anthropic adapter
- Story 3.3 (done): Credentials resolve at call time, never stored where OcuPilot can show them
- Story 3.4 (done): Test connection
- Story 3.5: The Definition form
- Story 3.6: The first-login gate and the configuration-empty state
- Story 3.7: Switches — the kill switch and enforced read-only
- Story 3.8: Every configuration change is resource-gated and audited

## Requirements & Constraints

- **The definition's schema invariant is an absence**: it carries **no key property at all**.
  Eleven server-side rules plus the XOR credential invariant are enforced on the instance and
  accumulate into one response. Any provider, endpoint or credential change disables the definition
  until Test connection passes again. Exactly one is default; all users see definitions for
  selection, only OcuPilot administrators edit. Retention renders disabled and captioned as not yet
  enforced — a field must not promise what nothing does.
- **Credentials are referenced, never held.** A key entered in the form is written once to the chosen
  store and returned by no API call, ever; only the type and the variable or credential name are
  stored. The environment-variable rung works in any namespace but is not writable from OcuPilot
  (IRIS publishes a getter and no setter), so that save is refused with a code naming the reason; the
  IRIS-credentials rung is offered only where the install namespace is interoperability-enabled.
- **Enforced read-only has exactly one enforcement point, and it is Story 3.7's.** While it — or a
  definition's own read-only flag — is in force, every write tool returns a structured "blocked by
  read-only mode" result, the agent states what it would have changed and on which screen, and **no
  proposal card is minted**. Story 10.4's per-user toggle sits over that gate and adds no second one,
  so cutting build step 7 cannot leave a banner over an agent that still mints proposals. A write in
  flight when the switch flips is abandoned at the next step boundary, never half-applied.
- **The kill switch is off by default.** The agent's initial silence comes from having no enabled
  definition — a distinct state — not a switch someone must find and clear. Turns are refused
  server-side, not merely hidden, and every screen keeps working in both states.
- **Everything here is resource-gated and audited.** Every configuration endpoint checks the
  administrative resource server-side. Every change to a definition, either switch, the
  context-sharing default or the turn limits emits an audit event naming actor, target and old and
  new values, an endpoint change recorded as old and new endpoint specifically. The event types must
  be registered at install or emission silently returns 0 and drops. OcuPilot's own API web
  application carries no application or matching roles, and the installer asserts it.

## Technical Decisions

- **Egress is an allow-list, not a free-text URL.** The endpoint decides where the instance's data
  goes: absolute HTTPS (or a declared local address for the OpenAI-compatible adapter), refused for
  link-local metadata addresses with no escape, refused for loopback or the instance itself unless
  the definition is marked local, private-network hosts allowed outright because local models are
  supported. The same judgement applies at write time and at call time.
- **One provider base, adapters behind one contract**, Anthropic's message shape canonical, so a new
  family is an adapter plus a form entry with no change to the agent loop, tools or screens. TLS uses
  a named SSL configuration the installer creates if absent, identity checking on, never the
  instance's default; proxy settings are configuration. Every call has a bounded timeout and retries
  only on a retryable status, delay = max(provider hint, exponential backoff), bounded count — and
  **a call that threw mid-flight is never retried**, because it may already have been processed. A
  failure is a turn error, never an exception to the client.
- **Secrets never reach a surface OcuPilot itself displays.** OcuPilot renders the instance's error
  log and messages.log, so a key must never enter an exception, status, log line or trap: fetched at
  the point of use, cleared before return, never interpolated into a URL, message or error. That a
  forced provider failure leaves no credential material is a test, not a note.
- **Switch state is instance state in the protected database**, evaluated on the instance at the
  point of effect — in the write path and in the turn loop — never only in the client and never
  cached for a turn's length. The turn re-reads both between every step; confirm re-evaluates them,
  so a proposal minted before a switch cannot be applied after it.

## UX & Interaction Patterns

- **The `form-page` contract** governs the Definition form and Switches: full-page route, single
  column, sticky Save/Cancel bar, validation inline on blur and on Save, an error summary banner
  taking focus on a failed Save with a link per field, `aria-invalid` plus `aria-describedby` with
  the first invalid field focused, and an unsaved-changes guard **agent navigation waits on too**.
  Create opens the new entity's editor; edit stays open showing "Saved", and the first successful
  definition Save also offers "Go to Home".
- **The Definition form inverts the usual field order**: name, provider, model, endpoint, key and
  Test connection above the fold, the numeric limits, prompt override and retention under a
  closed-by-default "Advanced". The key field is write-only and masked — empty after save with the
  published "Stored" caption, a labeled reveal toggle, pastes untrimmed, shape check inline on blur.
- **Two agent-off states must stay distinct.** Unconfigured: the panel names who can configure it
  and renders a **static example proposal card** — the live card's own bar, header, diff rows,
  collapsed disclosure, agent text and Reverse line under the example band, with no countdown, no
  buttons and nothing focusable — above three sentences on privileges, confirmation and the audit
  marker; the context chip is absent, there being no provider or endpoint to name. Kill switch: its
  banner naming who and why, a read-only transcript, and a composer and Send that stay **focusable
  and `aria-disabled`** with the reason, never natively disabled. The read-only footer status line
  shows in **both** states, so the mode is learnable.
- **Gating and the gate.** Definitions and Switches gate their side-bar entries naming the
  administrative resource, while the Agent co-pilot rail item **never** gates — its attention dot,
  whose accessible name states the reason, is the signal. The first-login gate redirects an
  administrator with no enabled definition onto the Definition form under its landing banner, fires
  on every login until one is enabled and never afterwards, and is bypassable; the reminder banner
  then persists in the panel on every screen.

## Cross-Story Dependencies

- 3.5 and 3.6 build on 3.1–3.4; 3.8's gating and audit cover what 3.1, 3.4 and 3.7 write. 3.7 is
  the single enforcement point Epic 4's turn loop and Epic 5's confirm path both read.
- 3.6's example proposal card is the component Story 5.2 makes live — it is written once, and
  retention's disabled field is enabled by Story 14.4, whose task Story 13.1's uninstall hook
  already expects to remove.
- Protected storage, the resource and role, the SSL configuration and registered audit events come
  from Epic 1's installer; 3.8 adds the endpoint-level half of Story 1.3's storage-protection test.
- Each routed ledger entry on a story binds: addressed there, or declined with a written reason.
