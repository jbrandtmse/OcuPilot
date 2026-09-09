---
title: 'Rubric review — ARCHITECTURE-SPINE.md (OcuPilot)'
target: '../ARCHITECTURE-SPINE.md'
reviewer: rubric lens (good-spine checklist)
created: '2026-09-08'
altitude: initiative
verdict: 'Structurally strong, factually unsafe in two ADOPTED decisions; 4 critical, 14 high findings'
---

# Rubric review — OcuPilot Architecture Spine

Reviewed against the good-spine checklist. The units one level down are taken to be the six
portal areas (5.5–5.10) plus the shell (5.1), the agent (5.2–5.4) and packaging (5.11).
Everything under *Stack*, *Structural Seed* and *Core entities* is read as seed and is not
judged as invariant except where a seed statement is load-bearing for a rule.

Instance probes in this review were run against the `ocupilot-iris` container
(IRIS for Health 2026.2 build 221U, instance GUID `92989EE2-AB37-11F1-AE6A-769196E3B75A`).
Probe SQL and method bodies are in the Evidence appendix; the scratch probe class was deleted
after use.

## Verdict

The spine picks its invariants well. AD-5 (one screen descriptor), AD-6 (server-minted
proposal), AD-7 (turn job / confirm split), AD-13 (id encoding), AD-14 (change events),
AD-19 (signal stores) and AD-20 (absolute API URLs) are exactly the right nine-unit
divergence points, are stated at the right altitude, and a reviewer could mechanically check
compliance with each. The Deferred table is honest and mostly correct.

Two problems dominate. First, the two ADs that carry the most weight — **AD-2**, which backs
every read and write in five of six areas, and **AD-4**, which governs every write payload —
rest on generalizations from a single probed endpoint that **do not hold across the endpoint
family**, and both fail in ways that are silent at runtime. Second, a whole class of
cross-unit contracts is absent: **session/token handling**, **the list-read and
model-input budget**, **switch evaluation points**, **namespace scope**, and **the
monitoring/management API surface** — five contracts that all nine units need on day one and
that nothing in the document fixes.

The operational envelope is the weakest dimension: environments and the dev loop, build/CI,
data retention, backup, and data migration are silent rather than deferred.

---

## 1. Does it fix the real divergence points, and does it miss any?

**What it gets right.** The nine units' shared surfaces are largely identified: the screen
contract (AD-5) is the correct keystone and matches the UX's own "Adding a screen (the screen
contract)" ten-item list almost field for field; the write lifecycle (AD-6, AD-7, AD-15) is
fixed end to end; the error envelope (AD-12), id encoding (AD-13) and change bus (AD-14) are
the three things six areas would otherwise each invent. Dependency direction is stated and is
checkable.

Six contracts that every unit needs and that the spine does not fix follow. Each is
constructed concretely enough to drop into the document.

### F1.1 — No session, token or 401 contract  ·  **CRITICAL**

FR-1, FR-2 and NFR-3 specify a token pair held per browser tab, carried as a Bearer header,
refreshed before expiry and once on any 401, with a failed refresh returning to the form
login with the route preserved. The addendum §2 adds the hard numbers: **access token 60 s,
refresh 900 s, ES256**, and `CSPBrowserId` as the silent-login carrier.

AD-20 names "one API service" but constrains only the *URL*. Nothing says who attaches the
Bearer, where the token lives, that a slice must never handle a 401 itself, or that
concurrent 401s must collapse into one refresh. With a 60-second access token and a turn that
runs to 90 s, the panel's progress polling (AD-7) crosses at least one token expiry on nearly
every turn — so this is not a theoretical concern, it is the common path. Six areas plus the
shell plus the panel will each meet the same 401 and answer it differently; the first
divergence produces a double-refresh race that logs the user out mid-turn.

AD-1 resolves the *server-side* half of Open Question 17 and says so well. The *browser* half
is unanswered.

> **Construct — AD-24: one session service owns the token pair; nothing else touches it.**
> The token pair lives in `sessionStorage` (per tab, per NFR-3), is written and read by
> exactly one `core/auth` service, and is attached by exactly one HTTP interceptor. A 401 is
> handled only there: a single-flight refresh serialises concurrent 401s into one
> `POST /api/ocupilot/refresh`, replays the queued calls once, and on failure clears storage
> and routes to the form login with the intended route preserved. No slice, store or screen
> reads the token, retries a 401, or calls `logout`. Silent login runs once at bootstrap
> before any screen resolves. *Mechanical check:* `Authorization`, `sessionStorage`,
> `localStorage` and `document.cookie` appear nowhere outside `ui/src/app/core/auth/`.

### F1.2 — No read/list contract, and no budget on what reaches the model  ·  **HIGH**

Three separate consumers need one answer here and get none:

- **Screens.** NFR-1 promises a first page within two seconds against a thousand rows.
  Nothing fixes page size, whether paging is offset or cursor, whether a total count is
  returned, or whether long lists virtualise. The UX requires `role="grid"` with virtual
  scroll and `aria-activedescendant`; six areas can satisfy the state matrix while making
  opposite paging choices, and the read tools generated from those screens (AD-5) inherit the
  divergence.
- **Screen context.** EXPERIENCE.md carries an explicit, unanswered
  `[NOTE FOR ARCHITECTURE]`: *"cap the rows that travel with a turn (a viewport holds about
  16; 50 is a safe ceiling) and show the count on the read tool-call card — a 1,000-row fetch
  must never be sent to the provider."* The spine's index of UX notes is otherwise well
  answered (the id encoding, partial writes, the auditing install step, the expiry constant
  all landed as ADs); this one did not.
- **Tool results.** AD-11 says untrusted text enters "as delimited tool-result content" but
  places no bound on it. FR-72's truncation is polish-week, so Release 1 has no cap at all,
  and the harvested agent loop has **no context trimming whatsoever** (recorded in the run's
  own decision log as a gap OcuPilot must fill).

> **Construct — AD-25: one list contract, one model-input budget.** Every list read returns
> `{rows, nextCursor, truncated, totalIsEstimate}` with a server-enforced default and maximum
> page size declared once; a screen never requests more than its max-rows setting. Screen
> context carries at most N viewport rows (N fixed here, ≤ 50) and the count is shown on the
> read tool-call card. Every tool result is truncated to a fixed byte budget before it reaches
> the provider, and the truncation is visible in the card. Conversation history is trimmed to
> a fixed token budget by one function in `Kernel/Agent/`; no adapter trims. *Mechanical
> check:* one constant class holds the four numbers; grep finds no other literal row or byte
> cap.

### F1.3 — No AD fixes where the switches are evaluated  ·  **HIGH**

FR-19 and FR-20 are unusually precise: enforced read-only, the per-user toggle, a definition's
read-only flag, the kill switch and the per-user turn limits are *"evaluated on the instance
before every provider call, before every tool call and at confirmation"*, and *"an in-flight
turn stops at its next step when the state changes"*. FR-20 adds that a pending proposal can
no longer be confirmed once the kill switch engages.

AD-22 governs the polish-week *governance policy* cascade. Nothing governs the Release 1
switches. AD-6 lists what invalidates a proposal (user, fingerprint, expiry, single use) and
omits read-only and kill-switch state, which FR-17 explicitly requires. The predictable
outcome: the panel checks client-side, the turn job checks once at start, and the confirm path
forgets — three units, three answers, and the security property FR-20 is buying evaporates.

> **Construct — AD-26: one gate, four call sites.** A single `Kernel/Governance:Gate(context)`
> returns a structured allow/deny with a reason slug, and is called at exactly four points:
> turn start, before each provider call, before each tool call, and at proposal confirm. It
> evaluates, in order: kill switch (global then per-user), enforced read-only, per-user
> read-only, the definition's read-only flag, per-user turn limits, then (polish week) the
> governance policy. No other code reads a switch; the client's copy is display only.
> *Mechanical check:* the switch storage class is referenced only by the gate.

### F1.4 — Namespace scope is unfixed, and the descriptor cannot express it  ·  **HIGH**

FR-5 requires a namespace switch; routes carry `?ns=` (AD-13); the UX includes namespace in
screen context and re-fetches the current screen on switch. But the six areas are not
uniformly namespace-scoped: web applications, users, roles, resources, services, SSL
configurations, processes, locks and databases are instance-wide; tasks, application errors
and the interoperability surfaces are namespace-scoped. AD-5's ten descriptor fields do not
include a scope, AD-16 covers only `%SYS` save/restore, and AD-6's fingerprint identifies the
target entity without its namespace — so a proposal minted while the shell was in `HSCUSTOM`
can be confirmed after a namespace switch with no mismatch detected.

> **Construct — AD-27:** every descriptor declares `scope: instance | namespace`. A
> namespace-scoped read or write takes the route's `ns` and switches per AD-16; an
> instance-scoped one ignores `ns` and the header switch does not re-fetch it. A proposal's
> stored arguments always include the resolved namespace, and it is part of the target
> fingerprint. *Mechanical check:* no slice reads `$NAMESPACE` directly; every descriptor has
> the field.

### F1.5 — Two external surfaces have no port  ·  **HIGH**

The paradigm says *"The three things outside OcuPilot are reached through ports... Nothing else
crosses the boundary."* The container diagram on the same page shows
`Slices --> Monitor["/api/monitor"]` and the capability map assigns FR-33/FR-34 (REST API
explorer, OpenAPI document viewer) to `Area/WebApp/`, which needs `/api/mgmnt`. FR-56 (system
usage and dashboard meters) needs `/api/monitor`. Neither has a port, neither is named in the
`Port/` tree, and AD-1's HTTP prohibition lists `/api/admin`, `/api/mgmnt` and
`/api/ocupilot` — but not `/api/monitor`, leaving it ambiguous whether metrics may be fetched
over HTTP from inside a turn.

Two units (WebApp and OsMgmt) will each invent a way to reach a different vendor API, and one
of them may do it over an authenticated HTTP hop that AD-1 exists to prevent.

> **Construct — AD-28:** `MonitorPort` and `MgmntPort` join the three existing ports, each
> with one adapter and the same in-process rule as AD-2 (`%Api.Monitor` and `%Api.Mgmnt.v2`
> dispatch classes, invoked without an HTTP envelope), or an explicit, documented exception
> stating why one of them must be an HTTP call. Update the paradigm's "three things" sentence
> to match the diagram.

### F1.6 — Nothing fixes how OcuPilot makes an outbound HTTPS call  ·  **HIGH**

`%Net.HttpRequest` cannot make an HTTPS call on IRIS without a named SSL configuration. The
PRD's harvest map explicitly rejects the sibling's approach (*"its hard-coded `DefaultSSL` and
lack of proxy support"* — do not inherit) and lists *"proxy and custom-CA support"* as new work
for OcuPilot. AD-17's installer roster creates web applications, a resource, a role and audit
events; it does not create or name an SSL configuration. ProviderPort is named in the tree and
in no AD. FR-27 additionally requires that link-local metadata endpoints be refused while
loopback and private-network hosts stay allowed.

Without this, the agent unit and the packaging unit each assume the other owns it, and the
first `docker compose up` on a clean clone produces a Test-connection failure with a TLS error
— on the judge's path (UJ-2, UJ-5).

> **Construct — AD-x:** ProviderPort resolves its SSL configuration by a fixed name the
> installer creates (guard-then-act, per AD-17), supports an optional proxy and an optional
> extra CA from the definition, refuses the link-local metadata range, and permits loopback and
> private ranges. Plain HTTP is permitted only under FR-25's stored acknowledgment.

### F1.7 — The descriptor derives routing and tools, but not the screen  ·  **MEDIUM**

AD-5 derives route, nav, gate, read tool, write tools, context capture and change routing from
the descriptor, and closes with *"Sixty screens stay consistent because there is only one place
to be consistent in."* But the rendered screen is not derived from anything. The UX defines
thirteen archetypes and a surface × state matrix (cold-load, empty, error, permission-denied,
refreshing, selected, changed) that each archetype must satisfy. Nothing in the spine says
those archetypes are implemented once and configured per screen rather than written per area.
Six areas building `list` independently is the single largest consistency risk left in the
document, and it is invisible to AD-5's checks.

> **Construct — AD-29:** each UX archetype has exactly one implementation under
> `ui/src/app/shell/archetypes/`; an area slice supplies a descriptor and column/field
> definitions and never a bespoke table, form or state machine. Every state in the surface ×
> state matrix is implemented once, in the archetype. *Mechanical check:* no `<table>`,
> skeleton or empty-state markup outside `shell/archetypes/`.

### F1.8 — The web-application settings that the whole silent-login design rests on are unstated  ·  **MEDIUM**

FR-65 is specific: the API application is password-authenticated with JWT enabled,
`UseSession=0`, member of the vendor's portal group, **carrying no application roles and no
matching roles, which the installer asserts**; the static application is unauthenticated with
a non-root base href and a deep-link fallback. The addendum §2 gives the full settings table.
AD-17 covers install mechanics and idempotence; no AD carries these settings, and the
"installer asserts this" requirement — a security property, since an application role would
silently elevate every caller and break AD-8 — appears nowhere.

> **Construct:** fold into AD-17 or add an AD: the two applications' settings are declared once
> in the installer as data, the assertion on application/matching roles runs on every install,
> and a test reads the created applications back and fails on any drift.

### F1.9 — Progress record shape and lifecycle  ·  **LOW**

AD-7 says the job "writes per-step progress to a temp global keyed by turn id" and the panel
polls. The record's shape, the poll interval, who deletes the global, and what a poll returns
for an unknown or finished turn are unstated — the panel and the agent are two different units
building the two ends of that channel. (See also F2.6: the storage choice has a privacy
consequence.)

---

## 2. Is every Rule enforceable, and does it prevent its stated divergence?

Most rules pass this test: AD-5, AD-6, AD-12, AD-13, AD-14, AD-16, AD-19, AD-20, AD-21 and
AD-23 all state something a reviewer could check by reading a diff. The exceptions follow, and
the first two are the most serious findings in this review.

### F2.1 — AD-2 is factually wrong and materially incomplete  ·  **CRITICAL**

AD-2 is marked `[ADOPTED]` and backs every screen read and every tool in areas 5.5–5.10.
Probed against the running instance, three of its load-bearing claims fail.

**(a) "All 70 endpoint classes are free of `%request` / `%response` references" is false.**
Eleven methods across eight endpoint classes reference `%request`, `%response` or `%session`
directly. At least one is on a Release 1 path:

```
%Api.Admin.Endpoints.Security.Audit.Record:RunList     <- FR-61, audit database viewer
%Api.Admin.Endpoints.Database.Actions:RunCompact / RunDefragment / RunIntegrityCheck
%Api.Admin.Endpoints.Journal.Record:RunList
%Api.Admin.Endpoints.AsyncResult:RunList / ValidateSemantics
%Api.Admin.Endpoints.Database.AsyncTaskSysBackground:Cancel / Pause / Resume
%Api.Admin.Endpoints.Security.Encryption.Settings:RunPut
```

`Security.Audit.Record:RunList` begins `Set task.TaskName = ..GetName(%request)`. In AD-7's
background turn job there is no `%request`, so the audit-database read tool raises
`<UNDEFINED>`. The AD's blanket assurance is worse than the defect, because it tells every
slice author they need not check.

**(b) The status channel is silently discarded.** AD-2 mandates `IsRunningAsync = 1`. The base
class's status setter is, in full:

```objectscript
Method SetRespStatus(status)
{
    If '..IsRunningAsync {
        Set %response.Status = status
    }
}
```

Under `IsRunningAsync = 1` it is a **no-op**. Endpoints signal 400, 404, 409, 415, 422 and 201
through `SetRespStatus` and then `Return {}` with `sc` still `$$$OK`. So, in-process:
`Security.User:RunPut` against a missing user returns success and an empty object;
`Wallet.Secret:RunPut` with a bad `Type` returns success and an empty object;
`Task.CRUD:RunPut` with a bad start date returns success. AD-12 cannot render an error that
never arrives, and AD-6's confirm path cannot distinguish "written" from "silently refused" —
which defeats FR-22's marker semantics and SM-5's ledger/audit reconciliation.

**(c) The recipe omits five things the vendor's own `Main()` does.** Reading
`%Api.Admin.Dispatch.v1:Main()` in full:

- `Set endpoint.ApiVersion = ..ApiVersion()` — omitted. Response shape branches on it
  (`Audit.Record:RunGet` adds `UTCTimeStamp` only when `ApiVersion > 1`). NFR-8 pins v2; the
  port must set it or reads silently return v1 shapes.
- `endpoint.ValidateQueryParams()` and `endpoint.NeedsRequestBody()` — omitted.
- `%Api.Admin.Util.General.BeginCaptureOutput/EndCaptureOutput` — omitted. Endpoints `Write`
  to the current device and the vendor captures that into the response's message array.
  In-process inside a REST handler, uncaptured device output lands **in the HTTP response
  body**, producing exactly the double-envelope AD-12 forbids — and not necessarily as `}{`,
  so AD-12's test would not catch it.
- The `ShouldRunAsync()` branch — omitted entirely (see F3.1).
- `Catch e { ... e.Name = "<PROTECT>" -> 403 }` — omitted. This is how a privilege failure
  inside a security API surfaces, and AD-8 requires that "a 403 from a tool is identical to a
  403 from a screen."

The AD's altitude is right — this is knowledge that belongs in the spine because AdminPort is
built once — but the rule as written will produce a port that loses errors. **It should state
the port's contract (inputs, result, error mapping, output capture, async handling) rather
than a method sequence**, and the sequence should be corrected.

### F2.2 — AD-4 generalises a PUT semantic that does not hold  ·  **CRITICAL**

AD-4's rule opens by asserting the API's behaviour: *"The admin API's PUT semantics are
get-merge-put (`MergeJsonAndProperties` over existing properties, then `Modify`), so a partial
body is honored."* The run's decision log shows this was verified on exactly one class,
`WebApp.App`. Probed across the family: **18 of 47 `RunPut` implementations call
`MergeJsonAndProperties`. 29 do not**, and at least three distinct idioms exist —
`MergeJsonAndProperties` (WebApp.App), `MergeJsonAndObj` (Task.CRUD), and per-endpoint
`%IsDefined` loops (Security.User). Two concrete failures on Release 1 paths:

- **`Wallet.Secret:RunPut` (FR-46, build step 5)** reads `requestBody.Type`, validates it
  against an allow-list, and returns **HTTP 400** if absent. A body carrying "exactly the
  fields the diff shows as changed, plus the identifying key" fails, because `Type` is
  required on every PUT and is not the key. Combined with F2.1(b), that 400 is invisible.
- **`Security.Audit.Event:RunPut` (FR-47) and `Wallet.Secret:RunPut` are upserts** — they
  `Create` when the target does not exist. So a partial body sent against a target that was
  deleted between propose and confirm does not fail; it **creates a new entity populated with
  only the changed fields**. That is precisely the class of accident AD-4 and AD-6's
  fingerprint exist to prevent, and the fingerprint re-read is itself deferred to build step 7.

The rule needs to stop asserting a property of the vendor and start mandating a check:

> **Rewrite:** each write descriptor declares its endpoint's update semantic — `merge`,
> `replace`, or `upsert` — verified against that endpoint's `RunPut` before the story is
> closed, and recorded in a generated table beside the generated schemas (AD-3). A `merge`
> endpoint receives changed fields plus the key; a `replace` endpoint receives the full body
> rebuilt from the fresh read plus the diff; an `upsert` endpoint is never called without a
> confirmed prior existence check. Required-on-every-PUT fields (e.g. `Wallet.Secret.Type`)
> are declared in the descriptor and always sent.

### F2.3 — AD-9 puts the code where the users cannot reach it  ·  **HIGH**

AD-9: *"OcuPilot's globals **and packages** live in a dedicated database guarded by a dedicated
resource that no ordinary role holds."* Per the Authorization Guide, the database **Read**
permission is what enables *"data access and routine execution"* — *"you must have the Read
privilege for a database to ... Execute a routine."* If no ordinary role holds the resource,
no ordinary user can execute OcuPilot's classes at all, so no user ever reaches
`$SYSTEM.Security.AddRoles()` to escalate. The privileged-routine-application mechanism itself
is well chosen and was proven on the instance; the *placement* is self-defeating.

The conventional shape works: **code stays in the install namespace's routine database
(ordinarily readable); the globals are mapped to the protected database**; the privileged
routine application grants the state role to the storage classes only. The FR-29 acceptance
test (a `%DB_HSCUSTOM:RW` + `%Admin_Operate` holder can read neither table nor global) still
passes, because it is the *globals* that are protected.

AD-9 is also silent on where the new database's `.DAT` lives. Given AD-17's own finding that
only the durable volume survives a restart, a database created under the image's `mgr`
directory would vanish on the first upgrade — the exact failure AD-17 exists to prevent.

### F2.4 — AD-8's one-resource model is incomplete on 2026.2  ·  **HIGH**

AD-8 makes every gate `$System.Security.Check(resource, permission)` against *"the resource the
screen descriptor names"* (AD-5 declares one privilege resource per screen). Since IRIS 2025.2,
**every security API — that is, every class that touches `IRISSECURITY`, which is what
`Security.Users`, `Security.Roles`, `Security.Resources`, `Security.Applications`,
`Security.SSLConfigs` and the OAuth2 classes all do — requires both `%DB_IRISSYS:R` and
`%Admin_Secure:U`**, with some OAuth2 operations additionally requiring `%Admin_OAuth2_*:U`.

The consequences reach three units. A user with `%Admin_Secure:U` but no `%DB_IRISSYS:R`
passes the endpoint's own `ResourcesOR()` gate and then takes a `<PROTECT>` inside the security
class — which, per F2.1(c), the port currently does not map to a 403. FR-4's "disabled with a
tooltip naming the required resource" will name one resource when two are needed, so the
Permissions and Security areas will show enabled entries that fail on click, and each will
work around it locally. The PRD's decision that *"the classic portal's finer gates, such as
`%DB_IRISSYS`, are not reproduced"* was made about the classic portal's *page* gates; it does
not survive the 2025.2 API change.

> **Amend AD-5 and AD-8:** the descriptor's privilege field is a *set* of `resource:permission`
> pairs, all of which are checked; the OAuth2 screens declare their `%Admin_OAuth2_*`
> requirement; the port maps `<PROTECT>` to the same 403 the screen shows.

### F2.5 — AD-11 is a posture, not a rule  ·  **HIGH**

AD-11 states the right intent and then gives a reviewer nothing to check. "Untrusted text
enters only as delimited tool-result content" fixes no delimiter, no escaping of the delimiter
inside the content, no size bound (F1.2) and no enumeration of which fields are untrusted.
"A rendered reply issues no request to any host but the configured provider" names no
mechanism — a Content-Security-Policy header on the static application is the mechanical
enforcement and appears nowhere in the document. NFR-6's seeded-injection test is deferred to
build step 7, so in the meantime nothing at all holds this line.

Compare AD-6, which is enforceable sentence by sentence. AD-11 should be rewritten to the same
standard: one `Untrusted(text, sourceKind)` wrapper that every tool result and every context
field passes through; a fixed delimiter with a stated escaping rule; a byte cap; a named CSP
header shipped by the static application; and the list of sources treated as untrusted
(entity names, comments, log lines, audit user names, task descriptions, tool results).

### F2.6 — Turn progress in a temp global is world-readable  ·  **MEDIUM**

AD-7 stores per-step progress — which includes tool results and, by FR-11, screen context — in
"a temp global keyed by turn id". `%DB_IRISTEMP` carries **Read and Write as public privileges
by default**. So any authenticated user on the instance can read any other user's in-flight
tool results by walking the global. That contradicts FR-29's protection of OcuPilot's state and
FR-72's rule that a user sees only their own transcripts and that an administrator sees another
user's tool results only when holding the resources those tools required. Either the progress
record goes in the protected database (AD-9), or it stays in IRISTEMP holding only opaque step
labels with the content fetched through the API.

### F2.7 — AD-3 does not say what "generated" looks like  ·  **MEDIUM**

"Derived at build time from the endpoint's `RequestBodySchema()`" names no artifact, no
location, no regeneration trigger and no way for a reviewer to distinguish a generated schema
from a hand-written one that claims to be generated — which is the review failure the AD is
trying to make catchable. Name the generated file(s), require a do-not-edit banner, and make
"regeneration produces no diff" a CI check. This matters more than usual because AD-3 is what
makes the PRD's sizing of CP-12/CP-13 (75 tools) credible.

### F2.8 — Two homes for the prohibited set  ·  **LOW**

AD-10 puts the Release 1 prohibited set in the write path; AD-5's descriptor carries "row
actions with self-protection rules"; the UX carries self-protection as a *gating* rule in the
Privilege Gating table. Three statements of the same list. Say which is authoritative (the
write path, per AD-10) and that the descriptor and UI derive their gating from it, so the list
cannot drift.

### F2.9 — AD-12's test is necessary, not sufficient; part of it is a coding standard  ·  **LOW**

"A test asserts no response body contains `}{`" will not catch captured device output
interleaved before the envelope (F2.1c), nor a second envelope separated by whitespace. Assert
instead that each response parses as exactly one JSON document and that the body is byte-equal
to the writer's output. The nested-`Catch` `Return $$$OK` prescription is a language rule and
belongs in the Consistency Conventions table or the project's ObjectScript rules, not in an
AD's Rule.

---

## 3. Could anything under Deferred let two units diverge?

Ten of the twelve deferrals are sound, and two are not.

### F3.1 — "Async admin API endpoints" is wrong on both counts and is a Release 1 hole  ·  **CRITICAL**

The row reads: *"Only 4 of 70 endpoint classes override `ShouldRunAsync`; none is on a Release 1
path."* Probed: **seven** classes override it, and at least three are on Release 1 paths.

```
%Api.Admin.Endpoints.Database.Actions          OS management (FR-58 neighbourhood)
%Api.Admin.Endpoints.Database.SysCRUD          Databases (FR-58)
%Api.Admin.Endpoints.ECP.DataServer            Stage 2
%Api.Admin.Endpoints.Journal.File              Stage 2
%Api.Admin.Endpoints.Namespace.Namespace       Stage 2
%Api.Admin.Endpoints.Security.Audit.Record     Logs — audit database viewer (FR-61)
%Api.Admin.Endpoints.Security.LDAP             Security — LDAP configurations (FR-45)
```

Worse, the audit viewer's list is not merely *capable* of running async — it is **always**
async, by a second mechanism the deferral does not mention. `Security.Audit.Record:RunList`
queues a `RecordListTask` and returns `{}`:

```objectscript
Method RunList(ByRef sc, requestBody) As %DynamicObject
{
    Set task = ##class(%Api.Admin.Endpoints.Security.Audit.RecordListTask).%New()
    Set task.TaskName = ..GetName(%request)     ; <- also F2.1(a)
    ...
    Set sc = task.AddToAsyncQueue()
    Return {}
}
```

with the class comment *"The list endpoint also runs async, but it does its own logic to queue
up a special async task."* So FR-61 — a Release 1 screen, and the screen UJ-3 ends on ("Shall I
show you the audit entry?") — cannot be read at all through AD-2's recipe. The vendor's
`Main()` handles this by constructing `%Api.Admin.Util.AsyncTaskEndpoint.%New(%request,
endpoint)`, which itself takes `%request`, so the in-process port needs a designed answer, not
a deferral.

Both the Logs unit and the Security unit (LDAP, FR-45) need that answer on day one, and the
OsMgmt unit needs it for the Databases screen whose "async values arriving" state the UX
already specifies. **This must move from Deferred into an AD**: how the port queues, polls and
surfaces an async endpoint result, and how a read tool represents a result that is not ready.

### F3.2 — "Multi-namespace ... not planned" versus FR-5's namespace switch  ·  **HIGH**

The deferral reads *"OcuPilot manages the instance that serves it, by explicit non-goal."* That
is right about multi-*instance*. Read as multi-*namespace*, it contradicts FR-5, AD-13's `?ns=`
route and the UX's namespace switch, and leaves the question in F1.4 unanswered while implying
it has been answered. Split the row: multi-instance is out; namespace scope is decided by AD-27.

### F3.3 — Provider adapters deferred with no contract to build against  ·  **MEDIUM**

"Local model profile — Anthropic only in the floor; the provider port already admits an
OpenAI-compatible adapter" defers three of four adapters to build step 7. FR-25 requires that
adding a family changes nothing in the loop, the tools or the screens. No AD states the
ProviderPort contract (message adaptation, tool-call schema translation, error and rate-limit
mapping, retry ownership, streaming seam). The adapter written in week three will be shaped by
whatever the Anthropic adapter happened to do. Pair this with F1.6.

### F3.4 — Per-user read-only and turn limits deferred while the gate is missing  ·  **MEDIUM**

Deferring the *toggle* to build step 7 is fine; F1.3's gate must exist now, or step 7 becomes a
retrofit across the panel, the turn job and the confirm path.

### F3.5 — The CORS deferral answers production and skips development  ·  **LOW**

"Same-origin by construction" is correct for the shipped product. The addendum records that
`CSPBrowserId` is `SameSite=Strict`, so an `ng serve` on another port drops it and silent login
cannot work — *"local development must proxy through the IRIS origin."* That is an
environment decision every UI unit shares (see F6.1) and it is nowhere in the document.

---

## 4. Is named technology verified-current, or asserted?

The Stack table is headed *"Verified current 2026-09-09"* and is mostly accurate. Independent
checks:

| Claim | Status |
| --- | --- |
| IRIS for Health Community 2026.2 (build 221U) | **Verified** — probed: `2026.2 (Build 221U) Fri Jun 26 2026` |
| Angular 22.1.x; v22.0.0 released 2026-06-03 | **Verified** — 22.1.5 is current (2026-09-03); v22 released 03 Jun 2026 |
| Zoneless default since v21 | **Verified** — Angular docs: "Zoneless is the default in Angular v21+" |
| Angular Material + CDK 22.x | Consistent with the release line; not independently pinned |
| IPM 0.10.x | **Verified** — 0.10.9, released 2026-08-05 |
| IPM absent from `intersystems/irishealth-community:latest-cd` | Accepted (probed three ways in the run log) |
| Admin API v2 | **Verified** — `%Api.Admin.Dispatch.v1` and `.v2` both present |
| 70 admin endpoint classes | **Verified** — `COUNT(*) = 70` (the PRD's "82" is superseded) |

### F4.1 — TypeScript 5.9.x is wrong; Angular 22 requires TypeScript 6  ·  **HIGH**

The table says *"TypeScript 5.9.x (as pinned by Angular 22)"*. Angular v22's release notes and
compatibility matrix require **TypeScript 6** (`~6.0.3` is the range currently advised), and v22
also **drops Node 20**. This is a major-version error in the one row a developer will copy into
`package.json` on day one, under a heading that claims verification. It is also the kind of
error that surfaces as a wall of template type errors rather than as a clear version message.

### F4.2 — No Node or build-toolchain row at all  ·  **MEDIUM**

Angular 22 requires Node 22.22.3+ / 24 / 26. FR-64 requires the built bundle inside the module
archive *"so install needs no Node toolchain"* — true at install, but the build and the CI job
(FR-66) need a pinned Node, a pinned package manager and a build command. Nothing in the Stack
table, the tree or the Deferred list owns this. See F6.2.

### F4.3 — Verification date precedes the document date  ·  **LOW**

The document's front matter is `updated: '2026-09-08'`; the Stack table claims verification on
2026-09-09 and the decision log dates its instance probes the same way. Harmless in substance,
but it makes the provenance of "verified" unauditable. Pick one clock.

---

## 5. Does it cover FR-1…FR-79 and NFR-1…NFR-14?

The Capability → Architecture Map lists every area and every FR range, so no *group* is
formally missing. Reading the map against the ADs it cites, four groups are named without being
governed, and one is superseded silently.

### F5.1 — FR-23 has no architecture, and FR-67's gateway requirement is silently superseded  ·  **HIGH**

FR-23 requires exponential backoff on 429/5xx honouring `Retry-After` up to a bounded count, a
fixed per-call timeout with the timed-out step named in the report, and an installer that
*checks and reports* the Web Gateway response timeout. FR-67 requires the Docker path to *set*
that timeout. The map's 5.3 row cites eight ADs, none of which mentions retry, timeout or the
gateway. AD-7 argues persuasively that a background turn job "removes the Web Gateway 300 s
timeout from the install prerequisites entirely" — which may well be right, but it is a change
to two stated requirements and the spine does not say so. Either state the supersession (and
what FR-23's installer check becomes) or carry the requirement.

### F5.2 — FR-24…FR-27 (provider families, credential ladder, test connection) are unaddressed  ·  **MEDIUM**

The map's 5.4 row cites AD-9 and AD-21 — state protection and injection safety. The eleven
validation rules, the provider cascade, the credential ladder's two rungs and their namespace
condition (FR-26: the IRIS-credentials rung requires an interoperability-enabled namespace),
and Test connection's endpoint restrictions have no invariant. Cross-refs F1.6, F3.3.

### F5.3 — FR-7's auto-refresh framework is a store field, not a contract  ·  **MEDIUM**

FR-7 requires persisted rate, sort, filter, page size and max rows per screen, a last-update
stamp, and a **pause while a proposal on that screen's entity type is awaiting confirmation**.
AD-19 lists these as store contents; AD-14 covers the change event. The pause rule — which
couples the panel, the proposal store and every list screen — is stated in the PRD and the UX
and in no AD. Five areas have auto-refresh screens; each will implement the pause differently
or not at all.

### F5.4 — FR-4's route-to-classic-resource mapping is unaddressed  ·  **MEDIUM**

The addendum records that the classic portal's **custom portal resources are keyed by
normalised classic page URL**, and that *"OcuPilot's routes must map back to those keys, or
existing assignments are lost. Relevant to FR-4."* The descriptor (AD-5) carries a privilege
resource but no classic-page key. FR-9's fallback links need the same mapping. One field on the
descriptor closes both.

### F5.5 — FR-66's smoke script and CI harness are unowned  ·  **MEDIUM**

FR-66 requires a smoke script that runs UJ-3 against a fresh container and *"gates every publish
of the listing and every step of the build order"*, plus a CI unit-test harness against a stock
image with at least one test per endpoint, the confirmation-binding tests, the state-protection
test and the audit-marker round trip. The Conventions table's Tests row covers per-handler and
per-tool tests. Nothing owns the smoke script, CI, or the image re-pinning FR-67 requires at
each publish. See F6.2.

### F5.6 — NFR-12 accessibility has no architectural hook  ·  **LOW**

The UX's accessibility floor is unusually load-bearing (gated controls must be `aria-disabled`
and focusable rather than `disabled`; tables are one `role="grid"` Tab stop with
`aria-activedescendant` so in-place re-fetch never drops focus — which is an AD-14 requirement,
not a styling one). AD-29 (F1.7) would carry this; without it, "keyboard operation of every
screen" is six independent implementations.

Otherwise: FR-1–FR-9 (partly, see F1.1), FR-10–FR-15, FR-16–FR-22, FR-28–FR-29, FR-30–FR-63,
FR-64–FR-69 and FR-70–FR-79 are all located in the map, and NFR-3 through NFR-11 and NFR-13 are
each traceable to at least one AD or Convention.

---

## 6. Is every structural dimension decided, deferred, or an open question?

| Dimension | Status in the spine |
| --- | --- |
| Deployment topology | **Decided** — AD-17, AD-18; container start, one instance |
| Distribution channel | **Decided** — AD-18 |
| Runtime stack | **Decided** (with F4.1) |
| Source tree / module boundaries | **Decided** — seed tree, paradigm |
| Data shape | **Seed** — Core entities ERD |
| Persistence protection | **Decided** — AD-9 (with F2.3) |
| Authn/authz (server) | **Decided** — AD-8 (with F2.4) |
| Authn/session (browser) | **SILENT** — F1.1 |
| Environments and dev loop | **SILENT** — F6.1 |
| Build, CI, release | **SILENT** — F6.2 |
| Data lifecycle / retention | **SILENT** — F6.3 |
| Backup & recovery | **SILENT** — F6.4 |
| Upgrade & data migration | **Partial** — code only; F6.5 |
| Performance budgets | **SILENT as an invariant** — F6.6 |
| Observability & diagnostics | **Partial** — F6.7 |
| Web-layer security posture | **SILENT** — F6.8 |
| Egress / outbound network | **SILENT** — F1.6 |
| Cost controls | **Deferred** — acceptable (bounded by max tokens/iterations) |
| Localization | Decided by NFR-14; not restated (fine) |

### F6.1 — Environments and the development loop  ·  **HIGH**

Nothing states how a developer runs the shell against the instance. The constraint is already
known and is not obvious: `CSPBrowserId` is `SameSite=Strict`, so `ng serve` on another port
silently breaks silent login and every developer will hit it. Related decisions with no home:
the `base href` set at build time, "Serve Files Always" during development to defeat gateway
caching, and immutable cache headers for hashed assets versus no-cache for `index.html` (all in
the addendum, none in the spine). Nine units share one dev loop; if two developers proxy
differently, two sets of auth bugs are reported that neither can reproduce.

### F6.2 — Build, CI and release  ·  **HIGH**

Unowned: the pinned Node and package manager (F4.2); how the Angular bundle is built and placed
into the IPM archive and the Docker image; the smoke script that gates every build step (F5.5);
CI against a stock image; and FR-67's re-pinning of the exact image tag at each publish. This
is the packaging unit's core work and the one the feasibility budget rates *low* confidence at
2.5 days.

### F6.3 — Data lifecycle and retention  ·  **HIGH**

The ledger records every LLM call and every tool call from Release 1. Transcripts, proposals
and per-turn progress accumulate. Nothing states retention, purge ownership, or growth bounds;
FR-72's purge task is polish-week and covers transcripts only. On a Community container with a
judge exercising the demo through a voting week, an unbounded ledger in the protected database
is a plausible failure, and each of the three writers (ledger, transcript, proposal) will make
its own choice.

### F6.4 — Backup, journaling and the state database's physical placement  ·  **MEDIUM**

AD-9 creates a database and says nothing about where its `.DAT` lives, whether it is journalled,
or what backup/restore means for it — despite AD-17's own finding that only `/durable` survives
a restart. See F2.3.

### F6.5 — Data migration across builds  ·  **MEDIUM**

SM-2 commits to a user-visible change every day of the voting week, on top of an installed base
that already holds definitions, ledger rows, transcripts and a governance baseline. AD-17
guarantees the *installer* is idempotent; nothing says what happens to persisted data when a
storage class changes shape between builds, or where AD-22's frozen baseline is stored and how
it survives an upgrade (the AD says it is "captured at the Release 1 freeze" and "never
regenerated to grow" — so an upgrade that loses it silently disables every write tool).

### F6.6 — Performance budgets are quoted, never turned into a rule  ·  **MEDIUM**

NFR-1's two-second targets are cited as bindings on AD-7 and AD-19 but produce no invariant:
no default page size, no virtualisation requirement, no payload cap, no measurement point.
See F1.2.

### F6.7 — Observability  ·  **MEDIUM**

The Conventions table names "one structured logger, one line per event, JSON payload" without
saying where it writes (messages.log? a global? the ledger?), what levels exist, or what
identifier ties a turn to its tool calls, its proposal, its write and its audit marker. AD-15
solves the audit↔vendor-event pairing; the internal chain is unaddressed, and NFR-7's "without
correlating across systems by hand" depends on it.

### F6.8 — Web-layer security posture of the static application  ·  **MEDIUM**

The static shell is served unauthenticated (FR-65). No Content-Security-Policy, frame-ancestors,
referrer or cache-control policy is stated, although AD-11's "issues no request to any host but
the configured provider" and NFR-10's no-CDN promise are both enforced in practice by a CSP
header. Stage 4's embedded editors make `frame-ancestors` a forward-looking decision too.

### F6.9 — No health or readiness endpoint  ·  **LOW**

The Compose flow is judge-facing; "is OcuPilot up yet" has no answer other than loading the SPA.
Cheap to add, and the installer already needs a self-check.

---

## 7. Is the altitude right?

Broadly yes. The document reads as a set of invariants rather than a design, the diagrams are
seed rather than prescription, and most ADs bind a decision that two units would otherwise make
differently without dictating how either implements it. AD-6, AD-13, AD-14, AD-17, AD-19 and
AD-20 are model entries: each states a divergence, a rule, and something a reviewer can check.

Four exceptions.

### F7.1 — AD-11 is above the altitude at which it could bind  ·  **MEDIUM**

A rule a reviewer cannot check is a value statement. See F2.5.

### F7.2 — AD-5 does not say how the descriptor becomes code  ·  **MEDIUM**

AD-5 is the keystone: sixty screens, seven derived artefacts, a client mirror "as generated
TypeScript". It does not say whether derivation is compile-time code generation, runtime
reflection over the class dictionary, or a build step; who owns the generator; where the
generated TypeScript lands; or what the descriptor may *not* carry (presentation? column
widths? copy?). Two units will answer differently, and the answer determines whether adding a
screen is a one-file change (the AD's promise) or a three-place change. Pair with AD-3's same
gap (F2.7).

### F7.3 — Two rules descend to story or standards level  ·  **LOW**

AD-12's nested-`Catch` prescription is an ObjectScript coding standard (it already appears in
the project's own rules); AD-13's "fixed corpus that includes a leading underscore, a slash, a
space, a percent sign and a non-ASCII character" is a story's acceptance criterion. Both are
good; neither is an initiative invariant. Move them to the Conventions table and the story
template respectively, keeping the invariant ("one shared encode/decode pair, never a slice").

### F7.4 — AD-2 states a method sequence where it should state a contract  ·  **LOW** (severity of the altitude issue only; the factual defects are F2.1)

Because AdminPort is implemented once, the detail is defensible — but expressing it as a
call sequence is what let the missing steps (ApiVersion, output capture, status mapping, async)
go unnoticed. A port contract — inputs, result, error mapping, output capture, async handling —
would have made the omissions visible.

Nothing else in the document is too vague to bind or too specific to be an invariant. The
Consistency Conventions table is at the right altitude throughout, and the Deferred table's
"Revisit when" column is specific enough to act on.

---

## Findings by severity

**Critical (4)**
- F1.1 — no session/token/401 contract for the browser side
- F2.1 — AD-2: `%request` claim false; `SetRespStatus` a no-op under `IsRunningAsync=1`; recipe omits ApiVersion, output capture, `<PROTECT>`→403 and the async branch
- F2.2 — AD-4: get-merge-put generalised from one endpoint; 29 of 47 PUTs use another idiom; `Wallet.Secret` 400s on a changed-fields-only body; two Release 1 PUTs are upserts
- F3.1 — "async endpoints" deferral wrong on both counts; FR-61's audit list is unconditionally async and unreadable through AD-2

**High (14)**
- F1.2 list/model-input budget · F1.3 switch evaluation points · F1.4 namespace scope ·
  F1.5 MonitorPort/MgmntPort · F1.6 outbound HTTPS, SSL config, proxy, CA ·
  F2.3 AD-9 code placement · F2.4 `%DB_IRISSYS:R` + `%Admin_Secure:U` · F2.5 AD-11 unenforceable ·
  F3.2 multi-namespace deferral vs FR-5 · F4.1 TypeScript 6, not 5.9 · F5.1 FR-23 / FR-67 gateway ·
  F6.1 environments and dev loop · F6.2 build/CI/release · F6.3 data retention

**Medium (18)** — F1.7 archetype implementations · F1.8 web-app settings · F2.6 IRISTEMP progress ·
F2.7 AD-3 generation artefacts · F3.3 ProviderPort contract · F3.4 gate before step 7 ·
F4.2 Node toolchain · F5.2 provider/credential/test-connection · F5.3 auto-refresh pause ·
F5.4 classic-resource key mapping · F5.5 smoke script and CI · F6.4 backup/placement ·
F6.5 data migration · F6.6 performance budgets · F6.7 observability · F6.8 CSP posture ·
F7.1 AD-11 altitude · F7.2 AD-5 derivation mechanism

**Low (9)** — F1.9 progress record shape · F2.8 prohibited-set homes · F2.9 AD-12 test strength ·
F3.5 dev origin · F4.3 verification date · F5.6 accessibility hook · F6.9 health endpoint ·
F7.3 two story-level rules · F7.4 AD-2 as contract

---

## Evidence appendix

All probes on `ocupilot-iris`, namespace `%SYS`, 2026-09-08. A scratch class
(`OcuPilotReviewProbe.Scan`) was used to read method implementation streams and was deleted
afterwards.

**Endpoint count (AD-2's "70")**
```sql
SELECT COUNT(*) FROM %Dictionary.CompiledClass
 WHERE Name %STARTSWITH '%Api.Admin.Endpoints.'          -- 70
```

**`ShouldRunAsync` overrides (Deferred row's "4")**
```sql
SELECT parent, Name FROM %Dictionary.CompiledMethod
 WHERE Name = 'ShouldRunAsync' AND parent %STARTSWITH '%Api.Admin.Endpoints.'
   AND Origin = parent                                    -- 7 rows, listed in F3.1
```

**`%request` / `%response` / `%session` references (AD-2's "free of")** — stream scan over
`%Dictionary.CompiledMethod.Implementation` for own methods of `%Api.Admin.Endpoints.*`:
`COUNT = 11`, listed in F2.1(a).

**PUT merge idiom (AD-4)** — same scan over own `RunPut` methods:
`MergeJsonAndProperties` present in 18; absent in 29, including `Security.User`, `Task.CRUD`,
`Security.Resource`, `Security.X509Credential`, `Security.Audit.Enabled`, `Security.Audit.Event`,
`Wallet.Secret`, `Device.Settings`, `Database.SysCRUD`, `DocDB`, `Security.OAuth2.*`,
`Security.SQLPrivilege.*`, `Security.WebAuth`, `License.Key`, `FSAccess.*`.

**`%Api.Admin.Endpoint:SetRespStatus`** (verbatim) — the no-op under `IsRunningAsync`:
```objectscript
If '..IsRunningAsync {
    Set %response.Status = status
}
```

**`%Api.Admin.Dispatch.v1:Main()`** — the steps AD-2 omits: `endpoint.ApiVersion` assignment;
`ValidateQueryParams()`; `NeedsRequestBody()` + content-type checks; the `ShouldRunAsync()`
branch constructing `%Api.Admin.Util.AsyncTaskEndpoint.%New(%request, endpoint)`;
`BeginCaptureOutput`/`EndCaptureOutput` into the message array; and the
`<PROTECT>` → `HTTP403FORBIDDEN` catch. Gate is `ResourcesOR()` only — **no `ResourcesAND`
exists anywhere in `%Api.Admin.*`**, so AD-2 is correct on that point.

**`Wallet.Secret:RunPut`** — requires `requestBody.Type` against a three-value allow-list, 400
otherwise; `Create`s when the secret does not exist (upsert).
**`Security.Audit.Event:RunPut`** — `Create`s with 201 when the event does not exist, else
`Modify` with `%IsDefined` guards (upsert, partial honoured).
**`Security.User:RunPut` → `UpdateUser`** — iterates `..Schema()` with `json.%IsDefined(key)`,
then `Security.Users.Modify` (partial honoured, third idiom).
**`Task.CRUD:RunPut`** — `MergeJsonAndObj` then `%Save()` (second idiom); returns 409 via
`SetRespStatus` on a bad start date.

**Instance identity** — `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2
(Build 221U) Fri Jun 26 2026`, GUID `92989EE2-AB37-11F1-AE6A-769196E3B75A`.

**External** — Angular v22 release notes and compatibility matrix (TypeScript 6 required,
Node 20 dropped); angular.dev Zoneless guide ("default in Angular v21+"); Angular 22.1.5 current
(2026-09-03); IPM 0.10.9 (2026-08-05); InterSystems *Authorization Guide* → Applications
(privileged routine applications, `AddRoles`) and *System Administration Guide* → Using
Resources to Protect Assets (database Read = "data access and routine execution"; `%DB_IRISTEMP`
Read/Write public by default); *Using Security APIs and Role Escalation* (since 2025.2 all
security APIs require `%DB_IRISSYS:R` and `%Admin_Secure:U`).
