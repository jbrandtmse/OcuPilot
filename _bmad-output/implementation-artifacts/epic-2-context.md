# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real data from its instance: Web applications, Users, SSL/TLS, Task schedule, Processes, and in Logs the audit database viewer and application error drill-down, plus a bounded messages.log endpoint. Every list is backed by one descriptor-declared read that the agent's read tool shares, and every admin-API call goes through one port. This is build step 1: once it passes the smoke script, the listing build can be submitted.

## Stories

- Story 2.0: Epic 1 Deferred Cleanup (done)
- Story 2.1: The AdminPort reproduces the vendor's dispatcher, exactly once (done)
- Story 2.2: Write-tool field lists are derived at build time and pinned in CI
- Story 2.3: One descriptor-declared read serves both the screen and its read tool
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

- **Performance and bounds.** First page within 2 s at 1,000 rows. Every read is capped by max rows (default 1,000, editable, persisted per screen with sort and filter) and reports truncation. Cursor paging only where the route offers one; no page-size control.
- **One read, two consumers.** Screen and read tool resolve through one declaration, so filter, sort and field set cannot diverge; the tool's view is narrowed by the context cap and stripped of secret-typed fields.
- **Read tools.** Registered from the descriptor with no tool code, named `<area>.<screen>.read` (no `iris_` prefix), declaring `read`; a tool declaring neither `read` nor `write` fails the build. Not dispatchable until Epic 4.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked at call time, never cached; a denial names the failing pair. A descriptor declares the classic page class it replaces, so an operator's custom resource on it still applies. A denied screen is never an empty state.
- **Navigation.** A list never links out to the classic portal; an unbuilt screen has no side-bar entry. Ids go through the shared one-segment encoder, so `/csp/myapp` and `_SYSTEM` round-trip.
- **Secrets and state.** No private key material in any SSL/TLS read. Disabled or expired reads as a word, never by color alone.
- **Demo rows** on a fresh container: `/csp/myapp` disabled with no resource, a demo SSL/TLS configuration, a task suspended after an error.
- **Logs.**
  - No endpoint accepts a filesystem path: a fixed source enum, directory `$System.Util.ManagerDirectory()` resolved per call. messages.log pages survive rotation. `LogSourcePort` checks its resource with `$System.Security.Check` before any access.
  - The audit viewer never hides OcuPilot's own events; the marker filter is not a default. Its privilege set must require both `%Admin_Secure` (audit LIST) and `%Admin_Operate` (the async poll), or the port must forget a task whose poll is refused; otherwise a caller with only the first leaves a queued task row behind.
  - The error log reads only through `SYS.ApplicationError`; its namespace comes only from the drill level, and its variable table never reaches screen context or the model.

## Technical Decisions

- **AdminPort (delivered).** `OcuPilot.Port.AdminPort.Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault) As %Status` is the only way to call an admin endpoint, and `AdminPort.cls` is the only file naming `%Api.Admin`, including XData and `scripts/*.sh` (checked by `check-objectscript.py`).
  - Callers name the endpoint package-relative (`WebApp.App`) and the type as `GET`, `LIST` or `INFO`; never a vendor class or type number. Query parameters (including `maxRows`) go in `pQuery`.
  - It verifies the instance on every call and runs the vendor's `Main()` order in `%SYS` behind its own `%request`/`%response`/`%session` stubs; the caller's CSP objects and namespace are untouched.
  - Success is exactly an OK status with a 2xx HTTP status. Anything else returns an error status and a `{error, reason, code}` fault from `Kernel.Fault.Outcome` (HTTP status mapped first); vendor text goes only to the log.
  - Fault codes: `PORT.ACCESSDENIED` 403, `PORT.NOTFOUND` 404, `PORT.CONFLICT` 409, `PORT.VALIDATION` 400/422, `PORT.NOTIMPLEMENTED` 501 (unknown endpoint or suffix, or a read type the endpoint does not implement), `PORT.UNAVAILABLE` and `PORT.TIMEOUT` 503. An unmapped failure is 500 `INTERNAL`.
  - A vendor-gate 403 names no privilege; the descriptor gate names the failing pair. Under `%All` every check passes, so testing a denial needs a real denied principal.
  - Not safe to call inside an active `%SYS.Capture` with buffered output: the vendor refuses a nested capture, so it fails 500 (inference).
- **Async is one path with two entries** (`ShouldRunAsync()` hand-off, or a `Run()` that self-queues and answers 202). The port polls `AsyncResult` to `Finished` or `Failed`, deletes the finished row, and times out with `PORT.TIMEOUT` (30 s), leaving the row. Slices see an ordinary call and write no polling logic. The audit record LIST (2.10) is self-queued; the other Release 1 async call is database directory info.
- **Derived write schemas.** Field lists and JSON types are generated from the instance as committed, reviewed source, never at runtime. An unclassifiable field is secret. A CI inventory fixture (classes, templates, both async entries, CSP-touching classes) fails the build when the instance moves.
- **Descriptors.** One declarative class each under `Screen/Descriptor/`, mirrored by `screen-mirror.mjs`; archetype and entity-type key fail closed. Adding a screen never edits a router, nav list or tool registry.
- **Client.** Zoneless, `OnPush`; each screen is `<screen>.page.ts`, `.store.ts` (framework-free, mirrored into signals) and `.descriptor.ts` under `ui/src/app/areas/<area>/`. One API service; design tokens only.
- **Auto-refresh** (Task schedule, Processes) uses the shared framework: a silent re-fetch through the same read, preserving sort, filter, selection and scroll.
- **Tests.** Every handler gets an HTTP integration test and every tool a schema round-trip test; one test class at a time.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll over the capped fetch: identifiers in `code`, numbers tabular and right-aligned, status a disc plus a word, empty values "(none)", footer with row count and a labeled max-rows field.
- **Selection and keyboard.** A row click selects; the name cell is a link that opens. `role="grid"`, one Tab stop, `aria-activedescendant` so refresh never drops focus.
- **Loading and empty.** Skeleton on first load only, never on re-fetch. An empty state names its scope in one sentence. The audit viewer opens on its criteria form and shows a skeleton only after Search.
- **Gating.** A gated control uses `aria-disabled` and names "Requires <resource>". A 403 is an inline alert and data already on screen stays.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical; a new string gets a row there. Non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.1's port is in place; 2.3 (shared read) is its first consumer and underpins every list in 2.5–2.10, and 2.4's table serves all of them. 2.5 is the first HTTP consumer and the first real denied principal. 2.10 uses the port's self-queued async path. 2.12 uses 2.11's `LogSourcePort`. 2.2's inventory fixture must record both async entries.
- **Built on Epic 1.** Descriptor registry, archetype and entity-type vocabularies, id encoder, gate, error envelope, auto-refresh, screen mirror, demo fixture, and the smoke script, which must now pass one live list per area.
- **Waiting on this epic.** Epic 4 dispatches the read tools (and must not call the port inside an output capture); Epic 5 finds its first writes through 2.10's marker filter and scopes its error-log delete by 2.12's namespace source; Epic 6 builds on 2.11; write tools consume 2.2's field lists.
