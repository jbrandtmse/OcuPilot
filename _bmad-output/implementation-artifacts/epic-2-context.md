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
- **Read tools.** Registered from the descriptor with no tool code, named `<area>.<screen>.read`, declaring `read`; a tool declaring neither `read` nor `write` fails the build. Not dispatchable until Epic 4.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all required, checked at call time, never cached; a denial names the failing pair. A descriptor declares the classic page class it replaces, so an operator's custom resource on it still applies. A denied screen is never an empty state.
- **Navigation.** A list never links out to the classic portal; an unbuilt screen has no side-bar entry. Ids go through the shared one-segment encoder, so `/csp/myapp` and `_SYSTEM` round-trip.
- **Secrets and state.** No private key material in any SSL/TLS read. Disabled or expired reads as a word, never by color alone.
- **Demo rows** on a fresh container: `/csp/myapp` disabled with no resource, a demo SSL/TLS configuration, a task suspended after an error.
- **Logs.**
  - No endpoint accepts a filesystem path: a fixed source enum, directory `$System.Util.ManagerDirectory()` resolved per call. messages.log pages survive rotation. `LogSourcePort` checks its resource with `$System.Security.Check` before any access.
  - The audit viewer never hides OcuPilot's own events; the marker filter is not a default. Its privilege set requires `%Admin_Secure` (audit LIST) and `%Admin_Operate` (the async poll), unless the port forgets a task whose poll is refused; otherwise a caller with only the first leaves a queued task row.
  - The error log reads only through `SYS.ApplicationError`; its namespace comes only from the drill level, and its variable table never reaches screen context or the model.

## Technical Decisions

- **AdminPort (delivered).** `OcuPilot.Port.AdminPort.Invoke` is the only way to call an admin endpoint, and `AdminPort.cls` is the only file naming `%Api.Admin`, including XData and `scripts/*.sh` (checked by `check-objectscript.py`).
  - Callers name the endpoint package-relative (`WebApp.App`) and the type as `GET`, `LIST` or `INFO`, never a vendor class or type number; query parameters (including `maxRows`) go in `pQuery`.
  - Success is exactly an OK status with a 2xx HTTP status; anything else returns an error status and a `{error, reason, code}` fault (`PORT.*`, HTTP status mapped first). Vendor text goes only to the log.
  - A vendor-gate 403 names no privilege; the descriptor gate names the failing pair. Under `%All` every check passes, so testing a denial needs a real denied principal.
- **Async is one path with two entries** (`ShouldRunAsync()` hand-off, or a `Run()` that self-queues and answers 202). The port polls `AsyncResult` to a terminal state, deletes the finished row, and times out with `PORT.TIMEOUT` (30 s). Slices write no polling logic. Release 1's async calls: the audit record LIST (self-queued) and database directory info.
- **Derived write schemas.** A build step reads the instance and emits committed, reviewed source; nothing derives at runtime.
  - Derivation reads the body-template methods only (`RequestBodySchema`, `PutRequestBodySchema`, `PutAndPostSchema`, `Schema`, first found). Field list and JSON shape (scalar, object, array) are contract; the placeholder's scalar type is information only (`WebApp.App`'s GET returns numbers where its template shows `""`). `required`, `enum` and `description` are authored once per tool.
  - Each derived field gets a reviewed per-tool entry: `ordinary`, `secret`, or `opaque` (an object or array the template does not describe member by member). No entry emits secret. A string-placeholder field matching the case-insensitive suffix `(password|passwd|pwd|secret|apikey|privatekey|token)$` and not classified secret fails the build (a boolean such as `ChangePassword` is not a credential). The descriptor's classification drives confirm and ledger redaction; the name pattern is only a backstop. Credentials built outside a template (`Security.User`'s POST `Password`, change-password `NewPassword`) never enter a derived list; the write tool authors them as secret.
  - Mutating means the class itself defines `RunPut`, `RunPost`, `RunDelete` or `RunPatch`; 16 such endpoints have no template. In Release 1, `Wallet.Secret` gets one list per `Type` (`%Wallet.KeyValue`, `%Wallet.RSA`, `%Wallet.SymmetricKey`) and `Security.Audit.Event` derives from `Security.Events`, each pinned by a test; `Process`, `Lock` and `Task.Manager` need none.
  - A CI inventory fixture (classes, templates, both async entries, CSP-touching classes) fails the build when the instance moves.
- **Descriptors.** One declarative class each under `Screen/Descriptor/`; adding a screen never edits a router, nav list or tool registry.
- **Client.** Each screen is `<screen>.page.ts`, a framework-free `.store.ts` and `.descriptor.ts` under `ui/src/app/areas/<area>/`; one API service, design tokens only.
- **Auto-refresh** (Task schedule, Processes) uses the shared framework: a silent re-fetch through the same read, preserving sort, filter, selection and scroll.
- **Tests.** Every handler gets an HTTP integration test and every tool a schema round-trip test.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll over the capped fetch: identifiers in `code`, numbers tabular and right-aligned, status a disc plus a word, empty values "(none)", footer with row count and a labeled max-rows field.
- **Selection and keyboard.** A row click selects; the name cell is a link that opens. `role="grid"`, one Tab stop, `aria-activedescendant` so refresh never drops focus.
- **Loading and empty.** Skeleton on first load only, never on re-fetch. An empty state names its scope in one sentence. The audit viewer opens on its criteria form and shows a skeleton only after Search.
- **Gating.** A gated control uses `aria-disabled` and names "Requires <resource>". A 403 is an inline alert and data already on screen stays.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical; a new string gets a row there. Non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.1's port is in place; 2.3 (shared read) is its first consumer and underpins every list in 2.5–2.10, and 2.4's table serves all of them. 2.5 is the first HTTP consumer and the first real denied principal. 2.10 uses the port's self-queued async path. 2.12 uses 2.11's `LogSourcePort`.
- **Built on Epic 1.** Descriptor registry, id encoder, gate, error envelope, auto-refresh, screen mirror, demo fixture, and the smoke script, which must now pass one live list per area.
- **Waiting on this epic.** Epic 4 dispatches the read tools (and must not call the port inside an output capture, since the vendor refuses a nested capture (inference)); Epic 5 finds its first writes through 2.10's marker filter and scopes its error-log delete by 2.12's namespace source; Epic 6 builds on 2.11; write tools consume 2.2's field lists.
