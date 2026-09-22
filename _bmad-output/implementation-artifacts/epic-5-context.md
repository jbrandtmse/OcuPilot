# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh
read, presses Confirm, watches the affected screen re-fetch and highlight what changed, then finds
that same change in the IRIS audit database marked as having come through the agent — in **each** of
the six areas (SM-3, SM-4). Stories 5.1–5.7 built the write path once; 5.8–5.13 proved it end to end
in all six real areas, ending with the epic's only *destructive* leg. **The feature work is
finished. 5.14 is the epic's burn-down and its last story: it closes nine filed defects against
surfaces this epic already shipped, and designs nothing new.**

## Stories

- Stories 5.0–5.13 — **done**: the whole write path, plus the Web applications, Permissions,
  Security-and-secrets, Tasks, OS-management and Logs area legs. What survives is in the "Settled"
  blocks below; nothing there is re-decided.
- Story 5.14: Epic 5 burn-down ← **next, and last**
- Then the epic's retro-review gate.

## Requirements & Constraints

### Story 5.14 — the next story's own subject

**This is not a feature story.** It closes nine entries the burn-down gate chartered from the
ledger, each with a named reason for being here rather than re-owned: floor-blocking or
downstream-blocking (Rule 27). Everything else Epic 5 filed went to `range-end-cleanup`, which runs
**after** the 2026-09-27 floor, so an entry's presence here is the decision that it cannot wait.
Each one is a correction to something already shipped; none of them re-opens a design.

**Floor-blocking.**

- **DW-1336 — the agent panel's composer reads as an afterthought.** In the docked panel the
  "Message to the agent" entry renders roughly one character wide beside a Send button taking the
  remaining width. The panel is the product's centrepiece and every demo frame shows it. Both
  controls are token-driven (`ui/src/styles/_components.scss:3523`, `:3530`), so this may be a token
  change rather than a layout rewrite. **(inference)** the two symptoms may be one cause — the
  composer is `flex: 1 1 auto; min-width: 0` while Send sizes intrinsically beside it, so a Send
  that is too wide necessarily narrows the box. **Measure it in the browser tier rather than
  assuming it: jsdom computes no layout.** The probe is the composer's and the button's rendered
  widths at the panel's docked width on the narrowest supported viewport (1,280px), diffed against
  the figures EXPERIENCE.md and DESIGN.md already declare — so the fix is a diff against a declared
  figure, not a judgement about what looks right. 21 browser specs touch geometry and none compares
  a control's rendered proportion against its declared one, which is why this passed every gate. If
  the fix changes the panel's overflow behaviour, say so on **DW-1388** so Story 15.6 takes its
  baseline against the corrected tree.
- **DW-1437 — AD-10's account set is enumerated by verb and by role name, so two equivalent-effect
  lockouts are permitted.** `Prohibited.User` keys its disable refusals on `$Data(pChanged(Enabled))`
  alone, so a `Roles` delta stripping `%All` from the last holder is not that predicate's business;
  and on a stock instance `SuperUser`, `_Ensemble`, `_SYSTEM` and `irisowner` all hold `%All`, so
  `PROHIBITED.LASTALLHOLDER` cannot fire — a vendor service account with no human password is what
  keeps it from firing. Both match AD-10's literal words and both defeat its stated effect. The fix
  is one predicate change plus a "counts as a holder" clause.
- **DW-1438 — the prohibited set has no account-side analogue of its serving-path predicate.**
  AD-10 refuses every change to a web application that serves OcuPilot, but the account the CSP
  service *runs as* has no counterpart: `CSPSystem` is enabled, holds no roles, is not `_SYSTEM`,
  not the signed-in user and not a `%All` holder, so disabling it is permitted — and would break
  every CSP request including OcuPilot's own. `_Ensemble` and `irisowner` sit the same way. This is
  a self-destruct reachable through the product's own tool surface, the class Story 5.5 exists to
  make impossible; the fix is a `ServesOcuPilot` analogue over a closed list of service accounts.
- **DW-1467 — `security.auditing.update` declares `DESTRUCTIVE 1` while two planning artifacts
  call the same action a warning.** EXPERIENCE.md's confirm-dialog row and `epics.md` both name the
  same three cases (suspend the Task Manager, disable auditing, disable OcuPilot's web service)
  non-destructive warnings; `AuditingUpdate.cls:57` disagrees with both. It is on the demo's
  auditing card, and Story 14.7 puts a typed-name field on destructive cards, so a wrong flag today
  becomes a wrong **requirement** there.

**Downstream-blocking.**

- **DW-1447 — `resetRememberedState` clears only three value kinds**, so the membership kinds
  `recent` and `favorite` accumulate and the browser suite is **not idempotent** on a reused
  instance; `suggested-view.browser-spec.mjs:44` imports the reset and no line calls it, which reads
  as compliance while pinning a precondition nothing enforces. The suite is green on a first pass
  over a fresh instance (files run alphabetically), which is why CI never saw it; a local re-run is
  untrustworthy without clearing `OcuPilot_Kernel_State.Pref`, and that has already cost this epic
  real time twice.
- **DW-1448 — `browser-reset.mjs` counts two literal spellings**, `createBrowserContext(` and
  `browser.newPage(`, and requires no reset when the count is zero — so any spec taking its page
  from a helper (`signedInAt()` in `panel-spec.mjs`) escapes the requirement entirely while the
  checker reports clean. **This is its third under-detection** (DW-1435 was the call-without-import
  case). The ruling that came with the charter: **re-key it on context *creation* wherever that
  occurs, including inside a helper.** The spellings are a proxy; creation is the invariant. A
  checker that has missed three times is becoming the thing it was built to replace.
- **DW-1452 — `OcuPilot.Test.ProhibitedRoute` is armed class-wide**, so on a throwaway predating
  `OCUPILOT_ALLOW_AUDIT_TOGGLE` its nine pre-existing least-privileged legs silently do not run.
  `%UnitTest` offers no per-method skip. It costs coverage on a **reused** container rather than in
  CI, which is the class of thing that reads as green.
- **DW-1473 — `AdminPort.MUTATINGTYPES` admits a request type by bare suffix.** `EndpointType`
  (`AdminPort.cls:813`) admits any member on any endpoint, so admitting `Process/SUSPEND` also opens
  `Task.CRUD/SUSPEND`, which declares `TYPESUSPEND 15` and overrides `Run` — it answered 501 before
  5.12 and reaches the vendor after it. Latent, not exposed: no advertised tool declares that pair.
  The widening compounds with every action type Story 7.6 and Epic 9 add, and `BODYLESSTYPES`
  already keys by `(endpoint, type)` in the same file. **fix-risk high** — keying `PUT` by pair
  touches every merge write.
- **DW-1479 — nine documents still state the broad process-ownership rule the narrowing
  replaced** (`epics.md:153`, `:807`, `:3506-3508`, `:5636`; `EXPERIENCE.md:93`, `:220`, `:414`;
  `prd.md:806`; `SPEC.md:99`), plus `spec-5-12`'s `## Verification` recipes naming `OwnedByCaller`,
  a method that no longer exists, so 5.12's Rule 19 evidence is not re-runnable as written.
  `epics.md:3506-3508` is the sharpest: a **worked example** now teaching a false rule. Kept as one
  entry because a half-corrected set is worse than an uncorrected one. EXPERIENCE.md's three are
  **published copy** Epic 7's row actions will read, so a UX call governs that third.

**Two standing cautions for this story specifically.** Editing a planning document other tests pin
by line requires **`npm run test:tools`, not `lint-docs`** — see the verification traps below; three
of these nine touch such documents. And the burn-down's own edits are corrections at their origin:
delete the wrong sentence, do not append a paragraph explaining that it was wrong.

### Settled in Story 5.13 (`be6f6fc`) — record, do not revisit

- **AD-52 is new: a write tool declares the port it reaches its target through, defaulting to
  `AdminPort`.** It was a constant at `Confirm.cls:57`, `Mint.cls:45` and `Prohibited.cls:252`,
  while AD-48 routes the error log through `LogSourcePort` — so the write path **could not express
  5.13's write at all**. The mint's fresh read, the confirm's re-read, the prohibited-set evaluation
  and the write itself all resolve through that one declaration; **nothing else changes**, and a
  port is where the target lives, never a lighter path to it. The declaration is the **tool's**,
  not the screen's, because the port is a property of the target: one screen may read through one
  port and write through another.
- **AD-51's adequacy clause was corrected, and the correction is load-bearing.** The subject carries
  **the precondition fields the tool's own read type answers**, and **identity is NOT part of it** —
  the proposal's `TargetRef` (AD-13) already answers "which object is this?", while the fingerprint
  answers "has the reviewed state moved?". The old clause bound one shipped tool and not its sibling
  by an accident of vendor reads (`Process`'s `GET` answers `Pid`; `Task.CRUD`'s `INFO` answers no
  `Id`), making a correct tool **unregistrable**. **Do not re-add an identity requirement.** Naming
  the id where the read answers it is permitted and harmless. An empty subject is still refused —
  `Registry.FingerprintSubjectProblem` now refuses an action write declaring none, which is what
  makes DW-1476 enforceable at all; `TaskResume` declares `Suspended` as both its `PRECONDITIONFIELD`
  and its `FINGERPRINTSUBJECT`.
- **The process-ownership prohibition was NARROWED, reversing 5.12's merge-gate ruling.**
  `Prohibited.IsOcuPilotProcess` replaces `OwnedByCaller` and refuses exactly two harms: the job
  serving the confirm (`$JOB`) and any job running an OcuPilot turn, **whoever owns it**. It fails
  **closed** on a read with no `Pid` and on a state read that errors, and identifies a turn job from
  OcuPilot's own `running` rows (`Turn.GuardedIsTurnJob`) rather than from anything the process read
  carries, so a finished turn's pid cannot refuse the process the instance next gives that pid to.
  A process the confirming user owns which is neither is **permitted** — AD-10 names accounts, the
  serving path and IRIS system processes and **nowhere names process ownership**, so the broad rule
  borrowed authority it did not have and prohibited the feature's most likely legitimate use. One
  predicate for both harms, per DW-1206's lesson, rather than two kept in step. The code moved with
  the rule (`PROHIBITED.OWNPROCESS` → `PROHIBITED.OCUPILOTPROCESS`), `FIELDUSERNAME` is gone, and
  both process tools' model-facing `DESCRIPTION` was corrected at its origin. `epics.md`'s Story
  5.12 AC2 carries the `[AMENDED]` marker. **DW-1479 is the rest of that cleanup.**
- **The delete leg itself.** `logs.applicationerrors.delete` deletes **exactly the enumerated ids**,
  executed as `DeleteByError(ns, date, <ids>)` **once per enumerated date** — the fan-out is the
  substance of the amendment, and every seeded error being stamped today is why a loop stopping
  after its first date passed everything until a test drove two. The card's residue sentence is an
  authorised Fixed string carrying **both** facts (exactness, and that errors logged since the
  proposal remain); a version saying only "removes `<n>` errors" fails the AC. The removal-row and
  Reverse-line card forms are real now (DW-1228, DW-1242 closed), and DW-1470, DW-1474, DW-1475 and
  DW-1476 all closed against delivered code. The new tool changed the **tool population**, which
  reddened three cross-cutting rosters — when one of those reddens on a file the story did not
  touch, the roster is the thing that changed and it is the story's to update.

### Settled in Story 5.12 (`7db6887`) — record, do not revisit

- **The action-write fingerprint subject is declared by the tool, not derived by exclusion, and the
  guard is built.** `Screen/Tool/Write.cls` carries `FINGERPRINTSUBJECT` and `PRECONDITIONFIELD`
  with accessors; `Fingerprint.Of` takes a fourth `pSubject` and projects before canonicalizing;
  `Registry.FingerprintSubjectProblem` runs from `Registry.ListTools` for **every** write tool, so a
  tool whose subject it refuses cannot register, be reached by the model, or be minted from. The
  names are checked through `DeclaredNames`, the same extraction `ConfirmChannelProblem` validates
  `fingerprintExcludes` against — **never a second validator beside it**, which is DW-1206's defect
  in a new hat.
- **Why the inversion, measured.** A digest over a live process's whole read refuses the confirm
  whenever the target has executed a command between mint and confirm — it fires hardest for exactly
  the processes the action exists to suspend and never for an idle one: across two reads
  `CommandsExecuted` moved 1,678 → 6,004,249 and `CPUTime` 0 → 90, while an idle daemon held still
  over 20 s. What AD-6 prevents is state that moved **under the diff**, and an action write's diff is
  *this target, in this state, this verb*. **AD-6 was corrected at its origin in the same commit.**
- **The two process tools are the worked examples.** `ProcessSuspend`: `READTYPE = "GET"`,
  `WRITETYPE = "SUSPEND"`, `SENDSBODY = 0`, `DESTRUCTIVE = 0`, `STATEFIELD`/`PRECONDITIONFIELD` =
  `State`, `FINGERPRINTSUBJECT = "Pid,State"`, over the screen's own pair set at `USE`;
  `ProcessResume` mirrors it. `Test/SubjectProbe/*` pins each refusing condition directly.
- **`process` joined four rosters in one pass:** `Prohibited.COVEREDTYPES` with its dispatch branch,
  `EntityRef.IDRULES` (`process:integer`), and the port's two. A listed type with no branch is
  refused `PROHIBITED.UNCOVERED`; a registered write tool over an unlisted type reddens
  `UncoveredWriteTools`. `AdminPort.BODYLESSTYPES` keys `Endpoint/TYPE`; `MUTATINGTYPES` still keys
  by bare suffix, which is DW-1473 above.

### Settled in Stories 5.9–5.11 — record, do not revisit

- **5.11 (`7b3893f`) built the action-style seam**: `READTYPE` (default `GET`, used by the mint's
  fresh read *and* the confirm's re-read), `WRITETYPE` (default `PUT`), `SENDSBODY` (default 1,
  deciding body, disclosure and whether the ledger records field names), `StateDiff()` (the card's
  rows from the fresh read, returning a `pProblem` that **refuses the mint** when the target is not
  in the state the action moves it out of), and `STATEFIELD` (the one label a state row carries —
  its absence made `Prohibited.Changed` read a state **label** as a payload **field** and answer
  `403 PROHIBITED.UNCOVEREDFIELD` with the row left live where the AC requires `409 TARGETCHANGED`).
  A write tool's `WriteType()` must be a `MUTATINGTYPES` member and a `BODYLESSTYPES` member
  **exactly when** `SendsBody()` is 0; neither list is computable from the other and disagreement is
  silent both ways.
- **5.10 (`66ee3da`)**: AD-15 was amended — *a write whose effect is to close the audit channel
  cannot be marked at all, and that is a physical constraint, not a relaxation*; marker-before-write
  was considered and **rejected**. It licenses nothing else: elsewhere a failed marker is AD-15's
  ordinary case (the write stands, the drop is recorded, "done · audit not marked").
  `security.auditing.update` ships over the `auditing-configuration` type advertising `Enabled`
  alone, with the auditing-off banner and the three-type `RESTRAINT_ENTITIES` re-read roster — its
  `DESTRUCTIVE` flag is DW-1467 above. DW-1206 is **built**: one `Registry.DeclaredNames` over the
  union, which `screen-mirror.mjs` **derives** rather than re-implements.
- **5.9 (`c93fff6`)**: `permissions.users.update` over the Users list's own read; `Enabled` derived,
  `Roles` AD-3's **authored** half; `%Admin_Secure:USE`, never `:WRITE`. `user` is in the prohibited
  set with four refusals, the `%All` one resting on a census over the whole population — the gaps
  DW-1437 and DW-1438 name are in that predicate. DW-1431 resolved as the documented half only: the
  planned `AccessCheck` override was reverted on measurement, because every OcuPilot class lives in
  a database the caller cannot read, so the override itself raises `<PROTECT>`.

### Four decisions settled and terminal — no later stage reopens them

**DW-1428**: a disclosed field value is **not** truncated; a bound contradicts "every field stays
available", and a cross-request cache for the cost half would be fail-**open** on a security
decision. **DW-1430**: when a caller fails both the privilege-pair gate and AD-30's read-only
verdict, the **implemented refusal order stands, by design**, pinned in the method comment.
**DW-1412** resolved (the toast is offset by `--ocu-panel-live-width`); **DW-1429** dropped.

### Epic 5's signature defect — found **twelve times across six stories**, and the region to distrust

**A safety predicate or asserted claim whose executed path is not the path it names.** This is the
single most reliable defect prediction the epic produced, and 5.14 edits safety predicates
(DW-1437, DW-1438), a gate (DW-1473) and a checker (DW-1448) — every one of them the shape.

5.9 found **five** in one story, one a **real grant path**: the privilege predicate asked only about
role *names*, never the **resources** a role carries, so adding `%Manager` answered `prohibits=0` —
and since IRIS ships no role whose name starts `%Admin_`, four privilege-grant legs had been passing
for the wrong reason. 5.10 found three unfalsifiable-*test* defects; 5.11's was the `StateField`
defect above; 5.12's was `Prohibited.Process()`'s two AD-10 refusals, never reached through the
shipped `Prohibits()` because the tests asked the predicates through a helper that
**re-implemented the dispatch order**. **5.13 added the last three:**

- the **permitted** arm of the narrowed predicate — the arm the whole reversal exists to restore —
  was pinned only through a test-local re-implementation of the branch order; it now drives the
  shipped `Prohibits` against a probe process whose owner is read back from `%SYS.ProcessQuery`;
- a test carrying a **literal unfilled `MUTATIONLINE` placeholder** — an assertion set shipped with
  no demonstrated falsifiability at all, which is worse than a stale recipe because it never had
  one (the tree was swept for siblings; there are none);
- `TestAChangedFieldOnAnApplicationErrorProposalIsRefused` asserted **five parameters** and never
  called `Prohibits`, so emptying `Prohibited.ApplicationError` reddened **nothing** — and its doc
  comment named a mechanism the shipped rows do not use.

The shapes to distrust hardest: a fixture seam that **replaces** a safety method rather than arming
its input; a fixture whose two reads differ only in the field under test; a test that reaches a
predicate by any route other than the shipped one; and a recipe that names a mechanism rather than
the one the code executes.

### Settled in 5.7–5.13, load-bearing for anything 5.14 touches — built once, only pinned again

The instance mints every proposal from a fresh read (server id, user, conversation, tool, resolved
arguments, AD-13's scoped target triple, a fingerprint — for a **merge** write over the complete
property set the write will send minus descriptor-declared side-effect fields, for an **action**
write over the tool's declared subject of the fresh read (AD-51 as corrected) — the diff, a
single-use token, ten-minute expiry); secrets are never stored and never accepted from the model.
Confirm is a **separate authenticated POST** (`Kernel/Proposal/Confirm.cls`), absent from the
registry, refused when the caller carries the turn marker, usable only by the minting user; it
executes the **stored** arguments and payload, and any client key other than the descriptor's
declared secret fields is **rejected outright, not ignored**. `Propose.GuardedClaimAndClose` is
**one** conditional UPDATE inside a per-target lock that burns the token, writes the terminal state
and cancels same-target siblings in one transaction, with the vendor write after `TCOMMIT`; every
gate — prohibited set, `Restraint.Verdict`, the declared `(resource, permission)` pairs, the
fingerprint re-read — is evaluated **inside that transition**, never at the minting tool call.
Execution is **strictly as the user**, and the advertised tool set is the **full** set with
privilege checked at call time, never by hiding tools. The marker is emitted from **one site** in
`Confirm.Transition` after the write reads OK, with `$System.Security.Audit`'s return value
**checked**.

- **The gate.** A write tool's pair set **is the screen's own declared set**, and an administrative
  resource on it is required at `USE`, **never `WRITE`** (AD-8 as amended). Built-in `%Admin_*`,
  `%Service_*` and `%Development` carry no `WRITE` at all — verified on the instance — so a `WRITE`
  pair is a gate only a `%All` holder can pass, inverting the least-privilege story. `LogSourcePort`
  resolves its gate **per namespace**, so its tool declares no `WRITERESOURCE` and the roster tests
  carry a discriminating assertion: another namespace must resolve **that** namespace's resource and
  not this one's.
- **A write tool's permitted-field allowlist is declared in exactly two places** (the tool's
  `PERMITTEDFIELDS` and `Kernel.Proposal.Prohibited.PermittedChangeFields`) under
  `additionalProperties: false`, and the suite fails if only one is updated. An action-style write
  admits none, and a field argument sent to one is **refused by name**. `Disclosure.cls` projects
  masked `{field, value}` rows from the stored payload, so the "N unchanged fields" caption equals
  its rows with no second read — masking, not withholding, fail-closed on anything not
  ordinary+literal; a bodyless write discloses nothing and its caption is 0.
- A confirmed write publishes **one** `changed` event carrying AD-13's scoped triple plus an `action`
  from a closed set, **refused rather than defaulted**, after the `proposal-closed` that ends AD-43's
  pause; the per-type id rule is a **declared table** (`EntityRef.IDRULES`) `screen-mirror.mjs`
  mirrors and **throws at prebuild** over (AD-5). `Mint` stores a **folded** `targetRef` while a
  row's key is the name the instance returns **case-preserved** — two HIGH defects came from that
  gap with the whole suite green, and `DataTable.viewKeyFor`/`changedKeyFor` reconcile it.

## Technical Decisions

- **Merge is OcuPilot's, not the API's (AD-4).** Only 19 of 47 vendor `RunPut` implementations merge,
  so read fresh, apply the diff, and send the complete property set merged over the fresh read.
  **AD-4 has no subject for an action-style write** (AD-51), which sends nothing and erases nothing.
- **AD-29's pair set is established two ways together, never from `ResourcesOR()` alone** — the
  vendor's gate is a **lower bound**: read the backing query or class's own check, then run the read
  as a real least-privileged principal on a throwaway and add what the instance still refuses. A port
  without a named gate is a review failure — least-privileged driving found three defect classes this
  epic that no `%All` suite could see. This is the coverage DW-1452 silently removed on a reused
  container.
- **A mutating `AdminPort.Invoke` refuses a non-object `pBody`.** A `%String` body used to answer 200
  with the object unchanged and write nothing — the silent-success shape this epic rules against. A
  `BODYLESSTYPES` write is the one exemption, keyed `Endpoint/TYPE`.
- **Governing ADs.** AD-52 (the declared port), AD-51 **as corrected 2026-09-23** (action-style
  writes; the declared subject carries the precondition fields the tool's read answers and **not**
  identity), AD-6 **as corrected**, AD-10 (its set is accounts, the serving path and IRIS system
  processes — it does not reach process ownership), AD-7, AD-48, AD-16, AD-14, AD-43, AD-13, AD-8 and
  AD-15 as amended above. AD-45, AD-41, AD-46, AD-9, AD-34, AD-36, AD-40, AD-1, AD-29, AD-31, AD-33,
  AD-35, AD-44, AD-12/AD-39 hold throughout.
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
  **one at a time** — a loop over two classes in one invocation reported failures that do not exist
  when each is run singly. A denial test uses a purpose-built least-privileged role, never
  `%Operator`. Epic 13's gates bind: `Test/EndpointCoverage.cls` probes equal compiled routes and
  `Test/SurfaceCoverage.cls` rows equal registered tools. `smoke.sh`'s `executed=` count is **not** a
  stable invariant — read the skip lines, not the number (DW-1402), and `agentwrite` and
  `auditmarker` must both pass.
- **Verification traps measured across this epic, all still live.** `ui/tools/ci-runner.mjs` does
  **not** load source, so after editing a `.cls` the container must be recompiled explicitly — **a
  green under an unloaded mutation attributes nothing, exactly as a red under a failed load does**,
  and that direction is the dangerous one because it reads as a test that was never load-bearing.
  **A revert must be applied in both the worktree and the container.** A browser spec asserts the
  shipped bundle matches the stamp **the installer recorded**, so a `docker cp` without re-running
  `Installer.Install()` reddens `about-help-links` for a reason that is not the code (and successive
  `docker cp`s can leave several `main-*.js` in the shell directory, where the stamp names one and
  the page loads another). **Five test classes now refuse unarmed on a reused throwaway** —
  `AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `ProhibitedRoute`, `TaskResume` — needing
  `docker exec -e OCUPILOT_ALLOW_AUDIT_TOGGLE=1 -e OCUPILOT_ALLOW_PROCESS_CONTROL=1 -e
  OCUPILOT_ALLOW_TASK_CONTROL=1` and friends; a container started before a variable existed refuses
  the whole class and tests nothing while failing nothing (DW-1452). **Editing a planning document
  other tests pin by line requires `npm run test:tools`, not `lint-docs`** — inserting one row into
  EXPERIENCE.md's Fixed-strings table shifted every later anchor and reddened all three `gates` legs
  in CI while `lint-docs` read clean: the obvious checker is not the covering checker. `npm test`
  does **not** run the browser suite, the browser suite is **not idempotent** on a reused instance
  (clear `OcuPilot_Kernel_State.Pref` — DW-1447, DW-1448), and piping a suite through `tail` reports
  **`tail`'s** exit code: capture the run in full.
- **Push before stacking bookkeeping.** GitHub evaluates only the pushed head, so a code commit with
  `skip ci` commits stacked above it gets **no run at all** — reproduced three times this epic
  (DW-1434). Push right after the implement stage's code commit. `gh run list --commit <sha>` can
  return an empty array for a sha that has a run; query by `--branch` and match `headSha`.
- **Three standing rulings.** **Rule 29**: the story's **own** browser spec files, ObjectScript
  classes and client tier run inside the implement loop; the **full** browser suite and the **full**
  ObjectScript sweep run **once**, before `dev_complete`. **Rule 28**: a story's CI run resolves
  before the *next* story's implement spawn. **Rule 27**: the epic's burn-down charters only
  floor-blocking or downstream-blocking entries — which is exactly the nine 5.14 carries. And prefer
  the shape that cannot be quietly wrong over the shape that is only right if an enumeration was
  complete: a deferred entry naming an AD's own invariant is standing work, a hedged finding is
  **probed, not filed**, and Rule 19 mutations run on the runner's own throwaway (DW-1185).

## UX & Interaction Patterns

- **The card.** Target heading; instance-computed diff rows — for an action write, the rows the tool
  computes from the fresh read, labelled with the product's word for the state rather than a vendor
  property name; for a delete, the identifying fields as **removals with no after-state**, with the
  residue sentence stating both that exactly the listed errors go and that anything logged since the
  proposal remains; the rest behind "N unchanged fields" with real masked rows behind the caption (0
  for a bodyless write); rationale and expected impact **labeled** on the agent tint; "Reverse: <how
  to undo>" where one exists, and its **absence** on a delete card is a stated decision. Footer:
  "Runs as <user name>, with your privileges." and "Confirm here; sending a message cancels this
  proposal". Countdown "Expires in m:ss" from 10:00, `warning` from 1:00, announced **once**.
  Story 14.7 adds the typed-name field to **destructive** cards, which is why DW-1467's flag matters.
- **Confirm.** In flight the button shows progress and is `aria-disabled` with focus kept; on success
  it becomes "Confirmed by <user name> · hh:mm:ss" and takes focus. A fingerprint mismatch raises a
  warning banner offering **only** Re-propose. **One decision at a time** — no "Confirm all", a typed
  message cancels every live proposal, **Stop cancels nothing**.
- **Showing the change.** The screen **re-fetches in place** preserving sort, filter, selection and
  scroll, and **highlights within two seconds**, scrolling into view; for a delete the removed rows
  leave and the selection clears if it was on one of them. The announcement string's fixed `Updated:`
  prefix (DW-1423) was **re-owned to Story 7.1**: `announceChanged` is private to `data-table.ts` and
  called only from within it, so no screen outside that component can emit the announcement, and the
  Logs error-log page is a hand-written page rather than a `DataTable` — 5.13 could not execute the
  `deleted` branch after all. 7.1 deletes from a list that **is** a `DataTable`. When the screen is
  **not** open a toast names the change and carries "Open in <screen>", offset by the panel's live
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
- **The panel is the demo's face.** The composer and Send are the product's primary interaction and
  DW-1336 says they currently read as an afterthought; EXPERIENCE.md owns the composer contract and
  DESIGN.md the control sizing, so the intended proportions are already declared.

## Cross-Story Dependencies

- **Ledger routes.** 5.14's nine are set out under its own subject above: DW-1336, DW-1437, DW-1438,
  DW-1447, DW-1448, DW-1452, DW-1467, DW-1473, DW-1479. Nine further Epic 5 entries were re-owned to
  `range-end-cleanup` and are **not** this story's; DW-456 stays owner-level; DW-1423 went to 7.1 and
  DW-1480 to 7.1 as the first delete of another type.
- **Footprint.** 5.14 spans more of the tree than a feature story: `ui/src/app/shell/panel*` and
  `ui/src/styles/_components.scss` (DW-1336 — the styles carve governs Story 15.6, so flag any
  overflow change on DW-1388), `ui/browser/preferences-reset.mjs` and
  `suggested-view.browser-spec.mjs` (DW-1447), `ui/tools/browser-reset.mjs` (DW-1448),
  `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (DW-1437, DW-1438),
  `src/OcuPilot/Port/AdminPort.cls` (DW-1473), `src/OcuPilot/Screen/Tool/AuditingUpdate.cls`
  (DW-1467), `src/OcuPilot/Test/ProhibitedRoute.cls` (DW-1452), and the planning documents
  `epics.md`, `EXPERIENCE.md`, `prd.md`, `SPEC.md` plus `spec-5-12`'s verification recipes
  (DW-1479). `src/OcuPilot/Test/**` and `ui/src/app/core/**` are **shared-create**; `Api/Router.cls`
  and EXPERIENCE.md's Fixed-strings table are epic-wide **shared-append** — tail only, union merge.
  **Epics 2, 3, 4, 6, 10, 13 and 15 have all merged into this branch; Epic 5 is the only live epic,
  so no concurrent-epic contention remains.**
- **Forward references.** Stories 7.8 and 16.6 add the Processes row actions and the Terminate dialog
  over 5.12's tools and the `JobType` predicate; 7.6 retargets 5.11's navigation and adds three row
  actions over AD-51's seam, and with Epic 9 is what makes DW-1473's widening compound. The auditing
  banner's link and "Turn auditing on" action land at 7.4; 14.7 puts the typed-name field on
  destructive cards. Epic 8 depends on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
