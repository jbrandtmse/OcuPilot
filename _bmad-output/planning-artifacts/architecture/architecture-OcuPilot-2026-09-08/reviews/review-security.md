---
name: Security review — OcuPilot architecture spine
type: review
lens: security
target: ../ARCHITECTURE-SPINE.md
reviewed: AD-1 through AD-25; PRD §6 (NFR-3..NFR-7), §7; addendum §2
date: '2026-09-08'
status: draft
---

# Security Review — OcuPilot Architecture Spine

**Verdict.** The spine's security model is unusually well-formed for a document at this
altitude: AD-6, AD-8, AD-9, AD-10 and AD-11 name the right invariants and mostly name them in
the right order. It does not yet survive contact. Three findings are exploitable as written and
each defeats a load-bearing invariant end to end — a `JOB` started inside AD-9's escalated frame
carries the elevated role for the child's whole life (verified on the instance), AD-6's
secret-at-confirm channel is unbound and re-opens client-authored write arguments, and AD-3's
generated schemas will contain the admin API's password fields by default while every redaction
mechanism in the design keys off a single hand-maintained annotation. The recurring structural
weakness is that the strongest claims — "escalation is never in effect while tool code runs",
"privilege is checked at call time", "no write without a confirmation on a server-computed diff"
— are asserted as facts about call ordering with no enforcement point named and no test that
would fail if they became false.

Twenty-six findings, most severe first.

---

## Evidence gathered on the instance

Probes run against `ocupilot-iris` (IRIS for Health 2026.2 build 221U), then cleaned up:

| Probe | Result |
| --- | --- |
| `New $ROLES` · `Set $ROLES="%Manager"` · `Job Child()` | Child's `$ROLES` = `%All,%Manager` **for the child's entire lifetime**. `New $ROLES` bounds the parent frame only. |
| Exception thrown inside the escalated frame, caught in the **caller** | `$ROLES` restored at the catch (`%All`). AD-9's stated verification holds — for that frame arrangement only. |
| Method called **downward** from inside the escalated frame | Sees `%All,%Manager`. Escalation is inherited by every callee. |
| `Xecute` inside the escalated frame | Runs escalated. |
| `Set $ROLES = ""` as `_SYSTEM` | Still `%All`. `$ROLES` is login-roles + added-roles; the assignment sets only the added portion, and **cannot drop a login role**. Any design that expects to *reduce* privilege by assigning `$ROLES` is wrong. |
| `GET /api/monitor/metrics`, no credentials | **HTTP 200.** |
| `GET /api/admin/v2/`, `GET /api/atelier/`, no credentials | HTTP 401. |

---

## SEC-01 — Generated write schemas carry the vendor's password fields, and every redaction path keys off one hand-written annotation · **CRITICAL**

**Attack.** AD-3 derives a write tool's JSON schema at build time from the endpoint's
`RequestBodySchema()` and forbids restating field types — narrowing is only by "an explicit
subset of field names". The admin API's write payloads for users, SSL configurations, X.509
credentials, OAuth clients, LDAP and the wallet contain secret fields (`Password`,
`PrivateKeyPassword`, `ClientSecret`, wallet `SecretValue`, LDAP bind password). AD-3's default
is therefore to *include* them. FR-17 requires each such field to be "declared secret in its
schema" and refused from the model — but nothing derives that declaration; it is authored per
tool, per field, by hand, against roughly forty payload contracts the PRD itself flags as
unobserved. One missed field advertises a `PrivateKeyPassword` parameter to the model.

**Precondition.** One annotation omitted on one write tool. No attacker capability required to
create the hole; injected content (AD-11's threat model) or an ordinary user request then walks
through it.

**Impact.** A single missing annotation breaches NFR-5 at four independent sites at once,
because every mechanism keys off the same annotation: the model emits the secret in its
tool-call arguments (so it has *already left the instance* in the provider request), AD-6 stores
it in the proposal's arguments (contradicting "secret-typed fields are excluded from the stored
arguments"), the proposal card renders it in the diff, and FR-21's schema-driven ledger
redaction does not drop it because the schema does not mark it. There is no runtime signal that
any of this happened.

**AD to tighten — AD-3, and a new backstop clause.**

- **Binds:** every generated write schema; NFR-5; FR-17's secret-field rule; FR-21's ledger
  redaction.
- **Prevents:** a secret field reaching the model, the proposal store, the diff or the ledger
  because one annotation was forgotten.
- **Rule:** The generator marks a field secret when **any** of three sources says so: the vendor
  schema (`format: password`, `writeOnly`, or the field's presence in the endpoint's
  write-only set), the shared secret name matcher, or the screen descriptor's explicit
  declaration. A field the matcher flags that the descriptor does not declare **fails the
  build** — the annotation is confirmed, never authored from scratch. Independently of the
  schema, the proposal store and the ledger writer run the name matcher over every field they
  are about to persist and drop matches. FR-21's "by schema, not by pattern" is restated: the
  schema is the contract, the pattern is the backstop, and the blast radius does not justify a
  single point of failure.

---

## SEC-02 — A background job started inside AD-9's escalated frame inherits the state role permanently · **CRITICAL**

**Attack.** Verified above: `New $ROLES` + `Set $ROLES = <added>` followed by `Job` gives the
child the parent's *current* role set for the child's whole life. `New $ROLES` restores the
**parent's** frame; it has no reach into a process that has already been spawned. AD-9 says the
role "is gone when the frame unwinds" — true for the parent, false for anything the frame
started.

The turn endpoint (AD-7) must read the agent definition, the kill switch, the effective
read-only state and the per-user turn limit before it starts the job. All four live in the
protected database and are therefore reached through AD-9's escalating storage classes. If the
`Job` command is issued anywhere inside that escalated frame — the natural shape being a helper
that loads the definition and starts the job together — the turn job runs the entire LLM loop
and every tool with OcuPilot's state role attached. The same shape recurs in the transcript
purge task, the proposal-expiry sweep, any `%SYS.Task` created from a storage method, and the
async admin endpoints the Deferred table already anticipates.

**Precondition.** One `Job`, `%SYS.Task` creation, `$System.Event.Signal` or `%SYSTEM.WorkMgr`
call physically inside an escalated frame. No attacker action needed to create it; AD-9 as
written does not forbid it and no test would catch it.

**Impact.** Full defeat of AD-8 and, transitively, of AD-6. A turn job carrying the state role
can read every user's transcript, the whole ledger, every agent definition and the proposal
store — and can **write** the proposal store. Writing a proposal record with different stored
arguments converts AD-6's "executes from the stored arguments, never from anything the client
sends" into "executes from arguments the compromised model chose", with the user confirming a
diff that no longer describes the write. That is the confirmation invariant broken from the
inside, and it is reachable by prompt injection (AD-11's own threat model) the moment any tool
runs in a job spawned that way.

**AD to tighten — AD-9.**

- **Binds:** FR-29, FR-66; every escalated storage method; AD-7's job start; every task the
  installer registers.
- **Prevents:** an escalated role escaping its frame into a process that outlives it — the one
  way `New $ROLES` does not restore.
- **Rule:** No process-spawning or process-signalling call may appear inside the escalated
  frame: `Job`, `%SYS.Task` creation or `RunNow`, `$System.Event.Signal`, `%SYSTEM.WorkMgr`
  queueing, `$ZF` callout. The escalated region is a leaf. `POST /turn` reads every switch it
  needs, exits the escalated frame, and only then issues `Job`. A test asserts that a job
  started by the turn endpoint reports a `$ROLES` equal to the request process's pre-escalation
  baseline, and a source check fails the build on a spawn keyword inside a method that calls
  `AddRoles`.

---

## SEC-03 — The secret channel at confirm is unbound, re-opening client-authored write arguments · **CRITICAL**

**Attack.** AD-6 says confirm "executes from the **stored** arguments — never from anything the
client sends back except secrets". The exception is unqualified. Nothing states that the merged
payload is restricted to field names the tool schema marked secret, that the field path is
validated, that unknown keys are rejected rather than ignored, or that the merged fields
appeared in the diff the user reviewed.

A user reviews and confirms `security.sslconfig.update` changing `Description`. The confirm body
carries `{"secrets": {"PrivateKeyPassword": "x", "Name": "other-config", "Enabled": 0}}`. If the
merge is a loop over what the client sent, the identifying key and arbitrary non-secret fields
are overwritten by client-supplied values. The same hole answers "can a proposal for target A be
confirmed against target B" in the affirmative: the target identity is structurally safe only
while it lives exclusively in the stored arguments, and the secrets channel is the one path that
writes into them.

**Precondition.** An authenticated user holding the underlying privilege — so this is not
privilege escalation. It is defeat of the reviewed-diff invariant, which is what makes it
critical rather than routine.

**Impact.** The executed change and the audited change diverge: AD-15's marker and FR-21's
ledger row record the *proposal*, while the instance received something else. Combined with a
same-origin XSS (SEC-13) or simply a second tab, an attacker turns a user's confirmation of a
benign diff into an arbitrary write of the same tool's shape. It also undoes AD-11's central
claim, since "no write without a confirmation on a server-computed diff" is only true if the
confirmed diff is what executes.

**AD to tighten — AD-6.**

- **Binds:** FR-17's secret-field rule; every write tool whose payload contains a secret.
- **Prevents:** the secrets channel becoming a general-purpose argument-override channel.
- **Rule:** The confirm body carries exactly one object, keyed **only** by field names the tool's
  schema declares secret and that the proposal recorded as awaiting a value. A key that is not in
  that set **refuses the confirm** — it is never silently dropped. Values are type-checked against
  the schema before merge. The proposal card names which fields the user is being asked to
  supply, and the ledger row records the field *names* merged (never values). A test confirms a
  proposal with an extra non-secret key and asserts the write did not occur.

---

## SEC-04 — The turn job holds a frozen copy of the user's roles across sign-out, revocation and account disablement · **HIGH**

**Attack.** AD-7 has the job "inherit `$USERNAME` and `$ROLES` from the request process". Verified:
that inheritance is a *copy taken at spawn* and is never re-evaluated. Consequently:

- **Sign-out (FR-2)** ends the browser login and stops token minting. The job needs neither
  (AD-1 removed the HTTP hop) and has no session. It keeps running, keeps sending the user's
  screen context to the provider, and keeps minting proposals. FR-2's consequences say nothing
  about in-flight turns.
- **Role revocation.** An administrator removes `%Admin_Secure` mid-turn. `$System.Security.Check`
  in the job still passes, because it tests the process's attached role set, not a live lookup.
  AD-8's "checked at call time" is true of the *call*, false of the *roles*.
- **Account disabled or deleted.** Same; the job runs to completion.
- **Kill switch and read-only.** FR-19 and FR-20 require an in-flight turn to stop at its next
  step when either changes. AD-7 only commits the job to checking a **stop flag** between steps —
  not the kill switch, not effective read-only, not governance, not the turn limits.

**Precondition.** A turn in flight. Window is up to the turn's maximum duration (the design cites
a 90 s provider timeout and asks for a 300 s gateway timeout, and max-iterations multiplies it).

**Impact.** "The agent never holds a privilege the user does not" (§7.1, AD-8) is false for the
length of a turn after any privilege change, and stays false after sign-out — the case an
operator would most expect to be safe. It also means the emergency controls do not stop what is
already running, which is the moment they exist for.

**AD to tighten — AD-7.**

- **Binds:** FR-2, FR-12, FR-19, FR-20; every step boundary of the turn loop.
- **Prevents:** a detached process acting on a privilege snapshot the instance has already
  revoked, and emergency controls that do not reach in-flight work.
- **Rule:** The job does not trust its inherited `$ROLES` beyond the first step. At every step
  boundary it re-reads the user's current recursed role set and the account's enabled state from
  `%SYS`, and aborts the turn on any reduction or disablement; in the same check it evaluates the
  kill switch, effective read-only, the governance cascade and a session-liveness marker that
  sign-out invalidates. The maximum staleness window is one step and is stated as a number. A
  test signs the user out mid-turn and asserts the next step aborts.

---

## SEC-05 — Confirm re-checks the target and nothing else · **HIGH**

**Attack.** AD-6 requires only: valid, unexpired, unburned token; fingerprint match; execute from
stored arguments; burn. FR-17 requires considerably more — refusal "if the user, the
conversation, the agent definition or the user's read-only state has changed since the proposal"
— and AD-6 drops all of it. Three concrete consequences:

- **Confirmed by a different user.** If confirm is keyed by proposal id alone, the id is the only
  secret. It is not one: it appears in ledger rows, in AD-7's progress global (a temp global with
  no stated protection, see SEC-09), and in AD-15's audit marker, which FR-61's audit viewer
  renders to anyone who can read the audit database. Any authenticated user who reads an id
  confirms another user's proposal, and the write executes under *their* roles against a diff
  *they* never saw.
- **Privilege revoked inside the ten-minute window.** The diff was computed while the user held
  `%Admin_Secure`. AD-6 does not say the confirming process re-runs the resource gate. AD-2's
  `ResourcesOR()` probably saves this if confirm routes through AdminPort, but the spine never
  says it does, and the sequence diagram draws confirm as its own path into `D`.
- **Kill switch, read-only or governance flipped inside the window.** FR-19, FR-20 and AD-22 all
  require evaluation at confirmation; AD-6 mentions none of them.

**Precondition.** For the cross-user case: any authenticated OcuPilot user who can see a
proposal id. For the others: a ten-minute window and an administrator action.

**Impact.** Writes executing outside the authorization state that justified them, including after
an operator has pulled the kill switch — which the PRD sells as always-reachable and effective.

**AD to tighten — AD-6.**

- **Binds:** FR-17, FR-19, FR-20, AD-22; every confirm request.
- **Prevents:** a confirmation surviving the change in authorization state that would have
  refused the proposal.
- **Rule:** Confirm enumerates its preconditions and refuses on any failure: the confirming
  request's authenticated `$USERNAME` equals the minting user (the request's own identity, never
  the stored one); same conversation; same agent-definition version; kill switch off; effective
  read-only off for that user; the tool's governance key still enabled; and the descriptor's
  resource re-checked with `$System.Security.Check` in the confirming process. The proposal id is
  treated as an identifier, never as a capability — possession alone authorizes nothing.

---

## SEC-06 — The static shell application is unauthenticated *and* carries a dispatch class · **HIGH**

**Attack.** FR-65 and addendum §6 put the shell on an unauthenticated CSP application
(`AutheEnabled=64`) that must also carry a **dispatch class**, because the deep-link fallback
needs both a physical path and a `%CSP.REST` catch-all. The security consequence is never stated:
a `%CSP.REST` subclass is running with no authentication, in the `UnknownUser` context, for
anyone who can reach the port.

- Any route ever added to that class is anonymous. The harvest map takes this handler from
  iris-couch, described there as having "path-traversal checks" — which implies it takes a path.
- AD-21's "no endpoint accepts a path" is scoped to the log endpoints. The static handler
  accepts a path by definition, so the invariant that would cover it explicitly does not.
- The catch-all rewrite makes traversal and enumeration silent: everything unknown answers 200
  with `index.html`, so neither a scanner nor a *test* can tell a served file from a rewritten
  one. AD-20 already notes this silence as a functional hazard; it is also a security one.
- On a Community instance at Minimal security, `UnknownUser` holds `%All`. This project's own
  README flow (unexpiring `_SYSTEM` on every fresh container) is the signature of an instance
  that is not hardened. The anonymous dispatch class then runs with `%All`.

**Precondition.** Network reach to the instance port. No credentials.

**Impact.** Anonymous file disclosure from the instance, and — on a Minimal-security instance —
an anonymous `%All` execution context inside OcuPilot's own dispatch class.

**AD to add — AD-26, and extend AD-21.**

- **Binds:** FR-65, AD-20; the static handler; the anonymous surface.
- **Prevents:** anonymous file read and anonymous dispatch through the application that must stay
  unauthenticated for the shell to load.
- **Rule:** The static handler serves only names present in a manifest compiled from the built
  bundle — no path parameter, no filesystem walk, no traversal check needed because no path is
  accepted. The deep-link fallback returns `index.html` only for paths matching a route pattern
  derived from the descriptor registry (AD-5); everything else is 404. The static application
  declares no route besides that fallback and carries no application roles and no matching roles,
  asserted by the installer exactly as FR-65 already asserts for the API application. A test
  enumerates the anonymous surface and asserts it is exactly {bundle assets, `index.html`},
  including for traversal-shaped and percent-encoded paths. AD-21's Rule is restated to bind the
  static handler: **no** OcuPilot endpoint accepts a path, not merely the log endpoints.

---

## SEC-07 — The descriptor's privilege resource is enforced only inside AdminPort · **HIGH**

**Attack.** AD-2 enforces `ResourcesOR()` with `$System.Security.Check` as part of the vendor
dispatch sequence — but that is the *AdminPort* sequence. Three of OcuPilot's read surfaces do
not go through it:

- **Monitoring-backed screens** (alerts FR-60, dashboards and metrics FR-54..FR-58). **Verified:
  `GET /api/monitor/metrics` returns 200 with no credentials at all.** The vendor supplies no gate.
- **LogFilePort screens** — messages.log (FR-62) and the application error log (FR-63).
- **The audit database viewer** (FR-61), which is SQL-backed rather than endpoint-backed.

AD-5 has the descriptor *declare* a privilege resource and AD-8 says gates are evaluated "against
the resource the screen descriptor names" — but no AD names the enforcement point for these
ports. FR-18 does say the log endpoints require the resource the classic portal's log pages
require; nothing binds it.

**Precondition.** A signed-in user with any `%Admin_*` resource (the turn endpoint's floor per
FR-65) but not the resource the screen declares. Or, for the monitoring API, no account at all.

**Impact.** messages.log and the application error log routinely contain database paths,
namespace and routine names, licensing data, and connection strings — including credential-shaped
material from failed connections. The audit viewer exposes usernames and event data. A
low-privilege user, or the agent acting for them, reads all of it. This is also the ingress that
makes SEC-10's injection path free: alerts content is anonymously reachable.

**AD to tighten — AD-8, plus a port-level clause.**

- **Binds:** every port, not only AdminPort; FR-18's log-endpoint resource; FR-60..FR-63.
- **Prevents:** a screen whose backing API has no gate of its own being effectively ungated.
- **Rule:** Every port entry point enforces the descriptor's declared resource with
  `$System.Security.Check` before it does any work — AdminPort through the vendor's
  `ResourcesOR()`, LogFilePort, the monitoring adapter and every SQL-backed read through the same
  check written once in a port base class. A port method reachable without that check is a review
  failure. A test iterates the descriptor registry and asserts each read tool 403s for a user
  holding no resources.

---

## SEC-08 — Model-initiated navigation is an ungated action that redirects the next turn's context egress · **HIGH**

**Attack.** This is the answer to the brief's question: find an agent action not gated by a
confirmation on a server-computed diff. Navigation is it, and AD-11 explicitly blesses it —
"navigation accepts only routes present in the descriptor registry". Allow-listing the *route*
does not make navigation safe, because FR-11 assembles screen context "fresh on every turn from
the screen the user is on at that moment". Navigation therefore changes what the *next* turn
exports.

A lesser-privileged party writes an injection into a task description, a user comment or a web
application description. The user asks the agent what it does. The injected model navigates to
an allow-listed route — say the SSL configuration detail for the config holding a private key,
or the users list filtered to `%All` holders, or the audit viewer filtered to a named user
(FR-15 permits applying a filter). Whatever the user types next ships that screen's context to
the provider. AD-24 and FR-11 exclude secret-typed *fields*, so the private key stays — but the
configuration name, host, port, CA file paths, cipher list, peer names, the X.509 subject, or
the roster of privileged accounts, all leave.

Each hop looks like the assistant being helpful. Repeated across turns, injection turns the agent
into an exfiltration cursor over everything the *user* is privileged to see.

**Precondition.** Write access to any free-text field the agent reads — the weakest capability in
NFR-6's own list — plus one user question about the poisoned entity.

**Impact.** Silent data egress to a third-party provider, while §7.2's promise ("OcuPilot sends
nothing to any endpoint other than the instance and the configured provider") stays technically
true. That is precisely why it slips past the stated invariants.

**AD to tighten — AD-11 and AD-24.**

- **Binds:** FR-11, FR-15; the navigation tool; the context chip.
- **Prevents:** the model choosing what the next turn exports.
- **Rule:** A model-initiated navigation is a *proposal to navigate* the user accepts, or —
  minimum viable — it sets a per-conversation flag that suppresses screen context on the
  following turn until the user navigates themselves or re-enables sharing explicitly. The
  context chip states when the current screen was reached by the agent rather than by the user.
  The seeded-injection test (NFR-6) asserts zero navigations **and** that a navigation, if one
  ever occurs, exports no context on the next turn.

---

## SEC-09 — The progress channel is a model-writable surface rendered in privileged chrome, stored in a world-readable global · **HIGH**

**Attack.** Three distinct problems in one mechanism.

- **Unsanitized rendering.** FR-13's sanitize-and-vendor rules are scoped to "agent replies".
  Nothing extends them to tool-call cards (whose "arguments summary" is model-authored), progress
  steps, error cards, the navigation announcement, or — worst — the proposal card's "rationale and
  expected impact labeled as the agent's text". That is model-authored Markdown rendered in the
  highest-trust element in the product, the one the user reads immediately before pressing
  Confirm.
- **Social-engineering the confirmation.** The diff is server-computed and correct; the prose next
  to it is not. "Expected impact: adds a read-only reporting resource" rendered beside a diff row
  reading `Resources: %DB_IRISSYS:RW` defeats the human half of the invariant. The spine treats
  "server-computed diff" as sufficient; it is necessary.
- **The storage.** AD-7 puts per-step progress in "a temp global keyed by turn id" with no stated
  protection and explicitly outside AD-9's protected database. A temp global is readable — and
  **writable** — by any holder of the temp database's resource, which is broadly granted.
  Progress contains tool arguments and tool results, i.e. the user's screen context and admin
  data. Another process can also inject progress steps into a victim's turn, which the panel
  renders as the agent's own output.

**Precondition.** For rendering: any injection source. For the global: read/write on the temp
database, a far lower bar than the `%Admin_*` floor OcuPilot otherwise assumes.

**Impact.** Cross-user disclosure of screen context and tool results; a confirmation surface whose
narrative half is attacker-controlled; and a channel by which one user forges another user's
agent output.

**AD to tighten — AD-11 and AD-7.**

- **Binds:** FR-12, FR-13, FR-17's proposal card; the progress channel.
- **Prevents:** untrusted or model-authored text rendering unsanitized, and turn state readable or
  writable outside its owner.
- **Rule (AD-11):** Every model-authored or tool-result-derived string, wherever it renders —
  reply, tool-call card, progress step, error card, proposal rationale, navigation announcement —
  passes the same vendored sanitizer and renders in a visually distinct "agent says" treatment.
  The server-computed diff renders from server-side structure only and is never adjacent to
  model prose without the label.
  **Rule (AD-7):** Turn progress lives in the protected database (AD-9) or in a global whose
  subscript includes a server-minted per-turn secret; it is readable only through
  `GET /turn/{id}/progress`, which checks the requesting user against the turn's owner; direct
  global access by another user is proved impossible by the FR-29-style test.

---

## SEC-10 — Escalation is inherited downward and by the frame's own `Catch`, with no enforcement that the region is a leaf · **HIGH**

**Attack.** Verified: a method called from inside the escalated frame sees the elevated roles, and
`Xecute` inside the frame runs elevated. AD-9's "the storage classes — and only the storage
classes — obtain that role" and AD-8's "not in effect while any tool, port or provider code runs"
are assertions about call ordering with no named mechanism.

Two concrete shapes:

- **The frame's own `Catch`.** The project's own conventions (`objectscript-basics.md`) put the
  whole method body in `Try`/`Catch`. A storage method written that way has its catch block — and
  therefore `Error.Render`, the structured logger, and AD-15's audit emission — executing *still
  escalated*, because the catch is inside the frame that added the role. AD-9's verification
  ("restores the prior role set on unwind") is about a throw that unwinds *past* the frame, which
  is the arrangement the code will not have.
- **Anything the storage call reaches.** A `%Save()` on a proposal or ledger row fires index
  maintenance, `%OnBeforeSave`/`%OnAfterSave`, triggers and `SqlComputed` expressions — all inside
  the frame. A property whose `LogicalToDisplay` is overridden runs escalated. A callback passed
  into a storage method runs escalated.

**Precondition.** Ordinary ObjectScript style, followed correctly. No attacker step required to
create the condition.

**Impact.** The elevated role reaches error-path code that handles untrusted content (SEC-14),
reaches file and audit I/O, and reaches any code a future contributor adds to a storage method.
The boundary AD-9 draws is a naming convention, not a boundary.

**AD to tighten — AD-9, and a new AD-27 to make AD-8 enforceable.**

- **Binds (AD-9):** every method that calls `AddRoles`.
- **Prevents:** third-party, error-path or generated code executing inside the escalated frame.
- **Rule (AD-9):** The escalated region is a leaf: it contains the `AddRoles` call and exactly one
  global or SQL operation, no `Try`/`Catch` of its own (errors propagate out of the frame, which
  is what restores the role), no method call, no callback, no `Xecute`, no `%Save()` on a class
  carrying triggers or computed properties. Logging, audit and error rendering happen in the
  caller, unescalated.
- **New AD-27 — the role baseline is captured and asserted.**
  **Binds:** AD-8, AD-9; every tool, port and provider entry point.
  **Prevents:** AD-8's central claim being unverifiable at the moment it matters.
  **Rule:** The REST dispatch captures the request process's `$ROLES` as a request-scoped
  baseline. Every tool, AdminPort, ProviderPort and LogFilePort entry point asserts `$ROLES`
  equals that baseline and refuses otherwise. This is the enforcement AD-8 asserts and does not
  currently provide, and it catches SEC-02 and SEC-10 at runtime rather than at review time.
  Note that `$ROLES` cannot be used to *reduce* privilege — assigning it sets only the added
  portion and never drops a login role (verified) — so the assertion must be equality against the
  baseline, not a subset test.

---

## SEC-11 — Two confirms racing both write · **HIGH**

**Attack.** AD-6 calls the token single-use and says confirm "burns" it, but does not say when
relative to the write, nor that the burn is atomic. The natural sequence — validate, re-read,
compare fingerprint, write, burn — lets two simultaneous confirms both pass validation and both
write. Under AD-4's get-merge-put semantics, two interleaved merges over the same base produce a
lost update, which is exactly the class of failure the fingerprint check exists to catch.

**Precondition.** A double click; a client retry after a 502 or a gateway timeout (the design
already treats the 60 s stock gateway timeout as marginal, FR-23/AD-17); or two tabs.

**Impact.** Duplicate creates, lost updates on security objects, and a ledger that records one
confirmation for two writes — breaking SM-5's one-to-one claim.

**AD to tighten — AD-6.**

- **Binds:** FR-17's single-use requirement; SM-5.
- **Prevents:** a confirmation executing more than once.
- **Rule:** The burn is a conditional atomic state transition performed **before** the write — an
  `UPDATE ... WHERE State = 'pending'` checked for row count, or an extent lock — so exactly one
  confirm proceeds and the loser gets "already confirmed". The proposal carries a terminal state
  recording the outcome, so a confirm that crashes after the transition leaves the proposal
  burned rather than replayable. A test fires two concurrent confirms and asserts one write.

---

## SEC-12 — The provider API key can reach `^ERRORS`, which OcuPilot itself exposes as a screen and a read tool · **HIGH**

**Attack.** FR-26 resolves the provider key at call time from an environment variable or an IRIS
credential; it lives in the turn job's process memory for the call. IRIS's application error log
records **local variables at the point of an unhandled error**. OcuPilot ships a viewer for that
log (FR-63) *and a read tool over it*. A provider call that errors with the key in scope writes
the key into `^ERRORS` in the install namespace — which is outside AD-9's protected database, so
FR-29's protection does not cover it. The agent can then read it back through its own read tool
and, in the next provider request, send it out.

Secondary paths in the same family: the turn job is a long-lived background process whose
variables a `%Development` holder can inspect; AD-7's progress global (SEC-09) is world-readable;
NFR-5's "redacted from every log line" covers lines OcuPilot writes, and `^ERRORS` is not one.

**Precondition.** Any unhandled error inside the provider adapter with the key in a local
variable — a timeout, a TLS failure, a malformed response — plus the log-viewer privilege, or the
agent reading its own error log.

**Impact.** Provider credential disclosure with a self-service read path, breaching NFR-5 and
FR-26's "never returned by any OcuPilot API call".

**AD to add — a ProviderPort and LogFilePort clause.**

- **Binds:** NFR-5, FR-26, FR-63; ProviderPort; the application-error-log viewer and read tool.
- **Prevents:** a secret held in process memory being persisted by the platform's own error
  capture and then read back through OcuPilot.
- **Rule:** The credential is resolved immediately before the HTTP send, held in a variable
  `Kill`ed in the same method, and never in scope across a `Do`. The provider adapter's outermost
  frame traps every error so no frame containing the credential can reach `^ERRORS`. Independently,
  the application-error-log read tool and viewer pass every returned value through the shared
  secret matcher before it leaves the port — the log is untrusted output as well as untrusted
  input. A test forces an error inside the provider call and asserts the key appears nowhere in
  `^ERRORS`.

---

## SEC-13 — Same-origin XSS anywhere on the instance mints a token pair; CSRF is otherwise sound · **MEDIUM–HIGH**

**Attack.** The direct CSRF story holds and should be recorded as holding: with `UseSession=0`,
`JWTAuthEnabled=1` and Bearer-only authorization, a cross-site form POST cannot set an
`Authorization` header, and `CSPBrowserId` is `SameSite=Strict`, so `CSRFToken=0` on the API is
defensible.

The residual is the **minting** path. Per addendum §2, an empty-body `POST <jwt-app-root>/login`
carrying only the cookie returns a fresh token pair. That is a cookie-authorized, side-effecting
POST with no CSRF token. `SameSite=Strict` blocks cross-*site* sends — but not a **same-origin**
attacker. On an IRIS instance the origin includes every CSP application anyone can publish: the
classic portal's own pages (which render attacker-controlled entity names — NFR-6's exact threat
actor), and in this repository's sandbox the sibling MCP suite's web applications. It also does
not block the `postMessage` path the addendum flags as having **no origin check** (deferred to
Stage 4, same-origin by construction).

Because `/api/ocupilot` joins `%ISCMgtPortal`, one minted pair authorizes `/api/ocupilot`,
`/api/admin`, `/api/interop-editors` and `/api/security-config` alike. Per-tab `sessionStorage`
(NFR-3) does not mitigate this: the attacker mints fresh rather than stealing.

**Precondition.** Script execution anywhere on the instance origin, by any means, while the victim
holds a browser login.

**Impact.** Full impersonation across every JWT-enabled management API on the instance.

**AD to add — AD-28, recording the boundary rather than pretending it away.**

- **Binds:** NFR-3, FR-1, FR-2; the recommended web application settings; addendum §2's Design B.
- **Prevents:** treating same-origin script execution as out of scope when the auth design makes
  it equivalent to full compromise.
- **Rule:** The shell ships a strict Content-Security-Policy with no `unsafe-inline` and a
  per-response nonce, `connect-src` limited to the instance origin (which FR-13 already needs),
  `frame-ancestors 'none'` and `object-src 'none'`. OcuPilot never interpolates instance-supplied
  strings into HTML anywhere, including error pages and the static handler's fallback. Sign-out
  revokes server-side rather than only clearing tab storage. The spine records explicitly that
  `GroupById` membership trades blast radius for the silent-first login, and that Design B
  (JWT-only, outside the group) is the hardened configuration an operator can choose — the PRD
  already keeps it as the fallback, so name it as the security posture option it is.

---

## SEC-14 — A tool can call Confirm in-process; AD-1 dissolved the barrier that used to prevent it · **MEDIUM**

**Attack.** FR-17 requires that "no tool and no request issued from within a turn can confirm a
proposal". Under the pre-AD-1 design that was enforced by the agent having no token. AD-1 makes
tools run in-process with the user's roles and forbids only *HTTP* — so a tool calling the
confirm **class method** directly is not forbidden by anything in the spine, and is now the more
natural implementation shape. AD-6 does not restate the prohibition at all.

**Precondition.** One tool, or one shared helper reachable from a tool, calling the confirm entry
point. Injection then confirms its own proposals.

**Impact.** Complete removal of the human from the write path — the single invariant the entire
safety model rests on.

**AD to tighten — AD-6.**

- **Binds:** FR-17; AD-1's in-process execution; the turn job.
- **Prevents:** AD-1's removal of the HTTP hop also removing the barrier between proposing and
  confirming.
- **Rule:** Confirm is reachable only from the REST dispatch path. The turn job sets a
  process-private "inside a turn" marker at spawn; the confirm entry point refuses whenever that
  marker is present, and refuses whenever it is not executing under the confirm route's dispatch.
  A test calls Confirm directly from a tool body and asserts refusal. This restores by construction
  the property AD-1 removed by accident.

---

## SEC-15 — The fingerprint's scope is unstated, and the interesting changes are outside any plausible scope · **MEDIUM**

**Attack.** AD-6 fingerprints "the target". AD-4 sends only changed fields and displays unchanged
ones from the fresh read. If the fingerprint covers the whole entity, benign concurrent edits
cause false refusals and the pressure is to narrow it; once narrowed to the diff's fields, changes
to *related* entities are invisible entirely.

Concretely: `permissions.role.update` adds a resource to a role. Between mint and confirm someone
else grants that role `%All`. If the fingerprint covers only the fields in the diff, it still
matches, and the confirmed write proceeds against a role that now means something entirely
different from what the user reviewed. The same holds for a web application's matching roles, an
SSL configuration's referenced credential, and an OAuth client's server.

**Precondition.** A concurrent change inside the ten-minute window, by another administrator or by
another turn.

**Impact.** The user confirms a diff whose meaning changed underneath it. AD-6's Prevents clause
("a write against state that moved under the diff") is only partially delivered.

**AD to tighten — AD-6.**

- **Binds:** AD-4's changed-fields-only writes; FR-17's re-read.
- **Prevents:** a fingerprint narrow enough to be practical and therefore too narrow to be
  meaningful.
- **Rule:** The fingerprint covers the full serialization of the target as the endpoint's GET
  returns it, plus the identity and version of every entity the diff *names* (the role's resource
  list, the application's matching roles, the referenced credential). Refusal with "target
  changed, re-propose" is the safe default and is cheap; a false refusal costs one round trip and
  a true one prevents an unreviewed change.

---

## SEC-16 — No concurrency bound on turns, and the one that exists is a client affordance in a stretch step · **MEDIUM**

**Attack.** FR-12's lock is *per conversation*, and a new tab starts a new conversation — so it
bounds nothing per user. FR-19's per-user concurrent-turn limit is explicitly build step 7,
i.e. may not ship for Release 1. AD-7 mentions no limit at all. N tabs produce N jobs, each
holding provider credentials in memory (SEC-12), each writing to the progress global, each running
the escalated between-steps state read (SEC-02, SEC-10).

**Precondition.** An authenticated user with the `%Admin_*` floor and a loop.

**Impact.** Provider cost DoS (§7.3 makes cost the operator's problem, which is fine, but not
unbounded), and — on a Community container with a small process table — job exhaustion that takes
down **the instance**, not just OcuPilot. The management portal replacement becoming the thing
that wedges the instance it manages is the worst available failure mode.

**AD to tighten — AD-7.**

- **Binds:** FR-12, FR-19, §7.3; `POST /turn`.
- **Prevents:** unbounded job creation by an authenticated user.
- **Rule:** A per-user and an instance-wide concurrent-turn cap are enforced at `POST /turn`
  before the job is started, as server-side constants in Release 1 — like AD-6's ten minutes — so
  the bound does not depend on step 7 landing. A turn whose progress has not advanced within a
  timeout is reaped and marked failed, so orphans do not consume the cap.

---

## SEC-17 — The prohibited set is enumerated over request fields, and its predicates race · **MEDIUM**

**Attack.** AD-10's set is expressed as actions ("deleting or disabling the current user, the last
`%All` holder or `_SYSTEM`; disabling the web application serving OcuPilot"). Two problems:

- **The predicates are queries and they race.** Two concurrent confirms each deleting a *different*
  `%All` holder both pass "is this the last one?" and leave zero. Same for the last enabled
  administrator.
- **They are expressed over field names, not effects.** "Disabling the web application serving
  OcuPilot" is achievable without touching `Enabled` — rename it, change its path, change its
  namespace, remove its dispatch class, or lock its resource. FR-30's web-application editor lets a
  human do all of that, and FR-17's last bullet says the screen path and the tool path are two
  callers of one operation, which is what makes AD-10's "refused by the write path" load-bearing.

Also worth noting: a **turn job is not an IRIS system process**, so the prohibition on terminating
system processes does not protect it. A user, or an injected agent proposing a process terminate
the user confirms, can kill another user's turn job — leaving that user's proposals live for the
rest of the window (SEC-18) and their panel spinning.

**Precondition.** Two concurrent writes, or one write expressed in a field the enumeration does
not name.

**Impact.** An instance with no `%All` holder — unrecoverable without a restart in single-user
mode — or an OcuPilot that has locked itself out of the instance it manages.

**AD to tighten — AD-10.**

- **Binds:** §7.1's Level 4; FR-18's prohibited set; FR-56's process control.
- **Prevents:** a prohibition that a rename, a race or a second field defeats.
- **Rule:** Prohibited predicates are evaluated over the **post-write state** — simulate the merge,
  then assert — inside the same transaction as the write and under a lock on the affected extent,
  never over the request's field names. "Disabling the web application serving OcuPilot" includes
  renaming it, changing its path or namespace, removing its dispatch class, and changing its
  resource. OcuPilot turn jobs are added to the set of processes that may not be terminated.

---

## SEC-18 — Orphaned proposals stay confirmable after their turn dies · **MEDIUM**

**Attack.** Proposals live ten minutes and are invalidated by confirm, cancel, a new turn in the
conversation, or expiry. If the minting job dies — gateway timeout, process kill (SEC-17), a
provider error that aborts the loop — its proposals remain confirmable until the user sends
another message or the clock runs out.

**Precondition.** An abnormal turn end, which FR-12 already anticipates ("a turn that exceeds the
provider timeout ends with an error card").

**Impact.** A user confirms a proposal from a turn that failed, without the surrounding
explanation that made it make sense. Narrow, but it is confirmation without context, which is the
condition every other invariant is trying to avoid.

**AD to tighten — AD-6 and AD-7.**

- **Binds:** FR-12, FR-17's cancellation triggers.
- **Prevents:** a proposal outliving the reasoning that produced it.
- **Rule:** A proposal is invalidated when its minting turn ends abnormally, in addition to the
  FR-17 triggers. The turn's terminal state is written by the reaper (SEC-16) when the job cannot
  write it itself.

---

## SEC-19 — The ledger is an agent-writable store with no rate bound, and the recorded resource is gameable · **MEDIUM**

**Attack.** Every tool call writes a ledger row into the protected database (FR-21). AD-11's "no
write occurs without a confirmation" is about IRIS configuration; OcuPilot's own state is written
freely by the agent loop. An injected model calling read tools in a loop to max-iterations floods
the ledger, the transcript store and, where reads are audited, the audit database.

Sharper: FR-72 gates an administrator's view of another user's transcript on holding "every
resource the transcript's tool calls required, as recorded per ledger row". If the recorded
resource comes from the call's outcome rather than the descriptor — or if a call that fails the
gate records nothing — then the model, steered by injected content, controls the recorded resource
set and therefore controls which administrators can later read that transcript.

**Precondition.** Any injection source; the loop is free.

**Impact.** Storage growth in the protected database (which has no separate quota story), and a
transcript-access control whose input the attacker influences.

**AD to tighten — AD-21, or a new ledger clause.**

- **Binds:** FR-21, FR-72; the agent loop's iteration bound.
- **Prevents:** the ledger being both the audit record and an attacker-influenced input to an
  access decision.
- **Rule:** The ledger's resource field is written from the screen descriptor, never from the
  call's outcome, and is recorded for calls that fail the privilege gate as well as those that
  pass. Ledger rows per turn are bounded by the same max-iterations constant that bounds the loop,
  and a turn that reaches it terminates rather than truncating its record.

---

## SEC-20 — AD-24 caps rows, not content, and delimiting is the only thing left · **MEDIUM**

**Attack.** AD-24 is a good addition, but it bounds row *count* and excludes secret-typed fields.
It says nothing about per-field length or shape. A single web application `Description`, task
description or user `Comment` is a long free-text field an ordinary user writes, and it enters the
context payload whole. AD-11 says untrusted text enters "only as delimited tool-result content" —
delimiting is a prompt-format defense, and AD-11's own first sentence says prompt format is not
the defense. A 4 KB hostile comment field has plenty of room to work with.

**Precondition.** Write access to any free-text field on any entity the six areas display.

**Impact.** The largest available injection payload, delivered through the channel the design
considers safe.

**AD to tighten — AD-24.**

- **Binds:** FR-11, NFR-6; every context serializer.
- **Prevents:** an unbounded single field being the injection surface that the row cap was
  supposed to close.
- **Rule:** In addition to the row cap, a per-field character cap, applied by the kernel, not by
  the serializer. The serializer emits structured JSON values, never a concatenated text blob, so
  there is no delimiter for content to escape and no ambiguity about where a field ends.

---

## SEC-21 — The ledger row and audit marker are finalized after the secret merge · **MEDIUM**

**Attack.** FR-22 has the ledger row "created before the admin API call and finalized after it".
At finalization the executing frame holds the **merged** argument set, including the secret the
client supplied at confirm. Nothing says redaction is re-applied to the merged set rather than to
the stored one — and the stored one, by AD-6, never contained the secret, so a redactor written
against it is a no-op that looks correct in testing.

**Precondition.** Any confirmed write on a secret-bearing tool.

**Impact.** Secrets in the protected ledger and possibly in the audit marker's event data,
breaching NFR-5 at the one site the design most relies on being clean, since FR-72 lets
administrators read ledger rows.

**AD to tighten — AD-6 and AD-15.**

- **Binds:** NFR-5, FR-21, FR-22.
- **Prevents:** the merge that AD-6 permits leaking into the record AD-15 writes.
- **Rule:** The ledger row and the audit marker are written from the **stored** arguments plus the
  *names* of merged secret fields — never from the merged set. The merged set does not escape the
  executing frame. A test performs a secret-bearing write and asserts the ledger row and the audit
  event data contain no field the schema marks secret and no substring of the supplied value.

---

## SEC-22 — Vendor error text reaches the model, the panel and the ledger unnormalized · **MEDIUM**

**Attack.** AD-12 renders internal failures generically and logs detail — correct for OcuPilot's
own errors. It does not cover **tool results**. AD-2's sequence surfaces
`ValidateRequest`/`ValidateSemantics` failures from vendor endpoint classes, whose text embeds
submitted values and underlying property and class names. That text becomes tool-result content
(intended), the panel's error card (unsanitized, per SEC-09), and a ledger row.

Adjacent, from this project's own conventions: a `%String` set to `''` by a SQL `UPDATE` reads
back as `$Char(0)`, a non-empty one-character string that renders invisibly. If it reaches a diff,
a field changing `""` → `$Char(0)` or back looks unchanged in the "N unchanged fields" collapse
while the write does change it.

**Precondition.** Any validation failure, which is the common case against forty unverified write
contracts.

**Impact.** Internal class and property names disclosed to the provider and to the user; and a
diff that under-reports a change.

**AD to tighten — AD-12.**

- **Binds:** AD-2's vendor dispatch; the diff computation; the panel's error card.
- **Prevents:** vendor error text bypassing both the sanitizer and the normalizer.
- **Rule:** Vendor error text is passed to the model verbatim (it is the model's diagnostic) but
  reaches the user only through the sanitizer, and both paths normalize `$Char(0)` to `""` first.
  The diff computation normalizes both sides before comparison so an empty-to-sentinel transition
  is displayed as the change it is.

---

## SEC-23 — The provider endpoint is a stored SSRF primitive, and the context egress follows it · **MEDIUM**

**Attack.** FR-27 refuses link-local metadata addresses but deliberately allows private-network and
loopback hosts, because local models are a supported case. That is an SSRF primitive by design,
available to an OcuPilot administrator — acceptable in itself. What is not stated is that the
*stored* endpoint is where every subsequent turn posts every user's screen context and transcript.
DNS rebinding between the Test-connection validation and the runtime call, or a redirect the
adapter follows, moves that destination without a further administrator action.

**Precondition.** The OcuPilot administrative resource, or a compromise of an account holding it.

**Impact.** Every screen context and transcript on the instance to an arbitrary reachable host,
with the context chip still saying what it said when the endpoint was approved.

**AD to add — a ProviderPort clause.**

- **Binds:** FR-24, FR-25, FR-27, §7.2's egress promise; the context chip.
- **Prevents:** the approved destination and the actual destination diverging.
- **Rule:** ProviderPort refuses redirects outright. The endpoint's host is re-validated at call
  time against the same rules Test connection applied, and the resolved address is checked at
  connect time, not only at save. Plain HTTP requires the acknowledgment FR-25 already describes
  *and* is surfaced on the context chip on every turn, not only at configuration. Every change to
  a definition's endpoint is audited with old and new values (FR-24 already requires this — bind
  it here so it is enforced at the port, not only at the form).

---

## SEC-24 — Governance is evaluated at the tool call, not at the write · **LOW–MEDIUM**

**Attack.** AD-22 gates the tool call and returns a structured `GOVERNANCE_DISABLED` result. The
write happens at confirm, minutes later, in a different request. Nothing says the governance key
is re-checked there, so a tool disabled during the window still writes. Same family as SEC-05;
listed separately because AD-22's own "fails safe" claim is what it undermines.

**Precondition.** A policy change inside the ten-minute window.

**Impact.** A governance denial that does not take effect.

**AD to tighten — AD-22 (Rule) and AD-6 (confirm preconditions, SEC-05).**

- **Rule:** The governance cascade is evaluated at the tool call *and* at confirm, against the
  key the proposal recorded. A key disabled between the two refuses the confirm with the same
  structured result.

---

## SEC-25 — AD-1's adoption makes the raised access-token lifetime unnecessary; say so before it ships · **LOW**

**Attack.** Not an attack — a hardening opportunity the spine should capture before the addendum's
"or raise access to 300" is implemented from a stale rationale. AD-1 removes the HTTP hop, so the
server needs no token during a turn, and the 60 s-versus-90 s mismatch that motivated raising the
access lifetime no longer exists. A 300 s access token is five times the exposure window for a
token sitting in `sessionStorage` on an origin where same-origin script is the realistic threat
(SEC-13), bought for nothing.

**AD to tighten — AD-1.**

- **Binds:** NFR-3; addendum §2's recommended token timeouts.
- **Prevents:** a token lifetime raised to work around a design that was then replaced.
- **Rule:** Because tools run in-process, the access-token lifetime stays at the vendor's 60 s and
  the refresh at 900 s. The recommended-settings table's "or raise access to 300" is withdrawn,
  and the reason is recorded so it is not reintroduced.

---

## SEC-26 — "Audit emission never fails a write" versus SM-5's zero-tolerance claim · **LOW**

**Attack.** AD-15 makes marker failure non-fatal (right — an audit outage should not block
administration) and surfaces it as "done · audit not marked". SM-5 asserts zero confirmed
proposals without a matching marked event over the whole voting week. A transient failure makes
those two statements incompatible, and the design has no way to measure which one is true.

**AD to tighten — AD-15.**

- **Binds:** FR-22, NFR-7, SM-5.
- **Prevents:** an unmarked privileged write being invisible in the metric that claims none exist.
- **Rule:** An unmarked write is recorded in the protected ledger with a distinguishing state and
  a retry attempt; the panel and the agent audit viewer show a running count of unmarked writes, so
  SM-5 is a measurement rather than an aspiration.

---

## What held up

Recording what survived the attack, so later revisions do not trade it away:

- **AD-1's in-process execution** genuinely removes a class of problems — no mid-turn token
  refresh, no second authenticated hop, no token lifetime to reconcile. Its one side effect is
  SEC-14, which is cheap to close.
- **Bearer-only authorization with `SameSite=Strict` and `UseSession=0`** makes classic CSRF
  ineffective against the API. `CSRFToken=0` is defensible here; the residual is same-origin
  (SEC-13), not cross-site.
- **AD-6's core shape** — server-minted, server-stored arguments, server-computed diff, fresh
  re-read, single use, expiry — is the right shape. Every finding against it is a gap in the
  enumeration, not a flaw in the idea.
- **AD-10's "absent, not gated"** is the correct treatment of prohibited actions, and putting the
  refusal in the write path shared with the screens (FR-17) is what makes it real rather than
  advisory. SEC-17 is about how the predicates are written, not about the decision.
- **AD-9's use of `New $ROLES`** is the right primitive: verified that a throw unwinding past the
  frame restores the prior role set. The findings are about what the frame does not bound — a
  spawned process (SEC-02) and its own callees and catch block (SEC-10).
- **AD-24's addition of a context cap** closes the unbounded-egress hole; SEC-20 only asks it to
  cap content as well as rows.
- **AD-12's single error envelope and generic internal reason** is exactly right and should not be
  relaxed to help debugging.

## Suggested order of work

The three CRITICAL findings (SEC-01, SEC-02, SEC-03) are cheap to fix in the spine now and
expensive to retrofit after forty write tools exist. SEC-27's role baseline (folded into SEC-10)
is the single highest-leverage addition, because it converts AD-8 from an assertion into something
a test can fail on. SEC-04 and SEC-05 should land with the proposal store in build step 2, not in
step 7 — several of the guarantees they restore are currently scheduled into the stretch step that
the build order itself describes as the cut line.
