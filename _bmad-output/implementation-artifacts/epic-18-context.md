# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool and, where it writes, confirmed single-write tools. This is the first versioned IPM release after the contest. Done: 18.1 to 18.10 and 18.14 to 18.34 (18.27 closed unbuilt). Story 18.11 is planned and ready for implementation. It is narrowed to the Prometheus metrics table, DW-1872 and DW-1898. The rest, in run order, is 18.36 (the dashboard drill-downs), 18.12 (the agent grows with the stage), 18.13 (multi-namespace install), 18.37 (interoperability usage), 18.38 (the live log tail), and then the Epic 18 burn-down, chartered as 18.39.

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
- Story 18.11: Monitoring extras and the live log tail (narrowed to the Prometheus metrics table)
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
- Story 18.35: retired unused (it was the burn-down's provisional number)
- Story 18.36: Dashboard drill-downs
- Story 18.37: Interoperability usage
- Story 18.38: The live log tail
- Story 18.39: The Epic 18 burn-down (chartered at the burn-down gate; not yet in the epics file)

## Requirements & Constraints

- **One contract (FR-80).**
  - Each screen is one descriptor over one port. Its read tool, and its write tools' field lists, derive from that descriptor.
  - Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation.
  - Every gate checks the caller's own privileges at call time.
  - Acceptance is that contract plus each row's backing route. Anything finer is authored when the story is picked up.
- **Governance.** Every destructive or disruptive key ships `false`. A story that adds a write key adds its baseline entry.
- **Observe first.**
  - Measure each route's payload, effects, privileges and audit events on a throwaway before any form or tool exists.
  - Take privileges from the instance, never from the specification. Measure them as a least-privileged principal.
  - Never build on a `decision-pending` ledger entry.
- **Budgets.**
  - Bundle: the warning budget is 3487kB, and the error budget is 4000kB. The warning was re-based at 18.34 to 5% above the measured 3,320,521-byte initial total, under DW-1166. If Epic 20's `angular.json` collides, re-measure the merged tree and set the warning 5% above it. Stop and ask above 3800kB.
  - Fixed strings: 3,134 of the 3,400 bound were used at 18.34, and 18.11 adds eight. Stop past 3,350.
  - `Api/Error.cls` holds 989 of the 1,000 parameters a class may carry. New codes go in a sibling `*Error.cls`, such as `RestServiceError.cls`, with their prefix arms in `Error`'s reason mappers.
  - Entity types: 70. Read tools: 351 once 18.11 lands.
- **Ledger by story.** Address each item, or decline it with a reason.
  - **18.11.**
    - DW-1872: a parent-scoped `VOLUMELIST` read with no `dir` is refused before the vendor call.
    - DW-1898: a queued write still running at the bound logs nothing.
  - **18.12.**
    - DW-1756: the Guardrails page lacks the turns-per-hour setting.
    - DW-1084: the built-in system prompt never asks the model to name rows in backticks or to offer to select them.
    - DW-2321: the update tools take `MatchRoles` and `Routines` whole, but no read tool answers either list. Expose both to the agent, as a read field or a detail read, for web applications and for privileged routine applications.
  - **18.13.**
    - DW-219: uninstall's three half-state paths on an instance OcuPilot does not wholly own.
    - DW-423: `Stamp` keeps one row per install run with no retention.
    - DW-1333: IPM's exporter drops `<SystemRequirements>`.
    - DW-2172: detect a SQL grant on OcuPilot's schemas that was widened outside OcuPilot (to another role or `_PUBLIC`), beside install's schema-grant read-back.
  - **18.36, 18.37 and 18.38** own no ledger entries yet.
  - **The burn-down fixes three items, by orchestrator ruling.**
    - DW-2311: the REST service delete's deployed check sees only same-namespace applications that dispatch to `<Name>.disp`. In `MgmntPort.Resolved`, walk each listed application's `UrlMap` `Forward` targets, and read `GetWebRESTApps` over every namespace.
    - DW-2320: the `MatchRoles` grant classifier compares target names only. Key the held and wanted targets by MatchRole and target, so that moving a privileged target to another MatchRole, or to an empty one, counts as a grant.
    - DW-2322: clearing a privileged routine application's `Resource`, or enabling it, while it grants a privileged role is a grant. The vendor runs an application with no resource for anyone. It takes the existing privileged-grant treatment.
  - **The burn-down also owns these.**
    - DW-1896: measure `Security.LDAPConfigs.Modify` in `%SYS`. Build it only under the caller's own `%Admin_Secure`; otherwise the entry is wontfix-accepted.
    - DW-2167: the vendor's #822 must answer as an access refusal, not an absence.
    - DW-2160: apply 23.4's poll to `AuditVendorSecrets.AssertMasked` and its siblings.
    - DW-1966: refuse an existing database's directory as a journal directory.
    - DW-2007: the vendor's #1454 joins AD-2's unlogged list.
    - DW-2086: carry the reviewed key list through an activation's fingerprint.
    - DW-2085: offer Encrypt database on create while a database key is active.
    - DW-2087: a first key activation's start-mode change outlives deactivation.
    - DW-2126: name a stored certificate's loss when an RSA key is replaced.
    - DW-2100 (high): measure on a throwaway first, then decide AD-10's start arm.
    - DW-1979 and DW-1981: the journal records' order, and the input lengths of their offset and value fields.
    - DW-2149: the probe snapshots read `Monitor.State`.
    - DW-2299: lift the delete tools' `StateDiff` into `Screen/Tool/Write.cls`, after Epic 20 merges.
  - **Not Epic 18's.**
    - The CI flakes DW-2111 and DW-2123 go to the next epic burn-down gate.
    - Burn-down entries that came from Epic 20's stories (for example DW-2253, DW-2301 and DW-2225) belong to Epic 20's burn-down.
    - The vendor-defect candidates on owner hold stay unreported and are never built on. Examples are DW-2283, DW-2284 and DW-2309.

## Technical Decisions

- **Containment (AD-2, AD-27).**
  - Only `AdminPort` names `%Api.Admin.*`. It reads the outcome from both `tSC` and `%response.Status`.
  - A read answered 404 is an absence and is not logged.
  - Any other failure outside the unlogged list is logged and raises the instance's alert state. So refuse a predictable vendor refusal before the call.
  - A finished async task is read once, by the port's one poller (AD-26). A queued write still running at the bound answers as started and logs nothing; a read that reaches the bound still logs.
- **Gates (AD-8, AD-29).**
  - There is no service account. The only OcuPilot elevation is AD-9's.
  - A vendor method that checks the caller and then runs as its own account is the vendor's model, not an elevation.
  - Each port carries its own gate. `ResourcesOR()` is a lower bound only: read the backing class's own check, then run as a real least-privileged principal on a throwaway.
  - The monitoring API's anonymous reachability never becomes OcuPilot's.
  - Only `MonitorPort` calls `SYS.Monitor.SAM.Sensors.PrometheusMetrics()`, behind `%Admin_Operate:USE` plus `%DB_IRISSYS:READ`. It has three ways in: Home's row, the Dashboard's CPU, and 18.11's table.
- **Vendor-internal writes (AD-7).**
  - The turn never mutates the instance. AD-7 names exactly six vendor-internal write shapes, among them the sensor baseline: each metrics call rewrites 24 `^IRIS.Temp.SAM` nodes and shortens an external scraper's intervals. Any new shape needs a spine amendment at its spec gate.
  - Never call the alerts read (`/api/monitor/alerts`), which advances `LastAlertSent`.
- **Read contract (AD-36, AD-24).**
  - One read serves both the screen and the tool.
  - 18.11 adds the `monitor` source kind (`MonitorPort` `Metrics`/`LIST`, cut at the cap plus one).
  - A parent-scoped read requires its criterion before any port call.
  - Bounds: 200 rows by default (an operator sets 1 to 1,000), 65,536 characters in total, and 1,000 characters a field. The payload reports `rowsSent`, `rowsAvailable` and truncation.
- **Writes.**
  - A merge reads fresh and sends the complete body (AD-4).
  - A create fingerprints the target's absence (AD-54). An action fingerprints its preconditions (AD-51).
  - The screen and the agent are two callers of one tool (AD-53, AD-55), under the per-target hold (AD-34), with a read-back (AD-58) and a change event (AD-14).
  - A screen Save evaluates AD-10's prohibited set against the resolved target after the state read and before the port's write. The spine was corrected at 18.34.
- **Tool listing (AD-5, as of 20.24).**
  - `Screen.Tool.Registry.ListTools` caches the listing per process, keyed by namespace and registry class. It rebuilds the listing when the `OcuPilot.` compile signature changes.
  - Only compile-time declarations decide what is listed. A setting, grant, adjustment or policy is read on every call.
  - 20.24 reshaped `Registry.cls` (`BuildListing`, `CompileSignature`, `BuildCount`, `ForgetListing`), and Epic 18 was warned for 18.12. Extend the cache; do not bypass it.
- **Self-protection (AD-10).**
  - Predicates are stated over the effect and evaluated inside the confirm's atomic transition.
  - Granting `%All` or an `%Admin_*` privilege, through a role, an application role or a routine, is permitted at the destructive treatment that names the privilege (`GRANT.PRIVILEGED`).
  - On other web applications, "no authorization resource" is permitted at the strongest confirmation.
  - Every change to OcuPilot's own `OcuPilotState` and `OcuPilotIdentity` is refused (`PROHIBITED.OCUPILOTROUTINEAPP`).
- **Text and amendments.**
  - Vendor text is logged, never sent (AD-39). Each refusal sentence is written once, in Fixed strings.
  - New pairs, predicates, source kinds, vendor-write shapes and carve-outs are amended into the spine at the spec gate (Rule 20).
- **18.36, the drill-downs.**
  - The admin API's `GET /v2/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources` routes are read only.
  - The repository does not record their request types: only the main panel's type is among `AdminPort`'s bare types. Task 0 reads them on a throwaway.
  - The catalog never captured their meter names or thresholds.
  - `SystemUsage.BusyProcesses` in `/dashboard/main` always has ten rows, and the unused ones are `{"Process": "", "Commands": 0}`. Drop them.
- **18.12, the agent's growth.**
  - Every Stage 2 screen brings its tools with no hand-written tool code. Unadvertised tools stay unadvertised (AD-53).
  - History budgeting sits on top of AD-24: earlier turns replay only as their user message and final reply, capped at 65,536 characters with the oldest dropped first, and tool results and screen context are never replayed.
  - A proxy is a destination the egress policy judges. An https call tunnels through it, and a marked-local endpoint bypasses it (AD-42).
  - Outbound TLS uses the named configuration the installer creates (AD-32).
  - A wallet-backed rung joins the credential ladder, which never returns a value into a status or an error.
- **18.13, multi-namespace install.**
  - One idempotent `Installer` runs from the container start or from IPM's `<Invoke>`. Only the container path unexpires `_SYSTEM` (AD-17). IPM is never a runtime dependency (AD-18).
  - Code lives in the install namespace's database, and state lives behind OcuPilot's protected resource (AD-9).
  - An unauthenticated application carries exactly one purpose-built application role, read-only on the install namespace's routines and default globals databases (AD-21).
  - Install reads back its schema grant, and the gate answers `unreadable` when it cannot read its own state (AD-38).
  - OcuPilot deletes only what it created, and its retention sweep acts on its own state (AD-37).
- **18.37, interoperability usage.**
  - The classic page (`%CSP.UI.Portal.InteroperabilityUsage`, `%Admin_Operate`) queries `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces`.
  - The deprecated `/api/monitor/interop` (`%Api.InteropMetrics.v1`) checks nothing. It reaches the `[Internal]` `%SYS.Ensemble.SetSAMSensorsForInterop*` methods, which escalate with `$$$AddAllRoleTemporaryInTry`.
  - The spec gate prefers a source that keeps AD-8 as written. Any AD-8 relaxation is the owner's call, raised through the Planner.
  - The gate also settles whether the sensor setters write state, which would be a new AD-7 shape.
  - A new port must also fit AD-62, which reaches interoperability through one port behind its own gate (inference).
- **18.38, the live tail.**
  - The sources are `messages.log` and `alerts.log`, the only ones with `LogSourcePort`'s offset-and-identity cursor. They opt in through a descriptor key (AD-5).
  - An OcuPilot route long-polls within `Kernel.Provider.TestCall.BoundSeconds`, re-checking the file's size and identity between waits, because no vendor event signals a log write. This is iris-couch's `ChangesHandler` pattern.
  - Rotation invalidates offsets, so the route restarts cleanly (AD-21).
  - AD-12 lets only the response writer write to the device; the static handler is its one carve-out. The heartbeat bytes need a second carve-out, and AD-43 needs an amendment. Both are tier-1 amendments at the spec gate.
  - No endpoint accepts a path. A log is named from a fixed enum.

## UX & Interaction Patterns

- **Screens.** Every screen registers the screen contract, with its suggested prompts. The side bar lists only built screens.
- **Strings.**
  - New strings go in EXPERIENCE.md's Fixed strings, edited in place, with one `strings.ts` key per value.
  - Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- **Confirmations.**
  - A person's destructive confirm names the action and the target, states the consequence, and requires the typed name.
  - An agent's destructive card takes the destructive treatment.
- **Meters.**
  - A meter shows label, value and unit, with the dashboard's state as a word in its color.
  - It shows "—" over a skeleton until a value arrives, and its needle never animates.
- **Auto-refresh (AD-43).**
  - Auto-refresh uses one shared framework and pauses while a proposal is live.
  - A screen joins only by declaring it in its descriptor and appearing in EXPERIENCE.md's roster of thirteen. Every screen's default except Home's is off.
  - A sensor-baseline reader never auto-refreshes; 18.11's note says why. A drill-down that refreshes needs the roster amended.
- **Log viewers.**
  - Today a log viewer loads bounded pages with "Load newer", and nothing streams: the "Tail, not live" rule (EXPERIENCE.md :899) and the log-viewer component and state rows (:646, :848).
  - 18.38 amends these in place at its spec gate. The "nothing streams" pins in `log-viewer.spec.ts` and `Test/Descriptor.cls` are re-scoped to the sources that do not opt in.

## Cross-Story Dependencies

- **Run order:** 18.11 (implement next), 18.36, 18.12, 18.13, 18.37, 18.38, then the burn-down, then the epic close.
- **18.11.**
  - Its Rule 11 test edits are pre-authorized: `ToolRoundTrip` :89 and :20-22, `InteropDescriptor` :98, and `ReadTool` :93, :94 and :112. Union their totals at merges.
  - Its earlier spec (commit d0d9daef) keeps the anchors for 18.36, 18.37 and 18.38 in slices 2 to 4.
- **18.36** runs after 18.11.
- **18.12**
  - It consumes every Stage 2 tool, 18.11's `osmgmt.metrics.read` and 18.36's reads included.
  - It extends 20.24's listing cache and exposes the lists that 18.31's and 18.33's tools take whole (DW-2321).
  - 20.12 also touches the tool registry. Whichever merges second rebases on the first.
- **18.13.** Epic 20's 20.1 also reads per-namespace state. Whichever merges second rebases on the first.
- **18.37** runs after 18.13, and **18.38** runs after 18.37.
- **The burn-down.**
  - It takes DW-2311 against 18.32's `MgmntPort`, and DW-2320 and DW-2322 against 18.33's classifier, `GrantsPrivilegeByEffect` in `Kernel/Proposal/Prohibited.cls`.
  - Epic 20 holds `Prohibited.cls` and `Screen/Tool/Write.cls`. A non-add-only edit to either needs the orchestrator's pre-authorization.
  - DW-2299 waits for Epic 20's merge.
- **Epic 20** still runs on slot B and edits the same shared files: `Prohibited`, the registry, `Error.cls`, `Router.cls`, the governance baseline, the test rosters, `strings.ts`, EXPERIENCE.md, `angular.json` and the spine.
  - Edits are add-only and are unioned at merges.
  - Rosters that pin counts (entity types, `ClassicPageGate`, `ReadTool`) are token-merged at each forward merge and re-run fresh.
- **The epic close.** No story covers the WQM categories row (SA-05) or the row that enables the mirror service (SA-22). The epic close assigns or declines each.
- **At Epic 18's merge,** DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
