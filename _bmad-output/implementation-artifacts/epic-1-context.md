# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — what is built here is extended, never replaced, by every later epic.

## Stories

- Stories 1.1–1.13 (done): workspace and response envelope · design system and string table · protected state, resource, role · one command brings up an installed instance · static shell and deep links · silent-first sign-in · sign-out · identity and version guard · descriptor registry and navigation · header, status bar, page chrome · the namespace switch as data scope · Home · uniform errors and the connectivity probe
- Story 1.14: The auto-refresh framework — next
- Story 1.15: Classic portal fallback links
- Story 1.16: The IPM module, from one roster
- Story 1.17: Smoke script, readiness, CI

## Requirements & Constraints

- **A third web application is still to come.** Readiness needs its own unauthenticated application under the API prefix, resolved by longest prefix, reporting only whether OcuPilot is installed, its version stamp, and whether install is still running — nothing that aids reconnaissance. Install creates and removes it like the other two, and must refuse to adopt an application at any of the three paths that it did not create, which needs a provenance record install does not yet have.
- **No read is unbounded.** Every read is capped by max rows and reports whether it truncated, and a screen's list, its read tool and its refresh tick all resolve through one descriptor-declared read rather than a second query.
- **Install stays one class, two entry points, idempotent.** Its class roster and the IPM manifest's resource list are generated from one source and cannot drift, proven by a test. The Docker path never uses IPM — the 2026.2 image ships none — an IPM install never unexpires `_SYSTEM`, and the namespace is chosen in installer code (`HSCUSTOM` if present, else `USER`), the manifest being evaluated only after it is fixed.
- **Contest floor:** pinned image tag, every library vendored with no runtime CDN reference, desktop Chrome, WCAG 2.1 AA with full keyboard operation. CI runs against a throwaway container and fails on any CDN reference or embedded Python in a shipped class.
- **Routed ledger items bind.** Stories 1.14, 1.16 and 1.17 carry `DW-n` bullets, each addressed in its story or declined with a written reason.

## Technical Decisions

- **Extend the singletons; never add a second:** one response writer and one error writer, one router and gate, one entity-id codec, one installer, one string source, one refresh timer. The error envelope is likewise closed — flat `{error, reason, code, detail}`, the screen rendering the human half and a tool the machine half.
- **The screen descriptor is the single source for a screen** — route, navigation, privilege gate, tools, change-event routing, and whether it refreshes and at what rates — so adding a screen never means editing a router, a nav list or a timer, and no screen implements refresh of its own.
- **A descriptor declares the classic *class name* it replaces, never a page URL**, because the portal keys custom page resources by normalized class name. Link-out is a list-versus-detail distinction declared there: a list never links out, a detail view may via `classicLinkExemption` with a reason, a list declaring one fails the check, and the check reports every exemption it honors rather than passing silently. Release 1 has exactly one.
- **A confirmed write publishes the scoped triple on one client-side bus**; a screen showing that entity type re-fetches in place and never patches its own rows. The proposal lifecycle will publish proposal-open and proposal-closed for a scoped entity type on that same bus — the channel the refresh pause rides on, built before there is anything to pause for.
- **A reference crossing a boundary is `(entity type, scope, id)`** — scope the namespace, or the literal `instance` where there is none. It is what a re-fetch routes on. Entity types come from one closed kernel enum; the build fails on an unknown value.
- **Namespace is data scope.** The route's `ns` selects what every read and write executes against, travels into change events and proposals, and switching it **re-fetches in place, never re-routes**.
- **Client:** a screen's data, sort, filter, selection, max rows and refresh setting live in a signal store owned by that screen and keyed by its descriptor, never a component field.

## UX & Interaction Patterns

- **Refresh is silent** — no spinner, skeleton or announcement; sort, filter, selection, scroll and max rows survive every tick, and rate, sort, filter and max rows persist per screen across leaving and returning. The command-bar chip is the control and the status-bar stamp the readout; neither is announced to assistive technology. Under reduced motion, transitions are instant.
- **The pause is visible:** while a proposal against the screen's entity type is live the chip says auto-refresh is paused, resuming on confirm, cancel or expiry, so the diff under review cannot move.
- **A reduced form ends with a card** titled "More in the classic portal", naming the page it opens, opening in a new tab, with a caption noting the classic portal may ask the user to sign in again. It never appears on a list screen. A reduced editor carries the daily-administration fields plus the link — never a half-working full form — and its agent write tool ships regardless.
- A hardcoded color or user-facing literal fails the build, both coming from the token layer and the one string source; copy no planning artifact publishes is escalated to the owner, never invented.

## Cross-Story Dependencies

- **1.1–1.13 are done and floor everything after.** The newest floor is one client failure taxonomy — `unreachable` / `not-installed` / `rejected` / `refused` / `absent` / `server-fault` — classified once, with a connectivity service owning the probe and its backoff and a single `role="alert"` banner. Consume it; do not add a second classifier. A refresh tick that meets a fault suspends rather than re-arms.
- **1.10's bands host what remains:** 1.14 drives the command bar's rate chip and the status bar's stamp; 1.15's link-out is a card at the foot of a reduced form, not a command-bar item.
- **1.14 routes its re-fetch on the reference triple** and subscribes to the proposal channel. It also owns the join-versus-queue defect: a navigation-map reload that joins a read already in flight leaves the map computed against the previous namespace, and the fix is mark-dirty-and-re-run-once — a second load races, and a naive queue loops.
- **Caution carried from 1.13, the same family of code.** Three times in that story a recovery path was cancelled by the very event meant to drive it — a parked re-send deleted by the next notification, a park whose only trigger was taken by the next verdict. Timers, in-flight reads and state arriving while a read is outstanding are 1.14's whole subject: check that every path which schedules a retry still has something left to fire it.
- **1.17** owns the install-provenance record, the definition of "step complete", the readiness endpoint and its application, the connectivity probe's missing timeout (an accepted-but-never-answered connection stalls the backoff chain indefinitely), and the browser-runtime test harness no UI surface has had since 1.5 — every shell assertion to date is jsdom, which computes no layout. The clean-clone run happens once, in Epic 17, but is the same script CI runs on every change. **1.16** generates its manifest from the `src/OcuPilot/` tree the start hook compiles.
- **Other epics.** Epic 2 builds out the admin-API port, which Epic 1 only asserts is present at version 2; Epic 12 removes the one classic-link exemption; Story 3.7 owns the single enforcement point for read-only and the kill switch, which nothing here may preclude.
