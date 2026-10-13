# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental, hidden `/api/admin` v2 service, plus `/api/mgmnt` and `/api/monitor` where they back a screen. That covers namespaces and mappings, databases and disk operations, journals, licensing and ECP, encryption, superservers and authentication options, MFT, SQL privileges, web-application extras and monitoring. Each screen comes with a read tool and a confirmed single-write tool, so the agent keeps pace with the portal. The stage also prepares OcuPilot for real, shared instances: install into a chosen namespace, a clean uninstall, and a directory allow-list only a person can edit. It keeps the doubled tool roster affordable with per-turn budgets and scoped tool sets, and extends provider configuration with proxy and custom-CA settings and a wallet-held key. It is the first versioned IPM release after the contest.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Superservers, authentication options and managed file transfer
- Story 18.9: SQL object privileges
- Story 18.10: Web application extras and spec-based REST services
- Story 18.11: Monitoring extras and the live log tail
- Story 18.12: The agent grows with the stage
- Story 18.13: Multi-namespace install
- Story 18.14: Namespace mappings and copy-mappings
- Story 18.15: Enable interoperability on a namespace
- Story 18.16: Remote databases
- Story 18.17: Namespace and database follow-ups
- Story 18.18: Journal settings
- Story 18.19: Journal record browser
- Story 18.20: ECP data servers
- Story 18.21: ECP settings and application servers
- Story 18.22: Database and data-element encryption keys
- Story 18.23: Encryption startup settings
- Story 18.24: RSA and symmetric-key wallet secrets
- Story 18.25: Superservers
- Story 18.26: Managed file transfer connections
- Story 18.27: The operator's read-only LDAP view (closed unbuilt)
- Story 18.28: SQL column and admin privileges
- Story 18.29: Role members' admin option, user Copy from and password validation
- Story 18.30: Doc DB applications
- Story 18.31: Privileged routine applications
- Story 18.32: Spec-based REST services
- Story 18.33: Privileged routine application roles and routines
- Story 18.34: The person's REST service create
- Story 18.36: Dashboard drill-downs
- Story 18.37: Interoperability usage
- Story 18.38: The live log tail
- Story 18.39: The agent's context budget
- Story 18.40: Proxy and custom CA configuration
- Story 18.41: The wallet credential rung
- Story 18.42: Allowed directories: a person's write
- Story 18.43: Uninstall and grants on a shared instance
- Story 18.45: The agent's tool roster scoped per turn
- Story 18.46: Allowed directories: the screen's add, change and remove

## Requirements & Constraints

- **One contract, no feature spec.** A story is accepted against the staged-delivery contract plus its own backing route. Anything finer is authored when the story is picked up, never invented ahead.
- **One way to build a screen.** Each screen has one descriptor and reaches outside systems through one port. Its read tool and its write tools' field lists derive from that descriptor, with no hand-written dispatch or field list. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker.
- **Reads.** Every read is bounded and reports truncation. A screen's list and its read tool resolve through one declared read.
- **Gates.** Every gate is the caller's own `(resource, permission)` pairs, checked at call time. There is no service account. The vendor's `ResourcesOR()` is only a lower bound, so take privileges from the instance, not the specification.
- **Governance.** Every destructive or disruptive action ships with its governance key disabled: delete, dismount, truncate, encryption changes, the allow-list write. A new write key joins the checked-in baseline in the same change.
- **Secrets.** Key material and secrets are write-only and returned by no read. They are redacted from the ledger and every log line, and never placed in an exception, status or trap.
- **Paths.** No endpoint takes a caller path. Every server-path field resolves through the allow-list (`PathPort`), whose self-protection refusals cover the manager directory, the served directory, instance, database and journal files, and an existing `IRIS.DAT`. A database create always names its own directory.
- **Measure first.** The admin API's specification and IRIS disagree in places. Observe payloads, privileges and effects on a throwaway (Task 0) before building a form. "Checked" means seen on an instance; "reported" means another source's word only.
- **Owner calls.** A choice that changes a product promise, trust scope or secret exposure goes to the owner at the spec gate, before anything is built.

## Technical Decisions

- **`AdminPort`** is the only code that names `%Api.Admin.*`. It runs the vendor endpoint objects in process, in `%SYS` by explicit save and restore, at ApiVersion 2 with stub CSP state and `IsRunningAsync` 0. It reads the outcome from both `tSC` and `%response.Status`; a non-2xx answer is a failure. A read answered 404, and a correct field refusal listed in `UNLOGGEDREFUSALS`, are not logged, so they do not raise the instance alert state. Port guards refuse before the vendor call: SQL-privilege wildcards and lists, a password the policy refuses, and a privileged-routine or web-app call whose target is the wrong type.
- **Vendor-class fallback.** Where the admin API cannot carry a call, a dedicated port repeats the endpoint's gate and calls the vendor class in `%SYS`. Each such case is named in the architecture (user copy, background tasks, the encryption reads, for example).
- **Async.** The port picks the path per request type. One poller per task reads the finished result exactly once and deletes the row; a second read logs #7846 and turns the instance state to Warning. A read that hits the bound fails with `PORT.TIMEOUT`; a queued write that hits it answers "started". A queued write is refused unless it is named in `QUEUEDWRITES` or `SELFQUEUEDTYPES` and its body carries no secret. No slice writes polling logic.
- **Writes.** OcuPilot reads fresh, applies the diff and sends the complete property set. Per-endpoint exceptions are recorded in the architecture: journal settings, ECP's nested settings, encryption settings, web authentication, superservers, MFT, and the privileged-routine PUT, which replaces `MatchRoles` and empties an omitted `Routines`. There are three write kinds: merge; action-style (no body, a declared request type and fingerprint subject); and create (fingerprints the target's absence, which covers upserts). A write tool declares its port. A screen's Save and the agent's proposal are two callers of one tool. Save mints no proposal but inherits the prohibited set and the write's validation, and read-only and the kill switch never gate it. Every confirmed write reads its target back and returns a verdict.
- **Field lists and secrets.** Write field lists are generated at build time from the endpoint's body template and checked in, and the CI inventory fixture pins them. Each field is classified `ordinary`, `secret` or `opaque`; an unclassified field defaults to secret.
- **Prohibited set.** It lives once, in the kernel, and is evaluated against the resolved target inside the atomic confirm transition, from either caller. Stage 2 added these protections:
  - OcuPilot's install namespace, its mappings (matched by pattern overlap) and its databases, plus the seven system databases
  - keys in use
  - a start that cannot finish
  - OcuPilot's own sign-in, the O/S authentication its start hook signs in with, and the serving superserver
  - OcuPilot's SQL schemas and its privileged routine applications
  - any agent write to the allow-list

  A `%All` or `%Admin_*` grant is permitted, at the destructive confirmation, naming the privilege.
- **Tools per turn.** The tool listing is built from compile-time declarations only and cached per process, keyed by compile signature. A turn's scoped tool set is chosen after the listing, never inside it: the shell area's tools, the discovery tool `shell.tools.find`, and the screen context's tools. History is append-only, and a turn's tool results share a cap of 262,144 characters.
- **Monitoring.** `MonitorPort` reads in process behind `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, so the monitor API's anonymous reachability never becomes OcuPilot's. A metrics read rewrites the vendor's sensor baseline, so that screen never auto-refreshes. Interoperability usage runs the classic page's class queries as the signed-in user and never calls the deprecated `/api/monitor/interop`.
- **Vendor writes during reads.** A vendor-internal write a read triggers is tolerated only under the named exceptions; a new one goes to the lead.
- **Install.** One idempotent `Installer` class has two entry points, with one install namespace per instance. OcuPilot's globals map into its protected database, and its code stays in the install namespace's routines database. Uninstall removes only what OcuPilot created and still owns.
- **Provider.** The provider call uses a named SSL configuration created at install, with server-identity checking on. Proxy settings are configuration, and a custom CA is a separately named SSL configuration. Provider egress is an allow-list. The credential is fetched at the point of use and never logged.

## UX & Interaction Patterns

- A person's destructive action uses a typed-name dialog that names the target, with its consequence stated above the field. An agent proposal gets the destructive card treatment, without a typed name.
- A consequence sentence appears both at the form field and on the proposal card. Confirmations always name the target.
- A delete wizard lists dependents (namespaces, databases, web applications) before removing anything.
- An action whose governance key is off is drawn off, with the refusal's sentence as the reason.
- Async operations show progress from the port's single poller, which stops at the end. Auto-refresh comes only from the shared framework and pauses while a proposal is live.
- Every screen keeps working with the agent disabled.
- A new screen registers the full screen contract: route, side-bar position, archetype, pairs, entity key, context serializer, actions, empty state, fixed strings, aliases, and at least three suggested prompts. Adding a side-bar entry updates the browser specs that pin that area's list.

## Cross-Story Dependencies

- **Open at this compile:** 18.37 and 18.46 (ready for dev), and 18.38, 18.40 and 18.41 (backlog). The rest are done.
- **18.46** builds on 18.42's route, port, governance key and kernel refusal.
- **18.38** needs three tier-1 amendments at its spec gate: a heartbeat carve-out in the error envelope, the live-data framework, and the UX that defers the live tail. The "nothing streams" pins are re-scoped to sources that do not opt in.
- **18.37** prefers a source that checks the caller; relaxing that check is the owner's call. Its Task 0 measures any vendor metric-state write.
- **18.40** amends the outbound-TLS decision; the CA trust scope is the owner's call.
- **18.41** amends the egress, secrets and turn-job decisions. The vendor's per-use audit write is labeled (inference) until Task 0 measures it.
- **Other epics:**
  - 18.32 reused Story 20.21's namespace-routines-database check.
  - 18.45 sits after Story 20.24's per-process listing.
  - 18.30 leaves Story 19.17's Doc DB create and drop unchanged.
  - 18.3 and 18.4 extend Epic 16's `BackgroundTaskPort`.
  - Routed ledger items not taken by a story go to the Epic 18 burn-down.
