# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — what is built here is extended, never replaced, by every later epic.

## Stories

- Stories 1.1–1.14 (done): the workspace and response envelope, design system and strings, protected state and installer, the container install path, static shell, sign-in and sign-out, descriptor registry and navigation, page chrome, namespace as data scope, Home, uniform errors, and the auto-refresh framework
- Story 1.15: Classic portal fallback links — next
- Story 1.16: The IPM module, from one roster
- Story 1.17: Smoke script, readiness, CI

## Requirements & Constraints

- **Anything not rebuilt is one click away.** A cut large editor ships as a reduced form — the daily-administration fields plus the link, never a half-working full form — and its agent write tool ships regardless, so the change stays reachable through a confirmed proposal. A list screen never links out; an automated check asserts that across every list descriptor, honors an exemption only from a detail archetype, fails a list that declares one, and **reports every exemption it honors rather than passing silently**. Release 1 has exactly one.
- **A third web application is still to come.** Readiness needs its own unauthenticated application under the API prefix, resolved by longest prefix, with its own dispatch class, reporting only whether OcuPilot is installed, its version stamp, and whether install is still running — nothing that aids reconnaissance. A deeper health view is authenticated and privilege-gated like any other read. Install creates and removes it like the other two, and must refuse to adopt an application at any of the three paths it did not create, which needs a provenance record install does not yet have.
- **Install stays one class, two entry points, idempotent, and never depends on IPM.** Its class roster and the IPM manifest's resource list are generated from one source and cannot drift, proven by a test. The Docker path never uses IPM — the 2026.2 image ships none — an IPM install never unexpires `_SYSTEM` (its invoke carries no start-path argument), and the namespace is chosen in installer code (`HSCUSTOM` if present, else `USER`, the README documenting the override), the manifest being evaluated only after that choice is fixed. The module declares both applications with `<WebApplication>`, the package resource, the installer invoke, requirements for IRIS 2026.2+ and IPM 0.10.x, and carries the **built** bundle so install needs no Node toolchain.
- **One smoke script is the definition of "installed and working"**, owned by `Install/` rather than any slice. At build step 0 it asserts every part that exists so far and reports the rest as pending rather than passing vacuously. CI runs it against a throwaway container on every change; the clean-clone run is one story in Epic 17, the same script with the same assertions, so the late run cannot be their first exercise.
- **Contest floor:** pinned image tag, every library vendored with no runtime CDN reference, desktop Chrome, WCAG 2.1 AA with full keyboard operation. CI builds the bundle, lints, runs the ObjectScript unit and HTTP integration suites, the client unit tests and the endpoint-inventory fixture, and fails on any CDN reference or embedded Python in a shipped class. Every handler needs an HTTP integration test over status, content type and body shape, and no test class a property named `Test*`. Both Community images are exercised; the plain-Community `USER` fallback is deferred past the 2026-09-27 floor, the risk accepted.
- **Routed ledger items bind.** 1.15 carries DW-173, 1.16 DW-12 and DW-92, 1.17 seven entries — each addressed in its story or declined with a written reason.

## Technical Decisions

- **Extend the singletons; never add a second:** one response and error writer, one router and gate, one installer, one string source. The error envelope is closed — flat `{error, reason, code, detail}`.
- **A descriptor declares the classic *class name* it replaces, never a page URL**, because the portal keys custom page resources by normalized class name; a screen's privilege set is the union of the admin API's requirement and any custom resource on that key, and a screen with no classic equivalent says so explicitly. Link-out is declared in the same place, via `classicLinkExemption` with a reason.
- **Install completes before the first request is served**, at container start rather than image build, since the durable volume's databases supersede the image's on every start. Upgrade is install again, so this is the daily path: guard-then-act, fast, safe against a populated instance. The health check reports healthy only once **this** start's install recorded success — never on a stamp an earlier start wrote.
- **An unauthenticated application still needs a privilege floor.** Database read is routine-execution permission, so the readiness application carries exactly one purpose-built matching role, read-only on the install namespace's database and nothing else — and the install-time assertion naming every application and matching role must now cover three applications, not two. Every gate resolves the **authenticated** user and rejects the anonymous placeholders; none infers authorization from roles alone.
- **The refresh framework is built and inert.** Nothing declares a refresh until Epic 2 registers the first descriptor-declared read, so no chip and no stamp render today — designed, not missing. Its single-flight primitive (join on an unchanged key, mark-dirty-and-re-run-once on a changed one) serves any later re-entrant read; do not write a second.

## UX & Interaction Patterns

- **A reduced form ends with a card** titled "More in the classic portal", naming the page it opens, opening in a new tab, with a caption noting the classic portal may ask the user to sign in again. It never appears on a list screen. New windows and popups are banned everywhere else in the shell — this card and the OAuth classic links are the only exceptions.
- **A bounded bar meeting an unbounded string is the recurring chrome defect** (DW-173, DW-145 before it): a command-bar item that is a full sentence needs a max-width and a truncation rule, since no published design covers these chips at narrow widths.
- Card copy comes from the one string source and colors from the token layer — a hardcoded literal of either fails the build; copy no planning artifact publishes is escalated to the owner, never invented.

## Cross-Story Dependencies

- **1.1–1.14 are done and floor everything after** — one client failure taxonomy classified once behind a connectivity service that owns the probe and its backoff, with a single `role="alert"` banner. Consume them; do not add a second classifier, error writer or timer.
- **Epic 1's only screen is Home**, so 1.15 lands the mechanism — descriptor field, card component, automated check — ahead of the reduced forms that will use it (inference). 1.10's bands host the chrome it touches.
- **1.16 generates its manifest from the `src/OcuPilot/` tree the start hook compiles.**
- **1.17 also owns** the definition of "step complete", the connectivity probe's missing timeout (an accepted-but-never-answered connection stalls the backoff chain indefinitely), and the browser-runtime harness no UI surface has had since 1.5 — every shell assertion to date is jsdom, which computes no layout (DW-159).
- **Other epics.** Epic 2 builds the admin-API port Epic 1 only asserts is present at version 2, and its first descriptor-declared read brings the refresh framework to life; Epic 12 removes the one classic-link exemption; Story 3.7 owns the single enforcement point for read-only and the kill switch, which nothing here may preclude.
