# Epic 4 Context: Ask the agent about the screen you are on

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user on any screen asks a docked panel that already knows the screen, namespace, selection and visible
rows. The agent reads through the same declared reads the screen uses, in-process and as the user, and
answers naming the rows it used. Every model and tool call lands in a per-user ledger, and nothing on the
instance changes. This completes build step 2, UJ-1 and the read-only half of UJ-4, and ships on its own
if Epic 5's write model slips. Done so far: 4.0 (Epic 3's credential and egress decisions), 4.1 (turn job
and progress store), 4.2 (tool advertising, dispatch, the gate point, the three shell reads) and 4.3 (the
docked panel on every route).

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

Processing order after 4.3: 4.4, 4.5, 4.11, 4.6, 4.7, 4.8, 4.9, 4.10.

## Requirements & Constraints

- **Credential and egress rules in force.** A stored key goes only to the stored endpoint; a
  body-supplied endpoint carries the body's key or none. A proxy's host is judged by the same egress
  policy; https tunnels with CONNECT. An unreadable credential store is transient
  (`PROVIDER.CREDENTIALSTORE`, 503, definition stays enabled); only an absent entry
  (`PROVIDER.CREDENTIAL`) disables the definition.
- **The turn never holds a request open.** `POST` returns a turn id at once; a background job does the
  work, past the 60-second gateway timeout, and writes only OcuPilot's own state.
- **Every turn is bounded and re-checked.** `Kernel.Agent.Limits`: wall-clock 600 s; iterations the
  definition's maximum, capped at 100; 500,000 provider tokens; poll lease 120 s; message at most 16,000
  characters; one concurrent turn per user. Before each model call the job re-checks stop flag, sign-out,
  kill switch and holds, enforced read-only, current grants, lease, time and tokens, and abandons on a
  failure. A disabled account's turn is bounded by wall-clock alone. Only the owner's polls renew the
  lease. Sign-out first sends `POST /api/ocupilot/turn/abandon`. Stop is not a new turn.
- **Progress** lives in protected storage, keyed by turn, owned by its starter, capped at 100 steps (rest
  counted), kept 15 minutes after the turn. Another user's turn polls 404. First progress within 10 s.
  Model and tool text renders as data, never markup.
- **Tools.** Navigation tools are client-side read tools accepting only registry route and entity ids,
  never a URL, dispatched like any other. SQL-backed reads bind every value.
- **Screen context** is built by the client fresh at Send (4.11) and accepted by the server (4.4):
  route, namespace, selected entity, and the screen's filtered and sorted view with its sort and filter,
  cut to the row cap. The kernel itself bounds every context payload and every read tool result: row cap
  `contextRowCap` on Switches, 1-1,000, default 200, administrator-gated and audited; 65,536 characters
  total, cut by whole rows from the end; 1,000 characters a field unless the descriptor declares less,
  cut value ending in U+2026. Truncate, never refuse. The payload reports `rowsSent`, `rowsAvailable`,
  `truncated`, `truncatedFields`. The registry refuses a context field declared above the default.
  Secret-typed fields are excluded by descriptor schema; a screen with any sends only route and entity
  identity. Sharing off sends no screen data; the choice is stored per user on the instance, falling back
  to `Switch.ShareContextByDefault`.
- **Status read** of the default definition exposes `provider`, `endpointHost` and `leavesInstance`,
  from the provider port's own resolution: context stays only when the definition is marked local or
  every resolved address is loopback, link-local, RFC 1918 or `fc00::/7`; an unresolvable host leaves.
- **Paste warning (4.11).** Draft starts with `sk-`, `-----BEGIN`, `AKIA`, `ghp_`, `xox` or `AIza`, or
  holds a whitespace-free run of at least 24 characters using three of lower, upper, digit, symbol and
  none of `/ . : ^ (`. Once per draft text; a URL, a dotted class name and a global reference must not
  raise it, each pinned by a test.
- **Replies cannot reach out.** Sanitized Markdown with highlighting, all vendored. A remote image makes
  no request, asserted by a test. The CSP allows only the instance's origin. The bundle is already over
  its 500 kB warning with no size gate.
- **Provider trouble costs time, not the answer.** Retry 429 and 5xx with bounded exponential backoff,
  waiting the greater of backoff and `Retry-After`. Never retry a call that threw mid-flight. A timeout
  ends the turn with an error naming the step.
- **The ledger** writes one row per LLM call and per tool call; tool rows record the IRIS resource
  required. Redaction by schema. Rows bounded in rate and size per turn, overflow counted. An
  administrator's view of another user's rows is gated by each row's recorded resources. Rows outlive a
  deleted user.

## Technical Decisions

- **Governing ADs.** 4.4: AD-5, 11, 24, 36, 42, 48, Conventions › Secrets. 4.5: AD-11, 19, 33, 41.
  4.11: AD-5, 24, 42. 4.6: AD-11, 47. 4.7: AD-5, 11, 13, 44. 4.8: AD-32, 35, 39, 42. 4.9: AD-3, 9, 15,
  37, 41, 46. 4.10: AD-36. The epic carries AD-11's invariants 1, 3 and 4.
- **The loop is `Kernel/Agent/Loop`**, seams `PortClass()` and `LimitsClass()`. `JOB` appears only in
  `Job.cls`; `Kernel/Agent/` names no port but `ProviderPort`, no `Api` or `Area` handler, no `Screen`
  class but `Screen.Tool.Registry`; only `Kernel/Agent/Dispatch` calls `InvokeTool`.
- **Dispatch.** Every registered tool is advertised, in name order; `Loop.AnswerTools` answers one
  `tool_use` at a time: wire name (`TOOL.UNKNOWN`), identity (`TOOL.UNAVAILABLE`), gate
  `Kernel/Governance/Gate.Decide` (`TOOL.DENIED`), restraint for writes, privilege pairs against current
  grants (`AUTH.NOPRIVILEGE`, `detail.failedPair`), arguments (`TOOL.ARGUMENTS`), argument pairs,
  `Registry.InvokeTool`. Results return as bounded `tool_result` content or `{code, detail?}`.
- **Tool names** are dotted and canonical; on the wire dots become underscores. Tools run in-process as
  the job's spawn-time user; a denial is reported, never retried.
- **Prompt and untrusted text.** System prompt is a build-time constant (`Kernel/Agent/Prompt.Builtin()`);
  tool results enter only as delimited tool-result content. Screen context enters as a synthetic
  `screen.context` tool call and result before the user's message, canonical message shape, never
  advertised; a model-issued call with that name is refused as unknown. Tool schemas: top-level object,
  `additionalProperties:false`, no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
- **One read serves screen and tool.** Application-error variable tables never reach context or tool
  results. The chip's "leaves the instance" comes from the status read, so chip and request agree.
- **Secrets backstop.** One case-insensitive name list - suffixes `password`, `passwd`, `pwd`, `secret`,
  `secret64`, `apikey`, `privatekey`, `token`, `credential`; exactly `Key` or `CredentialName` - held by
  the server redactor and the client build-time pattern, pinned equal by a test. It only adds redaction.
- **Errors and routes.** Envelope `{error, reason, code, detail}`: screens render `reason`, tool results
  `code`. `POST /api/ocupilot/turn`, `GET …/turn/{id}/progress`, `POST …/turn/abandon` exist; every
  handler has an HTTP integration test.
- **Stores.** Progress, conversation and ledger use `Kernel/State`'s row-versioned save
  (`STATE.CONFLICT` 409). `%Persistent` class names within 29 characters, package included.
- **Testing a turn.** `OCUPILOT_ALLOW_TEST_PROVIDER=1` (set by `ci-throwaway.sh`) arms the `turnprobe`
  provider; `TurnWireFixture.EnsurePrincipal` makes a least-privileged principal. Armed classes refuse on
  the live instance.
- **Client.** Zoneless, `OnPush`; state in framework-free `core/` stores mirrored into signals. Only
  `core/preferences.ts` touches `localStorage`. Every user-visible string comes from `core/strings.ts`
  and must appear in EXPERIENCE.md. Geometry assertions run in the browser runner against a rebuilt and
  redeployed bundle.

## UX & Interaction Patterns

- **Panel (built).** Docked right, no close control, never overlays. Order: header; banners (kill switch,
  enforced read-only, "not being marked", administrator reminder, lock); context chip; transcript as a
  polite `role="log"` named "Conversation"; footer with read-only line, composer and Send. Ctrl/Cmd+I
  focuses the composer, even mid-turn.
- **During a turn.** Send becomes Stop and keeps focus. Use `aria-disabled`, never native disable on a
  focused control. Only the kill switch or no enabled definition makes the composer unavailable. A
  second send shows the lock banner and keeps the draft. Tool calls are ordered disclosure cards whose
  status is part of the accessible name.
- **Chip (4.11).** `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`, `<N rows>` being
  what the next turn would send; pill "leaves the instance", tooltip "Screen context is sent to <host>";
  key glyph named "Secret fields on this screen are never sent". Switch "Share screen context"; off reads
  "Screen context off — nothing from this screen is sent." Updates on route, namespace, selection or view
  change; absent when no definition is enabled. Paste warning inline above the composer: "This looks like
  a password or key. Send anyway?" with Send anyway (sends the text) and Edit (focus to composer).
  Switches gains "Context rows sent with a turn".
- **Replies.** Links are inert and show their host. A turn error reads "The turn stopped at <step>:
  <reason>."; a stopped turn is not an error.
- **Navigation.** Announce first, route about 1 s later, focus the new heading. Back restores the prior
  screen and selection.
- **Home.** The panel widens over 120 ms (none under reduced motion).

## Cross-Story Dependencies

- **From 4.3.** `ui/src/app/shell/panel.ts` renders empty slots; `core/panel-layout.ts` holds
  `PanelState` (width under `ocupilot.panel.width`, draft, full screen) and pure `resolveLayout(...)`,
  which alone computes side-bar yield, panel width and content scroll. 4.5 wires Send and Stop, the lock
  banner and cards, clears the draft on send, and adds New conversation. 4.11 fills the chip slot. 4.6
  renders replies and 4.7 announcements in the log. 4.10 passes `panel-home`'s width into
  `resolveLayout`. Epic 5 fills "not being marked". Decision-pending: DW-458 (panel cannot widen past
  352 px at 1,280 px after the side bar reopens; affects 4.10) and DW-460 (rail active in full screen).
- **4.4 → 4.5 → 4.11.** 4.4 is server-side: accepts context on the POST, bounds it, injects
  `screen.context`, stores the per-user sharing choice, serves the status read. 4.11 consumes 4.4's
  accepted context and status read and 4.5's Send: it assembles context at Send and adds chip, toggle and
  paste warning.
- **From 4.1.** 4.5 renders the progress contract and builds Stop on `GuardedRequestStop` (no stop route
  yet). 4.6 and 4.8 consume `reply` and `error`, 4.9 the step records and usage.
- **From 4.2.** 4.4 makes `TOOLROWS` the operator's `contextRowCap`, adds per-field cuts, carries the
  screen's namespace as the tools' scope (in a job `Kernel.Scope.Current()` is the job's), and owns
  DW-452 (per-reply tool-result budget in `Loop.AnswerTools`). 4.5 owns DW-451 (a tool step records
  neither rows sent, `truncated` nor the failed pair). 4.7's navigation tools register through the
  registry. 4.9 writes one ledger row per dispatched call with `RequiredPairs`, and owns DW-448
  (`BoundedWhere` has no guarded parameter-array helper, so the ledger's time window has no path).
- **From 4.0.** 4.8 reworks the request path and owns DW-441 (a proxy is still applied to a marked-local
  plain-http endpoint, in cleartext).
- **From earlier epics.** Epic 2's descriptor read tools, declared reads and AdminPort. Epic 3's provider
  contract, egress policy, switches and unsaved-changes guard (may refuse 4.7's navigation). Epic 1's
  protected storage, CSP, string table and audit events. 4.10 reads tasks (2.8), application errors
  (2.12) and agent status (3.7); its alerts line joins with 6.13.
- **Later epics build here.** Epic 5's first write tool passes the restraint branch, threads the
  "acting on behalf of the model" marker through job and `Dispatch`, and waits on DW-444. Epic 11 adds
  citation chips and streaming over the polling contract. Epic 14 adds governance on 4.2's gate, per-user
  turn limits, transcripts gated by 4.9's per-row resource, and the seeded-injection test.
- **Ledger entries** routed onto a story bind it: address each or decline with a reason. DW-456
  (registry-layer classes naming `Kernel` and `Api`) is escalated for the decision sheet.
