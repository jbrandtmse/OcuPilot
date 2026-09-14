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
- Story 2.5: The web applications list
- Story 2.6: The users list
- Story 2.7: The SSL/TLS configurations list
- Story 2.8: The task schedule list
- Story 2.9: The processes list
- Story 2.10: The audit database viewer, with its agent-marker filter
- Story 2.11: The messages.log paging endpoint
- Story 2.12: The application error log endpoint and drill-down

## Requirements & Constraints

- **Bounds.** First page within 2 s at 1,000 rows: the table alone is proven in the pinned browser; the end-to-end instance read at 1,000 rows is first measured in 2.10. Every read is capped (default 1,000, editable, persisted per screen with sort and filter; no ceiling, no page-size control) and reports truncation.
- **One read, two consumers.** The tool's view is the screen's, narrowed by the context cap and stripped of secret fields. Read tools are not dispatchable until Epic 4; nothing here depends on that.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked per call, never cached; a denial names the failing pair. A descriptor names the classic page it replaces, so an operator's custom resource on it still applies.
- **Navigation.** No list links out to the classic portal; an unbuilt screen has no side-bar entry. Ids use the one-segment encoder (`/csp/myapp`, `_SYSTEM` round-trip).
- **Secrets and state.** No private key material in any SSL/TLS read. Disabled or expired reads as a word, never color alone.
- **Demo rows** on a fresh container: `/csp/myapp` disabled with no resource, a demo SSL/TLS configuration, a task suspended after an error.
- **Logs.** No endpoint accepts a filesystem path: a fixed source enum, directory from `$System.Util.ManagerDirectory()` per call; pages survive rotation; `LogSourcePort` runs `$System.Security.Check` before any access. The audit viewer never hides OcuPilot's own events and the marker filter is not a default; its privilege set needs `%Admin_Secure` and `%Admin_Operate`, or the port forgets a task whose poll is refused. The error log reads only through `SYS.ApplicationError`, takes its namespace only from the drill level, and its variable table never reaches screen context or the model.

## Technical Decisions

- **AdminPort (delivered).** `OcuPilot.Port.AdminPort.Invoke` is the only caller of admin endpoints and the only file naming `%Api.Admin` (checked). Callers pass a package-relative endpoint (`WebApp.App`), a type and `pQuery`; anything but OK plus 2xx is an error with a `{error, reason, code}` fault. Async calls are polled inside the port (`PORT.TIMEOUT`, 30 s). Under `%All` every check passes, so a denial test needs a real denied principal.
- **Read declaration (delivered).** `read` holds `source` (`port: admin`, `endpoint`, `type: LIST`), unique `fields`, `filter`, `sort` (`fields`, `default`, `direction`) and `paging: cap`; it requires `context.secretFields`, and no secret field is filterable or sortable. `toolIdentifier` `<area>.<screen>` names the tool `<toolIdentifier>.read`. No other port or cursor paging is admitted, so 2.11 would extend the grammar (inference).
- **Table declaration (delivered).** A read also declares `table`: `columns` of `{field, labelKey, kind}` (`name`, `identifier`, `text`, `number`, `status`; exactly one `name`; fields from `read.fields`; never a secret field), plus `emptyNextKey` and `emptyAgentKey` beside a non-empty `emptyStateKey`. **Write-capable** means a declared primary or row action: it sets `emptyAgentKey` only, any other `emptyNextKey` only. Every key names a `STRINGS` key. The grammar demands `table` on any read; a first non-list read amends it. `Screen.Registry.Validate` and `ui/tools/screen-mirror.mjs` hold identical refusals; change both.
- **Execution (delivered).** `Screen.Read.Execute(descriptor, maxRows)` asks for `maxRows` + 1, strips `context.secretFields` once for route and tool, and answers `{fields, rows, truncated}`. `GET /api/ocupilot/screens/:screen/read?maxRows=` serves every screen (404 `ROUTE.NOTFOUND`, 403 `AUTH.NOPRIVILEGE`, 400 `READ.MAXROWS`); no per-screen route, handler or tool class.
- **View rule, twice.** Client filters and sorts for the screen, server for the tool, both over `Test/ReadViewCorpus.cls`: case-insensitive ASCII contains; stable sort on one field, numbers numerically, `null` last. Change it through the corpus.
- **Client list (delivered).** `ListPage` (the `list` archetype) binds the read through `RefreshService`; `DataTable` draws it. The store persists sort, direction, filter and max rows per screen; nothing writes sort or direction yet. `readNow()` serves first load, Retry, max-rows commit, scope switch and a `changed` event. A refused tick is never retried: a banner fault waits for the connectivity park, any other keeps rows and shows "request refused" with Retry. Row key is the `name` column's text; the name links only when an id route exists.
- **Checks.** `check-objectscript.py` enforces route order and tool `KIND`. Descriptors are one class each under `Screen/Descriptor/`; design tokens only. Every handler gets an HTTP integration test, every tool a schema round-trip test; geometry and focus go in `npm run test:browser` on `scripts/ci-throwaway.sh`.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll: `name` a `code` link, identifiers in `code`, numbers tabular and right-aligned, status a disc plus "Yes"/"No", empty "(none)"; footer "<n> rows", labeled "Max rows" and the cap notice. The command bar's "Filter rows" drives the filter.
- **Keyboard.** `role="grid"`, one Tab stop, `aria-activedescendant`; moving selects, Enter opens, Alt+Down or `contextmenu` opens the row menu. Row click selects; the name link opens.
- **Loading and empty.** Skeleton on first load only. The empty state appears only after a successful zero-row read, names its scope, and invites the agent on a write-capable list; a faulted, denied or filtered-to-zero view is never one. The audit viewer opens on its criteria form.
- **Gating.** `aria-disabled` plus "Requires <resource>"; a 403 is an inline alert and on-screen data stays.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical; non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.5 is the first production descriptor to declare a read and a table, so it is first over the wire and trips `ReadTool`'s deliberate zero-tools assertion. 2.6–2.9 follow the same shape; no control writes sort yet, so 2.9's persisted sort needs one or rests on the declared default (inference). 2.10 runs the async LIST through `Execute` plus server criteria under `DataTable`, and carries the end-to-end 1,000-row timing. 2.12 uses 2.11's `LogSourcePort`.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, demo fixture, smoke script (one live list per area).
- **Waiting on this epic.** Epic 4 dispatches read tools and supplies `contextCap`; Epic 5's first write-capable list uses the agent line, row menu and change highlight, finds writes through 2.10's marker filter and scopes error-log deletes by 2.12's namespace; Epic 6 builds on 2.11; write tools consume 2.2's field lists.
