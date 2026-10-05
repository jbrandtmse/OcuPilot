# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic brings OcuPilot to System Administration and System Operation parity on the experimental `/api/admin` v2 service. It covers namespaces and mappings, local and remote databases and their disk operations, journals, licensing and ECP, the four encryption pages, superservers and authentication options, MFT, SQL privileges, the web-application and monitoring extras, and installing into a chosen namespace. Each screen arrives with its read tool and its confirmed single-write tools from one descriptor, so the agent grows with the portal and key management stops being a reason to keep the classic portal open. Stage 2 is the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, so measured payloads, containment and self-protection carry the weight.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP (the license key and license servers since the split)
- Story 18.7: Encryption (the key files since the split)
- Story 18.8: Superservers, authentication options and managed file transfer
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

## Requirements & Constraints

- **One contract (FR-80).**
  - Each screen is one descriptor over one port. The read tool and the write field lists are derived, and no tool code is hand-written.
  - Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each row's backing route. Finer criteria are written at the story's plan.
- **Observe before building.**
  - Before any form or tool, a Task 0 on the slot's throwaway measures each route's payload, effects, required pairs and audit events. It restores the state it found exactly and halts on any contradiction.
  - Measure combinations of pairs, so that no write can half-apply under its declared pairs. Take privileges from the instance, not from the specification.
  - Probe objects use a prefix no other suite's prefix matches (18.7 took `OCUPROBE187`).
  - Build on the pinned 2026.2 image. An endpoint the inventory fixture does not cover means re-running the inventory audit.
- **Every instance here runs a Community license, CI included.** No test activates a license key, opens an ECP connection or needs a restart. Every success path that needs a licensed instance, or leaves anything only a restart clears, runs through a test seam. Community created key files at 18.7's Task 0, and no readable vendor source checks a license for encryption, so activation is likely not license-gated either (inference; 18.22's Task 0 measures).
- **Slot B's throwaway `ocupilot-b-ci`** was rebuilt fresh on 2026-10-04T22:38Z on the orchestrator's instruction. It carries every arming variable, `OCUPILOT_ALLOW_ENCRYPTION_CONFIG` included, reads `Config.CPF.PendingRestart` 0, and its HSSYSLOCALTEMP is intact. Restart it only on an orchestrator instruction.
- **Governance.**
  - Every destructive or disruptive action defaults to disabled. Encryption changes are among them, so every encryption key ships `false`.
  - Each new write key gets its `Kernel/Governance/Baseline.cls` line in the same change.
  - AD-22's dated window closed on 2026-10-04: how any other new key enters the baseline is the owner's call. 18.7 built its keys `false` with that answer a merge condition, which the orchestrator relays.
- **Secrets and key material are write-only.** They are never returned, logged, kept in a proposal or put in a queued body. The vendor generates every encryption key, and the agent never holds key material.
- **Budgets.** Each story re-bases `angular.json`'s `maximumWarning` to the measured total (DW-1166): 2,885 kB after 18.7. `maximumError` is 4,000 kB, and a runner stops and asks above 3,800 kB. `strings.test.mjs`'s literal bound is 2,600 with 2,578 used.
- **Specification mismatches still ahead:**
  - 18.9: sql-privilege rows use `Object` and `Action` (checked), so a revoke is built from those. A role owner's `AdminOption` is the string `"0"` or `"1"` (reported), so compare the value.
  - 18.11: `BusyProcesses` always has ten rows. Drop the empty ones.
- **Routed ledger items.** Each one is addressed or declined with a reason.
  - 18.22:
    - DW-2059: `Prohibited.DependsOnKey` compares key ids normalized (uppercase, hex digits only) and refuses an encrypted own database whose key id cannot be read. Task 0 activates a probe key and compares `Database.SysCRUD` `LIST` `EncryptionKeyID` with `KeyInFile` `LIST` `Id` to confirm or narrow that.
    - DW-2066: `DependsOnKey` reads only the journal's configured key (`DBEncJournalKeyID`), while journal files still needed for recovery may use an earlier one. Measure the vendor's `IsEncKeyInUse`, which guards deactivation, and widen the check.
  - 18.23: DW-2065 is decision-pending, an owner product call. Removing a key file's startup administrator is not refused, yet unattended activation opens `DBEncStartKeyFile` as `DBEncStartUsername`. The question is whether AD-10's key arm extends to it.
  - 18.24: DW-1555, creating and editing RSA and symmetric-key wallet secrets, which Story 8.6 shows read-only.
  - 18.8 and 18.9 meet DW-1774 through 18.7's fix. Browser specs take an area's labels from `ui/browser/side-bar-spec.mjs`, which derives them from the mirror, and `ui/tools/side-bar-pins.test.mjs` refuses count pins and literal lists. `ui/tools/navigation.test.mjs` keeps one literal per area, which a screen-adding story extends.
  - 18.9: DW-236. 18.13: DW-219 and DW-423.
  - Epic close burn-down (all decided):
    - DW-1966: refuse an existing database's directory, OcuPilot's own included, as a journal directory (AD-21).
    - DW-1979: make Journal records' Newest first draw the newest record first.
    - DW-1981: give the record browser's inputs a `maxlength`, with a budget re-base.
    - DW-2007: add a code-scoped `UNLOGGEDREFUSALS` entry, so that the vendor's #1454, which `EcpPort` maps to `ECP.DATASERVER.SSLCLIENT`, is not logged (AD-2). 18.7's logged credential refusals (#5001, #1219, #1204) and #5022 are recorded as occurrences of it.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).**
  - Only `AdminPort` and its subclasses name an `%Api.Admin.*` class. A write tool declares the port it reaches its target through, and that port builds the bodies, fresh reads and call sequences.
  - The outcome comes from both `tSC` and `%response.Status`. A call through a vendor class is allowed only as a named AD-27 case, such as `WalletPort`'s composed wallet read.
  - Only the vendor's own 404 reads as no rows (AD-36).
  - A failure outside `UNLOGGEDREFUSALS` is logged at severity 2, which raises the instance's alert state even when a port maps it to a refusal. Entries match endpoint, type and status. A distinct status mapped to a field joins the list (18.7: `AdminInFile` `POST` and `DELETE` 409). A 500 shared with internal faults stays logged until the burn-down's code-scoped entry.
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is only a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role. Never use `%Operator`. Administrative resources are required at `USE`.
  - Every `Config.*` write measured so far needed `%DB_IRISSYS:WRITE` beyond its screen's set.
  - A tool declares such extra pairs, plus `%Admin_Operate:USE` where it polls an async task. It refuses a caller without them by name, before any port call.
  - A screen whose port resolves a path declares `%Admin_FileSystemAccess:USE` as its own pair (Allowed directories, Encryption key files). A read that calls `Security.System.Get` declares `%Admin_Secure:USE`.
  - A self-protection read can need its own pair: `removekey` declares `%Admin_Manage:USE` because the database and namespace reads behind its AD-10 arm need it.
  - No new surface relies on the API floor alone, which admits `%Development:USE`.
  - `CLASSICPAGES` lists every classic page beyond the descriptor's own whose operation a write performs, spelled as `NormalizePage` answers.
  - A removal names its impact through the owning screens' declared reads, with the caller's privileges.
- **Write kinds.**
  - **Merge (AD-4).** Read fresh and send the complete set.
    - A nested body is merged member by member, and each object is sent complete.
    - The vendor does not stop at a refused member, so a port pre-checks any refusal that would leave a write half-applied.
    - Admin `PUT`s are upserts, so the fresh read and the fingerprint guard against a target deleted since the read.
  - **Create (AD-54).** Fingerprint the name's absence.
  - **Action (AD-51).** A declared request type with no body, or a port-built body as a named case (18.7: `EncryptionPort`). The fingerprint covers every precondition field, and `PRECONDITIONCODES` names the fresh-read refusals that close a proposal as target-changed.
  - **Secrets in a body (AD-56).** A secret-only body takes only its declared secrets. A port-built body may carry the tool's declared secrets beside its arguments (18.7's key-file passwords). An empty secret clears a stored value only where `CLEARABLESECRETS` says so.
  - **The screen and the agent are two callers of one tool (AD-53, AD-55).** The screen's call mints no proposal and emits no marker, and read-only and the kill switch do not gate it. An unadvertised tool is a named AD-53 case.
  - **Every write has** a read-back (AD-58), a port `Snippet` that mirrors every branch (AD-59), a change event (AD-14), and the per-target lock, `WRITE.TARGETBUSY` after 10 s (AD-34).
  - **Unaudited writes.** A write the vendor does not audit, measured with auditing on, is a named case in AD-15 and AD-53. Key-file writes are audited (`%System/%Security/DBEncChange`), so 18.7 added none.
- **Ids and fields (AD-13, AD-3).**
  - A new entity type joins the kernel's closed enum. Its id is `foldcase` where the instance stores names in upper case, and kept exactly where the vendor matches exactly. A composite id (18.14, 18.7's `encryption-key-file` of `root` and `path`) is kept exactly.
  - A singleton is declared as such: `journal-settings`, `license-key`, `ecp-settings`.
  - Fields are derived from the endpoint's body template into the generated sources, which are regenerated and never hand-merged. An endpoint with no template derives from its class, pinned by a test that fails when the instance disagrees, or is action-style. The `Security.Encryption.Settings` template's `AdminPassword` is a credential field.
  - Every field is classified by a reviewed per-tool entry, and an unclassified field is emitted secret.
- **Reads (AD-36).**
  - One declared read serves both the screen and the tool. The shapes: a single-object `GET`, `forEach` or `parts`, a `rowGet` detail call, `source.rows`, seeded parent keys, criteria with defaults and a `hint`, one fixed `read.note`, and a port-named read source (18.7's `encryption`, whose `root` and `path` criteria name an existing key file).
  - A payload with no schema stays screen-only. A key that completes key material is declared secret and never answered, and no read answers key material.
- **Async (AD-26).**
  - The port refuses a mutating type that would queue unless `QUEUEDWRITES` names it. It never queues a body that carries a secret, because the vendor writes the body in plain text to a public task row and to the journal. No encryption type queues.
  - Each task has one poller, which reads the task's end once. A second read logs ERROR #7846 and raises the instance to Warning.
  - Past the bound, the write answers "started" and its read-back is `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path.
  - **Sixth case:** a root plus a relative name, which `PathPort` resolves at the mint and again at the write. A file the consumer reads is a `source` and must exist (`PATH.NOFILE`). An overwriting file consumer declares its overwrite as a constant. A directory the vendor writes is refused the manager directory, OcuPilot's served directory, and every database, volume, journal and WIJ directory, read at call time.
  - An encryption key file is a sixth-case location: a create names a new file that never overwrites in a directory that must already exist, and every other key-file call names an existing file as a `source`. `AdminPort` refuses a caller's `file`, `File` or `DBEncStartKeyFile` on any `Security.Encryption.*` call unless it arrives through `EncryptionPort` (`PATH.NAME`).
  - **Seventh case:** a remote directory only as the data server's own listing spells it. **Eighth case:** a journal file only when it equals a listed `Name`.
  - A location that can name another host is shown and never set. A caller value that reaches code the vendor executes comes only from a closed set.
- **Text and self-protection.**
  - OcuPilot answers in its own sentences. Vendor text is logged and never sent (AD-39).
  - New error codes go in an area error class (`EncryptionError.cls`, `EcpError.cls` and others). `Api/Error.cls` holds 989 parameters against the compiler's 1,000, so it gains only dispatch lines.
  - AD-10's predicates live once, in the kernel. Each is stated over the effect, evaluated inside the confirm's atomic transition, and pinned by a test that fails when it is removed. New prohibitions go in AD-10.
  - Every grant outside OcuPilot's own applications, roles and resources is permitted at the strongest confirmation.
- **Encryption, as 18.7 built and measured it.**
  - `Port/EncryptionPort.cls` extends `AdminPort` and resolves key files through `PathPort`; its rules are in `Area/Security/EncryptionRules.cls`.
  - AD-26 is corrected at origin: `Security.Encryption.Settings` reads `%request` only under API v1, so under the v2 pin its administrator credentials travel in the body and it needs no CSP state.
  - All 13 encryption routes answer on Community. `Settings` `PUT {}` and `Key` `DEACTIVATE {}` stop at body validation (400), and `File` `ACTIVATE` on an absent file answers 404. The inventory's `Key` `mutating="0"` misses `DEACTIVATE`, which runs through `Key`'s own `Run`; 18.22 corrects it at origin.
  - `AdminPort` already admits `File/ACTIVATE`, `Key/DEACTIVATE` and `Settings/PUT` as mutating types. `Test/ToolWrite`'s `AHEADTYPES` asserts no tool reaches them yet, and the story that ships each tool removes its entry.
  - **AD-10 key arm (`PROHIBITED.OCUPILOTKEY`).** Removing from a key file a key that encrypts OcuPilot's own database, the install namespace's globals or routines database, one of the seven protected databases, or the journal is refused from either caller, read at the write; a failed read refuses.
  - **Test doubles.** `Test/EncryptionSeamPort` records each call with its body's key names, never a value, and arms dependency modes (`protected`, `system`, `namespace`, `unreadable`, `other`, `journal`), read-failure modes and `keysfail`. `Test/EncryptionEndpointPort` resolves every endpoint to a fixture: no test sends `File` `ACTIVATE`, `Key` `DEACTIVATE` or `Settings` `PUT` to the real vendor. `Test/EncryptionProbe` owns `OCUPROBE187` and `<ManagerDirectory>ocuprobe187/`.
  - **Vendor facts.** `KeyLen` is in bits (128, 192 or 256). Administrator names are stored upper case and compared without case. `File` `POST` returns the new key's id only in `Location`. `Database.SysCRUD` `LIST` rows carry `Encrypted` and `EncryptionKeyID`. `Settings` `GET` carries `DBEncStartMode`, `DBEncJournal`, `DBEncIRISSecurity`, `DBEncIRISTemp`, `AuditEncrypt`, the KMIP server, `DBEncStartKeyFile`, `DBEncDefaultKeyID` and `DBEncJournalKeyID`.
- **Encryption still to build.** These are the outlines kept in `spec-18-7-encryption.md` at commit `0a3dfe43`; each story's plan settles its own.
  - **18.22.** Two Security screens over `Key` `LIST` (`Id`, `KeyLen`, `IsDefault`) and `Key` `DATAELEMENTLIST` (`Id`). Tools on `EncryptionPort`: database activate (`File` `ACTIVATE`, the key file as a `source`, a secret `AdminPassword`) and deactivate (`Key` `DEACTIVATE`, `DESTRUCTIVE`), plus the data-element pair. Task 0 activates and deactivates a probe key and compares `Security.System`, the `PendingRestart` reasons and the journal state with S0; if an activation leaves anything only a restart clears, the success paths go through the seam. The vendor's key-in-use refusals map to refusals. Encrypting or decrypting an existing database has no admin API route and no classic page, so it is named unreachable rather than built.
  - **18.23.** An unlisted form reached from Database encryption, with one merge tool over `Settings` `GET`/`PUT`. The explicit version gate: the port refuses the `PUT` unless the derived template carries `AdminName` and `AdminPassword` (the v2 shape), pinned by a test. Every value change runs through a seam, since each effect is restart-only or destructive. Changing `AuditEncrypt` deletes the audit database at once, the agent's markers with it (AD-15), so the plan stops and gives the orchestrator options with a recommendation: an owner product call.
  - **18.24.** RSA and symmetric create tools on `WalletPort`, generated or imported, all material secret. The read widens to stored metadata, never a value, which amends AD-27's third case. Its product calls: replace versus delete and create; whether imports are advertised; whether public material may feed a read or a fingerprint.
- **What earlier stories left for reuse.**
  - Ports: `PathPort` and its picker, `NamespacePort`, `DatabasePort`, `RemoteDatabasePort`, `JournalPort`, `LicensePort`, `EcpPort`, `EncryptionPort`, `BackgroundTaskPort`, `MonitorPort`, `MgmntPort` and `WalletPort`.
  - The read-back, removal impact, the copy-out draft and the sanitizer.
  - **ECP rules for any later test:**
    - A test that changes `MaxServerConn` runs through `EcpSeamPort`'s `ecpserver` mode. An ObjectScript guard and a browser-spec twin in `ci.test.mjs` hold that rule.
    - Probe data servers are configuration only, at TEST-NET-1 (`192.0.2.0/24`).
    - Never send a `DBLIST`, a `SERVERACTION` with `Action` 3, or any change to `%Service_ECP`.
- **Later stories.**
  - 18.8:
    - Disabling `%Service_WebGateway` is refused `PROHIBITED.SERVINGSERVICE`.
    - AD-10 also prohibits disabling the superserver, so 18.8's superserver writes carry that arm (inference).
    - A change that would break OcuPilot's own sign-in, which depends on the instance's JWT issuer, is refused.
    - The LDAP list and its full editor already shipped, so the read-only LDAP view is likely covered (inference).
  - 18.9: its criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment. Reconcile at the spec gate, where the spine governs.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11:
    - Each read goes through its own port and gate, and `/api/monitor`'s anonymous reach never becomes OcuPilot's.
    - Only `MonitorPort` calls `PrometheusMetrics`.
    - The vendor alerts read is never called, because it advances a shared cursor.
    - The tail checks its offset against the file's identity and restarts on rotation.
  - 18.12:
    - Earlier turns reach the model capped at 65,536 characters, with the oldest dropped first (AD-24).
    - A proxy is judged by the egress policy (AD-42).
    - OcuPilot's provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled` are prohibited to change, so custom-CA support cannot rely on editing them (inference).
    - The credential ladder never returns a value into a status or error.
  - 18.13:
    - There is one idempotent installer with two entry points (AD-17).
    - Code goes in the install namespace and globals in OcuPilot's protected database (AD-9).
    - The own-namespace, own-mapping and own-database predicates key off the namespace the API runs in, read at the write.
- **Spine amendments at the spec gate (Rule 20).** Amend the spine for anything new: AD-4 nested merges, AD-8 pairs, AD-10 predicates, AD-13 entity types, AD-21 path cases, AD-26 queued writes, AD-27 named cases, AD-36 read shapes, AD-44 `CLASSICPAGES`, AD-51 port-built bodies and precondition codes, AD-56 secret bodies, and AD-15 and AD-53 unaudited writes.

## UX & Interaction Patterns

- **The screen contract.**
  - Every screen registers the 10-item screen contract and ships three suggested prompts.
  - The DW-1337 structural gate holds in both themes.
  - The side bar lists only built screens, at positions above 0.
- **Placement.**
  - OS management lists nineteen entries, ending with ECP settings at 18 and ECP application servers at 19.
  - Security and secrets lists SSL/TLS, X.509, LDAP / Kerberos, Wallet, OAuth 2.0, Auditing, Allowed directories (7) and Encryption key files (8). A key file's create is an unlisted form reached from its list.
  - 18.22 adds Database encryption (9) and Data element encryption (10), in the classic menu's order. 18.23's startup settings form is unlisted, reached from Database encryption. 18.24 replaces Story 8.6's read-only view of RSA and symmetric secrets on the Wallet screens.
- **Strings.**
  - New strings go in EXPERIENCE.md's Fixed strings, and a refusal sentence is published once and pinned to the kernel copy.
  - Edit EXPERIENCE.md in place, so that it keeps its line count (1,026 now), because `strings.ts` cites it by line.
  - `strings.ts` holds each value under one key, and a label another screen already publishes reuses that key.
  - After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- **Dialogs and pages.**
  - Dialogs are the closed set in EXPERIENCE.md's Dialogs line, and a new dialog joins it. Everything else is a full-page route, and dialogs never stack.
  - **Destructive confirm:** the title names the action and the target, and the body states the consequence. A typed name must match exactly, case-sensitive (a key's removal types its `Id`).
  - An action that removes nothing takes the destructive treatment with no typed name. An agent proposal has no typed name either; it uses the destructive bar and Confirm.
- **Editors.**
  - An editor is a form-page whose tabs mirror the classic page, with one form, a sticky Save and an unsaved-changes guard.
  - A setting shown but never set is read-only, with a hint naming the classic page.
  - A choice the license or a precondition rules out is drawn `aria-disabled` with its reason.
  - The path picker offers only allow-list roots plus a relative name.
  - A wait that may block is bounded and stated before it starts.
  - 18.23's startup options (interactive, unattended and KMIP) each state their consequence.
- **Controls and feedback.**
  - Gated controls stay focusable and `aria-disabled`, and name their reason. 18.7's dialogs tie each refusal to its control through `aria-describedby`.
  - An async write reads "<operation> running on the instance since <time>", then "<operation> finished."
  - Key material and passwords use the masked secret field: write-only, and empty after save. A password the person types at confirm needs a masked row on the agent's card, as 18.7's add-key and add-administrator cards carry, or the confirm cannot succeed.
  - Auto-refresh is one framework over a fixed roster. A screen joins only through its descriptor and EXPERIENCE.md's roster row. The encryption screens do not join it.

## Cross-Story Dependencies

- **Order.**
  - Done: 18.1-18.7 and 18.14-18.21.
  - Next is 18.22, then 18.23, which needs 18.22's Database encryption screen. 18.24 is independent and may run at any position.
  - Then 18.8-18.13, then the epic close burn-down.
- **Within the epic.**
  - 18.22 consumes 18.7's key files and `EncryptionPort`, naming a key file as a `source` for activation.
  - 18.23 sets the unattended startup key file through the same resolution.
  - 18.8 and 18.9 use the side-bar helper.
  - Each screen story delivers its own tool parity, so 18.12's context budgeting matters more as the roster grows.
- **Epic 19 runs in parallel** and merges forward at story boundaries. The latest merges brought 19.8 and 19.16's spec gate. Its spine amendments are its own.
  - Keep edits to these shared files add-only:
    - the kernel and registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, `Gate.cls` and `Classification.cls`;
    - the test rosters, `ci-throwaway.sh`, `ci.test.mjs` and `angular.json`;
    - `strings.ts`, `navigation.ts`, `screen-actions.ts` and `command-box.ts`;
    - EXPERIENCE.md and the spine.
  - `Prohibited.cls`'s Codes comment still says twenty-six codes against 27. That is left for the range-end cleanup (DW-2060).
  - Union one-line list members and roster counts at the merge.
  - Regenerate `screens.generated.ts` and `ToolFields.cls` instead of hand-merging them.
  - **AD-53's named-gap ordinals.** Epic 19's gaps fifteen and sixteen collide on sixteen with Epic 18's fourteenth, sixteenth and seventeenth, and renumbering is left to a merge. A new case takes the next ordinal after both lists, the eighteenth.
