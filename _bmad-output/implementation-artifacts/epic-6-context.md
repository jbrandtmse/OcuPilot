# Epic 6 Context: Every screen in the six areas reads live

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 3. Every remaining list, detail and viewer in the six areas reads live instance data, so
no area stops at one screen and the side bar has no dead entries. Each screen's agent read tool
arrives with it, derived from the same descriptor. The epic covers the REST API explorer and its
OpenAPI viewer, the rest of Permissions and Security (roles, resources, services, X.509,
LDAP/Kerberos, wallet, OAuth 2.0), the remaining task screens, OS management's details, meters,
locks, databases and devices, and the alerts.log and messages.log viewers. It is read-only: the
writes these screens host arrive in Epics 7, 8, 9 and 12. It depends on Epic 2 alone and runs in
parallel with Epic 4.

## Stories

- Story 6.1: The REST API explorer and its OpenAPI document viewer (done)
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

- **One hand-written descriptor per screen.** It declares route, side-bar position, archetype, the
  full `(resource, permission)` set, entity type and scope, id accessor, context serializer with
  its secret-typed fields, row actions with self-protection rules, empty-state text, command-box
  aliases and the classic page it replaces.
- **The read tool is derived, never hand-written.** It is named `<area>.<screen>.read`, declares
  `read`, and returns the screen's own declared read with the same fields, filter and sort.
- **Every read is bounded.** A max-rows cap (default 1,000, persisted per screen) with truncation
  reported on screen, and a first page within 2 s at 1,000 rows. The tool's view is narrower: the
  context cap (200 rows plus a total-size bound, each field truncated to a declared maximum), with
  secret fields removed.
- **Secrets are write-only end to end.** Wallet secret values, private keys and key material never
  appear in any read, on screen or in a tool.
- **Gating.** Gated entries stay listed and focusable and name their resource; a denial names the
  first pair the user lacks; a refusal is never a 500 and never an empty state. The security reads
  on 2026.2 need `%DB_IRISSYS:READ` and `%Admin_Secure:USE` together. The log viewers require the
  resource the classic portal's log pages require.
- **No list links out** to the classic portal.

Story traps:

- **6.3:** the Wallet screen is gated as a whole on the wallet administrative resource, which no
  planning document names; establish it like any pair set. Two ledger items must be done or
  declined with a reason: **DW-49**, mark the checked-in demo X.509 pair as a disposable fixture in
  `Install/Fixture.cls`'s header and beside the literal (the owner keeps the pair); **DW-233**,
  generate the pair at install through `%SYS.X509Credentials.LoadCertificate`, which also fills
  subject, issuer, validity and thumbprint. The open question is AD-21's no-caller-path rule,
  because that call reads a file path; the checked-in pair is the accepted fallback.
- **6.4:** archetype `detail`, not `list`, with five tabs: client server descriptions, client
  configurations, resource servers, a read-only authorization server view (issuer, scopes, grant
  types, keys), and server client descriptions. It declares several entity types: the primary one
  drives the route and change-event key, the secondary ones take part in change-event routing.
  Name cells open the classic editor in a new tab under a declared `classicLinkExemption` with its
  reason. That is Release 1's only exemption; it counts against SM-C1 and Epic 12 removes it.
- **6.6:** task history searches on the server: criteria form first, skeleton only after Search,
  never auto-refreshes.
- **6.7:** the route carries the task's scoped identity, the row is selected and the locator bar
  names it. The UJ-6 replay is Story 7.6's, and the pause under a live proposal is Story 5.7's.
- **6.8, conflict to settle at spec time:** the story asks for auto-refresh, but Process details is
  not in the auto-refresh roster (Processes, Databases, Database details, Task schedule, Task
  details, System usage). A screen joins only by declaring it **and** appearing in that roster, so
  either amend EXPERIENCE.md and AD-43 together or drop the declaration.
- **6.9:** meter names and thresholds come from the 25 definitions in
  `%CSP.UI.Portal.EnsembleMonitor`, never from the classic page. The 80% and 95% thresholds are
  assumptions to confirm there.
- **6.14:** confirm the assumed 28 px log row against a real tail with the densest severity mix.
  **DW-148:** the fault banner's "Open messages.log" link navigates without `ShellState.showArea`,
  leaving the side bar on the previous area. **DW-278:** the Logs area's pair set carries
  `%Admin_Secure:USE`, which this screen does not need. The area-level false denial was accepted,
  because relaxing area coverage would create a false admission and a ninth area breaks the fixed
  area vocabulary. The story decides whether the screen declares the pair.

## Technical Decisions

- **Descriptor grammar.** `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` hold every rule as
  the same refusal sentence; a new rule changes both and is pinned in a shared `Test/*Corpus.cls`
  that `screen-mirror.test.mjs` reads. `secondaryEntityTypes`, `parentScope` and
  `classicLinkExemption` are already accepted keys. The archetype vocabulary is closed and fails
  closed; this epic uses `list`, `list (two views)`, `list (server criteria)`, `detail`, `meters`
  and `log-viewer`, and only `detail` may declare an exemption.
- **Unlisted and sub-resource screens.** A screen reached only from its own list declares
  `sideBarPosition` 0 (routable, never listed): Task details, Process details, Database details,
  per-task history and a wallet collection's secrets. A sub-resource screen declares its parent:
  per-task history, and a collection's secrets. The client pairs a list with its surface by route
  suffix (`<list>/edit`, `<list>/document`; built, unlisted and id-keyed), so a name cell that opens
  a detail screen needs the same kind of pairing (inference).
- **Ids and scope.** Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=`. The id is one segment
  through the shared encoder only (encode twice, decode once), and a composite key names its parts.
  Every reference carries `(entity type, scope, id)`, with scope `instance` for configuration
  objects and entity types from the kernel's closed enum. `ns` is data scope: switching re-fetches.
  The classic page is declared as a normalized class name, or explicitly as none.
- **Pair sets are established, not copied.** `ResourcesOR()` is only a lower bound: read the backing
  query or class's own privilege check, then run the read as a real least-privileged principal on a
  throwaway and add what is still refused. An `admin`-source read must declare `%DB_IRISSYS:READ`
  (the registry refuses it otherwise). An empty pair set is held by everyone, so refuse an
  unresolvable requirement explicitly. Append pairs, because the gate names the first unheld one. An
  area must cover its screens' pairs.
- **One read contract.** Source kinds are `admin`, `state` and `mgmnt`. A read may name one per-row
  detail call (`rowGet`) after the cap, using `INFO` where the list is wrong (`Task.CRUD` LIST
  reports every task as not suspended). A row whose detail call answers 404 is dropped, and any
  other row fault fails the whole read. The cap bounds rows. One screen-only payload derived from a
  single named vendor object may sit beside them, but never in the tool's view or screen context.
- **Read-triggered vendor writes.** AD-7's exception covers exactly two shapes: the credential
  password migration, and the REST discovery cache that 6.1's explorer read rebuilds. A read that
  triggers any other vendor write needs a spine amendment first.
- **AdminPort** is the only code naming `%Api.Admin.*`. It turns non-2xx into a named fault and
  rewrites vendor text at the boundary. An endpoint outside the audited inventory is re-audited
  before use.
- **Async free space (6.11).** `Database.SysCRUD` `TYPEINFO` is async through `ShouldRunAsync()`,
  decided per request type, never per class. `AdminPort` polls `AsyncResult` with a bounded wait
  that fails `PORT.TIMEOUT`, never partial, and the slice writes no polling logic.
- **MonitorPort (6.13) does not exist yet.** It checks its descriptor's pairs with
  `$System.Security.Check` before any call, because `/api/monitor` answers anonymously and OcuPilot
  must not inherit that. AD-1's HTTP ban names `/api/admin`, `/api/mgmnt` and `/api/ocupilot`, not
  `/api/monitor`; 6.1's `MgmntPort` reaching its API's implementation class in process is the
  precedent to follow (inference).
- **Log files.** alerts.log joins `LogSourcePort`'s fixed source enum beside messages.log. No
  endpoint accepts a path. The manager directory is resolved per call, never cached, and pairs are
  checked before any read. Rotation invalidates a paging offset, so the offset is checked against
  the file's identity and restarts cleanly.
- **Task schedule fields** come from `%SYS.TaskSuper`'s documented properties. `TimePeriod` 0–5
  (daily, weekly, monthly, monthly-special, run-after, on-demand) fixes how `TimePeriodEvery` and
  `TimePeriodDay` read. `DailyFrequency`, `DailyFrequencyTime`, `DailyIncrement`, `DailyStartTime`
  and `DailyEndTime` are meaningful only together.
- **Untrusted text.** Log lines, task descriptions, entity names and comments reach the model only
  as delimited tool-result content.
- **Client.** A list over a declared read and table needs only its descriptor and the regenerated
  mirror; `ListPage` renders it. Any other archetype gets a bespoke `<screen>.page.ts` and
  `<screen>.store.ts` in its area folder. The store is framework-free (subscribe/notify) and
  components mirror it into signals; zoneless, OnPush, design tokens only. Auto-refresh is the one
  shared framework, re-fetching through the screen's own read.
- **Tripwires to edit with every screen:** `Test/ReadTool` (production tool list), `Test/Descriptor`
  (area pair sets), `navigation.test.mjs` (built routes in rail order), `screen-mirror.test.mjs`
  (descriptor rosters), the two `LIVE_PAYLOAD` copies (neither goes red alone), and `Install/Smoke`
  (one live read per built list, which must skip, never pass, without credentials). A denial test
  needs a real principal on the throwaway (`scripts/ci-throwaway.sh`). A class that creates
  principals checks its arming variable in `OnBeforeAllTests`.

## UX & Interaction Patterns

- **States by archetype.**
  - **detail:** skeleton fields; an error keeps the last values; a 403 message; auto-refresh in
    place with a field highlight.
  - **meters:** a skeleton per meter; a failed meter shows "—" with the error in its tooltip;
    interval refresh.
  - **list (two views):** states per view. Async figures fill per-row skeleton cells, and the table
    never reflows.
  - **list (server criteria):** criteria form first, skeleton on Search, manual Search only.
  - **log-viewer:** skeleton rows; "No entries." / "No matches."; new rows only via "Load newer".
- **Meter.** Label, value in `code` and unit, with its state (normal / warning / alert) as a word
  and a color. Fill and value text turn warning or error at the thresholds, and the needle never
  animates. EXPERIENCE.md and 6.9 show "—" with a skeleton until the first value, while DESIGN.md
  shows "…" for values still arriving; settle which at spec time.
- **Log viewer.** Rows are time, pid, severity chip, text. A sticky search highlights matches with
  a polite "n of N" and next/previous. Jump to top and bottom; "Load newer" at the tail. The Raw
  toggle is a bounded monospace view on the code surface with a line-number gutter, no wrapping and
  horizontal scroll inside the block. Severity chips are sentence case with the level word; a click
  sets that filter, and the command bar shows it with Clear. Nothing streams.
- **Wallet without its resource.** The side-bar entry names the resource. A deep link shows the
  title and a permission-denied message naming it, with no table.
- **Empty and loading.** An empty state names its scope ("No locks in HSCUSTOM."). A refused,
  denied, faulted or filtered-to-zero view is never empty, and only write-capable screens invite the
  agent. Skeletons appear on first load only; refresh is silent. The auto-refresh chip offers 5,
  10, 30 or 60 s, off by default.
- **New tabs:** only the classic-link card and the OAuth classic-editor links open one.
- **Side-bar order.** Logs: alerts.log · messages.log · Application errors · Audit database. OS
  management: Processes · Locks · System usage · Databases · Devices. Tasks: Task schedule ·
  On-demand tasks · Upcoming tasks · Task history. Permissions: Users · Roles · Resources ·
  Services. Security: SSL/TLS · X.509 · LDAP / Kerberos · Wallet · OAuth 2.0 · Auditing (Epic 7).
- **Command-box aliases** come from the contest wording ("x509", "certificates", "CPU", "disks").
- **Strings.** Add the EXPERIENCE.md Fixed strings row in the same pass as its `strings.ts` key,
  because `strings.test.mjs` demands exact set equality. Values are unique; non-ASCII is `\uXXXX`.
- **Tables and gated controls.** Every table is an APG grid with one Tab stop and an active
  descendant. Gated controls use `aria-disabled`, never `disabled`.

## Cross-Story Dependencies

- **Upstream is Epic 2** (`AdminPort` sync and async, `LogSourcePort` and the messages.log paging
  endpoint, the grammar and declared read, data table, `ListPage`, command bar, refresh framework,
  gate, error envelope) **plus 6.1**, which added `MgmntPort`, the `mgmnt` source kind and the
  `<list>/document` pairing.
- **Epic 4 runs in parallel** and builds read-tool dispatch. Both epics edit the tool and descriptor
  rosters and `Screen/Tool/`, so expect reconciliation at merge.
- **Within this epic.**
  - 6.10's owner link opens 6.8's route.
  - 6.7 links to 6.6's per-task history.
  - One meter component serves 6.9, 6.8 and 6.11's Database details.
  - One log-viewer component serves 6.13 and 6.14; whichever lands first builds it.
  - 6.3's secrets list is a sub-resource of the wallet collections.
- **Downstream.**
  - **Epic 7:** on-demand Run, lock removal with the transaction warning (needs 6.10 to show the
    transaction on the row), process actions, the OAuth deletes, and 7.6's UJ-6 replay against
    6.7's route.
  - **Epic 8:** the resource, X.509, device and wallet-secret editors.
  - **Epic 9:** the role, service and LDAP editors, and Edit task.
  - **Epic 12:** the OAuth editors, which remove 6.4's exemption.
