# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, and then
finds that same change in the IRIS audit database marked as having come through the agent — in
**each** of the six areas. This is the product's entire claim and the end of build step 2: SM-3 (six
areas, six confirmed writes) and SM-4 (the one-minute demo) are both met here. Stories 5.1–5.7 build
the write path once — the server-minted proposal, the card, confirm as one atomic transition,
execution as the user, the prohibited set, the audit marker, the change-event bus — and 5.8–5.13
exercise it once per area.

## Stories

- Story 5.0: Epic 4 deferred cleanup — **done**
- Story 5.1: The proposal is minted on the instance, from a fresh read — **done**
- Story 5.2: The proposal card — the diff the user reviews — **done** (`a8be036`, `2767f5a`)
- Story 5.3: Confirm is user-originated, and the write is one atomic transition ← **next**
- Story 5.4: Execution strictly as the user
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

**Settled upstream and consumed, not re-decided (5.1, 5.2).** The instance mints the proposal and
the client never authors one: server-issued unguessable id, user, conversation, tool, full resolved
arguments, the scoped target identity `(entity type, scope, id)`, a fingerprint over the **complete
property set the write will send** minus descriptor-declared side-effect fields, the diff, and a
single-use token, expiring on a server-side 10 minutes. Secret-typed values are never stored and
never accepted from the model. The payload is the whole merged object; the diff is only what the
user reviews. The card renders that wire row, with its phase model, countdown and terminal status
lines already built.

**Story 5.3 — the properties that make confirmation a system property.** Confirm is a **separate
authenticated, user-originated request** carrying the proposal id, executing the **stored**
arguments. The only keys a client may supply are the descriptor's declared secret-typed fields for
that tool; **any other key is rejected outright, not ignored**, and the identifying key is never
accepted from the client. Only the minting user can confirm. Confirm re-evaluates privileges,
enforced read-only, the per-user read-only state, the definition's read-only flag and the kill
switch, re-reads the target and compares the fingerprint, and refuses on all five FR-17 conditions
— user, conversation, definition, read-only state, fingerprint — each with its own card state and
status line. Burning the token and committing to the write are **one atomic transition** under a
lock or conditional update exactly one caller wins; the loser is refused with the terminal state,
never retried. Siblings on the same scoped target are canceled **in that same transition**. Every
gate that decides whether a write may happen is evaluated **at the write, inside that transition**,
never at the tool call that minted the proposal.

**Ahead in the epic.** Execution is strictly as the user — in-process, no service account, no
credential but the user's own, the **full** tool set always advertised, a tool's 403 identical to
the screen's and never retried (5.4). Prohibited actions are absent from the tool set, defined by
effect not verb, with **exactly one home in the kernel** (5.5). Every confirmed write emits a
correlatable audit marker; a failed marker never fails the write (5.6). One change event, screens
re-fetch in place and highlight within two seconds (5.7). The six area writes are 5.8–5.13.

## Technical Decisions

- **Governing ADs.** 5.3: AD-40, AD-34, AD-6, AD-8, AD-30. Then 5.4: AD-1, 8, 9, 29, 31. 5.5: AD-10,
  34, 40. 5.6: AD-15, 41, 46. 5.7: AD-14, 43, 13. Area stories add AD-2; 5.13 adds AD-48. AD-7,
  AD-9, AD-33 and AD-12/AD-39 hold throughout. **AD-7's Rule was amended** (DW-445): per-step
  progress lives in OcuPilot's own protected storage (AD-33) keyed by turn id — the shipped
  `Kernel.State.Turn` and `Kernel.State.Step` tables — not a temp global.
- **The confirm barrier is explicit because in-process tools removed the HTTP one (AD-40).** The
  kernel carries an "acting on behalf of the model" marker through the turn job and every tool call;
  confirm is not a tool, is not in the registry, and refuses any call whose originating context is a
  turn. The marker shipped in 5.1 as `Kernel/Proposal/Caller.cls` — set once at the top of
  `Loop.Run`, cleared when it unwinds — so a request process that has never run a turn carries
  nothing, which is the condition confirm requires. A proposal is bound to its turn's outcome as
  well as its own expiry: a turn that ended **abnormally** leaves its proposals unconfirmable, while
  a turn that ended normally leaves them confirmable until expiry (a turn ends the moment it emits
  the card, so the ordinary path must not trip this).
- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations
  merge; the 28 that do not include `Security.User`, `Task.CRUD`, `Security.Resource`,
  `Security.X509Credential`, `Wallet.Secret`, `Security.Audit.Event` and all four
  `Security.OAuth2.*`. `Wallet.Secret` and `Security.Audit.Event` PUTs are **upserts**, covered by
  the fresh read plus fingerprint. `Process`, `Lock` and `Task.Manager` publish **no body template**
  and are action-style with a trivial body, never a hand-typed field list.
- **Two 5.1 review facts that constrain any later merge or digest work.** `Mint.Merge` must **not**
  pass an argument's own JSON type as `%Set`'s third argument — only `null|boolean|number|string`
  are legal, so array- and object-valued arguments are set without the hint.
  `Fingerprint.Canonical` must honour an exclusion path in the **bracket spelling the generator
  emits** (`path[]`), the only spelling the descriptor validator accepts for an array field.
- **Proposal state is OcuPilot's own protected state** (privileged routine application, `New $ROLES`
  frame, nothing spawned or re-entered from inside it), written through `Kernel/State`'s
  row-versioned guarded save (`STATE.CONFLICT`, 409). A `%Persistent` class name including its
  package stays within 29 characters — which is why the class is `Kernel/State/Propose.cls` with
  `[ SqlTableName = Proposal ]`. References to IRIS objects are **weak**: scoped identity as data,
  never a foreign key.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` text is normalized at the port boundary with the raw kept for log and ledger
  only, and `detail.violations[]` carries `{field, code, reason}`, projected to `{field, code}`
  before it reaches the model.
- **The entity-type vocabulary is one closed enum owned by the kernel**; the build fails on an
  unknown value. Change events, proposal targets, highlight targets and audit markers all carry the
  scoped triple, ids percent-encoded in one segment by the single shared encode/decode pair. Field
  lists and secret classification come from the build-time derivation, not from a story.
- **Audit events must be registered.** `$System.Security.Audit()` silently returns 0 and drops the
  event when its Source/Type/Name triple was never created, so the return value is checked.
- **A disabled account's live tokens is decided, not open (5.4).** DW-444 was decided at Epic 4's
  merge gate: **refuse it** — check `Enabled` at authentication and refuse `/refresh` for a disabled
  user, on the authentication and refresh path rather than inside the turn job. Build it; do not
  re-litigate it.
- **5.13 has no admin API endpoint and no invariant relaxes.** `SYS.ApplicationError.DeleteByNamespace`
  with one explicit save/restore to `%SYS` and the namespace as a **parameter** taken from the
  drilled descriptor state (never the route's `?ns=`); the gate resolves per namespace at call time;
  the fingerprint is the **enumerated id set** captured at proposal time; the read tool returns
  summary fields only.
- **Client and tests.** Zoneless `OnPush`; `core/` imports no `@angular/core`; every user-visible
  string from `core/strings.ts` and present in EXPERIENCE.md; design tokens only. Geometry belongs
  in the browser runner, which loads the **deployed** bundle (`npm run build`, then
  `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`). `%UnitTest`
  classes run one at a time, each landed in `%UnitTest_Result` before the next. Every handler gets an
  HTTP test on status, content type and body shape; every tool a round-trip test over its generated
  schema; a denial test uses a purpose-built least-privileged role, never `%Operator`.

## UX & Interaction Patterns

- **The card, as shipped in 5.2.** Target heading; changed fields as diff rows; the rest of the
  payload behind an "N unchanged fields" disclosure; "Agent's rationale" and "Expected impact" as
  the agent's **labeled** text on the agent tint; "Reverse: <how to undo>" where one exists. Footer:
  "Runs as <user name>, with your privileges." and "Confirm here; sending a message cancels this
  proposal". Countdown "Expires in m:ss" from 10:00, `warning` from 1:00, announced **once** at 1:00.
  Delete proposals show `field · value → (removed)` with no after-state and no Reverse line.
- **Confirm's own transition (5.3).** In flight, the button shows progress and is `aria-disabled`
  with focus kept; on success the buttons are replaced by "Confirmed by <user name> · hh:mm:ss",
  which takes focus, and Send returns to primary. Terminal status lines: "Canceled — by your
  message", "Canceled — a sibling proposal was confirmed", "Expired", "target changed, re-propose".
  A fingerprint mismatch also raises a warning banner inside the card above the footer and offers
  **only** Re-propose. Buttons are `aria-disabled` for the transition, never removed while focused;
  the restrained treatment is by role at full opacity so the diff stays readable at AA.
- **One decision at a time.** Cards stack in order, each with its own Confirm and Cancel; there is
  **no "Confirm all"**; while one is live Send drops to secondary so Confirm is the only filled
  button. A typed message cancels every live proposal and the agent's next reply says so and offers
  to re-propose; New conversation cancels the same way; **Stop cancels nothing**.
- **Auto-refresh pauses under a live proposal** — "Auto-refresh paused — a proposal is awaiting
  confirmation" — resuming on confirm, cancel or expiry (AD-43).
- **Later in the epic.** The changed row takes `change-highlight` with a 3px agent bar and a
  "Changed" tag, settles over 2s, holds until the next interaction, scrolls into view (5.7). Toasts
  name the change with "Open in <screen>", stack three deep, 10s without an action and 30s with one,
  pause while hovered or focused, never for errors.

## Cross-Story Dependencies

- **From Story 5.2 (done) — what 5.3 inherits and must not break.** The card's phase model and its
  terminal status lines (`ui/src/app/core/proposal-view.ts`, `ui/src/app/shell/proposal-card.ts`);
  the panel's countdown ticker and its clock seeding — `phaseFor` reads the clock, so the panel and
  the card cannot disagree once a countdown runs out; the conversation restore path
  (`Kernel/State/Entry.cls` now stores its turn key, `Api/Conversation.cls AttachProposals` joins on
  `seq`, `Kernel/State/Base.cls` gained `GuardedPairsWhere`); and the AD-11 markup pin on the
  agent-tinted fields. Confirm's request is the seam 5.2 deliberately left open.
- **Three rulings from 5.2 that 5.3 respects rather than re-opens.**
  1. **A restored card is shown expired, with Re-propose.** EXPERIENCE.md and DESIGN.md both state
     it, and DESIGN.md carries showing a restored card live as an explicit **Don't**. Changing it is
     an owner-level document decision, not a slice change.
  2. **AD-4 governs the body OcuPilot sends to the vendor endpoint, not the wire to the browser**,
     and it cites FR-17's collapsed unchanged fields approvingly. So the card's unmet "every field
     reachable" clause is a real gap — **DW-1223, routed to 5.8** — not an AD constraint.
  3. **The wire's single `canceled` word and the unconditional restore-to-`expired` override are
     correct only while every stored row is `live`.** The moment 5.3 writes `confirmed` or
     `canceled`, a reload would show a confirmed write as "Expired" with Re-propose. **DW-1225 is
     5.3's to fix.**
- **Story 5.3's ledger inbox is 15 entries** — name each against the story, to address or decline
  with a reason. The conditional-write primitive AD-34's transition sits on: **DW-407** (four writes
  still bypass `GuardedSaveIfCurrent`), **DW-412** (`RowVersion` left raised after a rolled-back
  save, so a retry is permanently refused), **DW-430** (`GuardedVersion` answers with different
  types and no-row sentinels across stores, and two methods lack the `Try/Catch` the others carry),
  **DW-435** (two first writers to a singleton can both create a row, `TOP 1` hiding the second).
  Then **DW-1184** (three `Test/Dispatch` helpers set `%request`/`%response` without `New`),
  **DW-1205** (`fingerprintExcludes` validated against the write body template while the digest is
  taken over the fresh GET, so AD-6's side-effect fields cannot be declared — it bites where confirm
  recomputes the digest), **DW-1209** (a row past `ExpiresAt` still reports `state: live` and nothing
  emits `proposal-closed` on expiry), **DW-1212** (the merge writes the model's JSON type over the
  instance's on the five `WebApp.App` fields answered as numbers), **DW-1224** (Re-propose is
  rendered and wired to nothing), **DW-1225** (above), **DW-1229** (the terminal status line is both
  a `role=status` live region and a focus target, so it may announce twice or not at all),
  **DW-1230** (the `confirming` and canceled-sibling phases and `confirmedAt` ship with no writer),
  **DW-1231** (a typed message cancels every live card before the send is known to have succeeded),
  **DW-1243** (a user cancel and New conversation never publish `proposal-closed`, so a bound screen
  stays paused for the rest of the ten-minute window), **DW-1245** (a one-line EXPERIENCE.md
  amendment: it states the status line takes focus unconditionally where the card guards on a button
  of that card having held it — the implementation is right and the sentence is imprecise).
- **Four `decision-pending` entries await the owner at the merge-gate decision sheet; none is
  settled and none is settled inside a story.** **DW-456**: shipped registry-layer classes already
  name kernel and API classes the spine's direction line forbids. **DW-1206** (binds 5.10):
  `secretArguments` entries are validated against nothing while `fingerprintExcludes` entries are,
  so a typo leaves a credential-named field settable. **DW-1207** (binds 5.8): `AutheEnabled`,
  `Resource` and `DispatchClass` are settable **ordinary** arguments of the first write tool, so a
  proposal could make a web application unauthenticated, drop its authorization resource, or point
  its dispatch at arbitrary compiled code — note that AD-10's prohibited set does not land until
  Story 5.5 while confirm lands at 5.3. **DW-1208** (binds 5.8): `webapp.list.update` needs
  `%Admin_Secure:WRITE`, so it is `%All`-only.
- **Other standing routes.** 5.4 carries DW-444 (decided — implement the refusal) and DW-1120; 5.6
  DW-1174; 5.8 DW-1223; 5.10 DW-1171; 5.11 DW-269, also routed at the epic level. DW-1210 and
  DW-1211 were re-owned to the range-end cleanup story.
- **From Epic 4 and earlier.** The turn job with its progress and lease contract; `Dispatch`'s gate
  chain and its restraint branch for write-kind tools; the ledger (one row per call, `RequiredPairs`,
  schema-driven redaction, finalized **after** the write and recording what was actually executed);
  the panel with its banner order and its reserved `not-marked` slot; `AdminPort`'s eight-step vendor
  dispatch — the only code naming an `%Api.Admin.*` class; the audit viewer with its agent-marker
  filter and the application error drill-down; the kill switch, enforced read-only and the
  definition's read-only flag, all re-evaluated at confirm; protected storage and its resource, the
  closed entity-type enum, the descriptor mechanism, the string table, the registered audit events,
  and the smoke script that defines "step complete".
- **Deliberate forward references.** 5.10's write must be the **same operation** Story 7.4's Auditing
  configuration screen later calls, and 5.6's and 5.10's banner carries its sentence alone until 7.4
  makes its link live. 5.11 navigates to the **Task schedule list** with the task selected; pointing
  it at the details route is the one-line change assigned to Story 7.6. The typed-name confirmation
  arrives in full at 14.7. Epic 8 depends on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
- **Rule 27 governs the epic's burn-down gate, not the individual stories.** A cleanup story and its
  burn-down gate charter only ledger entries that block the 2026-09-27 floor or a downstream epic's
  story; every other closable entry is re-owned, with the gate's own `by=` trailer, to a single
  range-end cleanup story chartered after Epic 12 merges.
