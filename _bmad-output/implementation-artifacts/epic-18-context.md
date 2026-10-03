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
- **Observe before building.** A Task 0 on the slot's throwaway measures each route's payload, effects, required pairs and audit events before any form or tool, and restores the state it found. Measure pair combinations, not one principal: a write must be impossible to half-apply under its declared pairs. Build on the pinned 2026.2 image; the inventory fixture is re-derived for 2027.1 when it ships. An endpoint the fixture does not cover means re-running the inventory audit.
- **The instance beats the specification.**
  - 18.19: the journal record list returns half its `maxRows` (checked: 10 gave 5, 40 gave 20). The vendor's counter steps twice per kept row, so doubling is exact only when no row is skipped. Ask for twice the page and mark the list when the limit is reached. It answers 202, so it runs through the async path.
  - 18.9: sql-privilege rows use `Object` and `Action` (checked), and a revoke is built from them. A role owner's `AdminOption` is the string `"0"` or `"1"` (reported), so compare the value.
  - 18.11: `BusyProcesses` always has ten rows; drop the empty ones.
- **Governance.** Every destructive or disruptive action defaults to disabled: deletes, dismount, truncate, encryption changes. Each new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change (a test fails otherwise). Through 2026-10-04 other new keys enter enabled unless the story says otherwise; after that, the owner decides.
- **Secrets and key material** are write-only: never returned, logged, kept in a proposal, or put in a queued body.
- **Routed ledger items**, each addressed or declined with a reason:
  - 18.7: DW-1555 (RSA and symmetric-key wallet secrets); DW-1774 (a story adding a listed screen extends every pinned side-bar list, found with `grep -l ocu-side-bar-label ui/browser` plus `ui/tools/navigation.test.mjs`; 18.8 and 18.9 meet it too).
  - 18.9: DW-236 (a widened SQL grant on OcuPilot's state table).
  - 18.13: DW-219 (uninstall half-states) and DW-423 (install-stamp retention).
- **Decision pending (DW-1966):** whether Journal settings refuses an existing database's directory as a journal directory, where the vendor writes its `iris.lck` beside the database's. The lock-file collision is an inference; refusing would amend AD-21's sixth case. It waits for the epic-close decision sheet.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort`, or a declared port built on it (`JournalPort`, `DatabasePort`), names `%Api.Admin.*`. It reads the outcome from both `tSC` and `%response.Status`. A vendor-class call is allowed only as a named AD-27 case. Only the vendor's own 404 reads as no rows; a 404 carrying another code (such as `JOURNAL.FILE.UNLISTED`) is a refusal and fails the read (AD-36).
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role on the throwaway. Never use `%Operator`, which holds `%DB_IRISSYS:RW`. Administrative resources are required at `USE`.
  - A screen may declare its own pair beside its area's set where the classic page demands it (External language servers; Journal settings' `%Admin_Journal:USE`). A holder of the area's set keeps every other screen.
  - A tool declares extra pairs when the vendor writes a database the screen's read does not (usually `%DB_IRISSYS:WRITE`), or when an endpoint the call must reach names one (`%Admin_Operate:USE` for an async poll or a journal file switch; PathPort's `%Admin_FileSystemAccess:USE` when a root is sent). It refuses a caller without them by name, before any port call. Journal settings' update needs `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`, because every changing settings `PUT` starts a new journal file; with only the first, the vendor stores the change and then fails. A narrower audience than the classic page is accepted.
  - The API's floor now admits `%Development:USE`. No new screen, route or tool relies on the floor alone.
  - Each write tool lists in `CLASSICPAGES` every classic page whose operation it performs, Hidden pages included, spelled as `NormalizePage` answers. A write performed by its descriptor's own page declares none (Journal settings).
- **Write kinds.**
  - Merge (AD-4): read fresh and send the complete set. Measure whether the PUT keeps omitted keys or upserts. A key the tool shows but never sets is a named exception: `Journal.Settings` omits `ArchiveName`, `wijdir` and `targwijsz`, and the vendor keeps an omitted key (measured).
  - Create (AD-54): fingerprint the name's absence.
  - Action (AD-51): a declared request type, no body, and a fingerprint subject covering every precondition field. A port-built body or a port-composed fresh-read type (`JournalPort`'s `STATE` and `DIRSTATE`) is a named entry. A tool may name `PRECONDITIONCODES`, the codes its fresh read refuses with when the precondition no longer holds. The mint and a screen action answer them as they are; inside a confirm they read as a 404, so the proposal closes target-changed (switch directory: `JOURNAL.SWITCHDIR.NOOTHER`).
  - Secret-only body (AD-56).
  - Screen and agent are two callers of one tool (AD-53, AD-55). The screen's caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Every write also has a read-back (AD-58), a port `Snippet` that mirrors every branch (AD-59), the change event, the per-target lock (`WRITE.TARGETBUSY` after 10 s, AD-34), and an impact for a removal. A write the vendor does not audit, measured with auditing on, becomes a named case in AD-15 and AD-53.
- **Ids (AD-13).** `journal-settings` is a singleton. A `journal-file` id is the instance's own spelling of the file name, kept exactly.
- **Field lists (AD-3).** Fields are derived from the endpoint's body template into checked-in generated sources. Stage 2 mutating endpoints that publish no template derive from the underlying class, pinned by a test. Every field is classified, and an unclassified field is emitted secret.
- **Async (AD-26).**
  - The port refuses a mutating type that would queue unless it is named in `QUEUEDWRITES`; a type that queues itself is also named in `SELFQUEUEDTYPES`. A queued body carries no secret, because the vendor writes it in plain text to a publicly readable task row and to the journal.
  - One poller per task, and its end is read once: a second read logs ERROR #7846 and raises the instance to Warning (reported). Past the bound a write answers "started" and its read-back is `unchecked`. No slice polls. A least-privileged caller's finished task row is left for the 24-hour sweep (AD-37).
  - Paths still to come: `Journal.Record` LIST (self-queued, 18.19) and `ECP.DataServer`'s server action (18.6).
- **Server paths (AD-21).**
  - Sixth case: the caller names a root and a relative name, never a path, and `PathPort` resolves it at the mint and again at the write. A vendor-writes directory (database, journal, Journal settings' two directories) is refused the manager directory and OcuPilot's served directory. Journal settings' directories must already exist and are never cleared. The overwrite refusal covers every database, volume and journal directory and the WIJ directory, read at call time.
  - Seventh case: a remote directory only as the data server's own listing spells it, through a bounded child-job listing.
  - Eighth case: `AdminPort` takes a file on `Journal.File` and `Journal.Record` only when it equals a `Name` the journal list answers at that call, read whole and never cached, and refuses any other `JOURNAL.FILE.UNLISTED`. The list stops at the first missing file (named limit).
- **Screen-only text.** A check's console lines reach the screen and the proposal card only (AD-39), never the model, a tool result, the ledger or a log.
- **Self-protection (AD-10).**
  - Predicates live once, in the kernel. Each is stated over the effect, evaluated inside the confirm's atomic transition, and pinned by a test that fails when it is removed. New prohibitions go in AD-10.
  - Disabling `%Service_WebGateway` or the superserver is already refused. 18.8 adds refusing an authentication change that would break OcuPilot's own sign-in.
  - 18.9's criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment, which permits every grant outside OcuPilot's own applications, roles and resources, at the strongest confirmation. Reconcile at the spec gate; the spine governs.
- **18.19, the journal record browser.** Its plan starts from Part C of `spec-18-5-journals.md` (Execution C, AC8, Task 0 step 3).
  - The read is a declared `Journal.Record` LIST behind the file guard, with file, offset, order and an optional filter (column, operator, value). The filter's column and operator come only from closed sets, because the vendor splices the operator into code it executes. The plan sends a partial filter unfiltered.
  - Record values (`NewValue`, `OldValue`, `GlobalReference`) reach the record dialog only, through a detail route that is not a declared read. They never reach a read tool, screen context, the model, the ledger or a log, under AD-48's reasoning: the payload has no schema and can hold patient data or a journaled secret. `GlobalNode` stays an ordinary field.
  - Named limits from the plan: a caller who cannot read some databases gets fewer rows per page, and the list may read complete while later records remain (inference until Task 0 measures it). A scan longer than the async bound fails. The page's rows and filter sit in the vendor's publicly readable task row until the port deletes it, or until the 24-hour sweep.
  - Write these amendments at the spec gate: AD-21 (the closed filter sets), AD-36 (record values screen-only), AD-26 (the doubled `maxRows`), AD-13 (`journal-record`), and AD-44 (`%cspapp.op.utilsysjournal`).
- **Per story, still to come.**
  - 18.7: `Security.Encryption.Settings` is excluded by the v2 pin. Establish the reachable subset on the instance before any UI. `Encryption.Settings` `AdminPassword` is a credential field.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read goes through its own port and gate; `/api/monitor`'s anonymous reach never becomes OcuPilot's. Only `MonitorPort` calls `PrometheusMetrics`. The vendor alerts read is never called, because it advances a shared cursor. The tail checks its offset against the file's identity and restarts on rotation.
  - 18.12: earlier turns already reach the model as message and reply only, capped at 65,536 characters, oldest dropped first (AD-24). A proxy is judged by the egress policy, HTTPS CONNECT-tunnels through it, and a marked-local endpoint bypasses it (AD-42). OcuPilot's provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled` are prohibited to change and restored at every start, so custom-CA support cannot rely on editing them (inference). The credential ladder never returns a value into a status or error.
  - 18.13: one idempotent installer with two entry points (AD-17); code in the install namespace, globals in OcuPilot's protected database (AD-9); the floor roles read the install namespace's routines and default globals databases (AD-21). The install-namespace, own-mapping and own-database predicates key off the namespace the API runs in, read at the write.
- **Spine amendments at the spec gate (Rule 20)** for anything new: AD-8 pairs, AD-10 predicates, AD-13 id rules, AD-21 path cases, AD-26 queued writes, AD-27 named cases, AD-36 read shapes, AD-44 `CLASSICPAGES`, AD-51 port-built bodies and precondition codes, and AD-15 and AD-53 unaudited writes.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract. The side bar lists only built screens at a position above 0. New strings go in EXPERIENCE.md's Fixed strings, and a refusal sentence is published once and pinned to the kernel copy. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- Journals stay in OS management (System Operation), not in Logs. Journals and Journal settings are the thirteenth and fourteenth OS management entries. Journal file details and Journal records are unlisted. Records are reached from a journal file by a screen arrival with server criteria, and continue with Next records.
- Dialogs are the closed set in EXPERIENCE.md's Dialogs line, and a new dialog joins it (18.19's record detail dialog). Everything else is a full-page route, and dialogs never stack.
- **Destructive confirm-dialog:** the title names the action and target, and the body states the consequence. A typed-name field needs an exact, case-sensitive match. An agent proposal has no typed name; it uses the destructive bar and Confirm. Non-destructive warnings use button-primary and may carry one flag or one whole-number field.
- **Editors and wizards:** an editor is a form-page whose tabs mirror the classic page, with one form, a sticky Save and an unsaved-changes guard. A wizard is the vertical, linear form-stepper. The path picker offers only allow-list roots plus a relative name, and shows a `PATH.*` reason on its field. A setting shown but never set is read-only with a hint naming the classic page.
- **Gated controls** stay focusable, `aria-disabled`, and name their reason.
- **Async writes** read "<operation> running on the instance since <time>", then "<operation> finished."
- **Log viewers** load bounded pages with Load newer. 18.11's live tail supersedes that only for sources that opt in.
- **Auto-refresh** is one framework over a nine-screen roster. A screen joins only through its descriptor and EXPERIENCE.md's roster row; the journal screens do not.
- **Key material and passwords** use the masked-secret-field: write-only, and empty after save.
- Every screen ships three suggested prompts.

## Cross-Story Dependencies

- Done: 18.1-18.5 and 18.14-18.18. The rest runs 18.19, then 18.6 onward. They build on `PathPort` and the picker (18.1), `NamespacePort` (18.2, 18.14, 18.15), `DatabasePort` and the Integrity log (18.3, 18.4), `RemoteDatabasePort`'s bounded ECP listing and license pre-check (18.16), `JournalPort`, `AdminPort`'s journal-file guard and the settings form (18.5, 18.18), `BackgroundTaskPort`, `MonitorPort`, `MgmntPort`, `WalletPort`, the LDAP (16.14) and Services (16.13) editors, `Kernel.Shell.Effective` (16.3), governance (14.2), the read-back (16.17), removal impact (16.19), the copy-out draft (14.1) and the sanitizer (14.3).
- 18.19 consumes 18.5's file guard and opens from a journal file. The 18.5 split left the record filter's closed sets, the doubled `maxRows` and the offset paging to 18.19, along with the `JournalRecords` test class, the descriptor, its prompts, strings and EXPERIENCE.md lines.
- 18.6: without an ECP license (IRIS Community), an ECP listing blocks for about 11 s and leaves client daemons running. 18.16 refuses at once when `$SYSTEM.License.NetworkEnabled()` is 0, and ECP actions should reuse that check (inference). The harvested ECP status implementation was never identified, so these screens rely on the routes alone.
- 18.8: the LDAP / Kerberos list and full editor already shipped (16.14), so the read-only LDAP view is likely covered (inference).
- 18.12's tool parity is delivered by each screen story. Its context budgeting matters as the tool roster grows.
- Epic 19 runs in parallel. Keep edits to shared files additive (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts`, EXPERIENCE.md, the spine), and regenerate generated files instead of hand-merging them.
