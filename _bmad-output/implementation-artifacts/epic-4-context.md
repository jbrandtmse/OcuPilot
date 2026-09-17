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
- Story 4.4: Screen context on every turn, capped, with its toggle and chip
- Story 4.5: A turn, watched: progress cards and the conversation lock
- Story 4.6: Replies render safely and offline
- Story 4.7: The agent takes you to a screen
- Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it
- Story 4.9: The agent audit ledger
- Story 4.10: Home's suggested view and the starter prompts

## Requirements & Constraints

- **Credential and egress rules in force.** A stored key goes only to the stored endpoint; a
  body-supplied endpoint carries the body's key or none. A proxy's host is judged by the same egress
  policy, and https tunnels through it with CONNECT. An unreadable credential store is transient
  (`PROVIDER.CREDENTIALSTORE`, 503, definition stays enabled); only an absent entry
  (`PROVIDER.CREDENTIAL`) disables the definition.
- **The turn never holds a request open.** `POST` returns a turn id at once, and a background job does
  the work, past the stock 60-second gateway timeout. The job never changes the instance; it writes only
  OcuPilot's own state.
- **Every turn is bounded and re-checked.** Limits live in `Kernel.Agent.Limits`: wall-clock 600 s;
  iterations the definition's maximum, capped at 100; 500,000 provider tokens; poll lease 120 s; a
  message at most 16,000 characters; one concurrent turn per user, enforced on the instance. Before each
  model call the job re-checks its stop flag, sign-out, kill switch and holds, enforced read-only, the
  user's current grants, the lease, time and tokens, and abandons there when one fails. A disabled
  account's token keeps working, so its turn is bounded by wall-clock alone. Only the owner's
  authenticated polls renew the lease. OcuPilot's sign-out first sends `POST /api/ocupilot/turn/abandon`.
  Stop is not a new turn and cancels nothing.
- **Progress** lives in protected storage, keyed by turn, owned by its starter, capped per turn (100
  steps, the rest counted), kept 15 minutes after the turn ends. Another user's turn polls 404, not 403.
  The first visible progress appears within 10 s. Anything from the model or a tool renders as data,
  never markup.
- **Tools.** Navigation tools are read tools that run client-side and accept only registry route ids and
  entity ids, never a URL. They register like any other tool and pass the same dispatch. SQL-backed reads
  bind every value and use call-site literal text.
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

- **Governing ADs.** 4.4: AD-5, 24, 36, 42, 48. 4.5: AD-11, 19, 33, 41. 4.6: AD-11, 47. 4.7: AD-5, 11,
  13, 44. 4.8: AD-32, 35, 39, 42. 4.9: AD-3, 9, 15, 37, 41, 46. 4.10: AD-36. The epic carries AD-11's
  invariants 1, 3 and 4.
- **The loop is `Kernel/Agent/Loop`**, with seams `PortClass()` and `LimitsClass()`. `JOB` appears only
  in `Job.cls`; the checker lets `Kernel/Agent/` name no port but `ProviderPort`, no `Api` or `Area`
  handler, and no `Screen` class but `Screen.Tool.Registry`, and only `Kernel/Agent/Dispatch` calls
  `InvokeTool`.
- **Dispatch.** Every turn advertises every registered tool, in name order. `Loop.AnswerTools` answers
  one `tool_use` at a time. Each call goes: wire name (`TOOL.UNKNOWN`), identity (`TOOL.UNAVAILABLE`),
  the one gate point `Kernel/Governance/Gate.Decide` (`TOOL.DENIED`), the restraint verdict for write
  tools, privilege pairs against current grants (`AUTH.NOPRIVILEGE` with `detail.failedPair`), argument
  validation (`TOOL.ARGUMENTS`), argument pairs, then `Registry.InvokeTool`. A result goes back only as
  `tool_result` content capped at `Limits.TOOLROWS` (200) rows and `TOOLRESULTMAXLENGTH` (65,536)
  characters with `truncated`, or `{code, detail?}`.
- **Tool names** are dotted and canonical wherever stored or shown; on the wire each dot becomes an
  underscore. A `JOB` keeps its spawn-time `$USERNAME` and `$ROLES`, so pairs are checked against
  current grants. Tools run in-process: no HTTP call, no token mid-turn; a denial is reported, never
  retried.
- **System prompt is a build-time constant** (`Kernel/Agent/Prompt.Builtin()`); tool results enter only
  as delimited tool-result content. Tool schemas keep the cross-vendor subset: top-level object,
  `additionalProperties:false`, no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`.
- **One read serves screen and tool.** Application-error variable tables never reach context or tool
  results. The chip's "leaves the instance" is computed from the same configuration the request uses.
- **Errors and routes.** One envelope `{error, reason, code, detail}`: screens render `reason`, tool
  results `code`. `POST /api/ocupilot/turn`, `GET …/turn/{id}/progress` and `POST …/turn/abandon` exist;
  every handler has an HTTP integration test, matched by whole route and method.
- **Stores.** Progress, conversation and ledger use `Kernel/State`'s row-versioned save (`STATE.CONFLICT`
  409). `%Persistent` class names stay within 29 characters, package included.
- **Testing a turn.** `OCUPILOT_ALLOW_TEST_PROVIDER=1` (set by `ci-throwaway.sh`) arms the `turnprobe`
  provider; `TurnWireFixture.EnsurePrincipal` makes a least-privileged browser principal. Armed classes
  refuse on the live instance.
- **Client.** Zoneless, `OnPush`. State lives in framework-free `core/` stores mirrored into signals;
  components hold none. Only `core/preferences.ts` touches `localStorage`, through an allow-list. Every
  user-visible string comes from `core/strings.ts` and must appear in EXPERIENCE.md. Absolute API paths
  through the one API service. Geometry assertions run in the browser runner, against a rebuilt and
  redeployed bundle.

## UX & Interaction Patterns

- **Panel (built).** Docked right on every route, no close control, never overlays. Order: header;
  banners (kill switch, enforced read-only, "not being marked", administrator reminder, lock); context
  chip; transcript as a polite `role="log"` named "Conversation"; footer with the read-only line,
  composer and Send. Ctrl/Cmd+I focuses the composer, even mid-turn.
- **During a turn.** Send becomes Stop and keeps focus. Never natively disable or remove a focused
  control; use `aria-disabled`. Only the kill switch or no enabled definition makes the composer
  unavailable; enforced read-only restrains only the footer line. A second send shows the lock banner,
  keeps the draft and renders nothing. Tool calls appear as ordered disclosure cards whose status is
  part of the accessible name.
- **Chip and replies.** The chip names screen, namespace, rows sent, provider and endpoint host, with a
  "leaves the instance" pill for a non-private host. Reply links are inert and show their host. A turn
  error reads "The turn stopped at <step>: <reason>."; a stopped turn is not an error.
- **Navigation.** Announce first, route about 1 s later, focus the new heading. Back restores the prior
  screen and selection; there is no in-app undo.
- **Home.** The panel widens over 120 ms (none under reduced motion).

## Cross-Story Dependencies

- **From 4.3.** `ui/src/app/shell/panel.ts` renders the anatomy with empty slots; `core/panel-layout.ts`
  holds `PanelState` (remembered width under `ocupilot.panel.width`, draft text, full screen) and the
  pure `resolveLayout({viewport, sideBarPreferred, sideBarReopened, remembered, fullScreen})`, which
  alone computes side-bar yield, panel width and content scroll (no width media queries). Full screen
  makes side bar and content `inert`. 4.4 fills the chip slot, reading route and selection beside the
  panel. 4.5 wires Send (still `aria-disabled` with no reason) and Stop, fills the lock banner slot and
  the log with cards, clears the `PanelState` draft on send, and adds New conversation. 4.6 renders
  replies and 4.7 its announcements in the log region. 4.10 passes `panel-home`'s target width into
  `resolveLayout` on Home. Epic 5 fills the "not being marked" slot. Decision-pending: DW-458 (the panel
  cannot widen past 352 px at 1,280 px once the user reopens the side bar; 4.10's `panel-home` input
  depends on the choice) and DW-460 (the rail stays active in full screen and acts on the covered side
  bar).
- **From 4.1.** 4.4 adds context to the POST body. 4.5 renders the progress contract and builds Stop on
  `GuardedRequestStop`; no stop route exists yet. 4.6 and 4.8 consume `reply` and `error`, 4.9 the step
  records and usage.
- **From 4.2.** 4.4 makes `TOOLROWS` the operator's context cap, adds per-field cuts, carries the screen's
  namespace as the tools' scope (in a job `Kernel.Scope.Current()` is the job's), and owns DW-452: a
  per-reply tool-result budget in `Loop.AnswerTools`. 4.5 shows tool steps by dotted name and code, and
  owns DW-451: a tool step records neither rows sent nor `truncated` nor the failed pair. 4.7's
  navigation tools register through the registry. 4.9 writes one ledger row per dispatched call with
  `RequiredPairs` as the resource required, and owns DW-448: `BoundedWhere` has no guarded helper that
  runs its fragment with a parameter array, so the ledger view's time window has no path yet.
- **From 4.0.** 4.8 reworks the request path and owns DW-441: a configured proxy is still applied to a
  marked-local plain-http endpoint, which then goes through the proxy in cleartext.
- **From earlier epics.** Epic 2's descriptor read tools, declared reads and AdminPort. Epic 3's
  provider contract, egress policy and the switches the turn re-reads. Epic 1's protected storage, CSP,
  string table and audit events. Epic 3's unsaved-changes guard may refuse 4.7's navigation. 4.10 reads
  tasks (2.8), application errors (2.12) and agent status (3.7); its alerts line joins with 6.13, so the
  block must accept new lines.
- **Later epics build here.** Epic 5's first write tool passes the restraint branch and restates the
  built-in prompt's "change nothing" sentence; it threads the "acting on behalf of the model" marker
  through the job and `Dispatch` and mints proposals; its confirm plans wait on DW-444. Epic 11 adds
  citation chips and streaming over the same polling contract. Epic 14 adds governance on 4.2's gate,
  per-user turn limits, transcripts gated by 4.9's per-row resource, and the seeded-injection test.
- **Ledger entries** routed onto a story bind it: address each there, or decline it with a reason.
  DW-456 (registry-layer classes naming `Kernel` and `Api` classes against the direction line) is
  escalated for the decision sheet.
