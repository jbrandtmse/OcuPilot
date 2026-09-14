# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real instance data: Web applications, Users, SSL/TLS, Task schedule, Processes, and in Logs the audit viewer, application error drill-down and a bounded messages.log endpoint. Every list is backed by one descriptor-declared read that the agent's read tool shares, and every admin-API call goes through one port. Build step 1: once the smoke script passes, the listing build can be submitted.

## Stories

- Story 2.0: Epic 1 Deferred Cleanup (done)
- Story 2.1: The AdminPort reproduces the vendor's dispatcher, exactly once (done)
- Story 2.2: Write-tool field lists are derived at build time and pinned in CI (done)
- Story 2.3: One descriptor-declared read serves both the screen and its read tool (done)
- Story 2.4: The data table
- Story 2.5: The web applications list
- Story 2.6: The users list
- Story 2.7: The SSL/TLS configurations list
- Story 2.8: The task schedule list
- Story 2.9: The processes list
- Story 2.10: The audit database viewer, with its agent-marker filter
- Story 2.11: The messages.log paging endpoint
- Story 2.12: The application error log endpoint and drill-down

## Requirements & Constraints

- **Bounds.** First page within 2 s at 1,000 rows. Every read is capped (default 1,000, editable, persisted per screen with sort and filter) and reports truncation. No page-size control.
- **One read, two consumers.** The tool's view is the screen's, narrowed by the context cap and stripped of secret fields. Read tools are not dispatchable until Epic 4; nothing here depends on that.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked per call, never cached; a denial names the failing pair. A descriptor names the classic page it replaces, so an operator's custom resource on it still applies. A denied screen is never an empty state.
- **Navigation.** No list links out to the classic portal; an unbuilt screen has no side-bar entry. Ids use the one-segment encoder (`/csp/myapp`, `_SYSTEM` round-trip).
- **Secrets and state.** No private key material in any SSL/TLS read. Disabled or expired reads as a word, never color alone.
- **Demo rows** on a fresh container: `/csp/myapp` disabled with no resource, a demo SSL/TLS configuration, a task suspended after an error.
- **Logs.** No endpoint accepts a filesystem path: a fixed source enum, directory from `$System.Util.ManagerDirectory()` per call; messages.log pages survive rotation; `LogSourcePort` runs `$System.Security.Check` before any access. The audit viewer never hides OcuPilot's own events and the marker filter is not a default; its privilege set needs `%Admin_Secure` and `%Admin_Operate` (the async poll), or the port must forget a task whose poll is refused. The error log reads only through `SYS.ApplicationError`, takes its namespace only from the drill level, and its variable table never reaches screen context or the model.

## Technical Decisions

- **AdminPort (delivered).** `OcuPilot.Port.AdminPort.Invoke` is the only caller of admin endpoints and the only file naming `%Api.Admin` (checked). Callers pass a package-relative endpoint (`WebApp.App`), a type (`GET`, `LIST`, `INFO`) and `pQuery`. Anything but OK plus 2xx is an error status with a `{error, reason, code}` fault. A LIST answers a bare array with no truncation signal. Async (the audit LIST, database directory info) is polled inside the port, `PORT.TIMEOUT` at 30 s; slices write no polling. Under `%All` every check passes, so a denial test needs a real denied principal.
- **Read declaration (delivered).** `read` holds `source` (`port: admin`, `endpoint`, `type: LIST`), unique non-empty `fields`, `filter`, `sort` (`fields`, `default`, `direction`) and `paging: cap`. Unknown keys in `read` or `context` are refused; a read requires `context.secretFields`, and no secret field is filterable or sortable. `toolIdentifier` is `<area>.<screen>` in lower case, unique, and names the tool `<toolIdentifier>.read`. `Screen.Registry.Validate` and `ui/tools/screen-mirror.mjs` hold the same refusals; change both. No other port and no cursor paging are admitted yet, so 2.11's source would need the grammar extended (inference).
- **Execution (delivered).** `Screen.Read.Execute(descriptor, maxRows)` asks the port for `maxRows` + 1 and answers `{fields, rows, truncated}` (absent key `null`; port faults pass through). `GET /api/ocupilot/screens/:screen/read?maxRows=` (`:screen` = `toolIdentifier`) gates before the port: 404 `ROUTE.NOTFOUND` unknown or readless, 403 `AUTH.NOPRIVILEGE` with the pair, 400 `READ.MAXROWS` unless a positive integer. No per-screen route, handler or tool class. No production descriptor declares a read yet; 2.5's first one trips a deliberate zero-tools assertion.
- **View rule, twice.** The client filters and sorts for the screen, the server for the tool; `Test/ReadViewCorpus.cls` is read by both suites. Filter: any filter field's text contains the text, ASCII-only lower-casing. Sort: stable merge on one field, numbers numerically, else JSON text by code unit, `null` last. Change it through the corpus, both sides.
- **Client read (delivered).** `ui/src/app/core/screen-read.ts`: `applyView(rows, read, {filter, sort, direction})` and `createScreenRead(api, declaration)`, a `RefreshRead` under the service's scope answering `classifyFault` faults; a refused tick keeps the store's rows.
- **Read tools (delivered).** `Screen.Tool.Registry` has discovery and argument validation only (`ListTools`, `Resolve`, `ValidateArguments`); no `Dispatch`. `Tool.Read.View(descriptor, args, contextCap)` validates `filter`, `sort`, `direction`, `maxRows` before any port call. A concrete tool whose `KIND` is not `read` or `write` fails `check-objectscript.py`.
- **Routes.** 405 guards before the catch-all, sub-resource routes before `:param` routes, longer before shorter; `check-objectscript.py` (16 rules) enforces all three.
- **Descriptors** are one class each under `Screen/Descriptor/`, cached per process by compiled class hash; adding a screen edits no router, nav list or registry. Client screens are `<screen>.page.ts`, a framework-free `.store.ts` and `.descriptor.ts` under `ui/src/app/areas/<area>/`; design tokens only.
- **Auto-refresh** (Task schedule, Processes) silently re-fetches through the same read, keeping sort, filter, selection and scroll.
- **Tests.** Every handler gets an HTTP integration test, every tool a schema round-trip test.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll: identifiers in `code`, numbers tabular and right-aligned, status a disc plus a word, empty "(none)", footer with row count, labeled max-rows field and the cap message.
- **Keyboard.** Row click selects; the name link opens. `role="grid"`, one Tab stop, `aria-activedescendant`, so refresh never drops focus.
- **Loading and empty.** Skeleton on first load only. An empty state names its scope. The audit viewer opens on its criteria form.
- **Gating.** `aria-disabled` plus "Requires <resource>"; a 403 is an inline alert and on-screen data stays.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical; non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.4's table consumes `applyView`, `createScreenRead` and `truncated`, and serves every list. 2.5–2.9 declare the first production reads; 2.5 is the first over the wire. 2.10 runs the async LIST through `Execute` plus server criteria. 2.12 uses 2.11's `LogSourcePort`.
- **Built on Epic 1.** Registry, id encoder, gate, error envelope, auto-refresh, screen mirror, demo fixture, smoke script (now one live list per area).
- **Waiting on this epic.** Epic 4 dispatches read tools and supplies `contextCap` (not inside an output capture, which the vendor refuses to nest (inference)); Epic 5 finds writes through 2.10's marker filter and scopes error-log deletes by 2.12's namespace; Epic 6 builds on 2.11; write tools consume 2.2's field lists.
