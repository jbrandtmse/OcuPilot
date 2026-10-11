# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool and confirmed single-write tools. This is the first versioned IPM release after the contest. Done: 18.1 to 18.10 and 18.14 to 18.33 (18.27 closed unbuilt). Still to build, in run order:

- the person's REST service create (18.34, ready for dev);
- the Prometheus metrics table (18.11, narrowed);
- the dashboard drill-downs (18.36);
- the agent's growth over the whole stage (18.12);
- multi-namespace install (18.13);
- interoperability usage (18.37);
- the live log tail (18.38);
- the epic-close burn-down, chartered one past the highest story (18.39 if nothing else is added).

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
  - Take privileges from the instance, never from the specification, and measure as a least-privileged principal.
  - Never build on a `decision-pending` ledger entry.
- **Async and secrets.**
  - Async operations go through `AdminPort`'s async path; no slice polls on its own.
  - A finished task's result is read once, by the port's one poller. A queued write still running at the bound answers as started.
  - Secrets are write-only: never read back, logged, kept in a proposal or queued.
- **Budgets.**
  - Bundle: the warning budget is 3326kB and the error budget 4000kB. The latest heads measured 3.29 to 3.31 MB.
  - Fixed strings: the bound is 3400 and about 3,130 are used (computed). The bound is raised only once the count is within 50 of it.
  - `Api/Error.cls` holds 989 of the 1,000 parameters a class may carry. New error codes go in a sibling class modeled on `Api/RestServiceError.cls`.
  - The feature branch carries 70 entity types.
- **Rows still to build.**
  - A raw Prometheus exposition rendered as a table.
  - The dashboard's three drill-down statistics: globals and routines, ECP, and system resources. The catalog never captured their meter names or thresholds.
  - Interoperability usage (current and historical interfaces, volume and database impact).
  - A live tail of text logs.
- **Ledger items owned here.** Address each, or decline it with a reason.
  - **18.11.**
    - DW-1872: a database-volumes read without `dir` reaches the vendor, whose 400 is logged at severity 2 and raises the monitor state. Refuse it before the admin call, as the sibling reads do.
    - DW-1898: `AdminPort.AwaitTask` logs the bound before the caller answers a queued write as started, which raises the alert state. The port must not log a bound it converts to started; a read that reaches the bound still logs.
  - **18.12.**
    - DW-1756: the Guardrails page lacks the turns-per-hour setting.
    - DW-1084: the built-in system prompt never asks the model to name rows in backticks or to offer to select them.
    - DW-2321: the update tools take `MatchRoles` and `Routines` whole, but no read tool answers either list. Expose both to the agent, as a read field or a detail read, for web applications and for privileged routine applications.
  - **18.13.**
    - DW-219: uninstall's three half-state paths on an instance OcuPilot does not wholly own (an owner-delegated decision).
    - DW-423: say what `Stamp` keeps and what prunes it.
    - DW-1333: IPM drops `<SystemRequirements>`.
    - DW-2172: detect a SQL grant on OcuPilot's schemas that was widened outside OcuPilot (to another role or `_PUBLIC`), beside install's schema-grant read-back.
  - **18.36, 18.37 and 18.38** own no ledger entries yet.
  - **Burn-down, fixes ruled by the orchestrator.**
    - DW-2311: the REST service delete's deployed check sees only same-namespace applications that dispatch to `<Name>.disp`. In `MgmntPort.Resolved`, walk each listed application's `UrlMap` `Forward` targets and read `GetWebRESTApps` over every namespace.
    - DW-2320: the `MatchRoles` grant classifier compares target names only. Key held and wanted targets by MatchRole and target, so moving a privileged target to another MatchRole, or to an empty one, counts as a grant.
    - DW-2322: clearing a privileged routine application's `Resource`, or enabling the application, while it grants a privileged role is a grant, because the vendor runs an application with no resource for anyone. It takes the existing privileged-grant treatment.
  - **Burn-down, decided.**
    - DW-1966: refuse an existing database's directory as a journal directory (AD-21).
    - DW-2007: the code-scoped #1454 joins AD-2's unlogged list.
    - DW-2086: carry the reviewed key list through an activation's fingerprint.
    - DW-2299: lift the delete tools' `StateDiff` into `Screen/Tool/Write.cls` after Epic 20 merges.
    - DW-1896: measure `Security.LDAPConfigs.Modify` in `%SYS`. Build it only under the caller's own `%Admin_Secure`; otherwise the entry is wontfix-accepted.
  - **Burn-down, also owned.**
    - DW-2100 (high): measure on a throwaway first, then decide AD-10's start arm.
    - DW-2085: offer Encrypt database on create while a database key is active.
    - DW-2087: a first key activation's start-mode change outlives deactivation.
    - DW-2126: name a stored certificate's loss when an RSA key is replaced.
    - DW-1979: the journal records' newest-first order. DW-1981: input lengths on the journal records' offset and value fields.
    - DW-2149: the probe snapshots read `Monitor.State`.
    - DW-2160: apply 23.4's poll to `AuditVendorSecrets.AssertMasked` and its siblings.
    - DW-2167: map #822 to an access refusal, not an absence.
  - **Not here.**
    - The CI flakes DW-2111 and DW-2123 go to the next epic burn-down gate.
    - The vendor-defect candidates on owner hold stay unreported and are never built on. Examples are DW-2283, DW-2284 and DW-2309.

## Technical Decisions

- **Containment (AD-2, AD-27).**
  - Only `AdminPort` names `%Api.Admin.*`. It reads the outcome from both `tSC` and `%response.Status`.
  - A read answered 404 is an absence and is not logged. Any other failure outside `UNLOGGEDREFUSALS` is logged and raises the instance's alert state, so refuse a predictable vendor refusal before the call.
- **Write kinds.**
  - A merge reads fresh and sends the complete set (AD-4). A privileged routine application's `PUT` replaces a sent `MatchRoles` and empties an omitted `Routines`, so every update sends both lists.
  - A create fingerprints the name's absence (AD-54). An action fingerprints its preconditions (AD-51), and a declared port may sequence calls (AD-52).
  - The screen and the agent are two callers of one operation (AD-53, AD-55), under the per-target lock (AD-34), with a read-back (AD-58), a copy-out (AD-59) and a change event (AD-14).
  - A write the vendor does not audit is a named gap (AD-15, AD-53).
- **Ids, fields and pairs.**
  - Each entity type has its own canonical-id rule (AD-13).
  - Field lists derive from body templates, and an unclassified field is treated as secret (AD-3).
  - One read serves both the screen and the tool (AD-36).
  - A screen's pairs are the admin API's, plus any custom resource on every classic page it replaces (AD-8, AD-44, AD-64). `ResourcesOR()` is only a lower bound (AD-29).
- **Tool listing (AD-5).**
  - `ListTools` caches the listing per process and rebuilds it when the `OcuPilot.` compile signature changes.
  - Only compile-time declarations decide whether a tool is listed. A setting, grant, adjustment or policy is read on every call and never enters the listing.
  - Extend this cache; do not bypass it.
- **Self-protection (AD-10).**
  - Predicates are stated over the effect, never over the payload. They are evaluated inside the confirm's atomic transition, whichever caller confirms.
  - The arms in play are `OCUPILOTROUTINEAPP`, `OCUPILOTCODE`, `OCUPILOTNAMESPACE`, `OCUPILOTDATABASE`, `OCUPILOTSQLPRIVILEGE`, `OCUPILOTSSL` and the start arms.
  - Granting `%All` or an `%Admin_*` privilege is permitted at the destructive treatment that names the privilege. That covers a grant through a role, an application role, or a routine added while a `MatchRoles` target grants one.
- **Text.**
  - Vendor text is logged, never sent (AD-39).
  - Each refusal sentence is written once, in Fixed strings.
  - New pairs, predicates, entity types, named cases and `CLASSICPAGES` entries go into the spine at the spec gate.
- **18.34 (AD-53).**
  - The person's create (`POST /rest-service`) goes through 18.32's `MgmntPort`.
  - It meets the port's rules: the name and document rules, a parsed document only, and the taken-name check (listed in any case, or an unlisted `.spec`/`.disp` class held). It also meets AD-10's `OcuPilot*` refusal.
  - It requires `%Development:USE` and WRITE on the namespace's routines database, under AD-34's hold.
  - It never runs the agent's routines-database check or the card's 30,000-character width. A person may therefore build where the agent is refused, and a test pins that difference.
  - It is named gap twenty-two.
- **Monitoring reads (18.11, 18.36, 18.37).**
  - Each read has its own port and resource gate (AD-29). A metric reaches a user through OcuPilot only if that user could have read it directly. The monitoring API's anonymous reachability never becomes OcuPilot's.
  - Only `MonitorPort` calls `SYS.Monitor.SAM.Sensors.PrometheusMetrics()`. It is gated on `%Admin_Operate:USE` plus `%DB_IRISSYS:READ`, and 18.11 adds a `monitor` read source kind behind that pair set.
  - Each call rewrites 24 sensor-baseline nodes, which shortens an external scraper's intervals. This is one of AD-7's six named vendor-internal write shapes. A new shape, such as a sensor setter, needs a spine amendment at its spec gate.
  - Never call the vendor's alerts read (`/api/monitor/alerts`): it advances the shared `LastAlertSent` cursor.
- **18.36.**
  - It reads the admin API's three `/v2/monitor/dashboard/*` drill-down routes. It is read-only, and its Task 0 reads their request types.
  - In `GET /v2/monitor/dashboard/main`, `SystemUsage.BusyProcesses` always has ten rows, and unused rows are `{"Process": "", "Commands": 0}`. Drop them before showing a top ten.
- **18.37.**
  - The catalog's source is the deprecated `%Api.InteropMetrics.v1` (`/api/monitor/interop`), which escalates without checking the caller.
  - AD-8 allows no elevation except AD-9's. A vendor method that runs under its own service account after checking the caller's privilege is the vendor's model, not an elevation.
  - The spec gate prefers a source that keeps AD-8 as written, such as the classic page's query if it checks the caller. An option that needs AD-8 relaxed is the owner's call, raised through the Planner.
  - The spec gate also settles whether the sensor setters write state (AD-7).
- **18.38.**
  - The live tail is a `%SYSTEM.Event` long-poll with a heartbeat flush between waits (the iris-couch ChangesHandler pattern), on an endpoint of OcuPilot's own, over `messages.log` and `alerts.log`.
  - A source opts in through a descriptor key (AD-5).
  - AD-12 lets only the response writer write to the device; the static handler is its one carve-out. The heartbeat bytes need a second carve-out, and AD-43 needs an amendment. Both are tier-1 amendments at 18.38's spec gate.
  - No endpoint accepts a path: a log is named from a fixed enum (AD-21).
- **18.12.**
  - Every Stage 2 screen brings its read and confirmed write tools with no hand-written tool code. Unadvertised tools stay unadvertised (AD-53).
  - AD-24 already bounds context at 200 rows by default, 65,536 characters in total and 1,000 characters a field.
  - Earlier turns replay only as their user message and final reply, capped at 65,536 characters with the oldest dropped first. Earlier tool results and screen context are never replayed.
  - Budget history on top of these bounds; do not replace them.
  - A proxy is a destination that the egress policy judges. An https call tunnels through it, and a marked-local endpoint bypasses it (AD-42). Outbound TLS is configured at install, never defaulted (AD-32).
  - A wallet-backed rung joins the credential ladder, which never returns a value into a status or an error (AD-42, AD-35).
- **18.13.**
  - One idempotent installer runs from the container start or from IPM's `<Invoke>`. Only the container path unexpires `_SYSTEM` (AD-17). IPM is never a runtime dependency (AD-18).
  - Code lives in the install namespace's database, and state lives in OcuPilot's protected database (AD-9).
  - An unauthenticated application carries exactly one purpose-built role (AD-21).
  - Install reads back its schema grant, and the gate reports `unreadable` when it cannot read its own state (AD-38).
  - The retention sweep touches only what OcuPilot created (AD-37).
- **Burn-down.**
  - `Kernel/Proposal/Prohibited.cls` and `Screen/Tool/Write.cls` belong to Epic 20 while it runs.
  - DW-2320's non-add-only edit to `Prohibited.cls` needs the orchestrator's pre-authorization, as 18.32's two edits had. DW-2322's classifier, `GrantsPrivilegeByEffect`, is in the same file.
  - DW-2299 waits for Epic 20's merge.

## UX & Interaction Patterns

- **Screens.** Every screen registers the screen contract, including three suggested prompts. The side bar lists only built screens.
- **Strings.** New strings go in EXPERIENCE.md's Fixed strings, edited in place, with one `strings.ts` key per value. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- **Dialogs.**
  - Dialogs come from the closed set and never stack.
  - A person's destructive confirm names the action and target, states the consequence and requires the typed name.
  - An agent's destructive card takes the destructive treatment, with no typed name.
- **Editors.** Editors are tabbed form pages in the classic order, with a sticky Save/Cancel bar and an unsaved-changes guard. Gated controls stay focusable and `aria-disabled`, with their reason.
- **Meters.** A meter shows label, value and unit, with the dashboard's state as a word in its color. It shows "—" over a skeleton until a value arrives, and its needle never animates.
- **Auto-refresh.** It uses AD-43's shared framework and pauses while a proposal is live. A screen joins only by declaring it in its descriptor and appearing in EXPERIENCE.md's roster of thirteen; every screen's default except Home's is off.
- **Log viewers.**
  - Today a log viewer loads bounded pages with "Load newer", and nothing streams.
  - 18.38 amends EXPERIENCE.md's "Tail, not live" rule and the log-viewer component and state rows at its spec gate.
  - The "nothing streams" pins are re-scoped to the sources that do not opt in.

## Cross-Story Dependencies

- **Run order:** 18.34, 18.11, 18.36, 18.12, 18.13, 18.37, 18.38, then the burn-down, then the epic close.
- **18.34** consumes 18.32's port and create tool and does not edit `Port/MgmntPort.cls`.
- **18.36** runs after 18.11.
- **18.37 and 18.38.** 18.37 runs after 18.13, and 18.38 runs after 18.37. 18.11's spec Code Map keeps the live tail's anchors (its slice 4) to seed 18.38.
- **18.12** consumes every Stage 2 tool, from 18.24's wallet tools through 18.34's. It extends 20.24's tool-listing cache and exposes the lists that 18.31's and 18.33's tools take whole (DW-2321).
- **The burn-down** takes DW-2311 against 18.32's `MgmntPort`, and DW-2320 and DW-2322 against 18.33's classifier.
- **Epic 20** still runs on slot B and edits the same shared files: the kernel's `Prohibited`, the registry, `Error.cls`, `Router.cls`, the governance baseline, test rosters, `strings.ts`, EXPERIENCE.md and the spine.
  - Edits are add-only and are unioned at merges.
  - Rosters that pin counts (entity types, `ClassicPageGate`, `ReadTool`) are token-merged at each forward merge and re-run fresh.
- **Unassigned rows.** No story in the epics file covers the WQM categories row (SA-05) or the row that enables the mirror service (SA-22). The epic close assigns or declines each.
- **At Epic 18's merge**, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
