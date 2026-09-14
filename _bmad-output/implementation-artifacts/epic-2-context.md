# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real instance data: Web applications, Users, SSL/TLS, Task schedule, Processes, and in Logs the audit viewer, application error drill-down and a bounded messages.log endpoint. Every list is backed by one descriptor-declared read that the agent's read tool shares, and every admin-API call goes through one port. Build step 1: once the smoke script passes, the listing build can be submitted.

## Stories

- Story 2.0: Epic 1 Deferred Cleanup (done)
- Story 2.1: The AdminPort reproduces the vendor's dispatcher, exactly once (done)
- Story 2.2: Write-tool field lists are derived at build time and pinned in CI (done)
- Story 2.3: One descriptor-declared read serves both the screen and its read tool (done)
- Story 2.4: The data table (done)
- Story 2.5: The web applications list (done)
- Story 2.6: The users list (done)
- Story 2.7: The SSL/TLS configurations list
- Story 2.8: The task schedule list
- Story 2.9: The processes list
- Story 2.10: The audit database viewer, with its agent-marker filter
- Story 2.11: The messages.log paging endpoint
- Story 2.12: The application error log endpoint and drill-down

## Requirements & Constraints

- **Bounds.** First page within 2 s at 1,000 rows (table proven in the browser; the end-to-end read is measured in 2.10). Every read is capped (default 1,000, editable, persisted per screen; no ceiling, no page-size control) and reports truncation.
- **One read, two consumers.** The tool's view is the screen's, narrowed by the context cap and stripped of secret fields. Read tools are not dispatchable until Epic 4.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked per call, never cached; a denial names the failing pair. A descriptor names the classic page it replaces, so an operator's custom resource on it still applies.
- **Navigation.** No list links out to the classic portal; an unbuilt screen has no side-bar entry. Ids use the one-segment encoder (`/csp/myapp`, `_SYSTEM` round-trip); a name-keyed entity is a `single` id, not composite.
- **Secrets and state.** No private key material in any SSL/TLS read. Disabled or expired (an `ExpirationDate` set and earlier than today on the instance clock) reads as a word, never color alone.
- **Demo rows** on a fresh container: `/csp/myapp` disabled with no resource (shipped), a demo SSL/TLS configuration, a task suspended after an error.
- **Logs.** No endpoint takes a filesystem path: a fixed source enum, directory from `$System.Util.ManagerDirectory()` per call; pages survive rotation; `LogSourcePort` runs `$System.Security.Check` first. The audit viewer never hides OcuPilot's own events, the marker filter is not a default, and its set needs `%Admin_Secure` and `%Admin_Operate`. The error log reads only through `SYS.ApplicationError`, takes its namespace only from the drill level, and its variable table never reaches context or the model.
- **Known gap.** No list has the manual Refresh action (DW-260, burndown); do not add one per screen.

## Technical Decisions

- **AdminPort.** `OcuPilot.Port.AdminPort.Invoke` is the only caller of admin endpoints and the only file naming `%Api.Admin` (checked). Callers pass a package-relative endpoint, a type and `pQuery`; anything but OK plus 2xx is a `{error, reason, code}` fault. Async calls are polled inside the port (`PORT.TIMEOUT`, 30 s). The epics' REST paths name the data, not the call: 2.5's `GET /web-apps` is the `WebApp.App` LIST.
- **Read and table grammar.** `read`: `source` (`port: admin`, `endpoint`, `type: LIST`, optional `rowGet`), `fields`, `filter`, `sort` (`fields`, `default`, `direction`), `paging: cap`, `table` (`columns` of `{field, labelKey, kind}`, kinds `name`/`identifier`/`text`/`number`/`status`, exactly one `name`; `emptyNextKey`, or `emptyAgentKey` only when a primary or row action is declared). No secret field is a column, filter or sort. No cursor paging, so 2.11 would extend the grammar (inference). `Registry.ReadProblem` and `screen-mirror.mjs` `readProblem` hold identical refusal sentences; change both, and pin new ones in a shared corpus class the way `Test/RowGetCorpus.cls` does.
- **A list screen is one descriptor class** directly in `Screen/Descriptor/` (the mirror reads it flat), then `node ui/tools/screen-mirror.mjs`; `ListPage` renders it, with no per-screen route, handler, tool class, page, store or `areas/` file. `WebAppList` and `UserList` are the templates: instance scope, `single` id, tool `webapp.list.read` / `permissions.users`. The gate does not union the area's pairs; each descriptor declares its own. Never set `navigates` on a list's area.
- **The admin-port read pair set.** Proven on the throwaway with a real principal: `%Admin_Secure:USE` + `%DB_IRISSYS:READ` together, each necessary, both sufficient — the port switches to `%SYS`, whose `%DB_IRISSYS` has no public permission. `WebAppList`, `UserList` and both the `web-applications` and `permissions` areas in `Screen/Area.cls` declare the pair. Never `%DB_IRISSECURITY`: IRIS refuses to grant it to a role (probed). Whether *every* admin-port read needs `%DB_IRISSYS:READ` is still unproven (DW-264, 2.7).
- **Fields are the live row's keys.** Probe the vendor LIST; it can differ from the GET/PUT schema (`Namespace`, not `NameSpace`). `Read.Project` writes `null` for a missing key, so `Test/ScreenRead`'s field-presence test over admin-LIST descriptors is the drift guard.
- **Execution.** `Screen.Read.Execute` asks for `maxRows` + 1, strips secret fields once, answers `{fields, rows, truncated}` at `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=`.
- **Per-row detail (AD-36, landed in 2.6).** A read may name one detail call, `read.source.rowGet`, when the LIST omits needed fields. After the cap, one GET of the same endpoint per surviving row merges the declared `fields` with their JSON types; a 404 drops the row, any other row fault fails the whole read, and `truncated` still follows the LIST. `rowGet.derived` computes fields on the instance from a closed rule set — the only rule is `beforeToday`, true when a `YYYY-MM-DD` value is earlier than `+$Horolog`, false for `""`/`null`, and a malformed date is a 500 `INTERNAL`.
- **Dates.** The spine's Conventions Dates row is scoped: emitted timestamps are ISO-8601 UTC; comparisons against the instance's own calendar date use `+$Horolog`.
- **View rule, twice.** Client (screen) and server (tool) filter and sort over `Test/ReadViewCorpus.cls`: case-insensitive ASCII contains; stable one-field sort, numbers numerically, `null` last. An array's text is its members' texts joined by `, `, in both engines, and that text is what the cell, the filter and the sort read.
- **Classic links, once.** `Registry.ClassicLinkProblem` takes the parsed declaration, and both it and `classic-links.mjs` `classicLinkProblem` are pinned against one shared corpus, `OcuPilot.Test.ClassicLinkCorpus` (XData `Cases`, `{name, declaration, expected}`). `classicLinkExemption.exempt` must be a JSON boolean; the sentences use double quotes.
- **Client shell.** `ListPage` reads through `RefreshService.readNow()`; the store persists sort, direction, filter and max rows per screen. A refused tick is never retried. The outlet mounts no page until `NavigationService.answered()` (a failed map read counts, fail-open), so a denied deep link issues no read.
- **Tripwires per list.** `Test/ReadTool` pins the production tool list; `Test/Descriptor.cls` pins every area's privilege pair set, `navigates` and `pinBottom` by content; `navigation.test.mjs`, `navigation-wire.test.mjs` and `rail-wire.spec.ts` pin built routes and `LIVE_PAYLOAD`; `Install.Smoke` runs one live screen read per built list (`webapplications`, `users`) and its `arealists` pending note names the areas still to come.
- **Denial and demo checks run on the throwaway.** Under `%All` every check passes, so a denial needs a real principal: `Test/Wire.cls` and `Test/WireSecurityRead.cls`, or a browser spec on `scripts/ci-throwaway.sh` (`ocupilot-ci`, `OCUPILOT_DEMO=1`) that deletes its principal. No security-object mutation on live `ocupilot`; leave zero principals behind.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll: `name` a `code` link, identifiers in `code`, numbers tabular and right-aligned, `status` a disc plus "Yes"/"No" (a boolean outside a `status` column reads Yes/No with no disc), empty "(none)" in body type; vendor strings verbatim (`System,CSP`). Footer "<n> rows", "Max rows" and the cap notice. "Filter rows" drives the filter.
- **Loading and empty.** Skeleton on first load only. The empty state follows only a successful zero-row read, names its scope, and invites the agent only on a write-capable list; a faulted, denied or filtered-to-zero view is never empty.
- **Gating.** `aria-disabled` plus "Requires <resource>:<permission>" in rail, side bar and command box; a denied deep link shows the title and "You need <pair> to open <screen>."; a 403 is an inline alert and on-screen data stays.
- **Strings.** Each list adds one EXPERIENCE.md Fixed strings row (title, headers, empty-state lines) and `strings.ts` keys, whose `EXPERIENCE.md:<line>` comments `strings.test.mjs` checks; `strings.test.mjs` requires unique values, so a label two lists share is one shared key (Name, Type, Enabled, the empty-state second line, Namespace's `headerNamespaceLabel`). Non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.7–2.9 copy `WebAppList`/`UserList`'s shape. 2.7 owns DW-264 (prove its pair set with a real principal on the throwaway; if every admin-port read needs `%DB_IRISSYS:READ`, make the read grammar refuse a declaration without it) and DW-266 (nothing checks an area's declared pair set covers the union of its screens' sets — `Registry.Validate` should refuse that; corrected scope: `Gate.RequiredPairs` never unions the area set, so only a screen declaring the missing pair is refused, not every screen inside). 2.9's persisted sort needs a sort control or rests on the declared default (inference). 2.10 runs the async LIST through `Execute` plus server criteria and carries the 1,000-row timing. 2.12 uses 2.11's `LogSourcePort`.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, demo fixture, smoke script.
- **Waiting on this epic.** Epic 4 dispatches read tools; Epic 5 uses the agent line, row menu, change highlight, 2.10's marker filter and 2.12's namespace; 7.1, 8.1 and 9.2 add web-app row actions, Create and the editor; Epic 6 builds on 2.11 and owns the fault banner's cross-area link (DW-148 residual); write tools consume 2.2's field lists.
