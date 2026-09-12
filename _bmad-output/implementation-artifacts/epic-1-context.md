# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — what is built here is extended, never replaced, by every later epic.

## Stories

- Story 1.1: Workspace and response envelope (done)
- Story 1.2: Design system and string table (done)
- Story 1.3: Protected state, resource, role (done)
- Story 1.4: One command brings up an installed instance (done)
- Story 1.5: Static shell and deep links (done)
- Story 1.6: Silent-first sign-in (done)
- Story 1.7: Sign-out (done)
- Story 1.8: Identity and version guard (done)
- Story 1.9: Descriptor registry and navigation (done)
- Story 1.10: Header, status bar, page chrome (done)
- Story 1.11: The namespace switch as data scope (done)
- Story 1.12: Home (done)
- Story 1.13: Uniform errors and the connectivity probe — next
- Story 1.14: The auto-refresh framework
- Story 1.15: Classic portal fallback links
- Story 1.16: The IPM module, from one roster
- Story 1.17: Smoke script, readiness, CI

## Requirements & Constraints

- **A third web application is still to come.** Readiness (1.17) needs its own unauthenticated application under the API prefix, resolved by longest prefix, with a purpose-built read-only role. Install creates and removes it like the other two, asserting every setting.
- **No read is unbounded** — every read is capped and reports whether it truncated, and a screen's list and its later read tool resolve through one descriptor-declared read.
- **Install runs at container start and finishes before traffic**, idempotent, refusing a stored schema newer than the code; the health check, healthy only on this start's install, is the readiness contract. It never adopts an application it did not create, picks `HSCUSTOM` else `USER` in installer code, and never unexpires `_SYSTEM` on an IPM path. The Docker path never uses IPM: the 2026.2 image ships none.
- **Contest floor:** pinned image tag, every library vendored with no runtime CDN, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items bind.** Stories 1.13, 1.16 and 1.17 carry `DW-n` bullets, each addressed in its story or declined with a written reason.
- **Rendered DOM, ARIA state and focus movement are testable** on the client runner. A live `%UnitTest` run executes as `_SYSTEM`, so a denial test needs a purpose-built role to contrast against `%All`.

## Technical Decisions

- **Extend the singletons; never add a second:** one response writer and one error writer, one router and gate, one entity-id codec, one installer, one escalation point, one string source, one refresh timer.
- **Error envelope:** flat `{error, reason, code, detail}` — closed-enum slug, human text, a stable dotted-uppercase `code` that is never a number. The screen renders the human half, a tool the machine half, and no slice adds a field. A vendor `%Status` becomes a slug and a written reason at the port boundary, its raw text kept for the log and the ledger alone.
- **Privilege is the caller's**, checked at call time, never cached, with `UnknownUser` and `_PUBLIC` rejected. A requirement is a set of `(resource, permission)` pairs, unioned with any custom resource on the classic page replaced, and a denial names the failed pair. The server stays the gate; a client-side verdict is presentation, never authorization.
- **Namespace is data scope.** The route's `ns` selects what every read and write executes against, travels into change events and proposals, and switching it **re-fetches in place, never re-routes**. Handlers read the once-resolved scope from the kernel seam, not `$NAMESPACE`; `%SYS` is explicit save and restore, the restore first in every `Catch`.
- **A reference crossing a boundary is `(entity type, scope, id)`** — scope the namespace, or the literal `instance` where there is none, and a descriptor's declared scope is one of those two values only. It is what a re-fetch routes on. A reference to an IRIS object OcuPilot does not own is **weak**: scoped identity as data, never a foreign key, rendering as "no longer present" rather than failing the screen.
- **The screen descriptor is the single source for a screen** — route, navigation, privilege gate, tools, change-event routing, and whether it refreshes and at what rates, so adding a screen never means editing a router, a nav list or a timer. Descriptor names reach the client through a generated mirror, not the runtime navigation payload, so a new descriptor must be regenerated before its name appears. A confirmed write publishes the scoped triple on one client-side bus; screens re-fetch in place and never patch their own rows.
- **A descriptor declares the classic *class name* it replaces, never a page URL**, because the portal keys custom page resources by normalized class name. Link-out is a list-versus-detail distinction there: a list never links out, a detail view may via `classicLinkExemption` with a reason, and the check reports every exemption it honors.
- **Client:** screen state lives in a store keyed by its descriptor, never a component field. Every API path is absolute — the deep-link fallback would answer a relative one with `index.html`.

## UX & Interaction Patterns

- A hardcoded color or user-facing literal fails the build — both come from the token layer and the one string source, and copy a story needs that no planning artifact publishes is escalated to the owner, never invented. Teal is the only action color, yellow the agent's; "co-pilot" never appears alone.
- **Gated controls stay reachable:** `aria-disabled="true"`, never `disabled`, never hidden, naming the required resource in a tooltip on hover and focus, and inside the accessible name in menus and result lists, where key managers skip disabled items.
- **Failures are distinguished, not generalized:** 401 refreshes and retries invisibly, a background concern of the API service that no screen handles; 403 renders inline with `role="alert"` naming the privilege, the data on screen kept; an unexplained failure runs a connectivity probe separating an unreachable instance — one alert banner with Retry, and the status bar saying so — from a refused request; a 5xx is generic in the browser with Retry and a link to messages.log, logged in full with secrets redacted.
- **Refresh is silent** — no spinner, skeleton or announcement; sort, filter, selection, scroll and max rows survive it, and neither the rate chip nor the stamp is announced. Under reduced motion, transitions are instant and spinners become the word "running".

## Cross-Story Dependencies

- **1.1–1.12 are done and floor everything after**, from the envelope and router through install, the static shell, sign-in, the identity guard, the descriptor registry and privilege gate, the chrome and namespace scope, ending at Home — the first tenant of `areas/`, reached through an archetype-to-component map, so Epic 2 adds screens by declaring descriptors rather than editing a router.
- **1.10's bands are where the rest lands:** 1.13's probe verdict belongs in the status bar's connection segment, which today reads Connected whenever the session is signed in; 1.14 drives the rate chip and the stamp; 1.15's link-out sits in the command bar; Epic 4's panel owns Home's widening and its remembered width.
- **1.13 is next, and carries the epic's error-handling residue** — six routed items, all about what a user sees when something fails: a detail route for an entity that no longer exists; a form submit meeting an unreachable instance, discarded silently for want of a string; the password-expired branch, unreachable and unimplemented; an identity call classified as neither a privilege denial nor install-in-flight, leaving a signed-in tab blank with nothing scheduled to ask again; a failed navigation-map read indistinguishable from an un-privileged one and equally unretried; and a tile or locator segment that opens an area's first built screen without consulting that screen's verdict, landing an allowed-area user on a refusal page.
- **1.14 routes its re-fetch on the reference triple**, and subscribes to the proposal-open and proposal-closed channel before there is anything to pause for.
- **1.17** owns the install-provenance record behind install's refusal to adopt an application it did not create, the definition of "step complete", and the browser-runtime test harness no UI surface has had since 1.5; the clean-clone smoke run happens once, in Epic 17. **1.16** generates its manifest from the `src/OcuPilot/` tree the start hook compiles.
- **Other epics.** Epic 2 builds out the admin-API port — Epic 1 only asserts its presence at version 2 — and owns the registry's per-call descriptor re-parse. Story 3.7 owns the one enforcement point for read-only and the kill switch, which nothing here may preclude.
