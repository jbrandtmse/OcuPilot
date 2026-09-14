# Epic 2 Context: Every area shows live instance data

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Each of the six areas shows real data from the instance it runs on. The step-1 lists are Web applications, Users, SSL/TLS, Task schedule, Processes, and in Logs both the audit database viewer and the application error drill-down, plus a bounded messages.log endpoint. Every list is backed by exactly one descriptor-declared read that the agent's read tool shares, and every admin-API call goes through one port that reproduces the vendor's dispatcher faithfully. A list's first page renders within two seconds at a thousand rows, and sort and filter survive refresh. This is build step 1: once its build passes the smoke script, the listing build can be submitted. Story 2.0 runs first. It closes the Epic 1 defects that sit directly under this work, so descriptors added in bulk land on tooling that reports its own failures.

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

- **Performance.** A list's first page renders within 2 s on a Community container holding 1,000 rows.
- **Bounded reads.** Every read is capped by max rows and reports whether it truncated. The cap defaults to 1,000, is editable, and is persisted per screen with sort and filter. Page by cursor only where the backing route offers one. There is no page-size control and no infinite scroll.
- **One read, two consumers.** A screen's list and its read tool resolve through one declaration, so filter, sort and field set cannot diverge. The tool's view is the screen's view narrowed by the context cap (200 rows by default, also bounded by total size and per field) and stripped of secret-typed fields. It never runs free-form SQL.
- **Read tools.** Each is registered from its descriptor with no hand-written tool code. It is named `<area>.<screen>.read` (lower case, dots, no `iris_` prefix) and declares `read`; a tool declaring neither `read` nor `write` fails the build. These tools are not dispatchable until Epic 4, and nothing here may wait on that.
- **Privilege.** A gate is a set of `(resource, permission)` pairs, all of them required, checked at call time and never cached. A denial names the pair that failed. A descriptor declares the classic page class it replaces, and the gate adds any custom resource an operator assigned to that page. A permission-denied or refused screen is never rendered as an empty state.
- **Navigation.** A list archetype never links out to the classic portal, and an unbuilt screen has no side-bar entry. Ids go through the shared one-segment encoder, so `/csp/myapp` and `_SYSTEM` round-trip.
- **Secrets and state.** No private key material appears in any SSL/TLS read. A state such as disabled or expired is readable as a word, never by color alone.
- **Demo rows.** The opt-in compose fixture's rows must appear on a fresh container: `/csp/myapp` disabled with no resource, a demo SSL/TLS configuration, and a task suspended after an error.
- **Logs.**
  - No endpoint accepts a filesystem path. The source is a fixed enum, and the directory is `$System.Util.ManagerDirectory()`, resolved on every call.
  - messages.log is served in bounded pages and survives rotation.
  - A port with no vendor gate checks its declared resource with `$System.Security.Check` before any access.
  - The audit viewer never hides OcuPilot's own events; the agent-marker filter is not a default.
  - The application error log reads only through `SYS.ApplicationError`. Its namespace comes only from the drill level, and its variable-table detail never reaches screen context or the model.

## Technical Decisions

- **AdminPort** (`Port/AdminPort`) is the only code naming an `%Api.Admin.*` class, and an automated check asserts it. Epic 1 built its version-and-probe verification; this epic adds the full vendor dispatch sequence. Every screen read inherits these rules:
  - Stub `%request` and `%response` with `IsRunningAsync = 0`, or statuses are discarded.
  - Call `ValidateQueryParams()` before `Run`.
  - Capture output.
  - Treat a non-2xx `%response.Status` as a failure even when `tSC` is OK. A failure never arrives as an empty success.
- **Async and errors.** `ShouldRunAsync()` is evaluated per request type. The port polls internally, so a slice never writes polling logic; the audit record LIST is this epic's async path. Vendor error text is normalized at the port to OcuPilot's flat `{error, reason, code, detail}` envelope, and the raw text goes to the log only.
- **Derived write schemas.** Field lists and JSON types are generated from the running instance as committed, reviewed source, never derived at runtime. A field that cannot be classified is secret. A CI inventory fixture fails the build when the instance moves.
- **Tool registry.** It is harvested from iris-session-agent. It takes `%IsA` or a recursive walk in place of flat `Super` equality, gains a schema-driven argument validator, and keeps no sibling names.
- **Descriptors.** Each is one hand-written declarative class under `Screen/Descriptor/`, mirrored to the client by `screen-mirror.mjs`. The archetype comes from a closed vocabulary and the entity-type key from the kernel's closed enum; both fail closed. Adding a screen never edits a router, nav list or tool registry.
- **Client.** Zoneless and `OnPush`. Screen state lives in a framework-free store under `core/`, keyed by descriptor and mirrored into signals, never in component fields. Each screen is `<screen>.page.ts`, `.store.ts` and `.descriptor.ts` under `ui/src/app/areas/<area>/`. API paths are absolute and go through the one API service. Only design tokens are used.
- **Auto-refresh.** One shared framework serves the screens whose descriptors declare it; in this epic those are Task schedule and Processes. It re-fetches silently through the same read, preserving sort, filter, selection and scroll.
- **ObjectScript.**
  - `%SYS` is entered by explicit save and restore, with the restore first in every `Catch` and never `New $NAMESPACE`.
  - All SQL binds caller values.
  - Every handler gets an HTTP integration test covering status, content type and body shape, and every tool gets a schema round-trip test.
  - Run one test class at a time.

## UX & Interaction Patterns

- **One data table.** Every list uses one table built on CDK virtual scroll over the capped fetch.
  - Identifiers are set in `code`, and numbers are tabular and right-aligned.
  - Status is a disc plus a word, and an empty value reads "(none)".
  - The footer holds the row count and a labeled max-rows field.
- **Selection and keyboard.** A click on the row selects it; the name cell is a visible link that opens the entity. The grid is `role="grid"` and one Tab stop, with `aria-activedescendant` so neither refresh nor virtual scroll drops focus.
- **Loading and empty states.** The skeleton appears on first load only, never on a re-fetch. An empty state names its scope in one sentence.
- **Server-criteria lists.** The audit viewer opens on its criteria form and shows a skeleton only after Search.
- **Gating.** A gated control uses `aria-disabled` and names "Requires <resource>". A 403 is an inline alert, and data already on screen stays. Skip to content is the first Tab stop.
- **Strings.** EXPERIENCE.md's Fixed strings table is canonical. A new string gets a row there and is never invented in a component. Non-ASCII is written as `\uXXXX`.

## Cross-Story Dependencies

- **Story order.**
  - 2.0 lands first and takes only its eight ledger items; items routed to later stories stay there.
  - 2.1 (port) and 2.3 (the shared read) underpin every list in 2.5–2.10, and 2.4's table serves all of them.
  - 2.10 needs 2.1's async path, and 2.12 uses the `LogSourcePort` from 2.11.
- **Built on Epic 1.** Descriptor base and registry, archetype vocabulary, entity-type enum and id encoder, gate, error envelope, auto-refresh framework, namespace scope, screen mirror, demo fixture, and the smoke script, which must now pass one live list per area.
- **Waiting on this epic.**
  - Epic 4 makes the read tools dispatchable.
  - Epic 5's first confirmed writes are found through 2.10's marker filter, and its error-log delete uses 2.12's single namespace source.
  - Epic 6 builds the messages.log viewer on 2.11.
  - Write tools consume 2.2's derived field lists, and Epic 9 builds the full editors behind these lists.
