# Epic 3 Context: Configure the agent, and hold the switches that restrain it

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An OcuPilot administrator picks a provider, pastes a key, proves the definition works before
enabling it, and from then on holds two switches — the kill switch and enforced read-only — that
restrain or silence the agent instance-wide without any screen losing function. A user with no
agent configured still gets every screen, plus a panel showing what a proposal would look like.
Definitions and Switches are ordinary screens that must work **before** any agent does, which makes
this epic standalone and a prerequisite for every turn in Epics 4 and 5. It opens by closing the
Epic 2 work that epic's burn-down could not finish.

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

## Requirements & Constraints

- **The definition's schema invariant is an absence**: no key property at all. Eleven server-side
  rules plus the XOR credential invariant accumulate into one response, and any provider, endpoint
  or credential change disables the definition until Test connection passes again — one minimal
  call on the definition as edited, over the path a real turn takes.
- Exactly one definition is default; all users see definitions, only administrators edit; retention
  renders disabled and captioned, since nothing purges until 14.4.
- **Credentials are referenced, never held**: only the type and the variable or credential name are
  stored, and a key is returned by no API call, ever. The environment-variable rung is readable in
  any namespace but not writable from OcuPilot, so that save is refused with a code naming the
  reason; the IRIS-credentials rung needs an interoperability-enabled install namespace.
- **Enforced read-only has exactly one enforcement point, Story 3.7's.** While it or a definition's
  read-only flag is in force, every write tool returns a structured "blocked by read-only mode"
  result, the agent states what it would have changed and where, and **no proposal is minted**;
  Story 10.4's per-user toggle sits over that gate. A write in flight stops at the next step
  boundary.
- **The kill switch is off by default**; initial silence comes from having no enabled definition, a
  distinct state. Turns are refused server-side, and every screen works in both.
- **Every configuration change is resource-gated server-side and audited**, the event naming actor,
  target and old and new values; unregistered event types drop silently. The API web application
  carries no application and no matching roles, the installer asserts that, and the turn endpoint
  refuses a caller holding no `%Admin_*` resource.
- **A promised verification is a test or it is struck** — Epic 2's open one closes as a real
  least-privileged principal observing a port's named refusal over HTTP.

## Technical Decisions

- **Egress is an allow-list, not a free-text URL**: absolute HTTPS, or a declared local address for
  the OpenAI-compatible adapter; link-local metadata refused with no escape; loopback or the
  instance itself refused unless the definition is marked local and its provider's catalog row
  admits it; private networks allowed, because local models are supported. The same judgment binds
  write time and call time.
- **One provider base, adapters behind one contract**, Anthropic's message shape canonical, so a new
  family is an adapter plus a form entry and no change to the loop, the tools or the screens. TLS
  uses a named SSL configuration the installer creates if absent, identity checking on, never the
  instance's default; proxy is configuration. Calls are timeout-bounded and retry only on a
  retryable status, the delay the greater of the provider's hint and a backoff — and **one that
  threw mid-flight is never retried**. A failure is a turn error, not a client exception.
- **One envelope on the wire, two renderings above it**: a coarse slug, human `reason`, a stable
  dotted-uppercase machine `code` always present, and an optional structured detail. A validation
  refusal carries that same pair per field — `{field, code, reason}` — so the screen renders the
  reason on the field named and a tool result renders the code, written once on the server. Vendor
  error text is normalized at the port boundary.
- **A screen over OcuPilot's own configuration is an ordinary declared read**: a declared read names
  either an instance endpoint through a port or OcuPilot's own protected state resolved against a
  kernel store's guarded list — same fields, filter, sort, paging and row cap, one bounded read
  shared by screen and tool.
- **Secrets never reach a surface OcuPilot itself displays** — it renders the error log and
  messages.log. A key is fetched at the point of use, cleared before return, and never enters an
  exception, status, log line, trap, URL or message; a test proves a forced failure leaves none. In
  the UI the matching field is write-only: empty after save, a labeled reveal toggle, pastes
  untrimmed.
- **Switch state is instance state in the protected database**, reached only through the privileged
  routine application inside a `New $ROLES` frame that spawns nothing and re-enters nothing, and
  evaluated at the point of effect — never only in the client, never cached for a turn.
- References to objects OcuPilot does not own are **weak**: scoped identity data, never a foreign
  key, rendering as "no longer present" rather than failing the screen.

## UX & Interaction Patterns

- **The `form-page` contract** governs the Definition form and Switches: full-page route, one column
  no wider than 720px, a sticky Save/Cancel bar, required fields asterisked under a one-line legend
  with `aria-required` carrying the semantics, validation on blur and on Save, an error summary
  banner taking focus on a failed Save with a link per field, `aria-invalid` and `aria-describedby`
  with the first invalid field focused, and an unsaved-changes guard. Create opens the new editor;
  edit stays open showing "Saved".
- **Agent navigation may be refused.** The departing screen answers the guard's question for the
  agent too; the refusal reaches the turn as an ordinary tool result rather than an error, and the
  announced navigation is withdrawn.
- **Surfaces and gating.** Agent co-pilot has exactly two side-bar entries, Definitions and
  Switches, each gated naming the administrative resource; the Definition form is routable but
  declares **no side-bar position**, reached from the Definitions name cell, that list's Create and
  the gate, as every later editor will be — the route table sees every built screen, the side bar,
  command box, Home tile caption, locator bar and rail landing only the listed ones. Definitions is
  the first write-capable list: enable, disable and set-default act on the row in place.
- **The rail item never gates, and its attention dot means exactly two things**: the agent is
  unconfigured, or the kill switch is on. A failed Test connection is deliberately **not** a third,
  because nothing stores one. It is the dark agent accent in both themes, its reason reaches
  **both** its accessible name and the rail tooltip, and it clears when the reason clears.
- **Three agent-off states stay distinct.** A non-administrator sees a panel naming who can
  configure it; an administrator who left the gate sees the persistent, non-dismissible reminder
  banner. Both carry the same **static example proposal card** — the live card's anatomy with no
  countdown, no buttons and nothing focusable — over three sentences on privileges, confirmation
  and the audit marker, with no context chip. The kill switch instead shows a restrained banner
  naming who and why, a read-only transcript, and a composer and Send left **focusable and
  `aria-disabled`**. The read-only footer line shows in **every** state, and every user-facing
  literal must already be published.
- **The first-login gate** lands an administrator with no enabled definition on the Definition form
  under its own banner, fires on every login until one is enabled and never afterwards, and is
  bypassable into the persistent panel reminder.

## Cross-Story Dependencies

- 3.5 and 3.6 build on 3.1–3.4; 3.8's gating and audit cover what 3.1, 3.4 and 3.7 write. 3.7 is the
  single enforcement point Epic 4's turn loop and Epic 5's confirm path both read.
- 3.6's example proposal card is the component Story 5.2 makes live, written once; retention's
  disabled field is enabled by Story 14.4, whose task Story 13.1's uninstall hook expects.
- Switches is the **second** form-page screen and the second set of row actions, so the archetype
  page mapping and action labeling Definitions established must generalize rather than stay keyed
  to that first screen.
- Protected storage, the resource and role, the SSL configuration and registered audit events come
  from Epic 1's installer; 3.8 adds the endpoint-level half of Story 1.3's storage-protection test.
- Each routed ledger entry on a story binds: addressed there, or declined with a written reason.
