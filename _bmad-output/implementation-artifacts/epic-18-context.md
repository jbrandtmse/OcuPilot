# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental `/api/admin` v2 service: namespaces and mappings, local and remote databases and their disk operations, journals, licensing and ECP, encryption, superservers, authentication options, MFT, SQL privileges, the web-application and monitoring extras, and installing into a chosen namespace. Each screen arrives with its read tool and confirmed single-write tools from one descriptor, so the agent grows with the portal. Stage 2 is the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, so measured payloads, containment and self-protection carry the weight.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
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

## Requirements & Constraints

- **One contract (FR-80).** One descriptor over one port per screen. The read tool and the write field lists are derived, with no hand-written tool code. Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate is the caller's own privileges, checked at call time. Acceptance is this contract plus each row's backing route; finer criteria are written at the story's plan, never in advance.
- **Observe before building.** A Task 0 on the slot's throwaway measures each route's payload, effects, required pairs and audit events before any form or tool, and restores the state it found. Measure pair combinations, not one principal: a write must be impossible to half-apply under its declared pairs. Take privileges from the instance, not the specification: `%Operator` holds `%Admin_Operate:USE`, which the specification accepts for the database lists, yet both answer it 403 (reported). Build on the pinned 2026.2 image; the inventory fixture is re-derived for 2027.1 when it ships. An endpoint the fixture does not cover means re-running the inventory audit.
- **Specification mismatches still ahead.** 18.9: sql-privilege rows use `Object` and `Action` (checked), and a revoke is built from them; a role owner's `AdminOption` is the string `"0"` or `"1"` (reported), so compare the value. 18.11: `BusyProcesses` always has ten rows; drop the empty ones.
- **Governance.** Every destructive or disruptive action defaults to disabled: deletes, dismount, truncate, encryption changes. Each new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change (a test fails otherwise). Through 2026-10-04 other new keys enter enabled unless the story says otherwise; after that, the owner decides.
- **Secrets and key material** are write-only: never returned, logged, kept in a proposal, or put in a queued body.
- **Bundle budget.** `angular.json`'s `maximumWarning` is re-based to the measured total in each story (DW-1166; 2,638 kB after 18.19 and the 19.14 merge). `maximumError` is 4,000 kB, and a runner stops and asks above 3,800 kB.
- **Routed ledger items**, each addressed or declined with a reason:
  - 18.6: none.
  - 18.7: DW-1555 (RSA and symmetric-key wallet secrets) and DW-1774. DW-1774's rule binds every story that adds a listed screen: extend every pinned side-bar list, found with `grep -l ocu-side-bar-label ui/browser` plus `ui/tools/navigation.test.mjs`.
  - 18.9: DW-236 (a widened SQL grant on OcuPilot's state table).
  - 18.13: DW-219 (uninstall half-states) and DW-423 (install-stamp retention).
  - Epic close burn-down: DW-1966, decided 2026-10-03: Journal settings refuses an existing database's directory, OcuPilot's own included, as a journal directory (AD-21 already states the rule). DW-1979: Journal records' Newest first draws oldest first; steer the store's sort with the order criterion. DW-1981: give the record browser's offset and value inputs a `maxlength`, landing with a budget re-base.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` names an `%Api.Admin.*` class. Declared ports (`DatabasePort`, `JournalPort`, `NamespacePort`, `RemoteDatabasePort`) build bodies, fresh-read types and call sequences on it. The outcome comes from both `tSC` and `%response.Status`. A call through a vendor class is allowed only as a named AD-27 case. Only the vendor's own 404 reads as no rows; a 404 carrying another code is a refusal and fails the read (AD-36).
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role on the throwaway. Never use `%Operator`, which holds `%DB_IRISSYS:RW`. Administrative resources are required at `USE`.
  - A screen may declare its own pair beside its area's set where the classic page demands it (External language servers; Journal settings' `%Admin_Journal:USE`). A holder of the area's set keeps every other screen.
  - A tool declares extra pairs when the vendor writes a database the screen's read does not (usually `%DB_IRISSYS:WRITE`), or when an endpoint its call must reach names one (`%Admin_Operate:USE` for an async poll; PathPort's `%Admin_FileSystemAccess:USE` when a root is sent). It refuses a caller without them by name, before any port call. A narrower audience than the classic page is accepted.
  - The API's floor now admits `%Development:USE`. No new screen, route or tool relies on the floor alone.
  - Each write tool lists in `CLASSICPAGES` every classic page beyond its descriptor's own whose operation it performs, Hidden pages included, spelled as `NormalizePage` answers.
  - A removal names its impact, read through the owning screens' declared reads with the caller's privileges.
- **Write kinds.**
  - Merge (AD-4): read fresh and send the complete set. Measure whether the PUT keeps omitted keys or upserts. A key the tool shows but never sets is a named exception (`Journal.Settings`).
  - Create (AD-54): fingerprint the name's absence.
  - Action (AD-51): a declared request type, no body, and a fingerprint subject covering every precondition field. A port-built body or a port-composed fresh-read type is a named entry. `PRECONDITIONCODES` names the fresh-read refusals that close a proposal target-changed inside a confirm.
  - Secret-only body (AD-56).
  - Screen and agent are two callers of one tool (AD-53, AD-55). The screen's caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Every write also has a read-back (AD-58), a port `Snippet` that mirrors every branch (AD-59), the change event, the per-target lock (`WRITE.TARGETBUSY` after 10 s, AD-34), and an impact for a removal. A write the vendor does not audit, measured with auditing on, becomes a named case in AD-15 and AD-53.
- **Ids and entity types (AD-13, AD-14).** A new entity type joins the kernel's closed enum and adds a canonical-spelling rule where the instance folds spellings; a type with no rule canonicalizes to itself. Singletons are declared as such (`journal-settings`).
- **Field lists (AD-3).** Fields are derived from the endpoint's body template into checked-in generated sources. A mutating endpoint that publishes no template derives from the underlying class, pinned by a test, or is action-style. Every field is classified, and an unclassified field is emitted secret.
- **Read shapes (AD-36).** One declared read serves screen and tool. Available shapes: a single-object `GET` (404 reads as zero rows), `forEach`, `parts`, a `rowGet` detail call, `source.rows` over a bare type answering row arrays (License usage, sent `maxRows` as cap plus one), seeded parent keys, and criteria with defaults and a `hint`. A payload with no schema stays screen-only (journal record values).
- **Async (AD-26).**
  - The port refuses a mutating type that would queue unless it is named in `QUEUEDWRITES`; a type that queues itself is also named in `SELFQUEUEDTYPES`. A queued body carries no secret, because the vendor writes it in plain text to a publicly readable task row and to the journal.
  - One poller per task, and its end is read once: a second read logs ERROR #7846 and raises the instance to Warning (reported). Past the bound a write answers "started" and its read-back is `unchecked`. No slice polls. A least-privileged caller's finished task row is left for the 24-hour sweep (AD-37).
  - The one path still to come is `ECP.DataServer`'s server action (18.6).
- **Server paths (AD-21).**
  - Sixth case: the caller names a root and a relative name, never a path, and `PathPort` resolves it at the mint and again at the write. A file the consumer reads is a `source` and must exist. A vendor-writes directory is refused the manager directory and OcuPilot's served directory, and the overwrite refusal covers every database, volume and journal directory and the WIJ directory, read at call time. A database directory is always required.
  - Seventh case: a remote directory only as the data server's own listing spells it, through `RemoteDatabasePort`'s bounded child job, never at a mint or in a turn.
  - Eighth case: `AdminPort` takes a journal file only when it equals a `Name` the journal list answers at that call (`JOURNAL.FILE.UNLISTED` otherwise).
  - A caller value that reaches code the vendor executes comes only from closed sets (the journal record filter).
- **Screen-only text.** A check's console lines reach the screen and the proposal card only (AD-39), never the model, a tool result, the ledger or a log.
- **Self-protection (AD-10).** Predicates live once, in the kernel. Each is stated over the effect, evaluated inside the confirm's atomic transition, and pinned by a test that fails when it is removed. New prohibitions go in AD-10.
- **Licensing and ECP (18.6).**
  - Every instance this project has, CI included, runs a Community license: `$SYSTEM.License.NetworkEnabled()` and `MaxECPServers()` are 0, and the classic ECP page says the license does not support ECP. A data-server listing there blocked about 11 s, answered no rows, and started client daemons that outlive the call and reconnect about every 65 s until the data server is deleted (18.16's Task 0). `RemoteDatabasePort` therefore answers `DATABASE.SERVER.UNREACHABLE` at once with a sentence naming the license. An 18.6 call that opens an ECP connection should reuse that pre-check and the bounded child-job model (inference), and its success path needs a test seam.
  - Per the inventory fixture, `License.Key`, `License.Server`, `ECP.Settings` and `ECP.DataServer` publish body templates. `ECP.AppServerSSLConnection` mutates with no template, and `ECP.AppServerList` only reads. `ECP.DataServer` alone is async (`SERVERACTION`), so it needs a `QUEUEDWRITES` entry and `%Admin_Operate:USE` for the `AsyncResult` poll. Its `ResourcesOR()` is `%Admin_Manage`, a lower bound.
  - The harvested ECP status implementation was never identified, so these screens rely on the routes alone.
  - From 18.16: `ECP.DataServer` `GET` answers `{Address, BatchMode, MirrorConnection, SSLConfig, Port}`, and its `LIST` reads `Config.ECPServers:StatusListSMPFilter`. A data-server delete's 409 #423 can name the remote databases through Remote databases' declared read (AD-5), and `RemoteDatabasePort.Directories` is reusable.
  - The classic pages are the license key page with its activate dialog and print page, License servers, ECP settings, ECP application servers, ECP data servers and the data-server dialog. Read each name from `NormalizePage` on the instance.
  - If activation reads a key file, that file is a sixth-case `source`, never a caller path (inference).
  - The spine holds no licensing or ECP amendment yet. Pairs, the queued write, named cases, `CLASSICPAGES` and unaudited writes are all 18.6's spec-gate amendments.
- **Per story, still to come.**
  - 18.7: `Security.Encryption.Settings` is excluded by the v2 pin. Establish the reachable subset on the instance before any UI. `Encryption.Settings` `AdminPassword` is a credential field.
  - 18.8: disabling `%Service_WebGateway` is refused `PROHIBITED.SERVINGSERVICE`, and AD-10 also prohibits disabling the superserver, which no tool reaches yet because it is not a `Security.Service`; 18.8's superserver writes carry that arm (inference). 18.8 adds refusing an authentication change that would break OcuPilot's own sign-in.
  - 18.9: its criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment, which permits every grant outside OcuPilot's own applications, roles and resources, at the strongest confirmation. Reconcile at the spec gate; the spine governs.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read goes through its own port and gate; `/api/monitor`'s anonymous reach never becomes OcuPilot's. Only `MonitorPort` calls `PrometheusMetrics`. The vendor alerts read is never called, because it advances a shared cursor. The tail checks its offset against the file's identity and restarts on rotation.
  - 18.12: earlier turns already reach the model as message and reply only, capped at 65,536 characters, oldest dropped first (AD-24). A proxy is judged by the egress policy, HTTPS CONNECT-tunnels through it, and a marked-local endpoint bypasses it (AD-42). OcuPilot's provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled` are prohibited to change and restored at every start, so custom-CA support cannot rely on editing them (inference). The credential ladder never returns a value into a status or error.
  - 18.13: one idempotent installer with two entry points (AD-17); code in the install namespace, globals in OcuPilot's protected database (AD-9); the floor roles read the install namespace's routines and default globals databases (AD-21). The install-namespace, own-mapping and own-database predicates key off the namespace the API runs in, read at the write.
- **Spine amendments at the spec gate (Rule 20)** for anything new: AD-8 pairs, AD-10 predicates, AD-13 id rules, AD-21 path cases, AD-26 queued writes, AD-27 named cases, AD-36 read shapes, AD-44 `CLASSICPAGES`, AD-51 port-built bodies and precondition codes, and AD-15 and AD-53 unaudited writes.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract. The side bar lists only built screens at a position above 0. New strings go in EXPERIENCE.md's Fixed strings, and a refusal sentence is published once and pinned to the kernel copy. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- **Placement.** EXPERIENCE.md's area table does not yet place License key, License servers, ECP settings, application servers or data servers; License usage already sits in OS management. 18.6's plan places them and adds the row. Journals and Journal settings stay in OS management (System Operation), not in Logs.
- Dialogs are the closed set in EXPERIENCE.md's Dialogs line, and a new dialog joins it. Everything else is a full-page route, and dialogs never stack.
- **Destructive confirm-dialog:** the title names the action and target, and the body states the consequence. A typed-name field needs an exact, case-sensitive match. An agent proposal has no typed name; it uses the destructive bar and Confirm. Non-destructive warnings use button-primary and may carry one flag or one whole-number field.
- **Editors and wizards:** an editor is a form-page whose tabs mirror the classic page, with one form, a sticky Save and an unsaved-changes guard. A wizard is the vertical, linear form-stepper. The path picker offers only allow-list roots plus a relative name, and shows a `PATH.*` reason on its field. A setting shown but never set is read-only with a hint naming the classic page. A wait that may block, such as a data-server listing, is bounded and stated before it starts.
- **Gated controls** stay focusable, `aria-disabled`, and name their reason.
- **Async writes** read "<operation> running on the instance since <time>", then "<operation> finished."
- **Log viewers** load bounded pages with Load newer. 18.11's live tail supersedes that only for sources that opt in.
- **Auto-refresh** is one framework over a nine-screen roster. A screen joins only through its descriptor and EXPERIENCE.md's roster row.
- **Key material and passwords** use the masked-secret-field: write-only, and empty after save.
- Every screen ships three suggested prompts.

## Cross-Story Dependencies

- Done: 18.1-18.5 and 18.14-18.19. Next is 18.6, then 18.7-18.13, then the epic close burn-down. They build on `PathPort` and the picker (18.1), `NamespacePort` (18.2, 18.14, 18.15), `DatabasePort` and the Integrity log (18.3, 18.4), `RemoteDatabasePort`'s license pre-check and bounded listing (18.16), `JournalPort` and the journal-file guard (18.5, 18.18, 18.19), `BackgroundTaskPort`, `MonitorPort`, `MgmntPort`, `WalletPort`, the LDAP (16.14) and Services (16.13) editors, `Kernel.Shell.Effective` (16.3), governance (14.2), the read-back (16.17), removal impact (16.19), the copy-out draft (14.1) and the sanitizer (14.3).
- 18.6 consumes 18.16's `RemoteDatabasePort` and Remote databases' declared read; 18.16 left data-server management, ECP settings and the server action to 18.6.
- 18.8: the LDAP / Kerberos list and full editor already shipped (16.14), so the read-only LDAP view is likely covered (inference).
- 18.12's tool parity is delivered by each screen story. Its context budgeting matters as the tool roster grows.
- Epic 19 runs in parallel, and its stories merge forward at story boundaries; its spine amendments (AD-61, AD-36's 19.14 clause) are Epic 19's. Keep edits to shared files additive (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts`, EXPERIENCE.md, the spine), and regenerate generated files instead of hand-merging them.
