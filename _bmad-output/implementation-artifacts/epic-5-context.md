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
- Story 5.4: Execution strictly as the user — **done** (`d213550`)
- Story 5.5: Prohibited actions are absent from the tool set ← **next**
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

**Story 5.3's contract, which everything downstream inherits whole.** Confirm is a **separate
authenticated POST** (`Kernel/Proposal/Confirm.cls`) — not a tool, absent from the registry, and
refused outright when the calling process carries the turn marker
(`Kernel.Proposal.Caller.IsTurn()`). The executor uses the **stored** arguments and stored payload;
the only client-suppliable keys are the descriptor's declared secret-typed fields for that tool, any
other key is **rejected outright, not ignored**, and the identifying key is never accepted from the
client. Only the minting user can confirm. `Propose.GuardedClaimAndClose` is the claim: **one**
conditional UPDATE inside a per-target lock which, in one transaction, burns the token, writes the
terminal state and cancels same-target siblings; the loser is refused with the row's terminal state
and never retried; the vendor PUT follows `TCOMMIT`. Every gate that decides whether a write may
happen — the prohibited-set seam, `Restraint.Verdict` (kill switch, enforced read-only, per-user
hold, definition read-only flag), the declared `(resource, permission)` pairs, and the fingerprint
re-read — is evaluated **inside that transition**, never at the tool call that minted the proposal.
All five FR-17 refusals are built: user, conversation, definition, read-only state, fingerprint.

**Story 5.4's settled contract, which 5.5 consumes.** Execution is **strictly as the user**: every
tool body runs in the calling process under the caller's own `$USERNAME`/`$ROLES`, with no service
account and no credential other than the user's own. The tool set advertised to the model is the
**full set** — privilege is checked at call time, never by hiding tools — and a tool's 403 is
byte-for-byte the screen's 403, surfaced as `failed — <resource>` and **reported, never retried**
with another credential or another path. The **only elevation on the request path** is AD-9's
privileged routine application, now joined by a **second, narrowly scoped application for one
identity read** — whether the authenticating user's account is enabled. AD-8 and AD-9 were
**amended under Rule 5 on 2026-09-20** to say so; it is a settled contract, not an exception to
argue. `New $ROLES` is confined by `scripts/check-objectscript.py` to `Kernel/State/Base.cls`, so
the escalation has **exactly one legal home**. Neither escalation is in effect while any tool, port
or provider code runs; nothing is spawned or re-entered from inside an escalated frame. A drifted
`OcuPilotIdentity` application now surfaces as **`503 INSTALL.UNREADABLE`, never `AUTH.DISABLED`**
(AD-38) — OcuPilot saying it cannot read its own state, not that the user did something. Each port
declares and evaluates its own gate before any call; the log ports inherit no vendor gate and
`/api/monitor/metrics` answers anonymously on this instance.

**Story 5.5 — what the prohibited set must prove.** The Release 1 prohibited set lives in **exactly
one home in the kernel**, as predicates evaluated against the **resolved target** — never duplicated
into a screen, a descriptor or a policy file, and **never expressed as a match on request fields**,
which a caller can vary. Because a predicate reads live state (who the last `%All` holder is, which
application serves OcuPilot), it is evaluated **inside Story 5.3's atomic transition, inside the
per-target lock, before the vendor PUT**, so the answer cannot change between the check and the
effect. The set is defined **by effect, not by verb**, and covers:

- deleting or disabling the current user, the last `%All` holder, or `_SYSTEM`;
- **granting privilege through any path** — setting `MatchRoles` or `Roles` on any web application,
  adding a role to a resource, or adding `%All` or any `%Admin_*` role to any user or role. Granting
  `%All` as an application role on OcuPilot's own API is neither a delete nor a disable and would
  make every later request, including every turn job, run elevated — quietly falsifying AD-8.
  Privilege **grants** are Level 4 in Release 1 and are **not proposable at any confirmation level**;
- **disabling the path that serves OcuPilot** — the web application, the **web service** behind it
  (`%Service_Web` and the CSP service), and the superserver;
- terminating IRIS system processes;
- deleting OcuPilot's own web applications, resource, role or database.

A prohibited action is **never advertised as a tool** and is refused on the instance whatever the
caller. Governance can disable a permitted tool; it can **never enable a prohibited one**. A
self-protection rule a screen enforces in its UI is an **affordance, not a prohibition** — the
instance refuses it on the write path regardless of what the UI does.

**Ahead in the epic.** Every confirmed write emits a correlatable audit marker; a failed marker never
fails the write and surfaces as "done · audit not marked" on the card's collapsed line (5.6). One
change event, screens re-fetch in place and highlight within two seconds (5.7). The six area writes
are 5.8–5.13.

## Technical Decisions

- **Governing ADs.** 5.5: **AD-10** (the set, its single home, effect-not-verb), **AD-34** (the
  atomic transition the predicates run inside), **AD-40** (the gate is on the write, not on the tool
  call that minted the proposal — a check made only at mint time is a check against state that has
  since moved). Then 5.6: AD-15, 41, 46. 5.7: AD-14, 43, 13. AD-8 and AD-9 as amended, AD-1, AD-29,
  AD-31, AD-35, AD-7 (amended), AD-30, AD-33 and AD-12/AD-39 hold throughout.
- **The seam 5.5 fills already exists.** `Kernel/Proposal/Write.cls`'s `ProhibitedClass()` returns
  `""` today and is AD-10's **single seam**, reached through `Confirm.ProhibitedClassName()` inside
  the transition and before the write type is dispatched; `Test/ProposalConfirm.cls` already pins
  that call's position. Fill the seam — do not add a second decision point.
- **IRIS's default isolation is READ UNCOMMITTED, and that fact is load-bearing (AD-34).** The 5.3
  review found a real violation: a rival claim's **uncommitted** `confirmed` made the other claim's
  `%EXACT(State) = 'live'` sibling UPDATE match zero rows, so it never requested the lock — two
  confirmed rows on one target and two vendor PUTs. The per-target lock closes it. Any new
  conditional-update-plus-cancel pattern in this epic carries the same hazard, and a prohibited-set
  predicate that reads live state is subject to exactly the same window.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone.** The
  vendor's gate is a **lower bound**: read the backing query or class's own privilege check in
  `irislib/`, then run the read as a **real least-privileged principal** on a throwaway and add what
  the instance still refuses. Probed: `%Api.Admin.Endpoints.Process` answers `%Admin_Operate` alone
  while `%SYS.ProcessQuery.AllowToOpen` admits four different ways in and `VariableByPid` requires
  `%Admin_Manage:USE` outright. A port without a named gate is a review failure.
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

## Standing rulings

- **A deferred entry that names an AD's own invariant is not a deferral candidate.** Rule 6 already
  grades it high, so it is standing work on the story that owns it, not something the burn-down gate
  re-weighs.
- **Rule 19 falsifiability mutations run on the runner's own throwaway container, never on the
  shared dev instance** (DW-1185). For slot A that is `ocupilot-ci` on 52776/1975.

## Instance and slot

Every IRIS MCP call from this runner carries `server: "ocupilot-slot-a"`. The slot's dev container is
`ocupilot`; its throwaway is `ocupilot-ci` on 52776/1975. Never `up`, `down`, stop, remove or
recreate the dev container.

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
- **For 5.5 specifically:** a prohibited action is not a tool the model can see, so there is no card
  for it; a refusal that does reach the user renders through the existing `toolCallStatusFailed`
  string (`failed — <reason>`) and the agent states the refusal rather than retrying. Auto-refresh
  pauses under a live proposal and resumes on confirm, cancel or expiry (AD-43).

## Cross-Story Dependencies

- **Story 5.5's ledger inbox is DW-1207, and it is floor-blocking by owner decision (2026-09-19) —
  not re-ownable and not deferrable.** `AutheEnabled`, `Resource` and `DispatchClass` are settable
  **ordinary** arguments of the first write tool, so a confirmed write can make a web application
  unauthenticated, drop its authorization resource, or repoint its dispatch at arbitrary compiled
  code. AD-10's set exists so some actions are never offered **even with confirmation**; this ships
  in Release 1 through `Write.ProhibitedClass()`.
- **Three `decision-pending` entries remain owner-level and are not settled inside a story.**
  **DW-456**: shipped registry-layer classes already name kernel and API classes the spine's
  direction line forbids. **DW-1208**, decided: Release 1 ships the **`%All`-only write**, with the
  limitation stated in the story and, if the screen can carry it, in user-facing text naming
  `%Admin_Secure:WRITE`; later non-`%All` write targets are the recorded follow-on. **DW-1206** lands
  *with* 5.10, validating `secretArguments` against the same declared field set `fingerprintExcludes`
  already uses.
- **Footprint, settled.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**: any
  epic creates files there freely, and modifying a file another epic created or modified is a
  **Clarification**. `ui/src/app/core/proposal-view.ts` and `ui/src/app/core/turn.ts` are Epic 5's,
  as are `panel*`, `proposal-card*`, `reply*`, `tool-call-card*`. **Epic 13** (live on 13.2) holds
  `ui/tools/ci*.mjs`, `.github/workflows/**`, `scripts/`, `Install/Uninstall*`, `module.xml`,
  `spec/**`. **Epic 15** (live on 15.1) holds
  `ui/src/app/shell/{header,account-menu,side-bar,command-box}*` and `ui/src/styles/**`.
  **`src/OcuPilot/Api/Router.cls` and EXPERIENCE.md's Fixed-strings table are epic-wide
  shared-append** — additions at the tail only; expect a union merge.
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
