# Epic 6 Context: Every screen in the six areas reads live

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 3. Every remaining list, detail and viewer in the six areas reads live instance data, so
no area stops at one screen and the side bar has no dead entries, and each screen's agent read tool
arrives with it from the same descriptor. The epic is read-only: the writes these screens host
arrive in Epics 7, 8, 9 and 12. It depends on Epic 2 alone and runs in parallel with Epic 4.

## Stories

- Story 6.1: The REST API explorer and its OpenAPI document viewer (done)
- Story 6.2: The roles, resources and services lists (done)
- Story 6.3: The X.509, LDAP/Kerberos and wallet lists (done)
- Story 6.4: The OAuth 2.0 screen (done)
- Story 6.5: On-demand and upcoming tasks (done)
- Story 6.6: Task history, per task and across tasks (done)
- Story 6.7: Task details
- Story 6.8: Process details
- Story 6.9: System usage and the dashboard meters
- Story 6.10: The locks view
- Story 6.11: Databases, with free space arriving as it lands
- Story 6.12: The devices list
- Story 6.13: The alerts.log viewer
- Story 6.14: The messages.log viewer

## Requirements & Constraints

These apply to every story, and the story specs do not repeat them:

- **One hand-written descriptor per screen** declares route, side-bar position, archetype, the full
  `(resource, permission)` set, entity type and scope, id accessor, context serializer with its
  secret-typed fields, row actions, empty-state text, command-box aliases, and the classic page it
  replaces (a normalized class name, or explicitly none).
- **The read tool is derived, never hand-written:** `<area>.<screen>.read`, declared `read`,
  returning the screen's own declared read with the same fields, filter and sort.
- **Every read is bounded:** a max-rows cap (default 1,000, persisted per screen) with truncation
  reported, first page within 2 s at 1,000 rows. The tool's view is narrower: 200 rows plus a
  total-size bound, fields truncated to a declared maximum, secret fields removed.
- **Secrets are write-only end to end.** Wallet secret values, private keys and key material never
  appear in any read, screen, tool or fixture report.
- **Gating.** Gated entries stay listed and focusable and name their resource; a denial names the
  first pair the user lacks; a refusal is never a 500 or an empty state. Security reads on 2026.2
  need `%DB_IRISSYS:READ` and `%Admin_Secure:USE` together. The log endpoints require the resource
  the classic portal's log pages require.
- **An area covers its screens' pairs.** A screen that adds a pair its area lacks appends it to the
  area; coverage is not relaxed. The union currently gates OS management on `%Admin_Manage:USE`, Logs
  on `%Admin_Secure:USE` and Security on `%Admin_Wallet:USE`, and a gated rail item opens no side bar
  (its screens stay reachable by command box and deep link). **DW-1018** puts that aggregate false
  denial to the user at the merge gate (decision pending; the stock `%SecurityAdministrator` role
  lacks the wallet resource). Build on the union as it stands.
- **No list links out** to the classic portal; only a `detail` may, under a declared exemption.
- **Untrusted text** (log lines, task descriptions, entity names) reaches the model only as delimited
  tool-result content.

Story traps:

- **No new classic link-out.** Release 1's one `classicLinkExemption` (counted once against SM-C1,
  removed in Epic 12) is the OAuth 2.0 screen's, declared by its five tab descriptors; no later story
  in this epic adds another.
- **6.7:** re-point Task schedule's name cell from the one-task History (its temporary target) to
  Task details, and put the History link on Task details, which targets
  `tasks/schedule/history/<Id>`. Key on the numeric task `Id`, Task schedule's row key since 6.6; until
  6.7 the locator's entity segment on History reads that id, not the task name. The route must carry
  the task's scoped identity with the row selected and the locator naming it (UJ-6). A stale parent id
  whose read answers 404 draws the generic "request refused" with a Retry that cannot clear it
  (accepted for Secrets as DW-1021; a deleted task meets the same path, inference).
- **6.8, settle at spec time:** the story asks for auto-refresh, but Process details is not in the
  roster (Processes, Databases, Database details, Task schedule, Task details, System usage). A
  screen joins only by declaring it **and** appearing there, so amend EXPERIENCE.md and AD-43
  together or drop the declaration.
- **6.9:** meter names and thresholds come from the 25 definitions in
  `%CSP.UI.Portal.EnsembleMonitor`; confirm the assumed 80% and 95% there.
- **6.14:** confirm the assumed 28 px log row against a real tail at the densest severity mix.
  **DW-148:** the fault banner's "Open messages.log" link skips `ShellState.showArea`, leaving the
  side bar on the previous area. **DW-278:** the Logs area's accepted union carries
  `%Admin_Secure:USE`; decide only whether this screen declares it. **DW-1025:** a fresh instance logs
  repeated `<PROTECT>%DeleteData` from the audit LIST's async-task cleanup; find whether it originates
  in `AdminPort`'s poll (fix at the port) or the vendor's own cleanup (close with vendor evidence)
  before this viewer shows it.
- **No inert controls.** A row action ships only with its handler: On-demand tasks carries no Run
  (Story 7.5 declares it), as Task schedule carried no Resume before its handler.

## Technical Decisions

- **Descriptor grammar.** `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` refuse each shape
  with the same sentence, pinned in a shared `Test/*Corpus.cls`; a new rule changes all three. The
  archetype vocabulary is closed and already holds every archetype this epic uses (`list`,
  `list (two views)`, `list (server criteria)`, `detail`, `meters`, `log-viewer`).
- **Tables.** A `list` declaring a read declares `table`: columns (label key, kind, optional
  `emptyKey`) and two empty-state keys. `emptyKey` is the word an empty cell reads instead of
  "(none)" where empty means something else; it changes the cell only, never the filter or the tool.
  No column kind is a date, so vendor timestamps render as `text`.
- **Unlisted screens.** `sideBarPosition` 0 is routable but never listed: Task, Process and Database
  details, per-task History, Secrets. The client pairs a list with its surfaces by route suffix
  (`<list>/edit`, `<list>/document`), so a name cell opening a detail screen needs the same kind of
  pairing (inference).
- **Parent-scoped lists.** A sub-resource list declares `parentScope` naming its parent list's route
  and, with a read, exactly one `read.criteria` field, which the client fills from the route id (both
  engines refuse any other count). The parent's name cell links to the built, unlisted, id-keyed
  screen whose `parentScope` is its route, checked after the editor and the document viewer; the
  locator names the parent, and the page clears its store when the parent changes. The route id
  identifies an entity of the **parent screen's primary entity type**, resolved through the parent
  declaration and never declared twice, while the rows keep the screen's own type (Secrets' id is a
  `wallet-collection`, a task's History id is a `task`); both engines refuse an unresolvable parent. A
  parent-scoped list whose only criterion comes from the route is a plain `list` that reads on open.
- **Ids and scope.** Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=`, the id one segment through
  the shared encoder only. References carry `(entity type, scope, id)`, scope `instance` for
  configuration objects. `ns` is data scope: switching re-fetches.
- **Pair sets are established, not copied.** `ResourcesOR()` is a lower bound: read the backing
  query's own privilege check, run the read as a real least-privileged principal on a throwaway, and
  add what is still refused (a stricter backing query goes in `AdminPort`'s `QUERYPAIRS`). An `admin`
  read must declare `%DB_IRISSYS:READ`. An empty pair set admits everyone. Append pairs, since the
  gate names the first unheld one.
- **Tabbed screens.** One `detail` descriptor per tab, grouped by a declared `tab`
  (`{group, position, labelKey}`); each tab has its own primary entity type (secondaries allowed),
  read, tool and pair set. The group's listed member is the side-bar entry, the rest are unlisted
  routes, and the shared `DetailPage` draws the tab strip over `ListPage`. Grouping is declared, never
  hand-routed. A detail's `classicLinkExemption.rowLink` maps row fields to editor params, and a row
  with any blank param renders plain text.
- **One read contract.** Sources are `admin`, `mgmnt` and `state`. An `admin` read may name one
  per-row detail call (`rowGet`) after the cap, with an optional `type`: `GET` (default), `INFO` where
  the list row is wrong (`Task.CRUD` LIST reports every task as not suspended) or `CERTINFO` where only
  that type carries the fields; a type the port issues must be in `AdminPort`'s `TYPESUFFIXES`. A 404
  row is dropped and any other row fault fails the read. For endpoints with no plain LIST: a
  single-object `GET` source (404 reads as zero rows; no `rowGet`, `forEach` or criteria); a
  list-shaped admin type other than `LIST` (`UPCOMING`: admin only, no `rowGet` or `forEach`);
  fixed `source.query` parameters seeded before criteria that no caller can change or remove
  (`onDemand=1`), whose keys may not collide with reserved or declared criteria params or a
  `forEach.param`; list-shaped `HISTORY` the same way; a criterion's `vendorParam`, sending its value
  under the vendor's name where that name is reserved for the read's own arguments (`maxRows` and `ns`
  are reserved; on a `mgmnt` source, avoid a criterion named `namespace`, DW-1028); a `forEach`
  source listing a parent endpoint then the child list per parent, bounded by the row cap on rows held
  and cap+1 on parents listed, reporting truncation (a child 404 is skipped, any other fault fails the
  read); and `<object>.<member>` fields projecting one member of an object field. A secret-bearing
  object is never named whole, only its non-secret members. Server criteria travel on `admin` and `mgmnt`
  only. The cap bounds rows; one screen-only payload from a single named vendor object may sit beside
  them, never in the tool view or context.
- **Read-triggered vendor writes.** AD-7 permits exactly two: the credential password migration and
  the REST discovery cache. Any other needs a spine amendment first.
- **AdminPort** alone names `%Api.Admin.*`, turns non-2xx into a named fault and rewrites vendor
  text. An endpoint outside the audited inventory is re-audited before use.
- **Async free space (6.11).** `Database.SysCRUD` `TYPEINFO` is async per request type. `AdminPort`
  polls with a bounded wait that fails `PORT.TIMEOUT`, never partial; the slice writes no polling.
- **MonitorPort (6.13) does not exist yet.** It checks its pairs with `$System.Security.Check` before
  any call, because `/api/monitor` answers anonymously. Reaching the API's implementation in process,
  as `MgmntPort` does, is the precedent (inference).
- **Log files.** alerts.log joins `LogSourcePort`'s fixed source enum. No endpoint accepts a path; the
  manager directory is resolved per call; a paging offset is checked against the file's identity and
  restarts cleanly after rotation.
- **Client.** A list over a declared read and table needs only its descriptor and the regenerated
  mirror (`ListPage` renders it). Other archetypes get `<screen>.page.ts` and `<screen>.store.ts` in
  the area folder: a framework-free store mirrored into signals, zoneless, OnPush, tokens only. A
  list that needs a control above the shared table (Upcoming's horizon form) registers a small page in
  `DESCRIPTOR_PAGES` over ListPage's binding; a change yielding new criteria clears rows and reads once.
  Auto-refresh is the one shared framework.
- **Tripwires per screen:** `Test/ReadTool`, `Test/Descriptor`, `Test/ScreenRead` (every declared
  field is a key of the live row, issuing the declared detail type; parent-scoped reads are held by
  their area's own test), `Test/Wire` with `navigation.test.mjs`, `screen-mirror.test.mjs` and the two
  client `LIVE_PAYLOAD` copies (neither goes red alone), and `Install/Smoke` (one live read per built
  list, skipping without credentials). A denial test needs a real principal on the throwaway.
- **Browser specs** against a non-default origin need `OCUPILOT_BROWSER_CONTAINER`. Their docker-exec
  legs create principals and refuse only the live `ocupilot` container, not a slot instance
  (DW-1015), so point them only at your own slot's throwaway.

## UX & Interaction Patterns

- **States.** `detail`: skeleton fields, errors keep last values, auto-refresh in place with a field
  highlight. `meters`: skeleton per meter, a failed meter shows "—" with the error in its tooltip.
  `list (two views)`: async figures fill per-row skeleton cells and the table never reflows.
  `list (server criteria)`: criteria form first, skeleton on Search, never auto-refreshes (Refresh
  re-reads the form's current values, not the last submitted search, as the audit page does).
  `log-viewer`: "No entries." / "No matches.", new rows only via "Load newer".
- **Meter.** Label, value and unit with its state as a word and a color at the thresholds; the needle
  never animates. EXPERIENCE.md and 6.9 show "—" until the first value while DESIGN.md shows "…" for
  values still arriving; settle which at spec time.
- **Log viewer.** Rows are time, pid, severity chip, text. Sticky search with highlight and a polite
  "n of N"; jump to top and bottom; "Load newer"; a Raw toggle on the code surface with a line-number
  gutter and no wrapping. A severity chip click sets the filter, shown in the command bar with Clear.
  alerts.log merges the monitoring API's recent entries with the file's bounded tail. Nothing streams.
- **Empty and loading.** An empty state names its scope ("No locks in HSCUSTOM.", "No secrets in this
  collection."). A refused, denied, faulted or filtered-to-zero view is never empty. Only a descriptor
  declaring a primary or row action invites the agent. Skeletons show on first load only.
- **Denied deep link:** the title and "You need <pair> to open <title>." with no table and no read.
- **Side-bar order.** Logs: alerts.log · messages.log · Application errors · Audit database. OS
  management: Processes · Locks · System usage · Databases · Devices. Tasks: Task schedule ·
  On-demand tasks · Upcoming tasks · Task history. Security: SSL/TLS · X.509 · LDAP / Kerberos ·
  Wallet · OAuth 2.0 · Auditing (Epic 7).
- **Strings.** Add each EXPERIENCE.md Fixed strings row with its `strings.ts` key in one pass;
  `strings.test.mjs` demands exact set equality. Rows for On-demand, Upcoming, Task history (all)
  and the one-task History exist, the latter's title "History"; add Task details' row when it is built. Values are unique, so reuse an existing row's
  string rather than repeating it. Aliases come from the contest wording ("x509", "CPU", "disks").

## Cross-Story Dependencies

- **Upstream:** Epic 2 (`AdminPort` sync and async, `LogSourcePort`, the declared read, `ListPage`,
  command bar, refresh framework, gate), 6.1 (`MgmntPort`, the `mgmnt` source, `<list>/document`),
  6.2 (column `emptyKey`), 6.3 (`rowGet.type`, the parent-scoped list grammar and child link) and 6.4 (`tab`, `GET`,
  `forEach`, member fields, `rowLink`, `DetailPage`, registered for the `detail` archetype but
  built for tabbed tables over `ListPage`) 6.5 (`source.query`, `UPCOMING`, the Tasks area's
  criteria page precedent) and 6.6 (`HISTORY`, `vendorParam`, route-id entity type via the parent,
  Task schedule keyed on `Id`).
- **Epic 4 in parallel:** `Screen/Tool/**` is outside this epic's footprint, so a derived-tool change
  routes to a later story (descriptor-declared field descriptions are Story 7.1's, DW-1001 and
  DW-1013). Both epics edit `Registry`, `Read`, `AdminPort`, `Install/Smoke`, `Test/` and the
  client's core, shell and tools; expect reconciliation at merge. Story 4.4's screen context reads the parent-scoped
  route-id entity type 6.6 settled.
- **Within this epic:** 6.10's owner link opens 6.8; 6.7 re-points Task schedule's name cell to itself
  and links to 6.6's per-task History; one meter component serves 6.8, 6.9 and 6.11; one log-viewer serves 6.13 and
  6.14, built by whichever lands first.
- **Downstream:** Epic 7 (on-demand Run in Story 7.5, lock removal, which needs 6.10's transaction flag, process
  actions, OAuth deletes, 7.6's UJ-6 replay on 6.7's route); Epic 8 (resource, X.509, device and
  wallet-secret editors); Epic 9 (role, service, LDAP editors and Edit task; 9.4's diff-row must read
  an empty allowed-address list as "Unrestricted", DW-1016); Epic 11 (explains 6.13 and 6.14 rows);
  Epic 12 (OAuth editors, removing 6.4's exemption).
