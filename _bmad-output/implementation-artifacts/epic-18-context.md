# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental, hidden `/api/admin` v2 service, plus `/api/mgmnt` and `/api/monitor` where they back a screen. That covers namespaces and mappings, databases and disk operations, journals, licensing and ECP, encryption, superservers and authentication options, MFT, SQL privileges, web-application extras and monitoring. Each screen comes with a read tool and a confirmed single-write tool, so the agent keeps pace with the portal. The stage also prepares OcuPilot for shared instances (install into a chosen namespace, a clean uninstall, a directory allow-list only a person can edit), keeps the doubled tool roster affordable, and adds proxy, custom-CA and wallet-key provider configuration. Every feature story and the first burn-down are done. Story 18.48, the second burn-down, fixes or closes on evidence the encryption, journal, LDAP, agent-read and provider defects the stage routed forward, so the first versioned IPM release after the contest ships without the stage's own debt.

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

- **Burn-down acceptance.** Each of 18.48's twelve ledger entries is either fixed with a pinning test or closed on evidence in its ledger trailer. The entry text and the rulings recorded against it are the scope; nothing beyond them is invented.
- **One contract.** Each screen is one descriptor that reaches the instance through one port. Its read tool and its write field lists derive from that descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker. Every read is bounded and reports truncation.
- **Gates.** Every gate checks the caller's own `(resource, permission)` pairs at call time, with no service account. The vendor's `ResourcesOR()` is only a lower bound.
- **Governance.** Every destructive or disruptive write ships with its governance key disabled. A new write key joins the checked-in baseline in the same change.
- **Secrets.** Key material and secret values are write-only. No read returns them, the ledger and every log line redact them, and they never appear in an exception, a status or a trap.
- **Paths.** No endpoint takes a caller path. Every server-path field is a root plus a relative name resolved by `PathPort`, whose self-protection refusals cover the manager directory, the served directory, the instance's, database and journal files, and an existing `IRIS.DAT`.
- **Measure first.** Several entries rest on an inference: the start-arm gaps (DW-2100), the RSA certificate loss (DW-2126, read in the vendor source only), each key-file refusal's endpoint, type and status (DW-2427), and the LDAP write under the caller's own privilege (DW-1896). Task 0 measures each on the throwaway before it is fixed or closed. "Checked" means seen on an instance; anything else carries `(inference)`.
- **Owner calls.** A choice that changes a product promise, the trust scope or secret exposure goes to the owner at the spec gate.

## Technical Decisions

- **`AdminPort`** is the only code that names `%Api.Admin.*`. It runs the vendor endpoint objects in process in `%SYS`, entered by explicit save and restore, at ApiVersion 2 with stub CSP state and `IsRunningAsync` 0. It reads the outcome from both `tSC` and `%response.Status`, and a non-2xx answer is a failure.
- **Logging.** A read answered 404 is an absence and is not logged. A vendor 404 #822 (Access Denied) is a refusal, answered 403 and logged. Every other failure is logged at error severity, which raises the instance alert state, unless `UNLOGGEDREFUSALS` lists it. Entries may be scoped by vendor code: #1454 and #5809 are unlogged, while the superserver's generic #5001 stays logged. DW-2427 adds code-scoped entries for the key-file field refusals #5022, #1219 and #1204, each after its endpoint, type and status is measured.
- **Vendor-class fallback.** The port may complete a call through the vendor's own class only when the admin API cannot carry it, and only as a new named case recorded in the architecture. DW-1896 is such a case. The admin API's `Security.LDAP` `PUT` keeps the stored list for `LDAPAttributes []` and answers `[""]` with 500 (measured). The fix writes through `Security.LDAPConfigs.Modify` in `%SYS`, built only under the caller's own `%Admin_Secure`, and then lifts the `LDAP.ATTRIBUTES.LASTONE` refusal. If that privilege does not suffice, the entry closes wontfix-accepted.
- **Prohibited set.** It lives once in the kernel and is defined by effect, not by verb. It is evaluated against the resolved target inside the atomic confirm, from either caller. A privilege grant (`%All`, an `%Admin_*` role, or a role carrying one) is permitted at the strongest confirmation: the destructive treatment without a typed name, with the diff naming the privilege. Grants compare roles per (MatchRole, target). For a privileged routine application, a cleared `Resource`, or enabling it while it grants a privileged role, is a grant. DW-2425 extends this to web applications. Enabling one that grants a privileged role is a grant, and so is pointing a `Resource` at a publicly held one.
- **Encryption start.** `PROHIBITED.STARTUPINTERACTIVE` refuses a settings change that would leave key activation at startup Interactive while the audit log, IRISSECURITY or IRISTEMP is encrypted, now or at the next start. Such a start aborts into single-user mode (measured). Two cases are unmeasured: an Unattended key file or KMIP server lacking the active key for those databases, and journal encryption under Interactive. Whether the arm widens is decided only after Task 0 measures both.
- **Key activation.** An action write's fingerprint covers every field its precondition reads. DW-2086 carries the reviewed key list taken from the file through the activation's fingerprint, as task import does, so a key file whose keys changed since the mint refuses the confirm. DW-2087 gives a first database key activation only the destructive treatment, following the license activation's precedent, governance default included. Its consequence names the startup-mode change to Interactive. That change outlives every deactivation, and only a settings `PUT` of None resets it (measured). DW-2085 adds Encrypt database to the database create. It is offered only while a database key is active, and it sends `Encrypted` and the default key's id.
- **Wallet keys.** A stored secret's value is never read, so a fingerprint covers metadata only. DW-2126: regenerating an RSA key over a secret that holds a certificate drops the certificate (inference). `WALLETKEY.REPLACE.RSA` and the card must say so. The wallet credential rung reads a key-value secret's value only after value-free checks of the caller's use privilege, its usage, `RequireTLS` and `AllowedHosts`. The value never reaches a local, a log or a refusal.
- **Journal directories.** Both journal directories are vendor-writes locations named by a root and a relative name. They must already exist and are never cleared. DW-1966 refuses an existing database's directory, OcuPilot's own included, because the vendor writes its `iris.lck` there.
- **Provider TLS.** `OCUPILOTSSL` and `PROVIDERSSL` refuse changes to `Type`, `VerifyPeer`, `CAFile`, `Enabled`, `TLSMinVersion` and `CipherList`. Before each call, the provider port re-reads the configuration in use through OcuPilot's SSL-read routine application. It refuses unless that configuration is an enabled client with `VerifyPeer` 1 or more and a `TLSMinVersion` floor of TLS 1.2 (16) or higher. `CipherList` is not judged at call time. Switches' egress save checks an enabled verifying client only. DW-2424 adds the TLS 1.2 floor to that save-time rule, with one new `EGRESS` violation code.
- **Reads.** A screen and its read tool resolve through one declared read, so they cannot diverge. The tool's view is the screen's, narrowed by the context cap and stripped of secret fields. DW-2335 either widens the reads behind the superserver, local database and user copy forms (14, 10 and 12 unanswered fields) or records why each field stays form-only.
- **Async and writes.** A port has one poller per task, and no slice writes polling logic. OcuPilot reads fresh, applies the diff and sends the complete property set. A screen's Save and the agent's proposal are two callers of one tool. Every confirmed write reads its target back and returns a verdict.

## UX & Interaction Patterns

- A gated control is never hidden. It stays focusable with `aria-disabled="true"` and names its reason. An action whose governance key is off is drawn off, with the refusal's sentence as the reason.
- A person's destructive action uses a typed-name dialog that names the target, with its consequence stated above the field. An agent proposal gets the destructive card treatment without a typed name. A consequence sentence appears both at the field and on the card. The RSA replace sentence must say that a stored certificate is lost. The first database key activation's consequence names the startup-mode change.
- Every screen works with the agent disabled. A field the person sees should be answerable by a read tool, unless the record says why it stays form-only.
- Live tail streams only on the current alerts.log and messages.log files. With Live tail off, nothing streams, and that spec's timers must be isolated per test (DW-2415).

## Cross-Story Dependencies

- **Open at this compile:** Story 18.48 only (backlog). Every other story is done, 18.47 included.
- **Order and sources within 18.48:**
  - DW-2100 comes first: its Task 0 runs on the throwaway, and only then is the start-arm scope decided.
  - DW-2085, DW-2086 and DW-2087 build on Story 18.22's key activation.
  - DW-2126 amends Story 18.24's RSA replace.
  - DW-1966 amends Story 18.18's journal settings.
  - DW-1896 is the LDAP editor's last-attribute write, left over when Story 18.27 closed unbuilt.
  - DW-2335 comes from Story 18.12's survey.
  - DW-2415 is Story 18.38's log-viewer spec. It failed on the Node 22.22.3 gates leg only.
- **Built on 18.47:**
  - DW-2425 extends DW-2322's grant arm and edits the kernel's prohibited-set class, which Epic 20 also holds. Coordinate the edit.
  - DW-2427 extends the code-scoped unlogged list built for DW-2007.
  - DW-2424 aligns Story 18.40's egress save with 18.47's call-time floor.
- **Routed out of the epic:** DW-2299 went to Story 23.9, and DW-2426 (test classes' teardown on an unarmed instance) to Story 23.10.
