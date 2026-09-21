# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once. **5.8–5.13 exercise that
finished path once per area and add nothing to it.**

## Stories

- Stories 5.0–5.7 — **done**: Epic 4 cleanup; proposal minted on the instance from a fresh read; the
  proposal card; confirm as one atomic transition; execution strictly as the user; the prohibited
  set; the agent marker; the screen shows the change.
- Story 5.8: Web applications — enable a disabled application and grant it a resource ← **next**
- Story 5.9: Permissions — the area's first confirmed user write
- Story 5.10: Security and secrets — disable and re-enable auditing
- Story 5.11: Tasks — resume a task suspended after an error
- Story 5.12: OS management — suspend and resume a process
- Story 5.13: Logs — delete application errors by namespace

## Requirements & Constraints

**5.8 is the first end-to-end confirmed, user-visible write in a real area, and it is the demo
path.** A disabled `/csp/myapp` with no resource; one typed sentence; a read tool-call card runs and
completes; a proposal card headed "Proposal — Web application /csp/myapp" shows **two** diff rows
(Enabled No→Yes, Resource (none)→%Development) with the rest behind "N unchanged fields"; rationale
and expected impact render as labeled agent text with "Reverse: disable /csp/myapp and clear its
resource"; the list's auto-refresh chip reads paused. On Confirm the write runs as that user through
**the same endpoint the screen's editor uses**, sending the **complete merged property set**, not the
two changed fields; the status line reads "Confirmed by <user name> · hh:mm:ss" and takes focus; the
write's card reads "done · audit marked"; the row re-fetches and highlights within two seconds. The
agent states what it verified and ends "Shall I show you the audit entry?"; yes navigates to Logs →
Audit database with the agent-marker filter, where the event appears under the user's own name.
Without the privilege the user gets **the same 403 the editor would give**, the card reads
"failed — <resource>", and the agent states the refusal without retrying. OcuPilot's own applications
are refused on the instance and were never advertised as a tool.

**5.8's four ledger bullets.**

- **DW-1208 — decided by the owner 2026-09-21; a standing rule, not a one-off.** The write tool
  requires **`%Admin_Secure:USE`, never `:WRITE`.** No shipped role grants WRITE on a built-in
  `%Admin_*` resource — verified on the instance: those are Type 9 system resources and every shipped
  grant is `:U`, while only `%DB_*` carry `:R`/`:RW` — so a WRITE pair is a gate only a `%All` holder
  can pass. `USE` is *exactly* what the classic editor checks: the Web Applications editor pages
  declare `Parameter RESOURCE = "%Admin_Secure"` with no suffix, and
  `%CSP.Portal.Application.CheckSecurity` is in full `Quit $System.Security.Check(pResource,"USE")`.
  That makes 5.8's "the same 403 the editor would give" satisfiable **by construction**. The rejected
  alternative — an OcuPilot-owned resource carrying its own WRITE — is technically viable but creates
  a second authorization model that must be kept in step with the vendor's, the failure shape this
  epic has ruled against repeatedly. Apply the rule to every later `%Admin_*` pair.
- **DW-1223.** The "N unchanged fields" disclosure has **no rows behind it** — `WireRow` emits only
  `unchangedCount`, so 5.8's own "remaining fields collapsed" clause has nothing to collapse. Add the
  rows; exclude secret-typed fields.
- **DW-1252.** A confirm refusal that leaves the row live gives the card **no reason anywhere**; the
  refusal must reach the card as a stated reason, not a silent non-event.
- **DW-1382.** `smoke.sh`'s `agentwrite` and `auditmarker` checks are still `pending`, and AD-45's
  Rule names one confirmed agent write and its marker as part of the one smoke path. 5.8 is where
  they stop being pending.

**Inherited from 5.1–5.6 — consumed, never re-decided.** The instance mints every proposal from a
fresh read (server id, user, conversation, tool, resolved arguments, AD-13's scoped target triple, a
fingerprint over the complete property set the write will send minus descriptor-declared side-effect
fields, the diff, a single-use token, ten-minute expiry); secrets are never stored and never accepted
from the model. Confirm is a **separate authenticated POST** (`Kernel/Proposal/Confirm.cls`), absent
from the registry, refused when the caller carries the turn marker, usable only by the minting user;
it executes the **stored** arguments and payload, and any client key other than the descriptor's
declared secret fields is **rejected outright, not ignored**. `Propose.GuardedClaimAndClose` is
**one** conditional UPDATE inside a per-target lock that burns the token, writes the terminal state
and cancels same-target siblings in one transaction, with the vendor PUT after `TCOMMIT`. Every gate
— prohibited set, `Restraint.Verdict`, the declared `(resource, permission)` pairs, the fingerprint
re-read — is evaluated **inside that transition**, never at the minting tool call. Execution is
**strictly as the user** under the caller's own `$USERNAME`/`$ROLES`; the advertised tool set is the
**full** set and privilege is checked at call time, never by hiding tools. The marker is emitted from
**one site** in `Confirm.Transition` after the write reads OK, with `$System.Security.Audit`'s return
value **checked** — it returns 0 and silently drops when its triple was never registered.
`webapp.list.update` already ships (5.5) with an allowlist of four reviewed fields — `AutheEnabled`,
`Description`, `Enabled`, `Resource` — under `additionalProperties: false`, declared in exactly two
places (`Screen.Tool.WebAppUpdate.PERMITTEDFIELDS`, `Kernel.Proposal.Prohibited.PermittedChangeFields`);
the suite fails if only one is updated. An entity type the prohibited set does not evaluate is refused
wholesale (`PROHIBITED.UNCOVERED`), so **5.9–5.13 must each add their type's predicates before their
write tool can register.**

**Settled in 5.7, load-bearing for every area story.**

- A confirmed write publishes **one** `changed` event on the client change bus carrying AD-13's
  scoped triple plus an `action` from a closed set (`created`/`updated`/`deleted`), **refused rather
  than defaulted**. `TurnStore.decideProposal` publishes it after the `proposal-closed` that closes
  AD-43's pause, in that order.
- The per-type id rule is a **declared table** — `EntityRef.IDRULES`/`IDRULENAMES` — that
  `ui/tools/screen-mirror.mjs` mirrors and **throws at prebuild** on an undeclared rule, unknown type,
  a rule the client cannot implement, or a duplicate type; `REFSEPARATOR` likewise. There is **no**
  second identity rule hand-written in TypeScript — that second source is what AD-5 forbids and is how
  the original divergence arose. `web-application` folds case and strips trailing slashes.
- **Sharp edge for any story that marks a row.** `Mint` stores a **folded** `targetRef` while a row's
  key is the name the instance returns, **case-preserved** (`Security.Applications` keeps the name as
  created). Two separate HIGH defects came from that gap in 5.7 alone — the mark never landing, then
  never clearing — **both found with the whole suite green**. `DataTable.viewKeyFor` and
  `changedKeyFor` are the reconciliation points, and 5.8 marks a `/csp/myapp` row.
- `DefinitionForm.publishChange()` now takes its action, so a create publishes `created` and an edit
  `updated`; it previously hard-coded `updated`, leaving AD-14's `created` unreachable.
- The off-screen toast exists — store, stack of three, two lifetimes, counted hover/focus hold,
  dismiss, "Open in <screen>" — with real browser coverage for geometry, stacking and pointer-events.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations merge;
  sending only changed fields to one of the other 28 erases every omitted field. Read fresh, apply the
  diff, send the complete property set merged over the fresh read's whole object.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check in `irislib/`, then
  run the read as a real least-privileged principal on a throwaway and add what the instance still
  refuses. A port without a named gate is a review failure. DW-1208 is this rule applied.
- **Governing ADs.** AD-14 (one change event; screens **re-fetch, never patch**; closed kernel-owned
  entity-type enum keyed from the screen descriptor), AD-43 (one shared auto-refresh framework;
  `proposal-open`/`proposal-closed` ride the same bus and carry the pause), AD-13 as amended (every
  boundary-crossing reference carries `(entity type, scope, id)`, scope being the namespace or the
  constant `instance`). AD-45, AD-41, AD-15, AD-46, AD-8/AD-9 as amended, AD-10, AD-34, AD-36, AD-40,
  AD-1, AD-29, AD-31, AD-33, AD-35, AD-44, AD-12/AD-39 hold throughout.
- **IRIS's default isolation is READ UNCOMMITTED (AD-34).** A rival claim's *uncommitted* `confirmed`
  once made the other claim's `%EXACT(State) = 'live'` sibling UPDATE match zero rows — two confirmed
  rows on one target and two vendor PUTs. The per-target lock closes it; any new
  conditional-update-plus-cancel pattern carries the same hazard.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` normalized at the port boundary with the raw kept for log and ledger only;
  `detail.violations[]` is projected to `{field, code}` before it reaches the model. `Api/Error.cls`
  validates by **shape**, so a new `PROPOSAL.*`/`PROHIBITED.*` code needs no contended edit. Proposal
  and ledger state are OcuPilot's own protected state through `Kernel/State`'s row-versioned guarded
  save (`STATE.CONFLICT`, 409); IRIS references are **weak** — scoped identity as data, never a foreign
  key. Audit events are registered with `Security.Events.Create()` at install under OcuPilot's Source.
- **Tests that can fail.** Geometry belongs in the browser runner, which loads the **deployed** bundle,
  and its specs use `panel-spec.mjs`'s `saveAndSettle()` (DW-1169). `%UnitTest` classes run **one at a
  time**. Every handler gets an HTTP test on status, content type and body shape; every tool a
  round-trip test over its generated schema; a denial test uses a purpose-built least-privileged role,
  never `%Operator`. Epic 13's gates bind: `Test/EndpointCoverage.cls` holds probes equal to compiled
  routes and `Test/SurfaceCoverage.cls` rows equal to registered tools, so a new route or write tool
  must declare its row or the `instance` job reddens. `smoke.sh`'s `executed=` count is **not** a stable
  invariant (45 clean, 44 after a browser run) — read the skip lines, not the number (DW-1402).
- **Prefer the shape that cannot be quietly wrong over the shape that is only right if an enumeration
  was complete** — 5.5's allowlist plus `additionalProperties: false` is the worked example. A deferred
  entry naming an AD's own invariant is standing work, not a deferral candidate. A hedged finding is
  **probed, not filed**. Rule 19 mutations run on the runner's own throwaway (DW-1185).

## UX & Interaction Patterns

- **The card.** Target heading; instance-computed diff rows; the rest behind "N unchanged fields"
  (**rows still to be supplied — DW-1223**); rationale and expected impact **labeled** on the agent
  tint; "Reverse: <how to undo>" where one exists. Footer: "Runs as <user name>, with your
  privileges." and "Confirm here; sending a message cancels this proposal". Countdown "Expires in
  m:ss" from 10:00, `warning` from 1:00, announced **once**.
- **Confirm.** In flight the button shows progress and is `aria-disabled` with focus kept; on success
  the buttons become "Confirmed by <user name> · hh:mm:ss", which takes focus. Terminal lines:
  "Canceled — by your message", "Canceled — a sibling proposal was confirmed", "Expired", "target
  changed, re-propose"; a fingerprint mismatch raises a warning banner inside the card offering
  **only** Re-propose. **One decision at a time** — cards stack with their own Confirm and Cancel,
  there is **no "Confirm all"**, a typed message cancels every live proposal, **Stop cancels nothing**.
- **Showing the change.** The screen **re-fetches in place** preserving sort, filter, selection and
  scroll, and **highlights within two seconds**, scrolling into view: change-highlight background, 3px
  agent bar, a "Changed" tag, settling over two seconds and holding until the next interaction. When
  the screen is **not** open a toast names the change and carries "Open in <screen>". Toasts are
  **never** used for errors (banners are) nor to confirm what the user just did on the open screen; the
  bus **does not cross tabs**. A live proposal against a screen's entity type **pauses** its
  auto-refresh with the chip "Auto-refresh paused — a proposal is awaiting confirmation".
- **Marking.** The **collapsed** tool-call line carries "done · audit not marked" in `warning` and the
  reply mentions it. The panel's `auditingOffBanner` states **only** that agent writes are not being
  marked and carries no link until Story 7.4; **its absence is never a positive claim that marking
  works**. A reachable refusal renders through `toolCallStatusFailed` ("failed — <reason>") on the card
  that was refused.

## Cross-Story Dependencies

- **Ledger routes.** 5.8: DW-1223, DW-1208 (decided), DW-1252, DW-1382. 5.10: DW-1171, DW-1206
  (validate `secretArguments` against the same declared field set `fingerprintExcludes` uses). 5.11:
  DW-269 (the vendor tasks LIST coerces every task's `Suspended` to false, so a suspended task cannot
  be told from a running one in a list read — declare the `INFO` `rowGet` AD-36 names or state why the
  story does not need it) and **DW-1419** (AC4's "with the entity selected" is unimplemented — the
  toast's route names the entity but nothing selects it, because `list-page.ts` injects no
  `ActivatedRoute` and never reads the id segment; 5.11's own target is the Task schedule list **with
  that task selected**, so that clause lands here). **DW-456** stays owner-level.
- **Per-area shape.** 5.9 writes `Security.User`, one of the 28 non-merging endpoints, and must prove
  by test that a two-field change leaves every other field intact; privilege grants (`%All`, any
  `%Admin_*` role) are **prohibited at any confirmation level**. 5.10's disable-auditing write is
  declared **destructive** (warning inside the card, `destructive` bar, 14.7's typed-name
  confirmation), deliberately **not** in the prohibited set, and must be the **same operation** Story
  7.4's Auditing screen later calls; the disable/re-enable round trip is a single demo sequence, never
  a resting state. 5.13 has no admin API endpoint: `SYS.ApplicationError.DeleteByNamespace` with one
  explicit save/restore to `%SYS`, the namespace a **parameter** from the drilled descriptor state
  (never the route's `?ns=`), the gate resolved per namespace at call time, and the fingerprint the
  **enumerated id set** captured at proposal time.
- **Footprint.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**; modifying a
  file a **concurrent** epic created is a Clarification. Epic 5's client files:
  `ui/src/app/shell/panel.ts`, `panel.spec.ts`, `proposal-card*`, `reply*`, `tool-call-card*`,
  `core/proposal-view.ts`, `core/turn.ts`. `shell/panel-resize-handle*` was **released to trunk** (not
  transferred): Epic 4 created it and has merged, so Epic 5 and Epic 15 alike may edit it, verifying
  against the other's pushed head immediately before. Genuinely Epic 15's, live on 15.5:
  `ui/src/app/shell/{header,account-menu,side-bar,command-box}*`, `ui/src/styles/**`.
  `src/OcuPilot/Api/Router.cls` and EXPERIENCE.md's Fixed-strings table are epic-wide **shared-append**
  — tail only, union merge. **Epics 4, 6 and 13 have merged; their files are the trunk's.**
- **Forward references.** 5.11 navigates to the Task schedule list with the task selected; retargeting
  at the details route is the one-line change assigned to 7.6. Typed-name confirmation arrives in full
  at 14.7. Epic 8 depends on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10. **Rule 27** governs the epic's
  burn-down gate, not the stories: only entries blocking the 2026-09-27 floor or a downstream epic's
  story are chartered there; the rest are re-owned to the range-end cleanup story chartered after Epic
  12 merges.
