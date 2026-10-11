# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool and confirmed single-write tools. This is the first versioned IPM release after the contest. Done: 18.1 to 18.10 and 18.14 to 18.30 (18.27 closed unbuilt). 18.31 is in review. Still to build: spec-based REST service writes (18.32, then the person's create in 18.34), privileged routine application roles and routines (18.33), the monitoring extras and live tail (18.11), the agent's growth (18.12), multi-namespace install (18.13), and the burn-down (18.35).

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
- Story 18.35: The burn-down at the epic's close (in the run order; not yet in the epics file)

## Requirements & Constraints

- **One contract (FR-80).** Each screen is one descriptor over one port. Its read tool, and its write tools' field lists, derive from that descriptor. Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Acceptance is that contract plus each row's backing route; anything finer is authored when the story is picked up.
- **Governance.** Every destructive or disruptive action is absent from the baseline, so its key ships `false`. A story that adds a write key adds its baseline entry.
- **Observe before building.** Measure each route's payload, effects, required privileges and audit events on a throwaway before any form or tool exists. Take privileges from the instance, never from the specification; the two disagree. The API floor admits any `%Admin_*`, `%Development:USE` or `%Ens_Portal:USE` holder, but no surface is gated on the floor alone.
- **Async.** Async operations go through `AdminPort`'s async path, and no slice writes its own polling. Read a finished task's result exactly once: a second read logs a severity-2 alert and turns the instance to Warning. Two views of one task share one poller.
- **Secrets are write-only.** They are never read back, logged, kept in a proposal or queued. Anything only a restart would clear runs through a test seam.
- **Budgets.** Bundle: `maximumWarning` 3326kB (about 3.23 MB at 18.30's merge); `maximumError` 4000kB. Fixed strings: the bound is 3400, raised only once the count is within 50 of it.
- **Ledger items still owned here** (address each, or decline it with a reason):
  - 18.33: DW-2279 (a per-tool noun for `MappingMint`'s empty-namespace refusal, for the Doc DB tools). It is buildable now, because 20.3's `MappingMint` change is on the branch.
  - 18.12: DW-1756 (the Guardrails page lacks Story 14.6's turns-per-hour setting).
  - 18.13: DW-219 (uninstall's three half-state paths), DW-423 (`Kernel.State.Stamp` keeps one row per run with no retention), DW-1333 (IPM's exporter drops `<SystemRequirements>`) and DW-2172 (detect a SQL grant on OcuPilot's schemas widened outside OcuPilot, beside install's schema-grant read-back).
  - 18.35: DW-1896, DW-2160 and DW-2167 (re-owned), plus the decided DW-1966, DW-1979, DW-1981, DW-2007, DW-2085, DW-2086, DW-2087, DW-2100, DW-2126 and DW-2149. Vendor-defect candidates on owner hold (DW-2280, DW-2283, DW-2284 among them) stay unreported and are never built on.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort` names `%Api.Admin.*`. It reads the outcome from both `tSC` and `%response.Status`. A vendor 404 is an absence and is not logged. Any other failure outside `UNLOGGEDREFUSALS` is logged at severity 2 and raises the instance's alert state, so a predictable vendor refusal is refused before the call. Two type checks run before the vendor and log nothing:
  - a `Security.PrivilegedRoutine` call naming a non-routine application answers 404 or 409 `PRIVROUTINE.TYPE`;
  - a `WebApp.App` `PUT` or `DELETE` naming a routine application answers 409 `PRIVROUTINE.WEBAPP`.
- **Write kinds.**
  - A merge (AD-4) reads fresh and sends the complete set. Its exceptions are named in AD-4.
  - A create (AD-54) fingerprints the name's absence, since admin `PUT`s are often upserts. A create whose id rule folds case sends the name as typed (`TypedId`).
  - An action (AD-51) fingerprints its preconditions.
  - A declared port may sequence several calls for one write (AD-52).
  - Screen and agent are two callers of one tool (AD-53, AD-55), under the per-target lock (AD-34). Every write has a read-back (AD-58), a copy-out snippet (AD-59) and a change event (AD-14).
  - A write the vendor does not audit is a named gap (AD-15, AD-53).
- **Ids, fields, reads.**
  - Each entity type has its own canonical-id rule (AD-13). `routine-application` is the name, `foldcase`.
  - Fields derive from the endpoint's body template into generated, checked-in artifacts, and an unclassified field is emitted secret (AD-3).
  - One declared read serves both screen and tool, with at most one per-row detail call (AD-36).
- **Pairs and classic pages (AD-8, AD-44, AD-64).**
  - A screen declares the classic page it replaces. Its privileges are the admin API's requirement plus any custom resource on that page.
  - `CLASSICPAGES` lists the extra classic pages a write performs. A routine application's create and update declare `%CSP.UI.Portal.Applications.PrivRoutine`; its delete declares none.
  - `ResourcesOR()` is only a lower bound. Measure a least-privileged principal.
- **Paths and reads.** No endpoint accepts a caller's path, outside AD-21's named cases. A write that would queue is refused unless `QUEUEDWRITES` names it (AD-26). A read may write vendor state only in AD-7's six shapes. OcuPilot never calls the vendor's alerts read.
- **Self-protection (AD-10).** Predicates live once in the kernel and are evaluated inside the confirm's atomic transition. Every write to `OcuPilotState` or `OcuPilotIdentity`, on every path, is refused `PROHIBITED.OCUPILOTROUTINEAPP`. Granting `%All` or an `%Admin_*` privilege is permitted at the destructive treatment, naming the privilege. OcuPilot's own code, including new names under its packages, is refused `PROHIBITED.OCUPILOTCODE`.
- **Text.** Vendor text is logged and never sent (AD-39). Each refusal sentence is written once, in Fixed strings (AD-53). Each new pair, predicate, entity type, named case or `CLASSICPAGES` entry goes into the spine at the spec gate.
- **18.33** extends 18.31's tools, form and rules. Its plan is seeded from 18.31's first plan (`18436f8d`). Measured:
  - `GET` answers `MatchRoles[{MatchRole, TargetRoles[]}]` and `Routines[{RoutineOrClass, Db, Type}]`.
  - `PUT` always sets `Routines` (an omitted list empties them), and a sent `MatchRoles` replaces the list. Send complete sets.
  - An absent target role answers 500 #879, so validate first. An absent `Resource`, `Db` or routine is stored as given.
  - No `Type` answers 400 #40301.
  - `%DB_HSCUSTOM:R` reads `Config.Databases`, the source of the Routines tab's database list.
- **18.32 (split A).** It keeps `MgmntPort`'s first writes, the agent's create, either caller's delete, the AD-10 arm, the keys, `RestServiceError` and the AD-53 amendment (ruling Q2 (B)). The create is agent-only until 18.34. Rules:
  - The agent's create is held to 20.21's rules at the mint and again at Confirm. Generated classes go only into the namespace's own routines database, never `%SYS`, a `%` name or `OcuPilot*`.
  - Extend `ExplorerSave`'s `AgentProblem`, `ConfirmProblem` and `CodeWritePairs` rather than copying them.
  - The card shows the whole document, at most 30,000 characters.
  - The create's key ships enabled. The delete is destructive, ships `false`, and refuses a service a web application dispatches to.

  Measured:

  - `POST /api/mgmnt/v2/:ns/:app` is an upsert (201, then 200) that generates `.spec`, `.disp` and `.impl`. A re-create keeps an existing `.impl`'s code.
  - `DELETE` keeps `.impl` and answers 200 for an absent service.
  - Presence ignores case (#5092).
  - Only OpenAPI 2.0 is accepted: a 3.0 document, or an undeclared path parameter (#8711), answers 404 and leaves no class.
  - A `%` name writes a `Protect` audit row, so refuse it first.
  - Neither write records a vendor event.
  - A non-object `swagger` is fetched as a URL or file, so pass a parsed object (an AD-21 case).
  - The writes need `%Development:USE` plus WRITE on the routines database, which `MgmntPort`'s read pairs lack.
- **18.34** is the person's Create dialog over 18.32's port and rules: its Save route, page, dialog and store, Fixed strings and browser spec. The Save takes the per-target hold.
- **18.11.**
  - Each read has its own port and resource gate; the monitoring API's anonymous reachability never becomes OcuPilot's.
  - Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`), and each call rewrites the sensor baselines.
  - The drill-downs read the admin API's `/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources`. Drop `BusyProcesses`' empty rows.
  - Interoperability usage reads the deprecated InteropMetrics v1.
  - The live tail is a `%SYSTEM.Event` long-poll with a heartbeat (the sibling's ChangesHandler pattern).
- **18.12.**
  - Every Stage 2 screen brings a read tool and a confirmed single-write tool with no hand-written tool code.
  - License key activation, `security.secrets.replacesymmetric` and `explorer.sqldata.save` stay unadvertised (AD-53).
  - AD-24 already sends earlier turns as their user message and final reply only, capped at 65,536 characters with the oldest dropped first.
  - A proxy is a destination judged by the egress policy, and an https call tunnels through it (AD-42).
  - `PROHIBITED.OCUPILOTSSL` keeps the provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled`.
  - OcuPilot deletes only credential entries it created (AD-37).
- **18.13.**
  - One idempotent installer runs at container start or from IPM's `<Invoke>`. Only the container path unexpires `_SYSTEM` (AD-17).
  - IPM is never a runtime dependency (AD-18).
  - Code lives in the install namespace's routines database, and state in OcuPilot's protected database (AD-9).
  - The unauthenticated applications' role reads exactly that namespace's routines and default globals databases (AD-21).
  - The install-namespace arms (`OCUPILOTNAMESPACE`, `OCUPILOTMAPPING`, `OCUPILOTDATABASE`) read, at the write, the namespace the API runs in.
  - Install reads back its schema grant (AD-38).

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract, including three suggested prompts. The side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, edited in place, with one `strings.ts` key per value citing its line. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. A person's destructive confirm names the action and the target, states the consequence and requires the name typed. An agent's destructive card takes the destructive treatment with no typed name.
- Editors are form pages with tabs in the classic order, a sticky Save and Cancel bar and an unsaved-changes guard. Gated controls stay focusable and `aria-disabled`, giving their reason through `aria-describedby`.
- Log viewers load bounded pages; the live tail supersedes that only for the sources that opt in. Auto-refresh uses AD-43's shared framework.

## Cross-Story Dependencies

- **Run order:** 18.31 (review), re-plan 18.32 to split A, then 18.33, 18.34, 18.11, 18.12, 18.13 and 18.35, then the epic close.
- 18.33 follows 18.31. 18.34 follows 18.32. 18.32 reuses 20.21's code-write checks and 20.20's whole-document card, both on feature. 18.34 follows 19.17's create dialog and Save.
- 18.12 consumes every Stage 2 tool, including 18.24's wallet tools, 18.10's `webapp.pctaccess.*` and 18.31 to 18.34's tools. 20.12 (guided workflows, backlog) also grows the agent (inference). 18.13 touches 20.1's namespace category gating (inference).
- Epic 20 on slot B (20.22 next) edits the same shared files: the kernel's `Prohibited`, the registry, `Error.cls`, `Router.cls`, the governance baseline, test rosters, `strings.ts`, EXPERIENCE.md and the spine. Edits are add-only and are unioned at merges.
- No story covers the catalog rows WQM categories (SA-05) and enabling the mirror service (SA-22). The epic close assigns or declines each.
- At Epic 18's merge, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
