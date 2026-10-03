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
- **Observe before building.** A Task 0 on the slot's throwaway measures each route's payload, effects, required pairs and audit events before any form or tool, and restores the state it found. Build on the pinned 2026.2 image; the inventory fixture is re-derived for 2027.1 when it ships. An endpoint the fixture does not cover means re-running the inventory audit.
- **The instance beats the specification.**
  - 18.19: the journal record list returns half its `maxRows` (checked). The vendor's counter steps twice per kept row, so doubling is exact only when no row is skipped. Ask for twice the page and mark the list when the limit is reached. It answers 202, so it runs through the async path.
  - 18.9: sql-privilege rows use `Object` and `Action` (checked), and a revoke is built from them. A role owner's `AdminOption` is the string `"0"` or `"1"` (reported), so compare the value.
  - 18.11: `BusyProcesses` always has ten rows; drop the empty ones.
- **Governance.** Every destructive or disruptive action defaults to disabled: deletes, dismount, truncate, encryption changes. Each new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change (a test fails otherwise). Through 2026-10-04 other new keys enter enabled unless the story says otherwise; after that, the owner decides. The journal settings key lands with 18.18.
- **Secrets and key material** are write-only: never returned, logged, kept in a proposal, or put in a queued body.
- **Routed ledger items**, each addressed or declined with a reason:
  - 18.18: DW-1950 (a switch-directory proposal confirmed after the alternate stops being distinct answers 500; map the fresh read's `NOOTHER` to the target-changed refusal).
  - 18.7: DW-1555 (RSA and symmetric-key wallet secrets); DW-1774 (a story adding a listed screen extends every pinned side-bar list, found with `grep -l ocu-side-bar-label ui/browser` plus `ui/tools/navigation.test.mjs`; 18.8, 18.9 and 18.18 meet it too).
  - 18.9: DW-236 (a widened SQL grant on OcuPilot's state table).
  - 18.13: DW-219 (uninstall half-states) and DW-423 (install-stamp retention).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort`, or a declared port built on it (`JournalPort`, `DatabasePort`), names `%Api.Admin.*`. It reads the outcome from both `tSC` and `%response.Status`. A vendor-class call is allowed only as a named AD-27 case. A read answered with the vendor's own 404 is an unlogged absence; a 404 carrying another code is a refusal and fails the read (AD-36).
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role on the throwaway. Never use `%Operator`, which holds `%DB_IRISSYS:RW`. Administrative resources are required at `USE`.
  - A tool declares extra pairs when the vendor writes a database the screen's read does not (usually `%DB_IRISSYS:WRITE`), or when an endpoint the call must reach names one (`%Admin_Operate:USE` for an async poll; PathPort's `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`). It refuses a caller without them by name, before any port call. A narrower audience than the classic page is accepted (18.5's switch directory needs `%DB_IRISSYS:WRITE` and `%Admin_Manage:USE`).
  - The API's floor now admits `%Development:USE`. No new screen, route or tool relies on the floor alone; each declares the pairs its classic page's `RESOURCE` implies.
  - Each write tool lists in `CLASSICPAGES` every classic page whose operation it performs, Hidden pages included, spelled as `NormalizePage` answers on the instance.
- **Write kinds.**
  - Merge (AD-4): read fresh and send the complete set. Measure whether the PUT keeps omitted keys or upserts; a key the tool shows but never sets is a named exception.
  - Create (AD-54): fingerprint the name's absence.
  - Action (AD-51): a declared request type, no body, and a fingerprint subject covering every precondition field. A port-built body or a port-composed fresh-read type (`JournalPort`'s `STATE` and `DIRSTATE`) is a named AD-51 entry.
  - Secret-only body (AD-56).
  - Screen and agent are two callers of one tool (AD-53, AD-55). The screen's caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Every write also has a read-back (AD-58), a port `Snippet` that mirrors every branch (AD-59), the change event, the per-target lock (`WRITE.TARGETBUSY` after 10 s, AD-34), and an impact for a removal. A write the vendor does not audit, measured with auditing on, becomes a named case in AD-15 and AD-53.
- **Field lists (AD-3).** Fields are derived from the endpoint's body template into checked-in generated sources. Stage 2 mutating endpoints that publish no template derive from the underlying class, pinned by a test. Every field is classified, and an unclassified field is emitted secret. `Encryption.Settings` `AdminPassword` is a credential field.
- **Async (AD-26).**
  - The port refuses a mutating type that would queue unless it is named in `QUEUEDWRITES`; a type that queues itself is also named in `SELFQUEUEDTYPES`. A queued body carries no secret, because the vendor writes it in plain text to a publicly readable task row and to the journal.
  - One poller per task, and its end is read once: a second read logs ERROR #7846 and raises the instance to Warning (reported). Past the bound a write answers "started" and its read-back is `unchecked`. No slice polls. A least-privileged caller's finished task row is left for the 24-hour sweep (AD-37).
  - Paths still to come: `Journal.Record` LIST (self-queued, 18.19) and `ECP.DataServer`'s server action (18.6).
- **Server paths (AD-21).**
  - Sixth case: the caller names a root and a relative name, never a path, and `PathPort` resolves it at the mint and again at the write. A tool's kind (`file`, `directory` or `source`), overwrite and vendor-writes are constants. A vendor-writes directory (database, journal) is refused the manager directory and OcuPilot's served directory, and a database's directory is always named, never left for the vendor to default. The overwrite refusal covers every database, volume and journal directory and the WIJ directory, read at call time.
  - Seventh case: a remote directory only as the data server's own listing spells it, through a bounded child-job listing.
  - Eighth case: `AdminPort` takes a journal file on `Journal.File` and `Journal.Record` only when it equals a `Name` the journal list answers at that call, and refuses any other `JOURNAL.FILE.UNLISTED`. The list stops at the first missing file (named limit).
- **Screen-only text.** A check's console lines reach the screen and the proposal card only (AD-39), never the model, a tool result, the ledger or a log.
- **Self-protection (AD-10).**
  - Predicates live once, in the kernel. Each is stated over the effect, evaluated inside the confirm's atomic transition, and pinned by a test that fails when it is removed. New prohibitions go in AD-10.
  - Disabling `%Service_WebGateway` or the superserver is already refused. 18.8 adds refusing an authentication change that would break OcuPilot's own sign-in.
  - 18.9's criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment, which permits every grant outside OcuPilot's own applications, roles and resources, at the strongest confirmation. Reconcile at the spec gate; the spine governs.
- **Per story.**
  - 18.18 and 18.19 are planned as Parts B (AC7) and C (AC8) of `spec-18-5-journals.md`. Its proposed amendments for them are not yet in the spine; write them at each spec gate:
    - 18.18: settings are a merge over `Journal.Settings` that omits `ArchiveName`, `wijdir` and `targwijsz` (shown, never set; a WIJ change activates at once). Directories come only from the picker and must already exist. The screen's own pair is `%Admin_Journal:USE`: the classic page requires it with `%Admin_Manage`, while the admin API takes either.
    - 18.19: the filter's column and operator come only from closed sets, because the vendor executes the operator as code. Record values reach the record dialog only, never a read tool, context, the ledger or a log, under AD-48's reasoning.
  - 18.7: `Security.Encryption.Settings` is excluded by the v2 pin. Establish the reachable subset on the instance before any UI.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read goes through its own port and gate; `/api/monitor`'s anonymous reach never becomes OcuPilot's. Only `MonitorPort` calls `PrometheusMetrics`. The vendor alerts read is never called, because it advances a shared cursor. The tail checks its offset against the file's identity and restarts on rotation.
  - 18.12: earlier turns already reach the model as message and reply only, capped at 65,536 characters, oldest dropped first (AD-24). A proxy is judged by the egress policy, HTTPS CONNECT-tunnels through it, and a marked-local endpoint bypasses it (AD-42). OcuPilot's provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled` are prohibited to change and restored at every start, so custom-CA support cannot rely on editing them (inference). The credential ladder never returns a value into a status or error.
  - 18.13: one idempotent installer with two entry points (AD-17); code in the install namespace, globals in OcuPilot's protected database (AD-9); the floor roles read the install namespace's routines and default globals databases (AD-21). The install-namespace, own-mapping and own-database predicates key off the namespace the API runs in, read at the write.
- **Spine amendments at the spec gate (Rule 20)** for anything new: AD-8 pairs, AD-10 predicates, AD-13 id rules, AD-21 path cases, AD-26 queued writes, AD-27 named cases, AD-36 read shapes, AD-44 `CLASSICPAGES`, AD-51 port-built bodies, and AD-15 and AD-53 unaudited writes.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract. The side bar lists only built screens at a position above 0. New strings go in EXPERIENCE.md's Fixed strings, and a refusal sentence is published once and pinned to the kernel copy. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- Journals stay in OS management (System Operation), not in Logs. Journals is listed; Journal settings (18.18) is a listed form-page after it. Journal file details and Journal records are unlisted, and records are reached from a file by a screen arrival with server criteria and Next records.
- Dialogs are the closed set in EXPERIENCE.md's Dialogs line, and a new dialog joins it (18.19's record detail dialog). Warnings precede switching the journal file or directory and a journal integrity check, which carries a check-every-record flag. Everything else is a full-page route, and dialogs never stack.
- **Destructive confirm-dialog:** the title names the action and target, and the body states the consequence. A typed-name field needs an exact, case-sensitive match. An agent proposal has no typed name; it uses the destructive bar and Confirm. Non-destructive warnings use button-primary and may carry one flag or one whole-number field.
- **Editors and wizards:** an editor is a form-page whose tabs mirror the classic page, with one form, a sticky Save and an unsaved-changes guard. A wizard is the vertical, linear form-stepper. The path picker offers only allow-list roots plus a relative name, and shows a `PATH.*` reason on its field.
- **Gated controls** stay focusable, `aria-disabled`, and name their reason.
- **Async writes** read "<operation> running on the instance since <time>", then "<operation> finished."
- **Log viewers** load bounded pages with Load newer. 18.11's live tail supersedes that only for sources that opt in.
- **Auto-refresh** is one framework over a nine-screen roster. A screen joins only through its descriptor and EXPERIENCE.md's roster row; the journal screens do not.
- **Key material and passwords** use the masked-secret-field: write-only, and empty after save.

## Cross-Story Dependencies

- Done: 18.1-18.5 and 18.14-18.17. The rest runs 18.18, 18.19, then 18.6 onward, and builds on `PathPort` and the picker (18.1), `NamespacePort` (18.2, 18.14, 18.15), `DatabasePort` and the Integrity log (18.3, 18.4), `RemoteDatabasePort`'s bounded ECP listing and license pre-check (18.16), `JournalPort` and `AdminPort`'s journal-file guard (18.5), `BackgroundTaskPort`, `MonitorPort`, `MgmntPort`, `WalletPort`, the LDAP (16.14) and Services (16.13) editors, `Kernel.Shell.Effective` (16.3), governance (14.2), the read-back (16.17), removal impact (16.19), the copy-out draft (14.1) and the sanitizer (14.3).
- 18.18 and 18.19 take Task 0 steps 6 and 3 of the 18.5 spec. 18.18 re-points `Test/ToolWrite`'s legs that use `Journal.Settings` `PUT` as an unissued type, and it makes primary equal to alternate reachable (DW-1950). 18.19 consumes the guard; its page's rows and filter sit in the vendor's publicly readable task row until the port deletes it (named limit).
- 18.6: without an ECP license (IRIS Community), an ECP listing blocks for about 11 s and leaves client daemons running. 18.16 refuses at once when `$SYSTEM.License.NetworkEnabled()` is 0, and ECP actions should reuse that check (inference). The harvested ECP status implementation was never identified, so these screens rely on the routes alone.
- 18.8: the LDAP / Kerberos list and full editor already shipped (16.14), so the read-only LDAP view is likely covered (inference).
- 18.12's tool parity is delivered by each screen story. Its context budgeting matters as the tool roster grows.
- Epic 19 runs in parallel. Keep edits to shared files additive (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts`, EXPERIENCE.md, the spine), and regenerate generated files instead of hand-merging them.
