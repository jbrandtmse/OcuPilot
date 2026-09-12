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
- Story 1.11: The namespace switch as data scope — next
- Story 1.12: Home
- Story 1.13: Uniform errors and the connectivity probe
- Story 1.14: The auto-refresh framework
- Story 1.15: Classic portal fallback links
- Story 1.16: The IPM module, from one roster
- Story 1.17: Smoke script, readiness, CI

## Requirements & Constraints

- **A third web application is still to come.** Readiness (1.17) needs its own unauthenticated application under the API prefix, resolved by longest prefix, carrying the one purpose-built read-only matching role the shell carries — database READ is routine-execution permission. Install creates and removes it like the other two, and install-time tests assert every setting.
- **Nothing a user cannot open is hidden, and no read is unbounded** — every read is capped and reports whether it truncated, and a screen's list and its later read tool resolve through one descriptor-declared read.
- **Install runs at container start and finishes before traffic**, idempotent, refusing a stored schema newer than the code; the health check, healthy only on this start's install, is the readiness contract. It never adopts an application it did not create, picks `HSCUSTOM` else `USER` in installer code rather than a manifest, and never unexpires `_SYSTEM` on an IPM path. The Docker path never uses IPM: the 2026.2 image ships none.
- **Contest floor:** pinned image tag, every library vendored with no runtime CDN, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items bind.** Stories 1.11, 1.12, 1.13, 1.16 and 1.17 carry `DW-n` bullets, each addressed in its story or declined there with a written reason. 1.12 now carries six — accessibility, locator and shell items 1.10 pinned but did not fix, each needing copy no planning artifact publishes or a UX call.
- **Rendered DOM, ARIA state and focus movement are testable** on the client runner; CI itself arrives in 1.17. A live `%UnitTest` run executes as `_SYSTEM`, so a denial test needs a purpose-built role to contrast against `%All`.

## Technical Decisions

- **Extend the singletons; never add a second:** one response writer and one error writer, one router and gate, one entity-id codec, one installer, one escalation point for the protected globals, one string source, one refresh timer.
- **Error envelope:** flat `{error, reason, code, detail}` — closed-enum slug, human text, a stable dotted-uppercase `code` that is never a number. No slice adds a field; a vendor `%Status` becomes a slug and a written reason at the port boundary, its raw text kept for the log alone.
- **Privilege is the caller's**, checked at call time, never cached, with `UnknownUser` and `_PUBLIC` rejected. A requirement is a set of `(resource, permission)` pairs, never one resource, unioned with any custom resource on the classic page replaced; a denial names the failed pair.
- **Namespace is data scope, not decoration.** Routes are `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`; the route's namespace selects what every read and write executes against, travels into change events and proposals, and switching it **re-fetches in place, never re-routes**. Reaching `%SYS` is explicit save and restore, the restore first in every `Catch`.
- **A reference crossing a boundary is `(entity type, scope, id)`** — scope the namespace, or the literal `instance` where there is none, so a task of one name in two namespaces is two entities. The id rides one path segment through the shared codec: **encode-twice, decode-once**, run once per id, with `%2F` and `%00` never reaching IRIS. Entity types come from one closed kernel-owned enum.
- **The screen descriptor is the single source for a screen** — route, navigation, privilege gate, tools, change-event routing, and whether it refreshes and at what rates all resolve through it, so adding a screen never means editing a router, a nav list or a timer. A confirmed write publishes the scoped triple on one client-side bus; screens re-fetch in place and never patch their own rows.
- **A descriptor declares the classic *class name* it replaces, never a page URL** — the portal keys custom page resources by normalized class name. Link-out is a list-versus-detail distinction in that descriptor: a list never links out, a detail view may via `classicLinkExemption` with a reason, and the check reports every exemption it honors.
- **A reference to an IRIS object OcuPilot does not own is weak** — scoped identity as data, never a foreign key, rendering as "no longer present" rather than failing the screen.
- **Client:** screen state lives in a store keyed by its descriptor, never a component field, and screens communicate only through the change-event bus and the router. Every API path is absolute — the deep-link fallback would answer a relative one with `index.html`.

## UX & Interaction Patterns

- Colors come from tokens and user-facing strings from the one string source; a literal of either kind fails the build. Teal is the only action color, yellow the agent and never a control; "co-pilot" never appears alone.
- **The shell never overlays and never scrolls horizontally** — under pressure the side bar collapses first, the panel shrinks next, content scrolls inside itself; Home's tiles wrap.
- **Gated controls stay reachable:** `aria-disabled="true"`, never `disabled`, never hidden, naming the required resource in a tooltip on hover and focus, inline after the label in the side bar and command box, and inside the accessible name in menus and result lists, where key managers skip disabled items and no tooltip can show.
- **Failures are distinguished, not generalized:** 401 refreshes and retries invisibly, a background concern of the API service that no screen handles; 403 renders inline with `role="alert"` naming the privilege, the data on screen kept; an unexplained failure runs a connectivity probe separating an unreachable instance from a refused request; a 5xx is generic in the browser, logged in full with secrets redacted.
- **Refresh is silent** — no spinner, skeleton or announcement; sort, filter, selection, scroll and max rows survive it, and neither the rate chip nor the stamp is announced. Under reduced motion, transitions are instant and spinners become the word "running".

## Cross-Story Dependencies

- **1.1–1.10 are done and floor everything after**, through 1.9's descriptor registry, privilege gate, rail and side bar, and 1.10's shell frame — header with lockup, status bar (server flag, instance, licensed-to, host), locator bar, command bar, command box and an overlay stack, the identity call now also returning `serverFlag`, `licensedTo` and `serverName`.
- **1.10's bands are where the rest lands:** the header's namespace slot becomes 1.11's switch; 1.12's instance line reads the extended identity fields; 1.13's probe verdict lands in the status bar's connection segment; 1.14 drives the rate chip and the stamp; 1.15's link-out sits in the command bar; Epic 5's panel registers on the overlay stack.
- **1.11 is next.** A `?ns=` selection already survives the rail, side bar, locator, command box and lockup, so 1.11 wires a control into an existing band: the list restricted to namespaces the user can read *and* write, the selection re-fetching the current screen in place.
- **Only Home carries a real screen descriptor** — the other seven rail areas are declared with no screens, so they list in the rail and do not navigate. 1.12 builds Home's page; later epics add screens by adding descriptors.
- **1.11 precedes 1.14:** the reference triple must exist before a re-fetch can be routed, and 1.14 subscribes to the proposal-open and proposal-closed channel before there is anything to pause for. **1.13 owns the retry** for an identity call failing as neither a privilege denial nor install-in-flight, which today leaves a signed-in tab on a blank content area.
- **1.17** owns the install-provenance record behind install's refusal to adopt an application it did not create, and the definition of "step complete"; the clean-clone smoke run happens once, in Epic 17. **1.16** generates its manifest from the `src/OcuPilot/` tree the start hook compiles.
- **Other epics.** Epic 2 builds out the admin-API port — Epic 1 only asserts its presence at version 2 — and owns the registry's per-call descriptor re-parse, so a story adding a descriptor should not work around it locally. Story 3.7 owns the one enforcement point for read-only and the kill switch, which nothing here may preclude.
