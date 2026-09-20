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
- Story 5.5: Prohibited actions are absent from the tool set — **done** (`be39be4`)
- Story 5.6: The agent marker, and what happens when it fails ← **next**
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

**Story 5.4's settled contract.** Execution is **strictly as the user**: every tool body runs in the
calling process under the caller's own `$USERNAME`/`$ROLES`, with no service account and no
credential other than the user's own. The tool set advertised to the model is the **full set** —
privilege is checked at call time, never by hiding tools — and a tool's 403 is byte-for-byte the
screen's 403, surfaced as `failed — <resource>` and **reported, never retried** with another
credential or another path. The **only elevation on the request path** is AD-9's privileged routine
application, joined by a **second, narrowly scoped application for one identity read** — whether the
authenticating user's account is enabled. AD-8 and AD-9 were **amended under Rule 5 on 2026-09-20**
to say so; it is a settled contract, not an exception to argue. `New $ROLES` is confined by
`scripts/check-objectscript.py` to `Kernel/State/Base.cls`, so the escalation has **exactly one legal
home**. Neither escalation is in effect while any tool, port or provider code runs. A drifted
`OcuPilotIdentity` application surfaces as **`503 INSTALL.UNREADABLE`, never `AUTH.DISABLED`**
(AD-38). Each port declares and evaluates its own gate before any call; the log ports inherit no
vendor gate and `/api/monitor/metrics` answers anonymously on this instance.

**Story 5.5's settled contract, for 5.6 to consume.** `Kernel/Proposal/Prohibited.cls` is AD-10's
**one home**, reached only through `Write.ProhibitedClass()` at the single seam in
`Confirm.Transition` — before the restraint verdict, the pairs, the fingerprint re-read and the port
call. The set **permits by name and refuses by shape**: `webapp.list.update` advertises an allowlist
of four reviewed fields (`AutheEnabled`, `Description`, `Enabled`, `Resource`) with
`additionalProperties: false`, and every other changed field is refused — so a vendor property a
later IRIS build adds is covered without having been enumerated. A fifth field is added in exactly
two places, `Screen.Tool.WebAppUpdate.PERMITTEDFIELDS` and
`Kernel.Proposal.Prohibited.PermittedChangeFields`, and the suite fails if only one is added. An
entity type the set does not evaluate is refused wholesale (`PROHIBITED.UNCOVERED`), so Stories
5.9–5.13 must each add their type's predicates before their write tool can register. The set is
defined by **effect, not verb** and covers: deleting or disabling the current user, the last `%All`
holder or `_SYSTEM`; **granting privilege through any path** (Level 4, not proposable at any
confirmation level); disabling the path that serves OcuPilot (application, web service,
superserver); terminating IRIS system processes; deleting OcuPilot's own applications, resource,
role or database. Governance can disable a permitted tool; it can **never** enable a prohibited one.

**Identity canonicalization is new and touches everything (AD-13, amended under Rule 20).**
`EntityRef.NormalizedId(type, id)` decides the canonical form per entity type, beside
`EntityRef.Validate`; `EntityRef.Key` builds from it; `EntityRef.Canonical` re-reads a stored key;
and `Propose.GuardedClaimAndClose` takes AD-34's per-target lock and runs its sibling cancel on
**both** the canonical ref and the ref as stored. For `web-application` the rule is case-fold plus
strip trailing slashes — what the instance itself does. A type with no rule canonicalizes to itself;
a later write-tool story adds its own. Two consequences downstream stories must know: the `TargetRef`
a proposal, the ledger and the panel show is now the **canonical** spelling, not the one the agent
typed; and the client mirror `ui/src/app/core/entity-ref.ts` does **not** normalize yet (DW-1364,
routed to Story 5.7, which is its reopen condition).

**Story 5.6 — what the marker must prove.** Every confirmed write emits an audit event carrying the
agent marker, the proposal id, the tool, the target identity and the user, **alongside** the vendor's
own change event for the same operation, and either record locates the other. The same write made by
hand through a screen emits **no** such marker — the marker is what distinguishes agent from human.
The audit viewer's agent-marker filter shows the write under the user's own name, described as
coming through the agent co-pilot. When the marker fails, **the write does not fail and the failure
does not propagate**: the condition is recorded on the ledger row and shown on the tool-call card as
"done · audit not marked" in `warning` on its **collapsed** line, never only in the body, and the
reply mentions it. `$System.Security.Audit()`'s return value is checked, because it silently returns
0 and drops the event when its Source/Type/Name triple was never registered. When auditing is off on
the instance, or OcuPilot's own events are disabled, the banner "Agent writes are not being marked.
Auditing is off on this instance." shows to every user and the executor records the condition on each
write; the banner carries its sentence alone until Story 7.4's Auditing configuration screen makes
its link and "Turn auditing on" action live. The ledger row is created **before** the port call and
**finalized after** it, recording what was **actually executed** — resolved target, fields actually
sent, privileges actually exercised — not what the proposal predicted, with secret-typed fields
excluded at write time rather than redacted afterwards. The pairing metric measures the **pair**: no
confirmed proposal without a marked event and no marked event without a confirmed proposal, which
holds precisely because a failed marker is itself recorded and surfaced rather than silent.

**Ahead in the epic.** One change event, screens re-fetch in place and highlight within two seconds
(5.7). The six area writes are 5.8–5.13.

## Technical Decisions

- **Governing ADs.** 5.6: **AD-15** (registered events under OcuPilot's own Source; marker alongside
  the vendor's `%System/%Security/*Change`; emission never fails or propagates), **AD-41** (turns and
  the ledger are bounded; the row finalized after the write, recording what was executed), **AD-46**
  (OcuPilot's markers are ordinary audit rows, never hidden; the ledger is protected per-user state
  and its cross-user gate lives with the ledger, not the screen), **AD-13 as amended**. Then 5.7:
  AD-14, 43, 13. AD-8/AD-9 as amended, AD-10, AD-34, AD-40, AD-1, AD-29, AD-31, AD-35, AD-7
  (amended), AD-30, AD-33 and AD-12/AD-39 hold throughout.
- **Audit events must be registered.** `Security.Events.Create()` at install under OcuPilot's own
  Source; the `Audit()` return value is checked at every emission site, never discarded.
- **IRIS's default isolation is READ UNCOMMITTED, and that fact is load-bearing (AD-34).** The 5.3
  review found a real violation: a rival claim's **uncommitted** `confirmed` made the other claim's
  `%EXACT(State) = 'live'` sibling UPDATE match zero rows, so it never requested the lock — two
  confirmed rows on one target and two vendor PUTs. The per-target lock closes it. Any new
  conditional-update-plus-cancel pattern in this epic carries the same hazard.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone.** The
  vendor's gate is a **lower bound**: read the backing query or class's own privilege check in
  `irislib/`, then run the read as a **real least-privileged principal** on a throwaway and add what
  the instance still refuses. A port without a named gate is a review failure.
- **Every browser spec this epic writes uses `saveAndSettle()` (DW-1169, closed on a
  reproduction).** Waiting on a value the test itself typed is **vacuous** — the field reads it
  before any request leaves — so the spec walks on while the save is in flight, and
  `switches.store.ts`'s `if (this.savingValue) return false` plus the page's `if (this.busyFlag)
  return` **absorb** the next press with no error and no effect. An out-of-band `fetch` does not
  close the gap either. `ui/browser/panel-spec.mjs` exports `saveAndSettle()`, which presses Save and
  waits for the form bar's `role="status"` element.
- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations
  merge; sending only changed fields to one of the other 28 erases every omitted field. Read fresh,
  apply the diff, send the complete property set — merged over the fresh read's whole object.
- **Proposal and ledger state are OcuPilot's own protected state**, written through `Kernel/State`'s
  row-versioned guarded save (`STATE.CONFLICT`, 409). References to IRIS objects are **weak**:
  scoped identity as data, never a foreign key.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` text normalized at the port boundary with the raw kept for log and ledger only;
  `detail.violations[]` is projected to `{field, code}` before it reaches the model. `Api/Error.cls`
  validates a code by **shape**, so a new `PROPOSAL.*` or `PROHIBITED.*` code needs no contended edit.
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
- **Epic 13's coverage gates are now on the trunk and bind this epic.**
  `src/OcuPilot/Test/EndpointCoverage.cls` holds declared probes equal to compiled routes and
  `Test/SurfaceCoverage.cls` holds coverage rows equal to registered tools — a new route or a new
  write tool must declare its row or the `instance` job reddens. `ui/tools/ci.test.mjs` holds
  `scripts/ci-throwaway.sh`'s arming rosters equal to the classes declaring each variable. CI now
  runs **seven** jobs (a `package` job was added).

## Standing rulings

- **A deferred entry that names an AD's own invariant is not a deferral candidate** — Rule 6 already
  grades it high, so it is standing work on the story that owns it. Check that the invariant is
  genuinely named, rather than pattern-matching the rule onto an entry that merely sounds like it.
- **Prefer the shape that cannot be quietly wrong over the shape that is only right if an
  enumeration was complete.** 5.5's allowlist-plus-`additionalProperties: false` is the worked
  example: a vendor field nobody enumerated is refused rather than silently permitted.
- **Rule 19 falsifiability mutations run on the runner's own throwaway container, never on the
  shared dev instance** (DW-1185). For slot A that is `ocupilot-ci` on 52776/1975.
- **A file another epic created is a Clarification only while that epic is a concurrent writer.**
  Once that epic merges, the file is the trunk's and is edited like any other.

## Instance and slot

Every IRIS MCP call from this runner carries `server: "ocupilot-slot-a"`. The slot's dev container is
`ocupilot`; never `up`, `down`, stop, remove or recreate it. Its throwaway is `ocupilot-ci` on
52776/1975, for which **there is no MCP profile** — it is driven by `docker exec` plus
`scripts/ci-unit-test.sh` / `ui/tools/ci-runner.mjs`.

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
- **For 5.6 specifically:** the collapsed tool-call line carries "done · audit not marked" in
  `warning` — collapsed, not only in the body — and the reply mentions it. The panel banner "Agent
  writes are not being marked. Auditing is off on this instance." shows to every user, in the panel's
  established banner order and its reserved `not-marked` slot, and carries no link until 7.4. A
  refusal the user can reach renders through the existing `toolCallStatusFailed` string
  (`failed — <reason>`) and the agent states the refusal rather than retrying.

## Cross-Story Dependencies

- **Story 5.6's ledger inbox is five entries.** **DW-1348** (the one 5.5 sent it, and the reason this
  is 5.6's and not `range-end-cleanup`'s): a confirm refusal that leaves the proposal row live is
  invisible in the panel — `turn.ts decideProposal` records an outcome only when the refusal carried
  `detail.state`, and `panel.ts onCardConfirm` drops its own decision in its `finally` — so a
  prohibited or restrained refusal shows the user nothing and the card simply offers Confirm again,
  making 5.5's floor-blocking prohibited set unobservable from the user's seat. AD-30's restraint
  refusal has the same shape. **DW-1305** and **DW-1321** together settle the ledger row's own
  contract: an empty `RequiredPairs` must distinguish no-pairs-*needed* from no-pairs-*known* (today
  every such row, including every `llm` row from the default landing screen, is withheld from every
  cross-user reader), and the column currently carries three incompatible meanings — a requirement
  evaluated against the caller, a tool's unchecked declaration, and the originating screen route's
  pairs — which `ViewForUser` gates identically. **DW-1309**: the provider port's gate evaluates the
  calling process where AD-31 has the turn job re-validate against the **turn owner's** live grants.
  **DW-1174**: the audit browser spec's agent-marker leg renders every OcuPilot-source row, so it
  times out on an instance that has been tested on for days — scope it to this proposal's own marker.
- **Three `decision-pending` entries remain owner-level and are not settled inside a story.**
  **DW-456**: shipped registry-layer classes already name kernel and API classes the spine's
  direction line forbids. **DW-1208**, decided: Release 1 ships the **`%All`-only write**, with the
  limitation stated in the story and, if the screen can carry it, in user-facing text naming
  `%Admin_Secure:WRITE`. **DW-1206** lands *with* 5.10, validating `secretArguments` against the same
  declared field set `fingerprintExcludes` already uses.
- **Footprint, settled.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**: any
  epic creates files there freely, and modifying a file a **concurrent** epic created is a
  Clarification. `ui/src/app/core/proposal-view.ts` and `core/turn.ts` are Epic 5's, as are `panel*`,
  `proposal-card*`, `reply*`, `tool-call-card*`. **`src/OcuPilot/Api/Router.cls` and EXPERIENCE.md's
  Fixed-strings table are epic-wide shared-append** — tail only, union merge expected. **Epic 15** is
  live on slot B and holds `ui/src/app/shell/{header,account-menu,side-bar,command-box}*` and
  `ui/src/styles/**`. **Epic 13 has merged and been torn down**: `ui/tools/ci*.mjs`,
  `.github/workflows/**`, `scripts/`, `Install/Uninstall*`, `module.xml` and `spec/**` are the
  trunk's now, and its coverage gates bind (see Technical Decisions).
- **Other standing routes.** 5.7 carries DW-1364; 5.8 DW-1223; 5.10 DW-1171 and DW-1206; 5.11 DW-269,
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
