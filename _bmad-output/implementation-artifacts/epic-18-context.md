# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental `/api/admin` v2 service. That means namespaces, their mappings and interoperability enablement; local and remote databases and their disk operations; journals, licensing, ECP, encryption, superservers, authentication options and MFT; and the SQL-privilege, web-application and monitoring extras. Every screen arrives with a read tool and confirmed single-write tools from one descriptor, so the agent grows with the portal. Stage 2 is the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, which is why containment, the endpoint inventory and self-protection carry most of the weight. Done so far: 18.1, 18.2, 18.14, 18.3 and 18.4. The run order from here is 18.15, then 18.16, then 18.5 to 18.13.

## Stories

- Story 18.1: The directory allow-list (done)
- Story 18.2: Namespaces and their mappings (done; namespaces only since the split)
- Story 18.3: Databases - configuration, creation, properties and volumes (done; remote databases moved to 18.16)
- Story 18.4: The deferred disk operations (done)
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Superservers, authentication options and managed file transfer
- Story 18.9: SQL privileges and the permission extras
- Story 18.10: Web application extras and spec-based REST services
- Story 18.11: Monitoring extras and the live log tail
- Story 18.12: The agent grows with the stage
- Story 18.13: Multi-namespace install
- Story 18.14: Namespace mappings and copy-mappings (done)
- Story 18.15: Enable interoperability on a namespace (runs next)
- Story 18.16: Remote databases (runs after 18.15)

## Requirements & Constraints

- **One contract (FR-80).**
  - Each screen is one descriptor over one port. Its read tool and its write tools' field lists derive from that descriptor, with no hand-written tool code.
  - Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time.
  - A story's acceptance is this contract plus each catalog row's backing route. Finer criteria are written at the story's plan and are never invented in advance.
- **Observe before building.**
  - Observe every write payload, its effects and the pairs it needs on the slot's throwaway before you build any form or tool. 18.15's Task 0 makes this explicit.
  - Build on the pinned 2026.2 image. The inventory fixture is re-derived against 2027.1 when 2027.1 ships.
  - Re-run the inventory audit before using an endpoint the fixture does not cover.
- **The instance is the contract, not the specification.** Some claims come from the DC article on where the SysAdmin API specification and IRIS disagree. Verify a claim the article only reports on the throwaway before anything relies on it. Notes for later stories:
  - 18.5: `POST /v2/journal/file/records` returns half its `maxRows` (checked). Ask for twice the page and mark the list when the limit is reached. It answers 202, so it runs through the async path. `switch-dir` takes no body, so it switches only to the alternate directory already configured.
  - 18.9: sql-privilege rows name the object and action `Object` and `Action` (checked). A role owner's `AdminOption` arrives as the string `"0"` or `"1"` (reported), so compare the value.
  - 18.11: the dashboard's `BusyProcesses` always has ten rows. Drop the empty ones.
- **Async results are read once.**
  - A second `async-result` read of an ended task logs ERROR #7846 and turns the instance state to Warning. `AdminPort`'s single read-then-delete adds no alert.
  - Run one poller per task, share it between every view of that task, and stop it at the end. No slice writes polling logic.
  - The port refuses a mutating type that would queue unless the type is named in `QUEUEDWRITES`. A type that queues itself is also named in `SELFQUEUEDTYPES`. A queued body carries no secret.
  - Past the port's bound, a queued write answers "started", and its read-back is `unchecked`.
  - The remaining Stage 2 async paths (AD-26) are `Namespace.Namespace` interop (18.15), `Journal.File`'s integrity check and `Journal.Record` LIST (self-queued, 18.5), and `ECP.DataServer`'s server action (18.6).
- **Governance (AD-22).**
  - Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change; `GovernanceBaseline` fails otherwise.
  - Earlier write stories also had to extend the roster tests that pin the disabled set, the violation codes and the tool pairs. Search the test classes for a sibling key to find them.
  - Destructive actions default to disabled: the namespace and database deletes, dismount, truncate and the rest of 18.4's operations, and the encryption changes.
  - Through 2026-10-04, any other new key enters enabled unless its story's criteria say disabled. After that date, the owner decides.
  - Enable-interop is not on the epic's destructive list, so 18.15's plan sets its value.
- **Catalog rows next.**
  - 18.15: SA-13's `POST /namespace/enable-interop` (async).
  - 18.16: SA-17, which is `GET|PUT|DELETE /database` (configuration) and `/ecp/data-server/databases`.
- **Routed ledger items.** Address each one in its story or decline it with a reason.
  - 18.15:
    - DW-1776: enable-interop itself.
    - DW-1813: a global mapping range with an empty low end (`:A`) covers the `%` globals, because the vendor reads the empty end as `%`. It needs the `MAPPING.SYSTEMGLOBAL` consequence, as does any range or pattern that reaches those globals.
    - DW-1858: the Integrity log gets an OS management side-bar position right after Databases.
    - DW-1824: the New Namespace form's Create a database keeps what was typed and returns to the form, as the classic portal does.
  - 18.5: DW-1797, adding journal directories to `PathPort`'s refusal, history and WIJ included.
  - 18.7: DW-1774, and DW-1555 for RSA and symmetric-key wallet secrets.
  - 18.9: DW-236.
  - 18.13: DW-219, DW-423 and DW-1788.
  - Every screen-adding story (DW-1774): extend every pinned side-bar list of your area. Find them with `grep -l ocu-side-bar-label ui/browser`, plus `ui/tools/navigation.test.mjs`.
- **Cited documents.** Other suites cite EXPERIENCE.md and epics.md by line, so after an edit to either, also run `cd ui && npm run test:tools`.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).**
  - Only `AdminPort`, or a port extending it, names an `%Api.Admin.*` class, and it reproduces `Main()`'s sequence. A non-2xx `%response.Status` fails even when `tSC` is OK.
  - A read answered 404 is an absence. The port does not log it, and the caller still gets `PORT.NOTFOUND`. Every other failure, including a write's 404, is logged at error severity and reaches `alerts.log`.
  - A vendor-class call is allowed only as a named AD-27 case in the spine. Product code makes no direct `Config.*` or `SYS.Database` write; test seeding is the exception.
  - A declared port may sequence several admin calls for one write. The proposal, fingerprint, gates, marker and ledger row stay those of the one write.
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is a lower bound. Take each pair set from the backing class's own check, plus a purpose-built least-privileged role on the throwaway. Never use `%Operator`, which holds `%DB_IRISSYS:RW`.
  - Administrative resources are required at `USE`.
  - A tool may declare pairs beyond its screen's set in two cases only:
    - the vendor writes a database that the screen's read does not (usually `%DB_IRISSYS:WRITE`);
    - an endpoint the call necessarily reaches names the resource, such as `%Admin_Operate:USE` for the async poll, or `PathPort`'s `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`.
  - A tool with extra pairs refuses a caller who lacks them, by name, before any port call. Record each case in AD-8, which holds 18.2's, 18.14's, 18.3's and 18.4's sets as precedents.
  - In `CLASSICPAGES`, each write tool names every classic page beyond its descriptor's `classicPage` whose operation it performs, as normalized class names confirmed on the instance. `Screen.Gate.WithClassicPages` unions those pages' custom resources into the tool's pairs.
  - An area's pair set covers its screens' pairs, except a pair a screen declares in `ownPrivileges`. An area opens when any of its listed screens is allowed.
- **Write kinds.**
  - Create (AD-54): fingerprint the name's absence.
  - Merge (AD-4): read fresh and send the complete set. Measure whether the PUT keeps omitted keys or acts as an upsert.
  - Action (AD-51): a declared request type, no body, and a fingerprint subject that names every field its precondition reads. When a vendor body carries a fixed or caller-chosen value, the port builds it under a named AD-51 entry. Examples: `NamespacePort` for `MAPPINGS`, and `DatabasePort` for `Database.Actions`, with a port-composed `STATE` fresh read.
  - Both callers reach one tool (AD-53, AD-55). The screen's caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Every write also gets:
    - the read-back (AD-58);
    - a `Snippet` that mirrors every port branch (AD-59);
    - the change event and the agent marker (AD-14, AD-15);
    - `%SYS` by explicit save and restore (AD-16);
    - the per-target lock, held from the fresh read through the write and its read-back, with 409 `WRITE.TARGETBUSY` after 10 s (AD-34; a Save does not hold the lock yet, DW-1882);
    - for a removal, an impact computed on the instance (AD-8).
  - A write the vendor does not audit becomes a named case in AD-15 and AD-53. Measure it with auditing on.
- **Field lists (AD-3).**
  - Fields come from the endpoint's body-template method. A mutating endpoint without one derives its fields from the underlying class, pinned by a test.
  - Classify every field `ordinary`, `secret` or `opaque` in `Classification.cls`. An unclassified field is emitted secret.
  - Regenerate `ToolFields.cls` and `screens.generated.ts`; never hand-merge either.
- **Self-protection (AD-10).** Predicates live once, in the kernel. Each is stated over the effect, so a bodyless write is covered. Each is evaluated inside the confirm's atomic transition, and each has a test that fails when it is removed.
  - Shipped:
    - `PROHIBITED.OCUPILOTNAMESPACE`: deleting the install namespace or `%SYS`, or changing its Globals or Routines database.
    - `PROHIBITED.OCUPILOTMAPPING`: matched by pattern overlap, plus `Prohibited.CODEGLOBALS`.
    - `PROHIBITED.OCUPILOTDATABASE`: OcuPilot's own database, the install namespace's globals and routines databases, and the seven system databases. These are matched by name ignoring case, or through another configuration name over their directories; a dismount is matched by directory.
  - A `%`-global mapping is permitted at the strongest confirmation, carrying `MAPPING.SYSTEMGLOBAL`.
  - AD-10 already refuses disabling `%Service_WebGateway` and the superserver (18.8). 18.8 must also refuse an authentication change that would break OcuPilot's own sign-in (the JWT issuer).
  - 18.9's criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment, which permits every grant outside OcuPilot's own applications at the strongest confirmation. Reconcile the two at 18.9's plan; the spine is the contract.
- **Server paths (AD-21's sixth case).**
  - The caller names a root and a relative name, never a path. `Port/PathPort` computes the roots on every call.
  - It resolves a `directory`, `file` or `source` at the mint and again at the write. Overwrite and vendor-writes are constants of the tool.
  - A refusal is a `PATH.*` code, rendered on the field it names, and never echoes a path. The composed path goes to the vendor under the vendor's own field.
  - Consumers embed `app-server-path-picker` fed by a page-owned `AllowedDirectoriesStore`. Never add a client copy of the segment rule, free-text paths or subdirectory browsing.
  - The owner's rule covers every operation that creates or moves a database file, including 18.16's remote databases: a database directory is always required and is never the manager directory. The tool refuses either by name before any vendor call.
  - 18.5's journal directories and 18.7's key files are path consumers, and 18.7 decides each one's kind. A file the operation reads, such as a key to activate, is a `source`.
- **Descriptors (AD-5, AD-13, AD-36, AD-44).**
  - A new entity type joins the kernel's closed enum with its canonical-spelling rule. References carry `(type, scope, id)`.
  - Each descriptor declares the classic page it replaces.
  - A list never links out to the classic portal. A tabbed editor is one descriptor per tab.
  - A form or wizard reached from its list takes `sideBarPosition` 0, so it is routable but not listed.
  - A page may issue another built screen's declared read instead of writing a second query. A parent-scoped list may seed its parent's key onto its rows.
- **Spine amendments at the spec gate (Rule 20).** Each story writes its own:
  - AD-8 for extra pairs;
  - AD-10 for new predicates;
  - AD-26 for each `QUEUEDWRITES` entry;
  - AD-44 for each tool's `CLASSICPAGES`;
  - AD-51 for a port-built body;
  - AD-21 for a new path case, such as 18.16's ECP connection;
  - AD-15 and AD-53 for writes the vendor does not audit.
- **Testing.**
  - A stateful class arms under its own `scripts/ci-throwaway.sh` variable, added to the rosters `ui/tools/ci.test.mjs` pins. `OCUPILOT_ALLOW_DATABASE_CONFIG` is the database model.
  - Throwaways compile the test classes because they set `OCUPILOT_LOAD_TESTS=1` (AD-17).
  - Predicate legs run through a recording port (`DatabaseRecordPort`), so a removed predicate records a call instead of writing.
  - Probe objects:
    - carry a story prefix;
    - never touch `USER`, `HSCUSTOM` or a system database;
    - are removed before all tests, after each, and after all;
    - create a `%DB_*` resource before its database.
  - One test class runs at a time. A database left mounted without its directory cannot be cleared.
  - No test depends on what another test left behind, because the CI shards reorder classes.
  - OcuPilot's own finished async rows are swept as objects after 24 h, never by SQL (AD-37).

## UX & Interaction Patterns

- **Screen contract.**
  - Each screen registers the same 10 things, and the side bar lists only built screens.
  - Every new string goes into EXPERIENCE.md's Fixed strings, extending existing rows in place.
  - A refusal sentence is published once and pinned to the kernel's copy (AD-53).
- **Placement.**
  - OS management's side bar holds Processes, Locks, System usage, Databases, Devices, Namespaces, Local databases, License usage, Dashboard and External language servers. The Integrity log gets a position right after Databases (DW-1858).
  - Configuration (Local databases, keyed by name) stays separate from operations (Databases and Database details, keyed by directory).
  - Journals stay in System Operation, not the Logs area.
- **Dialogs are a closed set:**
  - delete confirmations;
  - the warnings that precede a non-delete write;
  - the few named dialogs, copy mappings among them.

  Everything else is a full-page route, and dialogs never stack. A new dialog joins EXPERIENCE.md's Dialogs line.
- **Destructive actions on a screen** use a one-level `confirm-dialog`.
  - The title names the action and the target.
  - The body states the consequence and ends "This cannot be undone."
  - A typed-name field requires an exact, case-sensitive match. An agent proposal carries no typed-name field.
  - A removal's impact appears as the dialog's advisory. A kernel refusal the dialog can foresee is stated when it opens.
  - 18.15's enable states its consequence before it is confirmed.
- **Async writes** show a running line, such as "<operation> running on the instance since <time>" or the copy-mappings form, then a finished line or the still-running sentence. The read-back reads "not checked, the write is still running".
- **Wizards and editors.**
  - A wizard is a vertical, linear `form-stepper`. Next validates the step, Back keeps values, and a step with an error says so in text.
  - An editor is a form page whose tabs mirror the classic editor: one form across all tabs, a sticky Save, and an unsaved-changes guard.
- **Path picker.**
  - It offers only the read's roots, and its one text entry is the relative name. The composed path is display only.
  - A `PATH.*` reason renders on the field it names.
  - A single root is preselected without marking the form dirty.
- **Gated controls** stay focusable with `aria-disabled` and name their reason. Self-protection refusals use the same mechanism.
- **Live data.**
  - Auto-refresh is one framework over a fixed roster of nine screens, Databases and Database details among them. It pauses while a proposal on the same entity type is live (AD-43).
  - A screen joins the roster only through both its descriptor and EXPERIENCE.md's roster row.

## Cross-Story Dependencies

- **18.15 (next).** Task 0 runs on the throwaway first.
  - Earlier research: the Part C plan in `spec-18-14`'s history (commit `4b73be11`) read the vendor source. Everything below is inference until Task 0 observes it.
    - `INTEROP` takes the query parameter `name` and no body, and it queues through `ShouldRunAsync`.
    - It answers 404 for an absent namespace and calls `%EnsembleMgr.EnableNamespace(name, 1)`.
    - That call creates mappings and a portal application, adds SQL and database privileges, and modifies the Interop Editors API application.
    - On a non-HealthShare instance, it also creates the ENSTEMP and SECONDARY databases unless the namespace is `USER`.
    - Many of its step failures are only displayed, not returned.
  - The plan halts if Task 0 contradicts this: a body, no queue, a change to any of OcuPilot's own objects, or an artifact the cleanup cannot remove.
  - The enable needs:
    - a `QUEUEDWRITES` entry;
    - its measured pairs, plus `%Admin_Operate:USE` for the poll;
    - the read-once rule;
    - `CLASSICPAGES` `%CSP.UI.Portal.Namespace`;
    - a consequence stated before it is confirmed.
  - It reuses `NamespacePort`'s started conversion and the namespace list's page-owned action and running line.
  - The ENSTEMP and SECONDARY databases it creates would appear on Local databases (inference).
- **18.16.** It extends 18.3's database screens: `DatabasePort`, the `database-configuration` type and Local databases.
  - Local databases' read is local-only, and its update refuses a remote target with `DATABASE.REMOTE`.
  - Measured at 18.3's plan:
    - A remote configuration is created without a live ECP link.
    - `GET /ecp/data-server/databases` blocked about 11 s and opened an ECP connection attempt.
    - A data server that a remote database uses cannot be deleted (409 #423).
  - The ECP connection gets its own AD-21 case, and its wait is bounded and stated before it starts.
  - The local allow-list cannot supply a remote directory (inference).
  - Classic pages: `.RemoteDatabases` and `Dialog.RemoteDatabase`, catalog shorthand under `%CSP.UI.Portal`. Confirm both names on the instance.
- **Later stories.**
  - 18.5: the journal integrity check (`Journal.File`, self-queued) needs `SELFQUEUEDTYPES`, and its directories are `PathPort` consumers (DW-1797).
  - 18.6: relies on the ECP routes alone.
  - 18.7: establishes the reachable encryption subset before any UI, because `Security.Encryption.Settings` is excluded by the v2 pin. Key material is write-only.
  - 18.10: spec-based REST services go through the management API.
  - 18.11: reads through its own port and gate, and the monitoring API's anonymous reachability never becomes OcuPilot's (AD-29).
  - 18.12: adds context-window management as the tool roster doubles, proxy and CA support as configuration, and a wallet-backed credential rung.
  - 18.13: keeps one idempotent installer, and the install-namespace, own-mapping, own-database and dismount predicates must keep holding.
- **Shipped machinery to build on:**
  - governance (Epic 14);
  - the copy-out draft (14.1);
  - the sanitizer (14.3);
  - port-built async writes: 12.3's `AuditPort`, 18.14's `NamespacePort` and 18.4's `DatabasePort`;
  - the read-back (16.17) and the removal impact (16.19);
  - `Kernel.Shell.Effective` (16.3);
  - `BackgroundTaskPort` (16.5, extended by 18.3 and 18.4);
  - `PathPort` and the path picker (18.1);
  - Epic 6's database reads.
- **Shared files.** Other epics run in parallel, so keep edits to these files add-only: the kernel, the registry, `Error.cls`, `Router.cls`, `Baseline.cls`, the test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts` and EXPERIENCE.md. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
