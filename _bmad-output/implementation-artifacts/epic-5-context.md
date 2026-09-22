# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once; 5.8–5.12 proved it end to end
in five real areas. **5.13 is the last area leg and the epic's first *destructive* one: it deletes,
so it is the first story whose own path executes AD-14's `deleted` action, and it consumes AD-51's
action-style seam with no admin API endpoint behind it.**

## Stories

- Stories 5.0–5.12 — **done**: the whole write path, plus the Web applications, Permissions,
  Security-and-secrets, Tasks and OS-management area legs. What survives is in the "Settled" blocks
  below; nothing there is re-decided.
- Story 5.13: Logs — delete application errors by namespace ← **next**
- Then the epic's burn-down story and the retro-review gate.

## Requirements & Constraints

### Story 5.13 — the next story's own subject

With the user drilled to a namespace in the application error log, they ask the agent to clear that
namespace's errors; a proposal is minted enumerating the error ids it will remove, and confirming it
deletes exactly those **as that user**. The drill-down re-fetches, the removed rows leave, the
selection clears if it was on one of them, and the audit database carries the marked event. The card
shows the identifying fields as **removals with no after-state and no Reverse line**; typed-name
confirmation is build step 7's, not this story's.

- **AD-48 governs this story and is unusually prescriptive — read it whole and carry its specifics.**
  The log is reached through **`SYS.ApplicationError`** — the `NamespaceList`, `DateList`,
  `ErrorList` and `ErrorDetail` queries, and `DeleteByNamespace`, `DeleteByDate`, `DeleteByError` —
  and OcuPilot writes no `^ERRORS` traversal of its own. That class **does not exist in `HSCUSTOM`**,
  so `LogSourcePort` switches **once, to `%SYS`**, by AD-16's explicit save and restore, never into
  the namespace being read, and the target namespace travels as a **parameter** on every call. The
  read half is built (2.12): `LogSourcePort.Errors` serves four drill levels over those queries,
  `PairsFor(<namespace>)` resolves the gate **per namespace** — `^ERRORS` is unmapped and lives in
  each namespace's own globals database, so the requirement is a function of the selection, not a
  constant — and `ErrorRead` returns the summary fields only. 5.13 adds the delete half against the
  same seams (`QueryClass`, `DetailQuery`, `NamespaceResolver`, `OpenQuery`).
- **One namespace source.** The namespace for a read and for a delete is the level the user drilled
  to, carried in the screen's descriptor state. The route's `?ns=` (AD-44) does **not** reach this
  port. Two sources would let a fully compliant delete — matching fingerprint, correct-looking audit
  marker — purge a namespace other than the one on screen.
- **Three delete scopes, not two:** by namespace, by date, and by error. FR-63 names the first and
  the last; `DeleteByDate` exists and is either implemented or **explicitly refused**, never left for
  a builder to discover.
- **The deletes are ordinary writes.** The absence of an admin API endpoint changes nothing:
  proposal, server-computed diff, explicit confirmation (AD-6, AD-34), the caller's own privileges
  through the port's gate (AD-29, AD-8), the agent marker (AD-15's ordinary case). A builder reading
  "no `AdminPort` call" as "not a real write" produces exactly the unconfirmed, unaudited deletion
  this spine exists to prevent. Note what that does **not** mean: `AdminPort.MUTATINGTYPES` and
  `BODYLESSTYPES` key **vendor** request types and this write issues none, so the seam 5.13 consumes
  is the tool half on `Screen/Tool/Write.cls`, not the port's rosters.
- **The fingerprint is the enumerated id set**, captured at proposal time, never a count and never a
  live re-query. Fingerprinting a count livelocks on an instance still logging errors; re-running the
  selection at confirm would delete rows the user never saw. Residue from errors logged between
  proposal and confirm is **correct**, and the card says so.
- **The captured payload is secret-by-default.** An `^ERRORS` entry captures every local at every
  stack level plus `$ROLES` and `$USERNAME`, and there is no template for AD-3's derivation to
  classify against. It never enters screen context (AD-24) and never reaches the model; a user reads
  the variable table on screen, the agent does not. On a for-Health instance it can hold patient data.
- **AD-51 was amended and AD-6 corrected at its origin during 5.12** — read both in the spine, and
  the 5.12 block below. 5.13 is the **first consumer** of the amended fingerprint-subject seam.

**5.13's ledger inbox is seven entries — unusually large, and four are AD-51 seam hardening routed
out of 5.12.**

- **DW-1470 — a latent trap armed exactly when 5.13 arrives.** `Test.ProhibitedFixture.Digest`
  (`ProhibitedFixture.cls:176`) still computes the confirm digest with the **three-argument**
  `Fingerprint.Of`, while its sibling `ProhibitedRoute.Minted` was updated in 5.12 to project and
  pass the declared subject. Both current callers pass merge-write tools, so nothing is wrong today —
  and 5.13 is the first caller that would seed an **action** write through it, where a seeded
  proposal would carry a digest no confirm can match. Two sibling declarations updated separately is
  DW-1206's shape, which this epic already paid for once.
- **DW-1474.** `Fingerprint.Of` applies `Projection(pSubject)` and *then* `Canonical(.., pExcludes)`,
  so a subject name a descriptor's `fingerprintExcludes` also names is hashed out of the very set it
  is the whole of, collapsing the digest to the empty object; `FingerprintSubjectProblem`'s four
  conditions relate the two in none. No descriptor declares `fingerprintExcludes` today, and the
  guard is what AD-51's adequacy rule rests on. About eight lines, plus a probe descriptor 5.13's own
  action write can carry.
- **DW-1475.** That guard validates subject names against the **screen's declared read**
  (`ProcessList.read.fields`, the LIST spellings `Pid,Username,Nspace,…`), not against the read the
  tool's own `READTYPE` issues (`GET`, which spells them `UserName`, `NameSpace`,
  `CommandsExecuted`). A name only the `READTYPE` read answers registers cleanly and then fails
  `Fingerprint.Projection` at **every** mint as a 500. Both shipped tools declare `Pid,State`, which
  both sets carry, so nothing is wrong today.
- **DW-1476.** An action write that declares **no** subject silently keeps AD-6's whole-read digest:
  the guard only checks a subject that is declared, `Mint.FingerprintSubjectOf` catches every
  exception into an empty subject, and `TaskResume` (5.11) declares neither parameter. Harmless there
  — a task's `INFO` read carries no moving counters — but AD-51 as amended says an action write
  declares its subject **without condition**, so 5.12's spec and the spine now disagree.
- **DW-1423 — fires on 5.13's own demo path.** `STRINGS.tableChangeAnnouncement`'s fixed `Updated:`
  prefix precedes `created` and `deleted` alike. 5.11 and 5.12 both emit action `updated`, so on both
  paths the prefix is *accidentally correct* and the wrong branch is unexecutable; 5.13 **deletes**,
  so its own path executes the `deleted` branch and can falsify a fix. **Its human half is not the
  runner's to decide** — amending EXPERIENCE.md's Fixed-strings row is a UX call, raised at plan
  stage as a Rule 5 amendment rather than reworded here.
- **DW-1228.** The delete row's drawn and spoken `field · value → (removed)` forms have no producer,
  because no delete proposal exists yet. 5.13 is the first, so its card is where both forms become
  real (`ui/src/app/core/proposal-view.ts`).
- **DW-1242.** The card's Reverse line is model-authored text like the rationale, and the AD-11
  markup pin covers only `rationale` and `expectedImpact`. 5.13's card carries **no** Reverse line at
  all, so it must reason about that field explicitly rather than inherit the gap.

### Settled in Story 5.12 (`7db6887`) — record, do not revisit

- **AD-51 AMENDED: an action write's fingerprint subject is declared by the tool, not derived by
  exclusion — and the guard is built.** `Screen/Tool/Write.cls` carries `FINGERPRINTSUBJECT` and
  `PRECONDITIONFIELD` (both `""` by default) with `FingerprintSubject()`/`PreconditionField()`
  accessors; `Fingerprint.Of` takes a fourth `pSubject` and projects before canonicalizing;
  `Registry.FingerprintSubjectProblem` is called from `Registry.ListTools` for **every** write tool,
  so a tool whose subject it refuses cannot register, be reached by the model, or be minted from.
- **Adequacy is structural, not a review convention.** The guard holds four things: the declaration
  belongs to an action-style write alone (a merge write declaring one is refused — its fingerprint is
  the descriptor's exclusions over the whole payload); the subject carries the **scoped target
  identity** (`IdArgument`, AD-13); it carries **the field the action's own precondition reads**
  (`PRECONDITIONFIELD`); and every name in it is one the screen already knows. An empty subject is
  refused and is nowhere near sufficient — a subject of the identity alone would let a confirm
  succeed against a target somebody else had already moved. **The names are checked through
  `DeclaredNames`, the same extraction `ConfirmChannelProblem` validates `fingerprintExcludes`
  against. Never a second validator beside it: that is DW-1206's defect wearing a new hat.**
- **Why the inversion, measured.** A digest over a live process's whole read refuses the confirm
  whenever the target has executed a command between mint and confirm, so it fires hardest for
  exactly the processes the action exists to suspend and never for an idle one: across two reads of a
  working process `CommandsExecuted` moved 1,678 → 6,004,249 and `CPUTime` 0 → 90, while an idle
  daemon held still over 20 s. AD-6's purpose survives intact — what it prevents is state that moved
  **under the diff**, and an action write's diff is over state the read can see: *this target, in
  this state, this verb*. A counter advancing is not the diff moving. **AD-6 was corrected at its
  origin in the same commit**, so the spine states the merge/action split once.
- **The two process tools are the worked examples.** `ProcessSuspend`: `READTYPE = "GET"`,
  `WRITETYPE = "SUSPEND"`, `SENDSBODY = 0`, `DESTRUCTIVE = 0`, `STATEFIELD = "State"`,
  `PRECONDITIONFIELD = "State"`, `FINGERPRINTSUBJECT = "Pid,State"`, over the screen's own pair set
  at `USE`; `ProcessResume` mirrors it. Five `Test/SubjectProbe/*` classes pin each refusing
  condition of the guard directly.
- **`process` joined four rosters in one pass:** `Prohibited.COVEREDTYPES` with its dispatch branch,
  `EntityRef.IDRULES` (`process:integer`), and the port's two. A listed type with no branch is
  refused `PROHIBITED.UNCOVERED` at every write; a registered write tool over an unlisted type
  reddens `UncoveredWriteTools`. **DW-1464 resolved**: `AdminPort.BODYLESSTYPES` now keys
  `Endpoint/TYPE` (`Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME`), matching `BARETYPES` in the
  same file; `MUTATINGTYPES` reads `PUT,RESUME,SUSPEND`. **DW-1458 resolved**:
  `OCUPILOT_ALLOW_PROCESS_CONTROL` and `OCUPILOT_ALLOW_TASK_CONTROL` arm `Test.ProcessControl` and
  `Test.TaskResume` class-wide, set by `scripts/ci-throwaway.sh` alone, both roster halves derived.

### Settled in Story 5.11 (`7b3893f`) — record, do not revisit

- **The action-style seam is five per-tool declarations on `Screen/Tool/Write.cls`, and later stories
  consume them rather than re-deriving anything.** `READTYPE` (default `GET`) is the type the mint's
  fresh read **and** the confirm's fingerprint re-read use; `WRITETYPE` (default `PUT`) is the type
  the one write site issues; `SENDSBODY` (default 1) decides whether a body is sent, whether anything
  is disclosed as unchanged, and whether the ledger records field names; `StateDiff()` computes the
  card's `{field, before, after}` rows from the fresh read and returns a `pProblem` that **refuses
  the mint** when the target is not in the state the action moves it out of; `STATEFIELD` names the
  one label an action write's state row carries.
- **The port's roster and the tool's declaration are pinned equal.** A write tool's `WriteType()`
  must be an `AdminPort.MUTATINGTYPES` member, and a `BODYLESSTYPES` member **exactly when**
  `SendsBody()` is 0. Neither list can be computed from the other — the port's is a fact about the
  vendor's `NeedsRequestBody()`, the tool's is a choice about one operation — and disagreement is
  silent both ways (500 at the write, or a payload nobody reviewed).
- **The defect the code review found in that seam.** `Prohibited.Changed` read an action write's
  state-row **label** (`Status`) as a payload **field**, and `Task.CRUD` answers a `Status` property
  of its own. Since a bodyless write's stored payload **is** its fresh read, a race was refused `403
  PROHIBITED.UNCOVEREDFIELD` with the row left **live**, where the AC requires `409 TARGETCHANGED`
  with it closed — and **unreachable by the suite**, because the fixture's two reads differed only in
  the one field. `StateField()` is the fix: a diff row naming the declared label is skipped.
- **Three inbox entries closed against delivered code.** DW-269: the task schedule declares the
  `INFO` `rowGet` AD-36 names, which is what makes a coerced list field readable at all. DW-1419:
  `list-page` reads its route id segment, so "with the entity selected" is real. DW-1453:
  `SurfaceCoverage`'s roster extends to **unbuilt** descriptors. And a vendor resume row records the
  **caller**, not `RunAsUser`, so AD-45's attribution is implementable as written.

### Settled in Story 5.10 (`66ee3da`) — record, do not revisit

- **AD-15 was amended 2026-09-21, and the scope of the amendment is the whole of it.** *A write whose
  effect is to close the audit channel cannot be marked at all, and that is a physical constraint,
  not a relaxation* — measured with the check that rules out the obvious misread
  (`Security.Events.Exists` for the triple is 1 throughout). Marker-before-write was **considered and
  rejected**, not deferred. **It is licence for nothing else** — 5.13 does not close the channel, so
  a failed marker there is AD-15's ordinary case: the write stands, the drop is recorded, "done ·
  audit not marked".
- `security.auditing.update` ships over the `auditing-configuration` type, advertising `Enabled`
  alone, declared **destructive**, deliberately **not** prohibited. The panel's auditing-off banner
  and its three-type `RESTRAINT_ENTITIES` re-read roster are built — consume them, never rebuild.
- **DW-1206 is built, not just decided.** Both validators call **one** `Registry.DeclaredNames` over
  the union of the write tool's settable fields and everything the screen's read declares;
  `screen-mirror.mjs` **derives** the set from the kernel's declaration rather than re-implementing
  it. A new write tool inherits this; it does not re-derive a union beside it.

### Settled in Story 5.9 (`c93fff6`) — record, do not revisit

- `permissions.users.update` exists over the Users list's **own** read. `Enabled` is derived; `Roles`
  is AD-3's **authored** half, because the template answers `[]` so the derivation cannot type the
  element and AD-3 forbids inventing it. The pair set is exactly `UserList`'s two, with
  `%Admin_Secure:USE` — **never** `:WRITE`.
- `user` is in the prohibited set with four refusals (current user, last `%All` holder, `_SYSTEM`,
  privilege grant), the `%All` refusal resting on a census over the **whole** population.
- DW-1431 **resolved as the documented half only** — its planned `AccessCheck` override was reverted
  on measurement, because every OcuPilot class lives in the database the caller cannot read, so the
  override itself raises `<PROTECT>` and turns a bodyless 403 into a vendor 500.

### Four decisions settled and terminal — no later stage reopens them

**DW-1428**: a disclosed field value is **not** truncated; a bound contradicts "every field stays
available", and a cross-request cache for the cost half would be fail-**open** on a security
decision. **DW-1430**: when a caller fails both the privilege-pair gate and AD-30's read-only
verdict, the **implemented refusal order stands, by design**, pinned in the method comment.
**DW-1412** resolved (the toast is offset by `--ocu-panel-live-width`); **DW-1429** dropped.

### Epic 5's signature defect — found **ten times across four stories**, and the region to distrust

**A safety predicate or asserted claim whose executed path is not the path it names.** 5.9 found
**five** in one story, one a **real grant path**: the privilege predicate asked only about role
*names*, never the **resources** a role carries, so adding `%Manager` answered `prohibits=0` — and
since IRIS ships no role whose name starts `%Admin_`, four privilege-grant legs had been passing for
the wrong reason. 5.10 found three, all unfalsifiable-*test* defects. 5.11's was the `StateField`
defect above. **5.12's**: `Prohibited.Process()`'s two AD-10 refusals — the caller's own process, and
an IRIS system process by a closed `JobType` allow-list — were never reached through the shipped
`Prohibits()`, because the tests asked the predicates through a helper that **re-implemented the
dispatch order**. Both are now armed at their **input** (a fresh read whose `Pid` is `$JOB`;
`JobType` 36, 59 and an unnamed value), with a non-vacuity floor so a predicate refusing everything
cannot read green. The shapes to distrust hardest: a fixture seam that **replaces** a safety method
rather than arming its input; a fixture whose two reads differ only in the field under test; and a
test that reaches a predicate by any route other than the shipped one. **5.13 adds a destructive
delete behind a per-namespace gate — exactly where the eleventh instance would hide.**

### Settled in 5.7–5.12, load-bearing for 5.13 — built once, only pinned again

The instance mints every proposal from a fresh read (server id, user, conversation, tool, resolved
arguments, AD-13's scoped target triple, a fingerprint — for a **merge** write over the complete
property set the write will send minus descriptor-declared side-effect fields, for an **action**
write over the tool's declared subject of the fresh read (AD-51 as amended) — the diff, a single-use
token, ten-minute expiry); secrets are never stored and never accepted from the model. Confirm is a
**separate authenticated POST** (`Kernel/Proposal/Confirm.cls`), absent from the registry, refused
when the caller carries the turn marker, usable only by the minting user; it executes the **stored**
arguments and payload, and any client key other than the descriptor's declared secret fields is
**rejected outright, not ignored**. `Propose.GuardedClaimAndClose` is **one** conditional UPDATE
inside a per-target lock that burns the token, writes the terminal state and cancels same-target
siblings in one transaction, with the vendor write after `TCOMMIT`; every gate — prohibited set,
`Restraint.Verdict`, the declared `(resource, permission)` pairs, the fingerprint re-read — is
evaluated **inside that transition**, never at the minting tool call. Execution is **strictly as the
user**, and the advertised tool set is the **full** set with privilege checked at call time, never by
hiding tools. The marker is emitted from **one site** in `Confirm.Transition` after the write reads
OK, with `$System.Security.Audit`'s return value **checked**.

- **The gate.** A write tool's pair set **is the screen's own declared set**, and an administrative
  resource on it is required at `USE`, **never `WRITE`** (AD-8 as amended 2026-09-21). Built-in
  `%Admin_*`, `%Service_*` and `%Development` carry no `WRITE` at all — verified on the instance — so
  a `WRITE` pair is a gate only a `%All` holder can pass, inverting the least-privilege story. 5.13
  adds its own type's prohibited predicates before its tool can register.
- **A write tool's permitted-field allowlist is declared in exactly two places** (the tool's
  `PERMITTEDFIELDS` and `Kernel.Proposal.Prohibited.PermittedChangeFields`) under
  `additionalProperties: false`, and the suite fails if only one is updated. An action-style write
  admits none, and a field argument sent to one is **refused by name**. `Disclosure.cls` projects
  masked `{field, value}` rows from the stored payload, so the "N unchanged fields" caption equals
  its rows with no second read — masking, not withholding, fail-closed on anything not
  ordinary+literal; a bodyless write discloses nothing and its caption is 0.
- A confirmed write publishes **one** `changed` event carrying AD-13's scoped triple plus an `action`
  from a closed set (`created`/`updated`/`deleted`), **refused rather than defaulted**, published
  after the `proposal-closed` that ends AD-43's pause. The per-type id rule is a **declared table**
  (`EntityRef.IDRULES`/`IDRULENAMES`, today five types: web-application, user,
  auditing-configuration, task, process) that `screen-mirror.mjs` mirrors and **throws at prebuild**
  over; a type the table holds no pair for is keyed **verbatim**, so a story whose ids have a
  canonical spelling declares the rule as data rather than normalizing in code (AD-5).
- **Sharp edge for any story that marks a row.** `Mint` stores a **folded** `targetRef` while a row's
  key is the name the instance returns, **case-preserved**; two HIGH defects came from that gap,
  **both with the whole suite green**. `DataTable.viewKeyFor` and `changedKeyFor` are the
  reconciliation points, and a read-back takes the spelling the **instance** returns, never
  `target.id`.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations merge;
  sending only changed fields to one of the other 28 erases every omitted field. Read fresh, apply
  the diff, send the complete property set merged over the fresh read's whole object. **AD-4 has no
  subject for an action-style write** (AD-51), which sends nothing and erases nothing.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check, then run the read
  as a real least-privileged principal on a throwaway and add what the instance still refuses. A port
  without a named gate is a review failure — least-privileged driving found three defect classes this
  epic that no `%All` suite could see. `LogSourcePort` inherits no vendor gate at all, so its
  `PairsFor(<namespace>)` **is** the gate.
- **A mutating `AdminPort.Invoke` refuses a non-object `pBody`.** A `%String` body used to answer 200
  with the object unchanged and write nothing — the silent-success shape this epic rules against. A
  `BODYLESSTYPES` write is the one exemption, now keyed `Endpoint/TYPE`.
- **Governing ADs.** AD-48 (this story, above), AD-51 **as amended 2026-09-22** (action-style writes
  and the declared fingerprint subject), AD-6 **as corrected in the same commit**, AD-16 (one
  explicit save/restore to `%SYS`, namespace as a parameter), AD-14 (one change event; screens
  **re-fetch, never patch**; closed kernel-owned entity-type enum keyed from the descriptor), AD-43
  (one shared auto-refresh framework; `proposal-open`/`proposal-closed` ride the same bus and carry
  the pause), AD-13 as amended, AD-8 and AD-15 as amended above. AD-45, AD-41, AD-46, AD-9, AD-10,
  AD-34, AD-36, AD-40, AD-1, AD-29, AD-31, AD-33, AD-35, AD-44, AD-12/AD-39 hold throughout.
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
  equal compiled routes and `Test/SurfaceCoverage.cls` rows equal registered tools. `smoke.sh`'s
  `executed=` count is **not** a stable invariant — read the skip lines, not the number (DW-1402),
  and `agentwrite` and `auditmarker` must both pass.
- **Verification traps measured this session.** `ui/tools/ci-runner.mjs` does **not** load source, so
  after editing a `.cls` the container must be recompiled explicitly — **a green under an unloaded
  mutation attributes nothing, exactly as a red under a failed load does**, and that direction is the
  dangerous one because it reads as a test that was never load-bearing. **A revert must be applied in
  both the worktree and the container**, or a later run silently carries a stale compiled class. A
  browser spec asserts the shipped bundle matches the stamp **the installer recorded**, so a
  `docker cp` without re-running `Installer.Install()` reddens `about-help-links` for a reason that is
  not the code. **Four test classes now refuse unarmed on a reused throwaway** —
  `AuditingUpdate`, `ProcessControl`, `ProhibitedRoute`, `TaskResume` — needing
  `docker exec -e OCUPILOT_ALLOW_AUDIT_TOGGLE=1 -e OCUPILOT_ALLOW_PROCESS_CONTROL=1 -e
  OCUPILOT_ALLOW_TASK_CONTROL=1`; a container started before a variable existed refuses the whole
  class and tests nothing while failing nothing (DW-1452). `npm test` does **not** run the browser
  suite, the browser suite is **not idempotent** on a reused instance (clear
  `OcuPilot_Kernel_State.Pref` — DW-1447, DW-1448), and piping a suite through `tail` reports
  **`tail`'s** exit code: capture the run in full.
- **Push before stacking bookkeeping.** GitHub evaluates only the pushed head, so a code commit with
  `skip ci` commits stacked above it gets **no run at all** — reproduced three times this epic
  (DW-1434). Push right after the implement stage's code commit. `gh run list --commit <sha>` can
  return an empty array for a sha that has a run; query by `--branch` and match `headSha`.
- **Three standing rulings.** **Rule 29**: the story's **own** browser spec files, ObjectScript
  classes and client tier run inside the implement loop; the **full** browser suite and the **full**
  ObjectScript sweep run **once**, before `dev_complete`. **Rule 28**: a story's CI run resolves
  before the *next* story's implement spawn. **Rule 27**: the epic's burn-down charters only
  floor-blocking or downstream-blocking entries. And prefer the shape that cannot be quietly wrong
  over the shape that is only right if an enumeration was complete: a deferred entry naming an AD's
  own invariant is standing work, a hedged finding is **probed, not filed**, and Rule 19 mutations
  run on the runner's own throwaway (DW-1185).

## UX & Interaction Patterns

- **The card.** Target heading; instance-computed diff rows — for an action write, the rows the tool
  computes from the fresh read, labelled with the product's word for the state rather than a vendor
  property name; **for a delete, the identifying fields as removals with no after-state**; the rest
  behind "N unchanged fields" with real masked rows behind the caption (0 for a bodyless write);
  rationale and expected impact **labeled** on the agent tint; "Reverse: <how to undo>" where one
  exists — **5.13's card has none, and that absence is a decision it states**. Footer: "Runs as <user
  name>, with your privileges." and "Confirm here; sending a message cancels this proposal".
  Countdown "Expires in m:ss" from 10:00, `warning` from 1:00, announced **once**.
- **Confirm.** In flight the button shows progress and is `aria-disabled` with focus kept; on success
  the buttons become "Confirmed by <user name> · hh:mm:ss", which takes focus. Terminal lines:
  "Canceled — by your message", "Canceled — a sibling proposal was confirmed", "Expired", "target
  changed, re-propose"; a fingerprint mismatch raises a warning banner offering **only** Re-propose.
  **One decision at a time** — no "Confirm all", a typed message cancels every live proposal,
  **Stop cancels nothing**. Typed-name confirmation arrives in full at 14.7.
- **Showing the change.** The screen **re-fetches in place** preserving sort, filter, selection and
  scroll, and **highlights within two seconds**, scrolling into view; for a delete the removed rows
  leave and the selection clears if it was on one of them. The announcement string's fixed `Updated:`
  prefix is DW-1423, and 5.13 is the first path that executes its `deleted` branch. When the screen
  is **not** open a toast names the change and carries "Open in <screen>", offset by the panel's live
  width. Toasts are **never** used for errors (banners are) nor to confirm what the user just did on
  the open screen; the bus **does not cross tabs**. A live proposal against a screen's entity type
  **pauses** its auto-refresh with the chip "Auto-refresh paused — a proposal is awaiting
  confirmation" — on AD-43's roster screens only, needing **both** the screen's own `refreshes`
  declaration and the roster row.
- **Refusals and marking.** A prohibited or wrong-state target is refused with an **explanation**
  naming why, never a bare error, through `toolCallStatusFailed` ("failed — <reason>"). The
  **collapsed** tool-call line carries "done · audit not marked" in `warning` and the reply mentions
  it; the panel's `auditingOffBanner` states **only** that agent writes are not being marked, and
  **its absence is never a positive claim that marking works**.

## Cross-Story Dependencies

- **Ledger routes.** 5.13's seven entries are set out under its own subject above: DW-1228, DW-1242,
  DW-1423, DW-1470, DW-1474, DW-1475, DW-1476. **DW-456** stays owner-level.
- **Per-area shape.** 5.13 is the one area leg with **no admin API endpoint**: the write is
  `SYS.ApplicationError`'s deletes through `LogSourcePort`, whose read half, `%SYS` save/restore,
  per-namespace `PairsFor` gate, drill levels and `ErrorLogFixture` seams are built (2.12) — extend
  them, do not rebuild them. The Logs error-log screen is a hand-written page
  (`ui/src/app/areas/logs/error-log.page.ts` + `.store.ts`), not a `ListPage` archetype, so the
  change-highlight and selection behaviour it needs is wired there rather than inherited.
- **Footprint.** `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**; Epic 5's
  client files are `ui/src/app/shell/panel*`, `proposal-card*`, `reply*`, `tool-call-card*`,
  `core/proposal-view.ts`, `core/turn.ts`, plus this story's `areas/logs/error-log.*` and
  `browser/error-log.browser-spec.mjs`. `src/OcuPilot/Api/Router.cls` and EXPERIENCE.md's
  Fixed-strings table are epic-wide **shared-append** — tail only, union merge. **Epics 2, 3, 4, 6,
  10, 13 and 15 have all merged into this branch; Epic 5 is the only live epic, so no concurrent-epic
  contention remains.**
- **Forward references.** Stories 7.8 and 16.6 add the Processes row actions and the Terminate dialog
  over 5.12's tools and the `JobType` predicate it built for them; retargeting 5.11's navigation at
  the Task details route is 7.6's one-line change, which also adds three more row actions over
  AD-51's seam. The auditing banner's link and "Turn auditing on" action land at 7.4. Epic 8 depends
  on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
