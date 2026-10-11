# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

OcuPilot reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, so no such task needs the classic portal. Each screen brings a read tool and confirmed single-write tools from one descriptor, and every story rests on measured payloads, containment and self-protection. Still to build: Doc DB applications (18.30), privileged routine applications (18.31), spec-based REST services (18.32), the monitoring extras and live log tail (18.11), the agent's growth over the stage (18.12), multi-namespace install (18.13), then the burn-down (18.33).

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Superservers, authentication options and managed file transfer
- Story 18.9: SQL object privileges
- Story 18.10: Web application extras (narrowed to the `%`-class access list and DW-2239's arm)
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
- Story 18.30: Doc DB applications
- Story 18.31: Privileged routine applications
- Story 18.32: Spec-based REST services
- Story 18.33: The burn-down at the epic's close (in the dependency order; not yet in the epics file or sprint status)

## Requirements & Constraints

- **The contract (FR-80).** Each screen is one descriptor over one port; its read tool and write field lists derive from it. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker; every read is bounded and reports truncation; every gate checks the caller's own privileges at call time.
- **Governance.** A destructive or disruptive key ships `false`; a non-destructive key ships enabled unless the criteria say otherwise. A story adding a write key adds its `Kernel/Governance/Baseline.cls` line in the same change.
- **Its own pair, never the floor alone.** The API's floor admits any `%Admin_*` resource, `%Development:USE` or `%Ens_Portal:USE`. Every new screen, route and tool declares its own pair, matching its classic page's `RESOURCE`; `InteropFloorOwnPairs` pins the floor-only roster.
- **Observe before building.** Task 0 on the throwaway measures each route's payload, effects, required pairs and audit events before any form or tool exists, restores what it found and halts on a contradiction. Privileges come from the instance, never the specification or vendor documentation. A probe prefix matches no other suite's.
- **Fresh instance, either order (Rule 30).** A spec's `## Verification` names its shared surfaces (or `none`); implement greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each one's old shape. Outside a roster's own pin, counts are derived. A test creates and removes what it asserts on; a browser spec waits for the screen's answered signal. Before pushing, the runner checks the story on a freshly rebuilt throwaway, browser specs also singly in reverse order.
- **Prefer extending the sibling (Rule 31, new).** A plan's code map names, for each new tool, mint, port method, seam, probe, rules class, store or loader, the sibling it extends, or why a copy is better. An unjustified copy is a MED review finding naming both locations.
- **Community license, CI included.** No test activates a license or key, opens an ECP connection, or leaves anything only a restart clears.
- **Secrets are write-only:** never read back, logged, kept in a proposal or queued.
- **Environment.** Slot A: dev `ocupilot`, throwaway `ocupilot-ci` (52776/1975). One test class in flight at a time, each run a foreground call under the 10-minute cap.
- **Budgets.** Bundle: last recorded 3,190,536 bytes at 18.10, before 20.20's and 23.6's client changes merged, against `maximumWarning` 3326kB; a story crossing it re-bases it and the literal in `angular-json.test.mjs` (DW-1166). `maximumError` is 4000kB: stop and ask above 3800kB. Fixed strings: the table holds 2985 literals (counted with the test's own extractor), and `strings.test.mjs` still asserts at most 3000. The bound of 3400 is approved and moves in the first code head that needs it, under that file's protocol.
- **Test lessons.** Keep `$SYSTEM.Monitor.State()` out of before/after snapshots. Poll a vendor audit row; never read it once. The entity-type count is 63, a literal in `Test/Descriptor`, `MftConnectionDescriptor` and `SuperserverDescriptor` until DW-2202 (Story 23.5); Story 20.3's `production-item` moves it when it merges.
- **Screens and the side bar.** A screen-adding story extends the built-screen route literal in `ui/tools/navigation.test.mjs`; browser specs derive side-bar labels through `ui/browser/side-bar-spec.mjs`.
- **Ledger items routed to the remaining stories** (address each, or decline it with a reason):
  - 18.31: DW-2252 (a web-application write naming a privileged routine application reaches `WebApp.App` `PUT`, which answers 500 #799 and logs at severity 2; refuse a routine-type target before the vendor, as `AdminPort`'s type check does); DW-2262 (move `PRIVROUTINE.TYPE` out of `PctAccessError` into a privileged-routine home).
  - 18.12: DW-1756 (the Guardrails page lacks the turns-per-hour setting).
  - 18.13: DW-219 (uninstall's three half-state paths on an instance OcuPilot does not wholly own); DW-423 (what `Kernel.State.Stamp` keeps); DW-1333 (IPM drops `<SystemRequirements>`; install refuses below the roster's IRIS floor); DW-2172 (detect a SQL grant on OcuPilot's schemas widened outside OcuPilot, beside install's schema-grant read-back).
  - 18.33 re-owns DW-1896, DW-2167 and DW-2160 when chartered, and takes the decided items DW-1966, DW-1979, DW-1981, DW-2007, DW-2085, DW-2086, DW-2087, DW-2100, DW-2126 and DW-2149. Vendor-defect candidates on owner hold (DW-2084 among them) stay unreported and are never built on.

## Technical Decisions

- **Containment (AD-2, AD-27, AD-52).** Only `AdminPort` and its subclasses name `%Api.Admin.*`; a write tool's port builds its bodies, fresh reads and call sequences. The outcome reads both `tSC` and `%response.Status`; only the vendor's 404 means no rows. A failure outside `UNLOGGEDREFUSALS` logs at severity 2 and raises the instance's alert state, so a predictable vendor failure is refused before the call.
- **Pairs (AD-8, AD-29, AD-44, AD-64).** `ResourcesOR()` is only a lower bound: read the backing class's check and run the call as a least-privileged role. Administrative resources are required at `USE`. A tool declares each extra pair and refuses by name before any port call; `CLASSICPAGES` lists each extra classic page a write performs. Every gate reaches a screen's requirement through `Screen.Gate.RequiredPairs` (declared set or adjustment, plus the classic page's custom resource), and dispatch refuses a tool whose screen's pairs the user lacks before any mint. Screen permissions' writes are the one either-of check (`%Development:USE` or `%Admin_Secure:USE`); every-pair holds everywhere else. A code save's or create's WRITE pair is an argument pair, read from the namespace the proposal stored.
- **Write kinds.** A merge (AD-4) reads fresh and sends the complete set; a create (AD-54) fingerprints the name's absence, since admin `PUT`s are often upserts; an action (AD-51) fingerprints each precondition. Screen and agent are two callers of one tool (AD-53, AD-55); the screen's Save holds the per-target lock (AD-34). Every write has a read-back (AD-58), a port `Snippet` (AD-59), a change event (AD-14) and `WRITE.TARGETBUSY` after 10 s. A rendered ObjectScript snippet opens no block it does not close on the same line. A write the vendor does not audit is a named AD-15 and AD-53 case.
- **Ids, fields and reads (AD-3, AD-13, AD-36).** A new entity type joins the kernel's closed enum. Fields derive from the endpoint's body template into `screens.generated.ts` and `ToolFields.cls`, regenerated, never hand-merged; an unclassified field is a secret. One declared read serves screen and tool, with at most one per-row detail call.
- **Async, paths, reads (AD-26, AD-21, AD-7).** A write that would queue is refused unless `QUEUEDWRITES` names it. No endpoint accepts a caller's path. A read may write vendor state only in AD-7's six shapes; OcuPilot never calls the vendor's alerts read.
- **Text and self-protection.** OcuPilot answers in its own sentences; vendor text is logged, never sent (AD-39). New codes go in an area error class (`Api/Error.cls` gains only dispatch lines). AD-10's predicates live once in the kernel, inside the confirm's atomic transition, each pinned by a test.
- **What 18.10 left in place.** `PctAccessPort` (`webapp.pctaccess.create` and `.delete`, `READTYPE` `STATE`). `AdminPort` refuses a `Security.PrivilegedRoutine` call naming an application whose type lacks the routine bit (4), before the vendor and unlogged: `GET` 404, `PUT` and `DELETE` 409 `PRIVROUTINE.TYPE`; an absent name passes. AD-10's `PROHIBITED.OCUPILOTROUTINEAPP` refuses every write to `OcuPilotState` and `OcuPilotIdentity` (delete, disable, any field) on every path: the kernel, the web-app delete before its precondition, and `AdminPort`'s privileged-routine branch. A composite id is shown through `ErrorDeleteMint.ReadableId`.
- **18.30, measured at 18.10's first plan** (2026-10-08, `ocupilot-ci`; full notes: `git show 622b70eb:_bmad-output/implementation-artifacts/spec-18-10-web-application-extras-and-spec-based-rest-services.md`). `DocDB` `GET` (`name`, `namespace`) answers `{Description, Enabled, Resource}`; `LIST` adds `Name` and `Namespace`. `PUT` is an upsert (201 on create) and keeps omitted keys. Name and namespace are case-insensitive. The vendor stores a record for an absent namespace, resource or document database. Writes record `%System/%Security/DocDBChange`. The records are `Security.DocDBs` objects only: 19.17's `DocDbPort` create and drop stay unchanged and read no record.
- **18.31, measured there too.** `GET` answers `{MatchRoles[{MatchRole, TargetRoles[]}], Routines[{RoutineOrClass, Db, Type}], Enabled, Resource, Description}`; `LIST` answers `Enabled` false on every row, so `Enabled` comes from `GET` (inference). `PUT` is an upsert; it always sets `Routines` (an omitted list empties them) and keeps an omitted `MatchRoles`, so send the complete set. `Roles` is not in the body. An absent target role answers 500 #879 (validate first); an absent `Resource`, `Db` or routine is stored as given. Writes record `ApplicationChange`. A principal holding exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ` listed, created and deleted Doc DB records and privileged routine applications.
- **18.32 (ruling Q2 (B), written into AD-53 at its spec gate).** The REST create is the agent's second code path, held to 20.21's rules at the mint and at Confirm: every generated name lands in the namespace's own routines database, never `%SYS`, a `%` name or `OcuPilot*`. Extend `ExplorerSave`'s `AgentProblem`, `ConfirmProblem` and `CodeWritePairs` rather than copying them. The card shows the whole document (20.20's new-document pattern); the create's key ships enabled, the delete's, destructive, `false`. Measured: `POST /api/mgmnt/v2/:ns/:app` is an upsert (201, then 200) generating `.spec`, `.disp` and `.impl`; `DELETE` removes `.spec` and `.disp`, keeps `.impl`, and answers 200 for an absent application. An OpenAPI 3.0 document answered 404 and left no class. A `%` name answers 404 and writes a `Protect` audit row, so refuse it first. Neither write records a vendor event. `%REST.API` treats a non-object `swagger` as a URL or server file and fetches it, so the port passes a parsed object (an AD-21 case). The writes need `%Development:USE` and WRITE on the routines database, which `MgmntPort`'s read pairs lack.
- **18.11.** Each read uses its own port and gate. Only `MonitorPort` calls `PrometheusMetrics` (`%Admin_Operate:USE` plus `%DB_IRISSYS:READ`), and each call rewrites sensor baselines. The drill-downs read `/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources`; interoperability usage reads the deprecated InteropMetrics v1. Drop `BusyProcesses`' empty rows. The live tail long-polls with a heartbeat and restarts on rotation.
- **18.12.** Every Stage 2 screen carries a read tool and a confirmed single-write tool; 18.24's wallet key tools and 18.10's `webapp.pctaccess.*` are consumed here. License key activate and `security.secrets.replacesymmetric` stay unadvertised (AD-53). AD-24 already fixes the history rule and result bounds; measure before adding. A proxy is a destination judged by the egress policy (AD-42). `PROHIBITED.OCUPILOTSSL` keeps the installer's SSL configuration's `VerifyPeer`, `CAFile`, `Type` and `Enabled`. OcuPilot deletes only credential entries it created (AD-37).
- **18.13.** One idempotent installer at container start or IPM's `<Invoke>` (AD-17); only the container path unexpires `_SYSTEM`; IPM is never a runtime dependency (AD-18). Code in the install namespace's database, globals in OcuPilot's protected database (AD-9). `PROHIBITED.OCUPILOTNAMESPACE` keys off the namespace the API runs in. Install reads back its schema grant (AD-38).
- **Spine amendments (Rule 20).** Each new pair, predicate, entity type, path case, named case, read shape, `CLASSICPAGES` entry or unaudited write goes into the spine at the spec gate.

## UX & Interaction Patterns

- Every screen registers the 10-item screen contract and three suggested prompts; the side bar lists only built screens.
- New strings go in EXPERIENCE.md's Fixed strings, each refusal sentence once, edited in place; one key per value in `strings.ts`, each cited `/** EXPERIENCE.md:NNN */`. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- Dialogs come only from the closed set and never stack. A destructive confirm names the action and target, states the consequence and requires the name typed exactly.
- Editors are form pages with tabs mirroring the classic page, a sticky Save and an unsaved-changes guard. Gated controls stay focusable and `aria-disabled`, naming their reason through `aria-describedby`.
- Auto-refresh is AD-43's shared framework; log viewers load bounded pages, and the live tail supersedes that only for sources that opt in.
- Panel blocks over eight lines start collapsed; Confirm, consequences and secret fields are never inside one.

## Cross-Story Dependencies

- **Order.** Done: 18.1 to 18.10 and 18.14 to 18.29. Next: 18.30, 18.31, 18.32, 18.11, 18.12, 18.13, then 18.33. 18.31 builds on 18.10's arm and type check. 18.32 waited for 20.21 on feature, which is now met.
- **Epic 20 on slot B** (20.3 next, then 20.22 and 20.4 onward). 20.3 adds the `production-item` entity type and AD-62's item writes. 18.12 overlaps 20.12 (guided workflows over the same registry), and 20.21 and 20.20 (merged) already grow the advertised roster. 18.13 meets 20.1 (per-namespace feature gating).
- **Unassigned rows.** WQM categories (SA-05) and enabling the mirror service (SA-22) name no story; the epic's close assigns or declines each.
- At Epic 18's merge, `Wire.cls`'s doc comments that still name a two-member floor reopen DW-2170.
- Shared files (kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, test rosters, `ci.test.mjs`, `strings.ts`, `navigation.ts`, EXPERIENCE.md, the spine) take add-only edits, unioned at merges.
