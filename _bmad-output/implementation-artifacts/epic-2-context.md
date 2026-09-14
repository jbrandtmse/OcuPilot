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
- Story 2.6: The users list
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
- **Read and table grammar.** `read`: `source` (`port: admin`, `endpoint`, `type: LIST`), `fields`, `filter`, `sort` (`fields`, `default`, `direction`), `paging: cap`, `table` (`columns` of `{field, labelKey, kind}`, kinds `name`/`identifier`/`text`/`number`/`status`, exactly one `name`; `emptyNextKey`, or `emptyAgentKey` only when a primary or row action is declared). No secret field is a column, filter or sort. No cursor paging, so 2.11 would extend the grammar (inference). `Registry.Validate` and `screen-mirror.mjs` hold identical refusals; change both.
- **A list screen is one descriptor class** directly in `Screen/Descriptor/` (the mirror reads it flat), then `node ui/tools/screen-mirror.mjs`; `ListPage` renders it, with no per-screen route, handler, tool class, page, store or `areas/` file. `WebAppList` is the template: instance scope, `single` id, `%Admin_Secure:USE` (the vendor's `ResourcesOR`; may under-declare, DW-262), tool `webapp.list.read`. The gate does not add the area's pairs; each descriptor declares its own. Never set `navigates` on a list's area.
- **Fields are the live row's keys.** Probe the vendor LIST; it can differ from the GET/PUT schema (`Namespace`, not `NameSpace`). `Read.Project` writes `null` for a missing key, so `Test/ScreenRead`'s field-presence test over admin-LIST descriptors is the drift guard.
- **Execution.** `Screen.Read.Execute` asks for `maxRows` + 1, strips secret fields once, answers `{fields, rows, truncated}` at `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=`.
- **Per-row detail.** A read may name one detail call, `source.rowGet`, when the LIST omits needed fields (`Security.User` LIST has six keys, no `Roles` or expiry; its GET has both). After the cap, one GET per surviving row merges the declared detail fields; a 404 drops the row, any other row fault fails the whole read. Not yet in the grammar or mirror; 2.6 adds it.
- **View rule, twice.** Client (screen) and server (tool) filter and sort over `Test/ReadViewCorpus.cls`: case-insensitive ASCII contains; stable one-field sort, numbers numerically, `null` last.
- **Client shell.** `ListPage` reads through `RefreshService.readNow()`; the store persists sort, direction, filter and max rows per screen. A refused tick is never retried. The outlet mounts no page until `NavigationService.answered()` (a failed map read counts, fail-open), so a denied deep link issues no read.
- **Tripwires per list.** `Test/ReadTool` pins the production tool list; `navigation.test.mjs`, `navigation-wire.test.mjs` and `rail-wire.spec.ts` pin built routes and `LIVE_PAYLOAD`; `Install.Smoke` gets one live check per area (`webapplications` exists) and `arealists` pending names the rest.
- **Denial and demo checks run on the throwaway.** Under `%All` every check passes, so a denial needs a real principal: `Test/Wire.cls`'s `%Admin_Operate` user, or a browser spec on `scripts/ci-throwaway.sh` (`ocupilot-ci`, `OCUPILOT_DEMO=1`) that deletes its principal. No security-object mutation on live `ocupilot`.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll: `name` a `code` link, identifiers in `code`, numbers tabular and right-aligned, status a disc plus "Yes"/"No", empty "(none)" in body type; vendor strings verbatim (`System,CSP`). Footer "<n> rows", "Max rows" and the cap notice. "Filter rows" drives the filter.
- **Loading and empty.** Skeleton on first load only. The empty state follows only a successful zero-row read, names its scope, and invites the agent only on a write-capable list; a faulted, denied or filtered-to-zero view is never empty.
- **Gating.** `aria-disabled` plus "Requires <resource>:<permission>" (e.g. "Requires %Admin_Secure:USE") in rail, side bar and command box; a denied deep link shows the title and "You need <pair> to open <screen>."; a 403 is an inline alert and on-screen data stays.
- **Strings.** Each list adds one EXPERIENCE.md Fixed strings row (title, headers, empty-state lines) and `strings.ts` keys, whose `EXPERIENCE.md:<line>` comments `strings.test.mjs` checks; Namespace reuses `headerNamespaceLabel`. Non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.6–2.9 copy `WebAppList`'s shape. 2.6 owns DW-186 (one shared JSON link-out corpus both engines read, a test per engine) and DW-262 (`AdminPort` runs in `%SYS`, whose `%DB_IRISSYS` has no public permission: prove the security read pair set with a real principal on the throwaway, add `%DB_IRISSYS:READ` to `WebAppList` if confirmed). 2.9's persisted sort needs a sort control or rests on the declared default (inference). 2.10 runs the async LIST through `Execute` plus server criteria and carries the 1,000-row timing. 2.12 uses 2.11's `LogSourcePort`.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, demo fixture, smoke script.
- **Waiting on this epic.** Epic 4 dispatches read tools; Epic 5 uses the agent line, row menu, change highlight, 2.10's marker filter and 2.12's namespace; 7.1, 8.1 and 9.2 add web-app row actions, Create and the editor; Epic 6 builds on 2.11 and owns the fault banner's cross-area link (DW-148 residual); write tools consume 2.2's field lists.
