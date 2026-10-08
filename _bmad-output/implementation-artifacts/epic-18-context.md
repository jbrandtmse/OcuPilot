# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

OcuPilot reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, so no such task needs the classic portal. Each screen brings a read tool and confirmed single-write tools from one descriptor, and every story rests on measured payloads, containment and self-protection. Still to build: SQL column and admin privileges (18.28, extending 18.9) and the user and role page extras (18.29), the web-application and monitoring extras (18.10, 18.11), the agent's growth (18.12) and multi-namespace install (18.13), then the burn-down (18.30).

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

- **The contract (FR-80).** Each screen is one descriptor over one port; its read tool and write field lists derive from it. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker; every read is bounded and reports truncation; every gate checks the caller's own privileges at call time.
- **Governance.** Every destructive or disruptive action ships with its governance key `false`; a story adding a write key adds its line to `Kernel/Governance/Baseline.cls` in the same change. A non-destructive key ships enabled unless the criteria say otherwise.
- **Its own pair, never the floor alone.** The API's floor admits any `%Admin_*` resource, `%Development:USE` or `%Ens_Portal:USE` (20.14). Every new screen, route and tool declares its own pair, matching its classic page's `RESOURCE` in `irissys/`; `InteropFloorOwnPairs` pins the floor-only roster.
- **Observe before building.** Task 0 on the throwaway measures each route's payload, effects, required pairs and audit events before any form or tool exists, restores what it found and halts on a contradiction. Privileges come from the instance, not the specification. A probe prefix matches no other suite's.
- **Fresh instance, either order (Rule 30).** A spec's `## Verification` names its shared surfaces (or `none`); implement greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each one's old shape and updates every hit (18.9 went red on the editors' tab lists). Outside a roster's own pin, counts are derived, never literals. A test creates and removes what it asserts on, never relies on state it did not make, and a browser spec waits for the screen's answered signal. Before pushing, the runner checks the story on its own freshly rebuilt throwaway, browser specs also singly in reverse order.
- **Community license, CI included.** No test activates a license or key, opens an ECP connection, or leaves anything only a restart clears; such paths run through a test seam.
- **Secrets are write-only:** never read back, logged, kept in a proposal or queued; the agent never holds key material.
- **Environment.** Slot A: dev `ocupilot`, throwaway `ocupilot-ci` (52776/1975). One test class in flight at a time.
- **Budgets.** `angular.json` `maximumWarning` is 3165kB; a story crossing it re-bases it and the literal in `angular-json.test.mjs` to the measured total (DW-1166). `maximumError` is 4000kB: stop and ask above 3800kB. The Fixed-strings table holds 2910 after 18.9 against a bound of 3000 in `strings.test.mjs`.
- **Test lessons.** Keep `$SYSTEM.Monitor.State()` out of before/after snapshots. Poll a vendor audit row, never read it once. Take a signing-key snapshot only after a mint. A probe fixture creates and removes every vendor object it needs. The entity-type count (61) is a literal in `Test/Descriptor`, `MftConnectionDescriptor` and `SuperserverDescriptor` until DW-2202 (23.5) derives it.
- **Ledger items routed to the remaining stories** (address each, or decline it with a reason):
  - 18.28: keep the SQL privilege dialog's type, action and object-pattern lists equal to `SqlPrivilegePort`'s as the port's lists grow (DW-2190's reopen trigger).
  - 18.29: DW-1662 (the authorization-server tab's two pairs cannot create a configuration: the editor pre-ticks default roles the create refuses).
  - 18.12: DW-1756 (Guardrails lacks the turns-per-hour setting).
  - 18.13: DW-219 (uninstall's half-state paths), DW-423 (install-stamp retention), DW-1333 (no version floor in the IPM archive), DW-2172 (DW-236's detection half: a grant on OcuPilot's schemas widened outside OcuPilot).
- **The burn-down (18.30)** takes every open ledger item it owns. Decided ones:
  - DW-1896: an LDAP configuration's last attribute via `Security.LDAPConfigs.Modify` only if measured under the caller's own `%Admin_Secure`, else wontfix. DW-1966: refuse a database's directory as a journal directory (amends AD-21). DW-1979, DW-1981: the record browser's newest-first order and input `maxlength`.
  - DW-2007: a code-scoped `UNLOGGEDREFUSALS`, taking `Security.Superserver` `PUT` #5001, `Security.MFT` `DELETE` #5809, and `Security.SQLPrivilege.Standard` #5540 (SQLCODE -30, -118, -187, -428, -473) and #5035 (-112, -99, -126).
  - DW-2085 to 2087 amend 18.22's activations (Encrypt database only under an active key; the fingerprint carries the reviewed key list; a first activation is destructive). DW-2100: measure whether AD-10's `STARTUPINTERACTIVE` arm widens. DW-2126: name a stored certificate's loss on an RSA regenerate. DW-2149, DW-2160: monitor state out of snapshots, polled audit reads. DW-2167: the vendor's 404 #822 is an access refusal.
  - Vendor-defect candidates (the ledger's `owner_hold` rows, DW-2095 to DW-2201) stay unreported; OcuPilot works around each.
- A screen-adding story extends its area's literal in `ui/tools/navigation.test.mjs`, with labels from `ui/browser/side-bar-spec.mjs` (DW-1774).

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name `%Api.Admin.*`; a write tool's port builds its bodies, fresh reads and call sequences. The outcome reads both `tSC` and `%response.Status`; only the vendor's 404 means no rows. A direct vendor-class call needs a named AD-27 case. A failure outside `UNLOGGEDREFUSALS` logs at severity 2 and raises the instance's alert state.
- **Pairs (AD-8, AD-29, AD-44).** `ResourcesOR()` is only a lower bound (18.27). Read the backing class's check and run the call as a least-privileged role. Administrative resources are required at `USE`. A tool declares each extra pair and refuses by name before any port call. `CLASSICPAGES` lists each extra classic page whose operation a write performs.
- **Adjustable screen pairs (AD-64, Story 20.15, in progress on slot B).** Every gate reaches a screen's requirement through `Screen.Gate.RequiredPairs` at the call (the declared set or its adjustment, plus the classic page's custom resource); a tool's extra pairs and `CLASSICPAGES` add on top, and port, vendor and area pairs never move. The client never derives availability from the mirror's `privileges`. Adjusting requires `%Development:USE` or `%Admin_Secure:USE`.
- **Write kinds.** A merge (AD-4) reads fresh and sends the complete set; a create (AD-54) fingerprints the name's absence (admin `PUT`s are often upserts); an action (AD-51) fingerprints each precondition. An empty secret clears only under `CLEARABLESECRETS` (AD-56). Screen and agent are two callers of one tool (AD-53, AD-55); the screen's Save mints nothing but holds the per-target lock (AD-34). Every write has a read-back (AD-58, `READBACKTOOL` for a create read through a list row), a port `Snippet` (AD-59), a change event (AD-14) and `WRITE.TARGETBUSY` after 10 s. A write the vendor does not audit is a named AD-15 and AD-53 case.
- **Ids, fields and reads (AD-3, AD-13, AD-36).** A new entity type joins the kernel's closed enum. Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, regenerated, never hand-merged; an unclassified field is a secret. A bodyless tool (`SENDSBODY 0`) authors its arguments in its `InputSchema` instead. One declared read serves screen and tool, with at most one per-row detail call; no read answers key material.
- **Async (AD-26).** A write that would queue is refused unless `QUEUEDWRITES` names it; a secret-carrying body never queues. Past the poll bound a write answers `PORT.STARTED`, read-back `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path; `PathPort` resolves a root plus a relative name at the mint and at the write. A vendor-writes directory may not be the manager's, OcuPilot's served one, or any database, volume, journal or WIJ directory.
- **Text and self-protection.** OcuPilot answers in its own sentences; vendor text is logged, never sent (AD-39). New error codes go in an area error class (`Api/Error.cls`, near the compiler's parameter limit, gains only dispatch lines). AD-10's predicates live once in the kernel, run inside the confirm's atomic transition, each pinned by a test.
- **SQL privileges: what 18.9 built, which 18.28 extends** (its list, port, guard and AD-10 arm).
  - One unlisted read (`SqlPrivilegeList`) feeds a SQL privileges tab on both editors and the read tool. Grant and revoke tools target the grantee through `UserList` and `RoleList` (no new entity type); namespace, type, object and action are arguments, one privilege per write.
  - `SqlPrivilegePort` (AD-52) reads the state, sends one action (a revoke once per direct grantor, as `asGrantor`) and re-reads: a write that moved nothing is 409 `SQLPRIV.NOTAPPLIED`, never applied.
  - The port refuses every `Security.SQLPrivilege.*` call, the read included, before the endpoint (AD-2): an undefined namespace, an absent grantee, no READ on the namespace's databases, or `*` or `,` in object, action or grantee.
  - Pairs (AD-8): Security's set plus READ on the namespace's routines and globals databases, resolved at the call and refused by name; no WRITE, no `%DB_IRISSYS:READ`. Past them the grantor rule decides (SQLCODE -112 standard, -99 admin).
  - Rows: only a `Direct` row offers Revoke; a schema grant lists per-object `Schema Privilege` rows and is judged by their count; an `%All` holder lists only `SuperUser` rows.
  - AD-10: `PROHIBITED.OCUPILOTSQLPRIVILEGE` refuses a grant or revoke on OcuPilot's own schemas from either caller; a SQL grantee among OcuPilot's roles or `%DB_OCUPILOT` is `OCUPILOTROLE`. No SQL route confers a role. `CLASSICPAGES` (AD-44): the editor's page plus the grant's dialog page.
  - The vendor audits every grant and revoke (`UserChange`, `RoleChange`): no AD-15 or AD-53 case (inference for columns).
- **18.28 (measured at 18.9's plan).** `.Column` takes TABLE and VIEW: rows `{Column, Action, GrantedBy, GrantOption, GrantedVia}` per grantee, namespace and `schema.table`; a grant of an unknown column, or by a grantor without the privilege, answers 200 and stores nothing; a `DELETE` grant answers 200 and stores a row the column list never shows. `.Admin` takes a closed list of 31 privileges (`GetPrivNum` maps 32, but the instance refuses `%DEFER`) kept per namespace: rows `{Privilege, GrantOption, GrantedVia}`; an unknown one answers 400 #5001, a revoke of one not held 200, a grantor without it 500 #516 (-99). The OcuPilot-schema arm and the input refusals hold for columns.
- **18.29.** No admin route copies a user. `Security.Users.Copy`, the classic call, copies roles and every SQL privilege; it is an AD-27 case only if Task 0 measures it under the caller's own `%Admin_Secure`, else the copy is roles and fields through the admin API, stated as narrower. A copy conferring `%All` or an `%Admin_*` role is destructive and names the privilege. `OWNERLIST` also needs `%DB_IRISSYS:READ`; `AdminOption` is the string `"0"` or `"1"`; an absent role answers 404 #883. Password checks wrap `$SYSTEM.Security.ValidatePassword` and never carry the password (AD-35).
- **18.10.** Spec-based REST services are created and deleted from an OpenAPI document through `MgmntPort`; the `%`-class access list, Doc DB applications and privileged routine applications go through the admin API.
- **18.11.** Each read uses its own port and gate, never the monitoring API's anonymous reach. Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`); each call rewrites sensor baselines. Never call the vendor's alerts read (it advances a shared cursor). Drop `BusyProcesses`' empty rows. The live tail long-polls with a heartbeat, checks the file's identity and restarts on rotation.
- **18.12.** Every Stage 2 screen carries a read tool and a confirmed single-write tool from its descriptor; 18.12 takes in 18.24's wallet key tools. History reaches the model as user messages and final replies only, capped at 65,536 characters oldest-first (AD-24). The egress policy judges a proxy as a destination (AD-42). The installer-created SSL configuration is AD-10-protected (inference: custom-CA support cannot edit it). The wallet rung never returns a value into a status or an error.
- **18.13.** One idempotent, guard-then-act installer runs at container start or from IPM's `<Invoke>` (AD-17); only the container path unexpires `_SYSTEM`. Code goes in the install namespace's database, globals in OcuPilot's protected database (AD-9). `PROHIBITED.OCUPILOTNAMESPACE` keys off the namespace the API runs in. Install reads back its schema grant; a missing grant reads `unreadable` (AD-38). DW-2172's detection needs every grantee on the schema enumerated.
- **Spine amendments (Rule 20).** Each new pair, predicate, entity type, path case, queued write, named case, read shape, `CLASSICPAGES` entry or unaudited write goes into the spine at the spec gate.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts; the side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, each refusal sentence once, edited in place so cited line numbers hold; one key per value in `strings.ts`. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. A destructive confirm names the action and target, states the consequence and requires the name typed exactly; an agent proposal uses the destructive bar.
- Editors are form pages with tabs mirroring the classic page, a sticky Save and an unsaved-changes guard. A setting shown but never set is read-only, with a hint naming the classic page.
- Gated controls stay focusable and `aria-disabled`, naming their reason through `aria-describedby`. Key material uses the masked secret field.

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.9 and 18.14 to 18.27. Next: 18.28 (extends 18.9's list, port, guard, arm and dialog), 18.29, 18.10 to 18.13, then 18.30.
- **Epic 20 runs in parallel on slot B.** It overlaps 18.12 at 20.12 (the tool registry) and 20.18 (dispatch refuses before any mint when the user lacks a screen's effective pairs, and the screen context carries the current screen's verdict and marks unusable tools), and 18.13 at 20.1 (per-namespace state, AD-44's `appliesWhen`). 20.15 (AD-64) adds the screen-permission store and tools. 20.2 merged an Interoperability area over `InteropPort` (AD-62).
- At Epic 18's merge, `Wire.cls`'s doc comments that still name a two-member floor reopen DW-2170.
- Shared files (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md, the spine) take add-only edits, unioned at merges.
