# Epic 6 Context: Every screen in the six areas reads live

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 3. Every remaining list, detail and viewer in the six areas reads live instance data, so
no area stops at one screen and the side bar has no dead entries, and each screen's agent read tool
arrives with it from the same descriptor. The epic is read-only: the writes these screens host
arrive in Epics 7, 8, 9, 12 and 16. It depends on Epic 2 alone and runs in parallel with Epic 4.
Stories 6.1 to 6.11 are done; the three that remain are Devices and the two log viewers.

## Stories

- Story 6.1: The REST API explorer and its OpenAPI document viewer (done)
- Story 6.2: The roles, resources and services lists (done)
- Story 6.3: The X.509, LDAP/Kerberos and wallet lists (done)
- Story 6.4: The OAuth 2.0 screen (done)
- Story 6.5: On-demand and upcoming tasks (done)
- Story 6.6: Task history, per task and across tasks (done)
- Story 6.7: Task details (done)
- Story 6.8: Process details (done)
- Story 6.9: System usage and the dashboard meters (done)
- Story 6.10: The locks view (done)
- Story 6.11: Databases, with free space arriving as it lands (done)
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
- **Every read is bounded:** a max-rows cap (default 1,000, persisted per screen with sort and
  filter) with truncation reported, first page within 2 s at 1,000 rows. The tool's view is
  narrower: 200 rows plus a total-size bound, fields truncated to a declared maximum, secret fields
  removed.
- **Secrets are write-only end to end**, and nothing OcuPilot writes to a log may later be shown by
  the log screens it builds.
- **Gating.** Gated entries stay listed and focusable and name their resource; a denial names the
  first pair the user lacks; a refusal is never a 500 or an empty state. Security reads on 2026.2
  need `%DB_IRISSYS:READ` and `%Admin_Secure:USE` together. The log endpoints require the resource
  the classic portal's log pages require, resolved per namespace where the source is a global. The
  per-process variable read needs `%Admin_Manage:USE` outright — stricter than
  `%SYS.ProcessQuery.AllowToOpen`, which also admits IRISSYS write, IRISSYS read or the caller's own
  pid (corrected in the spine; DW-1050 closed).
- **An area covers its screens' pairs.** A screen that adds a pair its area lacks appends it to the
  area; coverage is not relaxed. The union currently gates OS management on `%Admin_Manage:USE`, Logs
  on `%Admin_Secure:USE` and Security on `%Admin_Wallet:USE`, and a gated rail item opens no side bar
  (its screens stay reachable by command box and deep link). **DW-1018** puts that aggregate false
  denial to the user at the merge gate. Build on the union as it stands.
- **No list links out** to the classic portal; only a `detail` may, under a declared exemption.
  Release 1's one exemption is the OAuth 2.0 screen's (counted once against SM-C1, removed in Epic
  12); no remaining story in this epic adds another.
- **No inert controls.** A row action or primary action ships only with its handler — lock removal is
  16.12, the device editor is 8.8, process actions are 7.8.
- **Untrusted text** (log lines, entity names, vendor status words) reaches the model only as
  delimited tool-result content.

Story traps (6.10 to 6.12 as built, 6.13 and 6.14 as planned):

- **6.10 Locks** landed as built: instance-wide scope, a composite row id, the owner cell linking to
  `os-management/processes/details/<pid>` through the cross-screen row target (carrying `Pid`, not the
  row key; a remote owner lands on "This process no longer exists.", DW-1074), and no transaction
  column — that condition is a removal concern 16.12 warns about from the endpoint's own 409.
- **6.11 Databases** shipped (`52c14c8`, CI run 35308816275 green on all six jobs). It built **four
  descriptors**: `DatabaseList` (listed, `sideBarPosition` 4), `DatabaseFreeSpace` (unlisted),
  `DatabaseDetails`, and `DatabaseVolumeList` (parent-scoped) — plus a new **`VOLUMELIST`** list
  source type in `READSOURCETYPES`, `AdminPort`'s `TYPESUFFIXES`, `Read.Execute` and
  `screen-mirror.mjs`, each with a corpus case for its refusal, and a new **`ViewOptions`** registry
  at `ui/src/app/core/view-options.ts`, registered as a value provider in `ui/src/main.ts` (the
  `ScreenActions` precedent) and rendered by the command bar's own View slot. **AD-5** now records
  that a page may issue another built screen's declared read through the ordinary read route, so
  that screen's gate, cap and field set apply unchanged — the Free-space view uses it for its rows
  and Database details for its volume-file section. **Escalations closed against 6.11, not to be
  re-filed:** DW-1080 (the background-tasks section is chartered to the owner) and DW-1090 (a
  `rowGet` read's async bound is per row, so a staged read's wall clock is rows × `ASYNCTIMEOUT`
  with no read-wide deadline).
- **6.12 Devices** is the list only.
- **6.13 alerts.log** shipped as built, and 6.14 declares against it. It reads the file through
  **`LogSourcePort` alone**: the monitoring half was removed at the orchestrator's decision, because
  `/api/monitor` reads the same file lossily and advances the instance-wide SAM cursor on every call
  whatever tag is passed (DW-1116, routed to FR-76's story, which names the sha the `MonitorPort`
  implementation is recoverable at). `LogSourcePort` gained a `Rows` entry point beside `Page`, the
  screen declares a `logsource` read source -- a fourth port value in `Screen/Read.cls`,
  `Screen/Registry.cls` and `screen-mirror.mjs` -- so its read stays declared and its tool derived
  with no `Screen/Tool/` file, and its pair set is `%Admin_Operate:USE` alone. **The shared log
  viewer is 6.13's**: page, store, parser, five severity chips, sticky search with highlight and a
  polite count, jump controls, Load newer, Raw toggle, chip filter. 6.14 adds a descriptor at
  `sideBarPosition` 2 and one `SOURCES` entry, needs no new string and no parser change, and
  re-confirms the 28 px row against messages.log's own severity mix. A fresh instance has **no**
  `alerts.log` at all, and `LOG.ABSENT` reads as zero entries.
- **6.14 messages.log** reads through the bounded paging endpoint Epic 2 built and never loads the
  whole file. No endpoint accepts a path: the manager directory is resolved per call, and a paging
  offset is checked against the file's identity so a rotation restarts cleanly rather than serving a
  stale position. A severity chip click sets the filter, shown in the command bar with Clear. Confirm
  the assumed **28 px log row** against a real tail at the densest severity mix. **DW-148:** the
  fault banner's "Open messages.log" link skips `ShellState.showArea`, leaving the side bar on the
  previous area. **DW-278:** the Logs area's accepted union carries `%Admin_Secure:USE`; decide only
  whether this screen declares it. **DW-1025:** a fresh instance logs repeated `<PROTECT>%DeleteData`
  from the audit LIST's async-task cleanup; find whether it originates in `AdminPort`'s poll (fix at
  the port) or the vendor's own cleanup (close with vendor evidence) before this viewer shows it.
- **Stale parent ids and the generic refusal.** A route whose id answers 404 draws "request refused"
  with a Retry that cannot clear it (accepted for Secrets as DW-1021; Database details and Process
  details meet the same path, inference).
- **Auto-refresh roster is seven:** Processes, Process details, Databases, Database details, Task
  schedule, Task details, System usage — settled by 6.11's two additions (Databases, Database
  details). A screen joins only by declaring it in its descriptor **and** appearing in that roster;
  none of the three remaining stories (6.12–6.14) join it.

## Technical Decisions

- **Descriptor grammar.** `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` refuse each shape
  with the same sentence, pinned in a shared `Test/*Corpus.cls`; a new rule changes all three. The
  archetype vocabulary is closed, classifies each key as `list`, `detail` or `none`, fails closed on
  an unknown key, and already holds every archetype these three stories need (`list`,
  `list (two views)`, `detail`, `log-viewer`).
- **Tables.** A `list` declaring a read declares `table`: columns (label key, kind, optional
  `emptyKey`) and two empty-state keys. `emptyKey` is the word an empty cell reads instead of
  "(none)" where empty means something else; it changes the cell only, never the filter or the tool.
  No column kind is a date, so vendor timestamps render as `text`. A descriptor is write-capable when
  it declares a primary or row action, which is what the empty state's agent invitation keys off.
- **Unlisted screens.** `sideBarPosition` 0 is routable but never listed: Database, Task and Process
  details, per-task History, Secrets, the OpenAPI document viewer. The client pairs a list with its
  surfaces by route suffix (`<list>/edit`, `<list>/document`, `<list>/details/<id>`,
  `<list>/history/<id>`). Task details and Process details are the precedents for an id-keyed detail
  screen with its own page, opened from a list's name cell.
- **Cross-screen row targets.** A list may declare exactly one: another screen's route plus the row
  field holding its id — the field need not be the row's own key — so the shared table links that
  cell through the shared encoder and keeps one cell-rendering path. Validated identically in
  `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`, resolved ahead of the paired-surface chain.
- **Ids and scope.** Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=`, the id one segment through
  the shared encoder only (encode twice, decode once). References carry `(entity type, scope, id)`,
  scope `instance` for configuration objects and the namespace where the object is namespace-scoped.
- **Pair sets are established, not copied.** `ResourcesOR()` is a lower bound: read the backing
  query's own privilege check, run the read as a real least-privileged principal on a throwaway, and
  add what is still refused (a stricter backing query goes in `AdminPort`'s `QUERYPAIRS`). An `admin`
  read must declare `%DB_IRISSYS:READ`. An empty pair set admits everyone. Append pairs, since the
  gate names the first unheld one.
- **One read contract.** Sources are `admin`, `mgmnt` and `state`. An `admin` read may name one
  per-row detail call (`rowGet`) after the cap, with an optional `type`: `GET` (default), `INFO`
  where the list row is wrong, or `CERTINFO`; a type the port issues must be in `AdminPort`'s
  `TYPESUFFIXES`. A 404 row is dropped and any other row fault fails the read. A detail call may
  declare derived fields from a closed rule set computed on the instance (`beforeToday`). For
  endpoints with no plain LIST: a single-object `GET` source (404 reads as zero rows), which may
  declare up to three `parts` (`{type, as}`), each answering one object, merged into its one row as
  `<as>.<member>` fields — the member projection composes, so a nested group reads
  `<as>.<group>.<member>` — and a part's type may be one the endpoint names without the `TYPE` prefix
  (System usage); a list-shaped admin type other than `LIST` (`UPCOMING`, `HISTORY`); fixed
  `source.query` parameters no caller can change or remove, whose keys may not collide with reserved
  or declared criteria params; a criterion's `vendorParam` where the vendor's name is reserved
  (`maxRows` and `ns` are reserved; on a `mgmnt` source avoid a criterion named `namespace`,
  DW-1028); a `forEach` source, bounded by the row cap on rows held and cap+1 on parents listed; and
  `<object>.<member>` fields. A secret-bearing object is never named whole, only its non-secret
  members. Server criteria travel on `admin` and `mgmnt` only. The cap bounds rows; one screen-only
  payload from a single named vendor object may sit beside them, never in the tool view or context.
- **Parent-scoped reads.** A sub-resource list declares `parentScope` naming its parent list's route
  and exactly one `read.criteria` field filled from the route id; the route id identifies an entity
  of the parent screen's primary entity type while the rows keep the screen's own type. A
  parent-scoped single-object `GET` takes the route id as its one criterion, may name one detail call
  keyed by it, and that route-id criterion does not bar auto-refresh, since it reads on open rather
  than from a search form.
- **Read-triggered vendor writes.** AD-7 permits exactly two: the credential password migration and
  the REST discovery cache. Any other needs a spine amendment first.
- **AdminPort** alone names `%Api.Admin.*`, reproduces the vendor dispatcher once (stub `%request`,
  `%response` and `%session`, `IsRunningAsync = 0`, gate before query params, read the outcome from
  both `tSC` and `%response.Status`), turns non-2xx into a named fault and rewrites vendor text at
  the port boundary. An endpoint outside the audited inventory is re-audited before use.
- **Log files.** `LogSourcePort` serves every log source the admin API does not back, from a fixed
  enum, switching to `%SYS` once by explicit save and restore where the API lives there.
- **Client.** A list over a declared read and table needs only its descriptor and the regenerated
  mirror (`ListPage` renders it). Other archetypes get `<screen>.page.ts` and `<screen>.store.ts` in
  the area folder: a framework-free store mirrored into signals, zoneless, OnPush, tokens only, no
  hardcoded colors. A list that needs a control above the shared table registers a small page in
  `DESCRIPTOR_PAGES` over ListPage's binding; a change yielding new criteria clears rows and reads
  once. Auto-refresh is the one shared framework, and the field highlight is the shared
  `ui/src/app/core/detail-highlights.ts` helper — reuse it rather than diffing per page (a changed
  entity id, such as a reused pid, must not mark every field changed).
- **Tripwires per screen:** `Test/ReadTool`, `Test/Descriptor`, `Test/ScreenRead` (every declared
  field is a key of the live row, issuing the declared detail type; a live-entity test asserts real
  values, not null-filled keys), `Test/Wire` with `navigation.test.mjs`, `screen-mirror.test.mjs` and
  the two client `LIVE_PAYLOAD` copies (neither goes red alone), and `Install/Smoke` (one live read
  per built list, skipping without credentials). **Two literal pins break on any added screen and no
  stage re-runs them by itself, and this epic has now been bitten by both twice:**
  `src/OcuPilot/Test/Navigation.cls` pins the os-management roster by literal index **and** count —
  **nine** screens after 6.12 — and went red in CI on 6.9 and again on 6.10, so any story that builds
  an os-management screen updates both; and `Install/Smoke.cls`'s name list, its indexed `$Select` arm
  and its loop bound must change together. In `Test/Smoke.cls` only the arm-count assertion derives
  from them: `TestEachAreaListCheckReadsItsOwnScreen` needed three literal edits of its own in 6.12
  (its roster, its count twice, and `tExpected`), so both methods are read before either is trusted. Run the whole ObjectScript sweep, not a chosen subset, before believing a story is green —
  **and run it on a fresh throwaway:** `node tools/ci-runner.mjs` runs what the throwaway compiled at
  container start, so a sweep after an edit needs a fresh throwaway or an in-container recompile — and
  the throwaway mounts a **copy** of the source at `/tmp/<project>/src`, so an in-container `LoadDir`
  after an edit silently recompiles the old file unless that copy is refreshed first, which is a
  false-green trap for the Rule 19 mutation every story does; the
  lead's standing gate is the whole sweep on a throwaway brought up after the last edit. A denial test
  needs a real principal on the throwaway, never `%Operator`; a denied deep link wants a browser leg,
  not only the payload and the HTTP 403 (DW-1049).
- **Browser specs** against a non-default origin need `OCUPILOT_BROWSER_CONTAINER`, and their
  docker-exec legs refuse only the live `ocupilot` container, not a slot instance (DW-1015) — point
  them only at your own slot's throwaway. A browser spec reads the deployed bundle, so rebuild and
  redeploy before believing one.

## UX & Interaction Patterns

- **States.** `list`: skeleton, then empty-state; an error keeps the data on screen.
  `list (two views)`: per view, plus the Databases free-space view's skeleton cells, which fill
  together when the asynchronous call resolves and cannot reflow the table (its grid tracks come from
  the declared column kinds). `detail`: skeleton fields, errors keep last values,
  auto-refresh in place with a field highlight. `log-viewer`: skeleton rows, then "No entries." /
  "No matches."; new rows only via "Load newer"; nothing streams.
- **Auto-refresh.** Only the seven roster screens carry it: a command-bar chip switches off or a
  rate from a short fixed list (5/10/30/60 s assumed, default off), the status bar stamps the last
  update, and refresh is silent — no spinner, skeleton or announcement, and sort, filter, selection and scroll survive it. The shared
  framework pauses it while a proposal on the screen's entity type is live and says so in the chip.
- **Meter.** One component, on System usage and Database details only: a 6 px rounded
  `surface-container-high` track with a `success` fill, label in caption above, value in code type
  beside it. A percentage meter fills `warning` at 85% and `error` at 95% (the numbers an assumption,
  not the behavior) with the value text in the same color so meaning survives without the bar; a
  status meter takes the dashboard's own word (Normal / Warning / Troubled) as reported. Pending
  shows a skeleton fill and "—"; a failed meter shows "—" with the error in its tooltip. Never
  animates.
- **Log viewer.** Rows are time (code type), pid (code type), severity chip, text (body, wrapping),
  at the 28 px log row height. Sticky search in the command bar with highlight and a polite "n of N",
  next and previous, jump to top and bottom, "Load newer" at the tail, and a Raw toggle onto the code
  surface with a line-number gutter, no wrapping and horizontal scroll inside its own block. The
  severity chip is the column's whole content and the word is always present; clicking it applies
  that severity as the filter, with Clear in the command bar.
- **Empty, loading and refused.** An empty state names its scope ("No locks on this instance." when
  instance-wide, "No REST applications in HSCUSTOM." when namespace-scoped), with a second line saying what to do next and the agent invitation only on a write-capable list. A
  refused, denied, faulted or filtered-to-zero view is never an empty state. Skeletons show on first
  load only. A denied deep link renders the title and "You need <pair> to open <title>." with no
  table and no read.
- **Side-bar order.** OS management: Processes · Locks · System usage · Databases · Devices. Logs:
  alerts.log · messages.log · Application errors · Audit database. A screen that is not yet built
  does not appear.
- **Strings.** Add each EXPERIENCE.md Fixed strings row with its `strings.ts` key in one pass;
  `strings.test.mjs` demands exact set equality, and values are unique, so reuse an existing row's
  string rather than repeating it. The test's literal bound is **520**, raised by Story 6.11 with a
  comment noting it covers 6.12 through 6.14; the Fixed strings table stands at about 451 literals
  after Story 6.12's row landed at `EXPERIENCE.md:366`.
- **Color never alone:** severity, meter state and changed rows each carry a word or tag.

## Cross-Story Dependencies

- **Upstream:** Epic 2 (`AdminPort` sync and async, `LogSourcePort`, the declared read, `ListPage`,
  the command bar and its View and filter controls, the refresh framework, the gate), 6.1
  (`MgmntPort`, the `mgmnt` source, `<list>/document`), 6.2 (column `emptyKey`), 6.3 (`rowGet.type`,
  the parent-scoped list grammar and child link), 6.4 (`tab`, single-object `GET`, `forEach`, member
  fields, `rowLink`, `DetailPage`), 6.5 (`source.query`, `UPCOMING`, the criteria-page precedent),
  6.6 (`HISTORY`, `vendorParam`, route-id entity type through the parent), 6.7 (parent-scoped
  single-object `GET` with a keyed detail call and auto-refresh, the name-cell-to-detail link), 6.8
  (Process details' own page with silent auto-refresh, the shared `detail-highlights` helper, the
  process pair set 6.10's owner link lands on) and 6.9 (the `parts` source shape, the meter component
  and its thresholds, the dashboard's own status words).
- **Epic 4 in parallel:** `Screen/Tool/**` is outside this epic's footprint, so a derived-tool change
  routes to a later story (descriptor-declared field descriptions are Story 7.1's, DW-1001 and
  DW-1013). Both epics edit `Registry`, `Read`, `AdminPort`, `Install/Smoke`, `Test/` and the
  client's core, shell and tools; expect reconciliation at merge.
- **Within this epic:** 6.11's Database details reuses 6.9's meter component and its free-space view
  reuses 6.3's `rowGet.type`; one log-viewer serves 6.13 and 6.14, built by whichever lands first, and
  6.13 builds the shared log viewer 6.14 declares against, and ships no `MonitorPort`. `Kernel/EntityType.cls` already carries both
  `device` and `lock`, so no remaining story needs that contended file.
- **Downstream:** Epic 7 (process actions in 7.8, on-demand Run in 7.5, 7.6's UJ-6 replay on 6.7's
  route); Epic 8 (the device editor in 8.8, plus the resource, X.509 and wallet-secret editors);
  Epic 9 (role editor and Edit task); Epic 11 (11.2 explains a 6.13 or 6.14 row); Epic 12 (OAuth
  editors, removing 6.4's exemption); Epic 16's polish week (16.11 Task Manager control, 16.12 lock
  removal — which warns from the endpoint's own 409 and is action-style with no body template, 16.13 the
  service editor whose diff-row must read an empty allowed-address list as "Unrestricted", DW-1016,
  and 16.14 the LDAP and Kerberos editor).
