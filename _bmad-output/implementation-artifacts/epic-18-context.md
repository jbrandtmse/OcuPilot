# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

OcuPilot reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, so no such task needs the classic portal. Each screen brings a read tool and confirmed single-write tools from one descriptor, and every story rests on measured payloads, containment and self-protection. Still to build: the web-application extras and spec-based REST services (18.10), the monitoring extras and live log tail (18.11), the agent's growth over the stage (18.12) and multi-namespace install (18.13), then the burn-down (18.30).

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Authentication and web-session options
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
- **Its own pair, never the floor alone.** The API's floor admits any `%Admin_*` resource, `%Development:USE` or `%Ens_Portal:USE`. Every new screen, route and tool declares its own pair, matching its classic page's `RESOURCE` in `irissys/`; `InteropFloorOwnPairs` pins the floor-only roster.
- **Observe before building.** Task 0 on the throwaway measures each route's payload, effects, required pairs and audit events before any form or tool exists, restores what it found and halts on a contradiction. Privileges come from the instance, never the specification or the vendor documentation. A probe prefix matches no other suite's.
- **Fresh instance, either order (Rule 30).** A spec's `## Verification` names its shared surfaces (or `none`); implement greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each one's old shape and updates every hit. Outside a roster's own pin, counts are derived, never literals. A test creates and removes what it asserts on, and a browser spec waits for the screen's answered signal. Before pushing, the runner checks the story on its own freshly rebuilt throwaway, browser specs also singly in reverse order.
- **Community license, CI included.** No test activates a license or key, opens an ECP connection, or leaves anything only a restart clears; such paths run through a test seam.
- **Secrets are write-only:** never read back, logged, kept in a proposal or queued; the agent never holds key material.
- **Environment.** Slot A: dev `ocupilot`, throwaway `ocupilot-ci` (52776/1975). One test class in flight at a time.
- **Budgets.** The build measured 3,173,310 bytes at 18.29 against `maximumWarning` 3326kB; a story crossing it re-bases it, and the literal in `angular-json.test.mjs`, about 5% above the measured total (DW-1166). `maximumError` is 4000kB: stop and ask above 3800kB. The Fixed-strings table holds 2964 literals against the bound of 3000 in `strings.test.mjs`; a story adding more moves the bound at its spec gate under that file's documented protocol.
- **Test lessons.** Keep `$SYSTEM.Monitor.State()` out of before/after snapshots. Poll a vendor audit row, never read it once. A probe fixture creates and removes every vendor object it needs. The entity-type count (62) is a literal in `Test/Descriptor`, `MftConnectionDescriptor` and `SuperserverDescriptor` until DW-2202 (Story 23.5) derives it.
- **Screens and the side bar.** A screen-adding story extends the built-screen route literal in `ui/tools/navigation.test.mjs` (a roster pin); browser specs derive side-bar labels through `ui/browser/side-bar-spec.mjs` (DW-1774).
- **Ledger items routed to the remaining stories** (address each, or decline it with a reason):
  - 18.12: DW-1756 (the Guardrails page lacks the per-user turns-per-hour setting, AD-41).
  - 18.13: DW-219 (uninstall on an instance OcuPilot does not wholly own: the bundle directory removed even when an adopted `/ocupilot` is kept, an unreadable provenance record that continues removing, a declared role whose application is already gone never removed; decide each); DW-423 (decide what `Kernel.State.Stamp` keeps and what prunes it); DW-1333 (IPM drops `<SystemRequirements>`; the routed direction is that install refuses below the roster's IRIS version floor); DW-2172 (detect a SQL grant on OcuPilot's schemas widened outside OcuPilot, beside install's schema-grant read-back; needs every grantee on the schema enumerated, and a user copy reproduces such a grant by design).
- **The burn-down (18.30)** takes every open ledger item it owns. Decided ones:
  - DW-1896: an LDAP configuration's last attribute via `Security.LDAPConfigs.Modify` only if measured under the caller's own `%Admin_Secure`, else wontfix. DW-2167: the vendor's 404 #822 is an access refusal, not an absence. DW-1966: refuse a database's directory as a journal directory (amends AD-21). DW-1979, DW-1981: the record browser's newest-first order and input `maxlength`.
  - DW-2007: a code-scoped `UNLOGGEDREFUSALS`, taking ECP data server #1454, `Security.Superserver` `PUT` #5001, `Security.MFT` `DELETE` #5809, `Security.SQLPrivilege.Standard` #5540 and #5035, and `Security.SQLPrivilege.Admin` #516.
  - DW-2085: the database create offers Encrypt database only while a database key is active. DW-2086: an activation's fingerprint carries the reviewed key list. DW-2087: a first activation takes the destructive treatment. DW-2100: measure whether AD-10's `STARTUPINTERACTIVE` arm widens. DW-2126: name a stored certificate's loss on an RSA regenerate. DW-2149, DW-2160: monitor state out of snapshots, polled audit reads.
  - Epic 18's vendor-defect candidates (the ledger's `owner_hold` rows, DW-2095 to DW-2223) stay unreported; OcuPilot works around each.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name `%Api.Admin.*`; a write tool's port builds its bodies, fresh reads and call sequences. The outcome reads both `tSC` and `%response.Status`; only the vendor's 404 means no rows. A direct vendor-class call needs a named AD-27 case. A failure outside `UNLOGGEDREFUSALS` logs at severity 2 and raises the instance's alert state, so a predictable vendor failure is refused before the call (wildcard or list inputs, a column object not `schema.table`, a password the policy refuses).
- **Pairs (AD-8, AD-29, AD-44).** `ResourcesOR()` is only a lower bound. Read the backing class's check and run the call as a least-privileged role. Administrative resources are required at `USE`. A tool declares each extra pair and refuses by name before any port call. `CLASSICPAGES` lists each extra classic page whose operation a write performs.
- **Screen pairs and refusals (AD-64, Stories 20.15 and 20.18, merged).** Every gate reaches a screen's requirement through `Screen.Gate.RequiredPairs` at the call (the declared set or its adjustment, plus the classic page's custom resource); a tool's extra pairs and `CLASSICPAGES` add on top. Dispatch refuses before any mint when the user lacks a tool's screen's effective pairs, naming the screen; the screen context carries the screen's `verdict` and the `unavailable` tools. New tools inherit this through the registry; the client never derives availability from the mirror's `privileges`.
- **Write kinds.** A merge (AD-4) reads fresh and sends the complete set; a create (AD-54) fingerprints the name's absence (admin `PUT`s are often upserts); an action (AD-51) fingerprints each precondition. An empty secret clears only under `CLEARABLESECRETS`; `SCREENOPTIONAL` names declared values a screen action may omit (AD-56). Screen and agent are two callers of one tool (AD-53, AD-55); the screen's Save mints nothing but holds the per-target lock (AD-34). Every write has a read-back (AD-58), a port `Snippet` (AD-59), a change event (AD-14) and `WRITE.TARGETBUSY` after 10 s. A write the vendor does not audit is a named AD-15 and AD-53 case.
- **Ids, fields and reads (AD-3, AD-13, AD-36).** A new entity type joins the kernel's closed enum. Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, regenerated, never hand-merged; an unclassified field is a secret. A bodyless tool (`SENDSBODY 0`) authors its arguments in its `InputSchema`. One declared read serves screen and tool, with at most one per-row detail call; no read answers key material.
- **Async (AD-26).** A write that would queue is refused unless `QUEUEDWRITES` names it; a secret-carrying body never queues. A finished task is read once. Past the poll bound a write answers `PORT.STARTED`, read-back `unchecked`.
- **Server paths (AD-21).** No endpoint accepts a caller's path; `PathPort` resolves a root plus a relative name at the mint and at the write.
- **Reads that write vendor state (AD-7).** A read may write vendor state only in one of the six shapes AD-7 names (the REST discovery cache and the sensor baseline among them); Task 0 snapshots for any other. OcuPilot never calls the vendor's alerts read (`SYS.Monitor.SAM.Sensors.Alerts()`, `/api/monitor/alerts`), which advances a shared cursor.
- **Text and self-protection.** OcuPilot answers in its own sentences; vendor text is logged, never sent (AD-39). New error codes go in an area error class (`Api/Error.cls`, near the compiler's parameter limit, gains only dispatch lines). AD-10's predicates live once in the kernel, run inside the confirm's atomic transition, each pinned by a test.
- **What 18.9, 18.28 and 18.29 left in place.** `SqlPrivilegePort` reads and writes standard, column and admin SQL privileges, judging every write by its re-read; AD-10's `PROHIBITED.OCUPILOTSQLPRIVILEGE` refuses a grant or revoke on OcuPilot's own schemas. `UserCopyPort` is an AD-27 case over `Security.Users.Copy`. `AdminPort` checks a password against the instance's policy before a user create or set-password.
- **18.10.** The `%`-class access list (`/web-app/pct-accesses`, a dialog off the web-app editor), Doc DB applications (`/doc-dbs`, `/doc-db`) and privileged routine applications (`/security/privileged-routines`) go through the admin API. Doc DB applications are the `Security.DocDBs` records, which Story 19.17's DocDB create does not write (DW-2084, owner hold). OcuPilot runs on its own privileged routine applications (AD-9); the plan confirms that AD-10's own-application arm covers them (inference: no arm names them). Spec-based REST services are created and deleted through `MgmntPort` (`POST`/`DELETE /api/mgmnt/v2/:ns/:app`): the create generates the spec, disp and impl classes in the named package and the delete removes them, while the web application is a separate step. A package beginning `OcuPilot` would compile or delete documents `PROHIBITED.OCUPILOTCODE` protects (inference).
- **18.11.** Each read uses its own port and gate, never the monitoring API's anonymous reach. Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`); each call rewrites sensor baselines. The drill-downs read `/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources`; interoperability usage reads the deprecated InteropMetrics v1. Drop `BusyProcesses`' empty rows. The live tail long-polls with a heartbeat, and validates its offset against the file's current identity, restarting on rotation, as paging already does.
- **18.12.** Every Stage 2 screen carries a read tool and a confirmed single-write tool from its descriptor; 18.24 names 18.12 as the consumer of its wallet key tools. Two Stage 2 writes stay unadvertised by decision (AD-53): license key activate and `security.secrets.replacesymmetric`. AD-24 already fixes the history rule (user messages and final replies only, capped at 65,536 characters oldest-first, earlier tool results never replayed) and the result bounds (the row cap, 65,536 characters in all, 1,000 a field, the source reads' 60,000-character exception, `TOOL.RESULTTOOLARGE` past the budget); the plan measures what is built before adding to it. A proxy is a destination judged by the egress policy, and an https endpoint tunnels through it (AD-42). The installer's SSL configuration keeps `VerifyPeer`, `CAFile`, `Type` and `Enabled` under `PROHIBITED.OCUPILOTSSL` (inference: custom-CA support cannot edit it). The credential ladder never returns a value into a status or an error. Storing a key without the credential-store privilege is a named refusal (AD-42). OcuPilot deletes only credential entries it created and never overwrites one it did not (AD-37).
- **18.13.** One idempotent, guard-then-act installer runs at container start or from IPM's `<Invoke>` (AD-17); only the container path unexpires `_SYSTEM`, and IPM is never a runtime dependency (AD-18). Code goes in the install namespace's database, globals in OcuPilot's protected database (AD-9). `PROHIBITED.OCUPILOTNAMESPACE` keys off the namespace the API runs in. Install reads back its schema grant; a missing grant reads `unreadable`, and the schema name comes from the class dictionary (AD-38).
- **Spine amendments (Rule 20).** Each new pair, predicate, entity type, path case, queued write, named case, read shape, `CLASSICPAGES` entry or unaudited write goes into the spine at the spec gate.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts; the side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, each refusal sentence once, edited in place so cited line numbers hold; one key per value in `strings.ts`. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. A destructive confirm names the action and target, states the consequence and requires the name typed exactly; an agent proposal uses the destructive bar.
- Editors are form pages with tabs mirroring the classic page, a sticky Save and an unsaved-changes guard. A setting shown but never set is read-only, with a hint naming the classic page.
- Gated controls stay focusable and `aria-disabled`, naming their reason through `aria-describedby`. Key material uses the masked secret field.
- Auto-refresh is AD-43's shared framework: a screen joins only by declaring it in its descriptor and appearing in EXPERIENCE.md's Auto-refresh roster. Log viewers load bounded pages; the live tail supersedes that only for sources that opt in.
- Panel blocks over eight lines start collapsed, and a proposal card then shows a summary line; Confirm, consequences and secret fields are never inside a collapsed block (Story 20.17).

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.9 and 18.14 to 18.29. Next: 18.10, 18.11, 18.12, 18.13, then 18.30.
- **Epic 20 runs in parallel on slot B** (20.21 next, then 20.20 and 20.3 to 20.6). 18.12 overlaps 20.12 (guided workflows over the same tool registry) and 20.21 and 20.20 (the agent's class and routine saves and creates, AD-53), which grow the advertised roster too. 18.13 meets 20.1 (merged: per-namespace feature gating, AD-44 `appliesWhen`). 18.10's REST create writes classes, where 20.21's rules for agent-authored code (own routines database, never `%SYS` or a `%` name) are the nearest precedent; a posture question goes to the orchestrator.
- **Unassigned rows.** Two stage rows name no story: WQM categories (SA-05; no screen exists) and enabling the mirror service (SA-22, placed by the catalog on the existing Services editor). The epic's close assigns or declines each.
- At Epic 18's merge, `Wire.cls`'s doc comments that still name a two-member floor reopen DW-2170.
- Shared files (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md, the spine) take add-only edits, unioned at merges.
