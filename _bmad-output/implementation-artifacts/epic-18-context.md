# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool and, where it writes, confirmed single-write tools. The agent grows with the stage: wallet-backed keys, history budgeting as the tool roster roughly doubles, and proxy and custom-CA support as configuration. This is the first versioned IPM release after the contest. Done: 18.1 to 18.11 and 18.14 to 18.34 (18.27 closed unbuilt, 18.35 retired). 18.36 is planned, gated and ready to implement. Still to plan, in run order: 18.12, 18.13, 18.37, 18.38, then the Epic 18 burn-down (18.39), then the epic close.

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
- Story 18.11: Monitoring extras (narrowed to the Prometheus metrics table)
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
- Story 18.39: The Epic 18 burn-down (chartered at the burn-down gate; not in the epics file)

## Requirements & Constraints

- **One contract (FR-80).** Each screen is one descriptor over one port; its read tool and its write tools' field lists derive from it. Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Acceptance is that contract plus each row's backing route; anything finer is authored when the story is picked up.
- **Governance.** Every destructive or disruptive key ships `false`. A story that adds a write key adds its baseline entry. 18.36, 18.37 and 18.38 are read-only and add no keys.
- **Observe first.** Measure each route's payload, effects, privileges and audit events on a throwaway before any form or tool exists. Take privileges from the instance, measured as a least-privileged principal, never from the specification. Never build on a `decision-pending` ledger entry.
- **Budgets.**
  - Bundle: about 3,323 kB at 18.11 against a 3487kB warning and a 4000kB error budget. Re-base the warning to 5% above the measured total when a story crosses it (DW-1166); stop and ask above 3800kB.
  - Fixed strings: 3,142 of the 3,400 bound at 18.11, and 18.36 adds its own. Stop past 3,350.
  - `Api/Error.cls` holds 989 of the 1,000 parameters a class may carry. New codes go in a sibling `*Error.cls` with prefix arms in `Error`'s reason mappers.
  - Entity types: 70 (18.11 and 18.36 add none). Read tools: 356 on the branch after 20.23's forward merge; 18.36 adds four.
- **Ledger, by owner.** Address each item, or decline it with a reason.
  - **18.12:** DW-1756 (the Guardrails page lacks the turns-per-hour setting), DW-1084 (the built-in system prompt never asks the model to name rows in backticks or to offer to select them, so that offer has no producer), DW-2321 (the update tools take `MatchRoles` and `Routines` whole, but no read answers either list; expose both for web applications and privileged routine applications, as a read field or a detail read).
  - **18.13:** DW-219 (uninstall's three half-state paths on an instance OcuPilot does not wholly own), DW-423 (`Stamp` keeps one row per install run with no retention; the live instance held 3,306), DW-1333 (IPM's exporter drops `<SystemRequirements>`, so the archive carries no IRIS or IPM version floor), DW-2172 (detect a SQL grant on OcuPilot's schemas widened outside OcuPilot, to another role or `_PUBLIC`, beside install's schema-grant read-back).
  - **18.36, 18.37, 18.38:** none.
  - **18.39 fixes, by orchestrator ruling:** DW-2311, DW-2320, DW-2322, DW-2328; it audits DW-2327.
  - **18.39 also owns:** DW-1896 (measure `Security.LDAPConfigs.Modify` in `%SYS`; build only under the caller's own `%Admin_Secure`, else wontfix-accepted), DW-2167 (the vendor's #822 answers as an access refusal, not an absence), DW-2160 (23.4's poll for `AuditVendorSecrets.AssertMasked` and siblings), DW-1966 (refuse an existing database's directory as a journal directory), DW-2007 (#1454 unlogged; the spine already says so), DW-2085 (Encrypt database on create while a database key is active), DW-2086 (the reviewed key list in an activation's fingerprint), DW-2087 (a first key activation's start-mode change outlives deactivation), DW-2126 (name a stored certificate's loss when an RSA key is replaced), DW-2100 (high: measure on a throwaway, then decide AD-10's start arm), DW-1979 and DW-1981 (journal records' order; offset and value input lengths), DW-2149 (probe snapshots read `Monitor.State`), DW-2299 (lift the delete tools' `StateDiff` into `Screen/Tool/Write.cls` after Epic 20 merges).
  - **Never built on:** DW-2329 (decision-pending: are backslashes in Windows `dir` labels doubled) and the vendor-defect candidates on owner hold (for example DW-2283, DW-2284, DW-2309), which stay unreported.
  - **Not Epic 18's:** the CI flakes DW-2111 and DW-2123 go to the next epic burn-down gate. Entries from Epic 20's stories (DW-2214, DW-2225, DW-2253, DW-2301, DW-2314) belong to Epic 20's burn-down.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort` names `%Api.Admin.*`, reading the outcome from both `tSC` and `%response.Status`. A read answered 404 is an absence and is not logged. Any other failure outside the unlogged list is logged and raises the instance's alert state, so refuse a predictable vendor refusal before the call. A finished async task is read once, by the port's one poller (AD-26); a queued write still running at the bound answers as started and logs nothing, while a read that reaches the bound still logs.
- **Gates (AD-8, AD-29).** There is no service account; the only OcuPilot elevation is AD-9's, and it is never in effect while tool, port or provider code runs. A vendor method that checks the caller and then runs as its own account is the vendor's model, not an elevation. Each port carries its own gate, evaluated before any vendor call. `ResourcesOR()` is a lower bound: read the backing class's own check, then run as a real least-privileged principal on a throwaway. The monitoring API's anonymous reachability never becomes OcuPilot's. `MonitorPort` alone calls `SYS.Monitor.SAM.Sensors.PrometheusMetrics()`, behind `%Admin_Operate:USE` plus `%DB_IRISSYS:READ`.
- **Vendor-internal writes (AD-7).** The turn never mutates the instance. Exactly six vendor-internal write shapes are named, among them the sensor baseline (each metrics read rewrites 24 `^IRIS.Temp.SAM` nodes); any new shape needs a spine amendment at its spec gate. Never call the alerts read, which advances `LastAlertSent`.
- **Read contract (AD-36, AD-24).** One read serves the screen and the tool. Bounds: 200 rows by default (operator sets 1 to 1,000), 65,536 characters in total, 1,000 characters a field; the payload reports `rowsSent`, `rowsAvailable` and truncation. A bare-rows read and a parent-scoped `VOLUMELIST` read require their route criterion before any port call; other parent-scoped reads are not covered by that check. 18.11 added the `monitor` source kind; 18.36 adds `AdminPort`'s composed `RESOURCEROWS` and `BUSYPROCESSES` (empty-`Process` rows dropped) with the grammar unchanged.
- **Writes.** A merge reads fresh and sends the complete body (AD-4). A create fingerprints the target's absence (AD-54); an action fingerprints its preconditions (AD-51). The screen and the agent are two callers of one tool (AD-53, AD-55), under the per-target hold (AD-34), with a read-back (AD-58) and a change event (AD-14). A screen Save evaluates AD-10's prohibited set against the resolved target after the state read and before the port's write.
- **Self-protection (AD-10).** Predicates are stated over the effect and evaluated inside the confirm's atomic transition. Granting `%All` or an `%Admin_*` privilege through a role, an application role, a matching role or a routine is permitted at the destructive treatment naming the privilege (`GRANT.PRIVILEGED`). Every change to OcuPilot's own `OcuPilotState` and `OcuPilotIdentity` is refused (`PROHIBITED.OCUPILOTROUTINEAPP`). Deleting, or changing the databases of, OcuPilot's install namespace or `%SYS` is refused (`PROHIBITED.OCUPILOTNAMESPACE`).
- **Text and amendments.** Vendor text is logged, never sent (AD-39). Each refusal sentence is written once, in Fixed strings. New pairs, predicates, source kinds, vendor-write shapes and carve-outs are amended into the spine at the spec gate (Rule 20).
- **18.12, the agent's growth.**
  - Every Stage 2 screen brings its tools from its descriptor with no hand-written tool code. A tool declared unadvertised stays out of the provider list, dispatch and screen context (AD-53).
  - History already replays earlier turns only as their user message and final reply, capped at 65,536 characters oldest-first, never tool results or screen context (AD-24). The new pressure is the roster itself, 356 read tools plus the write tools (inference). Any new trimming rule is a spine amendment.
  - The tool listing (AD-5, as of 20.24) is cached per process by namespace and registry class in `Screen.Tool.Registry.ListTools` (`BuildListing`, `CompileSignature`, `BuildCount`, `ForgetListing`), rebuilt when the `OcuPilot.` compile signature changes. Only compile-time declarations decide what is listed; a setting, grant, adjustment or policy is read on every call. Extend the cache; never bypass it or key it on a runtime value.
  - Proxy egress (judged as a destination, https CONNECT-tunnelled, bypassed by a marked-local endpoint, AD-42) and the installer-created SSL configuration with server-identity checking (AD-32) already ship in `ProviderPort` (inference: the proxy and custom-CA criterion may be largely met; Task 0 confirms what a custom CA still needs).
  - The credential ladder (`Kernel.Secret.Ladder`) ships the `env` and `creds` rungs. A wallet-backed rung joins it, reusing the wallet wiring the secrets screens already use. The ladder never returns a value into a status or an error (AD-42), and no secret reaches a surface OcuPilot displays (AD-35).
  - DW-2321 (inference): a whole list as one row field meets the 1,000-character field cut, so a detail read with one row per role or routine fits the read contract better.
- **18.13, multi-namespace install.**
  - One idempotent `Installer`, run from the container start or IPM's `<Invoke>`; only the container path unexpires `_SYSTEM` (AD-17). IPM is never a runtime dependency (AD-18).
  - Validation refuses `%SYS`, confirms the namespace exists, confirms interoperability enablement where a chosen credential rung needs it (the `creds` rung does), and maps the package.
  - Code lives in the install namespace's database; only OcuPilot's globals sit behind its protected resource (AD-9). Each unauthenticated application carries exactly one application role, read-only on the install namespace's routines and default globals databases (AD-21).
  - Install reads back its schema grant, and the gate answers `unreadable` when it cannot read its own state (AD-38). OcuPilot deletes only what it created, and its retention sweep acts on its own state (AD-37), which is where DW-423's `Stamp` retention belongs.
  - AD-10's install-namespace arm names one namespace; more than one install namespace needs that arm restated at the gate (inference).
- **18.37, interoperability usage.**
  - The catalog row names the deprecated `/api/monitor/interop/v1` (`%Api.InteropMetrics.v1`). It checks nothing, and it reaches the `[Internal]` `%SYS.Ensemble.SetSAMSensorsForInterop*` methods, which escalate with `$$$AddAllRoleTemporaryInTry`. That fails AD-8's test, which accepts a vendor running as itself only after the vendor has checked the caller.
  - The classic page (`%CSP.UI.Portal.InteroperabilityUsage`, `RESOURCE` `%Admin_Operate`) queries `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces`. The spec gate prefers the source that keeps AD-8 as written; any relaxation of AD-8 is the owner's call, raised through the Planner.
  - The gate also settles whether the sensor setters write state, which would be a new AD-7 shape. The port declares its own gate (AD-29) and fits AD-62, which reaches interoperability through one port behind its own gate (inference).
- **18.38, the live tail.**
  - The sources are `messages.log` and `alerts.log`, the only ones with `LogSourcePort`'s offset-and-identity cursor. They opt in through a descriptor key (an AD-5 addition), and each keeps the classic log page's resource.
  - The catalog row named a `%SYSTEM.Event` long-poll, but no vendor event signals a log write. An OcuPilot route therefore long-polls within `Kernel.Provider.TestCall.BoundSeconds`, re-checking the file's size and identity between waits (iris-couch's `ChangesHandler` pattern). Rotation invalidates offsets, so the tail restarts cleanly (AD-21).
  - No endpoint accepts a path; a log is named from a fixed enum (AD-21). Log text reaching the model passes AD-60's sanitizer.
  - Only the response writer writes to the device, and the static handler is its one carve-out (AD-12). Heartbeat bytes need a second carve-out, and AD-43 needs an amendment; both are tier-1 amendments at the spec gate. Whether concurrent tails need a per-user bound, as turns have (AD-41), is a gate question (inference: each open poll holds a server process up to the bound).
  - Anchors: `LogSourcePort` `Page`, `Identity` and `ReadWindow` (the port never writes to the device); `Api/LogPage.cls` and the log routes in `Api/Router.cls`; `Api/Response.cls`; the client's `log-viewer.store.ts` (`loadNewer`, `read`); and `core/turn.ts` as the chained-poll precedent.
- **18.39, the burn-down.**
  - DW-2311: in `MgmntPort.Resolved`, walk each listed application's `UrlMap` `Forward` targets and read `GetWebRESTApps` over every namespace, so a forwarded or cross-namespace service counts as deployed.
  - DW-2320: key the held and wanted `MatchRoles` targets by matching role and target in `GrantsPrivilegeByEffect` (`Kernel/Proposal/Prohibited.cls`), so moving a privileged target to another or an empty matching role counts as a grant.
  - DW-2322: clearing a privileged routine application's `Resource`, or enabling it, while it grants a privileged role takes the privileged-grant treatment, because the vendor runs an application with no resource for anyone.
  - DW-2328: rows of an id-kind-none list share one key when the name column repeats (MetricsList: 942 rows over 115 metrics). Either give such rows a row-unique key in the shell's table model, or declare MetricsList's id composite `[Metric, Labels]`.
  - DW-2327: audit the 48 two-argument `%GetNext` sites. Fix those reading caller-controlled JSON, which answer 500 on an oversized string or number (18.34's three-argument fix answers 422 or 400), or charter a sweep if many.

## UX & Interaction Patterns

- **Screens.** Every screen registers the screen contract with its suggested prompts. The side bar lists only built screens.
- **Strings.** New strings go in EXPERIENCE.md's Fixed strings, edited in place, with one `strings.ts` key per value. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- **Confirmations.** A person's destructive confirm names the action and target, states the consequence, and requires the typed name. An agent's destructive card takes the destructive treatment.
- **Guardrails (18.12, DW-1756).** The page is read-only and open to every signed-in user (EXPERIENCE.md :583). The turns-an-hour limit (AD-41: none by default, set on Switches, refused `TURN.LIMITHOUR`) has its strings at :281.
- **Auto-refresh (AD-43).** One shared framework, paused while a proposal is live. A screen joins only by declaring it and appearing in EXPERIENCE.md's roster of thirteen (:896); every default except Home's is off. A sensor-baseline reader never auto-refreshes.
- **Log viewers (18.38).** Today a log viewer loads bounded pages with "Load newer" and nothing streams ("Tail, not live", :899; component and state rows :646 and :848). 18.38 amends those lines in place at its spec gate, and the "nothing streams" pins in `log-viewer.spec.ts` and `Test/Descriptor.cls` are re-scoped to the sources that do not opt in.

## Cross-Story Dependencies

- **Run order:** 18.36 (implement next), 18.12, 18.13, 18.37, 18.38, then the burn-down, then the epic close.
- **18.36.** Its edits to `ReadTool` :93 and :94 are token edits in an Epic 20 file and need the orchestrator's pre-authorization, as 18.11's did. Read-tool and navigation rosters are unioned at merges.
- **18.12.**
  - It consumes every Stage 2 tool, including 18.11's metrics read and 18.36's four reads.
  - It extends 20.24's listing cache and answers the lists 18.31's and 18.33's tools take whole (DW-2321).
  - 20.12 (backlog) also touches the tool registry; whichever merges second rebases on the first.
- **18.13.** Epic 20's 20.1 (namespace category gating, which reads per-namespace state) has merged, so 18.13 rebases on it. Install runs only on a throwaway; never `docker compose up` against the live container.
- **18.37** runs after 18.13, and **18.38** after 18.37.
- **18.39.**
  - It fixes DW-2311 against 18.32's `MgmntPort`, and DW-2320 and DW-2322 against 18.33's classifier.
  - Epic 20 holds `Prohibited.cls` and `Screen/Tool/Write.cls`; a non-add-only edit to either needs the orchestrator's pre-authorization. DW-2299 waits for Epic 20's merge.
- **Epic 20** still runs on slot B (20.5 in progress) and edits the same shared files: `Prohibited`, the tool registry, `Error.cls`, `Router.cls`, the governance baseline, the test rosters, `strings.ts`, EXPERIENCE.md, `angular.json` and the spine.
  - Edits are add-only and unioned at merges.
  - Count-pinning rosters (entity types, `ClassicPageGate`, `ReadTool`) are token-merged at each forward merge and re-run fresh.
  - If `angular.json` collides, re-measure the merged bundle.
- **The epic close.** No story covers the WQM categories row (SA-05) or the row that enables the mirror service (SA-22); the close assigns or declines each. At Epic 18's merge, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
