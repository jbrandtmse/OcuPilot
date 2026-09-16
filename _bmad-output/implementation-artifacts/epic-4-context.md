# Epic 4 Context: Ask the agent about the screen you are on

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user on any screen types a question into a docked panel that already knows the screen, namespace,
selection and visible rows, watches the agent read through the same declared reads the screen uses
(in-process, as the user), and gets an answer that names the rows it used, with every model and tool
call recorded in a per-user ledger and nothing on the instance changed. This is the second half of
build step 2 and completes UJ-1 plus the read-only half of UJ-4. It is also a real risk boundary: an
agent that reads and explains but never writes is a complete product that can ship even if Epic 5's
write model slips. The epic opens by putting in place the credential and egress decisions taken at
Epic 3's merge gate, before the first turn sends a stored key anywhere.

## Stories

- Story 4.0: Epic 3 deferred cleanup
- Story 4.1: The turn runs in a background job and returns immediately
- Story 4.2: The tool registry, its one gate point, and the three shell reads
- Story 4.3: The docked panel, present on every route
- Story 4.4: Screen context on every turn, capped, with its toggle and chip
- Story 4.5: A turn, watched: progress cards and the conversation lock
- Story 4.6: Replies render safely and offline
- Story 4.7: The agent takes you to a screen
- Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it
- Story 4.9: The agent audit ledger
- Story 4.10: Home's suggested view and the starter prompts

## Requirements & Constraints

- **Credentials and egress first (4.0).** OcuPilot refuses by name to store a key into a credential
  entry it did not create. Naming an existing entry as a reference is still allowed and writes
  nothing. A store without `%Ens_Credentials:WRITE` gets a named refusal that names the resource to
  grant, never a 500 and never a grant at install time. A stored key goes only to the stored
  endpoint. The proxy host is judged by the same egress policy, and an https endpoint tunnels
  through it with CONNECT. A credential rung that cannot be reached, or that raises, fails with a
  named reason and does **not** disable the definition. A configuration write that disables or
  deletes something else names it in the change record. A delete that removed nothing says so, and
  a test reads back every write verb's audit row. Where `_SYSTEM`'s `%All` would hide a behavior,
  test it under a stripped role.
- **The turn never holds a request open.** `POST` returns a turn id at once and a background job does
  the work. A turn longer than the stock 60-second gateway timeout must complete on an unmodified
  container, and a test proves it. The gateway timeout value is reported as information only. The
  job never changes the instance: it writes only OcuPilot's own state, such as progress records.
- **Every turn is bounded.** Each turn has limits on iterations, wall-clock time and total provider
  tokens. Each user may run one turn at a time, and the instance enforces that. Signing out, or
  deleting the user, abandons their running turns. Between every step the job re-checks that the
  user is still enabled and still holds the privilege the next step needs. It also re-reads
  enforced read-only, the kill switch and its stop flag, and abandons the turn at the next step
  boundary when any of them has changed. Stop is not a new turn and cancels nothing.
- **Progress** lives in protected storage, keyed by turn and owned by the user who started it. It
  is capped in size per turn and is deleted when the turn ends. A poll for someone else's turn
  answers **404, not 403**. The first visible progress appears within 10 s of Send against a
  current cloud model.
- **Tools.** A registry over the tool base discovers every tool with its name, input schema and
  result shape. A tool that declares neither `read` nor `write` fails the build. Three shell reads
  get read tools: the privilege map, the namespace list and instance identity. Navigation tools are
  read tools that run client-side. Every call passes **one** call-time gate point, after the
  caller's identity is resolved and before any port is touched. In Release 1 that gate allows
  everything that is not prohibited. SQL-backed reads bind every value as a parameter, use fixed
  catalog queries only (no free-form SQL) and carry the harvested anti-runaway-query guard.
- **Screen context** is built fresh from the screen the user is on at the moment of Send: route,
  namespace, selected entity, and the visible rows with their active sort and filter. It is capped
  at 200 rows instance-wide (an operator can change the cap), truncated rather than refused, and
  the number actually sent is recorded. The payload is also bounded by total size, and each field
  is cut to a declared maximum with the cut marked. A serializer with an uncapped collection or an
  unbounded field fails review. Fields the descriptor types as secret are **always** excluded, and
  a screen that has any sends only its route and entity identity. The exclusion comes from the
  schema. A name-pattern matcher is only a backstop that can add redaction, never remove it.
  Context sharing is on by default and remembered per user. An OcuPilot administrator can set the
  instance default to off.
- **Replies cannot reach out.** Replies render as sanitized Markdown with code highlighting. The
  renderer, highlighter and sanitizer are vendored in the bundle, and the page loads with no CDN.
  A test asserts that a remote image produces no network request. The bundle is already over its
  500 kB warning with no gate pinning the size, and this pipeline is the next large addition.
- **Provider trouble costs time, not the answer.** A 429 or 5xx is retried with exponential backoff
  up to a bounded count, waiting the greater of the backoff and `Retry-After`. A call that threw
  mid-flight is never retried. A call that exceeds the fixed timeout ends the turn with an error that
  names the step. Every failure reaches the client as a turn error, never as an exception.
- **The ledger** writes one row per LLM call and per tool call: user, ISO-8601 UTC timestamp, screen
  route, tool or provider name, arguments, result status, and token usage where the provider reports
  it. Tool rows also record the IRIS resource the tool required. Redaction is by schema, and
  LLM-call arguments are stored after the screen-context secret exclusion. Rows are limited in rate
  and size per turn, and overflow is recorded as a count. Users see their own rows. An
  administrator's view of another user's rows is gated by the resources recorded on each row, and
  the ledger enforces that gate itself, not a screen. Rows outlive a deleted user.

## Technical Decisions

- **Governing ADs by story.**
  - 4.0: AD-7 (the credential-migration exception), AD-35, AD-37, AD-42.
  - 4.1: AD-7, AD-9, AD-12/AD-39, AD-28, AD-30, AD-31, AD-33, AD-41.
  - 4.2: AD-1, AD-5, AD-8, AD-11, AD-21, AD-22, AD-29, AD-36, AD-39.
  - 4.3: AD-19, AD-20.
  - 4.4: AD-5, AD-24, AD-36, AD-42, AD-48.
  - 4.5: AD-11, AD-19, AD-33, AD-41.
  - 4.6: AD-11, AD-47.
  - 4.7: AD-5, AD-11, AD-13, AD-44.
  - 4.8: AD-32, AD-35, AD-39, AD-42.
  - 4.9: AD-3, AD-9, AD-15, AD-37, AD-41, AD-46.
  - 4.10: AD-36.
  - This epic carries AD-11's invariants 1, 3 and 4.
- **`AgentLoop` is a rewrite, not a port.** iris-session-agent's loop is synchronous and never trims
  its context window. Take its 10-step flow and max-iteration fallback as the design, and run them
  inside the background job. The per-conversation lock is harvested from the same project: an
  exclusive open that returns an identically locked reference from both the new-row and
  existing-row branches, released on every exit path. The panel's lock banner is only the
  affordance; the instance enforces the lock.
- **Job startup ordering (AD-9).** A `JOB` inherits `$USERNAME` and `$ROLES` at spawn and keeps
  them for its whole life. So spawn before any escalated read, or from a frame that has already
  unwound, and take every state read first and pass it in as values. A storage method never calls a
  tool, a port or the provider from inside its escalated frame.
- **Tools run in-process (AD-1).** Tools reach the instance through the ports. No tool makes an
  HTTP call to `/api/admin`, `/api/mgmnt` or `/api/ocupilot`, and no token is used mid-turn.
  Privilege belongs to the calling process and is checked at call time against `(resource,
  permission)` pairs. The full tool set is always advertised. A 403 from a tool is the same 403 a
  screen gets, and it is reported, never retried.
- **Keep the system prompt constant (AD-11).** The system prompt is fixed at build time and nothing
  read at runtime is concatenated into it. Tool results enter only as delimited tool-result content,
  never as the system prompt or the user role. That means 4.1 must decide what precedence a
  definition's `systemPromptOverride` takes. Tool schemas keep the harvested cross-vendor
  JSON-Schema subset verbatim: a top-level object with `additionalProperties:false`, and no `$ref`,
  `oneOf`, `anyOf`, `allOf` or `pattern`.
- **One read serves screen and tool (AD-36).** A tool sees the screen's view, narrowed by the context
  cap and stripped of secret-typed fields. The read is bounded and reports truncation. A per-row
  detail call is allowed where the list is wrong: for example, the task LIST forces `Suspended` to
  false, so read it through `INFO`. The application error log's captured variable tables never
  enter context or tool results; the tool returns summary fields only (AD-48).
- **Provider.** One base with adapters behind it, using Anthropic's message shape and the named SSL
  configuration. The key is fetched at the point of use, cleared before return, and never placed in
  a status, log or trap (AD-35). The chip's "leaves the instance" statement is computed from the
  same configuration the request uses.
- **Errors.** One envelope `{error, reason, code, detail}`: screens render `reason`, tool results
  render `code`, and vendor text is normalized at the port boundary. Handlers never `Write` to the
  response.
- **Routes.** `POST /api/ocupilot/turn` and `GET /api/ocupilot/turn/{id}/progress`. In the router,
  sub-resource routes come before single-segment `:param` routes, and every handler gets an HTTP
  integration test.
- **Stores and schema.** New stores (progress, conversation, ledger) use `Kernel/State`'s save,
  which is conditional on row version and refuses a stale write with `STATE.CONFLICT` 409. A
  `%Persistent` class name, package included, is at most 29 characters. Storage sections are never
  hand-written. `SCHEMAVERSION` moves only when the meaning of a stored row changes.
- **Client.** Zoneless and `OnPush`. Panel and conversation state live in framework-free stores in
  `core/` that components mirror into signals, never in component fields. API paths are absolute
  and go through the one API service. Token refresh runs in the API service's background, so a
  turn that outlives an access token needs nothing from the panel. The CSP allows only the
  instance's own origin, and nothing evaluates fetched text at runtime. Use design tokens only. User
  strings come from `core/strings.ts`, with non-ASCII characters written as `\uXXXX`. Any assertion
  about geometry belongs in the browser runner, because jsdom computes no layout.

## UX & Interaction Patterns

- **Geometry.**
  - The panel is docked right on every route: 400 px by default, never below 320 px, width
    remembered per browser. Content keeps a 640 px minimum.
  - On Home the width is `min(50vw, viewport − rail − 640)`, animated over 120 ms (no animation
    under reduced motion). Leaving Home restores the remembered width.
  - There is no close control. The full-screen toggle fills the app area below the header, makes
    the hidden content `inert`, sets `aria-expanded`, and restores the same width.
  - The resize handle is the shell's only sash: `role="separator"`, vertical, focusable, with
    `aria-valuenow/min/max` in px. Left and Right change the width by 16 px, Escape releases the
    handle, and the grip turns `restrained` at the stop.
  - When space runs short, the side bar collapses first, then the panel shrinks toward 320 px, then
    content scrolls inside its own region. The panel never collapses or overlays, and the page body
    never scrolls horizontally.
- **Anatomy.** From top to bottom:
  - A header with the avatar, "Agent co-pilot", New conversation and Full screen.
  - Banners in this fixed order: kill switch, enforced read-only, "not being marked",
    administrator reminder, lock.
  - The context chip.
  - The transcript: `role="log"`, polite, labeled "Conversation", `tabindex="0"`, newest message at
    the bottom.
  - A footer with the always-present read-only line, the composer ("Message to the agent", growing
    to four lines), Send, and the key-hint caption.

  Ctrl/Cmd+I focuses the composer from anywhere, even mid-turn, except while a dialog or the
  command box is open.
- **During a turn.**
  - Send becomes Stop and keeps focus. The composer stays editable and `aria-disabled`; never
    natively disable or remove a control that holds focus.
  - A second send shows the lock banner, keeps the draft, leaves focus where it is, and does not
    render the refused message.
  - Stop halts the turn at its next step, and the last card reads "Stopped by you at <step>" with
    no body.
  - New conversation is `aria-disabled` with the reason "Stop the turn first".
  - A reload restores the tab's conversation with no running cards. A new tab starts a new
    conversation.
- **Tool-call cards.** Each card is a `<button aria-expanded>` disclosure, added in order. The
  running card is expanded, and a completed card collapses to one line. The status is part of the
  accessible name and updates in place. The body shows the arguments summary and the result on the
  code surface, scrolling after 12 lines. A read card also shows the rows returned and the number
  of context rows sent.
- **Chip.** Reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`. When the host
  is not on a private network it adds the "leaves the instance" pill, with the tooltip "Screen
  context is sent to <host>". Screens with secret-typed fields get a key glyph. With sharing off it
  reads "Screen context off — nothing from this screen is sent." It updates on every route,
  namespace, selection or row change. On a screen with secret fields, a draft that looks like a
  password or key triggers an inline warning with Send anyway and Edit.
- **Replies.** External links are inert, show the full host after the link text, and open only on
  an explicit click. Cited rows appear as `code` text with an offer to select them. A turn error is
  an error banner in the agent's slot: "The turn stopped at <step>: <reason>." A stopped turn is
  not an error.
- **Navigation.** The agent first commits "I'm opening <screen> for <entity> — use Back to return."
  About 1 s later the route changes, and the new heading takes focus and announces "<title> —
  opened by the agent; Back returns". Back returns with the previous selection intact. There is no
  in-app undo.
- **Home.**
  - "Suggested view" sits above the transcript as 32 px lines, each count in `code`.
  - A line appears only once its read exists. The line text is a button separate from "Open ›",
    and it fills the composer without sending.
  - When every count is zero, three starter prompts replace the lines, and the agent-status line
    stays.
  - An empty transcript shows "I'm ready. Ask about this screen, or try one of these." over three
    prompts and the row-selection hint.

## Cross-Story Dependencies

- **Order within the epic.**
  - 4.0 closes before any turn calls a provider.
  - 4.1 (job, progress, lock) and 4.2 (registry, dispatch, gate) are the server base.
  - 4.3's panel hosts 4.4's chip, 4.5's cards, 4.6's replies, 4.7's announcements and 4.10's
    suggested view.
  - 4.5 renders 4.1's progress records.
  - 4.7's navigation tool registers through 4.2.
  - 4.9's ledger records the calls 4.1, 4.2 and 4.8 make.
  - 4.1's test provider seam is the first place a key can be carried from the credential endpoint
    through to a served turn.
- **What this epic needs from earlier epics.**
  - Epic 2: the descriptor-registered read tools and the declared reads (2.3), plus AdminPort.
  - Epic 3: the provider contract, the egress policy, and the switches that 4.1's between-step
    re-reads consult. 4.2's gate point gives the restraint verdict its first real caller.
  - Epic 1: the protected storage, the CSP, the string table, and the audit events registered at
    install.
  - Epic 3's form-page unsaved-changes guard is what may refuse 4.7's navigation.
  - 4.10's lines read the task schedule (2.8), application errors (2.12) and agent status (3.7).
    Its alerts line joins with Story 6.13, so build the block to accept new lines.
- **What later epics build on this one.**
  - Epic 5 threads AD-40's "acting on behalf of the model" marker through this turn job and every
    tool call. It also mints proposals from the turn, adds AD-11's confirmation invariant, and
    makes the panel's proposal states live.
  - Epic 11 replaces plain-text cited rows with citation chips and adds streaming over the same
    polling contract.
  - Epic 14 adds the per-user read-only toggle, turn limits, governance on 4.2's gate point,
    transcripts gated by 4.9's per-row resource, and the seeded-injection test.
- **Ledger entries.** Every ledger entry routed onto a story binds that story: address it there, or
  decline it with a written reason.
