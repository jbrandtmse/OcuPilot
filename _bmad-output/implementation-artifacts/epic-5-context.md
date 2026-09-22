# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once; 5.8–5.11 proved it end to end
in four real areas. **5.12 and 5.13 exercise that path once per remaining area and add their own
type's prohibited predicates — and, because both vendor operations are action-style, they consume
AD-51's per-tool request-type seam rather than the PUT-shaped merge the first three writes used.**

## Stories

- Stories 5.0–5.11 — **done**: the whole write path, plus the Web applications, Permissions,
  Security-and-secrets and Tasks area legs. What survives is in the "Settled" blocks below; nothing
  there is re-decided.
- Story 5.12: OS management — suspend and resume a process ← **next**
- Story 5.13: Logs — delete application errors by namespace
- Then the epic's burn-down story and the retro-review gate.

## Requirements & Constraints

### Story 5.12 — the next story's own subject

From the Processes list with a row selected, the user asks the agent to suspend that process; a
proposal is minted naming the process id, and confirming it suspends the process **as that user**
through the same endpoint the screen reads. The target being the user's **own** process is refused
with an explanation. A **terminate** against an IRIS system process is refused on the instance and was
never advertised as a tool. `Process` is one of the five Release 1 endpoints publishing **no** body
template, so the tool is built **action-style with a trivial body needing no template**, never given a
hand-typed field list. On completion the list re-fetches, the row highlights within two seconds, and
the audit database carries the marked event.

- **AD-51 is the load-bearing decision and it is already built.** Read it in the spine in full. An
  action-style write declares its own admin request type, admits no settable fields, sends no body,
  and **fingerprints the fresh read rather than the sent body**. Both readings matter: AD-4's
  *Prevents* has **no subject** for a write that sends nothing (nothing is erased, so the merge idiom
  does not apply), and AD-6's "the property set the write will send" reads **empty** for a bodyless
  write — taken literally that is *no fingerprint at all*, so the **fresh read** is the fingerprint
  set. Everything else is unmoved: prohibited set, read-only verdict, kill switch, per-target lock,
  sibling cancel, marker, ledger row and change event all stay inside AD-34's one transition.
- **AD-10 names this story's boundary explicitly.** "Terminating IRIS system processes" is in the
  prohibited set; the set is defined **by effect, not by verb**, declared once in the kernel and
  evaluated inside the transition. `Prohibited.COVEREDTYPES` reads
  `web-application,user,auditing-configuration,task` in the tree today — 5.12 adds its entity type
  **and** a dispatch branch, or `UncoveredWriteTools` reddens (a registered write tool over an
  unlisted type) and a listed type with no branch is refused `PROHIBITED.UNCOVERED` at every write.
- **The pair set is established two ways together (AD-29), never from `ResourcesOR()` alone, and this
  endpoint is the measured example the AD itself cites.** `%Api.Admin.Endpoints.Process` answers
  `%Admin_Operate` alone, while `%SYS.ProcessQuery.AllowToOpen` admits `%Admin_Manage:USE` **or**
  IRISSYS write **or** IRISSYS read **or** the caller's own pid, and `VariableByPid` requires
  `%Admin_Manage:USE` outright — a caller holding only the declared set reads 500 on the variable
  table. Read the backing class's own check, then run it as a real least-privileged principal on a
  throwaway. Note that `%Api.Admin.*` is **absent from `irissys/`**, so the vendor request types,
  their `NeedsRequestBody()` and their `ResourcesOR()` are read from the **instance** (the way 5.11
  measured `Task.CRUD`), not from the export.
- **5.12's ledger inbox is two entries.** **DW-1458**: `OcuPilot.Test.TaskResume` creates, resumes and
  deletes a real task with **no arming variable**, while its own browser spec refuses to run outside a
  `-ci` throwaway. Routed here deliberately — 5.12 **suspends a process**, so an unarmed class pointed
  at a live instance is materially worse. The established pattern is an arming variable
  (`OCUPILOT_ALLOW_AUDIT_TOGGLE`, read by `OcuPilot.Test.ProhibitedRoute`) plus roster rows in
  `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs`; 5.12 adds it once and applies it to both
  classes. **DW-1464**: `AdminPort.BODYLESSTYPES` exempts a request-type **name** globally rather than
  an `(endpoint, type)` pair, matched by suffix alone — 5.12 adds the second action write and is where
  that grammar is either widened to `Endpoint/TYPE` or declined with a reason.

### Settled in Story 5.11 (`7b3893f`) — record, do not revisit

- **The action-style seam is five per-tool declarations on `Screen/Tool/Write.cls`, and 5.12 consumes
  them rather than re-deriving anything.** `READTYPE`/`ReadType()` (default `GET`) is the type the
  mint's fresh read **and** the confirm's fingerprint re-read use; `WRITETYPE`/`WriteType()` (default
  `PUT`) is the type the one write site issues; `SENDSBODY`/`SendsBody()` (default 1) decides whether
  a body is sent, whether anything is disclosed as unchanged, and whether the ledger records field
  names; `StateDiff()` (empty by default) computes the card's `{field, before, after}` rows from the
  fresh read and returns a `pProblem` that **refuses the mint** when the target is not in the state
  the action moves it out of; `STATEFIELD`/`StateField()` (default `""`) names the one label an
  action write's state row carries. `Mint` reads `ReadType`, `StateDiff` and `SendsBody`; `Confirm`
  reads `ReadType`, `WriteType` and `SendsBody`; `Prohibited` reads `ReadType` and `StateField`;
  `Disclosure` reads `SendsBody`. `TaskResume.cls` is the worked example: `READTYPE = "INFO"`,
  `WRITETYPE = "RESUME"`, `SENDSBODY = 0`, `STATEFIELD = "Status"`, `SettableFields()` empty.
- **The port's roster and the tool's declaration are pinned equal.** A write tool's `WriteType()` must
  be an `AdminPort.MUTATINGTYPES` member, and a `BODYLESSTYPES` member **exactly when** `SendsBody()`
  is 0. Neither list can be computed from the other — the port's is a fact about the vendor's
  `NeedsRequestBody()`, the tool's is a choice about one operation — and disagreement is silent both
  ways (500 at the write, or a payload nobody reviewed). 5.12's new type must land in both halves in
  the same pass.
- **The defect the code review found in that seam, because 5.12 walks the same ground.**
  `Prohibited.Changed` read an action write's state-row **label** (`Status`) as a payload **field**,
  and `Task.CRUD` answers a `Status` property of its own (the last run's result). Since a bodyless
  write's stored payload **is** its fresh read, AC6's race was refused `403
  PROHIBITED.UNCOVEREDFIELD` with the proposal row left **live**, where the AC requires `409
  TARGETCHANGED` with the row closed — fail-closed, ahead of the fingerprint gate that owns the
  moved-target answer, and **unreachable by the suite** because the fixture's two reads differed only
  in the one field. `StateField()` is the fix: a diff row naming the declared label is skipped.
  This is Epic 5's recurring shape once more — *a safety predicate or asserted claim whose refusing
  branch never runs against the real body* — landing on the newest Rule in the project.
- **Three inbox entries closed against delivered code, not against the story title.** DW-269: the
  task schedule declares the `INFO` `rowGet` AD-36 names (`ROWGETTYPES` carries `INFO`,
  `Screen/Tool/Read` issues it), which is what makes a coerced list field readable at all. DW-1419:
  `list-page` now reads its route id segment, so "with the entity selected" is real and 5.12's own
  navigation consumes it. DW-1453: `SurfaceCoverage`'s roster extends to **unbuilt** descriptors.
- **Two measurements worth not re-taking.** A vendor resume row records the **caller**, not
  `RunAsUser`, so AD-45's attribution is implementable as written. And `fingerprintExcludes` for the
  resume is **empty** because no `INFO` field moves while a task is suspended — the answer that keeps
  the fingerprint protecting rather than the one that makes a test pass.

### Settled in Story 5.10 (`66ee3da`) — record, do not revisit

- **AD-15 was amended 2026-09-21, and the scope of the amendment is the whole of it.** *A write whose
  effect is to close the audit channel cannot be marked at all, and that is a physical constraint,
  not a relaxation.* Measured with the check that rules out the obvious misread
  (`Security.Events.Exists` for the triple is 1 throughout, so a 0 return is the closed channel and
  not an unregistered event). Marker-before-write was **considered and rejected**, not deferred: it
  would record an agent write that may then fail. **It is licence for nothing else** — neither 5.12
  nor 5.13 closes the channel, so for both a marker that fails is AD-15's ordinary failure case: the
  write stands, the drop is recorded, "done · audit not marked".
- `security.auditing.update` ships over the `auditing-configuration` type, advertising `Enabled`
  alone, declared **destructive**, deliberately **not** prohibited. The panel's auditing-off banner
  and its three-type `RESTRAINT_ENTITIES` re-read roster are built — consume them, never rebuild.
- **DW-1206 is built, not just decided.** Both validators call **one** `Registry.DeclaredNames` over
  the union of the write tool's settable fields and everything the screen's read declares;
  `screen-mirror.mjs` **derives** the set from the kernel's declaration rather than re-implementing it
  (the 5.7 `IDRULES` pattern). A new write tool inherits this; it does not re-derive a union beside it.
- **`OCUPILOT_ALLOW_AUDIT_TOGGLE` arms `OcuPilot.Test.ProhibitedRoute` class-wide** (`%UnitTest` has
  no per-method skip). On a throwaway started **before** that variable existed, `ci-runner` refuses
  the whole class and **nine least-privileged legs silently do not run** — a reused container reads
  green while testing less than it did (DW-1452). That is both the pattern DW-1458 asks 5.12 to
  extend and its failure mode.

**The pattern 5.9–5.11 taught — the single most useful thing to carry forward. A safety predicate
whose refusing branch never runs against the real body.** 5.9 found **five** instances in one story,
one a **real grant path**: the privilege predicate asked only about role *names*, never the
**resources** a role carries, so adding `%Manager` answered `prohibits=0` — and since IRIS ships no
role whose name starts `%Admin_`, four privilege-grant legs had been passing for the wrong reason.
5.10 found three more, all unfalsifiable-*test* defects (an assertion that could not fail because the
port called `SaveRequestBody` on the vendor task, not the endpoint the test believed; a teardown that
read `AuditEnabled` after its own repair; a failed restore that leaked a least-privileged principal
into every later method). 5.11's was the `StateField` defect above. **5.12 and 5.13 each add their
own safety predicates**, so this is the region to distrust; the shapes to distrust hardest are **a
fixture seam that REPLACES a safety method** rather than arming its input, and a fixture whose two
reads differ only in the field under test — both give a green suite over an unexercised refusal.

### Settled in Story 5.9 (`c93fff6`) — record, do not revisit

- `permissions.users.update` exists over the Users list's **own** read. `Enabled` is derived; `Roles`
  is AD-3's **authored** half, because the template answers `[]` so the derivation cannot type the
  element and AD-3 forbids inventing it. The pair set is exactly `UserList`'s two, with
  `%Admin_Secure:USE` — **never** `:WRITE`.
- `user` is in the prohibited set with four refusals (current user, last `%All` holder, `_SYSTEM`,
  privilege grant), the `%All` refusal resting on a census over the **whole** population.
- DW-1412 **resolved**: the toast is offset by `--ocu-panel-live-width` on `.ocu-shell`. DW-1431
  **resolved as the documented half only** — its planned `AccessCheck` override was reverted on
  measurement, because every OcuPilot class lives in the database the caller cannot read, so the
  override itself raises `<PROTECT>` and turns a bodyless 403 into a vendor 500. DW-1429 **dropped**.

### Four decisions settled and terminal — no later stage reopens them

- **DW-1428.** A disclosed field value is **not** truncated; a bound contradicts "every field stays
  available", and a cross-request cache for the cost half would be fail-**open** on a security
  decision. **DW-1430.** When a caller fails both the privilege-pair gate and AD-30's read-only
  verdict, the **implemented refusal order stands, by design**, pinned in the method comment.
  **DW-1412** and **DW-1429**, as recorded above.

### Settled in 5.7–5.11, load-bearing for both remaining area stories — built once, only pinned again

The instance mints every proposal from a fresh read (server id, user, conversation, tool, resolved
arguments, AD-13's scoped target triple, a fingerprint over the complete property set the write will
send minus descriptor-declared side-effect fields — **for a bodyless write, over the fresh read**
(AD-51) — the diff, a single-use token, ten-minute expiry); secrets are never stored and never
accepted from the model. Confirm is a **separate authenticated POST** (`Kernel/Proposal/Confirm.cls`),
absent from the registry, refused when the caller carries the turn marker, usable only by the minting
user; it executes the **stored** arguments and payload, and any client key other than the
descriptor's declared secret fields is **rejected outright, not ignored**.
`Propose.GuardedClaimAndClose` is **one** conditional UPDATE inside a per-target lock that burns the
token, writes the terminal state and cancels same-target siblings in one transaction, with the vendor
write after `TCOMMIT`; every gate — prohibited set, `Restraint.Verdict`, the declared
`(resource, permission)` pairs, the fingerprint re-read — is evaluated **inside that transition**,
never at the minting tool call. Execution is **strictly as the user**; the advertised tool set is the
**full** set and privilege is checked at call time, never by hiding tools. The marker is emitted from
**one site** in `Confirm.Transition` after the write reads OK, with `$System.Security.Audit`'s return
value **checked**. `smoke.sh`'s `agentwrite` and `auditmarker` checks **pass**.

- **The gate.** A write tool's pair set **is the screen's own declared set**, and an administrative
  resource on it is required at `USE`, **never `WRITE`** (AD-8 as amended 2026-09-21). Built-in
  `%Admin_*`, `%Service_*` and `%Development` carry no `WRITE` at all — verified on the instance —
  so a `WRITE` pair is a gate only a `%All` holder can pass, inverting the least-privilege story.
  Both remaining stories are write stories, and each adds its own type's prohibited predicates
  before its tool can register.
- **A write tool's permitted-field allowlist is declared in exactly two places** (the tool's
  `PERMITTEDFIELDS` and `Kernel.Proposal.Prohibited.PermittedChangeFields`) under
  `additionalProperties: false`, and the suite fails if only one is updated. An action-style write
  admits none, and a field argument sent to one is **refused by name**.
- **The disclosure has real rows.** `Kernel/Proposal/Disclosure.cls` projects masked `{field, value}`
  rows from the stored payload, so the "N unchanged fields" caption equals its rows with no second
  read; it is **masking, not withholding**, and fail-closed on anything not ordinary+literal in
  `ToolFields`. A bodyless write discloses nothing and its caption is 0. A leg asserting that an
  ordinary literal carries its **value** is required — an assertion running as `%All`, where the
  class-dictionary read never fails, proves nothing.
- A confirmed write publishes **one** `changed` event carrying AD-13's scoped triple plus an `action`
  from a closed set (`created`/`updated`/`deleted`), **refused rather than defaulted**, published
  after the `proposal-closed` that ends AD-43's pause. The per-type id rule is a **declared table**
  (`EntityRef.IDRULES`/`IDRULENAMES`, today four types: web-application, user,
  auditing-configuration, task) that `screen-mirror.mjs` mirrors and **throws at prebuild** over; a
  type the table holds no pair for is keyed **verbatim**, so a story whose ids have a canonical
  spelling declares the rule as data rather than normalizing in code. No second identity rule in
  TypeScript (AD-5).
- **Sharp edge for any story that marks a row.** `Mint` stores a **folded** `targetRef` while a row's
  key is the name the instance returns, **case-preserved**. Two HIGH defects came from that gap,
  **both with the whole suite green**. `DataTable.viewKeyFor` and `changedKeyFor` are the
  reconciliation points; a read-back takes the spelling the **instance** returns, never `target.id`.
  The off-screen toast is already built — consume it, never rebuild it.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations merge;
  sending only changed fields to one of the other 28 erases every omitted field. Read fresh, apply
  the diff, send the complete property set merged over the fresh read's whole object. **AD-4 has no
  subject for an action-style write** (AD-51), which sends nothing and erases nothing.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check, then run the read
  as a real least-privileged principal on a throwaway and add what the instance still refuses. A port
  without a named gate is a review failure — least-privileged driving found three defect classes this
  epic that no `%All` suite could see.
- **A mutating `AdminPort.Invoke` refuses a non-object `pBody`.** A `%String` body used to answer 200
  with the object unchanged and write nothing — the silent-success shape this epic rules against. A
  `BODYLESSTYPES` write is the one exemption, which is what DW-1464 asks 5.12 to scope properly.
- **Governing ADs.** AD-51 (action-style writes, above), AD-14 (one change event; screens
  **re-fetch, never patch**; closed kernel-owned entity-type enum keyed from the descriptor), AD-43
  (one shared auto-refresh framework; `proposal-open`/`proposal-closed` ride the same bus and carry
  the pause), AD-13 as amended (every boundary-crossing reference carries `(entity type, scope, id)`,
  scope being the namespace or the constant `instance`), AD-8 and AD-15 as amended above. AD-45,
  AD-41, AD-46, AD-9, AD-10, AD-34, AD-36, AD-40, AD-48, AD-1, AD-29, AD-31, AD-33, AD-35, AD-44,
  AD-12/AD-39 hold throughout.
- **IRIS's default isolation is READ UNCOMMITTED (AD-34).** An *uncommitted* rival `confirmed` once
  made a sibling `%EXACT(State) = 'live'` UPDATE match zero rows — two confirmed rows on one target,
  two vendor writes. The per-target lock closes it; any new conditional-update-plus-cancel pattern
  carries the same hazard.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`,
  vendor `%Status` normalized at the port boundary; `detail.violations[]` is projected to
  `{field, code}` before it reaches the model, and `Api/Error.cls` validates by **shape**, so a new
  `PROPOSAL.*`/`PROHIBITED.*` code needs no contended edit. Proposal and ledger state go through
  `Kernel/State`'s row-versioned guarded save (`STATE.CONFLICT`, 409); IRIS references are **weak** —
  scoped identity as data, never a foreign key. Audit events are registered with
  `Security.Events.Create()` at install under OcuPilot's Source.
- **Tests that can fail.** Geometry belongs in the browser runner, which loads the **deployed**
  bundle, and its specs use `panel-spec.mjs`'s `saveAndSettle()` (DW-1169). `%UnitTest` classes run
  **one at a time**. Every handler gets an HTTP test on status, content type and body shape; every
  tool a round-trip test over its generated schema; a denial test uses a purpose-built
  least-privileged role, never `%Operator`. Epic 13's gates bind: `Test/EndpointCoverage.cls` probes
  equal compiled routes and `Test/SurfaceCoverage.cls` rows equal registered tools, so a new route or
  write tool declares its row or the `instance` job reddens. `smoke.sh`'s `executed=` count is **not**
  a stable invariant — read the skip lines, not the number (DW-1402).
- **Six measured traps in the verification loop.** `ui/tools/ci-runner.mjs` does **not** load source,
  so after editing a `.cls` the container must be recompiled explicitly — **a green under an unloaded
  mutation attributes nothing, exactly as a red under a failed load does**, and that direction is the
  dangerous one because it reads as a test that was never load-bearing. A browser spec asserts the
  shipped bundle matches the stamp **the installer recorded**, so a `docker cp` of a freshly hashed
  bundle without re-running `OcuPilot.Install.Installer.Install` reddens `about-help-links` for a
  reason that is not the code. `npm test` does **not** run the browser suite. The browser suite is
  **not idempotent on a reused instance** — clear `OcuPilot_Kernel_State.Pref` before trusting a
  local re-run (DW-1447, DW-1448). A throwaway predating `OCUPILOT_ALLOW_AUDIT_TOGGLE` skips two
  whole test classes without failing anything (DW-1452). And piping a suite through `tail` reports
  **`tail`'s** exit code: capture the run in full.
- **Push before stacking bookkeeping.** GitHub evaluates only the pushed head, so a code commit with
  `skip ci` commits stacked above it gets **no run at all** — reproduced three times this epic
  (DW-1434). Push right after the implement stage's code commit. `gh run list --commit <sha>` can
  return an empty array for a sha that has a run; query by `--branch` and match `headSha`.
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

- **The card.** Target heading; instance-computed diff rows — for an action-style write, the **one
  state row** the tool computes from the fresh read, labelled with the product's word for the state
  rather than a vendor property name; the rest behind "N unchanged fields" with real masked rows
  behind the caption (0 for a bodyless write); rationale and expected impact **labeled** on the agent
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
  3px agent bar, a "Changed" tag, settling over two seconds. When the screen is **not** open a toast
  names the change and carries "Open in <screen>", offset by the panel's live width. Toasts are
  **never** used for errors (banners are) nor to confirm what the user just did on the open screen;
  the bus **does not cross tabs**. A live proposal against a screen's entity type **pauses** its
  auto-refresh with the chip "Auto-refresh paused — a proposal is awaiting confirmation" — on
  AD-43's seven roster screens only, needing **both** the screen's own `refreshes` declaration and
  the roster row.
- **Navigation on the agent's initiative is built** (5.11): the announcement is posted **first**, the
  route changes about a second later, the destination heading announces it was opened by the agent,
  and `list-page` reads the route's id segment so the entity is genuinely selected.
- **Refusals and marking.** A prohibited target is refused with an **explanation** naming why — the
  user's own process, an IRIS system process — never a bare error, rendered through
  `toolCallStatusFailed` ("failed — <reason>") on the card that was refused. The **collapsed**
  tool-call line carries "done · audit not marked" in `warning` and the reply mentions it; the
  panel's `auditingOffBanner` states **only** that agent writes are not being marked, and **its
  absence is never a positive claim that marking works**.

## Cross-Story Dependencies

- **Ledger routes.** 5.12: **DW-1458** and **DW-1464**, as set out above. 5.13: **DW-1228** (the
  delete row's drawn and spoken `field · value → (removed)` forms have no producer, because no delete
  proposal exists yet — 5.13 is the first), **DW-1242** (the card's Reverse line is model-authored
  text like the rationale, and the AD-11 markup pin covers only rationale and expectedImpact — 5.13's
  card carries no Reverse line at all and must therefore reason about the field explicitly) and
  **DW-1423** (the change announcement's fixed "Updated:" prefix contradicts `created` and `deleted`;
  5.13 is the first story whose own path executes the `deleted` branch, so it is the first that can
  falsify a fix — its copy half is a Rule 5 UX amendment, not the story's to choose). **DW-456** stays
  owner-level.
- **Per-area shape.** 5.13 has no admin API endpoint: `SYS.ApplicationError.DeleteByNamespace` (the
  class does **not** exist in `HSCUSTOM`) with one explicit save/restore to `%SYS` and the target
  namespace travelling as a **parameter** taken from the drilled descriptor state, never the route's
  `?ns=`; the gate is resolved per namespace at call time because `^ERRORS` is unmapped; the
  fingerprint is the **enumerated id set** captured at proposal time, never a count and never a live
  re-query, and residue from errors logged between proposal and confirm is correct and the card says
  so. Its read tool returns summary fields only — time, error number, routine, line, error text —
  and the captured variable tables never reach the model.
- **Footprint.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**. Epic 5's
  client files: `ui/src/app/shell/panel.ts`, `panel.spec.ts`, `proposal-card*`, `reply*`,
  `tool-call-card*`, `core/proposal-view.ts`, `core/turn.ts`. `src/OcuPilot/Api/Router.cls` and
  EXPERIENCE.md's Fixed-strings table are epic-wide **shared-append** — tail only, union merge.
  **Epics 2, 3, 4, 6, 10, 13 and 15 have all merged and are integrated into this branch; their files
  are the trunk's, and Epic 5 is the only live epic — no concurrent-epic contention remains.**
- **Forward references.** Retargeting 5.11's navigation at the Task details route is the one-line
  change assigned to 7.6, which also adds three more row actions over AD-51's seam. Typed-name
  confirmation arrives in full at 14.7; the auditing banner's link and "Turn auditing on" action at
  7.4. Epic 8 depends on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
