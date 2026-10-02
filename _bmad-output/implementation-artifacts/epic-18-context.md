# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring OcuPilot to System Administration and System Operation parity on the experimental `/api/admin` v2 service: namespaces and mappings, local and remote databases and their disk operations, journals, licensing, ECP, encryption, superservers, authentication options, MFT, SQL privileges, and the web-application and monitoring extras. Each screen arrives with its read tool and confirmed single-write tools from one descriptor, so the agent grows with the portal. Stage 2 is the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, so measured payloads, containment and self-protection carry the weight.

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

## Requirements & Constraints

- **One contract (FR-80).** One descriptor over one port per screen. The read tool and the write field lists are derived, with no hand-written tool code. Every write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate is the caller's own privileges, checked at call time. Acceptance is this contract plus each row's backing route; finer criteria are written at the story's plan, never in advance.
- **Observe before building.** Measure each write's payload, effects and required pairs on the slot's throwaway before any form or tool. Build on the pinned 2026.2 image; the inventory fixture is re-derived for 2027.1 when it ships. An endpoint the fixture does not cover means re-running the inventory audit.
- **The instance beats the specification.** 18.5: the journal record list returns half its `maxRows` (checked), so ask for double and mark the list at the limit; it answers 202, so it uses the async path. `switch-dir` takes no body and swaps between the primary and alternate directories, answering 409 when they are the same (vendor source; Task 0 measures it). 18.9: sql-privilege rows use `Object` and `Action` (checked); a role owner's `AdminOption` is the string `"0"` or `"1"` (reported), so compare the value. 18.11: `BusyProcesses` always has ten rows; drop the empty ones.
- **Governance.** Every destructive or disruptive action defaults to disabled: deletes, dismount, truncate, encryption changes. Each new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change (a test fails otherwise). Through 2026-10-04 other new keys enter enabled unless the story says otherwise; after that, the owner decides.
- **Secrets and key material** are write-only: never returned, logged, kept in a proposal, or put in a queued body.
- **Routed ledger items**, each addressed or declined with a reason:
  - 18.5: DW-1797 (put former journal directories and the WIJ directory in PathPort's refusal).
  - 18.7: DW-1555 (RSA and symmetric-key wallet secrets); DW-1774 (a screen-adding story extends every pinned side-bar list, found with `grep -l ocu-side-bar-label ui/browser` plus `ui/tools/navigation.test.mjs`; 18.8 and 18.9 meet it too).
  - 18.9: DW-236 (a widened SQL grant on OcuPilot's state table).
  - 18.13: DW-219 (uninstall half-states) and DW-423 (install-stamp retention).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort`, or a declared port built on it, names `%Api.Admin.*`, and it reads the outcome from both `tSC` and `%response.Status`. A vendor-class call is allowed only as a named AD-27 case, for something the admin API cannot carry.
- **Pairs (AD-8, AD-29, AD-44).**
  - `ResourcesOR()` is a lower bound. Read the backing class's own check, then run the call as a purpose-built least-privileged role on the throwaway. Never use `%Operator`, which holds `%DB_IRISSYS:RW`. Administrative resources are required at `USE`.
  - A tool may declare extra pairs in two cases: the vendor writes a database the screen's read does not (usually `%DB_IRISSYS:WRITE`), or an endpoint the call must reach names the pair (`%Admin_Operate:USE` for an async poll; PathPort's `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`). The tool refuses a caller without them by name, before any port call.
  - Each write tool lists in `CLASSICPAGES` every classic page whose operation it performs, as class names read on the instance.
- **Write kinds.**
  - Merge (AD-4): read fresh and send the complete set; measure whether the PUT keeps omitted keys or upserts.
  - Create (AD-54): fingerprint the name's absence.
  - Action (AD-51): a declared request type, no body, and a fingerprint subject covering every precondition field. A body the port builds is a named AD-51 entry.
  - Secret-only body (AD-56).
  - Screen and agent are two callers of one tool (AD-53, AD-55). The screen's caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Every write also has a read-back (AD-58), a port `Snippet` that mirrors every branch (AD-59), the change event, the per-target lock, and an impact for a removal. A write the vendor does not audit, measured with auditing on, becomes a named case in AD-15 and AD-53.
- **Field lists (AD-3).** Fields are derived from the endpoint's body template into checked-in generated sources (`ToolFields.cls`, `screens.generated.ts`). Eleven Stage 2+ mutating endpoints publish no template, so they derive from the underlying class, pinned by a test. Every field is classified in `Classification.cls`, and an unclassified field is emitted secret. `Encryption.Settings` `AdminPassword` is a credential field.
- **Async (AD-26).**
  - The port refuses a mutating type that would queue unless it is named in `QUEUEDWRITES`; a type that queues itself is also named in `SELFQUEUEDTYPES`. A queued body must carry no secret, because the vendor writes it in plain text to a publicly readable task row and to the journal.
  - One poller per task, and its end is read once: a second read logs ERROR #7846 and raises the instance to Warning (reported).
  - Past the bound a write answers "started", and its read-back is `unchecked`. No slice polls.
  - Paths still to come: `Journal.File`'s integrity check, `Journal.Record` LIST (self-queued), and `ECP.DataServer`'s server action.
- **Server paths (AD-21, sixth case).**
  - The caller names a root and a relative name, never a path. `PathPort` resolves it at the mint and again at the write.
  - A tool's kind (`file`, `directory` or `source`), overwrite and vendor-writes are constants. A file the operation reads, such as a key to activate, is a `source`.
  - A journal directory is a vendor-writes directory, so the manager directory is refused.
- **Self-protection (AD-10).**
  - Predicates live once, in the kernel. Each is stated over the effect, evaluated inside the confirm's atomic transition, and pinned by a test that fails when it is removed. New prohibitions go in AD-10.
  - Disabling `%Service_WebGateway` or the superserver is already refused. 18.8 adds refusing an authentication change that would break OcuPilot's own sign-in.
  - 18.9's criterion refusing `%All` and `%Admin_*` grants predates AD-10's amendment, which permits every grant outside OcuPilot's own applications, roles and resources, at the strongest confirmation. Reconcile at the spec gate; the spine governs.
- **Per story.**
  - 18.7: `Security.Encryption.Settings` is excluded by the v2 pin. Establish the reachable subset on the instance before any UI.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read goes through its own port and gate; `/api/monitor`'s anonymous reach never becomes OcuPilot's. Only `MonitorPort` calls `PrometheusMetrics`. The vendor alerts read is never called, because it advances a shared cursor. The tail checks its offset against the file's identity and restarts on rotation.
  - 18.12:
    - Earlier turns already reach the model as message and reply only, 65,536 characters with the oldest dropped first (AD-24).
    - A proxy is judged by the egress policy, HTTPS CONNECT-tunnels through it, and a marked-local endpoint bypasses it (AD-42).
    - OcuPilot's provider SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled` are prohibited to change and restored at every start, so custom-CA support cannot rely on editing them (inference).
    - The credential ladder never returns a value into a status or error.
  - 18.13: one idempotent installer with two entry points (AD-17). Code lives in the install namespace and globals in OcuPilot's protected database (AD-9). The floor roles read the install namespace's routines and default globals databases (AD-21). The install-namespace, own-mapping and own-database predicates key off the namespace the API runs in, read at the write.
- **Spine amendments at the spec gate (Rule 20)** for anything new: AD-8 pairs, AD-10 predicates, AD-21 path cases, AD-26 queued writes, AD-27 named cases, AD-44 `CLASSICPAGES`, AD-51 port-built bodies, and AD-15 and AD-53 unaudited writes.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract. The side bar lists only built screens. New strings go in EXPERIENCE.md's Fixed strings, and a refusal sentence is published once and pinned to the kernel copy. After editing EXPERIENCE.md or epics.md, run `cd ui && npm run test:tools`.
- Journals stay in System Operation (OS management here, inference), not in Logs.
- Dialogs are the closed set in EXPERIENCE.md's Dialogs line, and a new dialog joins it. Everything else is a full-page route, and dialogs never stack.
- **Destructive confirm-dialog:** the title names the action and target, and the body states the consequence. A typed-name field needs an exact, case-sensitive match. An agent proposal has no typed name; it uses the destructive bar and Confirm. Non-destructive warnings use button-primary and may carry one flag or one whole-number field.
- **Editors and wizards:** an editor is a form-page whose tabs mirror the classic page, with one form, a sticky Save and an unsaved-changes guard. A wizard is the vertical, linear form-stepper. The path picker offers only allow-list roots plus a relative name, and shows a `PATH.*` reason on its field.
- **Gated controls** stay focusable, `aria-disabled`, and name their reason.
- **Async writes** read "<operation> running on the instance since <time>", then "<operation> finished."
- **Log viewers** load bounded pages with Load newer. 18.11's live tail supersedes that only for sources that opt in.
- **Auto-refresh** is one framework over a nine-screen roster. A screen joins only through its descriptor and EXPERIENCE.md's roster row.
- **Key material and passwords** use the masked-secret-field: write-only, and empty after save.

## Cross-Story Dependencies

- Done: 18.1-18.4 and 18.14-18.17. The rest builds on:
  - `PathPort` and the picker (18.1);
  - `NamespacePort` (18.2, 18.14, 18.15);
  - `DatabasePort` and the Integrity log (18.3, 18.4);
  - `RemoteDatabasePort`'s bounded ECP listing and license pre-check (18.16);
  - `BackgroundTaskPort`, `MonitorPort`, `MgmntPort` and `WalletPort`;
  - the LDAP (16.14) and Services (16.13) editors;
  - `Kernel.Shell.Effective` (16.3), governance (14.2), the read-back (16.17), removal impact (16.19), the copy-out draft (14.1) and the sanitizer (14.3).
- 18.6: without an ECP license (IRIS Community), an ECP listing blocks for about 11 s and leaves client daemons running. 18.16 refuses at once when `$SYSTEM.License.NetworkEnabled()` is 0, and ECP actions should reuse that check (inference). The harvested ECP status implementation was never identified, so these screens rely on the routes alone.
- 18.8: the LDAP / Kerberos list and full editor already shipped (16.14), so the read-only LDAP view is likely covered (inference).
- 18.12's tool parity is delivered by each screen story. Its context budgeting matters as the tool roster grows.
- Epic 19 runs in parallel. Keep edits to shared files additive (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts`, EXPERIENCE.md), and regenerate generated files instead of hand-merging them.
