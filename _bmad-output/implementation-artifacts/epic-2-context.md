# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real data from its instance: Web applications, Users, SSL/TLS, Task schedule, Processes, and in Logs the audit database viewer and application error drill-down, plus a bounded messages.log endpoint. Every list is backed by one descriptor-declared read that the agent's read tool shares, and every admin-API call goes through one port that reproduces the vendor's dispatcher. This is build step 1: once it passes the smoke script, the listing build can be submitted. Story 2.0 first closes the Epic 1 defects under this work.

## Stories

- Story 2.0: Epic 1 Deferred Cleanup
- Story 2.1: The AdminPort reproduces the vendor's dispatcher, exactly once
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
  - The audit viewer never hides OcuPilot's own events; the marker filter is not a default.
  - The error log reads only through `SYS.ApplicationError`; its namespace comes only from the drill level, and its variable table never reaches screen context or the model.

## Technical Decisions

- **AdminPort** (`Port/AdminPort`) is the only code naming an `%Api.Admin.*` class, asserted by an automated check. Epic 1 built its v2-and-probe startup verification; this epic adds the dispatch sequence, which follows the vendor's `Main()` order:
  1. Enter `%SYS` by explicit save and restore; construct the endpoint with `%New(type, 2)`.
  2. Stub `%request`, `%response` and `%session` (carrying `Username`, which the async queue records and checks), with `IsRunningAsync = 0` or every status the endpoint sets is discarded.
  3. Gate first: `ResourcesOR()` through `$System.Security.Check(res, "U")`, refusing on failure.
  4. Seed query parameters into `%request.Data`, then `SaveQueryParams()`, then `ValidateQueryParams()`. Seeding by `SaveOneQueryParam()` alone is not enough (`maxRows` is ignored); skipping validation leaves the identifying property empty and fails with an error that does not name the cause.
  5. `ValidateRequest(body)` then `ValidateSemantics()`; wrap `Run()` in `BeginCaptureOutput`/`EndCaptureOutput`; map `<PROTECT>` to 403.
  6. Read the outcome from both `tSC` and `%response.Status`: a non-2xx status is a failure even when `tSC` is OK, never an empty success.
- **Async is one path with two entries.** Either `ShouldRunAsync()` is true for the request type and the port hands off through `AsyncTaskEndpoint`, or the endpoint's own `Run()` queues its task and answers 202 with an `async-result` location. Both converge on one poll through the `AsyncResult` endpoint, a bounded wait that fails with `PORT.TIMEOUT`, never a partial result; slices see an ordinary call and write no polling logic. The audit record LIST (2.10) is self-queued (`ShouldRunAsync()` reads 0); the other Release 1 async call is database directory info. The stub request supplies the synthetic label self-queuing classes take from `GetName(%request)`.
- **Errors.** Vendor text is mapped at the port to OcuPilot's flat `{error, reason, code, detail}` envelope; the raw text goes to the log and ledger only.
- **Derived write schemas.** Field lists and JSON types are generated from the instance as committed, reviewed source, never at runtime. An unclassifiable field is secret. A CI inventory fixture (classes, templates, both async entries, CSP-touching classes) fails the build when the instance moves.
- **Tool registry** is harvested from iris-session-agent with `%IsA` in place of flat `Super` equality and a schema-driven argument validator.
- **Descriptors.** One declarative class each under `Screen/Descriptor/`, mirrored by `screen-mirror.mjs`; archetype and entity-type key fail closed. Adding a screen never edits a router, nav list or tool registry.
- **Client.** Zoneless, `OnPush`; screen state in a framework-free store under `core/` mirrored into signals. Each screen is `<screen>.page.ts`, `.store.ts`, `.descriptor.ts` under `ui/src/app/areas/<area>/`. One API service; design tokens only.
- **Auto-refresh** (Task schedule, Processes) uses the shared framework: a silent re-fetch through the same read, preserving sort, filter, selection and scroll.
- **ObjectScript.** `%SYS` by explicit save and restore with the restore first in every `Catch`, never `New $NAMESPACE`. All SQL binds caller values. Every handler gets an HTTP integration test and every tool a schema round-trip test. One test class at a time.

## UX & Interaction Patterns

- **One data table** on CDK virtual scroll over the capped fetch: identifiers in `code`, numbers tabular and right-aligned, status a disc plus a word, empty values "(none)", footer with row count and a labeled max-rows field.
- **Selection and keyboard.** A row click selects; the name cell is a link that opens. `role="grid"`, one Tab stop, `aria-activedescendant` so refresh never drops focus.
- **Loading and empty.** Skeleton on first load only, never on re-fetch. An empty state names its scope in one sentence. The audit viewer opens on its criteria form and shows a skeleton only after Search.
- **Gating.** A gated control uses `aria-disabled` and names "Requires <resource>". A 403 is an inline alert and data already on screen stays. Skip to content is the first Tab stop.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical; a new string gets a row there. Non-ASCII as `\uXXXX`.

## Cross-Story Dependencies

- **Order.** 2.0 lands first and takes only its eight ledger items. 2.1 (port) and 2.3 (shared read) underpin every list in 2.5–2.10, and 2.4's table serves all of them. 2.10 needs 2.1's async path; 2.12 uses 2.11's `LogSourcePort`. 2.2's inventory fixture must record 2.1's two async entries.
- **Built on Epic 1.** Descriptor registry, archetype and entity-type vocabularies, id encoder, gate, error envelope, auto-refresh, screen mirror, demo fixture, and the smoke script, which must now pass one live list per area.
- **Waiting on this epic.** Epic 4 dispatches the read tools; Epic 5 finds its first writes through 2.10's marker filter and scopes its error-log delete by 2.12's namespace source; Epic 6 builds on 2.11; write tools consume 2.2's field lists.
