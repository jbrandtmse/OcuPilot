# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental, hidden `/api/admin` v2 service, plus `/api/mgmnt` and `/api/monitor` where they back a screen. That covers namespaces and mappings, databases and disk operations, journals, licensing and ECP, encryption, superservers and authentication options, MFT, SQL privileges, web-application extras and monitoring. Each screen comes with a read tool and a confirmed single-write tool, so the agent keeps pace with the portal. The stage also prepares OcuPilot for shared instances: install into a chosen namespace, a clean uninstall, and a directory allow-list only a person can edit. It keeps the doubled tool roster affordable and adds proxy, custom-CA and wallet-key provider configuration. Every feature story is done. The stage closes with two burn-down stories that fix, or close on evidence, the defects its stories routed forward, so the first versioned IPM release after the contest ships without the stage's own debt.

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
- Story 18.47: Epic 18 burn-down, part 1 (grants, providers, the shell, the monitor)
- Story 18.48: Epic 18 burn-down, part 2 (encryption, journals, LDAP, agent reads)

## Requirements & Constraints

- **Burn-down acceptance.** Each chartered ledger entry is either fixed with a pinning test or closed on evidence in its ledger trailer. The entry text and the rulings recorded against it are the scope; nothing beyond them is invented.
- **One contract.** The stage's stories are accepted against the staged-delivery contract plus their own backing route. Each screen has one descriptor and reaches outside systems through one port. Its read tool and its write field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. Every read is bounded and reports truncation.
- **Gates.** Every gate is the caller's own `(resource, permission)` pairs, checked at call time, with no service account. The vendor's `ResourcesOR()` is only a lower bound.
- **Governance.** Every destructive or disruptive write ships with its governance key disabled. A new write key joins the checked-in baseline in the same change.
- **Secrets.** Key material and secrets are write-only. No read returns them, the ledger and every log line redact them, and they never appear in an exception, a status or a trap.
- **Paths.** No endpoint takes a caller path. Every server-path field resolves through `PathPort` (a root plus a relative name), whose self-protection refusals cover the manager directory, the served directory, the instance's, database and journal files, and an existing `IRIS.DAT`.
- **Measure first.** Several burn-down entries rest on an inference, not a measurement (the start-arm gaps, the RSA certificate loss, the monitor-state race in test probes, the Windows backslash, the cipher fields, and whether any surface reaches the #822 mapping). Task 0 measures each on the throwaway before it is fixed or closed. "Checked" means seen on an instance; anything else carries `(inference)`.
- **Owner calls.** A choice that changes a product promise, the trust scope or secret exposure goes to the owner at the spec gate.

## Technical Decisions

- **`AdminPort`** is the only code that names `%Api.Admin.*`. It runs the vendor endpoint objects in process in `%SYS`, entered by explicit save and restore, at ApiVersion 2 with stub CSP state and `IsRunningAsync` 0. It reads the outcome from both `tSC` and `%response.Status`, and a non-2xx answer is a failure.
- **Logging.** A read answered 404 is an absence, so the port does not log it. Every other failure is logged at error severity, which raises the instance alert state, unless `UNLOGGEDREFUSALS` lists it. Its entries match only endpoint, type and status. Two rulings apply:
  - A correct field refusal must not raise the alert state. The data server #1454 that `EcpPort` maps to `ECP.DATASERVER.SSLCLIENT` is therefore unlogged, scoped by its code, which needs a code-scoped form of the list. Other mapped refusals routed onto the same entry: superserver #5001, MFT delete #5809, and the SQL privilege #5540, #5035 and #516.
  - A vendor 404 #822 (Access Denied) is a refusal, not an absence, so it must not answer `PORT.NOTFOUND`.
- **Vendor-class fallback.** The port may complete a call through the vendor's own class only when the admin API cannot carry it, and only as a new named case recorded in the architecture. The LDAP last-attribute removal is such a candidate: `Security.LDAPConfigs.Modify` in `%SYS`, built only under the caller's own `%Admin_Secure`. Once it lands, the `LDAP.ATTRIBUTES.LASTONE` refusal is lifted.
- **Prohibited set and privilege grants.** The prohibited set lives once in the kernel. It is evaluated against the resolved target inside the atomic confirm, from either caller, and is defined by effect, not by verb. A privilege grant (`%All`, an `%Admin_*` role, or a role carrying one) is permitted at the strongest confirmation: the destructive treatment without a typed name, with the diff naming the privilege. Rulings:
  - Clearing a privileged routine application's `Resource`, or enabling it while it grants a privileged role, is a grant.
  - The `MatchRoles` classifier must compare MatchRole and target together, not target names alone.
- **Provider TLS.** `OCUPILOTSSL` and `PROVIDERSSL` refuse changes to `Type`, `VerifyPeer`, `CAFile` and `Enabled`. Before each provider call, the port re-reads the configuration in use and refuses unless it is an enabled client with `VerifyPeer` of 1 or more. `CipherList` and `TLSMinVersion` are uncovered today, and the ruling handles them the same way for both configurations.
- **Encryption start.** `PROHIBITED.STARTUPINTERACTIVE` refuses Interactive key activation at startup while the audit log, IRISSECURITY or IRISTEMP is encrypted, because such a start aborts into single-user mode (measured). Whether the arm widens is decided only after measurement. The two unmeasured cases are an Unattended key file or KMIP server lacking the active key, and journal encryption under Interactive.
- **Action writes.** The fingerprint subject is declared by the tool and covers every field the action's precondition reads. A reviewed list taken from a file is carried through the fingerprint, as task import does, so a file that changed since the mint refuses the confirm. A first database key activation gets the destructive treatment, following the license activation's precedent, governance default included. Its consequence names the startup-mode change, which only a Settings `PUT` of None resets (measured).
- **Paths for journals.** A journal directory may not be an existing database's directory, OcuPilot's own included, because the vendor writes its `iris.lck` there. This is decided and is built in the burn-down.
- **Screen gates.** `Screen.Gate.RequiredPairs` is the one reader of a screen's requirement: its declared or adjusted pairs, plus any custom resource on the classic page it replaces. The client never derives availability from the generated mirror.
- **Monitoring.** `MonitorPort` reads the sensors in process behind `%Admin_Operate:USE` and `%DB_IRISSYS:READ`. Each read rewrites the vendor's sensor baseline, so the metrics screen never auto-refreshes.
- **Async and writes.** A port has one poller per task, and no slice writes polling logic. OcuPilot reads fresh, applies the diff and sends the complete property set, apart from the per-endpoint exceptions the architecture records. A screen's Save and the agent's proposal are two callers of one tool. Every confirmed write reads its target back and returns a verdict. Each write field is classified `ordinary`, `secret` or `opaque`.

## UX & Interaction Patterns

- A gated control is never hidden. It stays focusable with `aria-disabled="true"` and names its reason ("Requires ..."), as the side-bar and Home already do. A link to a screen the caller is refused follows the same rule.
- A person's destructive action uses a typed-name dialog that names the target, with its consequence stated above the field. An agent proposal gets the destructive card treatment, without a typed name. A consequence sentence appears both at the field and on the card. An RSA key replaced over a stored certificate must say the certificate is lost.
- An action whose governance key is off is drawn off, with the refusal's sentence as the reason.
- Every screen works with the agent disabled. A field the person sees should be answerable by a read tool, unless the record says why it stays form-only.

## Cross-Story Dependencies

- **Open at this compile:** 18.47 and 18.48 (backlog). Every other story is done.
- **18.47:**
  - DW-2320 edits the kernel's prohibited-set class in a way that is not add-only. Epic 20, which is in progress, also holds that class, so the edit must be coordinated.
  - DW-2333's web-application `MatchRoles` read follows the routine-application reads Story 18.12 built.
  - DW-2311 makes the REST-service delete walk listed web applications' `UrlMap` Forward targets and read every namespace's REST applications.
  - DW-2329 accepts both backslash forms, skipping and counting one unreadable line (owner).
  - DW-2327 audits the 48 two-argument `%GetNext` sites and fixes those reading caller-controlled JSON. If more than about 10 need it, it charters one sweep entry instead.
  - DW-2149 either drops the monitor value from the five probes' snapshots or proves it cannot move mid-class.
  - DW-2328 either gives an id-kind-none list a row-unique key in the shell or declares a composite id.
- **18.48:**
  - DW-2100 comes first: its Task 0 runs on the throwaway, then the start-arm scope is decided.
  - DW-2085 builds on Story 18.22's key activation. The create offers Encrypt database only while a database key is active, and sends the default key's id.
  - DW-1979 and DW-1981 are fix-pack items. The bundle budget is re-based per story.
  - DW-2335 either widens the reads or records why each field stays form-only.
- **Other epics:**
  - DW-2299 moved to Story 23.9, the range-end cleanup.
  - Story 18.45 sits after Story 20.24's per-process listing.
  - Stories 18.3 and 18.4 extended Epic 16's `BackgroundTaskPort`.
