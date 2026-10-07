# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

OcuPilot reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service. Namespaces, databases and disk operations, journals, licensing and ECP, encryption, security configuration, SQL privileges, the web-application and monitoring extras, and installing into a chosen namespace stop being reasons to keep the classic portal open. Each screen arrives with a read tool and confirmed single-write tools derived from one descriptor, so the agent keeps pace with the portal. The stage builds about twenty screens on an experimental API, so every story rests on measured payloads, containment and self-protection. Remaining: 18.26 (spec validated), 18.27, 18.9 to 18.13, then the burn-down, 18.28.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Authentication and web-session options (superservers, MFT and the LDAP view split out)
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
- Story 18.28: The burn-down at the epic's close (merge-gate decision; not yet in the epics file)

## Requirements & Constraints

- **The contract (FR-80).** Each screen is one descriptor over one port. Its read tool and write field lists are derived from it, never hand-written. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Finer criteria are written when the story is planned.
- **Governance.** Every destructive or disruptive action ships with its governance key `false`. A story that adds a write key adds its line to `Kernel/Governance/Baseline.cls` in the same change. A non-destructive key ships enabled unless the criteria say otherwise.
- **Observe before building.** Task 0 on the throwaway measures each route's payload, effects, required pairs (in combination) and audit events before any form or tool exists. It restores the state it found and halts on a contradiction. Take privileges from the instance, not the specification. A probe prefix must neither match nor be matched by another suite's. Build on the pinned 2026.2 image.
- **Community license everywhere, CI included.** No test activates a license or key, opens an ECP connection, or leaves anything only a restart clears. Such success paths run through a test seam.
- **Secrets are write-only.** No read returns them. They are never logged, kept in a proposal or queued. The agent never holds key material.
- **Environment.** Slot A: dev instance `ocupilot`, throwaway `ocupilot-ci` (52776/1975). One test class per call, never two in flight.
- **Budgets.** `angular.json` `maximumWarning` is 3165kB. A story that crosses it re-bases the value and the literal in `angular-json.test.mjs` to the measured total (DW-1166). `maximumError` is 4000kB: stop and ask above 3800kB. The Fixed-strings bound in `strings.test.mjs` is 2900.
- **Test lessons.** Keep `$SYSTEM.Monitor.State()` out of before/after snapshots. Read a vendor audit row with a poll, not once. Take a signing-key snapshot only after a mint.
- **Specification mismatches.** 18.9: SQL-privilege rows name `Object` and `Action`, so build a revoke from those. A role owner's `AdminOption` is the string `"0"` or `"1"`, so compare the value. 18.11: `BusyProcesses` always has ten rows, so drop the empty ones.
- **Routed ledger items** (address each, or decline it with a reason):
  - 18.27: DW-1896, removing an LDAP configuration's last retrieved attribute through an AD-27 named case (`Security.LDAPConfigs.Modify` in `%SYS`).
  - 18.9: DW-236 (a widened SQL grant on `OcuPilot_Kernel_State` goes undetected), DW-1662 (the authorization-server tab's two pairs cannot create a configuration).
  - 18.12: DW-1756 (Guardrails lacks the turns-per-hour setting).
  - 18.13: DW-219 (uninstall's half-state paths), DW-423 (install-stamp retention), DW-1333 (the IPM archive carries no version floor).
  - 18.28 takes every open ledger item owned by the burn-down. Decided ones:
    - DW-1966: refuse an existing database's directory as a journal directory.
    - DW-1979: Newest first draws the newest records first.
    - DW-1981: the record browser's inputs get a `maxlength`.
    - DW-2007: a code-scoped `UNLOGGEDREFUSALS`, which takes 18.25's `Security.Superserver` `PUT` #5001 and 18.26's `Security.MFT` `DELETE` #5809.
    - DW-2085: Encrypt database is offered only while a database key is active.
    - DW-2086: an activation's fingerprint carries the reviewed key list (amends AD-51).
    - DW-2087: a first database-key activation is destructive, and its consequence names the `DBEncStartMode` change. The only reset is 18.23's `Settings` `PUT`.
    - DW-2100: measure, then decide whether AD-10's `STARTUPINTERACTIVE` arm widens.
    - DW-2126 (product call): naming a stored certificate's loss on an RSA regenerate.
    - DW-2149: remove the monitor state from five probes' snapshots.
    - DW-2160: apply 23.4's audit-read poll to `AuditVendorSecrets.AssertMasked` and its siblings.
    - Vendor-defect candidates DW-2124, 2125, 2137, 2139, 2146, 2147 and 2154 to 2156 stay on the owner's hold (not reported). OcuPilot already works around each one.
  - A screen-adding story extends its area's literal in `ui/tools/navigation.test.mjs`, with labels from `ui/browser/side-bar-spec.mjs` (DW-1774).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name `%Api.Admin.*`. A write tool declares its port, and the port builds the bodies, fresh reads and call sequences. The outcome comes from both `tSC` and `%response.Status`, and only the vendor's 404 means no rows. Calling a vendor class directly needs a named AD-27 case. A failure outside `UNLOGGEDREFUSALS` logs at severity 2 and raises the instance's alert state.
- **Pairs (AD-8, AD-29, AD-44).** `ResourcesOR()` is only a lower bound. Read the backing class's check and run the call as a least-privileged role. Administrative resources are required at `USE`. A tool declares each extra pair and refuses by name before any port call. `CLASSICPAGES` lists each extra classic page whose operation a write performs.
- **Write kinds.** A merge (AD-4) reads fresh and sends the complete set. A create (AD-54) fingerprints the name's absence, since admin `PUT`s are often upserts. An action (AD-51) fingerprints each precondition. An empty secret clears a value only under `CLEARABLESECRETS` (AD-56). The screen and the agent are two callers of one tool (AD-53, AD-55). The screen's Save mints nothing and emits no marker, but it holds the tool's per-target lock (AD-34). Each write also has:
  - a read-back (AD-58), and a create whose declared read is a list row re-reads through `READBACKTOOL`;
  - a port `Snippet` (AD-59) and a change event (AD-14);
  - `WRITE.TARGETBUSY` after 10 s.
  A write the vendor does not audit is a named AD-15 and AD-53 case, at the next free ordinal.
- **Ids, fields and reads (AD-3, AD-13, AD-36).**
  - A new entity type joins the kernel's closed enum.
  - Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, which are regenerated, never hand-merged.
  - An unclassified field is emitted as a secret.
  - One declared read serves both the screen and the tool, and no read answers key material.
- **Async (AD-26).** A write that would queue is refused unless `QUEUEDWRITES` names it, and a secret-carrying body is never queued. One poller reads a task's end once. Past the bound the write answers "started" (`PORT.STARTED`), and its read-back is `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path. `PathPort` resolves a root plus a relative name at the mint and again at the write. A vendor-writes directory is refused for the manager directory, OcuPilot's served directory and every database, volume, journal and WIJ directory.
- **Text and self-protection.** OcuPilot answers in its own sentences, and vendor text is logged, never sent (AD-39). New error codes go in an area error class: `Api/Error.cls` is near the compiler's parameter limit and gains only dispatch lines. AD-10's predicates live once in the kernel and run inside the confirm's atomic transition, each pinned by a test. A grant outside OcuPilot's own applications, roles and resources is permitted at the strongest confirmation.
- **MFT connections (18.26).**
  - `Security.MFT` is an upsert that keeps omitted keys. A create requires all five fields, and `Service` is create-only.
  - The id is the name, kept exactly.
  - The tools need only Security's set.
  - Create and update declare `%CSP.UI.Portal.MFT.Connection` in `CLASSICPAGES`. The delete and the token revoke declare none.
  - No vendor event audits these writes (the eighteenth AD-15 and AD-53 case).
  - `MftPort` answers the revoke's fresh read through a port-composed `STATE` (`GET` plus the list row's `IsAuthorized`) and refuses 409 `MFT.TOKEN.NONE`.
  - `MftPort` re-reads a `DELETE` the vendor answered with an error: an absent connection means the delete is done.
- **Later stories.**
  - 18.27: closed unbuilt. An LDAP configuration's read requires `%Admin_Secure:USE` and `%DB_IRISSYS:READ`: the admin API's gate admits `%Admin_Operate`, but `Security.LDAPConfigs` refuses that caller, and the classic read-only pages fail for it (AD-8).
  - 18.9: the criterion that refuses `%All` and `%Admin_*` grants predates AD-10's owner amendment, which permits them at the strongest confirmation. Reconcile at the spec gate, where the spine governs. Password validation wraps the instance's own validator.
  - 18.10: spec-based REST services go through `MgmntPort`.
  - 18.11: each read uses its own port and gate. Only `MonitorPort` calls `PrometheusMetrics`. Never call the vendor's alerts read, which advances a shared cursor. The live tail long-polls with a heartbeat, checks the file's identity and restarts on rotation.
  - 18.12: earlier turns are capped at 65,536 characters, oldest dropped first (AD-24). The egress policy judges a proxy (AD-42). AD-10 protects OcuPilot's provider SSL configuration, so custom-CA support cannot rely on editing it (inference). The wallet rung never returns a value into a status.
  - 18.13: one idempotent installer with two entry points (AD-17). Code goes in the install namespace and globals in OcuPilot's protected database (AD-9). The own-namespace predicates key off the namespace the API runs in.
- **Encryption, for the burn-down.** `Port/EncryptionPort` builds every `Security.Encryption.*` body, and its rules are in `Area/Security/EncryptionRules.cls`. 18.23's `Settings` merge sends `AuditEncrypt` exactly as the fresh read holds it unless that value was changed. Interactive activation is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted.
- **Spine amendments (Rule 20).** Each new pair, predicate, entity type, path case, queued write, named case, read shape, `CLASSICPAGES` entry or unaudited write is written into the spine at the spec gate.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts. The side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, and each refusal sentence is published once. Edit EXPERIENCE.md in place so its cited line numbers hold. Keep one key per value in `strings.ts`. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. Everything else is a full-page route.
- A destructive confirm names the action and the target, states the consequence, and requires the name typed exactly. An agent proposal uses the destructive bar.
- Editors are form pages with tabs that mirror the classic page, a sticky Save and an unsaved-changes guard. A setting that is shown but never set is read-only, with a hint naming the classic page.
- Gated controls stay focusable and `aria-disabled`, and name their reason through `aria-describedby`.
- A wait that may block is bounded and stated before it starts.
- Key material uses the masked secret field. A password typed at confirm needs a masked row on the agent's card.

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.8 and 18.14 to 18.25. Next: 18.26, 18.27, 18.9 to 18.13, then 18.28. 18.26 and 18.27 are independent.
- 18.12 takes in 18.24's wallet key tools. Each screen story enlarges the agent's roster, which makes 18.12's context budgeting more pressing. The burn-down's DW-2086 and DW-2087 amend 18.22's activations.
- **Epic 20 runs in parallel on slot B.** It overlaps 18.12 at 20.12 (the tool registry) and 18.13 at 20.1 (per-namespace state, AD-44's `appliesWhen`). Two of its stories touch Epic 18's descriptors:
  - 20.14 gives every surface that relies on AD-8's administrative floor alone its own pair, then widens the floor to `%Ens_Portal` holders.
  - 20.15 adds a runtime adjustment to a screen's pairs.
  The spine now has 63 ADs, including AD-62 (`InteropPort`) and AD-63 (the vendor's editors in a same-origin frame).
- Shared files take add-only edits, with one-line lists and roster counts unioned at merges: the kernel and registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, the test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md and the spine.
