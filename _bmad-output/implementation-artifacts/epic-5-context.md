# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, and then
finds that same change in the IRIS audit database marked as having come through the agent — in
**each** of the six areas. This is the product's entire claim and the end of build step 2: SM-3 (six
areas, six confirmed writes) and SM-4 (the one-minute demo) are both met here. Stories 5.1–5.7 build
the write path once — server-minted proposal, card, confirm as one atomic transition, execution as
the user, the prohibited set, the audit marker, the change-event bus — and 5.8–5.13 exercise it once
per area.

## Stories

- Story 5.0: Epic 4 deferred cleanup — **done**
- Story 5.1: The proposal is minted on the instance, from a fresh read — **done**
- Story 5.2: The proposal card — the diff the user reviews — **done**
- Story 5.3: Confirm is user-originated, and the write is one atomic transition — **done**
  (`596c773`, `9de53d3`)
- Story 5.4: Execution strictly as the user ← **next**
- Story 5.5: Prohibited actions are absent from the tool set
- Story 5.6: The agent marker, and what happens when it fails
- Story 5.7: The screen shows the change
- Story 5.8: Web applications — enable a disabled application and grant it a resource
- Story 5.9: Permissions — the area's first confirmed user write
- Story 5.10: Security and secrets — disable and re-enable auditing
- Story 5.11: Tasks — resume a task suspended after an error
- Story 5.12: OS management — suspend and resume a process
- Story 5.13: Logs — delete application errors by namespace

## Requirements & Constraints

**Settled upstream and consumed, not re-decided (5.0–5.2).** The instance mints every proposal and
the client never authors one: server-issued unguessable id, user, conversation, tool, full resolved
arguments, scoped target identity `(entity type, scope, id)`, a fingerprint over the **complete
property set the write will send** minus descriptor-declared side-effect fields, the diff, and a
single-use token, expiring on a server-side ten minutes. Secret-typed values are never stored and
never accepted from the model. The payload is the whole merged object; the diff is only what the
user reviews. The card, its phase model, countdown and terminal status lines are built.

**Story 5.3's contract, which 5.4 inherits whole.** Confirm is a **separate authenticated POST**
(`Kernel/Proposal/Confirm.cls`) — not a tool, absent from the registry, and refused outright when
the calling process carries the turn marker (`Kernel.Proposal.Caller.IsTurn()`). The barrier is
explicit precisely because in-process tools removed the HTTP one. The executor uses the **stored**
arguments and stored payload; the only client-suppliable keys are the descriptor's declared
secret-typed fields for that tool, any other key is **rejected outright, not ignored**, and the
identifying key is never accepted from the client. Only the minting user can confirm.
`Propose.GuardedClaimAndClose` is the claim: **one** conditional UPDATE inside a per-target lock
which, in one transaction, burns the token, writes the terminal state and cancels same-target
siblings; the loser is refused with the row's terminal state and never retried; the vendor PUT
follows `TCOMMIT`. Every gate that decides whether a write may happen — the prohibited-set seam,
`Restraint.Verdict` (kill switch, enforced read-only, per-user hold, definition read-only flag), the
declared `(resource, permission)` pairs, and the fingerprint re-read — is evaluated **inside that
transition**, never at the tool call that minted the proposal. All five FR-17 refusals are built:
user, conversation, definition, read-only state, fingerprint. `Write.Claim` carries six refusal
codes; `Write.ProhibitedClass()` returns `""` and is **AD-10's single seam for Story 5.5 to fill**.

**Story 5.4 — what execution as the user must prove.** Every tool body runs in the calling process
under the caller's own `$USERNAME`/`$ROLES`, with **no service account and no credential other than
the user's own**. The tool set advertised to the model is the **full set** — privilege is checked at
call time, never by hiding tools — and a tool's 403 is byte-for-byte the screen's 403, surfaced on
the tool-call card as `failed — <resource>` and **reported, never retried with another credential or
another path**. The one permitted escalation is OcuPilot's own protected storage, and it is **not in
effect while any tool, port or provider code runs**; no storage method calls a tool, a port, or code
that could, and nothing is spawned or re-entered from inside an escalated frame. Any token the
instance holds on the user's behalf during a turn lives in process memory only, never reaches the
ledger or a transcript, and is discarded when the turn ends. **Each port declares and evaluates its
own gate before any call** — the log ports inherit no vendor gate and `/api/monitor/metrics` answers
**anonymously** on this instance — and the log endpoints require the same resource the classic
portal's log pages require, so a metric, a log line or an audit row reaches a user through OcuPilot
only if that user could have read it directly.

**Ahead in the epic.** Prohibited actions absent from the tool set, defined by effect not verb, in
**exactly one home in the kernel** (5.5). Every confirmed write emits a correlatable audit marker; a
failed marker never fails the write (5.6). One change event, screens re-fetch in place and highlight
within two seconds (5.7). The six area writes are 5.8–5.13.

## Technical Decisions

- **Governing ADs.** 5.4: **AD-8** (privilege is the process's, checked at call time, never cached;
  the descriptor declares a **set** of `(resource, permission)` pairs, the gate requires all of it,
  and a denial names the pair that failed), **AD-1** (tools in-process, so "runs as the user" is a
  property of the process rather than something a token asserts), **AD-9** (the protected-storage
  escalation and its two ordering rules), **AD-29** (per-port gate), **AD-31** (the turn job
  re-validates between steps with `$SYSTEM.Security.CheckUserPermission`; wall-clock 600 s,
  iterations capped at 100, 500,000 provider tokens, 120 s poll lease), **AD-35** (no credential in
  an exception, status, log line or trap). Then 5.5: AD-10, 34, 40. 5.6: AD-15, 41, 46. 5.7: AD-14,
  43, 13. AD-7 (amended — progress lives in AD-33's protected storage, not a temp global), AD-30,
  AD-33 and AD-12/AD-39 hold throughout.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone.** The
  vendor's gate is a **lower bound**: read the backing query or class's own privilege check in
  `irislib/`, then run the read as a **real least-privileged principal** on a throwaway and add what
  the instance still refuses. Probed: `%Api.Admin.Endpoints.Process` answers `%Admin_Operate` alone
  while `%SYS.ProcessQuery.AllowToOpen` admits four different ways in and `VariableByPid` requires
  `%Admin_Manage:USE` outright. A port without a named gate is a review failure.
- **IRIS's default isolation is READ UNCOMMITTED, and that fact is load-bearing (AD-34).** The 5.3
  review found a real violation: a rival claim's **uncommitted** `confirmed` made the other claim's
  `%EXACT(State) = 'live'` sibling UPDATE match zero rows, so it never requested the lock — two
  confirmed rows on one target and two vendor PUTs. The per-target lock closes it. Any new
  conditional-update-plus-cancel pattern in this epic carries the same hazard.
- **DW-444 is DECIDED, not open, and 5.4 ships it.** Refuse a disabled account: check `Enabled` at
  authentication and refuse `/refresh` for a disabled user. The enabled-flag read AD-8 would
  otherwise forbid is **escalated deliberately** because this is a security hole that ships in
  Release 1 — carry it as a settled constraint, not a question. The non-obvious constraint:
  `/login`, `/refresh`, `/logout` and `/revoke` are **intercepted by the CSP server before
  dispatch** (`irissys/%CSP/REST.cls`), so `Api/Router.cls`'s `UrlMap` has no route for any of them
  and the refusal cannot live in a route handler. Probed on 2026.2: a disabled account's access
  token keeps answering and `/refresh` keeps minting pairs; only a fresh password login is refused.
- **DW-1120 is 5.4's too.** An `llm` row and a pre-dispatch refusal row carry an empty
  `RequiredPairs`, and `Screen.Gate.EvaluatePairs("")` returns 1 — held by everyone — so a
  cross-user reader holding only `OcuPilotAdmin:USE` receives them ungated. An empty pair set must
  never evaluate true; both row writers and the gate need the fix.
- **Every browser spec this epic writes uses `saveAndSettle()` (DW-1169, closed on a
  reproduction).** Waiting on a value the test itself typed is **vacuous** — the field reads it
  before any request leaves — so the spec walks on while the save is in flight, and
  `switches.store.ts`'s `if (this.savingValue) return false` plus the page's `if (this.busyFlag)
  return` **absorb** the next press with no error and no effect. An out-of-band `fetch` does not
  close the gap either: it proves the instance stored the value, not that the browser's promise
  resolved. `ui/browser/panel-spec.mjs` exports `saveAndSettle()`, which presses Save and waits for
  the form bar's `role="status"` element.
- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations
  merge; sending only changed fields to one of the other 28 erases every omitted field. Read fresh,
  apply the diff, send the complete property set — merged over the fresh read's whole object, never
  over the derived field list.
- **Proposal state is OcuPilot's own protected state**, written through `Kernel/State`'s
  row-versioned guarded save (`STATE.CONFLICT`, 409). References to IRIS objects are **weak**:
  scoped identity as data, never a foreign key.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` text normalized at the port boundary with the raw kept for log and ledger only;
  `detail.violations[]` is projected to `{field, code}` before it reaches the model. Confirm's codes
  extend the `PROPOSAL.*` set on `Kernel/Proposal/Write.cls`; `Api/Error.cls` validates a code by
  **shape**, so no contended edit is needed for a new one.
- **Audit events must be registered.** `$System.Security.Audit()` silently returns 0 and drops the
  event when its Source/Type/Name triple was never created, so the return value is checked.
- **5.13 has no admin API endpoint and no invariant relaxes.**
  `SYS.ApplicationError.DeleteByNamespace` with one explicit save/restore to `%SYS`, the namespace as
  a **parameter** from the drilled descriptor state (never the route's `?ns=`), the gate resolved per
  namespace at call time, the fingerprint the **enumerated id set** captured at proposal time, and a
  read tool returning summary fields only.
- **Client and tests.** Zoneless `OnPush`; `core/` imports no `@angular/core`; every user-visible
  string from `core/strings.ts` and present in EXPERIENCE.md's Fixed-strings table; design tokens
  only. Geometry belongs in the browser runner, which loads the **deployed** bundle (`npm run
  build`, then `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`).
  `%UnitTest` classes run **one at a time**, each landed in `%UnitTest_Result` before the next. Every
  handler gets an HTTP test on status, content type and body shape; every tool a round-trip test over
  its generated schema; a denial test uses a purpose-built least-privileged role, never `%Operator`.

## UX & Interaction Patterns

- **The card, as shipped.** Target heading; changed fields as instance-computed diff rows; the rest
  of the payload behind an "N unchanged fields" disclosure; the agent's rationale and expected impact
  **labeled** on the agent tint; "Reverse: <how to undo>" where one exists. Footer: "Runs as <user
  name>, with your privileges." and "Confirm here; sending a message cancels this proposal".
  Countdown "Expires in m:ss" from 10:00, `warning` from 1:00, announced **once** at 1:00. Delete
  proposals show `field · value → (removed)` with no after-state and no Reverse line.
- **Confirm's transition (5.3).** In flight the button shows progress and is `aria-disabled` with
  focus kept; on success the buttons are replaced by "Confirmed by <user name> · hh:mm:ss", which
  takes focus, and Send returns to primary. Terminal status lines: "Canceled — by your message",
  "Canceled — a sibling proposal was confirmed", "Expired", "target changed, re-propose". A
  fingerprint mismatch also raises a warning banner inside the card above the footer and offers
  **only** Re-propose. Buttons are `aria-disabled` for the transition, never removed while focused;
  the restrained treatment is by role at full opacity so the diff stays readable at AA.
- **One decision at a time.** Cards stack in order, each with its own Confirm and Cancel; there is
  **no "Confirm all"**; while one is live Send drops to secondary. A typed message cancels every live
  proposal and the agent's next reply says so and offers to re-propose; New conversation cancels the
  same way; **Stop cancels nothing**.
- **For 5.4 specifically:** a refused tool call renders on the tool-call card through the existing
  `toolCallStatusFailed` string (`failed — <reason>`), carrying the failed pair; the agent states the
  refusal rather than retrying. Auto-refresh pauses under a live proposal and resumes on confirm,
  cancel or expiry (AD-43).

## Cross-Story Dependencies

- **Story 5.4's ledger inbox is two entries, both already decided** — DW-444 (refuse a disabled
  account at authentication and at `/refresh`) and DW-1120 (an empty `RequiredPairs` must never
  evaluate true). Name each against the story; neither is a question to re-open.
- **Four `decision-pending` entries remain owner-level and are not settled inside a story.**
  **DW-456**: shipped registry-layer classes already name kernel and API classes the spine's
  direction line forbids. **DW-1207**, now **FLOOR-BLOCKING and routed to 5.5**: `AutheEnabled`,
  `Resource` and `DispatchClass` are settable **ordinary** arguments of the first write tool, so a
  confirmed write could make a web application unauthenticated, drop its authorization resource, or
  repoint its dispatch at arbitrary compiled code — AD-10 exists so some actions are never offered
  even with confirmation, and 5.5 must treat it as must-ship. **DW-1208**, decided: Release 1 ships
  the **`%All`-only write**, with the limitation stated in the story and, if the screen can carry it,
  in user-facing text naming `%Admin_Secure:WRITE`; later non-`%All` write targets are the recorded
  follow-on. **DW-1206** lands *with* 5.10, validating `secretArguments` against the same declared
  field set `fingerprintExcludes` already uses.
- **Footprint, as the orchestrator settled it 2026-09-19.** `src/OcuPilot/Test/**` and
  `ui/src/app/core/**` are **shared-create**: any epic creates files there freely, and modifying a
  file another epic created or modified is a **Clarification**. `core/proposal-view.ts` and
  `core/turn.ts`'s proposal publisher are Epic 5's, as are `panel*`, `proposal-card*`, `reply*`,
  `tool-call-card*`. **Epic 15** (running now) holds
  `ui/src/app/shell/{header,account-menu,side-bar,command-box}*` and `ui/src/styles/**`. **Epic 13**
  (on 13.2) holds `ui/tools/ci*.mjs`, `.github/workflows/**`, `scripts/`, `Install/Uninstall*`,
  `module.xml`, `spec/**`. **`Api/Router.cls` and EXPERIENCE.md's Fixed-strings table are epic-wide
  shared-append — additions at the tail only.**
- **Other standing routes.** 5.6 carries DW-1174; 5.8 DW-1223; 5.10 DW-1171 and DW-1206; 5.11 DW-269,
  also routed at the epic level.
- **From Epic 4 and earlier.** The turn job with its progress and lease contract; `Dispatch`'s gate
  chain (governance → restraint for `kind=write` → declared pairs → schema → `Registry.InvokeTool`)
  and its restraint branch; the ledger (one row per call, `RequiredPairs`, schema-driven redaction,
  finalized **after** the write and recording what was actually executed); the panel with its banner
  order and reserved `not-marked` slot; `AdminPort`'s eight-step vendor dispatch — the only code
  naming an `%Api.Admin.*` class; the audit viewer with its agent-marker filter; the kill switch,
  enforced read-only and the definition's read-only flag; protected storage and its resource; the
  closed entity-type enum; the descriptor mechanism; the string table; the registered audit events;
  and the smoke script that defines "step complete".
- **Deliberate forward references.** 5.10's write must be the **same operation** Story 7.4's Auditing
  configuration screen later calls, and 5.6's and 5.10's banner carries its sentence alone until 7.4
  makes its link live. 5.11 navigates to the Task schedule list with the task selected; retargeting
  it at the details route is the one-line change assigned to 7.6. Typed-name confirmation arrives in
  full at 14.7. Epic 8 depends on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
- **Rule 27 governs the epic's burn-down gate, not the individual stories.** A cleanup story and its
  burn-down gate charter only ledger entries that block the 2026-09-27 floor or a downstream epic's
  story; every other closable entry is re-owned, with the gate's own `by=` trailer, to the single
  range-end cleanup story chartered after Epic 12 merges.
