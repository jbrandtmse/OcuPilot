# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once; 5.8 and 5.9 proved it end to
end in two real areas. **5.10–5.13 exercise that finished path once per remaining area and add
nothing to it** beyond their own type's prohibited predicates.

## Stories

- Stories 5.0–5.9 — **done**: the whole write path, plus the Web applications and Permissions area
  legs. What survives is in the "Settled" blocks below; nothing there is re-decided.
- Story 5.10: Security and secrets — disable and re-enable auditing ← **next**
- Story 5.11: Tasks — resume a task suspended after an error
- Story 5.12: OS management — suspend and resume a process
- Story 5.13: Logs — delete application errors by namespace

## Requirements & Constraints

### Story 5.10 — the next story's own subject

Disable auditing, then re-enable it, through the admin API's audit endpoint. The card carries the
warning "Agent writes will no longer be marked in the audit database." **inside** the card; the write
is declared **destructive** (warning, `destructive` bar, 14.7's typed-name confirmation) and is
deliberately **not** in the prohibited set — the restraint is confirmation friction, not absence. It
must be the **same operation** Story 7.4's Auditing screen later calls. No screen: the visible effect
is the panel's "Agent writes are not being marked. Auditing is off on this instance." banner, which
appears immediately for every user and clears the moment the condition does. The disable marker lands
while auditing is still on and the re-enable marker once it is back, so the gap is visible on the
ledger rows rather than silent. The round trip is a **single demo sequence, never a resting state** —
acceptance includes returning the instance to the audited state.
`Security.Audit.Event` publishes **no body template** and its PUT is an **upsert**, so an event-level
change derives its field list from the underlying class, pins it with a test, and a body sent against
a target deleted since the read creates a stub rather than failing — which the fresh read plus
fingerprint already covers.

**5.10's ledger inbox is 10 entries — the largest of any remaining story** (`slice
5-10-security-and-secrets-disable-and-re-enable-auditing`). Most are reachable only once 5.10 ships
the first real secret field and `security.auditing.update`: DW-1171 (a dropped `SecurityChange`
emission logged as a configuration change), DW-1226 (`Mint.WarnsAuditingOff` answers false for a
non-boolean auditing argument, so `0`/`false`/null mints an auditing-off write with no warning),
DW-1227 (masked-field lookup keys on entity type rather than the proposal's own tool, is not filtered
to the diff's fields, and `screenForEntityType` has no test), DW-1232 (a Confirm disabled by an
unfilled masked field says nothing about why, and no published string exists to say it), DW-1244
(`Mint`'s audit-warning constants name a tool and a field that do not exist yet, and the only test
asserts them against themselves), DW-1246 (the in-card warning is a third polite live region in the
same frame, and the only shell `ocu-banner-warning` that is not `role=alert`), DW-1251 (the panel
hands confirm an empty secrets map, so AD-35's client half has no data path), DW-1278
(`ChannelProblem`'s accept arm and structured-secret guard are executed by no test), DW-1279
(`AdminPort`'s queueing path saves the request body to the vendor async task row, so the first
queueing mutating endpoint persists supplied secrets).

**DW-1206 is `decision-pending` and the lead must settle it at the spec gate before the story can be
planned on it.** `secretArguments` entries are validated against nothing while `fingerprintExcludes`
entries are, so one typo leaves a credential-named field settable and reachable by the model. The
open question is *which set* an entry must name — the write tool's settable fields, the declared
criterion params, or their union — because a read-only screen's secret **is** a criterion and
refusing it would be wrong. Raise it; do not build on a guess.

### Settled in Story 5.9 (`c93fff6`) — record, do not revisit

- `permissions.users.update` exists over the Users list's **own** read. `Enabled` is derived; `Roles`
  is AD-3's **authored** half, because the template answers `[]` so the derivation cannot type the
  element and AD-3 forbids inventing it; `EscalationRoles` is excluded. The pair set is exactly
  `UserList`'s two, with `%Admin_Secure:USE` — **never** `:WRITE`.
- `user` is in the prohibited set with the four refusals (current user, last `%All` holder,
  `_SYSTEM`, privilege grant), the `%All` refusal resting on a census over the **whole** population.
  `user:foldcase` is in `EntityRef.IDRULES` with a client twin, so two spellings are one target and
  one lock.
- **The pattern 5.9 taught — the single most useful thing to carry forward. Five separate instances
  in one story of a safety predicate whose refusing branch never ran against the real body over a
  real population.** The implement stage's own review found three, QA a fourth, and the code review a
  fifth that was a **real grant path**: the privilege predicate asked only about role *names* and
  recursed roles, never the **resources** a role carries, so adding `%Manager` answered
  `prohibits=0`. Measured: `%Manager` carries `%Admin_FileSystemAccess:U` and `%Admin_Journal:U`;
  `%Operator` carries `%Admin_Operate:U` plus `%DB_IRISSYS:RW`; `%SecurityAdministrator` carries
  `%Admin_Manage:U`; `%Developer` and `%SQL` carry none. IRIS ships **no** role whose *name* starts
  `%Admin_`, so the shipped name test was dead code and four privilege-grant legs had been passing
  for the wrong reason. **5.10–5.13 each add their own type's prohibited predicates, so this is the
  region to distrust: a fixture seam that REPLACES a safety method rather than arming its input
  produces a green suite over an unexercised refusal.**
- DW-1412 **resolved**: the toast is offset by the panel's live width, published as
  `--ocu-panel-live-width` on `.ocu-shell`.
- DW-1431 **resolved as the documented half only**. Its planned `AccessCheck` override was reverted
  on measurement: every OcuPilot class lives in the database the caller cannot read, so the override
  itself raises `<PROTECT>` and turns a bodyless 403 into a vendor 500. The prerequisite is
  documented instead.
- DW-1429 **dropped** — measurement refuted its premise.

### Four decisions settled and terminal — no later stage reopens them

- **DW-1428.** A disclosed field value is **not** truncated; it stays unbounded. A bound contradicts
  "every field stays available", and a cross-request cache for the cost half would be fail-**open**
  on a security decision.
- **DW-1430.** When a caller fails both the privilege-pair gate and AD-30's read-only verdict, the
  **implemented refusal order stands, by design** — both orders satisfy AD-30 and AD-8, and the order
  is pinned in the method comment.
- **DW-1412** and **DW-1429**, as recorded above.

### Settled in 5.7–5.9, load-bearing for every remaining area story — built once, only pinned again

The instance mints every proposal from a fresh read (server id, user, conversation, tool, resolved
arguments, AD-13's scoped target triple, a fingerprint over the complete property set the write will
send minus descriptor-declared side-effect fields, the diff, a single-use token, ten-minute expiry);
secrets are never stored and never accepted from the model. Confirm is a **separate authenticated
POST** (`Kernel/Proposal/Confirm.cls`), absent from the registry, refused when the caller carries the
turn marker, usable only by the minting user; it executes the **stored** arguments and payload, and
any client key other than the descriptor's declared secret fields is **rejected outright, not
ignored**. `Propose.GuardedClaimAndClose` is **one** conditional UPDATE inside a per-target lock that
burns the token, writes the terminal state and cancels same-target siblings in one transaction, with
the vendor PUT after `TCOMMIT`; every gate — prohibited set, `Restraint.Verdict`, the declared
`(resource, permission)` pairs, the fingerprint re-read — is evaluated **inside that transition**,
never at the minting tool call. Execution is **strictly as the user** under the caller's own
`$USERNAME`/`$ROLES`; the advertised tool set is the **full** set and privilege is checked at call
time, never by hiding tools. The marker is emitted from **one site** in `Confirm.Transition` after the
write reads OK, with `$System.Security.Audit`'s return value **checked** (it returns 0 and silently
drops an unregistered triple). An entity type the prohibited set does not evaluate is refused
wholesale (`PROHIBITED.UNCOVERED`), so **5.10–5.13 must each add their type's predicates before their
write tool can register.** `smoke.sh`'s `agentwrite` and `auditmarker` checks **pass** (AD-45's one
confirmed agent write and its marker, inside the one smoke path).

- **The gate.** A write tool's pair set **is the screen's own declared set**, and an administrative
  resource on it is required at `USE`, **never `WRITE`** (AD-8 as amended 2026-09-21). Built-in
  `%Admin_*`, `%Service_*` and `%Development` carry no `WRITE`, so a `WRITE` pair is a gate only
  `%All` can pass; `USE` is what the vendor's editor checks
  (`%CSP.Portal.Application.CheckSecurity` is `Quit $System.Security.Check(pResource,"USE")`).
- **A write tool's permitted-field allowlist is declared in exactly two places** (the tool's
  `PERMITTEDFIELDS` and `Kernel.Proposal.Prohibited.PermittedChangeFields`) under
  `additionalProperties: false`, and the suite fails if only one is updated.
- **The disclosure has real rows.** `Kernel/Proposal/Disclosure.cls` projects masked `{field, value}`
  rows from the stored payload, so the "N unchanged fields" caption equals its rows with no second
  read; it is **masking, not withholding**, and fail-closed on anything not ordinary+literal in
  `ToolFields`. A leg asserting that an ordinary literal carries its **value** is required — an
  assertion running as `%All`, where the class-dictionary read never fails, proves nothing. A refused
  confirm records a write tool-call card reading "failed — <pair>".
- A confirmed write publishes **one** `changed` event carrying AD-13's scoped triple plus an `action`
  from a closed set (`created`/`updated`/`deleted`), **refused rather than defaulted**;
  `TurnStore.decideProposal` publishes it after the `proposal-closed` that closes AD-43's pause, in
  that order, and `DefinitionForm.publishChange()` takes its action from the mode. The per-type id
  rule is a **declared table** — `EntityRef.IDRULES`/`IDRULENAMES` — that `screen-mirror.mjs` mirrors
  and **throws at prebuild** on an undeclared rule, unknown type, a rule the client cannot implement,
  or a duplicate type; `REFSEPARATOR` likewise. No second identity rule in TypeScript (AD-5).
- **Sharp edge for any story that marks a row.** `Mint` stores a **folded** `targetRef` while a row's
  key is the name the instance returns, **case-preserved**. Two HIGH defects came from that gap,
  **both with the whole suite green**. `DataTable.viewKeyFor` and `changedKeyFor` are the
  reconciliation points; a read-back takes the spelling the **instance** returns, never `target.id`.
  `ProposalFixture`'s mixed-case write-target trio is the lever. The off-screen toast is already
  built (store, stack of three, two lifetimes, hover/focus hold, dismiss, "Open in <screen>") with
  real browser coverage — consume it, never rebuild it.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations merge;
  sending only changed fields to one of the other 28 erases every omitted field. Read fresh, apply
  the diff, send the complete property set merged over the fresh read's whole object.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check in `irislib/`, then
  run the read as a real least-privileged principal on a throwaway and add what the instance still
  refuses. A port without a named gate is a review failure — least-privileged driving found three
  defect classes this epic that no `%All` suite could see.
- **A mutating `AdminPort.Invoke` refuses a non-object `pBody`.** A `%String` body used to answer 200
  with the object unchanged and write nothing — the silent-success shape this epic rules against.
- **Governing ADs.** AD-14 (one change event; screens **re-fetch, never patch**; closed kernel-owned
  entity-type enum keyed from the screen descriptor), AD-43 (one shared auto-refresh framework;
  `proposal-open`/`proposal-closed` ride the same bus and carry the pause), AD-13 as amended (every
  boundary-crossing reference carries `(entity type, scope, id)`, scope being the namespace or the
  constant `instance`), AD-8 as amended above. AD-45, AD-41, AD-15, AD-46, AD-9, AD-10, AD-34, AD-36,
  AD-40, AD-1, AD-29, AD-31, AD-33, AD-35, AD-44, AD-12/AD-39 hold throughout.
- **IRIS's default isolation is READ UNCOMMITTED (AD-34).** An *uncommitted* rival `confirmed` once
  made a sibling `%EXACT(State) = 'live'` UPDATE match zero rows — two confirmed rows on one target,
  two vendor PUTs. The per-target lock closes it; any new conditional-update-plus-cancel pattern
  carries the same hazard.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` normalized at the port boundary with the raw kept for log and ledger only;
  `detail.violations[]` is projected to `{field, code}` before it reaches the model. `Api/Error.cls`
  validates by **shape**, so a new `PROPOSAL.*`/`PROHIBITED.*` code needs no contended edit. Proposal
  and ledger state go through `Kernel/State`'s row-versioned guarded save (`STATE.CONFLICT`, 409);
  IRIS references are **weak** — scoped identity as data, never a foreign key. Audit events are
  registered with `Security.Events.Create()` at install under OcuPilot's Source.
- **Tests that can fail.** Geometry belongs in the browser runner, which loads the **deployed**
  bundle, and its specs use `panel-spec.mjs`'s `saveAndSettle()` (DW-1169). `%UnitTest` classes run
  **one at a time**. Every handler gets an HTTP test on status, content type and body shape; every
  tool a round-trip test over its generated schema; a denial test uses a purpose-built
  least-privileged role, never `%Operator`. Epic 13's gates bind: `Test/EndpointCoverage.cls` probes
  equal compiled routes and `Test/SurfaceCoverage.cls` rows equal registered tools, so a new route or
  write tool must declare its row or the `instance` job reddens. `smoke.sh`'s `executed=` count is
  **not** a stable invariant — read the skip lines, not the number (DW-1402).
- **Three measured traps in the verification loop.** `ui/tools/ci-runner.mjs` does **not** load
  source, so a browser result means nothing until source is synced, compiled and `Installer.Install`
  has run. `npm test` does **not** run the browser suite (`test:browser` is separate, with its own
  harness build), so "build plus `npm test`" never verifies a merge. And, measured at 5.9, the
  **browser suite is not idempotent on a reused instance**: `resetRememberedState` clears only the
  three value kinds, so `recent` rows accumulate and turn a re-run red on preconditions that were
  never about the story under test (DW-1447, DW-1448) — clear `OcuPilot_Kernel_State.Pref` before
  trusting any local re-run.
- **Three standing rulings.** **Rule 29**: the story's **own** browser spec files, ObjectScript
  classes and client tier run inside the implement loop; the **full** browser suite and the **full**
  ObjectScript sweep run **once**, before `dev_complete`. **Rule 28**: a story's CI run resolves
  before the *next* story's implement spawn. **Rule 27**: the epic's burn-down charters only
  floor-blocking or downstream-blocking entries; the rest are re-owned to the range-end cleanup story.
- **Prefer the shape that cannot be quietly wrong over the shape that is only right if an enumeration
  was complete.** A deferred entry naming an AD's own invariant is standing work, not a deferral
  candidate; a hedged finding is **probed, not filed**; Rule 19 mutations run on the runner's own
  throwaway (DW-1185).

## UX & Interaction Patterns

- **The card.** Target heading; instance-computed diff rows; the rest behind "N unchanged fields"
  with real masked rows behind the caption; rationale and expected impact **labeled** on the agent
  tint; "Reverse: <how to undo>" where one exists. Footer: "Runs as <user name>, with your
  privileges." and "Confirm here; sending a message cancels this proposal". Countdown "Expires in
  m:ss" from 10:00, `warning` from 1:00, announced **once**.
- **Confirm.** In flight the button shows progress and is `aria-disabled` with focus kept; on success
  the buttons become "Confirmed by <user name> · hh:mm:ss", which takes focus. Terminal lines:
  "Canceled — by your message", "Canceled — a sibling proposal was confirmed", "Expired", "target
  changed, re-propose"; a fingerprint mismatch raises a warning banner offering **only** Re-propose.
  **One decision at a time** — no "Confirm all", a typed message cancels every live proposal,
  **Stop cancels nothing**.
- **Showing the change.** The screen **re-fetches in place** preserving sort, filter, selection and
  scroll, and **highlights within two seconds**, scrolling into view: change-highlight background,
  3px agent bar, a "Changed" tag, settling over two seconds and holding until the next interaction.
  When the screen is **not** open a toast names the change and carries "Open in <screen>", placed
  bottom-right of the content area offset by the panel's live width (`--ocu-panel-live-width`).
  Toasts are **never** used for errors (banners are) nor to confirm what the user just did on the
  open screen; the bus **does not cross tabs**. A live proposal against a screen's entity type
  **pauses** its auto-refresh with the chip "Auto-refresh paused — a proposal is awaiting
  confirmation" — on AD-43's seven roster screens only, needing **both** the screen's own
  `refreshes` declaration and the roster row.
- **Marking.** The **collapsed** tool-call line carries "done · audit not marked" in `warning` and
  the reply mentions it. The panel's `auditingOffBanner` states **only** that agent writes are not
  being marked and carries no link until Story 7.4; **its absence is never a positive claim that
  marking works**. A reachable refusal renders through `toolCallStatusFailed` ("failed — <reason>")
  on the card that was refused.

## Cross-Story Dependencies

- **Ledger routes.** 5.10: the 10 entries above, DW-1206 needing a lead decision at the spec gate.
  5.11: DW-269 (the vendor tasks LIST coerces every task's `Suspended` to false, so a suspended task
  cannot be told from a running one in a list read — declare the `INFO` `rowGet` AD-36 names or say
  why not) and **DW-1419** (AC4's "with the entity selected" is unimplemented: `list-page.ts` injects
  no `ActivatedRoute` and never reads the id segment, and 5.11's target is the Task schedule list
  **with that task selected**). **DW-456** stays owner-level.
- **Per-area shape.** 5.12's `Process` is one of the five endpoints publishing **no** body template —
  action-style with a trivial body, never a hand-typed field list. 5.13 has no admin API endpoint:
  `SYS.ApplicationError.DeleteByNamespace` with one explicit save/restore to `%SYS`, the namespace a
  **parameter** from the drilled descriptor state (never the route's `?ns=`), the gate resolved per
  namespace at call time, and the fingerprint the **enumerated id set** captured at proposal time;
  its read tool returns summary fields only, variable tables never reaching the model.
- **Footprint.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**. Epic 5's
  client files: `ui/src/app/shell/panel.ts`, `panel.spec.ts`, `proposal-card*`, `reply*`,
  `tool-call-card*`, `core/proposal-view.ts`, `core/turn.ts`. `src/OcuPilot/Api/Router.cls` and
  EXPERIENCE.md's Fixed-strings table are epic-wide **shared-append** — tail only, union merge.
  **Epics 2, 3, 4, 6, 10, 13 and 15 have all merged and are integrated into this branch; their files
  are the trunk's, and Epic 5 is the only live epic — no concurrent-epic contention remains.**
- **Forward references.** Retargeting 5.11's navigation at the details route is the one-line change
  assigned to 7.6. Typed-name confirmation arrives in full at 14.7. Epic 8 depends on Epics 5 and 6;
  Epic 11 on 4, 5, 6 and 10.
