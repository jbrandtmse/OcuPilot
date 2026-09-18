# Epic 4 Context: Ask the agent about the screen you are on

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user on any screen asks a docked panel that already knows the screen, namespace, selection and visible
rows. The agent reads through the same declared reads the screen uses, in-process and as the user, and
answers naming the rows it used. Every model and tool call lands in a per-user ledger, and nothing on the
instance changes. It completes build step 2, UJ-1 and the read-only half of UJ-4. Shipped: the turn job
and its progress, the tool registry with its one gate point, the panel, bounded screen context,
conversations and the watched turn, the context chip, safe offline replies, and the agent's navigation.

## Stories

Shipped, in the order they ran: 4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.11, 4.6, 4.7. Remaining, in order:

- Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it
- Story 4.9: The agent audit ledger
- Story 4.10: Home's suggested view and the starter prompts
- Story 4.12: Epic 4 burn-down

## Requirements & Constraints

- **Provider trouble costs time, not the answer (4.8).** Retry 429 and 5xx with bounded exponential
  backoff, waiting the greater of backoff and `Retry-After`. Never retry a call that threw mid-flight or
  timed out. A timeout ends the turn with an error card naming **which step**; any provider failure is a
  turn error, never an exception reaching the client. The installer's Web Gateway response-timeout report
  is information, never a prerequisite.
- **The ledger (4.9)** writes one row per LLM call and per tool call: user, ISO-8601 UTC timestamp, the
  screen-context route, tool or provider name, arguments, result status, and token usage where reported.
  A tool row also records **the IRIS resource the tool required**. Redaction is by schema — each tool
  schema marks its secret fields and the writer drops them by declaration; LLM arguments pass screen
  context's own exclusion; the name pattern only adds. Rows are bounded in rate and size per turn,
  overflow a count. OcuPilot's audit event types are registered in `%SYS` at install. A user sees their
  own rows; an administrator's view of another's is gated by the resources recorded **on the row**, and
  that gate lives with the ledger, not a screen. Rows outlive a deleted user, whose sessions are
  invalidated and running turns abandoned.
- **Home's suggested view (4.10).** A "Suggested view" block above the transcript, each attention line a
  32px row with its count in `code`, its text a button distinct from its "Open ›" link; activating a line
  puts that text in the composer for the user to send. A line appears only when its read exists: tasks
  suspended after an error (2.8), application errors today per namespace (2.12), agent status (3.7); the
  alerts.log line joins at 6.13, so the block takes lines rather than being rewritten. All zero shows the
  three starter prompts instead, same gesture, agent-status line kept; an empty transcript shows the
  greeting, those prompts and the selection hint. The panel widens to `{spacing.panel-home}` over 120 ms
  (none under reduced motion), restoring the remembered width off Home.
- **The turn never holds a request open.** `POST` returns a turn id at once; the job writes only
  OcuPilot's own state, and progress is owned by the starter (100 steps, 15 minutes, 404 to anyone else).
- **Every turn is bounded and re-checked.** `Kernel/Agent/Limits`: wall-clock 600 s; iterations the
  definition's maximum capped at 100; 500,000 tokens; lease 120 s; message 16,000 characters; history
  65,536; one concurrent turn per user; `NAVWAITSECONDS` 60. Before each model call, and on every pass of
  a client wait, the job re-checks stop flag, sign-out, kill switch, holds, enforced read-only, current
  grants, lease, time and tokens, and abandons on a failure. Only the owner's polls renew the lease.
- **Credential and egress rules in force.** A stored key goes only to the stored endpoint; a
  body-supplied endpoint carries the body's key or none. A proxy's host is judged by the same egress
  policy and an https endpoint tunnels with CONNECT. An unreadable credential store is transient
  (`PROVIDER.CREDENTIALSTORE`, 503); only an absent entry disables a definition.
- **Context and read results stay bounded** by `Kernel/Agent/Bound`: `contextRowCap` (1–1,000, default
  200), 65,536 characters total, 1,000 a field unless the descriptor declares less — truncate, never
  refuse, with secret-typed fields excluded by descriptor.

## Technical Decisions

- **Governing ADs.** 4.8: AD-32, 35, 39, 42. 4.9: AD-3, 9, 15, 37, 41, 46. 4.10: AD-36, plus AD-43's
  Home width (DESIGN.md `:1135`). The epic carries AD-11's invariants 1, 3 and 4.
- **The loop is `Kernel/Agent/Loop`**, seams `PortClass()` and `LimitsClass()`. `JOB` appears only in
  `Job.cls`; `Kernel/Agent/` names no port but `ProviderPort` and no `Screen` class but
  `Screen.Tool.Registry`; only `Dispatch` calls `InvokeTool`.
- **Dispatch.** Every registered tool is advertised, in name order; `Loop.AnswerTools` answers one
  `tool_use` at a time, stopping at the first refusal: wire name (`TOOL.UNKNOWN`), identity
  (`TOOL.UNAVAILABLE`), gate (`TOOL.DENIED`), restraint for writes, declared pairs against current grants
  (`AUTH.NOPRIVILEGE`, `detail.failedPair`), arguments (`TOOL.ARGUMENTS`), the pairs the arguments add,
  `Registry.InvokeTool`. A result returns as bounded `tool_result` content or `{code, detail?}`.
- **A tool the browser fulfils (AD-11, amended 2026-09-18).** A tool declares `FULFILMENT` `instance`
  (`Screen/Tool/Base`'s default) or `client`; `Registry` refuses `client` on a write-kind tool.
  `Dispatch.ResolveClientCall` runs the whole chain above and records a **directive** instead of invoking
  a body, so every refusal precedes any announcement. The directive rides the progress poll that also
  renews the lease, and the browser answers once, on one route, in a closed outcome vocabulary. The wait
  is bounded by `NAVWAITSECONDS` and by every turn boundary check on each pass; a lapse is an ordinary
  tool result with the announcement withdrawn, never an error.
- **Prompt and untrusted text.** The system prompt is a build-time constant (`Prompt.BUILTIN`, whose
  two citation sentences now also tell the model to name rows in backticks and that the navigation tool
  announces before the browser moves and may be refused); tool results enter only as delimited
  tool-result content. Screen context enters as a synthetic, never-advertised `screen_context` call and
  result after `CONTEXTPREAMBLE` and before the user's message; a model-issued call with that name is
  refused as unknown. Application-error variable tables reach neither context nor a tool result.
- **Secrets backstop.** One case-insensitive list — suffixes `password`, `passwd`, `pwd`, `secret`,
  `secret64`, `apikey`, `privatekey`, `token`, `credential`, plus exactly `Key` or `CredentialName` —
  held by `Kernel/Audit/Log.Redact` (which `Audit/Event` passes through) and by the client pattern,
  pinned equal by a test. It only adds redaction.
- **Errors and routes.** Envelope `{error, reason, code, detail}`: screens render `reason`, tool results
  `code`. Under `/api/ocupilot`: `POST turn`, `GET turn/{id}/progress`, `POST turn/{id}/stop`,
  `POST turn/{id}/navigation`, `POST turn/abandon`, `POST/GET conversation[/{id}]` and
  `GET/PUT agent/context`, each with an HTTP test.
- **Stores.** Progress, conversation, the navigation directive and (4.9) the ledger use `Kernel/State`'s
  row-versioned guarded save (`STATE.CONFLICT` 409); a `%Persistent` class name, package included, stays
  within 29 characters (`OcuPilot.Kernel.State.` alone spends 22).
- **Testing a turn.** `OCUPILOT_ALLOW_TEST_PROVIDER=1` (set by `ci-throwaway.sh`) arms the `turnprobe`
  provider and `TurnWireFixture.EnsurePrincipal` makes a least-privileged principal; armed classes refuse
  on the live instance.
- **Test tiers, as CI's `instance` job runs them.** `%UnitTest` classes go through
  `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>` — one class at a time, each
  confirmed in `%UnitTest_Result` before the next, and it catches what the MCP runner misses (a class
  leaving `^OcuPilotTurnSlot` locked). The throwaway is compiled by
  `rsync -a --delete src/ /tmp/ocupilot-ci/src/` then `$System.OBJ.LoadDir("/opt/ocupilot/src", "ck", …)`.
  Browser specs run against the **deployed** bundle — `npm run build`, then
  `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` — and the suite is
  118/118; `npm test` is 940 node assertions plus 36 vitest files.
- **The bundle budget is a gate.** `ui/angular.json`'s `maximumWarning` 780 kB against a measured 766 kB
  initial total, enforced by `ui/tools/build-output.test.mjs` (a real build read from the real output
  directory) and `ui/tools/angular-json.test.mjs`. `marked`, `lowlight`, `highlight.js` and `dompurify`
  are vendored into it.
- **Client.** Zoneless, `OnPush`; state in framework-free `core/` stores mirrored into signals; only
  `core/preferences.ts` touches `localStorage`; every user-visible string comes from `core/strings.ts`
  and must appear in EXPERIENCE.md; geometry is asserted in the browser runner.

## UX & Interaction Patterns

- **Panel (built).** Docked right, no close control: banners in order (kill switch, enforced read-only,
  "not being marked", administrator reminder, lock), chip, transcript as a polite `role="log"`, footer
  with the read-only line, composer and Send; during a turn Send becomes Stop while the composer stays
  focusable under `aria-disabled`. The chip names screen, namespace, rows, provider and endpoint host
  with the "leaves the instance" pill; reply links are inert; navigation announces first, routes about
  1 s later and focuses the new heading, `core/strings.ts` carrying all three literals including the
  no-row form "I'm opening <screen> — use Back to return." (EXPERIENCE.md `:281`).
- **The turn error banner (4.8's).** "The turn stopped at <step>: <reason>."; a stopped turn is not an
  error, and 4.8 also owns a refused Send.

## Cross-Story Dependencies

- **From 4.7.** `Screen/Tool/Navigate` (`shell.screen.open`, read, client-fulfilled) and
  `Kernel/State/Nav` (one directive per turn, requested only against a committed `announce` step, settled
  by whichever of browser and lapse wins `GuardedSaveIfCurrent`); `Turn.GuardedView` carries
  `navigation {seq, route, entityId}` only while paired with that step, and `POST /turn/:id/navigation`
  takes only `{seq, outcome, code}`, 409 on an unclaimed settle. `Loop.AnswerClientCall` re-runs
  `Boundary` on every 250 ms pass of the wait, so a stop, kill switch, lapsed lease, wall-clock or token
  bound ends the turn mid-wait — the path 4.8's timeout work must not break. Client: `core/turn.ts`,
  `shell/agent-navigator.ts` and `ui/browser/turnprobe-spec.mjs`.
- **From 4.6 and 4.11.** `core/reply.ts` (`parseReply` → a plain-data node tree, never an HTML string,
  never throws) with `shell/reply.ts` (DOM by `createElement`, then a `DOMPurify` pass);
  `core/agent-context.ts`, the one source of `share`, `contextRowCap`, `provider`, `endpointHost` and
  `leavesInstance`, re-read on `agent-switch` **and** `agent-definition`; `core/screen-context.ts` and
  `shell/context-chip.ts`.
- **From 4.5.** `conversationId` is required on `POST /turn` (422 `TURN.CONVERSATION.REQUIRED`); the job
  holds a per-conversation lock over `Kernel/State/Convo` and `Entry` and appends the turn's entry on
  every exit path. A tool step carries `target`, an arguments summary, `rowsReturned`, `rowsSent`,
  `truncated`, `reason` and `failedPair`, written `running` before its call and settled `failed` if the
  turn ends while running — the records 4.9 reads alongside provider usage.
- **From 4.3.** `core/panel-layout.ts` holds `PanelState` and pure `resolveLayout(...)`, the sole layout
  computation — 4.10 passes `panel-home`'s width into it.
- **From 4.4.** `POST /turn`'s optional `context` is `route`, `namespace` (must equal the request's
  `?ns=` scope, else 422 `TURN.CONTEXT.INVALID`), `entity` and `view`; `Screen/Context` projects by
  descriptor and `Bound` reports `rowsSent`, `rowsAvailable`, `truncated`, `truncatedFields`.
  `GET/PUT …/agent/context` stores the per-user choice in `Kernel/State/Sharing`.
- **From 4.2.** 4.9 writes one ledger row per dispatched call with `RequiredPairs`, and owns DW-448
  (`BoundedWhere` has no guarded parameter-array helper, so the ledger's time window has no path).
- **From 4.0.** 4.8 reworks the request path through `Port/ProviderPort` and `Kernel/Provider/Base`,
  whose retry arithmetic already lives in `Kernel/Provider/Retry` (retryable 408, 409, 429 and every
  status from 500 up; the base's loop is what refuses to retry a call that raised).
- **From earlier epics.** Epic 2's declared reads and AdminPort; Epic 3's provider contract, egress
  policy and switches; Epic 1's protected storage, CSP, string table and audit events
  (`Kernel/Audit/Event`'s roster, registered by `Installer.EnsureAuditEvents`).
- **Later epics build here.** Epic 5's first write tool passes the restraint branch, threads the "acting
  on behalf of the model" marker through job and `Dispatch`, and waits on DW-444. Epic 11 adds streaming
  over the polling contract; Epic 14 adds governance on 4.2's gate, per-user turn limits and transcripts
  gated by 4.9's per-row resource.
- **Ledger entries** routed onto a story bind it: address each or decline with a reason. 4.8 carries
  DW-334 (four resolver lookups plus a `GetInterfacesInfo` read per endpoint judgement, uncached, on
  every provider call), DW-413 (`Egress.Addresses`' single-form `HostNameToAddr` fallback sits outside
  the `MultiLookup` seam), DW-441 (a proxy still applied to a marked-local plain-http endpoint, in
  cleartext), DW-1053 ("stopped at :" when the failure names no step) and DW-1054 (a Send refused with
  anything but 409 shows nothing). 4.9 carries DW-448. 4.10 carries DW-160 (Home's widening AC),
  DW-379 (`--ocu-panel-home` has no consumer) and DW-269 (the tasks LIST coerces `Suspended` to false,
  so the suspended line needs AD-36's `INFO` detail read). Open for the owner's decision sheet and the
  burn-down: DW-1052, DW-1048, DW-458, DW-460, DW-456.
