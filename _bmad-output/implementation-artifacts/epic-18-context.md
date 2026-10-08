# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

OcuPilot reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, so no such task needs the classic portal. Each screen brings a read tool and confirmed single-write tools from one descriptor, and every story rests on measured payloads, containment and self-protection. Still to build: SQL privileges and the user and role page extras (18.9, 18.28, 18.29), the web-application and monitoring extras (18.10, 18.11), the agent's growth (18.12) and multi-namespace install (18.13), then the burn-down (18.30).

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Authentication and web-session options (superservers, MFT and the LDAP view split out)
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
- Story 18.30: The burn-down at the epic's close (merge-gate decision; not yet in the epics file)

## Requirements & Constraints

- **The contract (FR-80).** Each screen is one descriptor over one port; its read tool and write field lists derive from it, never hand-written. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker; every read is bounded and reports truncation; every gate checks the caller's own privileges at call time.
- **Governance.** Every destructive or disruptive action ships with its governance key `false`; a story adding a write key adds its line to `Kernel/Governance/Baseline.cls` in the same change. A non-destructive key ships enabled unless the criteria say otherwise.
- **Its own pair, never the floor alone.** The API's floor admits any `%Admin_*` resource or `%Development:USE` (and `%Ens_Portal:USE` after 20.14). Every new screen, route and tool declares its own pair, matching its classic page's `RESOURCE` in `irissys/`; 20.14 pins the floor-only list (inference: a new floor-only surface turns it red).
- **Observe before building.** Task 0 on the throwaway measures each route's payload, effects, required pairs (together) and audit events before any form or tool exists, restores what it found and halts on a contradiction. Privileges come from the instance, not the specification. A probe prefix matches no other suite's. Pinned 2026.2 image.
- **Community license, CI included.** No test activates a license or key, opens an ECP connection, or leaves anything only a restart clears; such paths run through a test seam.
- **Secrets are write-only:** never read back, logged, kept in a proposal or queued; the agent never holds key material.
- **Environment.** Slot A: dev `ocupilot`, throwaway `ocupilot-ci` (52776/1975). One test class in flight at a time.
- **Budgets.** `angular.json` `maximumWarning` is 3165kB; a story that crosses it re-bases the value and the literal in `angular-json.test.mjs` to the measured total (DW-1166). `maximumError` is 4000kB: stop and ask above 3800kB. The Fixed-strings bound in `strings.test.mjs` is 2900.
- **Test lessons.** Keep `$SYSTEM.Monitor.State()` out of before/after snapshots. Poll a vendor audit row, never read it once. Take a signing-key snapshot only after a mint. A probe fixture creates and removes every vendor object it needs; a fresh CI instance lacks the dev instance's. A new entity type moves the count in two descriptor tests (61 now).
- **Ledger items routed to the remaining stories** (address each, or decline it with a reason):
  - 18.9: DW-236's refusal half (a SQL grant or revoke on OcuPilot's own schemas).
  - 18.29: DW-1662 (the authorization-server tab's two pairs cannot create a configuration: the editor pre-ticks default roles the create refuses).
  - 18.12: DW-1756 (Guardrails lacks the turns-per-hour setting).
  - 18.13: DW-219 (uninstall's half-state paths), DW-423 (install-stamp retention), DW-1333 (no version floor in the IPM archive), DW-2172 (DW-236's detection half: a grant on OcuPilot's schemas widened outside OcuPilot).
- **The burn-down (18.30)** takes every open ledger item it owns. Decided ones:
  - DW-1896: remove an LDAP configuration's last attribute via `Security.LDAPConfigs.Modify` only if measured under the caller's own `%Admin_Secure`, else wontfix.
  - DW-1966: refuse a database's directory as a journal directory (amends AD-21). DW-1979: Newest first draws the newest records. DW-1981: record-browser inputs get a `maxlength`.
  - DW-2007: a code-scoped `UNLOGGEDREFUSALS`, taking `Security.Superserver` `PUT` #5001 and `Security.MFT` `DELETE` #5809.
  - DW-2085: Encrypt database only while a database key is active. DW-2086: an activation's fingerprint carries the reviewed key list (amends AD-51). DW-2087: a first database-key activation is destructive and names the `DBEncStartMode` change. DW-2100: measure whether AD-10's `STARTUPINTERACTIVE` arm widens.
  - DW-2126: name a stored certificate's loss on an RSA regenerate. DW-2149: drop the monitor state from five probes' snapshots. DW-2160: 23.4's audit-read poll for `AuditVendorSecrets.AssertMasked` and siblings. DW-2167: the vendor's 404 #822 is an access refusal, not an absence.
  - Vendor-defect candidates DW-2095, 2124, 2125, 2137, 2139, 2144, 2146, 2147, 2154 to 2156, 2168, 2169 and 18.9's three SQL ones stay on the owner's hold, unreported; OcuPilot works around each.
- A screen-adding story extends its area's literal in `ui/tools/navigation.test.mjs`, with labels from `ui/browser/side-bar-spec.mjs` (DW-1774).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name `%Api.Admin.*`. A write tool declares its port, which builds the bodies, fresh reads and call sequences. The outcome reads both `tSC` and `%response.Status`; only the vendor's 404 means no rows. Calling a vendor class directly needs a named AD-27 case. A failure outside `UNLOGGEDREFUSALS` logs at severity 2 and raises the instance's alert state.
- **Pairs (AD-8, AD-29, AD-44).** `ResourcesOR()` is only a lower bound (18.27: `Security.LDAPConfigs` refuses the `%Admin_Operate` the admin API admits). Read the backing class's check and run the call as a least-privileged role. Administrative resources are required at `USE`. A tool declares each extra pair and refuses by name before any port call. `CLASSICPAGES` lists each extra classic page whose operation a write performs.
- **Write kinds.** A merge (AD-4) reads fresh and sends the complete set; a create (AD-54) fingerprints the name's absence (admin `PUT`s are often upserts); an action (AD-51) fingerprints each precondition. An empty secret clears only under `CLEARABLESECRETS` (AD-56). The screen and the agent are two callers of one tool (AD-53, AD-55); the screen's Save mints nothing and emits no marker but holds the per-target lock (AD-34). Every write has a read-back (AD-58; a create read through a list row re-reads via `READBACKTOOL`), a port `Snippet` (AD-59), a change event (AD-14) and `WRITE.TARGETBUSY` after 10 s. A write the vendor does not audit is a named AD-15 and AD-53 case (next free: AD-15's twentieth, AD-53's gap twenty-one, unless Epic 20 takes them).
- **Ids, fields and reads (AD-3, AD-13, AD-36).** A new entity type joins the kernel's closed enum. Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, regenerated, never hand-merged; an unclassified field is a secret. One declared read serves screen and tool, with at most one per-row detail call; no read answers key material.
- **Async (AD-26).** A write that would queue is refused unless `QUEUEDWRITES` names it; a secret-carrying body never queues. One poller reads a task's end once; past the bound the write answers `PORT.STARTED` and its read-back is `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path; `PathPort` resolves a root plus a relative name at the mint and at the write. A vendor-writes directory may not be the manager's, OcuPilot's served one, or any database, volume, journal or WIJ directory.
- **Text and self-protection.** OcuPilot answers in its own sentences; vendor text is logged, never sent (AD-39). New error codes go in an area error class (`Api/Error.cls`, near the compiler's parameter limit, gains only dispatch lines). AD-10's predicates live once in the kernel, run inside the confirm's atomic transition, each pinned by a test.
- **SQL privileges (measured 2026-10-07).** 18.9 takes the standard family (tables, views, cubes, schemas, procedures, ML configurations, foreign servers); 18.28 the column family and the admin family (a closed list of 32, kept per namespace).
  - **Pairs and grantor:** `%Admin_Secure:USE` plus READ on the target namespace's database, resolved at the call (else `<PROTECT>`); neither WRITE there nor `%DB_IRISSYS:READ`. Past the pair the instance's grantor rule decides: lacking the privilege gives SQLCODE -112 (standard) or -99 (admin); holding it with grant option suffices. Other failures are 500 #5540 carrying a SQLCODE.
  - **Silent no-ops (200, nothing changed):** a column grant the SQL layer refuses; a non-grantor's revoke unless `asGrantor` names the row's `GrantedBy`; a revoke of a privilege not held. The read-back reads each as refused.
  - **Wildcards:** the vendor expands comma lists, `*` and trailing `*`, and an unknown namespace answers 500 `<NAMESPACE>`; refuse all before any call.
  - **Rows:** only a `GrantedVia` `Direct` row offers a revoke; a schema grant lists as per-table `Schema Privilege` rows; every grantee shows four `Ens` `Owner Privilege` rows.
  - **Audit:** the vendor records every grant and revoke (`UserChange` or `RoleChange`), so no AD-15 or AD-53 case (inference for columns).
  - **AD-10:** a new arm refuses SQL grants and revokes on OcuPilot's own schemas from either caller (DW-236). No SQL route confers a role; a grant conferring `%All` or an `%Admin_*` role (only 18.29's copy can) takes the destructive treatment through the one tool, with no caller-scoped predicate. Application roles on OcuPilot's own web applications stay prohibited.
- **18.29.** No admin route copies a user. `Security.Users.Copy`, the classic call, copies roles and every SQL privilege; it is an AD-27 case only if Task 0 measures it under the caller's own `%Admin_Secure`, else the copy is roles and fields through the admin API, stated as narrower. A copy conferring `%All` or an `%Admin_*` role is destructive. `OWNERLIST` also needs `%DB_IRISSYS:READ`; `AdminOption` is the string `"0"` or `"1"`. Password checks wrap `$SYSTEM.Security.ValidatePassword` and never carry the password (AD-35).
- **18.10.** Spec-based REST services are created and deleted from an OpenAPI document through `MgmntPort`; the `%`-class access list, Doc DB applications and privileged routine applications go through the admin API.
- **18.11.** Each read uses its own port and gate, never the monitoring API's anonymous reach. Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`); each call rewrites sensor baselines, shortening an external scraper's windows. Never call the vendor's alerts read, which advances a shared cursor. `BusyProcesses` always has ten rows: drop the empty ones. The live tail long-polls with a heartbeat, checks the file's identity, restarts on rotation, and supersedes bounded pages only for sources that opt in.
- **18.12.** Every Stage 2 screen carries a read tool and a confirmed single-write tool from its descriptor; 18.12 takes in 18.24's wallet key tools. History reaches the model as user messages and final replies only, capped at 65,536 characters oldest-first (AD-24); budgeting builds on that (inference). The egress policy judges a proxy as a destination (AD-42). The installer-created SSL configuration is AD-10-protected, so custom-CA support cannot edit it (inference). The wallet rung never returns a value into a status or an error.
- **18.13.** One idempotent, guard-then-act installer runs at container start or from IPM's `<Invoke>` (AD-17); only the container path unexpires `_SYSTEM`. Code goes in the install namespace's database, globals in OcuPilot's protected database (AD-9); the unauthenticated application's role reads only the install namespace's databases. The own-namespace predicates (`PROHIBITED.OCUPILOTNAMESPACE`) key off the namespace the API runs in. Install reads back its schema grant (schema name from the class dictionary); a missing grant reads `unreadable` (AD-38). DW-2172's detection beside it needs every grantee on the schema enumerated.
- **For the burn-down.** `Port/EncryptionPort` builds every `Security.Encryption.*` body, with rules in `Area/Security/EncryptionRules.cls`. 18.23's `Settings` merge sends `AuditEncrypt` as the fresh read holds it unless changed. Interactive activation is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted.
- **Spine amendments (Rule 20).** Each new pair, predicate, entity type, path case, queued write, named case, read shape, `CLASSICPAGES` entry or unaudited write goes into the spine at the spec gate.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts; the side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, each refusal sentence once, edited in place so cited line numbers hold; one key per value in `strings.ts`. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. A destructive confirm names the action and target, states the consequence and requires the name typed exactly; an agent proposal uses the destructive bar.
- Editors are form pages with tabs mirroring the classic page, a sticky Save and an unsaved-changes guard. A setting shown but never set is read-only, with a hint naming the classic page.
- Gated controls stay focusable and `aria-disabled`, naming their reason through `aria-describedby`. A wait that may block is bounded and stated before it starts.
- Key material uses the masked secret field; a password typed at confirm needs a masked row on the agent's card.

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.8 and 18.14 to 18.27. Next: 18.9, 18.28 (extends 18.9's list, tools and refusals), 18.29, 18.10 to 18.13, then 18.30. The burn-down's DW-2086 and DW-2087 amend 18.22's activations.
- **Epic 20 runs in parallel on slot B.** It overlaps 18.12 at 20.12 (the tool registry) and 18.13 at 20.1 (per-namespace state, AD-44's `appliesWhen`). 20.14 gives every floor-only surface its own pair, then admits `%Ens_Portal` holders; 20.15 adds runtime adjustment of a screen's pairs. 20.2 merged an Interoperability area over `InteropPort` (AD-62).
- Shared files take add-only edits, with one-line lists and roster counts unioned at merges: the kernel and registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, the test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md and the spine.
