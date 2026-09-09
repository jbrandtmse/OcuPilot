---
name: OcuPilot architecture spine — adversarial review
type: review
lens: adversarial (unit-pair divergence)
target: ../ARCHITECTURE-SPINE.md
also-read:
  - ../../../ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md
  - ../../../prds/prd-OcuPilot-2026-09-08/prd.md
  - ../../../prds/prd-OcuPilot-2026-09-08/addendum.md
  - ../.memlog.md
created: '2026-09-08'
status: draft
---

# Adversarial review — ARCHITECTURE-SPINE.md

## Method and verdict

The spine was read as a contract, not as prose. For each pair of units one level down — the six
portal-area slices (`Area/WebApp`, `Area/Permissions`, `Area/Security`, `Area/Task`, `Area/OsMgmt`,
`Area/Log`), the shell (`ui/src/app/shell/` + `Api/`), the agent kernel (`Kernel/*`, `Screen/*`,
`Port/*`) and packaging/install (`Install/`, `module.xml`, `Dockerfile`) — I looked for two
implementations that each satisfy every AD **as written** and still cannot be assembled.

**Verdict: the spine is strong on the vertical (a slice cannot reach into a slice) and weak on the
horizontal (two slices reaching the *same object* through different descriptors).** Twenty
divergences are recorded. Three are release-blocking safety holes reachable by a confirmed agent
write that every AD permits. The recurring root cause is that AD-5 makes the screen descriptor the
source of everything about a screen, but the objects the screens administer are not screen-scoped:
one web application, one user, one audit event, one resource, one namespace-scoped name appears in
several descriptors owned by different slices, and nothing in the spine reconciles them. AD-14's
closing claim — "two screens over the same entity cannot disagree about what to listen for" — is an
assertion, not a mechanism.

Nine new or tightened ADs are proposed (AD-24 through AD-32), each written in the spine's
Binds/Prevents/Rule form and each closing at least one pair below.

| # | Severity | Pair | One-line divergence |
| --- | --- | --- | --- |
| 1 | Critical | `Area/WebApp` × `Api` + `Kernel` | The web-application editor can grant application roles to `/api/ocupilot`, elevating every subsequent request; AD-10 forbids only *disabling* and *deleting*. |
| 2 | Critical | `Area/Permissions` × `Area/WebApp` | AD-10 says "web **application**"; FR-18 says "web **service**". Permissions' Services editor can disable `%Service_Web` through a confirmed proposal. |
| 3 | Critical | `Kernel/Audit` × `Area/Security` | Name-matcher redaction versus a generated wallet-secret schema whose field is `Value`: the secret lands in the proposal store and the ledger. |
| 4 | High | `Area/Task` × `Area/Permissions` | AD-6 never fixes what the fingerprint covers. Tasks refuse every Confirm on a live schedule; Permissions guard five fields out of twenty. |
| 5 | High | `Area/Task` + `Area/Log` × `Area/Permissions` + `Area/OsMgmt` | AD-14's tuple and AD-13's route carry no identity **scope**; namespace-scoped names collide with instance-scoped ones. |
| 6 | High | `Install` × `Area/Security` | OcuPilot's own registered audit events are deletable rows on the Auditing screen, and auditing's on/off state has two owners. |
| 7 | High | `Kernel/Agent` × `Kernel/State` | AD-7's progress temp global holds the same tool arguments and diff that AD-9 protects — at a different protection level. FR-29's test still passes. |
| 8 | High | `Api` (AD-12) × every form-page slice | The flat `{error, reason}` envelope has no slot for the field-keyed validation errors six slices' form-pages require. |
| 9 | High | `Area/Permissions` × `Kernel/State` | Deleting and recreating a user hands the new account the old one's transcripts, ledger rows, kill switch and read-only flag. |
| 10 | High | `Install` × `Kernel/Agent` | Nothing orders "install finished" before "the API answers"; FR-67's upgrade path runs turns against half-compiled classes and stale schemas. |
| 11 | Med-high | `ui/shell` (panel) × area slice stores | "Pause auto-refresh while a proposal is live" has no channel; AD-19 forbids both alternatives. |
| 12 | Med-high | `Area/Security` (OAuth) × `Area/Task` (history) | AD-5's entity-type key and id accessor are underspecified for multi-entity screens and for lists whose rows are not the detail entity. |
| 13 | Med-high | `Area/OsMgmt` × `Area/Log` | `/api/monitor` and `/api/mgmnt` have no port. Two slices, two access paths, two error shapes, one bypassing AD-11. |
| 14 | Med-high | `Kernel/Governance` × any renaming slice | Tool keys derive from screen names; a polish-week rename makes every key "new", therefore disabled. |
| 15 | Med-high | `Kernel/Proposal` × slice card renderers | AD-4 says unchanged fields are not resent; the UX card says they are. The disclosure asserts a guarantee the write does not make. |
| 16 | Medium | `Kernel/Screen/Tool` × `Area/Log` | The descriptor's privilege resource is the only gate on the LogFilePort path and a redundant second gate everywhere else. |
| 17 | Medium | `Area/Log` × `Area/OsMgmt` | Composite ids under AD-13's one-segment rule: two grammars, and sibling-proposal comparison is a string compare across them. |
| 18 | Medium | `Kernel/Agent` × area context serializers | Two answers to how many rows travel with a turn and which parts of context are untrusted. The UX's row-cap ask was not adopted. |
| 19 | Medium | `ui/shell` × `Kernel` | The cached privilege map and the call-time `$System.Security.Check` give two answers to "can I do this". |
| 20 | Medium | area slice write × `Kernel/Audit` | No AD owns the transaction boundary; a slice's rollback discards the ledger row that recorded the failure. |

---

## 1. The web-application editor can elevate OcuPilot's own API — Critical

**Units.** `Area/WebApp` (web application editor, FR-30) × `Api/` + `Kernel/` (the request path AD-8
and AD-1 rest on).

**What `Area/WebApp` does, fully compliant.** It declares `webapp.editor` per AD-5: route
`/ocupilot/web-applications/<id>`, privilege resource `%Admin_Secure`, entity-type key
`webapplication`, id accessor = the application path. Its write tool `webapp.editor.save` has its
JSON schema generated at build time from `%Api.Admin.Endpoints.WebApp.App:RequestBodySchema()`
(AD-3) — the 45 fields the memlog probed, including `Roles`, `MatchRoles[{MatchRole,TargetRoles[]}]`,
`Resource`, `AutheEnabled`, `JWTAuthEnabled`, `GroupById` and `ServeFiles`. It sends only changed
fields (AD-4), through the single AdminPort sequence (AD-2), as the user (AD-1, AD-8), behind a
server-minted fingerprinted proposal (AD-6) with an audit marker (AD-15). It refuses the AD-10 set:
it will not *delete* `/ocupilot` or `/api/ocupilot`, and it will not set `Enabled = 0` on them.

**What `Api/` + `Kernel/` do, fully compliant.** AD-1's whole argument is that "runs as the user is a
property of the process, not something a token has to assert" — the process carries `$USERNAME` and
`$ROLES` as the Web Gateway established them for the `/api/ocupilot` application. AD-8: "There is no
service account and no elevation anywhere on the request path." AD-7's turn job inherits that role
set. FR-65 requires the OcuPilot API application to carry "no application roles and no matching
roles, and the installer asserts this".

**The incompatibility.** `Roles` and `MatchRoles` are in the generated schema, and setting them is
neither a delete nor a disable, so **AD-10 does not refuse it and AD-22's frozen baseline enables it**
(a Release 1 tool key is pre-existing, therefore enabled). The agent can propose
`webapp.editor.save("/api/ocupilot", {Roles: ["%All"]})`; the card renders one honest diff row
(`Application roles: (none) -> %All`); the user confirms; the write succeeds as the user, who holds
`%Admin_Secure` and is entitled to make it. From the next request onward **every process serving
`/api/ocupilot` runs with `%All` added**, including every turn job, every AdminPort call and every
tool. AD-8's "no elevation anywhere on the request path" is now false and nothing detects it: AD-8
checks `$System.Security.Check` in the calling process, and the calling process genuinely holds the
role. AD-1's identity argument inverts — the process no longer carries only the user's roles, it
carries the application's. FR-65's installer assertion runs at container start, so the condition
persists until the next restart, at which point AD-17's guard-then-act installer may simply observe
that the application exists and leave it.

Three smaller variants of the same write are equally reachable: clearing `JWTAuthEnabled` (breaks
FR-1's Bearer path for every user), clearing `GroupById` on the static application (breaks silent
login, the mechanism FR-1 and UJ-1 depend on), and changing `/ocupilot`'s `Resource` to one nobody
holds (soft lockout, not a disable).

**Closing AD.**

### AD-24 — Install-owned objects are one declared set, self-protected everywhere

- **Binds:** AD-10's prohibited set; AD-17's roster; every screen descriptor in 5.5-5.10 whose list
  can show an object the installer created; FR-65's assertion
- **Prevents:** a confirmed write that reconfigures OcuPilot's own attack surface without deleting or
  disabling anything, and two units disagreeing about which objects those are
- **Rule:** The installer's roster is the single generated source of the **install-owned object set** —
  `(kind, identity)` tuples for the two web applications, the OcuPilot resource, the OcuPilot role,
  the state database, the `%Service_Web` dependency, and every registered audit `Source/Type/Name`.
  That set is read at runtime by (a) the AD-10 refusal on the write path and (b) every descriptor's
  self-protection rules; no slice hard-codes an install-owned identity. For an install-owned object
  the prohibition is **any mutation of a security-bearing field** — `Enabled`, `Resource`, `Roles`,
  `MatchRoles`, `AutheEnabled`, `JWTAuthEnabled`, `GroupById`, `DispatchClass`, `ServeFiles`,
  service enablement, resource/role membership, event registration — not only delete and disable.
  The generated write schema for such a target has those fields removed, so the model is never
  offered them and the refusal is structural rather than a check. A test asserts that the OcuPilot
  API application's `Roles` and `MatchRoles` are empty after every write tool in the WebApp slice is
  exercised against it.

---

## 2. "Web application" versus "web service": the lockout AD-10 was written to prevent — Critical

**Units.** `Area/Permissions` (Services list and editor, FR-41) × `Area/WebApp` (which implements
AD-10's refusal as written).

**What `Area/Permissions` does, fully compliant.** It declares `permissions.services` and
`permissions.serviceeditor` per AD-5, with the "self-protection rules" AD-5 requires expressed the
way EXPERIENCE specifies them: *"disabling OcuPilot's own web service warns that it locks the user
out"* — a warning dialog, and, per EXPERIENCE's Privilege Gating table, a **gated control with an
explanation as its reason**. Its write tool `permissions.serviceeditor.save` is generated from the
Service endpoint's `RequestBodySchema()` (AD-3), advertised in full (AD-8: "The full tool set is
always advertised"), enabled by the frozen baseline (AD-22), and produces a normal proposal (AD-6).

**What `Area/WebApp` does, fully compliant.** It reads AD-10 literally — "disabling the web
**application** serving OcuPilot" — and refuses `webapp.list.disable("/ocupilot")` on the write path.

**The incompatibility.** FR-18 and the PRD addendum's L4 table say the prohibited set includes
"disabling the web **service** that serves OcuPilot". AD-10 narrowed that to "web application". A
service is a Permissions-slice entity, so **AD-10 as written binds only the WebApp slice**, and the
Permissions slice's compliant implementation makes self-protection a *UI gate plus a warning*, not a
write-path refusal. AD-8 then guarantees the tool stays advertised and privilege is checked at call
time — so the agent proposes `permissions.serviceeditor.save("%Service_Web", {Enabled: 0})`, the card
renders the diff, the user confirms, and OcuPilot, the classic portal, the admin API and the Web
Gateway all become unreachable in the same request. The user cannot undo it from a browser. This is
precisely the failure AD-10 exists to make unreachable, missed by one word.

The general shape is worse than the instance: **two units hold two different theories of what
self-protection is.** WebApp treats it as a refusal on the instance (AD-10); Permissions treats it as
`aria-disabled` with a reason (EXPERIENCE's Privilege Gating). A UI gate is invisible to the agent,
which reaches the tool directly. Every self-protected target EXPERIENCE lists — "the current user,
the user's own process, OcuPilot's own web applications, service, resource and role, IRIS system
processes and system resources" — is therefore protected in one slice and merely greyed out in
another, with no AD saying which is correct.

**Closing AD.** AD-24 above (which puts `%Service_Web` in the install-owned set), plus:

### AD-25 — Self-protection is a write-path refusal; the UI gate is its echo

- **Binds:** AD-5's "row actions with self-protection rules"; AD-10; EXPERIENCE's Privilege Gating
  self-protection row; FR-32, FR-37, FR-41, FR-55
- **Prevents:** a protection that exists only in the client, which the agent's tool path does not
  traverse
- **Rule:** Every self-protection rule named in a descriptor is enforced **on the instance in the
  write path**, in the same place AD-10's prohibited set is enforced, and returns the same structured
  refusal whether the caller is a screen editor or a tool. The descriptor's rule is the source; the
  client's `aria-disabled` treatment and its reason string are *derived* from it, never authored
  separately. A self-protection rule with no server-side test is a review failure. The refusal
  reasons the client shows and the reasons the write path returns come from one table.

---

## 3. Two theories of secret redaction; the wallet secret loses — Critical

**Units.** `Kernel/Audit` (ledger writer) + `Kernel/Proposal` (stored arguments) × `Area/Security`
(Wallet secret form, FR-46).

**What `Kernel/Audit` does, fully compliant.** The spine's Consistency Conventions row for Secrets
says secrets are "redacted by a **shared matcher on key name**". So the ledger writer and the
proposal store share one matcher over field names — `Password`, `Secret`, `Key`, `Token`,
`Credential`, `PrivateKey` — applied to every tool's arguments before they are persisted. This
satisfies NFR-5, AD-6 ("Secret-typed fields are excluded from the stored arguments") and AD-21
("Secrets are write-only ... redacted from the ledger and from every log line").

**What `Area/Security` does, fully compliant.** It declares `security.secret` (Secret form, reached
from a Wallet collection) with a write tool `security.secret.save` whose JSON schema is **generated**
from `%Api.Admin.Endpoints.Wallet.Secret:RequestBodySchema()` (AD-3 — "A write tool with a
hand-written payload schema is a review failure"). AD-5 requires the descriptor to carry a
"context serializer with its **secret-typed field list**" — a list scoped to *screen context*, which
is what FR-11 needs. Nothing in AD-3, AD-5 or AD-6 requires the slice to declare a secret-field list
for the **write schema**; the spine's convention says the matcher does that job.

**The incompatibility.** The wallet secret's payload field is whatever the vendor named it — `Value`,
`Data`, `Contents`, `SecretValue`. Three of those four do not match any name matcher. The moment the
field is not called `Secret*` or `*Password`, AD-6's exclusion does not fire: the plaintext secret
is stored in the proposal record (protected by AD-9, but readable by any OcuPilot administrator and
by the confirm path), written to the ledger row (FR-21), rendered into the proposal card's diff
instead of `••••••••`, and — because FR-11's screen-context exclusion is a *different* list on the
same descriptor — potentially sent to the provider as part of the form's values.

This is a direct conflict inside the documents, not merely a gap: FR-21 says "Redaction is
schema-driven: every tool schema marks its secret fields and the ledger writer drops them **by
schema, not by pattern**", and the spine's own conventions table says the opposite. Two units read
the two sentences and both are compliant with the spine.

Second-order: AD-6 says secrets "are supplied at confirm". If the field is not classified secret, it
is supplied by the **model** instead of the user — the model authors the wallet secret's value, which
FR-17 explicitly forbids ("do not accept it from the model").

**Closing AD.**

### AD-26 — The secret-field list is declared per write tool over the generated schema

- **Binds:** AD-3, AD-6, AD-21, FR-11, FR-17, FR-21, NFR-5; every write tool in 5.5-5.10 and the
  Definition form
- **Prevents:** a secret whose payload field name defeats a name matcher reaching the proposal store,
  the ledger, the card's diff, or the model
- **Rule:** Each write tool declares `SecretFields` as an explicit subset of its **generated** schema's
  field names, and separately declares `NonSecretFields` covering the remainder; the build fails when
  the two do not partition the schema, so a new vendor field cannot be silently unclassified. The
  same declared list drives all four consumers — proposal storage exclusion (AD-6), ledger redaction
  (FR-21), card masking, and the model-facing schema, from which secret fields are **removed** so the
  model cannot author them. The key-name matcher survives only as a build-time *assertion* that every
  field it flags is declared secret; it is never the runtime mechanism. AD-5's context serializer
  secret list and this list are generated from one declaration.

---

## 4. Two fingerprints: one that refuses everything, one that guards almost nothing — High

**Units.** `Area/Task` (Task details, Resume/Suspend, FR-50, FR-51) × `Area/Permissions` (Users list
row actions, FR-37).

AD-6 says the proposal carries "a target fingerprint from a fresh read" and confirm "re-reads the
target, compares the fingerprint, refuses on mismatch". It never says **what the fingerprint covers**,
and AD-5 gives each screen its own read tool returning "the same fields the screen shows" (FR-16).

**What `Area/Task` does, fully compliant.** Its write tools hang off `tasks.details`, whose read tool
returns the detail shape: name, namespace, description, task type, priority, run-as user,
suspend-on-error, the schedule, `Status`, `LastFinished`, `LastError`, and **`NextScheduled`**. The
fingerprint is a hash of that fresh read.

**What `Area/Permissions` does, fully compliant.** Its `enable`, `disable` and `delete` tools are row
actions on `permissions.users`, whose read tool returns the list shape FR-35 specifies: name, full
name, enabled, type, roles. The fingerprint is a hash of those five fields.

**The incompatibility — two opposite failures from one AD.**

- Tasks: `NextScheduled` advances on every schedule tick. On a task that runs every minute — the
  Nightly purge of UJ-6 is hourly, but `%SYS.Task` instances that run every 1-5 minutes are the
  common case — **every Confirm arrives after the fingerprint has already moved**. AD-6 refuses. The
  card shows "target changed, re-propose"; Re-propose is a **new turn** (EXPERIENCE step 5), which
  cancels the sibling proposals, costs a provider round trip and, on the next confirm, fails
  identically. UJ-6's climax is unreachable on a busy instance and the failure is deterministic, not
  intermittent.
- Permissions: a user's password, expiry date, comment, startup namespace and routine, email, mobile
  and two-factor settings are all outside the five fields. A concurrent User editor Save (or another
  administrator's classic-portal change) that sets an expiry date or enables two-factor **does not
  move the fingerprint**, and the confirm proceeds against state that has genuinely moved. AD-6's
  stated purpose — "a write against state that moved under the diff" — is not met, and the card told
  the user it was.

Both slices satisfy AD-6 verbatim. The safety property is a function of a per-slice choice the spine
does not constrain.

**Closing AD.**

### AD-27 — The fingerprint covers a declared field set, computed by the kernel, identical per entity

- **Binds:** AD-6; every write tool in 5.5-5.10; FR-17's "target changed, re-propose"; UJ-6
- **Prevents:** a fingerprint that moves on a clock tick, and a fingerprint that ignores the fields
  the write can change
- **Rule:** The fingerprint is computed by `Kernel/Proposal` over the entity's declared
  `FingerprintFields` — the union of every field any write tool on that entity type can change, plus
  the identifying key — and never over a whole read response. The set is declared **once per entity
  type**, not per screen, so a write proposed from a list and the same write proposed from a detail
  page fingerprint identically. Derived and volatile fields (`NextScheduled`, `LastFinished`, counters,
  free space, uptime, meter values) are excluded by declaration and a build check fails when a field
  the vendor schema marks read-only appears in the set. `Kernel/Proposal` re-reads through the same
  entity-level read used at mint, never through the invoking screen's read tool.

---

## 5. The change-event tuple has no scope: namespace-scoped names collide — High

**Units.** `Area/Task` and `Area/Log` (namespace-scoped entities) × `Area/Permissions` and
`Area/OsMgmt` (instance-scoped entities).

AD-13 fixes the route as `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>` — the namespace is a
*query parameter*, outside the id. AD-14 fixes the change event as `(entity type, id, action)` — three
slots, no scope. AD-16 tells the AdminPort to save and restore `$NAMESPACE` but does not say who
decides the target namespace.

**What `Area/Task` does, fully compliant.** Tasks are per-namespace: FR-48 says the schedule list
filters on "at least name and namespace". Its descriptor declares entity-type key `task` and an id
accessor returning the task name, and its AdminPort calls run in the route's `ns`. A confirmed
`tasks.details.resume` publishes `(task, "Purge", update)`.

**What `Area/Permissions` does, fully compliant.** Users, roles, resources and services are
instance-wide and live in `%SYS`. Its descriptor declares entity-type key `user` and an id accessor
returning the user name, and its AdminPort switches to `%SYS` regardless of the route's `ns`.

**The incompatibilities.**

1. **Wrong-row highlight.** The Task schedule screen open on `?ns=HSCUSTOM` receives
   `(task, "Purge", update)` emitted by a write that happened in `USER`, re-fetches, and highlights
   the *HSCUSTOM* task called `Purge` with the "Changed" tag. Identically-named tasks across
   namespaces are the norm, not the exception (the classic Task Manager seeds the same purge tasks
   per namespace). AD-14's closing sentence claims this cannot happen; the mechanism it cites — the
   descriptor's entity-type key — is exactly what makes it happen, because the key is `task` on both.
2. **Wrong-target confirm.** AD-6's confirm "re-reads the target". In which namespace? If the confirm
   request re-reads in *its own* route's namespace (the user switched namespaces between propose and
   confirm, which the header switch invites and EXPERIENCE keeps the panel and its conversation
   across), the re-read finds a *different* task with the same name. When the two are clones from the
   same definition — the ordinary case — the declared fingerprint fields match, and the write applies
   to the wrong namespace's task. The safety property of AD-6 is defeated by identity, not by
   staleness.
3. **A lie in the screen context.** EXPERIENCE's canonical context-chip string is
   `"Users, HSCUSTOM · 6 rows"`. Users are instance-wide; the chip and the serialized context assert a
   namespace scope that does not exist, and the model reasons on it ("switch to USER to see the other
   users").
4. **The Logs slice compounds it.** The application error log drills namespace -> date -> error, so
   *namespace is part of the row's identity*, while `alerts.log` and `messages.log` are instance-wide
   files. One slice needs both scopes at once.

**Closing AD.**

### AD-28 — Every entity carries a declared identity scope, and the scope travels with it

- **Binds:** AD-5's entity-type key and id accessor; AD-13's route; AD-14's change event; AD-6's
  re-read; FR-5, FR-11, FR-48, FR-63
- **Prevents:** a change event highlighting the same-named entity in a different namespace, and a
  confirm re-reading a different object than the one fingerprinted
- **Rule:** Each descriptor declares `IdentityScope` as `instance` or `namespace`. The change event is
  `(entityType, scope, id, action)`, where `scope` is the empty string for instance-scoped entities
  and the namespace name otherwise; a screen re-fetches only on a matching `(entityType, scope)`. A
  proposal stores the scope alongside the arguments and the confirm re-read is performed in the
  **stored** scope, never in the confirm request's route namespace; a mismatch between the two is
  reported as "target changed, re-propose". For an instance-scoped screen the route's `ns` is
  display-only, the context serializer omits it, and the context chip renders the scope word
  ("instance-wide") in place of the namespace so the model is not told a false scope. The AdminPort's
  target namespace comes from the descriptor's scope, never from the route.

---

## 6. OcuPilot's audit events are rows on somebody else's screen — High

**Units.** `Install/` (AD-15, AD-17) × `Area/Security` (Auditing configuration, FR-47).

**What `Install/` does, fully compliant.** AD-15: "OcuPilot registers its audit events with
`Security.Events.Create()` at install, under its own Source — without registration
`$System.Security.Audit()` silently returns 0 and drops the event." AD-17: the installer "enables
auditing and registers OcuPilot's events", is "guard-then-act throughout and safe to repeat", and
"re-runs its privileged steps even when the web applications already exist".

**What `Area/Security` does, fully compliant.** FR-47: "System events can be enabled and disabled and
their counters reset ... **user events can also be created and deleted**." OcuPilot's registered
events *are* user-defined events under a user-defined Source, so they appear as rows on this screen.
The slice declares `security.auditevents` with generated write tools including
`security.auditevents.delete` (AD-3), advertised (AD-8), enabled by the frozen baseline (AD-22), and
refused only for AD-10's prohibited set — **which does not name audit events**.

**The incompatibilities.**

1. **The marker deletes itself.** The agent can propose "delete user audit event
   `OcuPilot/Action/AgentWrite`". The card is honest, the user confirms, the write succeeds. The very
   write's own marker is then dropped silently (AD-15's own stated failure mode), surfacing only as
   "done · audit not marked" on one collapsed card line. Every subsequent agent write is unmarked.
   SM-5 ("zero confirmed proposals without a matching marked event") breaks for the rest of the
   voting week, and FR-22's "agent writes are not being marked" banner does **not** fire, because that
   banner's condition is *auditing off or OcuPilot's events disabled* — a deleted event is neither.
2. **Two owners of the auditing flag.** AD-17's phrasing is ambiguous between "enable auditing if it
   is off" and "assert auditing is on at every start". A guard-then-act reading of "re-runs its
   privileged steps even when the web applications already exist" gives the second. Under that
   reading, Marcus's change-controlled instance (UJ-4) has auditing **silently re-enabled on every
   container restart** by a portal he installed, reversing a deliberate operator decision that the
   Security slice's own screen made and audited. Under the first reading, a fresh Community container
   that was once configured and then wiped comes up with the events registered but auditing off. Two
   implementers will choose differently and both cite AD-17.
3. **Rows that come back.** A user event the operator deleted on purpose reappears after every
   restart with no explanation on the screen that shows it.

**Closing AD.** AD-24 (which puts every registered `Source/Type/Name` in the install-owned set),
plus:

### AD-29 — Install asserts creation, never operator state

- **Binds:** AD-17; FR-47; FR-66; UJ-4; the README's documented security-posture change
- **Prevents:** an installer silently reversing an operator's audited decision on every restart, and
  a fresh container opening with the marker unregistered
- **Rule:** The installer **creates what is missing** and never changes what exists: it registers any
  unregistered OcuPilot audit event on every start, and it enables auditing **only on a first install
  into this instance**, recorded by a one-time install marker in OcuPilot's own state. On subsequent
  starts it *reports* the auditing state and leaves it alone; the "Agent writes are not being marked"
  banner and its "Turn auditing on" action are the only path back on. The banner's condition is
  widened to *auditing off, OR OcuPilot's Source disabled, OR any of OcuPilot's declared events
  unregistered* — the third condition being the one AD-24 makes unreachable by write but not by an
  out-of-band change.

---

## 7. The progress buffer holds the protected data at an unprotected level — High

**Units.** `Kernel/Agent` (turn job, AD-7) × `Kernel/State` (AD-9).

**What `Kernel/Agent` does, fully compliant.** AD-7: the job "writes per-step progress to a temp
global keyed by turn id; the panel polls `GET /api/ocupilot/turn/{id}/progress`". EXPERIENCE fixes
what the panel renders from that buffer: each tool-call card's "arguments summary and the result (for
a read, the rows returned)", the running/done/failed status, and — because the proposal card is
delivered on the same progress response in the sequence diagram ("A-->>P: steps and proposal") — the
diff rows. So the buffer holds tool arguments, read results and the computed diff.

**What `Kernel/State` does, fully compliant.** AD-9 protects "agent definitions, switches, the ledger,
transcripts, proposals" in a dedicated database behind a dedicated resource, reached only through a
privileged routine application inside `New $ROLES`. FR-29's acceptance test: a holder of
`%DB_<install-namespace>:RW` plus `%Admin_Operate` "cannot read or write any of it through SQL or
direct global access".

**The incompatibility.** The progress buffer is **not in AD-9's list**, and a temp global is by
definition in `IRISTEMP`, which no OcuPilot resource guards. So the same tool arguments, the same
read results (a user list, a wallet collection listing, a log page) and the same diff that AD-9
protects inside the transcript and the proposal are simultaneously readable through
`^IRIS.Temp.OcuPilot(...)` by any holder of `%DB_IRISTEMP:RW` — a role many developers hold on a
Community instance. FR-29's test still passes, because it enumerates *tables and globals in the
install namespace*, and the leak is in a different database entirely. Two units, one dataset, two
protection levels, and the acceptance test is blind to the gap.

Second issue on the same seam: `GET /turn/{id}/progress` must refuse a turn id belonging to another
user. AD-7 says nothing about the endpoint's authorization; nothing in the spine binds it, and turn
ids are "opaque server-minted strings" (Consistency Conventions) — unguessability is not
authorization, and NFR-6 assumes the model is compromised.

**Closing AD.**

### AD-30 — The progress buffer is protected state, owned by its user

- **Binds:** AD-7, AD-9, FR-12, FR-29, NFR-5, NFR-6
- **Prevents:** the turn's content escaping AD-9's protection through the channel that renders it, and
  one user polling another user's turn
- **Rule:** The turn's progress buffer is part of OcuPilot's protected state and lives in the guarded
  database (a `^||` process-private global is not an option — the polling request is a different
  process). It stores the turn's owning `$USERNAME` in its first node; `GET /turn/{id}/progress`
  compares it against the calling process's `$USERNAME` and returns the AD-12 not-found slug on a
  mismatch, never a 403 that confirms the id exists. FR-29's acceptance test is extended to assert
  that no OcuPilot turn content is reachable from `IRISTEMP` or any unguarded database.

---

## 8. One flat error envelope, two consumers that need different shapes — High

**Units.** `Api/` (AD-12's single response writer) × every form-page slice — `Area/Permissions` (user,
role, service editors), `Area/WebApp` (application editor, create), `Area/Security` (SSL/TLS, LDAP,
X.509 import, secret form), `Area/Task` (wizard, edit), `Area/OsMgmt` (device editor).

**What `Api/` does, fully compliant.** AD-12: "failure through one `Error.Render(status, slug,
reason)`, whose payload is **flat** `{error, reason}` with the slug drawn from a fixed enum". A test
asserts no response body contains `}{`.

**What the form-page slices do, fully compliant.** EXPERIENCE's `form-page` › Validation is explicit:
"server rules land on the field they name"; on a failed Save "the error summary banner receives focus
(`role="alert"`) with a **link per field**; fields carry `aria-invalid` and their message via
`aria-describedby`, then the first invalid field is focused and **its tab opened**"; and a tab holding
errors "adds ', N errors' to its accessible name". That is the accessibility floor (NFR-12), not a
nicety. It requires `[{field, message}, ...]` keyed to the generated schema's field names.

**The incompatibility.** The flat envelope has no slot for it. The vendor endpoints' `ValidateRequest`
and `ValidateSemantics` (AD-2) return exactly this information in a `%Status`, and the single
AdminPort is the one place it could be translated — but AD-12 forbids the shape. Six slices will each
smuggle field errors into the `reason` string and six client parsers will disagree about the
delimiter, which is precisely the "per-slice error shapes the client has to special-case" that AD-12
was written to prevent. The agent path wants the opposite: a single reportable slug ("failed —
requires `%Admin_Secure`"). One envelope, two consumers, no accommodation.

Related: AD-12 says "Internal failures render a generic reason and log the detail." A vendor
*validation* failure is not internal, so its reason passes through — which means untrusted text (a
vendor message quoting a caller-supplied value) reaches the client and, through the tool result, the
model. AD-11 covers tool results; it does not cover the error envelope.

**Closing AD.**

### AD-31 — One envelope with an optional typed field-error array

- **Binds:** AD-12; every form-page and wizard in 5.5-5.10; FR-8; NFR-12; AD-11's boundary
- **Prevents:** six slices encoding field errors into a free-text reason, and an accessibility floor
  that the response shape makes unreachable
- **Rule:** The error payload is `{error, reason, fields?}` where `fields` is an array of
  `{field, message}` and every `field` value is a name from the tool's **generated** schema (AD-3);
  the writer rejects a field name not in that schema, so a slice cannot invent keys. `fields` is
  absent on every failure that is not per-field, and its presence never changes the HTTP status or
  the slug. Rendering the array is the shell's single form-error component, not per-slice code. Error
  `reason` and `fields[].message` text originating outside OcuPilot is treated as untrusted under
  AD-11 wherever it reaches the model. The no-double-envelope test is unchanged.

---

## 9. Deleting a user does not delete the user's OcuPilot state — High

**Units.** `Area/Permissions` (delete user, FR-37) × `Kernel/State` + `Kernel/Governance` (per-user
switches, transcripts, ledger, read-only flag).

**What `Area/Permissions` does, fully compliant.** `permissions.users.delete` refuses only AD-10's set
(the current user, the last `%All` holder, `_SYSTEM`), obtains a confirmed proposal, deletes the user
through AdminPort, publishes `(user, "dana", delete)` and emits a marker.

**What `Kernel/State` does, fully compliant.** Every per-user artifact the PRD names is keyed by the
login name, because that is the only identity the process carries (AD-1, AD-8) and the only identity
the audit database records (EXPERIENCE: "`<user name>` in any string is the login name, as the audit
database records it"): the per-user kill switch (FR-20), the per-user read-only toggle (FR-19,
"stored on the instance, not in the browser"), the per-user context-sharing preference (FR-11),
per-user turn limits (FR-19), transcripts (FR-72, "stored per user"), and ledger rows (FR-21).

**The incompatibility.** IRIS user names are reusable. Delete `dana`, create `dana` a week later, and
the new account silently inherits:

- the old dana's **transcripts** — which FR-72 gates as "a user sees only their own", so the new dana
  legitimately reads the old dana's conversations, screen contexts and tool results, including
  whatever the old dana's higher privileges surfaced. That is a privilege-crossing disclosure with no
  audit trail, because reading one's own transcript is not a ledger event;
- the old dana's **per-user kill switch and read-only flag** — so a newly created account may arrive
  already switched off, or already exempt from a restraint an administrator set for a different
  person;
- the old dana's **ledger rows**, which FR-72's administrator-access rule filters by "every resource
  the transcript's tool calls required" — a filter that now evaluates against a different human's
  privileges.

No AD assigns ownership of the user entity's lifecycle across the slice boundary, and AD-14's change
event carries `delete` but nothing in the kernel subscribes to it — AD-14 is explicitly a *client-side*
bus ("one client-side event bus"), so the server never hears about the deletion at all.

**Closing AD.**

### AD-32 — Per-user state is keyed by an OcuPilot-minted principal id, reconciled on the server bus

- **Binds:** AD-9's state; AD-14; FR-11, FR-19, FR-20, FR-21, FR-72; PM-04
- **Prevents:** a recreated login inheriting a previous holder's transcripts, ledger, switches and
  restraints
- **Rule:** OcuPilot mints a stable principal record on a user's first turn, holding the login name
  and the instance-unique identity IRIS exposes for the account; all per-user state references the
  principal id, never the bare name. A confirmed write whose entity type is `user` and whose action is
  `delete` publishes on a **server-side** change channel — the mirror of AD-14's client bus, and the
  only cross-slice server signal that exists — which the kernel consumes to tombstone the principal:
  switches and preferences are dropped, transcripts and ledger rows are retained under the tombstone
  and are never readable by a later login of the same name. A later login with a name matching a
  tombstone mints a new principal. A test creates a user, runs a turn, deletes the user, recreates it
  and asserts the new principal sees zero prior transcripts.

---

## 10. Install and the first request race; the upgrade path is the daily path — High

**Units.** `Install/` (AD-17) × `Kernel/Agent` + `Screen/Tool` (AD-7, AD-3, AD-5).

**What `Install/` does, fully compliant.** AD-17: all install logic in one class, run "at **container
start**, not at image build", idempotent, guard-then-act, "re-runs its privileged steps even when the
web applications already exist", compiling a generated class roster.

**What `Kernel/Agent` does, fully compliant.** AD-7: `POST /api/ocupilot/turn` starts a background
job and returns immediately; the job survives a browser reload; Confirm is a separate short
foreground request that executes from the stored arguments. AD-3: write schemas are generated at
**build** time. AD-5: routes, tools and change-event routing are derived from the descriptor registry
at runtime.

**The incompatibility.** Nothing in the spine orders *install complete* before *the API answers*. On
the FR-67 upgrade path — a newer image against an existing `./iris-data`, which SM-2 makes a **daily**
event during the voting week and which every judge on a second `docker compose up` performs — the web
applications, the resource, the role and the state database all already exist on the durable volume,
so the CSP Gateway serves `/api/ocupilot` from the moment IRIS accepts connections, while the
installer is still inside `$System.OBJ.CompilePackage("OcuPilot")`. Three concrete failures, none of
which any AD forbids:

1. A turn job starts against a **partially compiled** descriptor registry and resolves a tool set
   that is neither the old one nor the new one; AD-5's derivation makes the registry the router, so
   the failure is a missing route, not a compile error.
2. A proposal minted before the upgrade is confirmed after it. AD-6 executes "from the **stored**
   arguments", validated against AD-3's generated schema — which has changed. A field the old schema
   had and the new one dropped is passed to `MergeJsonAndProperties` and, under get-merge-put, is
   written. AD-6's fingerprint does not cover schema identity, so the confirm succeeds.
3. AD-9's state classes are being recompiled while a confirm request reads a proposal through them.

**Closing AD.**

### AD-33 — A readiness generation gates the API and stamps every proposal

- **Binds:** AD-17, AD-7, AD-3, AD-5, AD-6; FR-67; SM-2's daily publish
- **Prevents:** a turn or a confirm crossing an install, and a proposal executing against a schema it
  was not minted for
- **Rule:** The installer writes a **readiness generation** — a monotonic value derived from the same
  source that generates the class roster and the IPM manifest — as its last step, and clears it as its
  first. Every OcuPilot API request other than a fixed health route refuses with one AD-12 slug
  (`installing`) while the generation is absent; the shell renders it as the instance-unreachable
  state with Retry, which already exists. Every proposal stores the generation in force at mint;
  confirm refuses on a mismatch with "target changed, re-propose" and the card says the instance was
  upgraded. A running turn job checks the generation between steps exactly as it checks the Stop flag
  (AD-7) and ends with the FR-23 error card naming the upgrade.

---

## 11. "Pause auto-refresh while a proposal is live" has no channel — Medium-high

**Units.** `ui/src/app/shell/panel/` (proposal lifecycle) × each `ui/src/app/areas/<area>/` screen
store.

**What the panel does, fully compliant.** It owns the proposal card, its countdown, its Confirm and
its cancellation rules (AD-6, AD-7, EXPERIENCE's Agent Write Lifecycle).

**What a screen store does, fully compliant.** AD-19: "Each screen's data, sort, filter, selection,
max-rows and **auto-refresh** state live in a signal store owned by the screen ... **Nothing mutates
another screen's store. Cross-screen communication is the change-event bus (AD-14) and the router,
nothing else.**"

**The incompatibility.** FR-7 and EXPERIENCE require: "Refresh pauses while a proposal is awaiting
confirmation on that screen, so the diff under review does not move; the pause ends when the proposal
is resolved or expires", with the visible chip string "Auto-refresh paused — a proposal is awaiting
confirmation". AD-14's bus carries exactly one message — a *confirmed write* `(entity type, id,
action)`. There is no message for "a proposal on entity type X opened" or "closed", and AD-19 forbids
the two obvious alternatives (the panel writing the screen's store; the screen reading the panel's).
So the requirement is unimplementable as the spine is written, and two teams will implement it two
ways — an injected `ProposalState` service the screen reads (which is a second cross-screen channel,
against AD-19) or the panel calling into the store (against AD-19's first sentence).

The same missing vocabulary blocks two more stated behaviours: the off-screen toast's "Open in
`<screen>`" needs a reverse index from entity type to screen (ambiguous when a list and its editor
declare the same key), and the "Changed" highlight needs the *action* to distinguish a created row
(appears highlighted **and selected**) from an updated one.

**Closing AD.**

### AD-34 — The bus carries a fixed message vocabulary, and only the bus crosses screens

- **Binds:** AD-14, AD-19; FR-7, FR-14; EXPERIENCE's Screen Synchronization section
- **Prevents:** a second cross-screen channel invented per area to carry proposal state
- **Rule:** The client bus carries exactly four message kinds, all keyed by
  `(entityType, scope, id)` per AD-28: `changed` with an action of `create | update | delete`,
  `proposal-open`, `proposal-closed`, and `navigate`. The panel publishes the proposal kinds; screen
  stores subscribe; no store mutates another and no component reads the panel's state. The
  entity-type-to-screen reverse index used by the off-screen toast is derived from the descriptor
  registry and resolves to the screen the descriptor marks `primaryFor` that entity type, so a list
  and its editor cannot both claim the toast.

---

## 12. AD-5 cannot describe OAuth, and cannot describe Task history — Medium-high

**Units.** `Area/Security` (`OAuth 2.0`: one screen, five tabs, five entity types, two deletes) ×
`Area/Task` (`Task history`: rows that are not the entity the detail route uses).

**What `Area/Security` does, fully compliant.** EXPERIENCE fixes the surface: "one screen, five tabs:
Client server descriptions · Client configurations · Resource servers · Authorization server (view) ·
Server client descriptions". AD-5 says "Each screen is declared **once**" with *one* entity-type key,
*one* id accessor and *one* read tool ("`read` for the one read tool per screen"). The compliant
implementation is a single descriptor `security.oauth` with entity type `oauthentry`, a composite id
`clientconfig|myclient`, a read tool taking a `tab` argument that fans out to five endpoints, and
five write verbs.

**What `Area/Task` does, fully compliant.** `tasks.history` rows are history records with no
independently re-readable identity through the admin API. The compliant implementation declares the
entity type as `task` (the thing the screen is *about*) with the task name as the id, so change
events route and the read tool takes a task id.

**The incompatibility.** The kernel consumes `(entityType, id)` from both and gets two different
contracts:

- Under Security, `id` is a **slice-private composite** that only the Security slice can resolve to an
  endpoint. `Kernel/Proposal`'s "re-read the target" (AD-6) has no generic path to
  `clientconfig|myclient`; AD-13 promises the id is one encoded segment but says nothing about it
  being resolvable. So either the kernel learns a slice's private grammar (a slice reaching into the
  kernel) or every slice supplies a re-read callback the spine never mentions.
- Under Tasks, `id` identifies the **parent**, not the row, so the screen context's "selected entity"
  is not what the user clicked. The agent asked "explain this history row" receives the task and its
  whole history; FR-71's citation chips ("clicking a chip selects the cited row") have nothing to
  select; and a proposal targeting the screen's entity targets the task while the user is looking at
  a row.

AD-5 lists ten declarations and does not say whether `entity-type key` names the row, the target of
the detail route, or the subject of the screen — and the three differ on at least five Release 1
screens (OAuth, Task history, Wallet collections -> Secrets, Application errors drill-down, REST
explorer -> OpenAPI document).

**Closing AD.**

### AD-35 — One descriptor per entity type; a multi-entity surface is several descriptors sharing a route

- **Binds:** AD-5, AD-6, AD-13, AD-14; the OAuth screen, Task history, Wallet, the application error
  drill-down, the REST explorer
- **Prevents:** a composite id only its own slice can resolve, and a screen whose declared entity is
  not the thing its rows are
- **Rule:** A descriptor declares exactly one entity type, whose id is the identity the backing
  endpoint accepts for a single-entity read — no composites, no slice-private grammar. A surface that
  presents several entity types (tabs, embedded lists, a drill-down) is several descriptors sharing a
  route, each with its own read tool, privilege resource, change-event key and command-box aliases;
  the route resolves to the descriptor whose tab or level is active. Where a screen's rows are not
  independently re-readable, the descriptor declares `rowsAreSubordinateTo` naming the parent entity,
  and the kernel treats the parent as the proposal target and the row as citation-only. Every
  descriptor supplies a `ReadOne(id)` the kernel can call without knowing the slice.

---

## 13. Two vendor APIs, no port — Medium-high

**Units.** `Area/OsMgmt` (system usage and dashboard meters, FR-56; alerts via monitoring, FR-60's
partner) × `Area/Log` (alerts.log recent entries from the monitoring API, FR-60) — with
`Area/WebApp` (REST explorer over `/api/mgmnt`, FR-33, FR-34) as a third.

**What the spine says.** The paradigm names **three** ports — AdminPort, ProviderPort, LogFilePort —
and asserts "Nothing else crosses the boundary". The Stack table nonetheless pins `/api/monitor` and
`/api/mgmnt` v2, the Containers diagram draws `Slices --> Monitor["/api/monitor"]` as a direct edge
with no port, and AD-1 forbids *tools* from issuing HTTP to `/api/mgmnt` while saying nothing about
screens or the client.

**What each unit does, fully compliant.** `Area/OsMgmt` reaches `/api/monitor/metrics` **server-side**
from its slice code (AD-1's spirit, one hop, the user's process). `Area/Log` reaches
`/api/monitor/alerts` **client-side**, because the PRD records that the monitoring API is
unauthenticated on the instance and a browser fetch is cheaper than a server hop. `Area/WebApp`
reaches `/api/mgmnt/v2/...` client-side with the Bearer token, because the management API is
JWT-enabled and the OpenAPI document is large.

**The incompatibilities.**

1. **Two error shapes.** FR-8 requires "the shell renders admin API and OcuPilot API errors the same
   way"; AD-12 owns one envelope. A client-side call to `/api/monitor` or `/api/mgmnt` returns the
   *vendor's* shape, which no AD maps, so Logs and WebApp each write their own mapping and their 403
   and 5xx presentations diverge from the other four areas'.
2. **Two auth postures, one of them stale.** FR-1's refresh-and-retry-once lives in the single API
   service (AD-20). A slice calling `/api/mgmnt` directly gets a hard 401 mid-session and drops the
   user to the form login, losing the form values EXPERIENCE already flags as lost.
3. **AD-11 bypassed.** Alert text and OpenAPI documents fetched client-side enter the screen store,
   then the context serializer, then the turn — as *screen context*, not as delimited tool-result
   content. AD-11's boundary ("untrusted text enters only as delimited tool-result content") is
   defeated for the two most attacker-writable sources in the product: log/alert text, and a
   third-party OpenAPI document's `description` fields.
4. **AD-20 does not cover it.** AD-20 binds only "every client call to `/api/ocupilot`", so a relative
   `api/mgmnt/...` from a deep route resolves against `<base href>` into the static application and
   is answered with `index.html` — the exact silent failure AD-20 exists to prevent, unguarded for
   two of the four APIs.

**Closing AD.**

### AD-36 — Every vendor API is a port; slices never reach a network

- **Binds:** the paradigm's port list; AD-1, AD-11, AD-12, AD-20; FR-33, FR-34, FR-56, FR-60
- **Prevents:** three slices inventing three access paths to two vendor APIs, and untrusted vendor
  text entering the turn outside the tool-result boundary
- **Rule:** `MonitorPort` and `MgmntPort` join AdminPort, ProviderPort and LogFilePort. Every read of
  `/api/monitor` and `/api/mgmnt` goes through its port, in process, on the server, exactly as AD-1
  requires of tools; the client never calls a vendor API except the sign-in and `/info` calls the
  shell owns. Each port renders failures into the AD-12 envelope and marks its results untrusted, so
  they reach the model only as delimited tool-result content (AD-11). The API service's
  relative-path refusal (AD-20) applies to every absolute API path the client uses, not only
  `/api/ocupilot`.

---

## 14. A screen rename disables its own write tools — Medium-high

**Units.** `Kernel/Governance` (AD-22) × any slice that renames or splits a screen — concretely
`Area/Security`, whose OAuth editors are scheduled **early in the polish week** (FR-75, PRD 10.2).

**What `Kernel/Governance` does, fully compliant.** AD-22: "Policy keys are `tool` or `tool:action`. A
frozen baseline captured at the Release 1 freeze means 'pre-existing, therefore enabled'; a key
absent from it is new and is **disabled by default when it mutates**. The baseline is never
regenerated to grow."

**What `Area/Security` does, fully compliant.** Tool names are `<area>.<screen>.<verb>` (Consistency
Conventions), and screen names come from AD-5's descriptors. Release 1 ships one OAuth screen, so its
delete tools are `security.oauth.deleteclientconfig` and `security.oauth.deleteserverclient`. Polish
week splits the surface into five editors, as FR-75 and AD-35 both require; the tools become
`security.oauthclientconfig.delete`, `security.oauthresourceserver.save`, and so on.

**The incompatibility.** Every renamed key is **absent from the frozen baseline**, therefore new,
therefore **disabled by default because it mutates**. The OAuth editors — the polish week's first
scheduled item, chosen precisely because the contest task statement names OAuth setup — ship with
their writes silently refused by policy, returning the "This tool is disabled by policy" result while
staying advertised. FR-72's own consequence, "the policy's frozen baseline enables every write
tool-and-action key Release 1 ships, so SM-3 holds through 2026-10-04", is violated by a rename that
no AD forbids and that AD-35 actively requires. The failure is silent, policy-shaped, and lands in
the week SM-2 demands a visible improvement every day.

The same trap fires for any step-3-to-step-6 screen reshuffle inside the build order, and for the
Tasks slice if Task schedule and Upcoming tasks are consolidated.

**Closing AD.**

### AD-37 — Governance keys are stable tool ids, never derived from a name

- **Binds:** AD-22, AD-5; the Tool naming convention; FR-72; SM-2, SM-3
- **Prevents:** a rename or a screen split silently disabling shipped write tools
- **Rule:** Each write tool declares an immutable `ToolKey` once, at creation, independent of its area,
  screen or verb; the governance baseline, the ledger and the audit marker all reference the key,
  while the dotted `<area>.<screen>.<verb>` name is display and model-facing only and may change
  freely. A build check fails when a `ToolKey` present in the frozen baseline has no descriptor, and
  when a new descriptor reuses an existing key. Renaming is therefore free; introducing a new
  capability still defaults to disabled, which is what AD-22 is for.

---

## 15. The card says the payload sends 38 fields; AD-4 says it sends two — Medium-high

**Units.** `Kernel/Proposal` (diff builder, AD-4, AD-6) × the six slices' proposal-card rendering and
the UX contract.

**What `Kernel/Proposal` does, fully compliant.** AD-4: "A write carries exactly the fields the diff
shows as changed, plus the identifying key. The unchanged fields the UX collapses under 'N unchanged
fields' are *displayed* from the fresh read; **they are not resent**."

**What EXPERIENCE fixes, and the slices render.** The proposal card's disclosure is "the unchanged
fields **that the payload still sends**, collapsed under 'N unchanged fields' (every field stays
available, FR-17)", and UJ-3's canonical card reads "38 unchanged fields" beneath two changed rows.
FR-17's consequence: the card shows "**every field the payload will send**".

**The incompatibility.** The disclosure's label and its stated meaning are contradictory: AD-4 makes
the payload two fields; the card asserts forty. That is not cosmetic — it is the **review contract**.
The user confirming a proposal is being told the write is a full replacement, which is the safer
mental model and the one that justifies collapsing forty rows into a disclosure. Under get-merge-put
with a two-field body, a concurrent change to any of the other 38 fields between mint and confirm
**survives the write** — correct behaviour, but the opposite of what the user reviewed. Combined with
finding 4 (a fingerprint that may not cover those 38 fields), the card can honestly display a value
for a field that has since changed, will not be sent, and whose change did not invalidate the
proposal.

**Closing AD.** Fold into AD-27 and amend the fixed string. The correct disclosure label for a
merge-semantics write is "N fields not changed by this write", with the caption stating that they are
displayed from a fresh read and are not sent; and the fields shown under it must be exactly the
declared `FingerprintFields` (AD-27) so that "displayed but not sent" still means "guarded". Fields
outside the fingerprint set are not displayed at all, because the card cannot make any statement
about them.

---

## 16. One declared privilege resource, two enforcement depths — Medium

**Units.** `Kernel/Screen/Tool` (dispatch gate, AD-8) + any admin-API-backed slice × `Area/Log`
(LogFilePort-backed screens).

**What the kernel does, fully compliant.** AD-8: "Every gate is `$System.Security.Check(resource,
permission)` evaluated in the calling process at the moment of the call, **against the resource the
screen descriptor names**."

**What an admin-backed slice gets.** Two gates: the descriptor's resource at dispatch, and the
vendor's own `ResourcesOR()` inside AdminPort (AD-2). A wrong or missing resource in the descriptor is
invisible, because the vendor's gate catches it.

**What `Area/Log` gets.** One gate. `LogFilePort` reads `messages.log` and `alerts.log` from
`$System.Util.ManagerDirectory()`; a file read through `%Stream.FileCharacter` is gated by the OS, and
the IRIS process runs as `irisowner` regardless of `$USERNAME`. AD-21 binds the log endpoints and
specifies the fixed enum and the SQL binding — **it says nothing about a resource gate**. FR-18 does
("The log endpoints require the same resource the classic portal's log pages require"), but the spine
did not carry it into an AD.

**The incompatibility.** The same declared field — AD-5's "privilege resource" — is load-bearing in
one slice and redundant in five. An omitted or too-weak resource on `logs.messages` or
`logs.alerts` hands every user holding any `%Admin_*` resource the full contents of `messages.log`,
which routinely carries connection strings, user names, license details and stack traces; the classic
portal gates those pages behind `%Admin_Operate`. No test catches it, because the five other slices'
tests pass with a wrong descriptor resource too.

**Closing AD.** Add to AD-21: *"Every log endpoint checks `$System.Security.Check("%Admin_Operate",
"USE")` in its own body, in addition to the descriptor's gate, because no downstream gate exists on
the file path; a test asserts a user holding `%Admin_Secure` alone is refused."* And add to AD-5 a
build check that every descriptor's privilege resource is non-empty and exists on the instance.

---

## 17. Two composite-id grammars under a one-segment rule — Medium

**Units.** `Area/Log` (application error drill-down: namespace -> date -> error) × `Area/OsMgmt`
(Locks: remove one lock, all of a process, all of a remote client).

AD-13: "A route is `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`. The id occupies **one segment**
and is percent-encoded on write and decoded on read by one shared pair of functions." The round-trip
corpus tests the encoder against "a leading underscore, a slash, a space, a percent sign and a
non-ASCII character".

**What each unit does, fully compliant.** `Area/Log` needs three keys and packs them into one segment
as `USER|2026-09-08|17`, then percent-encodes the whole thing with the shared encoder — AD-13
satisfied to the letter. `Area/OsMgmt` needs `(namespace, lock reference, owner pid)` and picks a
different separator, or a different order, or a length-prefixed form.

**The incompatibility.** AD-13's corpus proves the *encoder* round-trips; it proves nothing about the
*composite grammar*, which is now per-slice and untested. Two consequences: an IRIS lock reference can
legally contain the separator `Area/OsMgmt` chose (lock references are arbitrary global references
including subscripts with punctuation), so the decode is ambiguous in exactly the slice where the
write is destructive; and EXPERIENCE's sibling rule — "Confirming one proposal cancels its siblings on
the same entity" — is implemented in the kernel as a string comparison over two grammars, so
`%SYS|^MYLOCK` and `%SYS|^MYLOCK ` (a trailing space, legal) are different entities and both
proposals confirm.

**Closing AD.** Amend AD-13: *"Composite ids are forbidden. A screen whose target needs more than one
key declares them as ordered path segments in the descriptor — `/ocupilot/<area>/<screen>/<k1>/<k2>` —
and the shared encoder encodes each segment independently. The round-trip corpus is extended to the
declared multi-segment forms, including a value containing every separator character."*

---

## 18. Two answers to how much of the screen travels with a turn — Medium

**Units.** `Kernel/Agent` (message assembly, AD-11) × each slice's context serializer (AD-5).

**What AD-11 requires.** "Untrusted text enters only as delimited tool-result content — never the
system prompt, never the user role", and it names screen context first in its list of untrusted
sources.

**What AD-5 provides.** "context serializer with its secret-typed field list" — one opaque function
per screen returning one payload. It does not distinguish the trusted parts (route, namespace,
descriptor name, selected entity id, row count — all kernel- or descriptor-generated) from the
untrusted parts (row values, entity names, comments, log lines), and it sets no size bound.

**The incompatibility.** Two slices serialize differently and the kernel cannot tell:

- `Area/Log`'s serializer returns raw log *lines* from `messages.log` — the single most
  attacker-writable text in the product, since any process on the instance can write it.
- `Area/Permissions`' serializer returns row objects including `Comment`, a user-writable field.
- `Area/OsMgmt`'s returns process rows including the client executable name and the current SQL
  statement.

If the kernel places the whole context in the system prompt (which is the natural implementation of
"the agent receives the current screen context with every turn"), AD-11 is violated for all three. If
it wraps the whole context as a synthetic tool result, the *route and namespace* are also treated as
untrusted, which is harmless but means AD-11's boundary is expressed nowhere in the descriptor.

Separately, the spine **dropped an explicit UX ask**: EXPERIENCE's Information Architecture carries
`[NOTE FOR ARCHITECTURE] cap the rows that travel with a turn (a viewport holds about 16; 50 is a safe
ceiling) and show the count on the read tool-call card — a 1,000-row fetch must never be sent to the
provider.` No AD adopts it. The data-table's cap is 1,000 rows; "the rows currently in the viewport"
is meaningful for a CDK virtual scroll and meaningless for a `list (server criteria)` screen. Two
slices will pick 16 and 1,000.

**Closing AD.** Amend AD-5: *"The context serializer returns two named parts — `identity` (route,
descriptor name, scope, selected entity id, row count; kernel-trusted) and `content` (row values;
untrusted) — and the kernel places `identity` in the turn's framing and `content` only inside the
delimited untrusted block. `content` is capped at a spine-level constant of 50 rows and 8 KB after
serialization, truncation is reported in `identity.truncated`, and the read tool-call card shows the
count sent."*

---

## 19 and 20. Two shorter divergences

**19. The privilege map versus the call-time check — Medium.** `ui/shell` caches the admin API's
`%Admin_*` privilege map at load (FR-4, and EXPERIENCE's exit condition for a gated entry is
"privilege granted -> next load"). `Kernel` checks `$System.Security.Check` at call time and never
caches (AD-8). After a confirmed `permissions.users.addrole` granting the current user a role, the
nav entry stays gated with "Requires %Admin_Secure" while the agent performs the same write happily —
two answers to "can I do this" inside one session, on the one screen most likely to change them.
*Fix:* the change-event bus's `changed` message for entity type `user` with the current user's id
invalidates the shell's privilege map, which refetches; the map is a cache with a declared
invalidation, not a load-time snapshot.

**20. Nobody owns the transaction boundary — Medium.** AD-2's sequence (`ValidateRequest ->
ValidateSemantics -> Run`) says nothing about transactions, and multi-step writes exist — the role
resource grant (`Modify` plus `Grant`), the wizard's create-then-schedule. A slice that wraps its
write in `TSTART/TCOMMIT` for atomicity is following ordinary practice; `Kernel/Audit` then writes the
ledger row and emits the marker *after* the write, inside the still-open transaction if the slice's
error path did not roll back — and the project's own rule forbids side effects inside a transaction
for exactly this reason. A `TROLLBACK` on the slice's error path then discards the ledger row that
recorded the failure, which is the one row the ledger exists to hold. AD-15's "Audit emission never
fails a write, and never propagates" addresses the opposite direction only.
*Fix:* amend AD-2 with *"AdminPort opens no transaction and asserts `$TLEVEL = 0` on entry and on
exit, restoring it in the Catch; a slice needing atomicity declares it and the transaction is opened
and closed inside the slice's own write body, before the kernel's ledger and marker run."*

---

## Cross-unit assumptions no AD assigns an owner

Not divergences, but places where two units both assume the other verified something:

1. **AD-9's escalation inside AD-7's background job.** The memlog proves `New $ROLES` containment in a
   foreground process and proves `JOB` inherits `$USERNAME` and `$ROLES`. It does **not** prove that
   `$SYSTEM.Security.AddRoles(<privileged routine application>)` works in a jobbed process with no
   `%request` and no CSP application context. The turn job must mint a proposal and write ledger rows
   into the protected database (AD-9's list), so if it does not, build step 2 — the SM-3 gate — fails
   at the last integration. Owner: `Kernel/State`, verified against `Kernel/Agent`, before step 2.
2. **AD-2's `ResourcesOR()` for the 70 endpoints was probed on one class.** `%Api.Admin.Endpoints.WebApp.App`
   was verified. The AdminPort is implemented once for all of them; a class whose `Run` touches
   `%request` despite `IsRunningAsync = 1`, or whose `ValidateSemantics` assumes a dispatch context,
   fails only in the slice that first uses it. Owner: `Port/AdminPort`, with a generated smoke test
   that instantiates every endpoint class the descriptors reference and asserts a clean list call.
3. **AD-17's CSP Gateway registration gap.** The spine has the installer *report* it. Nothing says
   what the shell does when `/ocupilot` returns 404 on a first install — which is the judge's very
   first interaction (UJ-5). Owner: `Install/`, with a README step and a start-script probe.
4. **AD-20's deep-link fallback versus AD-33's readiness gate.** The static application answers
   `index.html` for unknown paths; during an install the API refuses. The shell must distinguish
   "installing" from "unreachable" from "wrong version" (three of its four blocking states) using
   only the one health route AD-33 leaves open. Owner: `ui/shell` + `Api/`.

## Recommended adoption order

AD-24, AD-25 and AD-26 close the three critical findings and are cheap — a generated roster, a
refusal-not-a-gate rule, and a declared field partition. AD-27 and AD-28 change the proposal record's
shape and should land before build step 2 freezes it. AD-31, AD-33 and AD-34 change contracts the
client depends on and should land before step 3. AD-35 and AD-37 are the ones that cost the most if
deferred past the Release 1 freeze, because both are about names that become permanent at that
moment.
