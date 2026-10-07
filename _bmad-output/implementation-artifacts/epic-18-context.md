# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic brings OcuPilot to System Administration and System Operation parity on the experimental `/api/admin` v2 service: namespaces and mappings, databases and their disk operations, journals, licensing and ECP, encryption, superservers and authentication options, MFT, SQL privileges, the web-application and monitoring extras, and installing into a chosen namespace. Each screen arrives with a read tool and confirmed single-write tools built from one descriptor, so the agent keeps pace with the portal. Stage 2 adds about twenty screens on top of an experimental API, so the stories rely on measured payloads, containment and self-protection. Still to do: MFT connections (18.26), the operator's read-only LDAP view (18.27), the Permissions, web-application and monitoring extras (18.9 to 18.11), the agent's growth (18.12), multi-namespace install (18.13) and the burn-down (18.28).

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Authentication and web-session options (split 2026-10-07; superservers, MFT and the read-only LDAP view moved out)
- Story 18.9: SQL privileges and the permission extras
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
- Story 18.27: The operator's read-only LDAP view
- Story 18.28: The burn-down at the epic's close

## Requirements & Constraints

- **The contract (FR-80).** Each screen is one descriptor over one port. Its read tool and its write field lists are derived from that descriptor, never hand-written. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Acceptance is this contract plus each row's backing route; the finer criteria are written when the story is planned.
- **Governance.** Every destructive or disruptive action (deletes, dismount, truncate, encryption changes) ships with its governance key `false`. A story that adds a write key adds its line to `Kernel/Governance/Baseline.cls` in the same change; a non-destructive key ships enabled unless the story's criteria say otherwise.
- **Observe before building.** A Task 0 on the slot's throwaway measures each route's payload, effects, required pairs (in combination) and audit events before any form or tool is built. It restores exactly the state it found, and it halts on any contradiction. Take privileges from the instance, not from the specification. A probe prefix must neither match another suite's prefix nor be matched by one. Build on the pinned 2026.2 image.
- **Every instance here runs a Community license, CI included.** No test activates a license or encryption key, opens an ECP connection, or leaves anything that only a restart clears; success paths like these run through a test seam.
- **Secrets and key material are write-only.** No read returns them, and they are never logged, kept in a proposal or put in a queued body. The vendor generates encryption keys, and the agent never holds key material.
- **Environment.** Epic 18 runs on slot A: the dev instance is `ocupilot` and the throwaway is `ocupilot-ci` (52776/1975). Local throwaway data lives under `~/.ocupilot-throwaways`. Run one test class per call, never two in flight.
- **Budgets.** `angular.json`'s `maximumWarning` is 3073kB, re-based by 18.25 to its measured 3,072,046-byte initial total. When a story crosses the limit, it re-bases the value and the literal in `angular-json.test.mjs` to the measured total (DW-1166). `maximumError` is 4000kB; stop and ask above 3800kB. The bound in `strings.test.mjs` is 2900; recount the headroom before a large addition.
- **Test lessons.** Never put `$SYSTEM.Monitor.State()` in a before/after snapshot: another class's severity-2 line raises it mid-run. Take a signing-key snapshot only after a mint.
- **Specification mismatches to design for.** 18.9: SQL-privilege rows name `Object` and `Action`, so a revoke is built from those; a role owner's `AdminOption` is the string `"0"` or `"1"`, so compare the value. 18.11: `BusyProcesses` always has ten rows; drop the empty ones.
- **Routed ledger items** (each is addressed, or declined with a reason):
  - 18.27: DW-1896, the LDAP editor's last retrieved attribute, which needs an AD-27 named case through `Security.LDAPConfigs.Modify` in `%SYS`.
  - 18.9: DW-236, DW-1662.
  - 18.12: DW-1756.
  - 18.13: DW-219, DW-423 (install-stamp retention), DW-1333 (the IPM archive carries no version floor).
  - 18.28, the burn-down, decided:
    - DW-1966: refuse an existing database's directory as a journal directory (AD-21).
    - DW-1979: Newest first draws the newest records first.
    - DW-1981: the journal record browser's inputs get a `maxlength`.
    - DW-2007: a code-scoped `UNLOGGEDREFUSALS` entry (AD-2).
    - DW-2085: the database create offers Encrypt database only while a database key is active.
    - DW-2086: an activation's fingerprint carries the reviewed key list, as TaskImport does; this amends AD-51.
    - DW-2087: a first database key activation gets the destructive treatment, its consequence naming the `DBEncStartMode` change, and its key default follows 18.6's license activation. The only reset is 18.23's `Settings` `PUT`.
    - DW-2100: measure first, then decide whether AD-10's `STARTUPINTERACTIVE` arm widens.
    - DW-2126 (product call): `WALLETKEY.REPLACE.RSA` and the card should name the loss of a stored certificate when an RSA key is regenerated (an EXPERIENCE.md amendment).
    - DW-2124, DW-2125, DW-2137, DW-2139: whether to report these vendor defects to InterSystems. They are held with the vendor-report list (owner hold 2026-10-05: not reported), and OcuPilot already works around each one.
  - Any screen-adding story extends the one literal per area in `ui/tools/navigation.test.mjs` and takes its labels from `ui/browser/side-bar-spec.mjs` (DW-1774).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name an `%Api.Admin.*` class. A write tool declares its port, and the port builds the bodies, fresh reads and call sequences. The outcome is read from both `tSC` and `%response.Status`; only the vendor's 404 counts as no rows. A call through a vendor class is allowed only as a named AD-27 case. A failure outside `UNLOGGEDREFUSALS` is logged at severity 2, which raises the instance's alert state.
- **Pairs (AD-8, AD-29, AD-44).** `ResourcesOR()` is only a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role. Administrative resources are required at `USE`. A tool declares every extra pair it needs (for example `%DB_IRISSYS:WRITE` for `Config.*` writes, `%Admin_Operate:USE` to poll an async task, `%Admin_FileSystemAccess:USE` for a `PathPort` read) and refuses by name before any port call. `CLASSICPAGES` lists every extra classic page whose operation a write performs.
- **Write kinds.**
  - Merge (AD-4): read fresh and send the complete set, pre-checking any refusal that would half-apply.
  - Create (AD-54): fingerprint the name's absence. Admin `PUT`s are often upserts.
  - Action (AD-51): fingerprint every precondition field.
  - Secrets (AD-56): an empty secret clears a value only under `CLEARABLESECRETS`.
  - The screen and the agent are two callers of one tool (AD-53, AD-55): the screen's Save mints no proposal and emits no marker, but it now holds the per-target lock under the key its tool's mint computes (`Operation.HoldTool`, AD-34).
  - Every write has a read-back (AD-58), a port `Snippet` (AD-59), a change event that may name its tool (AD-14) and the lock, which answers `WRITE.TARGETBUSY` after 10 s. A create whose declared read is a list row re-reads through `READBACKTOOL`. A write the vendor does not audit is a named AD-15 and AD-53 case.
- **Ids, fields and reads (AD-3, AD-13, AD-36).** A new entity type joins the kernel's closed enum. Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, which are regenerated, never hand-merged. Every field is classified, and an unclassified one is emitted as a secret. `Wallet.Secret` derives one field list per `Type`. One declared read serves both screen and tool, and no read answers key material.
- **Async (AD-26).** A mutating type that would queue is refused unless `QUEUEDWRITES` names it, and a secret-carrying body is never queued. One poller reads a task's end once. Past the bound the write answers "started", its ledger row carries `PORT.STARTED`, and its read-back is `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path. A root plus a relative name is resolved by `PathPort` at the mint and again at the write. A vendor-writes directory is refused for the manager directory, OcuPilot's served directory and every database, volume, journal and WIJ directory.
- **Text and self-protection.** OcuPilot answers in its own sentences, and vendor text is logged, never sent (AD-39). New error codes go in an area error class, because `Api/Error.cls` is near the compiler's parameter limit and gains only dispatch lines. AD-10's predicates live once in the kernel, are evaluated inside the confirm's atomic transition, and are each pinned by a test. A grant outside OcuPilot's own applications, roles and resources is permitted at the strongest confirmation.
- **Encryption, for the burn-down.** `Port/EncryptionPort` builds every `Security.Encryption.*` body and resolves key files through `PathPort`; its rules are in `Area/Security/EncryptionRules.cls`. 18.23's `Settings` merge sends `AuditEncrypt` exactly as the fresh read holds it unless that value was changed. Interactive key activation is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted (`PROHIBITED.STARTUPINTERACTIVE`).
- **Wallet keys (18.24, done).** Four tools on `WalletPort`: RSA and symmetric create (enabled) and replace (governance key `false`). The symmetric replace is unadvertised (AD-53). `AdminPort` refuses `CertificateFile`, `PublicKeyFile` and `PrivateKeyFile` on any `Wallet.Secret` `PUT` (AD-21). Reads and fingerprints carry key metadata only, never a value, public halves included (AD-27).
- **Authentication options (18.8, done).** `authentication-options` is a singleton (AD-13), and its two tools need only Security's set (AD-8). The `Security.WebAuth` merge omits an unchanged `AutheKB`, because re-sending it sets all seven Kerberos bits (AD-4). AD-10 refuses a change that leaves one of OcuPilot's own web applications or `%Service_WebGateway` with no authentication method (`PROHIBITED.OCUPILOTSIGNIN`) and refuses turning O/S authentication off (`PROHIBITED.OCUPILOTSTART`, because the container's start hook signs in through `iris session`). A `JWTIssuer` or `JWTSigAlg` change is permitted at the strongest confirmation. `CHANGESMTPPWD` clears on `""` under `CLEARABLESECRETS` (AD-56), the audit read masks the SMTP password the vendor writes into its "Modify System" row (AD-35), and `AutheLoginToken` is a named exception to the secret-name matcher.
- **Superservers (18.25, done).** Its tools need only Security's set (AD-8). The id is the composite `[Port, BindAddress]` under rule `portbind`: the port in plain decimal, an empty bind address as `0.0.0.0`, the bind address lower-cased (AD-13). `Security.Superserver` is an upsert that keeps a key its body omits, and the merge never sends `SystemDefault` (AD-4). On the system default superserver, or the one whose port the serving request arrived through, AD-10 refuses a delete, `Enabled` or `EnableCSP` turned off, or SSL raised to Required (`PROHIBITED.SERVINGSUPERSERVER`); any other `SSLSupportLevel` or `SSLConfig` change there is permitted at the strongest confirmation. A turn's mint judges by the system default alone; the confirm judges both. Create and update declare `%CSP.UI.Portal.Server` in `CLASSICPAGES`; the delete declares none (AD-44).
- **Later stories.**
  - 18.26: the OAuth 2.0 client configuration a connection names is handled as the story's plan decides.
  - 18.27: the classic `%CSP.UI.Portal.LDAPsRO` and `.LDAPRO` pages serve `%Admin_Operate` holders. No OcuPilot screen does: Story 16.14's LDAP screens require `%Admin_Secure`. The view reads through the admin API and refuses every write.
  - 18.9: the criterion refusing `%All` and `%Admin_*` grants predates AD-10's owner amendment, which permits them at the strongest confirmation; reconcile this at the spec gate, where the spine governs. Password validation wraps the instance's own validator.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read goes through its own port and gate, and only `MonitorPort` calls `PrometheusMetrics`. Never call the vendor's alerts read, which advances a shared cursor. The live tail long-polls with a heartbeat, checks the file's identity and restarts on rotation.
  - 18.12: earlier turns are capped at 65,536 characters, oldest dropped first (AD-24). A proxy is judged by the egress policy (AD-42). OcuPilot's provider SSL configuration is protected by AD-10 (inference: custom-CA support cannot rely on editing it). The wallet rung never returns a value into a status.
  - 18.13: one idempotent installer with two entry points (AD-17). Code goes in the install namespace and globals in OcuPilot's protected database (AD-9). The own-namespace predicates key off the namespace the API runs in.
- **Spine amendments (Rule 20).** Anything new (pairs, predicates, entity types, path cases, queued writes, named cases, read shapes, `CLASSICPAGES`, unaudited writes) is written into the spine at the spec gate. A named AD-15 or AD-53 case takes the next free ordinal at the time it is written.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts. The side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, and each refusal sentence is published once. Edit EXPERIENCE.md in place so its cited line numbers hold, keep one key per value in `strings.ts`, and run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from EXPERIENCE.md's closed set and never stack; everything else is a full-page route. A destructive confirm names the action and the target, states the consequence, and requires a typed name matched exactly. An agent proposal uses the destructive bar instead.
- Editors are form pages whose tabs mirror the classic page, with a sticky Save and an unsaved-changes guard. A setting shown but never set is read-only, with a hint naming the classic page. Gated controls stay focusable, are `aria-disabled`, and name their reason through `aria-describedby`. A wait that may block is bounded and stated before it starts. Key material uses the masked secret field (write-only, empty after save). A password typed at confirm needs a masked row on the agent's card.

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.8 and 18.14 to 18.25. Next comes 18.26, then 18.27, then 18.9 to 18.13, then the burn-down as 18.28.
- 18.26 and 18.27 are independent. 18.12 takes in 18.24's wallet key tools. The burn-down's DW-2086 and DW-2087 amend 18.22's activations, and DW-2087's reset runs through 18.23's tool. As each screen story adds its tools, the agent's roster grows, which makes 18.12's context budgeting more pressing.
- **Epic 20 runs in parallel on slot B** (`OCU-1-epic20`). It overlaps 18.12 at 20.12 (the agent's tool registry) and 18.13 at 20.1 (per-namespace state). Its spine changes have reached this branch: AD-63 (the vendor's interoperability editors load in a same-origin frame that OcuPilot never reaches into) and AD-53 amendments, so the spine now has 62 AD headings.
- Epic 19 and Story 23.4 have closed and merged forward. Shared files take add-only edits, with one-line lists and roster counts unioned at merges: the kernel and registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, the test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md and the spine.
