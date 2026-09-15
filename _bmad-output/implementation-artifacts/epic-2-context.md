# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real instance data: Web applications, Users, SSL/TLS, Task schedule,
Processes, and in Logs the audit viewer, a bounded messages.log endpoint and the application error
drill-down. Every screen is backed by one descriptor-declared read that the agent's read tool
shares, and every admin-API call goes through one port. All twelve delivery stories are done; what
remains is the burn-down, Story 2.13, which closes the Epic 2 findings that mislead a user, hide a
refusal or let a misdeclaration ship — so Epic 3 builds on screens that say what is true and a
grammar that refuses what it cannot serve.

## Stories

- Stories 2.0–2.9 (done): Epic 1 cleanup; `AdminPort`; write-tool field lists; the
  descriptor-declared read; the data table; the five system lists
- Stories 2.10–2.12 (done): the audit database viewer with its agent-marker filter; the
  messages.log paging endpoint; the application error log endpoint and drill-down
- Story 2.13: Epic 2 burn-down

## Requirements & Constraints

Epic invariants the burn-down must not break:

- **Bounds.** First page within 2 s at 1,000 rows, measured end to end against the instance. Every
  read is capped (default 1,000, editable, persisted per screen; no ceiling, no page-size control)
  and **reports truncation on screen** — a level cut at its cap must never present as the complete
  set.
- **One read, two consumers.** The tool's view is the screen's, narrowed by the context cap and
  stripped of secret fields; read tools are not dispatchable until Epic 4.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked per call,
  never cached; a denial **names the failing pair**. A refusal must never arrive as a 500.
- **Reads only, by construction.** `AdminPort.TYPESUFFIXES = "GET,LIST,INFO"` keeps every vendor
  write type unreachable, and no Epic 2 screen declares `rowActions` or a `primaryAction`.
- **Secrecy is structural.** The error log's captured detail (locals at every stack level, `$ROLES`,
  `$USERNAME`) renders on screen but never enters screen context or the model; the summary path
  calls `ErrorList`, never `ErrorDetail`. On IRIS for Health those tables can hold patient data, so
  no burn-down change may widen what the read tool returns.
- **Navigation.** No screen links out to the classic portal; an unbuilt screen has no side-bar
  entry; `?ns=` does not reach `LogSourcePort` — the drilled-to level in descriptor state is the one
  source of namespace.

The eleven chartered items, with the shape each fix has already been decided to take:

- **DW-273** (sharpest, user-facing): a list's table frame collapses to header height, the
  virtual-scroll viewport reads `clientHeight` 0, rows overflow and the footer paints over them, so
  a real click at a row's centre reaches the footer. Measured in headless Chrome on all four list
  routes; the cause is Story 2.4's `ListPage`/`DataTable` height chain over an outlet with no
  definite height. A browser check must go red if the measured viewport height returns to zero.
- **DW-274**: `AdminPort` answers 500 where a query's own privilege refusal should be a named 403.
  Note the vendor status **never reaches OcuPilot** — `%Api.Admin.Util.ClassQuery` discards what
  `%Execute()` returned, so the port sees an empty result set, not an error. The port must detect
  the refused query itself (probe the resource the query names, or read the result set's own status)
  and answer `PORT.ACCESSDENIED` carrying that resource, with a standing assertion, not a one-off.
- **DW-271**: descriptor top-level keys are not a closed set, so `banners`/`Banner` validates,
  mirrors and installs a screen whose strip never raises. Both engines must refuse by name.
- **DW-293**: every error-log level computes `truncated` and the client drops it — carry it into the
  drill store and show the cap notice, or say in the footer/empty line that the level is cut.
- **DW-270**: a stopped Task Manager raises no banner; the strip matches `Suspended` only. The
  stopped case needs its own sentence **and** a Fixed strings row added in the same pass — a row
  with no key breaks `strings.test.mjs`'s count.
- **DW-260**: no list offers the manual Refresh action EXPERIENCE.md requires; the command bar
  renders only the auto-refresh chip. It is wanted on the screens that auto-refresh and the ones
  that do not (the audit viewer most, since it never auto-refreshes).
- **DW-248**: after sign-in or instance recovery the frame replaces the focused instance notice and
  focus falls to the document. Decided: treat it as a route arrival — focus the screen's heading,
  else `main#ocu-content`; pin both paths in the browser.
- **DW-279**: a criterion longer than the vendor's own column answers 500 from inside the queued
  task's save. Add a `maxLength` to the criteria grammar, refused in both engines before the port —
  the same shape as the choice-options check.
- **DW-289**: `Test/WireSecurityRead.cls` creates nine principals on whatever instance a
  package-discovery run points at, with only a doc comment keeping it off a live one. The guard
  pattern already exists (see throwaway guards below); this is the last unguarded destructive class.
- **DW-275**: area coverage will gate all of OS management on `%Admin_Manage:USE` once Locks (7.8)
  and Process details (6.8) land. Decide deliberately: the area declares the union and accepts a
  false denial for narrower screens, or coverage relaxes to per-screen gating.
- **DW-272**: about 148 EXPERIENCE.md line citations outside `strings.ts` are behind no gate, and
  most are already stale — a row insertion makes them resolve to a wrong but plausible line rather
  than dangle. Widen the existing resolver to every `ui/src` citation, or drop line numbers from
  prose citations; re-resolve mechanically, never by hand-bumping.

## Technical Decisions

- **The descriptor grammar has two engines.** Every rule is a refusal sentence held identically by
  `Screen/Registry.cls`'s `*Problem` methods and its `ui/tools/screen-mirror.mjs` twin; change both.
  New rules are pinned in a **shared corpus class** (`Test/*Corpus.cls` — `BannerCorpus`,
  `CriteriaCorpus`, `AdminPairCorpus`, `RowGetCorpus` are the templates), whose `Cases` XData
  `screen-mirror.test.mjs` reads off disk so one file drives both sides. `UnknownKeyProblem` is
  already applied to `read`, `read.source`, `read.sort`, `context`, `rowGet`, `table`,
  `table.columns` and `banner` — but never to the declaration object itself, which is DW-271.
- **`read`'s closed key set is six**: `source` (`port`, `endpoint`, `type`, optional `rowGet`),
  `fields`, `filter`, `sort`, `paging: cap`, `table` (`columns` of `{field, labelKey, kind}`,
  exactly one `name` kind), plus `criteria` (server search parameters, admin-source only). No secret
  field is a column, filter or sort. Optional surfaces built: `rowGet`, a `banner` second read whose
  **any** fault answers `""` so rows still list, and `refreshes`/`refreshRates`.
- **`Screen/Read.cls`** asks for `maxRows` + 1, strips secret fields once and answers
  `{fields, rows, truncated, banner}` at `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=`,
  declared criteria appended URL-encoded. `BannerKey` is where the task strip's `Suspended` match
  lives; `Project` copies only `read.fields`; `SeedCriteria` is the precedent for a criterion
  refused `400 READ.CRITERION` before the port, on both callers.
- **Two ports, each with its own rule.** `OcuPilot.Port.AdminPort.Invoke` is the only caller of
  admin endpoints and the only file naming `%Api.Admin` (checked); anything but OK plus 2xx is a
  `{error, reason, code}` fault built through `Kernel.Fault.Build`, with raw vendor text going to
  `Fault.LogRaw` only. `OcuPilot.Port.LogSourcePort` inherits no vendor gate, so it evaluates its own
  pairs through `GateClass()`/`Gate.EvaluatePairs` **before** resolving or reading anything.
  `Api/Error.cls` is the one home of the code vocabulary and the one writer of the envelope —
  `PORT.ACCESSDENIED`, `READ.CRITERION` and the five `LOG.*` codes are `Parameter`s there.
- **A pair set is established, not read off the endpoint (AD-29).** An endpoint's `ResourcesOR()` is
  a lower bound: read the backing query's own privilege check in `irislib/`, **and** run the read as
  a real least-privileged principal on a throwaway, adding what the instance still refuses. Every
  admin-port read also declares `%DB_IRISSYS:READ`. An **empty** pair set is held by everyone, so an
  unresolvable requirement is refused explicitly rather than handed to `EvaluatePairs`.
- **An area covers its screens.** `Registry.AreaCoverageProblem` refuses a screen declaring a pair
  its area does not — containment only, so a surplus area pair stands (that is DW-275's whole
  tension). Logs' surplus `%Admin_Secure:USE` false denial is **accepted and re-owned to Epic 6**
  (DW-278) — do not re-decide it here. Pair **order** matters: the gate names the first unheld pair
  and `failedPair` fixtures pin it, so append rather than prepend.
- **Client shell.** One data table on CDK virtual scroll inside `shell/list-page.ts`; pages read
  through `RefreshService.readNow()` (`core/refresh.ts`), which already exists and is what a manual
  Refresh action calls. `shell/command-bar.ts` renders the auto-refresh chip gated on
  `hasRefreshChip`, the sort menu (never a clickable header) and the filter input; the store persists
  sort, direction, filter and max rows per screen, and a refused tick is never retried. The outlet
  mounts no page until `NavigationService.answered()` (fail-open). The error-log drill store is
  separate and is the one that drops `truncated`.
- **Tripwires — a change here edits all of them.** `Test/ReadTool` pins the production tool list by
  content; `Test/Descriptor.cls` pins every area's pair set, `navigates` and `pinBottom`;
  `navigation.test.mjs` pins built routes in rail order; `navigation-wire.test.mjs` and
  `rail-wire.spec.ts` hold two byte-identical `LIVE_PAYLOAD` copies, **neither of which goes red on
  its own**; `screen-mirror.test.mjs` pins the descriptor and criteria rosters; `Install.Smoke` runs
  one live read per built list plus the independent `messageslog` check, and every check must
  **skip**, never pass, without credentials.
- **Browser and denial legs.** `ui/browser/list-spec.mjs`'s `filterToSubset` counts off
  `aria-rowcount` and never DOM rows — the table virtualises — and a leftover filter silently
  satisfies a cap assertion, so clear before asserting one. The specs currently click **above the
  fold** and set `scrollTop` directly, which is exactly why DW-273 was never caught; a real
  centre-of-row click is the new evidence. Under `%All` every check passes, so a denial needs a real
  principal: `Test/Wire.cls`, `Test/WireSecurityRead.cls`, `Test/LogSourceDenial.cls` and
  `Test/ErrorLogDenial.cls`, or a browser spec, on `scripts/ci-throwaway.sh` (`ocupilot-ci`,
  `OCUPILOT_DEMO=1`).
- **Throwaway guards.** A test class that mutates a real instance reads an arming variable in
  `OnBeforeAllTests` (`OCUPILOT_ALLOW_PRINCIPALS` for principal creation,
  `OCUPILOT_ALLOW_LOG_ROTATION` for a real rotation), set only by `ci-throwaway.sh`, so
  `%UnitTest.Manager` throws before any `Test*` method runs. That three-line shape is the fix for
  DW-289. No security-object mutation on live `ocupilot`; zero principals left behind. `ci-runner.mjs`
  selects test classes by **package**, which is how an unguarded class reaches a live instance.

## UX & Interaction Patterns

- **One data table**: `name` a `code` link, `status` a disc plus "Yes"/"No", empty "(none)" in body
  type, source strings verbatim. Footer "<n> rows", "Max rows" and the cap notice; "Filter rows"
  drives the filter. The cap notice is the existing precedent DW-293's drill levels should match.
- **Loading and empty.** Skeleton on first load only. The empty state follows only a successful
  zero-row read, names its scope, and invites the agent only on a write-capable screen; a faulted,
  denied or filtered-to-zero view is never empty.
- **Gating.** `aria-disabled` plus `readonly` — never the native `disabled` attribute the
  Accessibility Floor forbids — with "Requires <resource>:<permission>" in rail, side bar and command
  box; a denied deep link shows the title and "You need <pair> to open <screen>."; a 403 is an
  inline alert and on-screen data stays.
- **Focus.** A route arrival moves focus to the screen's heading; that is the published destination
  DW-248 adopts for the frame's arrival after sign-in and recovery.
- **Strings.** Each new or changed sentence adds its EXPERIENCE.md Fixed strings row **before** its
  `strings.ts` key — `strings.test.mjs` derives a closed-world key equality from that table, so a key
  with no row, or a row with no key, fails the build. Values must be unique (a label two screens
  share is one shared key) and non-ASCII is `\uXXXX`. Inserting rows shifts every `EXPERIENCE.md:<line>`
  citation below it (DW-272).

## Cross-Story Dependencies

- **Order.** 2.13 is the last story of the epic and touches shared surfaces every earlier story
  built — the grammar and its two engines, `Screen/Read.cls`, `AdminPort`'s fault mapping,
  `Screen/Area.cls`, the table and height chain, the command bar and `RefreshService`. Expect
  tripwire edits in several stories' fixtures for one change.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, demo fixture, smoke.
- **Waiting on this epic.** Epic 3 starts once the burn-down lands; Epic 4 dispatches read tools
  (4.10's Home line needs the tasks `Suspended`/stopped signal and the per-namespace "application
  errors today" line); Epic 5 adds the agent line and row menu and scopes its confirmed delete from
  2.12's namespace; Epic 6 builds the messages.log viewer and owns DW-278; 6.8 and 7.8 are the
  process and lock screens whose landing forces DW-275's decision.
