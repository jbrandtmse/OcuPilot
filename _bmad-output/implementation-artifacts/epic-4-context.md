# Epic 4 Context: Ask the agent about the screen you are on

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user on any screen asks a docked panel that already knows the screen, namespace, selection and visible
rows. The agent reads through the same declared reads the screen uses, in-process and as the user, and
answers naming the rows it used. Every model and tool call lands in a per-user ledger, and nothing on the
instance changes. This completes build step 2, UJ-1 and the read-only half of UJ-4, and ships on its own
if Epic 5's write model slips. Story 4.0 (done) put Epic 3's merge-gate credential and egress decisions
in place before any turn sends a stored key; Story 4.1 (done) shipped the turn job and its progress store.

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

- **Credential and egress rules now in force. Keep them true.**
  - A stored key goes only to the stored endpoint. A call to a body-supplied endpoint carries the
    body's own key or none, and says which.
  - A proxy is a destination: its host is judged by the same egress policy as the endpoint, and an
    https endpoint tunnels through it with CONNECT, so the proxy never terminates the session that
    carries the key.
  - A key is stored only into an entry OcuPilot created or an unused reference. An entry someone else
    created may be named but is never overwritten; the store is refused by name. A missing
    credential-store privilege is a named refusal naming the resource, and install never grants it.
  - Moving the default marker is a security change, because it selects the endpoint and key a turn uses.
  - An unreadable credential store is transient: it faults `PROVIDER.CREDENTIALSTORE` (503) and leaves
    the definition enabled. Only an absent entry (`PROVIDER.CREDENTIAL`) disables the definition.
- **The turn never holds a request open.** `POST` returns a turn id at once, and a background job does
  the work, past the stock 60-second gateway timeout on an unmodified container. The job never changes
  the instance. It writes only OcuPilot's own state (progress, bookkeeping). A vendor migration triggered
  by reading a credential is not a mutation; reading the vendor's secondary credential global directly
  to avoid it is refused.
- **Every turn is bounded and re-checked.** The limits live in `Kernel.Agent.Limits` until per-user
  settings exist: wall-clock 600 s; iterations the definition's maximum, capped at 100; 500,000 provider
  tokens; poll lease 120 s; a message at most 16,000 characters. One concurrent turn per user, enforced
  on the instance. Before each model call the job re-checks its stop flag, sign-out, the kill switch and
  holds, enforced read-only, the user's current grants (`$SYSTEM.Security.CheckUserPermission`; 0 for
  a deleted user), the lease, time and tokens, and abandons at that boundary when one
  fails. A least-privileged job cannot read its account's enabled flag, and the instance keeps honouring
  a disabled account's token (its access token and `/refresh` keep working), so a disabled account's
  turn is bounded by the wall-clock limit alone. The poll lease bounds a turn nobody is watching: only
  the owner's authenticated polls renew it. The instance never sees a token sign-out, so OcuPilot's
  sign-out first sends `POST /api/ocupilot/turn/abandon`; a session that ends any other way lapses the
  lease. Stop is not a new turn and cancels nothing.
- **Progress** lives in protected storage, keyed by turn, owned by its starter, capped per turn (100
  steps, the rest counted), kept 15 minutes after the turn ends and deleted with it. A poll for another
  user's turn answers 404, not 403. The first visible progress appears within 10 s. Anything from the
  model or a tool renders as data, never markup.
- **Tools.** A registry over the tool base discovers each tool's name, input schema and result shape. A
  tool that declares neither `read` nor `write` fails the build. The privilege map, namespace list and
  instance identity get read tools. Navigation tools are read tools that run client-side and accept only
  registry route ids and entity ids, never a URL. Every call passes one gate point, after identity is
  resolved and before any port; in Release 1 it allows everything not prohibited. SQL-backed reads bind
  every value, use fixed catalog queries only, and carry the anti-runaway-query guard.
- **Screen context** is built fresh at Send: route, namespace, selected entity, visible rows with sort and
  filter. It is capped at 200 rows instance-wide (operator-settable), truncated rather than refused, and
  the count sent is recorded. Total size and each field are bounded too, with cuts marked. Secret-typed
  fields are always excluded, by descriptor schema; a screen with any sends only route and entity
  identity. A name matcher may only add redaction. Sharing is on by default, remembered per user, and an
  administrator can default it off.
- **Replies cannot reach out.** Sanitized Markdown with highlighting, all vendored, no CDN. A remote image
  makes no request, and a test asserts it. The CSP allows only the instance's origin. The bundle is
  already over its 500 kB warning with no size gate.
- **Provider trouble costs time, not the answer.** Retry 429 and 5xx with exponential backoff up to a
  bounded count, waiting the greater of backoff and `Retry-After`. Never retry a call that threw
  mid-flight. A timeout ends the turn with an error naming the step. Every failure reaches the client as
  a turn error.
- **The ledger** writes one row per LLM call and per tool call, and tool rows record the IRIS resource
  required. Redaction is by schema. Rows are bounded in rate and size per turn, with overflow as a
  count. An administrator's view of another user's rows is gated by each row's recorded resources,
  enforced by the ledger. Rows outlive a deleted user.

## Technical Decisions

- **Governing ADs.** 4.2: AD-1, 5, 8, 11, 21, 22, 29, 36, 39. 4.3: AD-19, 20. 4.4: AD-5, 24, 36, 42,
  48. 4.5: AD-11, 19, 33, 41. 4.6: AD-11, 47. 4.7: AD-5, 11, 13, 44. 4.8: AD-32, 35, 39, 42. 4.9: AD-3,
  9, 15, 37, 41, 46. 4.10: AD-36. The epic carries AD-11's invariants 1, 3 and 4.
- **The loop is `Kernel/Agent/Loop`.** It keeps iris-session-agent's 10-step flow and max-iteration
  fallback inside the job, with seams `PortClass()`, `LimitsClass()` and `DispatchTools`. `JOB` appears
  only in `Job.cls`; the checker lets `Kernel/Agent/` name no port but `ProviderPort` and no `Api`,
  `Area` or `Screen` handler. Harvest the per-conversation lock: an exclusive open returning an
  identically locked reference from both branches, released on every exit path.
- **Job startup ordering.** A `JOB` keeps the `$USERNAME` and `$ROLES` it had at spawn. Spawn before any
  escalated read or from an unwound frame, and pass every state read in as values. A storage method never
  calls a tool, port or provider from its escalated frame.
- **Tools run in-process.** No tool makes an HTTP call to `/api/admin`, `/api/mgmnt` or `/api/ocupilot`,
  and no token is used mid-turn. Privilege is the process's, checked at call time against
  `(resource, permission)` pairs. The full tool set is always advertised; a tool's 403 is reported, never
  retried.
- **System prompt is a build-time constant** (`Kernel/Agent/Prompt.Builtin()`). Nothing read at runtime
  is concatenated into it; tool results enter only as delimited tool-result content. A definition's
  `systemPromptOverride` is administrator-written, audited configuration: `ProviderPort.Invoke` sends it
  in place of the built-in prompt whole. Tool schemas keep the harvested cross-vendor subset: top-level
  object, `additionalProperties:false`, no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
- **One read serves screen and tool.** The tool's view is the screen's, narrowed by the context cap and
  stripped of secret fields, bounded, reporting truncation. A declared per-row detail call covers a
  wrong list (the task LIST forces `Suspended` false; use `INFO`). Application-error variable tables
  never reach context or tool results.
- **Provider.** One base, Anthropic's message shape, the named SSL configuration. The key is fetched at
  use, cleared before return, never in a status, log or trap. The chip's "leaves the instance" is
  computed from the same configuration the request uses.
- **Errors.** One envelope `{error, reason, code, detail}`: screens render `reason`, tool results
  `code`; vendor text is normalized at the port. Handlers never `Write` to the response.
- **Routes.** `POST /api/ocupilot/turn`, `GET /api/ocupilot/turn/{id}/progress` and
  `POST /api/ocupilot/turn/abandon` exist. Sub-resource routes precede `:param` routes; every handler has
  an HTTP integration test, matched by whole route and method.
- **Stores.** Progress, conversation and ledger use `Kernel/State`'s row-versioned save (`STATE.CONFLICT`
  409). The turn's slot is a process lock the job holds for its life, and renew, stop and abandon are
  scalar signal nodes, not row fields. `%Persistent` class names, package included, stay within 29
  characters. No hand-written storage. `SCHEMAVERSION` moves only when a stored row's meaning changes.
- **Testing a turn.** `OCUPILOT_ALLOW_TEST_PROVIDER=1` (set by `ci-throwaway.sh`) arms the `turnprobe`
  provider, whose stub records identity, the key's hash and the request across the job boundary. Armed
  classes refuse by name on the live instance.
- **Client.** Zoneless, `OnPush`. Panel and conversation state live in framework-free `core/` stores
  mirrored into signals. Absolute API paths through the one API service, whose background token refresh
  means a long turn needs nothing from the panel. Geometry assertions run in the browser runner.

## UX & Interaction Patterns

- **Panel.** Docked right on every route, 400 px default, 320 px minimum, width remembered per browser;
  content keeps 640 px. No close control. Full screen fills the app area and makes hidden content
  `inert`. The resize handle is the shell's only sash. When space runs short the side bar collapses first,
  then the panel shrinks, then content scrolls in its own region; the panel never overlays and the body
  never scrolls horizontally. On Home the panel widens over 120 ms (none under reduced motion).
- **Order.** Header; banners (kill switch, enforced read-only, "not being marked", administrator
  reminder, lock); context chip; transcript as a polite `role="log"`; footer with the read-only line,
  composer and Send. Ctrl/Cmd+I focuses the composer, even mid-turn.
- **During a turn.** Send becomes Stop and keeps focus. Never natively disable or remove a focused
  control; use `aria-disabled`. A second send shows the lock banner, keeps the draft and renders nothing.
  Tool calls appear as ordered disclosure cards whose status is part of the accessible name.
- **Chip and replies.** The chip names screen, namespace, rows sent, provider and endpoint host, with a
  "leaves the instance" pill for a non-private host. Reply links are inert and show their host. A turn
  error reads "The turn stopped at <step>: <reason>."; a stopped turn is not an error.
- **Navigation.** Announce first, route about 1 s later, focus the new heading. Back restores the prior
  screen and selection; there is no in-app undo.

## Cross-Story Dependencies

- **Within the epic.** 4.1 (job, progress, slot) and 4.2 (registry, dispatch, gate) are the server base.
  4.3's panel hosts 4.4's chip, 4.5's cards, 4.6's replies, 4.7's announcements and 4.10's suggested
  view. 4.7 registers through 4.2. 4.9 records the calls 4.1, 4.2 and 4.8 make.
- **From 4.1.** 4.2 replaces `Loop.DispatchTools`, which answers every `tool_use` with a fixed
  `TOOL.UNAVAILABLE` result, and narrows the per-step grants check from any of the router's admin
  resources (passed in as a value) to per-tool pairs. 4.2 owns DW-250: `AdminPort.Invoke` fails 500 when
  its caller holds a `%SYS.Capture` with buffered output, so a capture around a tool call must be
  released or nested. 4.4 adds context to the POST body. 4.5 renders the progress contract and builds
  Stop on `GuardedRequestStop`; no stop route exists yet. 4.6 and 4.8 consume `reply` and `error`, 4.9
  the step records and usage.
- **From 4.0.** The turn resolves keys through `ProviderPort.Invoke` and keeps `PROVIDER.CREDENTIALSTORE`
  (transient, definition stays enabled) apart from `PROVIDER.CREDENTIAL`. 4.8 reworks the request path
  and owns DW-441: a configured proxy is still applied to a marked-local plain-http endpoint, which then
  goes through the proxy in cleartext.
- **From earlier epics.** Epic 2's descriptor read tools, declared reads and AdminPort. Epic 3's
  provider contract, egress policy and the switches the turn re-reads; 4.2's gate gives the restraint
  verdict its first caller. Epic 1's protected storage, CSP, string table and audit events. Epic 3's
  unsaved-changes guard may refuse 4.7's navigation. 4.10 reads tasks (2.8), application errors (2.12)
  and agent status (3.7); its alerts line joins with 6.13, so the block must accept new lines.
- **Later epics build here.** Epic 5 threads the "acting on behalf of the model" marker through the job
  and tool calls and mints proposals; its confirm plans wait on DW-444 (a disabled account's live
  tokens, decision-pending). Epic 11 adds citation chips and streaming over the same polling contract.
  Epic 14 adds governance on 4.2's gate, per-user turn limits, transcripts gated by 4.9's per-row
  resource, and the seeded-injection test.
- **Ledger entries** routed onto a story bind it: address each there, or decline it with a reason.
