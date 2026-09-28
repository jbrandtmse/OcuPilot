# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Take OcuPilot from the contest's Release 1 to System Administration and System Operation parity on the experimental `/api/admin` service: namespaces and their mappings, database configuration with its create, delete, properties and volume editors, the disk operations the contest list deferred, and then journals, licensing, ECP, superservers, authentication options, MFT, encryption, SQL privileges and the web-application extras. Each screen arrives with a read tool and a confirmed single-write tool from one descriptor, so the agent grows with the portal. Stage 2 ships as the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, which is why the containment, inventory and path rules below carry most of the weight. This run covers 18.1 to 18.4; 18.1 is done, and 18.3 is the first consumer of what it shipped.

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

## Requirements & Constraints

- **One contract, no second way to build a screen.** Every screen:
  - is declared by exactly one descriptor;
  - reaches outside only through one port;
  - derives its read tool, and its write tools' field lists, from that descriptor, with no hand-written tool code;
  - writes only through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker.

  No feature-level spec exists for these rows. A story's acceptance is this contract plus each row's own backing route; finer criteria are written at the story's plan, never invented in advance.
- **Gates on the stage.**
  - Write payloads are observed on the instance before any form is built. For 18.2 to 18.4 that means the slot's throwaway, because the probes delete, dismount and truncate.
  - Async operations use the port's async path.
  - The allow-list (18.1) has landed, so server-path pickers may now be built.
  - The owner amended the 2027.1 gate on 2026-09-26: Stage 2 builds on the pinned 2026.2 image, and the inventory is re-derived against 2027.1 when that ships.
- **Governance keys.**
  - Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change; `OcuPilot.Test.GovernanceBaseline` fails naming any registered key without one. The epic preamble's "absent from the baseline" wording predates that rule.
  - Destructive and disruptive keys enter as `false`: delete namespace, delete database, dismount, truncate, encryption changes, and every 18.4 operation (mount, dismount, truncate, compact, defragment, expand, integrity check).
  - Through 2026-10-04 any other key enters `true` unless its story's criteria say disabled; after that the owner decides how keys enter. A mapping delete and a mapping copy are named neither way, so the 18.2 spec gate says which.
  - Keys are `tool`, or `tool:action` for a tool that declares its governance action argument.
- **Reads and gates.** Every read is bounded and reports truncation, and every gate uses the caller's own privileges at call time. No slice writes polling logic.
- **Catalog rows, by row title:**
  - 18.1: SH-24.
  - 18.2: SA-03 and SA-11 to SA-15.
  - 18.3: SA-16 to SA-21.
  - 18.4: OS-16 to OS-22.
  - Later stories: SA-04, SA-06 to SA-10, SO-01 to SO-08, CP-35/39/41, WA-10 to WA-14, PM-19 to PM-22, SS-28 to SS-35, OS-30, LG-11 and PK-25.

  No story names SA-05 (WQM categories) or SA-22 (enable mirror service).
- **Routed ledger items.**
  - DW-236 (a widened SQL grant on OcuPilot's state schema goes undetected) belongs to 18.9.
  - DW-219 (Uninstall's three half-state paths) and DW-423 (`Kernel.State.Stamp` has no retention) belong to 18.13.
  - DW-1774 is routed to 18.7 but binds every screen-adding story. Browser specs pin area side bars as literal lists, and Rule 29 runs only a story's own specs, so extend every pinned list of your area: `grep -l ocu-side-bar-label ui/browser`, plus `ui/tools/navigation.test.mjs`.
- **Bundle budget.** `maximumWarning` is 2106kB, re-based under DW-1166 at 5% above the measured total. `ui/tools/angular-json.test.mjs` pins the literal. The hard stop is 4000kB. Re-measure after any merge that moves it.
- **Planning documents cited by line.** EXPERIENCE.md and epics.md are cited by line elsewhere, so an edit to either also runs `cd ui && npm run test:tools`.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort`, or a port extending it, names an `%Api.Admin.*` class. It reproduces `Main()`'s sequence exactly:
  - stub `%request`, `%response` and `%session`, with `IsRunningAsync` 0;
  - evaluate `ResourcesOR()` before the query parameters;
  - call `ValidateQueryParams()`, then capture output;
  - treat a non-2xx `%response.Status` as a failure even when `tSC` is OK.

  A call may go through the vendor's own class only as a named AD-27 case, written into the spine, and only where the admin API cannot carry it. Before using an endpoint outside the inventory fixture, re-run the audit; CI fails when the instance drifts from the fixture.
- **Server paths (AD-21's sixth case, shipped by 18.1).** The caller names a **root** and a **relative name**, never a path.
  - **Roots.** `Port/PathPort` alone computes them, on every call and never cached. They are the `%GUIFileSelector` purpose's roots when that purpose is restricted; otherwise the manager directory alone (`/durable/iris/mgr/` on the project containers).
  - **Root check.** A root must equal a root the read answers, character for character.
  - **Name check.** The relative name is empty, or at most 8 `/`-separated segments, each matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`. A literal `..` is refused, and a file needs at least one segment.
  - **Refusals.** `PATH.ROOT` or `PATH.NAME`, on the named field, before any vendor call. No refusal echoes a path.
- **What a path consumer does.** 18.3 is the first consumer. It:
  - declares `root` and `path` arguments;
  - declares the port's pairs `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ` on the tool, under AD-8's endpoint clause;
  - calls `PathPort.Resolve(root, path, kind)` at the mint and again at the write, so a root dropped after the mint refuses the confirm;
  - sends the composed path under the vendor's own field, which is never a settable tool field;
  - embeds `app-server-path-picker` (`ui/src/app/shell/server-path-picker.ts`), fed by an `AllowedDirectoriesStore` (`ui/src/app/core/allowed-directories.ts`) that its page owns;
  - renders `PATH.*` violations on the picker.

  Never add a client copy of the segment rule, a free-text path, or subdirectory browsing. The roots are the Security › Allowed directories read (`security.alloweddirectories.read`, source port `path`, rows `{Directory, Restricted}`), so the screen, the tool and every picker show one list.
- **Who holds the path pair.** Measured: `%Operator` does not hold `%Admin_FileSystemAccess:U`. `%Manager`, `%SecurityAdministrator`, `%Admin_Secure` and the resource's own role do.
- **Open decision DW-1770 (decision-pending, owner).** Should `PathPort.Resolve` refuse an existing file or an instance file (such as `IRIS.DAT` or `messages.log`) for kind `file`? It affects file-writing consumers, not 18.3's directory.
- **Remote database directory (18.3).** A remote database's directory lives on its data server, so the local allow-list cannot supply it (inference). The catalog's `/ecp/data-server/databases` read is the candidate source. AD-21 still forbids free text, so anything else needs a new AD-21 case.
- **Async (AD-26).** A request is async per request type, never per class. The Stage 2 async set:
  - `Database.Actions`: every type except mount and dismount. Compact, defragment and integrity queue themselves. This is wider than 18.4's criteria, which name three, so read the fixture before planning.
  - `Namespace.Namespace`: interop and mappings, so 18.2's enable-interop and copy-mappings.
  - `Journal.File`: integrity check.
  - `ECP.DataServer`: the server action.
  - `Security.LDAP`: test connection.
  - `Journal.Record`: LIST.

  For `TYPEINFO` the poll was measured to expose only `State` and a once-written `Result`. Whether the 18.4 operations report finer progress is unmeasured (inference), so measure before promising a progress figure.
- **Queued writes.** The port refuses a mutating request that would queue unless it is on `QUEUEDWRITES`. Each Stage 2 queued write needs its own named entry, whose body carries no secret. A write still running past the bound is recorded as applied and marked, and the screen and the agent both say it is "started, still running". Polling needs `%Admin_Operate:USE` (the `AsyncResult` gate), so a tool whose screen set lacks that pair declares it itself.
- **Privilege pairs (AD-8, AD-29).**
  - `ResourcesOR()` is only a lower bound. Establish each set by reading the backing class's own check and by running a least-privileged principal on a throwaway, never one holding `%Operator`, which carries `%DB_IRISSYS:RW`.
  - Administrative resources are required at `USE`, never `WRITE`.
  - A tool declares extra pairs only in AD-8's two named situations: the vendor class writes a database the screen's read does not, or an endpoint its call necessarily reaches names the resource (the async poll, `PathPort`).
  - An area's pair set must cover its screens' pairs, or `Screen.Registry.AreaCoverageProblem` refuses. A screen that needs more declares the extra pair in `ownPrivileges`. Precedents: Logs' interoperability and analytics logs; Security's wallet, OAuth and Allowed directories screens. A caller who lacks an own pair loses that screen only.
- **Field lists (AD-3).** A tool's fields come from the endpoint's body-template method: `RequestBodySchema`, then `PutRequestBodySchema`, then `PutAndPostSchema`, then `Schema`.
  - Of the 16 mutating endpoints that publish no template, 11 are Stage 2 or later. Derive their fields from the underlying class and pin that with a test.
  - Every field is classified `ordinary`, `secret` or `opaque`. An unclassified field is emitted as secret, and a string field whose name matches the credential pattern must be secret.
- **Write kinds.**
  - **Merge (AD-4):** read fresh and send the complete set. Measure whether each new `PUT` (namespace, mapping, database) erases omitted fields and whether it is an upsert.
  - **Create (AD-54):** fingerprint the name's absence, whatever the vendor does. Namespace create and edit share `PUT /namespace`, which makes create an upsert (inference).
  - **Two admin calls.** The catalog lists database create as two admin calls (`POST /database-dir`, then `PUT /database`) and delete as two (`DELETE /database`, `DELETE /database-dir`). One tool still carries each write (AD-55), and its plan settles how the declared port (AD-52) sequences them.
  - **Action-style (AD-51), which covers the disk operations:** a declared request type and no body. The fingerprint subject is every field the action's precondition reads. A fixed or caller-chosen vendor body, such as a truncate target or an integrity selection, is built by the port under a new named AD-51 entry.
  - **Secret-only body (AD-56).**
- **Two callers, one tool (AD-53, AD-55).** A screen's Save or row action and the agent's confirmed write run the same tool. The screen caller emits no marker and is not gated by read-only or the kill switch. Prohibited-set predicates are stated over the effect, so a bodyless delete is covered too.
- **Prohibited set (AD-10).**
  - Already refused: deleting OcuPilot's own database, web applications, resource or role; disabling its serving application or `%Service_WebGateway`.
  - The namespace and database delete wizards cascade to dependent databases and applications, so every predicate must hold over the whole cascade's effect.
  - Candidates to add to the kernel set at the spec gate (inference), because each reaches the serving path or AD-9's protected state:
    - deleting the install namespace;
    - dismounting or deleting OcuPilot's state database or the install namespace's code database;
    - a mapping that moves OcuPilot's package or globals.

    An effect that must never be reachable goes into the kernel set, never into a policy file.
- **Removal impact (AD-8).** A delete carries an impact computed on the instance, once at mint (kept on the proposal row) and again when the dialog opens. 18.2 lists the databases and web applications that depend on the namespace; 18.3 lists the namespaces and applications that depend on the database.
  - Each part is read through the owning screen's declared read, with the caller's own privileges.
  - A part the caller cannot read is reported as unchecked and names the missing pair, never as "no impact".
  - A target the prohibited set refuses shows that refusal's reason.
  - The impact is names only, and never enters screen context or a tool result.
- **Creating a database.**
  - Its resource must be named `%DB_<NAME>`, and it is created before the database. `SYS.Database` does not validate that the resource exists, so a database created first is silently `%All`-only.
  - Creating the resource auto-creates an implicit role that is granted to nobody.
  - A grant must be read back to be believed.
- **Identity and events (AD-13, AD-14).**
  - Each reference carries the triple `(type, scope, id)`, where the scope is `instance` for a configuration object with no namespace.
  - Each new type (namespace, mapping, database and so on) joins the kernel's closed entity-type enum and states its canonical-spelling rule.
  - A composite id, such as a mapping's namespace, kind and name, is one segment with named parts, joined by the shared encoder (AD-5).
- **Descriptors (AD-5, AD-36, AD-44).**
  - New descriptors go into existing slices.
  - Each declares the classic page class it replaces: `%CSP.UI.Portal.Namespaces`, `.Namespace`, `.NamespaceEdit`, `.Mappings`, `.Databases`, `.Database`, `.DatabaseVolumes` or `.RemoteDatabases`. A descriptor with no classic page says so. A list never links out.
  - A page may issue another built screen's read, as Database details already shows volumes beside properties.
  - A tabbed editor is one descriptor per tab.
  - A form or wizard reached from its list takes `sideBarPosition` 0.
- **Every write tool also gets:**
  - the read-back (AD-58);
  - a script form (AD-59): each port's `Snippet` mirrors every branch of its `Invoke`, and a registry test fails when a tool has none;
  - the change event and the marker (AD-14, AD-15);
  - the switch to `%SYS` by explicit save and restore (AD-16).
- **Mappings (18.2).** Harvest the `%`-global guard from the sibling's mapping manager (execute-mcp `Config:MappingManage`). Read its current body first, and rename it into OcuPilot's names.
- **Rules for later stories:**
  - **18.5:** journals stay in System Operation, not Logs. The journal directories are path consumers.
  - **18.6:** ECP relies on the routes alone.
  - **18.7:** `Security.Encryption.Settings` is excluded by the v2 pin, so establish the reachable subset first. Key material is write-only.
  - **18.8:** a change to authentication options that would break OcuPilot's own sign-in is refused under AD-10's serving-path rule.
  - **18.9:** its criteria still refuse an `%All` or `%Admin_*` grant, but AD-10 now permits such grants at the strongest confirmation and prohibits only application roles on OcuPilot's own applications. The spine governs; reconcile at the story's spec gate.
  - **18.10:** `MgmntPort` runs in process, and no tool makes an HTTP call (AD-1).
  - **18.11:** the monitoring API's anonymous reach never becomes OcuPilot's (AD-29). A new listed Logs screen joins the log hub's composed read.
  - **18.12:** a proxy is judged like the endpoint, and a marked-local endpoint bypasses it (AD-42). The wallet becomes a new rung on the credential ladder.
  - **18.13:** one idempotent installer (AD-17), and OcuPilot's globals stay in its protected database (AD-9).

## UX & Interaction Patterns

- **The screen contract.**
  - Each screen registers the same 10 things. The side bar lists only built screens, and every new string goes into EXPERIENCE.md's Fixed strings.
  - EXPERIENCE.md's side-bar table places no namespace or database-configuration screen yet: OS management lists Databases, and Database details opens from its name cell. 18.2 and 18.3 add their placements.
  - A refusal sentence is published once and pinned to the kernel's copy (AD-53).
- **Destructive actions on a screen** use a one-level `confirm-dialog`, never stacked:
  - the title names the action and the target;
  - the body states the consequence and ends "This cannot be undone.";
  - a typed-name field requires an exact, case-sensitive match.

  An agent proposal carries no typed-name field: its confirmation is the destructive bar plus the Confirm press.
- **Wizards** follow the New Task precedent: a vertical, linear stepper. Next validates the step, Back keeps values, and a step with an error names it in text ("This step needs attention: <reason>"). The integrity-check wizard and its log viewer form one flow, replacing four classic dialogs.
- **Editors** are form pages whose tabs mirror the classic editor, with one form across all tabs and a sticky Save.
- **The path picker.** It offers only the read's roots. Its one text entry is the relative name, and the composed path is display only. The server's `PATH.*` reason renders on the field it names.
- **Gated controls** stay focusable with `aria-disabled` and name their reason. A self-protection refusal is drawn the same way.
- **Live data.**
  - Databases and Database details auto-refresh. Auto-refresh pauses while a proposal on the same entity type is live (AD-43).
  - Async values render as skeleton cells until they resolve.
  - Log viewers load bounded pages; that rule yields only for sources that opt into 18.11's live tail.

## Cross-Story Dependencies

- **18.1 is done.** It shipped `PathPort`, the Security › Allowed directories screen and its read tool, the picker and the store, and AD-21's sixth case, with AD-8 naming the screen's own pair. Its resolver and picker have no consumer yet.
  - First consumer: 18.3, for the database create directory and any directory field its properties or volume editors expose.
  - Later consumers: 18.5 (journal directories), 16.4 (task export and import file), 19.2 and 19.8 (export and import files), and 21.2 (backup location).
- **18.2 and 18.3.** 18.2's inline create-database step (SA-13) reuses 18.3's create wizard (SA-20). Either 18.2 ships without the step and 18.3 adds it, or the order changes; settle this at 18.2's plan.
- **18.3 and 18.4.** 18.3's multi-volume save-and-expand (SA-18) and 18.4's expand volume (OS-21) share `POST /database-dir/expand-volume`, so they share one tool, owned by whichever story lands first.
- **18.4 and Epic 6.** 18.4 acts on the databases that Epic 6's read-only Databases list and Database details already show.
- **18.4 and DW-1770.** The integrity-check output file (OS-22) would be a file-kind `PathPort` consumer, which DW-1770 bears on (inference).
- **Shipped machinery these stories build on:**
  - governance (Epic 14: the baseline and its test, and the dispatch and Confirm gates);
  - the copy-out draft (14.1) and the sanitizer (14.3);
  - the read-back (16.17) and the removal impact (16.19);
  - `Kernel.Shell.Effective`, the one effective-privilege composition (16.3).
- **Shared files.** Epics 16 and 23 are still in progress on other slots, so edits stay add-only:
  - the kernel, the registry, `Error.cls` and the test rosters;
  - `strings.ts` and EXPERIENCE.md.

  `screens.generated.ts` is regenerated rather than hand-merged.
- **Stage 3 onward** relies on 18.1's allow-list for its server-path pickers.
