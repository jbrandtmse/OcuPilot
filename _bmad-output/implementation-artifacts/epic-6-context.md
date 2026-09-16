# Epic 6 Context: Every screen in the six areas reads live

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is build step 3. Every remaining list, detail and viewer in the six areas reads live instance
data, so no area stops at one screen and the side bar has no dead entries. The agent gets a read
tool for each screen at the same moment, derived from that screen's descriptor. The epic covers the
REST API explorer and its OpenAPI viewer, the rest of Permissions and Security (roles, resources,
services, X.509, LDAP/Kerberos, wallet, OAuth 2.0), the remaining task screens, OS management's
details, meters, locks, databases and devices, and the alerts.log and messages.log viewers. The
whole epic is read-only: the writes these screens host arrive in Epics 7, 8, 9 and 12. It depends on
Epic 2 alone and runs in parallel with Epic 4.

## Stories

- Story 6.1: The REST API explorer and its OpenAPI document viewer
- Story 6.2: The roles, resources and services lists
- Story 6.3: The X.509, LDAP/Kerberos and wallet lists
- Story 6.4: The OAuth 2.0 screen
- Story 6.5: On-demand and upcoming tasks
- Story 6.6: Task history, per task and across tasks
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

- **One descriptor per screen, written by hand.** It declares the route, side-bar position,
  archetype, full `(resource, permission)` set, entity-type key and scope, id accessor, context
  serializer with its secret-typed fields, row actions with self-protection rules, empty-state
  text, command-box aliases and the classic page it replaces.
- **The read tool is derived, never hand-written.** It is named `<area>.<screen>.read`, declares
  `read` when it is defined, and uses the screen's own declared read, with the same fields, filter
  and sort.
- **Every read is bounded.** It is capped by max rows (default 1,000, persisted per screen) and
  reports truncation on screen. The first page renders within 2 s at 1,000 rows. The tool sees the
  screen's view narrowed by the context cap (200 rows plus a total-size bound, each field truncated
  to a declared maximum), with secret fields removed.
- **Secret values never appear in any read.** Wallet secret values, private keys and key material
  are write-only end to end, on screen and in the tool.
- **Gating and refusals.** Gated entries stay listed and focusable and name their resource. A denial
  names the first pair the user lacks. A refusal is never a 500 and never an empty state.
- **No list links out** to the classic portal, and a screen that is not built yet has no side-bar
  entry.

Traps in individual stories:

- **6.1:** a service whose document the management API refuses shows the refusal and the reason it
  gave, never an empty view.
- **6.3:** the Wallet screen is gated as a whole on the wallet administrative resource. The planning
  documents never name that resource, so establish it the way every pair set is established (see
  Technical Decisions). Two deferred-work items are routed here, and each must be done or declined
  with a reason:
  - **DW-49:** mark the checked-in demo X.509 pair as a disposable demo fixture, both in the
    `Install/Fixture.cls` header and beside the literal. The owner is keeping the pair.
  - **DW-233:** generate the demo pair at install through `%SYS.X509Credentials.LoadCertificate`,
    which also fills the subject, issuer, validity and thumbprint metadata that is empty today. The
    open question is the no-caller-path rule (AD-21), because that call reads a filesystem path. The
    checked-in pair is the accepted fallback.
- **6.4:** the screen's archetype is `detail`, not `list`. Its five tabs are client server
  descriptions, client configurations, resource servers, a read-only authorization server view
  (issuer, scopes, grant types, keys) and server client descriptions.
  - It declares more than one entity type. The primary type drives the route and the change-event
    key; the secondary types are declared and take part in change-event routing.
  - Each entry's name cell opens the classic editor in a new tab under a declared
    `classicLinkExemption` with its reason. This is Release 1's only exemption: it counts against
    SM-C1, and Epic 12 removes it.
- **6.6:** task history searches on the server. It shows the criteria form first and a skeleton only
  after Search, and it never auto-refreshes.
- **6.7:** the route carries the task's scoped identity, the row is selected, and the locator bar
  names the task. The agent-driven UJ-6 replay has moved to Story 7.6, and the pause while a
  proposal is open is Story 5.7's work. This story builds neither.
- **6.8, conflict to settle at spec time:** the story asks for auto-refresh, but Process details is
  not in the six-screen auto-refresh roster (Processes, Databases, Database details, Task schedule,
  Task details, System usage). A screen joins auto-refresh only by declaring it and appearing in
  that roster. Either amend the roster in EXPERIENCE.md and AD-43 together, or drop the
  declaration.
- **6.9:** meter names and thresholds come from the 25 meter definitions in
  `%CSP.UI.Portal.EnsembleMonitor`, never from the classic page. The 80% and 95% thresholds are
  assumptions to confirm against those definitions.
- **6.14:** confirm the assumed 28 px log row against a real tail with the densest severity mix. Two
  deferred-work items are routed here:
  - **DW-148:** the fault banner's "Open messages.log" link navigates without
    `ShellState.showArea`, so the side bar stays on the previous area.
  - **DW-278:** the Logs area's pair set includes `%Admin_Secure:USE`, which this screen does not
    need. Relaxing area coverage and adding an area were both declined, so that false denial is
    accepted. The story records whether the screen itself declares the pair.

## Technical Decisions

- **Descriptor grammar.**
  - **Two engines.** `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` hold every rule as the
    same refusal sentence. A new rule changes both engines and is pinned in a shared
    `Test/*Corpus.cls`, which `screen-mirror.test.mjs` reads.
  - **Keys already in place.** The declaration already accepts `secondaryEntityTypes`,
    `parentScope` and `classicLinkExemption`.
  - **Archetypes.** The vocabulary is closed and refuses any unknown key. This epic uses `list`,
    `list (two views)`, `list (server criteria)`, `detail`, `meters`, `viewer (OpenAPI)` and
    `log-viewer`, and only `detail` may declare an exemption.
- **Sub-resource and unlisted screens.** A sub-resource screen declares its parent: per-task history,
  and the secrets of one wallet collection. A screen reached only from its own list declares
  `sideBarPosition` 0, which makes it routable but never listed. That covers Task details, Process
  details, Database details, the OpenAPI viewer, per-task history and a collection's secrets.
- **Ids and scope.**
  - **Route.** Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=`. The id is one path segment,
    encoded by the shared encoder only (encode twice, decode once). A composite key names its parts
    and uses the same encoder.
  - **Scoped identity.** Every reference carries `(entity type, scope, id)`, where scope is
    `instance` for configuration objects. Entity types come from the kernel's closed enum, and the
    build fails on an unknown value.
  - **Namespace.** The route's `ns` is data scope, so switching namespace re-fetches the screen.
  - **Classic page.** The classic page a screen replaces is declared as the page's normalized class
    name, never a URL. A screen with no classic equivalent says so explicitly.
- **Pair sets are established, not copied from the endpoint.**
  - **Lower bound only.** An endpoint's `ResourcesOR()` is only a lower bound. First read the backing
    query or class's own privilege check. Then run the read as a real least-privileged principal on
    a throwaway container, and add whatever the instance still refuses.
  - **Declaration rules.** Every admin-port read also declares `%DB_IRISSYS:READ`. An empty pair
    set is held by everyone, so a requirement that cannot be resolved is refused explicitly. Add
    pairs at the end, because the gate names the first unheld pair.
  - **Area coverage.** An area must cover its screens' pairs. OS management already declares the
    union, including `%Admin_Manage:USE`, and a screen that declares a pair outside its area's set
    is refused.
- **AdminPort.**
  - **Only caller.** It is the only code that names `%Api.Admin.*`. It turns any non-2xx answer into
    a named fault and rewrites vendor error text at the boundary.
  - **Unaudited endpoints.** An endpoint outside the audited inventory is re-audited before use, and
    the inventory fixture fails the build when the instance moves.
  - **Per-row detail calls.** `rowGet` makes one declared detail call for each row left after the
    cap. Use `INFO` where the `LIST` is wrong: `Task.CRUD` `LIST` reports every task as not
    suspended, while its `INFO` answers correctly. A row whose detail call returns 404 is dropped;
    any other fault on a row fails the whole read.
- **Async free space (6.11).** Free space comes from `Database.SysCRUD` `TYPEINFO`, which runs
  asynchronously through `ShouldRunAsync()`. Whether a call is async is decided per request type,
  never per class. `AdminPort` polls through `AsyncResult` with a bounded wait that fails with
  `PORT.TIMEOUT` rather than returning partial results, and the slice writes no polling logic.
- **Two new ports.** `MgmntPort` (6.1) and `MonitorPort` (6.13) do not exist yet.
  - **Own gate.** Neither inherits a vendor gate, so each checks its descriptor's pairs with
    `$System.Security.Check` before any call. The monitoring API answers anonymously, and OcuPilot
    must not inherit that.
  - **No HTTP hop to `/api/mgmnt`.** Tools may not call `/api/mgmnt` over HTTP, so `MgmntPort`
    reaches the management API in process (inference).
  - **Generated documents.** Hand-coded `%CSP.REST` services have no stored spec and do not appear
    in the v2 listing. The v1 `spec/<web app path>` form is the route to their generated document,
    but it has been probed only for `/api/admin`, so verify it for others.
  - **The refused service.** `%Api.InteropEditors` v1 to v7 are listed with a `swaggerSpec` URL
    but answer `ERROR #8753`. This is the vendor service the refusal state exists for (inference).
- **Log files.** The alerts.log tail joins `LogSourcePort`'s fixed source list beside messages.log.
  No endpoint accepts a path. The manager directory is looked up on every call and never cached,
  and the port checks its pairs before reading anything. A rotated file invalidates the paging
  offset, so the endpoint checks the offset against the file's identity and restarts cleanly.
- **Task schedule fields.** The schedule is read from the documented properties on
  `%SYS.TaskSuper`. `TimePeriod` 0–5 (daily, weekly, monthly, monthly-special, run-after, on-demand)
  decides how `TimePeriodEvery` and `TimePeriodDay` are read. `DailyFrequency`,
  `DailyFrequencyTime`, `DailyIncrement`, `DailyStartTime` and `DailyEndTime` only make sense read
  together.
- **Untrusted text.** Log lines, task descriptions, entity names and comments reach the model only
  as delimited tool-result content, never in the system prompt.
- **Client.**
  - **List screens.** A list over a declared read and table needs only its descriptor and the
    generated mirror, and the shared `ListPage` renders it.
  - **Other archetypes.** Each gets `<screen>.page.ts` and `<screen>.store.ts`. Stores live in
    `core/`, import no Angular, and are mirrored into signals. Components are zoneless and OnPush,
    and styles use design tokens only.
  - **Auto-refresh.** It is one shared framework that re-fetches through the screen's own read.
- **Rosters to edit with every screen.** Each new screen changes several pinned rosters:
  - the production read-tool list (`Test/ReadTool`)
  - the area pair sets (`Test/Descriptor`)
  - built routes in rail order (`navigation.test.mjs`)
  - the descriptor rosters (`screen-mirror.test.mjs`)
  - `Install/Smoke`'s one live read per built list, which must skip, never pass, when it has no
    credentials

  A denial test needs a real principal on the throwaway (`scripts/ci-throwaway.sh`). A test class
  that creates principals must check an arming variable in `OnBeforeAllTests`.

## UX & Interaction Patterns

- **States by archetype.**
  - **detail:** skeleton fields on first load; an error keeps the last values; a 403 message;
    refresh in place with a field highlight.
  - **meters:** a skeleton per meter; a failed meter shows "—" with its error; refresh on an
    interval.
  - **list (two views):** states per view. Async figures fill per-row skeleton cells as they arrive,
    and the table never reflows.
  - **list (server criteria):** the criteria form first, a skeleton on Search, and manual Search
    only.
  - **viewer (OpenAPI):** a skeleton, then the refused-document state, which stands in for both
    empty and permission-denied. Refresh is manual.
  - **log-viewer:** skeleton rows; "No entries." or "No matches."; new rows only through "Load
    newer".
- **OpenAPI viewer.** Paths appear in document order, each a disclosure that opens to its verbs with
  parameters and response codes. Verb chips carry no color, because teal is reserved for actions. A
  Raw toggle shows the document on the code surface, scrolling inside its own block.
- **Meter.** A meter shows its label, its value in `code` and its unit, with its state as a word as
  well as a color. The fill and the value text turn warning or error at the thresholds. A meter shows
  "—" with a skeleton until its first value arrives, and the needle never animates.
- **Log viewer.**
  - **Rows.** Each row is time, pid, severity chip and text.
  - **Search.** A sticky search field highlights matches and gives a polite "n of N" with
    next/previous. There are also jump to top, jump to bottom, and "Load newer" at the tail.
  - **Raw view.** The Raw toggle switches to a bounded monospace view with a line-number gutter, no
    wrapping, and horizontal scroll inside the block. Nothing streams.
  - **Severity chips.** Chips are sentence case and always include the level word. Clicking one sets
    it as the filter, and the command bar shows that filter with Clear.
- **Wallet without its resource.** The side-bar entry names the resource. A deep link shows the
  screen title and a permission-denied message naming the resource, with no table.
- **Empty states and loading.** An empty state names its scope ("No locks in HSCUSTOM."). A refused,
  denied, faulted or filtered-to-zero view is never shown as empty, and only write-capable screens
  invite the agent. The skeleton appears on first load only. Refresh is silent, and the auto-refresh
  chip offers 5, 10, 30 or 60 s, off by default.
- **New tabs.** Only the classic-link card and the OAuth classic-editor links open a new tab.
- **Side-bar order.**
  - **Logs:** alerts.log · messages.log · Application errors · Audit database
  - **OS management:** Processes · Locks · System usage · Databases · Devices
  - **Tasks:** Task schedule · On-demand tasks · Upcoming tasks · Task history
  - **Permissions:** Users · Roles · Resources · Services
  - **Web applications:** Web applications · REST API explorer
  - **Security:** SSL/TLS · X.509 · LDAP / Kerberos · Wallet · OAuth 2.0 · Auditing (Epic 7)
- **Command-box aliases** come from the contest wording, for example "REST", "x509",
  "certificates", "CPU" and "disks".
- **Strings.** Add the EXPERIENCE.md Fixed strings row before its `strings.ts` key, because
  `strings.test.mjs` requires the two sets to match exactly. Values must be unique, and non-ASCII
  characters are written as `\uXXXX`.
- **Tables and gated controls.** Every table uses the APG grid pattern: one Tab stop with an active
  descendant. Gated controls use `aria-disabled`, never `disabled`.

## Cross-Story Dependencies

- **Upstream is Epic 2 only.** Its reusable pieces are:
  - `AdminPort`, both sync and async
  - `LogSourcePort` and the messages.log paging endpoint
  - the descriptor grammar and the declared read
  - the data table, `ListPage` and the command bar
  - the refresh framework, the gate and the error envelope
- **Epic 4 runs in parallel.** It builds read-tool dispatch. Both epics edit the same tool and
  descriptor rosters, so expect to reconcile them at merge (inference).
- **Within this epic.**
  - 6.10's owner link opens 6.8's route.
  - 6.7 links to 6.6's per-task history.
  - One meter component serves 6.9, 6.8 and 6.11's Database details.
  - One log-viewer component serves 6.13 and 6.14, and whichever story lands first builds it.
  - 6.3's secrets list is a sub-resource of the wallet collections.
- **Downstream, waiting on this epic.**
  - **Epic 7:** on-demand Run, lock removal with the transaction warning (which relies on 6.10
    showing the transaction on the row), process actions, the OAuth deletes, and Story 7.6's UJ-6
    replay against 6.7's route.
  - **Epic 8:** the resource, X.509, device and wallet-secret editors.
  - **Epic 9:** the role, service and LDAP editors, and Edit task.
  - **Epic 12:** the OAuth editors, which remove 6.4's exemption.
