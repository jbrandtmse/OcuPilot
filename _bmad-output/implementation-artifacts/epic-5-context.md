# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once and 5.8 proved it end to end
in a real area. **5.9–5.13 exercise that finished path once per remaining area and add nothing to
it.**

## Stories

- Stories 5.0–5.8 — **done**: the whole write path plus the Web applications demo leg. What
  survives is in the two "Inherited"/"Settled" blocks below; nothing there is re-decided.
- Story 5.9: Permissions — the area's first confirmed user write ← **next**
- Story 5.10: Security and secrets — disable and re-enable auditing
- Story 5.11: Tasks — resume a task suspended after an error
- Story 5.12: OS management — suspend and resume a process
- Story 5.13: Logs — delete application errors by namespace

## Requirements & Constraints

**5.9 is the Users area's first confirmed write, over a non-merging endpoint.** The agent reads the
user through **the same endpoint the Users list uses** and mints a proposal diffing the changed
fields against that fresh read. `Security.User` is one of the 28 vendor endpoints that do **not**
merge, so the payload is the **complete property set** and a test must prove a two-field change
leaves every other field intact. Four refusals, all on the instance and never advertised as tools,
each **explained in the UI rather than merely hidden**: disabling or deleting the current user; the
last `%All` holder; `_SYSTEM`; and adding `%All` or any `%Admin_*` role to a user or role — privilege
grants are prohibited in Release 1 at **any** confirmation level. On success the list re-fetches, the
row highlights within two seconds, and the audit database carries the marked event.

**Four decisions taken by the deciding authority on 2026-09-21 — settled facts, not open questions.
Do not reopen any of them.**

- **DW-1428 — terminal.** A disclosed field value is **not** truncated; it stays unbounded. A bound
  contradicts "every field stays available", and a cross-request cache for the cost half would be
  fail-**open** on a security decision. Reopens only if a real payload makes the per-poll
  re-projection measurably slow on a live proposal.
- **DW-1430 — terminal by design.** When a caller fails both the privilege-pair gate and AD-30's
  read-only verdict, the **implemented order stands**: both orders satisfy AD-30 and AD-8, neither
  spec nor spine settles it, and the order is pinned in the method comment.
- **DW-1412 — routed to 5.9.** The change toast sits bottom-right of the **content area**, offset
  from the right edge by the panel's **live** width, so it never overlays the panel's Send button.
  DESIGN.md's component token (~line 507) and prose (~line 1211) and EXPERIENCE.md (~line 423) are
  all amended to say so.
- **DW-1429 — routed to 5.9, floor-blocking.** `Name` is **classified in Story 2.2's derivation**
  for `webapp.list.update`. AD-3's fail-closed rule is working exactly as the frozen matrix
  requires, but fail-closed makes an unclassified field indistinguishable from a real secret, and it
  does so on the one card the demo is built around. Epic 2 has merged, so the derivation is the
  trunk's and `Screen/Tool/**` is Epic 5's — fix it directly. It must not drift past the
  2026-09-27 floor.

**5.9's ledger inbox is three entries, already acceptance bullets in its epics block.**

- **DW-1431.** A principal holding **exactly** the declared pairs still cannot reach the confirm
  endpoint: it also needs `READ` on the install namespace's own code database — a lower IRIS
  access-control layer beneath the AD-8 pairs, and AD-9 working as designed ("database READ *is*
  routine-execution permission"). The resulting 403 arrives **before any dispatch code runs**, so it
  carries no error envelope and therefore no reason. Two obligations: the install grants it or the
  prerequisite is documented, and the refusal carries a reason. Measured on `ocupilot-ci` by driving
  a real least-privileged principal — the third defect class this epic found that way, and none of
  them were visible to a suite running as `%All`.
- **DW-1429** and **DW-1412**, above.

**Inherited from 5.1–5.8 — consumed, never re-decided.** The instance mints every proposal from a
fresh read (server id, user, conversation, tool, resolved arguments, AD-13's scoped target triple, a
fingerprint over the complete property set the write will send minus descriptor-declared
side-effect fields, the diff, a single-use token, ten-minute expiry); secrets are never stored and
never accepted from the model. Confirm is a **separate authenticated POST**
(`Kernel/Proposal/Confirm.cls`), absent from the registry, refused when the caller carries the turn
marker, usable only by the minting user; it executes the **stored** arguments and payload, and any
client key other than the descriptor's declared secret fields is **rejected outright, not ignored**.
`Propose.GuardedClaimAndClose` is **one** conditional UPDATE inside a per-target lock that burns the
token, writes the terminal state and cancels same-target siblings in one transaction, with the
vendor PUT after `TCOMMIT`. Every gate — prohibited set, `Restraint.Verdict`, the declared
`(resource, permission)` pairs, the fingerprint re-read — is evaluated **inside that transition**,
never at the minting tool call. Execution is **strictly as the user** under the caller's own
`$USERNAME`/`$ROLES`; the advertised tool set is the **full** set and privilege is checked at call
time, never by hiding tools. The marker is emitted from **one site** in `Confirm.Transition` after
the write reads OK, with `$System.Security.Audit`'s return value **checked** (it returns 0 and
silently drops an unregistered triple). `webapp.list.update`'s allowlist of four reviewed fields
under `additionalProperties: false` is declared in exactly two places
(`Screen.Tool.WebAppUpdate.PERMITTEDFIELDS`, `Kernel.Proposal.Prohibited.PermittedChangeFields`) and
the suite fails if only one is updated. An entity type the prohibited set does not evaluate is
refused wholesale (`PROHIBITED.UNCOVERED`), so **5.9–5.13 must each add their type's predicates
before their write tool can register.**

**Settled in 5.7–5.8, load-bearing for every remaining area story — built once, only pinned again.**

- **The gate.** A write tool's pair set **is the screen's own declared set**, and an administrative
  resource on it is required at `USE`, **never `WRITE`** (AD-8 as amended 2026-09-21). Built-in
  `%Admin_*`, `%Service_*` and `%Development` are system resources carrying no `WRITE`, so a `WRITE`
  pair is a gate only `%All` can pass; `USE` is exactly what the vendor's editor checks
  (`%CSP.Portal.Application.CheckSecurity` is `Quit $System.Security.Check(pResource,"USE")`), which
  makes "the same 403 the editor would give" satisfiable by construction. An OcuPilot-owned resource
  with its own `WRITE` was considered and rejected: a second authorization model to keep in step.
  **Standing for every later `%Admin_*` write tool.**
- **The disclosure has real rows.** `Kernel/Proposal/Disclosure.cls` projects masked
  `{field, value}` rows from the stored payload, so the "N unchanged fields" caption equals its rows
  with no second read; it is **masking, not withholding**, and fail-closed on anything not
  ordinary+literal in `ToolFields`. A leg asserting an ordinary literal carries its **value** is
  required — every earlier assertion held of a card that masked all 44 rows, because it ran as `%All`
  where the class-dictionary read never fails.
- **A refused confirm records a write tool-call card** reading "failed — <pair>"; the earlier
  zero-card assertion was refined, not loosened.
- `smoke.sh`'s `agentwrite` and `auditmarker` checks now **pass** (AD-45's one confirmed agent write
  and its marker, inside the one smoke path).
- A confirmed write publishes **one** `changed` event on the client change bus carrying AD-13's
  scoped triple plus an `action` from a closed set (`created`/`updated`/`deleted`), **refused rather
  than defaulted**. `TurnStore.decideProposal` publishes it after the `proposal-closed` that closes
  AD-43's pause, in that order.
- The per-type id rule is a **declared table** — `EntityRef.IDRULES`/`IDRULENAMES` — that
  `ui/tools/screen-mirror.mjs` mirrors and **throws at prebuild** on an undeclared rule, unknown
  type, a rule the client cannot implement, or a duplicate type; `REFSEPARATOR` likewise. There is
  **no** second identity rule hand-written in TypeScript (AD-5 forbids it; it is how the original
  divergence arose).
- **Sharp edge for any story that marks a row.** `Mint` stores a **folded** `targetRef` while a
  row's key is the name the instance returns, **case-preserved**. Two HIGH defects came from that
  gap, **both with the whole suite green**. `DataTable.viewKeyFor` and `changedKeyFor` are the
  reconciliation points; a read-back takes the spelling the **instance** returns, never `target.id`.
  `ProposalFixture`'s mixed-case write-target trio is the ready-made lever.
- `DefinitionForm.publishChange()` takes its action (create → `created`, edit → `updated`).
- The off-screen toast is built (store, stack of three, two lifetimes, hover/focus hold, dismiss,
  "Open in <screen>") with real browser coverage — consume it, never rebuild it.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations
  merge; sending only changed fields to one of the other 28 erases every omitted field. Read fresh,
  apply the diff, send the complete property set merged over the fresh read's whole object. 5.9's
  `Security.User` is one of the 28.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check in `irislib/`, then
  run the read as a real least-privileged principal on a throwaway and add what the instance still
  refuses. A port without a named gate is a review failure.
- **A mutating `AdminPort.Invoke` refuses a non-object `pBody`.** A `%String` body used to answer
  200 with the object unchanged and write nothing — the silent-success shape this epic rules against.
- **Governing ADs.** AD-14 (one change event; screens **re-fetch, never patch**; closed
  kernel-owned entity-type enum keyed from the screen descriptor), AD-43 (one shared auto-refresh
  framework; `proposal-open`/`proposal-closed` ride the same bus and carry the pause), AD-13 as
  amended (every boundary-crossing reference carries `(entity type, scope, id)`, scope being the
  namespace or the constant `instance`), AD-8 as amended above. AD-45, AD-41, AD-15, AD-46, AD-9,
  AD-10, AD-34, AD-36, AD-40, AD-1, AD-29, AD-31, AD-33, AD-35, AD-44, AD-12/AD-39 hold throughout.
- **IRIS's default isolation is READ UNCOMMITTED (AD-34).** An *uncommitted* rival `confirmed` once
  made a sibling `%EXACT(State) = 'live'` UPDATE match zero rows — two confirmed rows on one target,
  two vendor PUTs. The per-target lock closes it; any new conditional-update-plus-cancel pattern
  carries the same hazard.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` normalized at the port boundary with the raw kept for log and ledger only;
  `detail.violations[]` is projected to `{field, code}` before it reaches the model. `Api/Error.cls`
  validates by **shape**, so a new `PROPOSAL.*`/`PROHIBITED.*` code needs no contended edit. Proposal
  and ledger state are OcuPilot's own protected state through `Kernel/State`'s row-versioned guarded
  save (`STATE.CONFLICT`, 409); IRIS references are **weak** — scoped identity as data, never a
  foreign key. Audit events are registered with `Security.Events.Create()` at install under
  OcuPilot's Source.
- **Tests that can fail.** Geometry belongs in the browser runner, which loads the **deployed**
  bundle, and its specs use `panel-spec.mjs`'s `saveAndSettle()` (DW-1169). `%UnitTest` classes run
  **one at a time**. Every handler gets an HTTP test on status, content type and body shape; every
  tool a round-trip test over its generated schema; a denial test uses a purpose-built
  least-privileged role, never `%Operator`. Epic 13's gates bind: `Test/EndpointCoverage.cls` probes
  equal compiled routes and `Test/SurfaceCoverage.cls` rows equal registered tools, so a new route
  or write tool must declare its row or the `instance` job reddens. `smoke.sh`'s `executed=` count
  is **not** a stable invariant — read the skip lines, not the number (DW-1402).
- **Two measured traps in the verification loop.** `ui/tools/ci-runner.mjs` does **not** load
  source, so a browser result means nothing until source is synced, compiled and `Installer.Install`
  has run. And `npm test` does **not** run the browser suite (`test:browser` is separate, with its
  own harness build), so "build plus `npm test`" never verifies a merge.
- **Rule 29** shapes the next plan's Verification section: the story's **own** browser spec files,
  ObjectScript classes and client tier run inside the implement loop; the **full** browser suite and
  the **full** ObjectScript sweep run **once**, before `dev_complete`. **Rule 28**: a story's CI run
  resolves before the *next* story's implement spawn.
- **Prefer the shape that cannot be quietly wrong over the shape that is only right if an
  enumeration was complete** (5.5's allowlist plus `additionalProperties: false`). A deferred entry
  naming an AD's own invariant is standing work, not a deferral candidate. A hedged finding is
  **probed, not filed**. Rule 19 mutations run on the runner's own throwaway (DW-1185).

## UX & Interaction Patterns

- **The card.** Target heading; instance-computed diff rows; the rest behind "N unchanged fields"
  with real masked rows behind the caption; rationale and expected impact **labeled** on the agent
  tint; "Reverse: <how to undo>" where one exists. Footer: "Runs as <user name>, with your
  privileges." and "Confirm here; sending a message cancels this proposal". Countdown "Expires in
  m:ss" from 10:00, `warning` from 1:00, announced **once**.
- **Confirm.** In flight the button shows progress and is `aria-disabled` with focus kept; on
  success the buttons become "Confirmed by <user name> · hh:mm:ss", which takes focus. Terminal
  lines: "Canceled — by your message", "Canceled — a sibling proposal was confirmed", "Expired",
  "target changed, re-propose"; a fingerprint mismatch raises a warning banner inside the card
  offering **only** Re-propose. **One decision at a time** — no "Confirm all", a typed message
  cancels every live proposal, **Stop cancels nothing**.
- **Showing the change.** The screen **re-fetches in place** preserving sort, filter, selection and
  scroll, and **highlights within two seconds**, scrolling into view: change-highlight background,
  3px agent bar, a "Changed" tag, settling over two seconds and holding until the next interaction.
  When the screen is **not** open a toast names the change and carries "Open in <screen>", placed
  bottom-right of the content area offset by the panel's live width (DW-1412). Toasts are **never**
  used for errors (banners are) nor to confirm what the user just did on the open screen; the bus
  **does not cross tabs**. A live proposal against a screen's entity type **pauses** its
  auto-refresh with the chip "Auto-refresh paused — a proposal is awaiting confirmation" — on
  AD-43's seven roster screens only, which requires **both** the screen's own `refreshes`
  declaration and the roster row, never either alone.
- **Marking.** The **collapsed** tool-call line carries "done · audit not marked" in `warning` and
  the reply mentions it. The panel's `auditingOffBanner` states **only** that agent writes are not
  being marked and carries no link until Story 7.4; **its absence is never a positive claim that
  marking works**. A reachable refusal renders through `toolCallStatusFailed` ("failed — <reason>")
  on the card that was refused.

## Cross-Story Dependencies

- **Ledger routes.** 5.9: DW-1431, DW-1429 (floor-blocking), DW-1412. 5.10: DW-1171, DW-1206
  (validate `secretArguments` against the same declared field set `fingerprintExcludes` uses). 5.11:
  DW-269 (the vendor tasks LIST coerces every task's `Suspended` to false, so a suspended task cannot
  be told from a running one in a list read — declare the `INFO` `rowGet` AD-36 names or state why the
  story does not need it) and **DW-1419** (AC4's "with the entity selected" is unimplemented — the
  toast's route names the entity but `list-page.ts` injects no `ActivatedRoute` and never reads the id
  segment; 5.11's target is the Task schedule list **with that task selected**). **DW-456** stays
  owner-level.
- **Per-area shape.** 5.10's disable-auditing write is declared **destructive** (warning inside the
  card, `destructive` bar, 14.7's typed-name confirmation), deliberately **not** in the prohibited
  set, and must be the **same operation** Story 7.4's Auditing screen later calls; the
  disable/re-enable round trip is a single demo sequence, never a resting state. 5.12's `Process` is
  one of the five endpoints publishing **no** body template — action-style with a trivial body, never
  a hand-typed field list. 5.13 has no admin API endpoint:
  `SYS.ApplicationError.DeleteByNamespace` with one explicit save/restore to `%SYS`, the namespace a
  **parameter** from the drilled descriptor state (never the route's `?ns=`), the gate resolved per
  namespace at call time, and the fingerprint the **enumerated id set** captured at proposal time;
  its read tool returns summary fields only, variable tables never reaching the model.
- **Footprint.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**; modifying a
  file a **concurrent** epic created is a Clarification. Epic 5's client files:
  `ui/src/app/shell/panel.ts`, `panel.spec.ts`, `proposal-card*`, `reply*`, `tool-call-card*`,
  `core/proposal-view.ts`, `core/turn.ts`. `src/OcuPilot/Api/Router.cls` and EXPERIENCE.md's
  Fixed-strings table are epic-wide **shared-append** — tail only, union merge.
  **Epics 2, 3, 4, 6, 10, 13 and 15 have all merged and are integrated into this branch; their files
  are the trunk's, and Epic 5 is the only live epic — no concurrent-epic contention remains.**
- **Forward references.** Retargeting 5.11's navigation at the details route is the one-line change
  assigned to 7.6. Typed-name confirmation arrives in full at 14.7. Epic 8 depends on Epics 5 and 6;
  Epic 11 on 4, 5, 6 and 10. **Rule 27** governs the epic's burn-down gate, not the stories: only
  entries blocking the 2026-09-27 floor or a downstream epic's story are chartered there; the rest
  are re-owned to the range-end cleanup story chartered after Epic 12 merges.
