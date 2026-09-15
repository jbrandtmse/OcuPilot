# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real instance data: Web applications, Users, SSL/TLS, Task schedule,
Processes, and in Logs the audit viewer, a bounded messages.log endpoint and the application error
drill-down. Every screen is backed by one descriptor-declared read that the agent's read tool
shares, and every admin-API call goes through one port. Eleven of the twelve stories are done; what
remains is the application error log — the epic's only read that is neither an `AdminPort` call nor
a file, and the only one whose privilege cannot come from a static descriptor.

## Stories

- Stories 2.0–2.9 (done): Epic 1 cleanup; `AdminPort`; write-tool field lists; the
  descriptor-declared read; the data table; the five system lists
- Stories 2.10 and 2.11 (done): the audit database viewer with its agent-marker filter; the
  messages.log paging endpoint
- Story 2.12: The application error log endpoint and drill-down

## Requirements & Constraints

- **Bounds.** First page within 2 s at 1,000 rows, measured end to end against the instance. Every
  read is capped (default 1,000, editable, persisted per screen; no ceiling, no page-size control)
  and reports truncation.
- **One read, two consumers.** The tool's view is the screen's, narrowed by the context cap and
  stripped of secret fields; read tools are not dispatchable until Epic 4.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked per call,
  never cached; a denial names the failing pair. A descriptor names the classic page it replaces, so
  an operator's custom resource on that page still applies.
- **Reads only, by construction.** `AdminPort.TYPESUFFIXES = "GET,LIST,INFO"` keeps every vendor
  write type unreachable, and no Epic 2 screen declares `rowActions` or a `primaryAction` — the
  deletes and other writes belong to Epics 5, 7 and 16.
- **Navigation.** No screen links out to the classic portal; an unbuilt screen has no side-bar
  entry. Ids use the one-segment encoder — a name-keyed entity is a `single` id, a multi-column key
  a `composite` one.
- **The error log.** It reads only through `SYS.ApplicationError`'s own queries (`NamespaceList`,
  `DateList`, `ErrorList`, `ErrorDetail`) — never an `^ERRORS` traversal, never `%CSP.ErrorLog`. It
  switches to `%SYS` **once** by explicit save and restore, with the restore the first line of every
  `Catch`, never into the target namespace; the target namespace travels as a **parameter** on every
  call and no slice writes `Set $NAMESPACE` for this path. The namespace comes from **one source
  only** — the drill level the user reached, carried in descriptor state — and a route `?ns=`
  parameter must not reach the port, because a second source would let a fully compliant delete purge
  a namespace other than the one on screen. `^ERRORS` is unmapped and lives in each namespace's own
  globals database, so the requirement resolves **per namespace** (`%Admin_Operate` plus read and
  write on that database) and a single static descriptor resource cannot express it. Each drill
  level is a table whose empty state names its scope. The captured detail — every local at every
  stack level plus `$ROLES` and `$USERNAME` — renders on screen and is **secret by default**: never
  in screen context, never sent to the model, the read tool returning summary fields only (time,
  error number, routine, line, error text). On IRIS for Health those tables can hold patient data,
  so the rule is absolute.
- **Known gaps — name them, do not re-file, do not work around per screen.** Owed to the burn-down:
  no manual Refresh action (DW-260); a stopped Task Manager raises no banner (DW-270); a misspelled
  *top-level* descriptor key installs silently (DW-271); EXPERIENCE.md citations outside `strings.ts`
  are ungated (DW-272); a list's table frame collapses to header height, so a real click at a row's
  centre lands on the footer — browser specs click above the fold and set `scrollTop` directly
  (DW-273); a query's own privilege refusal arrives as a 500 naming no pair (DW-274); OS management
  will gate on `%Admin_Manage:USE` once 6.8 and 7.8 land (DW-275); an over-long criterion answers
  500 (DW-279). Accepted as they stand: DW-276, DW-282 to DW-286, and
  DW-289 (`Test/WireSecurityRead.cls` creates nine principals on whatever instance a
  package-discovery run points at, with only a doc comment keeping it off a live one).

## Technical Decisions

- **Two ports, each with its own rule.** `OcuPilot.Port.AdminPort.Invoke` is the only caller of
  admin endpoints and the only file naming `%Api.Admin` (checked); anything but OK plus 2xx is a
  `{error, reason, code}` fault. `OcuPilot.Port.LogSourcePort` is the second port and inherits no
  vendor gate, so it evaluates its own pairs through `GateClass()`/`Gate.EvaluatePairs` **before**
  resolving, opening or reading anything — observed by a fixture open-counter, not merely asserted.
  Its entry is `Page(pSource, pOffset, pMaxBytes, pIdentity, Output …)`; its seams, all overridable
  by `Test/LogSourceFixture.cls`, are `Sources()`, `PairsFor(pSource)`, `FileFor(pSource)`,
  `ManagerDirectory()`, `MaxBytesCap()` and `GateClass()`. `PairsFor` is a function of the source
  precisely so a source can carry its own requirement; 2.12 is its first other consumer, the first
  to pass a source key of its own, and therefore the first that can reach
  `LOG.SOURCE`. Refusals go through `Refuse`/`Fail` → `Kernel.Fault.Build`, raw vendor or OS text to
  `Fault.LogRaw` only. The five `LOG.*` codes (`LOG.SOURCE`, `LOG.ABSENT`, `LOG.UNREADABLE`,
  `LOG.OFFSET`, `LOG.MAXBYTES`) are `Parameter`s on `Api/Error.cls`, the one home of the code
  vocabulary and the one writer of the envelope.
- **No endpoint takes a path or a namespace from the caller.** A fixed source enum, the manager
  directory resolved per call and never cached, the source key bound by a **literal** route in
  `Api/Router.cls` whose four-line wrapper calls `Api/LogPage.cls`. Literal matters:
  `check_handler_wire_tests` keys a `:param` route by its dispatch class, so it rides free on an
  existing wire test; a literal URL forces a test naming it verbatim with all four wire markers.
  Route order is N-segment before (N−1). The messages page has no descriptor and did **not** extend
  the read grammar — its cursor is its own parameters; Epic 6 gives it a screen.
- **Read and table grammar.** `read`'s closed key set is six: `source` (`port`, `endpoint`, `type`,
  optional `rowGet`), `fields`, `filter`, `sort`, `paging: cap`, `table` (`columns` of
  `{field, labelKey, kind}`, exactly one `name` kind), and `criteria` (server search parameters,
  admin-source only). No secret field is a column, filter or sort. Optional surfaces already built:
  `rowGet` (one detail call per surviving row — a 404 drops the row, any other row fault fails the
  read), a `banner` second read whose **any** fault answers `""` so the rows still list, and
  `refreshes`/`refreshRates`. Every rule is a refusal sentence held identically by
  `Registry.*Problem` and its `screen-mirror.mjs` twin; change both, and pin new ones in a shared
  corpus class.
- **A screen is one descriptor class** directly in `Screen/Descriptor/` (the mirror reads it flat),
  then `node ui/tools/screen-mirror.mjs`; the shared page renders it, with no per-screen route,
  handler, tool class or store. Templates to copy: the five plain lists (`rowGet`, banner and
  `kind: number` between them) and `AuditList`, the precedent for a screen whose route drives its own
  page and store. Each declares its own gate. Never set `navigates` on a list's area.
- **A pair set is established, not read off the endpoint (AD-29).** An endpoint's `ResourcesOR()` is
  a **lower bound**: read the backing query's own privilege check in `irislib/`, **and** run the read
  as a real least-privileged principal on a throwaway, adding what the instance still refuses. Every
  *admin-port* read also declares `%DB_IRISSYS:READ`, because that port switches to `%SYS` for every
  request; a file read enters no database, so `LogSourcePort`'s
  `messages` pair set is `%Admin_Operate:USE` alone (measured on a principal holding neither of the
  other two). An **empty** pair set is held by everyone, so a requirement that cannot be resolved
  must be refused explicitly rather than handed to `EvaluatePairs`.
- **An area covers its screens.** `Registry.AreaCoverageProblem` refuses a screen declaring a pair
  its area does not — containment only, so a surplus area pair stands. Logs declares
  `%Admin_Operate:USE`, `%Admin_Secure:USE`, `%DB_IRISSYS:READ`; the surplus `%Admin_Secure:USE`
  false denial on the remaining Logs screens is **accepted and re-owned to Epic 6** (DW-278) — do not
  re-decide it here. Pair **order** matters: the gate names the first unheld pair and `failedPair`
  fixtures pin it, so append rather than prepend.
- **Fields and secrets.** `Read.Project` copies only `read.fields` and writes `null` for a missing
  key, so the field-presence test is the drift guard. Probe the live source and declare its own
  spelling, carrying the readable label in the string key; where its value is wrong rather than
  absent, declare the field nowhere — an absent column beats a false one.
- **Execution and the view rule.** `Screen.Read.Execute` asks for `maxRows` + 1, strips secret fields
  once, answers `{fields, rows, truncated, banner}` at
  `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=`, declared criteria appended
  URL-encoded. Emitted timestamps are ISO-8601 UTC and calendar comparisons use `+$Horolog`. Client
  and server filter and sort identically over `Test/ReadViewCorpus.cls`, and a number arriving as a
  JSON string sorts lexicographically, so a value's JSON type is itself asserted.
- **Client shell.** Pages read through `RefreshService.readNow()`; the store persists sort,
  direction, filter and max rows per screen, and a refused tick is never retried. The outlet mounts
  no page until `NavigationService.answered()` (fail-open), so a denied deep link issues no read.
  Sort is the
  command bar's menu, never a clickable header. The client's one `role="dialog"` arrived with 2.10
  (440px, Escape closes, focus returns to the opener, no stacking).
- **Tripwires — each new screen edits all of them.** `Test/ReadTool` pins the production tool list by
  content (six today); `Test/Descriptor.cls` pins every area's pair set, `navigates` and `pinBottom`;
  `navigation.test.mjs` pins built routes in rail order; `navigation-wire.test.mjs` and
  `rail-wire.spec.ts` hold two byte-identical `LIVE_PAYLOAD` copies,
  **neither of which goes red on its own**; `screen-mirror.test.mjs` pins the descriptor and criteria
  rosters; `Install.Smoke` runs one live read per built list (six today, its bounds re-derived by
  `Test/Smoke.cls`) plus the independent `messageslog` check, and every check must **skip**, never
  pass, without credentials.
- **Browser and denial legs.** `ui/browser/list-spec.mjs`'s `filterToSubset` counts off
  `aria-rowcount` and never DOM rows — the table virtualises — and a leftover filter silently
  satisfies a cap assertion, so clear before asserting one. Under `%All` every check passes, so a
  denial needs a real principal: `Test/Wire.cls`, `Test/WireSecurityRead.cls` (a leg per screen) and
  `Test/LogSourceDenial.cls`, or a browser spec, on `scripts/ci-throwaway.sh` (`ocupilot-ci`,
  `OCUPILOT_DEMO=1`). A test class that mutates a real instance now **refuses to run outside the
  throwaway**: it reads an arming variable
  in `OnBeforeAllTests` (`OCUPILOT_ALLOW_PRINCIPALS` for principal creation,
  `OCUPILOT_ALLOW_LOG_ROTATION` for a real rotation), set only by `ci-throwaway.sh`, and
  `%UnitTest.Manager` throws before any `Test*` method runs. Follow that shape for anything 2.12
  creates or deletes; no security-object mutation on live `ocupilot`, and zero principals left behind.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll: `name` a `code` link, `status` a disc plus "Yes"/"No",
  empty "(none)" in body type, source strings verbatim. Footer "<n> rows", "Max rows" and the cap
  notice; "Filter rows" drives the filter.
- **Loading and empty.** Skeleton on first load only. The empty state follows only a successful
  zero-row read, names its scope, and invites the agent only on a write-capable screen; a faulted,
  denied or filtered-to-zero view is never empty.
- **Gating.** `aria-disabled` plus `readonly` — never the native `disabled` attribute the
  Accessibility Floor forbids — with "Requires <resource>:<permission>" in rail, side bar and command
  box; a denied deep link shows the title and "You need <pair> to open <screen>."; a 403 is an
  inline alert and on-screen data stays.
- **Strings.** Each screen adds its EXPERIENCE.md Fixed strings row (title, headers, empty-state
  lines) **before** its `strings.ts` keys — `strings.test.mjs` derives a closed-world key equality
  from that table, so a key with no row fails the build. Values must be unique (a label two screens
  share is one shared key) and non-ASCII is `\uXXXX`. Inserting rows shifts `EXPERIENCE.md:<line>`
  citations elsewhere in `ui/src` (DW-272); repair only the `strings.ts` ones, never "bumping" a
  citation into a document that did not move.

## Cross-Story Dependencies

- **Order.** 2.12 is the last story. It reads through 2.11's `LogSourcePort` — the sibling of the
  `messages` path, reached by extending the port's fixed enum and `PairsFor`, and it is the first
  caller to supply a source key of its own.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, demo fixture, smoke.
- **Waiting on this epic.** Epic 4 dispatches read tools (4.10's Home line needs the tasks
  `Suspended` signal, DW-269, and the per-namespace "application errors today" line this story
  sources); Epic 5 adds the agent line and row menu, and scopes its confirmed delete from 2.12's
  namespace; Epic 6 builds the messages.log viewer on 2.11's page contract and owns DW-278; 6.7 and
  6.8 are the task and process details the name and Pid cells navigate to (inert links until then).
