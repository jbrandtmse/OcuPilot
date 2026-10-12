# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool, plus confirmed single-write tools where it writes. The agent grows with the stage: every Stage 2 tool is declared from its descriptor (18.12, done), each turn is assembled within a budget now that the roster has roughly doubled, and the provider call gains proxy and custom-CA configuration and a wallet-backed credential rung. OcuPilot also installs into a namespace the operator chooses, and a person, never the agent, edits the directory allow-list. This is the first versioned IPM release after the contest. Done: 18.1 to 18.12, 18.14 to 18.34 and 18.36 (18.27 closed unbuilt, 18.35 retired). 18.39 is planned, validated and ready for dev. Remaining run order: 18.39, 18.13, 18.42, 18.37, 18.38, 18.40, 18.41, the Epic 18 burn-down (18.43), then the epic close.

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
- Story 18.12: The agent grows with the stage (narrowed: tools from descriptors, DW-2321, DW-1756)
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
- Story 18.43: The Epic 18 burn-down (chartered at the burn-down gate; not in the epics file)

## Requirements & Constraints

- **One contract (FR-80).** Each screen is one descriptor over one port. Its read tool, and its write tools' field lists, derive from that descriptor. Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. A story's acceptance is that contract plus each row's backing route; anything finer is authored when the story is picked up.
- **Governance (AD-22).** Every destructive or disruptive key ships `false`. A story that adds a write key adds its `Kernel/Governance/Baseline.cls` entry in the same change. Governance is asked at dispatch and again at Confirm, and never for a person's own screen write. 18.37, 18.38 and 18.39 add no key.
- **Observe first.** Measure each route's payload, effects, privileges and audit events on the slot's throwaway (`ocupilot-ci`) before any form or tool exists. Take privileges from the instance, measured as a least-privileged principal, never from the specification. Never build on a `decision-pending` ledger entry. Install (18.13) runs only on a throwaway; starting or recreating the live `ocupilot` container is the owner's call. A live provider key (18.39's Task 0) is read from `.env.local` at the point of use, on `ocupilot-ci` only, and is never printed, logged, ledgered or committed.
- **Budgets.**
  - Bundle: 3,388,876 B initial after 18.12, against a 3527kB warning and a 4000kB error budget. A story that crosses the warning re-bases it to 5% above the measured merged total (DW-1166). Stop and ask above 3800kB.
  - Fixed strings: 3,279 after 18.12, against a 3,400 drift tripwire that is raised only once the count comes within 50 of it.
  - `Api/Error.cls` holds 989 of the 1,000 parameters a class may carry. New codes go in a sibling `*Error.cls`, with prefix arms in `Error`'s reason mappers.
  - Tools: 371 read tools after 18.12 (369 at the 20.5 merge, plus `webapp.routineapproles.read` and `webapp.routineapproutines.read`), pinned by `Test/ReadTool`, whose counts are token-unioned at each forward merge.
- **Ledger, by owner.** Address each item, or decline it with a reason.
  - **18.39, 18.37, 18.38, 18.40, 18.41:** none routed.
  - **18.13:** DW-219 (uninstall's three half-state paths on an instance OcuPilot does not wholly own), DW-423 (`Stamp` keeps one row per install run, with no retention), DW-1333 (IPM's exporter drops `<SystemRequirements>`, so the archive carries no version floor) and DW-2172 (detect a SQL grant on OcuPilot's schemas widened outside OcuPilot, to another role or `_PUBLIC`). DW-1788 is wontfix-theoretical, but becomes real if OcuPilot's applications can span namespaces: then a namespace delete whose bound applications include one of OcuPilot's own must be refused.
  - **18.42:** DW-2334, decided by the owner on 2026-10-11.
  - **18.43 fixes:** DW-2311, DW-2320, DW-2322, DW-2328, DW-2329, DW-2333, DW-2335 and DW-2340, and it audits DW-2327.
  - **The burn-down gate also holds** (owner `burndown`, from earlier Epic 18 stories): DW-1896, DW-1966, DW-1979, DW-1981, DW-2007, DW-2085, DW-2086, DW-2087, DW-2100 (high), DW-2126, DW-2149, DW-2160, DW-2167 and DW-2299 (after Epic 20 merges). The CI flakes DW-2111 and DW-2123 go to whichever epic burn-down gate comes first.
  - **Never reported:** the vendor-defect candidates on owner hold (for example DW-2283, DW-2284 and DW-2309).

## Technical Decisions

**Every story**

- **Containment (AD-2, AD-27).** Only `AdminPort` names `%Api.Admin.*`, and it reads the outcome from both `tSC` and `%response.Status`. A read answered 404 is an absence and is not logged. Any other failure outside the unlogged list is logged and raises the instance's alert state, so refuse a predictable vendor refusal before the call. A queued write still running at the bound answers as started.
- **Gates (AD-8, AD-29).** There is no service account. The only OcuPilot elevation is AD-9's, and it is never in effect while tool, port or provider code runs. Each port carries its own gate, evaluated before any vendor call. `ResourcesOR()` is only a lower bound: read the backing class's own check, then run as a real least-privileged principal. The monitoring API's anonymous reachability never becomes OcuPilot's.
- **The turn never mutates the instance (AD-7).** Exactly six vendor-internal write shapes are permitted (credential migration, the REST discovery cache, the sensor baseline, the routine index, the statement index and the DocDB refusal audit row). A new shape needs a spine amendment at its spec gate. Never call the alerts read, which advances `LastAlertSent`.
- **Read contract (AD-36, AD-24).** 200 rows by default (an operator sets 1 to 1,000), 65,536 characters in total cut by whole rows, 1,000 characters a field; the payload reports `rowsSent`, `rowsAvailable` and truncation.
- **Writes.** A merge reads fresh and sends the complete body (AD-4). A create fingerprints the target's absence (AD-54), an action its preconditions (AD-51). The screen and the agent are two callers of one tool (AD-53, AD-55), under the per-target hold (AD-34), with a read-back (AD-58) and a change event (AD-14). An unadvertised tool is reachable by its screen alone.
- **Self-protection (AD-10).** Predicates over the effect, refused whatever the caller and evaluated inside the confirm's atomic transition; a rule only a screen enforces is not a prohibition. A privileged grant (`%All` or `%Admin_*`) through a role, an application role, a matching role or a routine is permitted at the destructive treatment. Refused: any change to `OcuPilotState` or `OcuPilotIdentity`; deleting OcuPilot's install namespace or `%SYS`, or changing its databases (`PROHIBITED.OCUPILOTNAMESPACE`); deleting OcuPilot's own provider SSL/TLS configuration or changing its `VerifyPeer`, `CAFile`, `Type` or `Enabled` (`PROHIBITED.OCUPILOTSSL`).
- **Text and amendments.** Vendor text is logged, never sent (AD-39). Each refusal sentence is written once, in Fixed strings, and pinned equal to the kernel's reason. New pairs, predicates, source kinds, vendor-write shapes and carve-outs are amended into the spine at the spec gate (Rule 20). Rule 31: name the sibling a new class extends, or say why a copy is better.

**18.39, the context budget (ready for dev; the spec holds the plan)**

- **AD-24 as amended.** Within a turn, history is append-only: no message already sent is changed, reordered or removed, because current reasoning models bind each thinking block to what precedes it. A turn's tool results carry at most 262,144 characters together (`Limits.TURNRESULTMAXLENGTH`). Each reply's share is the lesser of `TOOLRESULTMAXLENGTH` (65,536) and what remains, cut by AD-24's whole-row mark and refused `TOOL.RESULTTOOLARGE` once less than 256 remains.
- **The tool array.** It is the listing's whole set (AD-5, AD-8), built once per turn and byte-identical on every call. A per-call selection would need AD-8's "full tool set" restated, which is the owner's call.
- **Caching.** The Anthropic adapter marks its last tool and the final message's last block `cache_control` ephemeral, and `system` stays a string. OpenAI, Gemini and compatible servers cache by their own rules, with no request change.
- **AD-31 as amended.** Anthropic's token figure is `input_tokens` plus cache writes and cache reads, with reads at full weight; OpenAI's and Gemini's figures already include their cached tokens.
- **Never.** A second listing cache (Rule 31), Gemini's `cachedContents`, Anthropic's context-editing beta, or a new error code, Fixed string, client change or schema change. Task 0's measured figures are added to AD-24 at dev_complete.

**18.13, multi-namespace install**

- **Installer (AD-17, AD-18).** One idempotent `Installer`, run from the container start or from IPM's `<Invoke>`. Only the container path unexpires `_SYSTEM`, and IPM is never a runtime dependency.
- **Validation.** It refuses `%SYS`, confirms the namespace exists, confirms interoperability enablement where a chosen credential rung needs it (the `creds` rung does), and maps the package. A second run into the same namespace changes nothing.
- **Code and data (AD-9, AD-21).** Code lives in the install namespace's database, and only OcuPilot's globals sit behind its protected resource. Each unauthenticated application (the shell and readiness) carries exactly one application role, read-only on the install namespace's routines and default globals databases.
- **Grant read-back (AD-38).** Install reads back its schema grant, and the gate answers `unreadable` when it cannot read its own state. DW-2172's detection belongs beside that read-back.
- **Lifecycle (AD-37).** OcuPilot deletes only what it created, and its retention sweep acts on its own state. DW-423's `Stamp` retention belongs in that sweep.
- **Self-protection.** AD-10's install-namespace arm names one namespace. More than one install namespace needs that arm restated at the gate (inference), together with DW-1788.

**18.42, allowed directories: a person's write**

- **AD-21 as amended (owner, DW-2334).** A person adds, changes and removes `FSAccess` entries (`Path`, `Purpose`) on the Allowed directories screen as a confirmed write whose governance key ships disabled, and the roots OcuPilot needs to run cannot be dropped.
- **The agent never writes the list.** The kernel refuses any agent write, narrowing included, in the AD-10 and AD-21 self-protection family; leaving the tool unadvertised (AD-53) is not enough. A reason for an agent narrowing found at the gate is the owner's question.
- **The fence it moves (AD-21's sixth case).** `Port/PathPort` alone computes the roots, at call time and never cached. When the instance restricts `%GUIFileSelector`, the roots are that purpose's paths (`FSAccess.Purpose` `GET`, `FSAccess.Path` `LIST`); otherwise `<ManagerDirectory>` alone. A write tool resolves again at its write, so a root dropped after a mint refuses that confirm. Which roots OcuPilot needs is the plan's to measure; turning the purpose's flag on or off switches between the two root sets.
- **Gate question.** AD-22 never asks governance for a person's screen write, so the disabled key alone cannot hold that write (inference); the gate settles what the key governs.

**18.37, interoperability usage**

- **The catalog row's source fails AD-8.** The row names the deprecated `/api/monitor/interop/v1` (`%Api.InteropMetrics.v1`), which checks nothing and reaches the `[Internal]` `%SYS.Ensemble.SetSAMSensorsForInterop*` methods. Those escalate with `$$$AddAllRoleTemporaryInTry`, and AD-8 accepts a vendor running as itself only after the vendor has checked the caller.
- **The preferred source.** The classic page (`%CSP.UI.Portal.InteroperabilityUsage`, `RESOURCE` `%Admin_Operate`) queries `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces`. The spec gate prefers the source that keeps AD-8 as written; relaxing AD-8 is the owner's call, raised through the Planner.
- **Gate questions.** Whether the sensor setters write state, which would be a new AD-7 shape. The port declares its own gate (AD-29), consistent with AD-62's one-port model for interoperability (inference).

**18.38, the live tail**

- **Sources.** `messages.log` and `alerts.log`, the only sources with `LogSourcePort`'s offset-and-identity cursor. They opt in through a descriptor key (an AD-5 addition), and each keeps its classic log page's resource.
- **The route.** No vendor event signals a log write, so an OcuPilot route long-polls within `Kernel.Provider.TestCall.BoundSeconds`, re-checking the file's size and identity between waits (iris-couch's `ChangesHandler` pattern). Rotation invalidates offsets, so the tail restarts cleanly (AD-21).
- **Inputs and model text.** No endpoint accepts a path; a log is named from a fixed enum (AD-21). Log text that reaches the model passes AD-60's sanitizer.
- **Device writes (AD-12).** Only the response writer writes to the device, and the static handler is its one carve-out. Heartbeat bytes need a second carve-out, and AD-43 needs an amendment; both are tier-1 amendments at the spec gate.
- **Concurrency.** Whether concurrent tails need a per-user bound, as turns have (AD-41), is a gate question (inference: each open poll holds a server process up to the bound).

**18.40, proxy and custom CA**

- **Custom CA.** A custom CA is a separately named SSL/TLS configuration, because AD-10 refuses a `CAFile` change on OcuPilot's own. AD-32 is amended at the spec gate. How far a custom CA is trusted is the owner's call through the Planner.
- **What already ships.** The installer creates `OcuPilotProvider` with server-identity checking on (AD-32). `Kernel/State/Egress.cls` stores the proxy settings and SSL configuration name, `SetGuarded` is its one writer, and no route renders it. `ProviderPort` judges the proxy host and CONNECT-tunnels https. `Api/Switches.cls` is the sibling settings surface.
- **Rules (AD-42).** A proxy is a destination judged by the endpoint's policy. An https endpoint CONNECT-tunnels through it, and a marked-local endpoint bypasses it. Test connection exercises the same path as a turn, so a misconfiguration surfaces at setup.

**18.41, the wallet rung**

- **The ladder.** `Kernel.Secret.Ladder` ships the `env` and `creds` rungs. A wallet rung joins them, reusing the wallet wiring the secrets screens use. AD-42, AD-35 and AD-7 are amended at the spec gate.
- **Key handling (AD-42, AD-35).** The ladder never returns a value into a status or an error. The key is fetched at the point of use, held in a variable cleared before return, and never interpolated into a URL, message or error. A test asserts that a forced provider failure leaves no credential in the error log.
- **Vendor entry points.** `Port/WalletPort.cls` lists secrets and never reads a value, so reading one is new behavior; read `%Wallet.KeyValue` `GetSecretValue` and `ApplyHTTP` first. The vendor's per-use audit write (`%Wallet.Secret` `AuditUsage`) is a candidate seventh AD-7 shape, labeled (inference) until Task 0 measures it.
- **Constraints.** The rung's name must fit the stored `CredType` field (at most 8 characters). Any choice that exposes a secret or adds a vendor audit write is the owner's.

**18.43, the burn-down**

- **DW-2311.** In `MgmntPort.Resolved`, walk each listed application's `UrlMap` `Forward` targets and read `GetWebRESTApps` over every namespace, so a forwarded or cross-namespace service counts as deployed.
- **DW-2320.** In `GrantsPrivilegeByEffect` (`Kernel/Proposal/Prohibited.cls`), key the held and wanted `MatchRoles` targets by matching role and target, so moving a privileged target to another matching role, or to an empty one, counts as a grant.
- **DW-2322.** Clearing a privileged routine application's `Resource`, or enabling it, while it grants a privileged role takes the privileged-grant treatment: an application with no resource runs for anyone.
- **DW-2328.** Rows of an id-kind-none list share one key when the name column repeats (MetricsList: 942 rows over 115 metrics), and `RoutineAppRoleList`'s Every caller row keys `''`. Give such rows a row-unique key in the shell's table model, or declare composite ids.
- **DW-2329 (owner, 2026-10-11).** `MonitorPort.Samples` handles a label value ending in a single or a doubled backslash, and skips and counts one unreadable line rather than failing the table. No Windows read is needed.
- **DW-2333.** DW-2321's web-application half: a detail read over a web application's `MatchRoles`, on 18.12's routine-application roles read, so `webapp.list.update` can send the list whole with one entry changed.
- **DW-2335.** Several Stage 2 editor forms show fields no read tool answers (superservers 14, local databases 10, user copy 12). Widen the reads, or record why each field stays form-only.
- **DW-2340.** The Dashboard's drill-down links (`dashboard.page.ts` `linksFor`) filter on `built` alone. Gate them on the screen verdict with `aria-disabled` and the Requires reason, as the side bar and Home do.
- **DW-2327.** Audit the 48 two-argument `%GetNext` sites. Fix those that read caller-controlled JSON, which answer 500 on an oversized string or number where 18.34's three-argument form answers 422 or 400, or charter a sweep if there are many.

## UX & Interaction Patterns

- **Screens.** Every screen registers the screen contract with its suggested prompts. The side bar lists only built screens.
- **Strings.** New strings go in EXPERIENCE.md's Fixed strings, edited in place, with one `strings.ts` key per value. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- **Gated controls (DW-2340).** A gated control stays focusable with `aria-disabled="true"`, never `disabled`, and names its reason. This is a contract (EXPERIENCE.md :214-216), not an option.
- **Allowed directories (18.42).** The screen's strings sit at EXPERIENCE.md :364. A person's write is reviewed by the screen's confirm dialog, not a proposal (AD-53).
- **Auto-refresh (AD-43).** One shared framework, paused while a proposal is live. A screen joins only by declaring it and by appearing in EXPERIENCE.md's roster of thirteen (:896). Every default is off except Home's.
- **Log viewers (18.38).** Today a log viewer loads bounded pages with "Load newer", and nothing streams ("Tail, not live", :899; the component and state rows are :646 and :848). 18.38 amends those lines in place at its spec gate, and re-scopes the "nothing streams" pins in `log-viewer.spec.ts` and `Test/Descriptor.cls` to the sources that do not opt in.
- **Provider settings (18.40, 18.41).** The proxy and SSL settings have no screen today. The credential rung is chosen on the agent definition form.

## Cross-Story Dependencies

- **Run order:** 18.39, 18.13, 18.42, 18.37, 18.38, 18.40, 18.41, then 18.43, then the epic close.
- **What 18.12 left.**
  - `Test/StageTwoTools.cls` holds Epic 18's screens (`Roster`) and every other screen (`Elsewhere`) equal to the registry both ways. A new screen, or an Epic 18 write tool on an earlier screen, needs its row.
  - `AllowedDirectoryList` is a `read-only` row whose reason says the list is a person's write; 18.42 turns it to `writes`, and an unadvertised tool joins the test's `UNADVERTISED` list.
  - The two routine-application detail reads are the pattern DW-2333 follows.
- **18.39** runs on 18.12's roster, downstream of 20.24's listing. 18.40 and 18.41 rebase on its `Kernel/Provider/Anthropic.cls`. 20.12 (backlog) also touches the tool registry; whichever merges second rebases on the first.
- **18.13** builds on Epic 20's merged 20.1 (namespace category gating). If the wallet rung has an install prerequisite, 18.41 extends 18.13's validation (inference).
- **18.42** adds a kernel refusal in `Prohibited.cls`, a governance baseline entry and a StageTwoTools row change.
- **18.37** runs after 18.42, and **18.38** after 18.37.
- **18.40 and 18.41** both edit the provider call path (`Port/ProviderPort.cls`, `Kernel/Provider/Base.cls`), so 18.41 rebases on 18.40.
- **18.43** fixes DW-2311 against 18.32's `MgmntPort`, DW-2320 and DW-2322 against 18.33's classifier, and DW-2333 on 18.12's detail-read pattern.
- **Epic 20** still runs on slot B (20.6 next) and owns `Prohibited.cls` and `Screen/Tool/Write.cls`.
  - A non-add-only edit to either needs the orchestrator's pre-authorization (18.42, DW-2320, DW-2299).
  - Its other shared files take add-only edits, unioned at merges: the tool registry, `Error.cls`, `Router.cls`, the governance baseline, the test rosters, `strings.ts`, EXPERIENCE.md, `angular.json` and the spine.
  - The count-pinning rosters (entity types, `ClassicPageGate`, `ReadTool`) are token-merged at each forward merge and re-run fresh. If `angular.json` collides, re-measure the merged bundle.
  - Each story re-checks Epic 20's diff against `Loop.cls`, `Dispatch.cls`, `Screen/Tool/Registry.cls` and `Write.cls` at its own plan.
- **The epic close.** No story covers the WQM categories row (SA-05) or the row that enables the mirror service (SA-22); the close assigns or declines each. At Epic 18's merge, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
