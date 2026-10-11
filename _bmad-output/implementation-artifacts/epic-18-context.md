# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool and confirmed single-write tools. This is the first versioned IPM release after the contest. Done: 18.1 to 18.10 and 18.14 to 18.31 (18.27 closed unbuilt). Still to build: the spec-based REST service writes (18.32, ready for dev), privileged routine application roles and routines (18.33), the person's REST service create (18.34), the monitoring extras and live tail (18.11), the agent's growth (18.12), multi-namespace install (18.13), and the burn-down (18.35).

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
- **Governance.** Every destructive or disruptive key ships `false`. A story that adds a write key adds its baseline entry.
- **Observe first.** Measure each route's payload, effects, privileges and audit events on a throwaway before any form or tool exists. Take privileges from the instance, never from the specification, and measure a least-privileged principal.
- **Async and secrets.** Async operations go through `AdminPort`'s async path, with no polling of a slice's own. Read a finished task's result once: a second read raises the instance's alert state. Secrets are write-only: never read back, logged, kept in a proposal or queued.
- **Budgets.** The bundle sits near its 3326kB warning budget (about 3.27 MB at the last merge). The Fixed-strings bound is 3400, raised only once the count is within 50 of it.
- **Ledger items owned here** (address each, or decline it with a reason):
  - 18.11: DW-1872 (a database-volumes read without its `dir` reaches the vendor, which answers 400, logged at severity 2) and DW-1898 (`AwaitTask` logs its bound before a queued write answers as started).
  - 18.12: DW-1756 (the Guardrails page lacks the turns-per-hour setting) and DW-1084 (the system prompt never asks the model to name rows in backticks or offer to select them).
  - 18.13: DW-219, DW-423, DW-1333 and DW-2172 (uninstall's half-state paths, `Stamp` retention, IPM dropping `<SystemRequirements>`, and detecting a widened SQL grant on OcuPilot's schemas).
  - 18.33: DW-2279 (a per-tool noun for `MappingMint`'s empty-namespace refusal).
  - 18.35: DW-1896, DW-1966, DW-1979, DW-1981, DW-2007, DW-2085, DW-2086, DW-2087, DW-2100, DW-2126, DW-2149, DW-2160 and DW-2167. The CI flakes DW-2111 and DW-2123 go to the next epic burn-down gate. Vendor-defect candidates on owner hold stay unreported and are never built on.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort` names `%Api.Admin.*`, reading the outcome from both `tSC` and `%response.Status`. A read answered 404 is an absence and is not logged. Any other failure outside `UNLOGGEDREFUSALS` is logged and raises the instance's alert state, so refuse a predictable vendor refusal before the call. Privileged-routine type checks (`PRIVROUTINE.TYPE`, `PRIVROUTINE.WEBAPP`) run before the vendor and log nothing.
- **Write kinds.**
  - A merge reads fresh and sends the complete set (AD-4).
  - A create fingerprints the name's absence (AD-54). It sends a case-folded id as typed (`TypedId`).
  - An action fingerprints its preconditions (AD-51), and a declared port may sequence calls (AD-52).
  - Screen and agent are two callers of one operation (AD-53, AD-55), under the per-target lock (AD-34), with a read-back (AD-58), a copy-out (AD-59) and a change event (AD-14).
  - A write the vendor does not audit is a named gap (AD-15, AD-53).
- **Ids, fields, pairs.**
  - Each entity type has its own canonical-id rule (AD-13).
  - Field lists derive from body templates, and an unclassified field is secret (AD-3).
  - One read serves screen and tool (AD-36).
  - A screen's pairs are the admin API's plus any custom resource on the classic pages it replaces (AD-8, AD-44, AD-64). `ResourcesOR()` is only a lower bound.
- **Tool listing (AD-5, from 20.24).** `ListTools` caches the listing per process and rebuilds it when the `OcuPilot.` compile signature changes. Only compile-time declarations decide whether a tool is listed. A value read at run time (a setting, a grant, an adjustment, a policy) never enters the listing. Extend this cache rather than bypassing it.
- **Self-protection (AD-10).** Kernel predicates are stated over the effect, never the payload, and evaluated inside the confirm's atomic transition. Each is refused from either caller: `OCUPILOTROUTINEAPP` (any write to `OcuPilotState`/`OcuPilotIdentity`), `OCUPILOTCODE` (OcuPilot's own code, including new names under its packages), `OCUPILOTNAMESPACE` and `OCUPILOTSSL`. Granting `%All` or an `%Admin_*` privilege is permitted at the destructive treatment, naming the privilege.
- **Text.** Vendor text is logged, never sent (AD-39). Each refusal sentence is written once, in Fixed strings. New pairs, predicates, entity types, named cases and `CLASSICPAGES` entries go into the spine at the spec gate.
- **18.32 and 18.34 (AD-53: the agent's second code path).** `webapp.restapis.create` compiles `.spec`, `.disp` and `.impl` from a whole OpenAPI 2.0 document, through `MgmntPort`. It is held to 20.21's rules at the mint and again at Confirm: only the namespace's own routines database, never `%SYS` or a `%` name, and `OcuPilot*` refused under `OCUPILOTCODE`. The card shows the whole document, at most 30,000 characters. The create's key ships enabled. `webapp.restapis.delete` is destructive, ships `false`, and refuses a service a web application dispatches to. Neither write records a vendor event (AD-15's twenty-first case, AD-53's named gap twenty-one). Reuse `ExplorerSave`'s checks rather than copying them. 18.34 adds the person's Create dialog over 18.32's port, and its Save takes the per-target hold. The two sources disagree on one rule. The epics file holds the person's create to the agent's rules. 18.32's spec says it skips the agent's routines-database check, as a person's Save does, but keeps `OCUPILOTCODE`. 18.34's plan settles which applies.
- **18.33** extends 18.31's tools, form and rules. Updates send the complete roles and routines sets. Validate target roles before the vendor call, since an absent one answers 500.
- **18.11.**
  - Each read has its own port and resource gate (AD-29); the monitoring API's anonymous reachability never becomes OcuPilot's.
  - Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`), and each call rewrites the sensor baselines. OcuPilot never calls the vendor's alerts read.
  - The drill-downs read the admin API's monitor dashboard routes; drop `BusyProcesses`' empty rows. Interoperability usage reads the deprecated InteropMetrics v1.
  - The live tail is a `%SYSTEM.Event` long-poll with a heartbeat (the iris-couch ChangesHandler pattern).
- **18.12.**
  - Every Stage 2 screen brings its read and confirmed write tools with no hand-written tool code.
  - Unadvertised tools stay unadvertised (AD-53).
  - Earlier turns replay only as user message and final reply, capped at 65,536 characters with the oldest dropped first (AD-24).
  - A proxy is a destination judged by the egress policy, an https call tunnels through it, and a marked-local endpoint bypasses it (AD-42).
  - A wallet-backed rung joins the credential ladder, which never returns a value into a status or an error.
- **18.13.**
  - One idempotent installer runs from the container start or IPM's `<Invoke>`; only the container path unexpires `_SYSTEM` (AD-17). IPM is never a runtime dependency (AD-18).
  - Code lives in the install namespace's routines database, and state in OcuPilot's protected database (AD-9).
  - The unauthenticated applications' role reads exactly that namespace's routines and default globals databases (AD-21).
  - Install reads back its schema grant (AD-38).

## UX & Interaction Patterns

- Every screen registers the screen contract, including three suggested prompts. The side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, edited in place, one `strings.ts` key per value. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come from the closed set and never stack. A person's destructive confirm names the action and target, states the consequence and requires the typed name. An agent's destructive card takes the destructive treatment with no typed name.
- Editors are tabbed form pages in the classic order, with a sticky Save/Cancel bar and an unsaved-changes guard. Gated controls stay focusable and `aria-disabled`, with their reason.
- Log viewers load bounded pages; the live tail supersedes that only for sources that opt in. Auto-refresh uses AD-43's shared framework and its roster.

## Cross-Story Dependencies

- **Run order:** 18.32, 18.33, 18.34, 18.11, 18.12, 18.13 and 18.35, then the epic close.
- 18.33 follows 18.31; its plan is seeded from 18.31's first plan (`18436f8d`). 18.34 follows 18.32; its seeds are in 18.32's first plan (`bb49cd14`). 18.32 reuses 20.21's code-write checks and 20.20's whole-document card, both on feature.
- 18.12 consumes every Stage 2 tool, from 18.24's wallet tools through 18.31 to 18.34's, and extends 20.24's tool-listing cache.
- Epic 20 runs on slot B and edits the same shared files: the kernel's `Prohibited`, the registry, `Error.cls`, `Router.cls`, the governance baseline, test rosters, `strings.ts`, EXPERIENCE.md and the spine. Edits are add-only and unioned at merges. 18.32's two pre-authorized non-add-only edits to the prohibited-set files merge as plain unions, and both classes are re-run fresh.
- No story covers the catalog rows WQM categories (SA-05) and enabling the mirror service (SA-22). The epic close assigns or declines each.
- At Epic 18's merge, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
