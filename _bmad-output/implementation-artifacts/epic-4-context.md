# Epic 4 Context: Ask the agent about the screen you are on

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user on any screen asks a docked panel that already knows the screen, namespace, selection and visible
rows. The agent reads through the same declared reads the screen uses, in-process and as the user, and
answers naming the rows it used. Every model and tool call lands in a per-user ledger, and nothing on the
instance changes. It completes build step 2, UJ-1 and the read-only half of UJ-4. Done so far: 4.0 (Epic 3's credential and egress decisions), 4.1 (turn job
and progress store), 4.2 (tools, dispatch, the gate point, the shell reads), 4.3 (the docked panel),
4.4 (screen context accepted, bounded and injected server-side) and 4.5 (conversations, the stop route,
richer tool steps, and a watched turn in the panel).

## Stories

- Story 4.0: Epic 3 deferred cleanup
- Story 4.1: The turn runs in a background job and returns immediately
- Story 4.2: The tool registry, its one gate point, and the three shell reads
- Story 4.3: The docked panel, present on every route
- Story 4.4: Screen context reaches the turn, capped and secret-free
- Story 4.5: A turn, watched: progress cards and the conversation lock
- Story 4.6: Replies render safely and offline
- Story 4.7: The agent takes you to a screen
- Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it
- Story 4.9: The agent audit ledger
- Story 4.10: Home's suggested view and the starter prompts
- Story 4.11: The context chip, its toggle and the paste warning
- Story 4.12: Epic 4 burn-down

Processing order after 4.5: 4.11, 4.6, 4.7, 4.8, 4.9, 4.10, 4.12.

## Requirements & Constraints

- **Credential and egress rules in force.** A stored key goes only to the stored endpoint; a
  body-supplied endpoint carries the body's key or none. A proxy's host is judged by the same egress
  policy; https tunnels with CONNECT. An unreadable credential store is transient
  (`PROVIDER.CREDENTIALSTORE`, 503, definition stays enabled); only an absent entry disables it.
- **The turn never holds a request open.** `POST` returns a turn id at once; a background job does the
  work, writes only OcuPilot's own state, and its progress is per-turn state owned by the starter
  (capped at 100 steps, kept 15 minutes, 404 to anyone else, first step within 10 s).
- **Every turn is bounded and re-checked.** `Kernel.Agent.Limits`: wall-clock 600 s; iterations the
  definition's maximum, capped at 100; 500,000 provider tokens; poll lease 120 s; message at most 16,000
  characters; cross-turn history 65,536 characters; one concurrent turn per user. Before each model call
  the job re-checks stop flag, sign-out, kill switch and holds, enforced read-only, current grants,
  lease, time and tokens, and abandons on a failure. A disabled account's turn is bounded by wall-clock
  alone; only the owner's polls renew the lease. Stop is not a new turn.
- **Tools.** Navigation tools are client-side reads taking only registry route and entity ids, never a
  URL; SQL-backed reads bind every value.
- **Screen context** is built by the client fresh at Send (4.11) and already accepted server-side. The
  kernel bounds context and every read tool result (row cap `contextRowCap`, 1-1,000, default 200;
  65,536 characters total; 1,000 a field unless the descriptor declares less). Truncate, never refuse.
  Secret-typed fields are excluded by descriptor; a screen with any sends only route and entity identity.
  Sharing off sends no screen data; the choice is per user, falling back to
  `Switch.ShareContextByDefault`.
- **Status read** answers `provider`, `endpointHost` and `leavesInstance` from the provider port's own
  resolution (local only when marked local or every address is private; an unresolvable host leaves).
- **Paste warning (4.11).** Draft starts with `sk-`, `-----BEGIN`, `AKIA`, `ghp_`, `xox` or `AIza`, or
  holds a whitespace-free run of at least 24 characters using three of lower, upper, digit, symbol and
  none of `/ . : ^ (`. Once per draft text; a URL, a dotted class name and a global reference must not
  raise it.
- **Replies cannot reach out.** Sanitized Markdown with highlighting, all vendored; a remote image makes
  no request, asserted by a test. The CSP allows only the instance's origin, and the bundle is already
  over its 500 kB warning with no size gate.
- **Provider trouble costs time, not the answer.** Retry 429 and 5xx with bounded exponential backoff,
  waiting the greater of backoff and `Retry-After`. Never retry a call that threw mid-flight. A timeout
  ends the turn with an error naming the step.
- **The ledger** writes one row per LLM call and per tool call; tool rows record the IRIS resource
  required. Redaction by schema; rows bounded in rate and size per turn, overflow counted. An
  administrator's view of another user's rows is gated by each row's recorded resources, and rows
  outlive a deleted user.

## Technical Decisions

- **Governing ADs.** 4.11: AD-5, 24, 42. 4.6: AD-11, 47. 4.7: AD-5, 11, 13, 44. 4.8: AD-32, 35, 39, 42.
  4.9: AD-3, 9, 15, 37, 41, 46. 4.10: AD-36. The epic carries AD-11's invariants 1, 3 and 4.
- **The loop is `Kernel/Agent/Loop`**, seams `PortClass()` and `LimitsClass()`. `JOB` appears only in
  `Job.cls`; `Kernel/Agent/` names no port but `ProviderPort`, no `Api` or `Area` handler, no `Screen`
  class but `Screen.Tool.Registry`; only `Dispatch` calls `InvokeTool`.
- **Dispatch.** Every registered tool is advertised, in name order; `Loop.AnswerTools` answers one
  `tool_use` at a time, in order: wire name (`TOOL.UNKNOWN`), identity (`TOOL.UNAVAILABLE`), gate
  `Kernel/Governance/Gate.Decide` (`TOOL.DENIED`), restraint for writes, privilege pairs against current
  grants (`AUTH.NOPRIVILEGE`, `detail.failedPair`), arguments (`TOOL.ARGUMENTS`), `Registry.InvokeTool`.
  Results return as bounded `tool_result` content or `{code, detail?}`, 65,536 characters a reply.
- **Tool names** are dotted and canonical; on the wire dots become underscores. Tools run in-process as
  the job's spawn-time user; a denial is reported, never retried.
- **Prompt and untrusted text.** System prompt is a build-time constant
  (`Kernel/Agent/Prompt.Builtin()`); tool results enter only as delimited tool-result content. Screen
  context enters as a synthetic, never-advertised `screen_context` tool call and result before the user's
  message; a model-issued call with that name is refused as unknown. Tool schemas: top-level object,
  `additionalProperties:false`, no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
- **One read serves screen and tool.** Application-error variable tables never reach context or tool
  results. The chip's "leaves the instance" comes from the status read, so chip and request agree.
- **Secrets backstop.** One case-insensitive list - suffixes `password`, `passwd`, `pwd`, `secret`,
  `secret64`, `apikey`, `privatekey`, `token`, `credential`, plus exactly `Key` or `CredentialName` -
  held by the server redactor and the client pattern, pinned equal by a test. It only adds redaction.
- **Errors and routes.** Envelope `{error, reason, code, detail}`: screens render `reason`, tool results
  `code`. Under `/api/ocupilot`: `POST turn`, `GET turn/{id}/progress`, `POST turn/{id}/stop`,
  `POST turn/abandon`, `POST/GET conversation[/{id}]`, `GET/PUT agent/context`; every handler has an
  HTTP test.
- **Stores.** Progress, conversation and ledger use `Kernel/State`'s row-versioned save
  (`STATE.CONFLICT` 409); `%Persistent` class names stay within 29 characters, package included.
- **Testing a turn.** `OCUPILOT_ALLOW_TEST_PROVIDER=1` (set by `ci-throwaway.sh`) arms the `turnprobe`
  provider; `TurnWireFixture.EnsurePrincipal` makes a least-privileged principal. Armed classes refuse
  on the live instance.
- **Client.** Zoneless, `OnPush`; state in framework-free `core/` stores mirrored into signals. Only
  `core/preferences.ts` touches `localStorage`. Every user-visible string comes from `core/strings.ts`
  and must appear in EXPERIENCE.md; geometry is asserted in the browser runner.

## UX & Interaction Patterns

- **Panel (built).** Docked right, no close control, never overlays: header with New conversation;
  banners (kill switch, enforced read-only, "not being marked", administrator reminder,
  lock); context chip; transcript as a polite `role="log"`; footer with read-only line, composer and
  Send. Ctrl/Cmd+I focuses the composer, even mid-turn. During a turn Send becomes Stop and keeps focus
  while the composer stays focusable and editable under `aria-disabled` - never native disable on a
  focused control; only the kill switch or no enabled definition makes it unavailable.
- **Chip (4.11).** `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`, `<N rows>` being
  what the next turn would send; pill "leaves the instance", tooltip naming the host, key glyph named for
  secret fields never being sent. Switch "Share screen context"; off reads "Screen context off — nothing
  from this screen is sent." Updates on route, namespace, selection or view change; absent with no
  enabled definition. The paste warning sits inline above the composer, offering Send anyway (sends
  the text) and Edit (focus to composer).
- **Replies.** Links are inert and show their host. A turn error reads "The turn stopped at <step>:
  <reason>."; a stopped turn is not an error.
- **Navigation.** Announce first, route about 1 s later, focus the new heading. Back restores the prior
  screen and selection.
- **Home.** The panel widens over 120 ms (none under reduced motion).

## Cross-Story Dependencies

- **From 4.5.** `POST /api/ocupilot/conversation` and `GET …/conversation/:id` exist; `conversationId` is
  required on `POST /turn` (422 `TURN.CONVERSATION.REQUIRED`, 404 for one the caller does not own), and
  `POST /turn/:id/stop` answers `{stopRequested}`. The job holds a per-conversation exclusive lock over
  `Kernel/State/Convo` and `Entry` and appends the turn's entry on every exit path; cross-turn history
  replays message and final reply only, under the AD-24 cap. A tool step carries `target`, an
  arguments summary, `rowsReturned`, `rowsSent`, `truncated`, `reason` and `failedPair`; a step is
  written `running` before its call and settled `failed` if its turn ends while running. The client's
  framework-free `core/turn.ts` store drives Send/Stop, the cards, the lock banner and New conversation,
  and clears on sign-out; the transcript renders every step and reply as data (AD-33). 4.6 swaps
  Markdown into the reply, 4.7 adds announcements to the log, 4.8 owns the error
  banner and a refused Send, 4.9 reads 4.1's step records and usage.
- **From 4.3.** `core/panel-layout.ts` holds `PanelState` (width under `ocupilot.panel.width`, draft,
  full screen) and pure `resolveLayout(...)`, the sole layout computation. 4.11 fills the chip slot, 4.10
  passes `panel-home`'s width into `resolveLayout`, and Epic 5 fills "not being marked".
- **From 4.4.** `POST /api/ocupilot/turn` takes an optional `context`: `route`, `namespace` (must match
  the request's `?ns=` scope, else 422 `TURN.CONTEXT.INVALID`), `entity`, `view` with `rows`, `sort`,
  `direction`, `filter`, `rowsAvailable`. `Screen/Context` projects it by descriptor (`context.fields`,
  `context.secretFields`, `context.maxLength`); `Kernel/Agent/Bound` applies row cap, total and field
  cuts to context and to every rows-shaped read tool result, reporting
  `rowsSent`, `rowsAvailable`, `truncated`, `truncatedFields`. `GET/PUT …/agent/context` answers and
  stores `share`, `shareDefault`, `userChoice`, `contextRowCap`, `provider`, `endpointHost`,
  `leavesInstance` (per-user store `Kernel/State/Sharing`); `contextRowCap` lives on Switches and also
  bounds tool rows. 4.11 assembles that POST shape at Send, on 4.5's Send path, and drives chip and
  toggle from `/agent/context`.
- **From 4.2.** 4.7's navigation tools register through the registry. 4.9 writes one ledger row per
  dispatched call with `RequiredPairs`, and owns DW-448 (`BoundedWhere` has no guarded parameter-array
  helper, so the ledger's time window has no path).
- **From 4.0.** 4.8 reworks the request path and owns DW-441 (a proxy is still applied to a marked-local
  plain-http endpoint, in cleartext).
- **From earlier epics.** Epic 2's descriptor read tools, declared reads and AdminPort; Epic 3's provider
  contract, egress policy, switches and unsaved-changes guard (may refuse 4.7's navigation); Epic 1's
  protected storage, CSP, string table and audit events. 4.10 reads tasks (2.8), application errors
  (2.12) and agent status (3.7); its alerts line joins with 6.13.
- **Later epics build here.** Epic 5's first write tool passes the restraint branch, threads the
  "acting on behalf of the model" marker through job and `Dispatch`, and waits on DW-444. Epic 11 adds
  streaming over the polling contract; Epic 14 adds governance on 4.2's gate, per-user turn limits,
  transcripts gated by 4.9's per-row resource, and the seeded-injection test.
- **Ledger entries** routed onto a story bind it: address each or decline with a reason. 4.8 carries
  DW-1053 (the error banner reads "stopped at :" when the failure names no step) and DW-1054 (a Send
  refused with anything but 409 shows nothing). Open for the owner's decision sheet and the burn-down:
  DW-1052 (no tool output stored, so a card's result block stays empty), DW-1048 (a flaky sign-out
  browser leg that leaves an enabled probe definition behind), DW-458, DW-460 and DW-456.
