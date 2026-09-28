# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Take OcuPilot from the contest's Release 1 to System Administration and System Operation parity on the experimental `/api/admin` service: namespaces and their mappings, database configuration with its create, delete, properties and volume editors, the disk operations the contest list deferred, and then journals, licensing, ECP, superservers, authentication options, MFT, encryption, SQL privileges and the web-application extras. Each screen arrives with a read tool and a confirmed single-write tool from one descriptor, so the agent grows with the portal. Stage 2 ships as the first versioned IPM release after the contest, and it deepens the dependency on an experimental API by about twenty screens, which is why the containment, inventory and path rules below carry most of the weight. 18.1 is done and on feature (`9b5e3a6e`). This run covers, in order, 18.2 (namespaces only since the split), 18.14 (mappings and copy-mappings), 18.3 and 18.4.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings (namespaces only; mappings moved to 18.14)
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
- Story 18.14: Namespace mappings and copy-mappings (split from 18.2; runs right after 18.2, before 18.3)

## Requirements & Constraints

- **One contract, no second way to build a screen.** Every screen is declared by exactly one descriptor, reaches outside only through one port, derives its read tool and its write tools' field lists from that descriptor with no hand-written tool code, and writes only through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. No feature-level spec exists for these rows: a story's acceptance is this contract plus each row's own backing route, and finer criteria are written at the story's plan, never invented in advance.
- **Gates on the stage.**
  - Write payloads are observed on the instance before any form is built. For 18.2 to 18.4 that means the slot's throwaway, because the probes delete, dismount and truncate.
  - Async operations use the port's async path. The allow-list has landed, so server-path pickers may be built.
  - Stage 2 builds on the pinned 2026.2 image (owner, 2026-09-26); the inventory is re-derived against 2027.1 when that ships.
- **Governance keys.**
  - Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change; `OcuPilot.Test.GovernanceBaseline` fails naming any registered key without one.
  - Enter as `false`: namespace delete, database delete, dismount, truncate, encryption changes, and every 18.4 operation (mount, dismount, truncate, compact, defragment, expand, integrity check).
  - Enter as `true` (orchestrator ruling at 18.2's gate): mapping deletes and copy-mappings. Each still takes the destructive or strongest-confirmation treatment.
  - Through 2026-10-04 any other key enters `true` unless its story's criteria say disabled; after that the owner decides. Keys are `tool`, or `tool:action` for a tool that declares its governance action argument.
- **Reads and gates.** Every read is bounded and reports truncation, every gate uses the caller's own privileges at call time, and no slice writes polling logic.
- **Catalog rows:**
  - 18.2: SA-03 (list), SA-12 (edit), SA-13 (create) and SA-15 (delete). SA-13's inline create-database is 18.3's, its enable-interop is 18.14's, and the admin API creates no web application.
  - 18.14: SA-11 (global, routine and package mappings), SA-14 (copy-mappings) and SA-13's enable-interop (DW-1776).
  - 18.3: SA-16 to SA-21. 18.4: OS-16 to OS-22.
  - Later stories: SA-04, SA-06 to SA-10, SO-01 to SO-08, CP-35/39/41, WA-10 to WA-14, PM-19 to PM-22, SS-28 to SS-35, OS-30, LG-11 and PK-25. No story names SA-05 or SA-22.
- **Routed ledger items.**
  - DW-1776 (18.14): observe enable-interop's payload on the throwaway with a probe database; it writes interoperability code into the namespace's databases and, being async, needs its own queued-write entry.
  - DW-1779 (18.3): a directory-kind location may be the manager directory itself, where IRISSYS's `IRIS.DAT` lives. The database directory must refuse it, or any directory already holding an `IRIS.DAT`; first probe whether the admin API's create accepts such a directory.
  - DW-1774 (routed to 18.7, binds every screen-adding story): browser specs pin area side bars as literal lists and Rule 29 runs only a story's own specs, so extend every pinned list of your area (`grep -l ocu-side-bar-label ui/browser`, plus `ui/tools/navigation.test.mjs`).
  - DW-1777 and DW-1778 (18.7): the file kind's gaps, below. DW-236 (18.9); DW-219 and DW-423 (18.13).
- **Bundle budget.** This branch's `maximumWarning` is 2106kB; feature's is 2107kB (Epic 16's re-base under DW-1166), and the next integrate-forward takes feature's value. `ui/tools/angular-json.test.mjs` pins the literal. The hard stop is 4000kB; stop and ask above 3800kB.
- **Planning documents cited by line.** EXPERIENCE.md (993 lines, edited in place) and epics.md are cited by line elsewhere, so an edit to either also runs `cd ui && npm run test:tools`.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort`, or a port extending it, names an `%Api.Admin.*` class, reproducing `Main()`'s sequence: stub `%request`, `%response` and `%session` with `IsRunningAsync` 0; `ResourcesOR()` before the query parameters; `ValidateQueryParams()`; captured output; a non-2xx `%response.Status` is a failure even when `tSC` is OK. A call through the vendor's own class is allowed only as a named AD-27 case written into the spine. Re-run the inventory audit before using an endpoint outside the fixture.
- **Measured on `ocupilot-b-ci` at 18.2's first plan (2026-09-28).**
  - **Namespace `PUT`** is an upsert that keeps omitted fields, and a create makes no web application, mapping or database. Lower case is stored upper.
  - **Namespace `DELETE`** removes the namespace, its mappings and every web application bound to it. It never deletes a database, and an application referencing the namespace never blocks it. Never send `maxRows` on it: it limits the application cascade.
  - **Mapping `PUT`** is an upsert keeping omitted fields. Templates: global `{Database, LockDatabase, Collation}`; routine and package `{Database}`. A subscript mapping also creates the base mapping on the default database. Deleting a base mapping while a subscript mapping exists answers 500. The vendor has no `%`-global guard.
  - **Copy-mappings** (`POST /namespace/copy-mappings {SourceNamespace, DestinationNamespace}`) answers 202 with a location. The poll carries `State`, `Console`, `FailureReason`, an empty `Result` and times, and **no progress field**. The copy merges, the source winning on a name. An absent source still answers 202, then fails. The v2 async `Location` points at `/v1`.
  - **Pairs.** Reads need `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, which OS management covers. Every namespace and mapping write also needs `%DB_IRISSYS:WRITE` (`<PROTECT>` otherwise, nothing changed). Namespace delete also needs `%Admin_Secure:USE`: without it the vendor answers 500 after deleting and orphans the bound applications, so the tool refuses by name before any port call. Copy needs `%Admin_Operate:USE` for the poll, which is owner-only.
  - Whether database configuration writes need `%DB_IRISSYS:WRITE` too is unmeasured (inference); measure at 18.3's plan.
  - DW-1775 holds eight vendor defect candidates from these probes (decision-pending, human report).
- **Not yet in the spine.** 18.2's first plan proposed amendments that its re-plan and 18.14's plan must each write at their own spec gate:
  - AD-8's pair cases;
  - AD-10's install-namespace predicate and OcuPilot-mapping predicate;
  - AD-26's queued-write entry for `MAPPINGS`;
  - AD-36's seeding of a parent's key onto a child list's rows;
  - AD-51's port-built copy body.

  The Part B research (payloads, amendments, tasks) survives in the 18.2 spec's history at `f473ce9b`.
- **The `%`-global guard (18.14).** Harvest it from the sibling's mapping manager (execute-mcp `Config:MappingManage`), reading its current body first and renaming it into OcuPilot's names. Orchestrator ruling: a `%`-global create is **permitted at the strongest confirmation**, AD-10's privilege-grant idiom, never banned. An agent proposal is minted destructive, and a person's Save shows a consequence line. No request field such as the sibling's `force` bypasses anything. The first plan widened coverage to every `%` name and to edit, because the vendor creates a subscript's base mapping (measured for a non-`%` global; for `%`, inference).
- **Mapping identity (18.14).** Vendor mapping rows carry no namespace, so the id is composite (namespace plus name), one segment joined by the shared encoder (AD-5, AD-13). The first plan split on `$Char(1)`, because a global subscript can contain `/`.
- **Server paths (AD-21's sixth case).** The caller names a **root** and a **relative name**, never a path.
  - **Roots.** `Port/PathPort` alone computes them on every call, never cached: the `%GUIFileSelector` purpose's roots when that purpose is restricted, otherwise the manager directory alone.
  - **Checks.** A root must equal a root the read answers, character for character. The name is empty, or at most 8 `/`-separated segments matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`; a literal `..` is refused, and a file needs at least one segment.
  - **Refusals.** `PATH.ROOT` or `PATH.NAME`, on the named field, before any vendor call, never echoing a path.
  - **Files (DW-1770, resolved).** An existing name is refused `PATH.EXISTS` unless the consuming tool declares it overwrites (`pOverwrite`), and a name directly in the manager directory is refused `PATH.MANAGER`. A directory is unaffected, hence DW-1779.
  - **Open, routed to 18.7.** DW-1777: `iris.cpf` and the sub-databases' `IRIS.DAT` sit outside the manager-directory refusal. DW-1778: no must-exist mode, so a consumer reading an existing file is refused unless it passes `pOverwrite`, which no tool declaration ties it to.
- **What a path consumer does.** 18.3 is the first; 18.2 and 18.14 take no path. A consumer:
  - declares `root` and `path` arguments, and the port's pairs `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ` on the tool under AD-8's endpoint clause;
  - calls `PathPort.Resolve` at the mint and again at the write, so a root dropped after the mint refuses the confirm;
  - sends the composed path under the vendor's own field, never a settable tool field;
  - embeds `app-server-path-picker` fed by an `AllowedDirectoriesStore` its page owns, and renders `PATH.*` violations on it.

  Never add a client copy of the segment rule, a free-text path or subdirectory browsing. Measured: `%Operator` lacks `%Admin_FileSystemAccess:U`; `%Manager`, `%SecurityAdministrator`, `%Admin_Secure` and the resource's own role hold it.
- **Remote database directory (18.3).** It lives on its data server, so the local allow-list cannot supply it (inference). `/ecp/data-server/databases` is the candidate source; anything else needs a new AD-21 case.
- **Async (AD-26).** A request is async per request type, never per class.
  - `Database.Actions`: every type except mount and dismount, and compact, defragment and integrity queue themselves. That is wider than 18.4's criteria name, so read the fixture first.
  - `Namespace.Namespace`: interop and mappings, so enable-interop and copy-mappings.
  - Later: `Journal.File` integrity, `ECP.DataServer`, `Security.LDAP` test, `Journal.Record` LIST.
  - **"Progress."** For copy-mappings it is a running line, then done or still running (orchestrator ruling). The `TYPEINFO` poll too exposes only `State` and a once-written `Result`. Whether 18.4's operations expose any finer figure is unmeasured (inference), so measure before promising one.
- **Queued writes.** The port refuses a mutating request that would queue unless it is on `QUEUEDWRITES`. Each Stage 2 queued write needs its own named entry, whose body carries no secret: copy-mappings, enable-interop, and 18.4's queued operations. Within the bound the confirm answers the outcome. Past it, the write is recorded applied and marked, and screen and agent both say "started, still running". A tool whose screen set lacks `%Admin_Operate:USE` declares it for the poll.
- **Privilege pairs (AD-8, AD-29).**
  - `ResourcesOR()` is only a lower bound. Establish each set from the backing class's own check plus a least-privileged principal on the throwaway, never `%Operator`, which carries `%DB_IRISSYS:RW`.
  - Administrative resources are required at `USE`, never `WRITE`. A tool declares extra pairs only in AD-8's two cases: the vendor class writes a database the screen's read does not (the namespace writes' `%DB_IRISSYS:WRITE`), or an endpoint its call necessarily reaches names the resource (the delete's `%Admin_Secure`, the async poll, `PathPort`).
  - An area's pair set must cover its screens' pairs (`Screen.Registry.AreaCoverageProblem`), unless a screen declares the extra pair in `ownPrivileges`.
- **Field lists (AD-3).** A tool's fields come from the endpoint's body-template method (`RequestBodySchema`, then `PutRequestBodySchema`, `PutAndPostSchema`, `Schema`). Of the 16 mutating endpoints with no template, 11 are Stage 2 or later: derive those fields from the underlying class and pin them with a test. Classify every field `ordinary`, `secret` or `opaque`; an unclassified field is emitted secret.
- **Write kinds.**
  - **Create (AD-54):** fingerprint the name's absence. Namespace and mapping creates need it, since their `PUT`s are measured upserts.
  - **Merge (AD-4):** read fresh and send the complete set. The database `PUT` is unmeasured: measure whether it erases omitted fields and whether it upserts.
  - **Two admin calls, one tool (AD-55).** Database create is `POST /database-dir` then `PUT /database`, and delete is `DELETE /database` then `DELETE /database-dir`. The tool's declared port (AD-52) sequences them, settled at 18.3's plan.
  - **Action-style (AD-51), including the disk operations:** a declared request type and no body. The fingerprint subject is every field the action's precondition reads. A fixed or caller-chosen vendor body (copy-mappings' source, a truncate target, an integrity selection) is built by the port under a new named AD-51 entry.
- **Two callers, one tool (AD-53, AD-55).** A screen's Save or row action and the agent's confirmed write run the same tool. The screen caller emits no marker and is not gated by read-only or the kill switch. Prohibited-set predicates are stated over the effect, so a bodyless delete is covered.
- **Prohibited set (AD-10).**
  - Already refused: deleting OcuPilot's own database, web applications, resource or role; disabling its serving application or `%Service_WebGateway`.
  - The namespace delete cascades to its bound web applications, and the database delete to dependent namespaces and applications, so every predicate must hold over the whole cascade's effect.
  - 18.2's first plan added `PROHIBITED.OCUPILOTNAMESPACE`: deleting, or changing the `Globals` or `Routines` database of, OcuPilot's install namespace or `%SYS`. The install namespace is the `NameSpace` of OcuPilot's API application, read at the write.
  - Candidates, each reaching the serving path or AD-9's protected state (inference):
    - 18.14: a mapping, or a copy into the install namespace or `%ALL`, that moves OcuPilot's package or globals.
    - 18.3 and 18.4: dismounting or deleting OcuPilot's state database or the install namespace's code database.
  - An effect that must never be reachable goes into the kernel set, never a policy file.
- **Removal impact (AD-8).** A delete carries an impact computed on the instance at mint (kept on the proposal) and again when the dialog opens, each part read through the owning screen's declared read with the caller's own privileges.
  - 18.2: the web applications deleted with the namespace, and its databases, which stay.
  - 18.3: the namespaces and applications that depend on the database.
  - A part the caller cannot read is reported unchecked, naming the pair. A target the prohibited set refuses shows that refusal. The impact is names only and never enters screen context or a tool result.
- **Creating a database.** Its resource must be `%DB_<NAME>` and is created first, because `SYS.Database` does not check that it exists and a database created first is silently `%All`-only. The resource's implicit role is granted to nobody. A grant must be read back to be believed.
- **Identity and events (AD-13, AD-14).** Each reference carries `(type, scope, id)`, scope `instance` for configuration objects. Each new type joins the kernel's closed entity-type enum with its canonical-spelling rule: namespace is scope `instance`, id `Name`, fold case (18.2's first plan).
- **Descriptors (AD-5, AD-36, AD-44).** New descriptors go into existing slices. Each declares the classic page it replaces (`%CSP.UI.Portal.Namespaces`, `.Namespace`, `.NamespaceEdit`, `.Mappings`, `.Databases`, `.Database`, `.DatabaseVolumes`, `.RemoteDatabases`), or says it has none. A list never links out. A page may issue another built screen's read, a tabbed editor is one descriptor per tab, and a form or wizard reached from its list takes `sideBarPosition` 0.
- **Every write tool also gets** the read-back (AD-58), a `Snippet` mirroring every branch of its port's `Invoke` (AD-59; a registry test fails without it), the change event and marker (AD-14, AD-15), and `%SYS` by explicit save and restore (AD-16).
- **Later stories.** 18.5's journals stay in System Operation and their directories are path consumers. 18.7 establishes the encryption subset first and settles the file kind (DW-1777, DW-1778). 18.9's criteria predate AD-10's permitted grants, and the spine governs. 18.13 keeps one idempotent installer and must keep the install-namespace predicate holding.

## UX & Interaction Patterns

- **The screen contract.** Each screen registers the same 10 things. The side bar lists only built screens, and every new string goes into EXPERIENCE.md's Fixed strings.
  - EXPERIENCE.md's side-bar table places no namespace or database-configuration screen yet; each story adds its placement.
  - 18.2's first plan put Namespaces in OS management beside Databases at `sideBarPosition` 6 (1 to 5 are taken). Mapping lists are unlisted, reached from the namespace editor, and the agent reaches them by route and command box: a list's name cell reaches one editor or one child list, never three.
  - A refusal sentence is published once and pinned to the kernel's copy (AD-53).
- **Destructive actions on a screen** use a one-level `confirm-dialog`: the title names the action and target; the body states the consequence and ends "This cannot be undone."; a typed-name field requires an exact, case-sensitive match. An agent proposal carries no typed-name field. The namespace delete is that dialog with the impact advisory, not a stepper, because the vendor offers no choice.
- **Wizards** follow the New Task precedent: a vertical, linear stepper; Next validates the step, Back keeps values, and a step with an error says "This step needs attention: <reason>". The integrity-check wizard and its log viewer form one flow replacing four classic dialogs.
- **Editors** are form pages whose tabs mirror the classic editor, with one form across all tabs and a sticky Save.
- **The path picker** offers only the read's roots. Its one text entry is the relative name, the composed path is display only, and a `PATH.*` reason renders on the field it names.
- **Gated controls** stay focusable with `aria-disabled` and name their reason, and a self-protection refusal is drawn the same way.
- **Live data.** Databases and Database details auto-refresh, pausing while a proposal on the same entity type is live (AD-43). Async values render as skeleton cells until they resolve. An async write shows a running line, then done or still running.

## Cross-Story Dependencies

- **18.1 is done** (on feature, `9b5e3a6e`). It shipped `PathPort`, the Security › Allowed directories screen and its read tool, the picker and its store, and AD-21's sixth case. Its first consumer is 18.3; later ones are 18.5, 16.4, 19.2, 19.8 and 21.2.
- **18.2 → 18.14.** 18.14 runs immediately after 18.2. It builds its mapping lists under 18.2's namespace editor and reuses 18.2's namespace identity and port, and its plan starts from the Part B research at `f473ce9b`.
- **18.2 and 18.14 → 18.3.**
  - SA-13's inline create-database step is 18.3's, added to the namespace form after 18.3's create wizard exists.
  - SA-15's optional database delete is 18.3's delete, not chained into the namespace delete.
  - 18.3's delete impact reads 18.2's namespace list (`Globals`, `Routines`, `TempGlobals`).
- **18.3 and 18.4.** 18.3's save-and-expand (SA-18) and 18.4's expand volume (OS-21) share `POST /database-dir/expand-volume`, so one tool is owned by whichever story lands first. 18.4's criteria make its key disabled, so reconcile that at 18.3's spec gate if 18.3 lands it.
- **18.4 and Epic 6.** 18.4 acts on the databases Epic 6's read-only Databases list and Database details already show.
- **18.4 and the file kind.** The integrity-check output file would be a file-kind `PathPort` consumer (inference): new names only unless it declares overwrite, never directly in the manager directory. DW-1777 and DW-1778 are 18.7's, so a file consumer landing first meets them first.
- **Shipped machinery these stories build on:** governance (Epic 14: the baseline and its test, the dispatch and Confirm gates), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17), the removal impact (16.19), and `Kernel.Shell.Effective` (16.3).
- **Shared files.** Epics 16 and 23 are still in progress on other slots, so edits stay add-only: the kernel, the registry, `Error.cls`, `Router.cls`, `Baseline.cls`, the test rosters, `ci-throwaway.sh` and `ci.test.mjs`, `strings.ts` and EXPERIENCE.md. `screens.generated.ts` is regenerated, never hand-merged.
