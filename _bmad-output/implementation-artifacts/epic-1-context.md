# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — what is built here is extended, never replaced, by every later epic. Two stories remain, and they carry the install and release contract.

## Stories

- Stories 1.1–1.15 (done): workspace and response envelope, design system and strings, protected state and installer, the container install path, static shell, sign-in and sign-out, identity and version guard, descriptors and navigation, chrome, namespace scope, Home, uniform errors, auto-refresh, classic-portal fallback links
- Story 1.16: The IPM module, generated from one roster — next
- Story 1.17: The smoke script, the readiness endpoint and CI — closes the epic

## Requirements & Constraints

- **One IPM command installs, with no Node toolchain.** The module declares both web applications with `<WebApplication>` — never the deprecated `<CSPApplication>` — plus the file copy of the **built** Angular bundle, the package resource, the installer invoke, and system requirements for IRIS 2026.2+ and IPM 0.10.x. The built bundle is inside the archive.
- **The installer's class roster and the manifest's resource list are generated from one source** and cannot drift, proven by a test.
- **Install stays one class, two entry points, idempotent, and never depends on IPM.** The Docker path never uses IPM — the 2026.2 image ships zero `%ZPM*` classes — so nothing in the install path may assume it exists. The IPM invoke calls `Install()` with **no second argument**, never the start-path form, so an IPM install never reaches the unexpire step — an expired `_SYSTEM` there may be the operator's choice. The namespace is chosen in installer code (`HSCUSTOM` if present, else `USER`, README documenting the override), the manifest being evaluated only after that choice is fixed; install validates the chosen namespace exists and fails loudly naming it.
- **One smoke script is the definition of "installed and working"**, owned by `Install/` rather than any slice: sign-in, one live list per area, one confirmed agent write, the audit marker. At build step 0 it asserts what exists so far and reports the rest as pending rather than passing vacuously. CI runs it on every change against a throwaway container; the clean-clone run is a single story in Epic 17 — the same script with the same assertions, so the late run cannot be their first exercise.
- **Readiness reports installed, version stamp, and whether install is still running — nothing more.** No instance detail, nothing that aids reconnaissance. Any deeper health view is authenticated and privilege-gated like any other read.
- **CI's contents are fixed:** build the bundle, lint, run the ObjectScript unit and HTTP integration suites, the client unit tests and the endpoint-inventory fixture, and fail on any CDN reference or embedded Python in a shipped class. Every handler needs an HTTP integration test over status, content type and body shape, and no test class carries a property whose name begins with `Test`. Both Community images are exercised and the admin API confirmed present on each; the plain-Community `USER` fallback is deferred past the 2026-09-27 floor, the risk accepted.
- **Contest floor:** explicitly pinned image tag, every library vendored with no runtime CDN reference, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items bind** — each addressed in its story or declined with a written reason. 1.16 carries DW-12 (neither namespace exists, or the override names a missing one) and DW-92 (the `<Invoke>` argument). 1.17 carries nine: DW-2, DW-35, DW-43, DW-50, DW-54, DW-94, DW-159, DW-167, DW-184.

## Technical Decisions

- **Readiness needs a third web application.** A password-authenticated application refuses an anonymous caller before any OcuPilot code runs, so readiness lives on its own unauthenticated application at a path under the API prefix — IRIS resolves applications by longest prefix — with its own dispatch class, created and removed by the installer like the other two.
- **An unauthenticated application still needs a privilege floor.** Database read is routine-execution permission, so that application carries exactly **one** purpose-built matching role, read-only on the install namespace's database and nothing else; without it the call fails `<PROTECT>` and leaks the database directory. The install-time assertion naming every application and matching role now covers three, not two.
- **Anonymous does not mean unprivileged** — the anonymous user can hold `%All` — so every gate resolves the **authenticated** user and rejects the anonymous placeholders; none infers authorization from roles alone. Install must also refuse to adopt an application at any of the three paths it did not create, reporting the conflict and removing only what it created, which needs a provenance record install does not yet have.
- **Install completes before the first request is served**, at container start rather than image build, since the durable volume's databases supersede the image's on every start. Upgrade is install again, so guard-then-act and safety against a populated instance are the daily path. The health check reports healthy only once **this** start's install recorded success — never on a stamp an earlier start wrote — and each start marks the stamp `installing` before recompiling, a best effort that never blocks the start.
- **Extend the singletons; never add a second:** one response and error writer, one router and gate, one installer, one string source. The error envelope is closed — flat `{error, reason, code, detail}`.
- **Archetype-dependent rules fail closed** against a closed `list`/`detail`/`none` vocabulary; a key outside it is refused, never passed. The classic-link-out check runs in `prebuild`, `prestart` and the pre-commit hook and reports every exemption it honors — and the hook's dispatch list must stay in step with the build's.
- **Anything `%Persistent` keeps its dotted class name at 29 characters or fewer** so it gets the natural data global; classes with no storage are not bound by the cap.

## Cross-Story Dependencies

- **1.1–1.15 are done and floor everything after** — one failure taxonomy behind a connectivity service that owns the probe and its backoff, one installer, one string source. Consume them; do not add a second.
- **1.16 generates its manifest from the `src/OcuPilot/` tree the start hook compiles**, after the namespace choice is fixed.
- **1.17 also owns** the definition of "step complete", the third application's provenance record, the connectivity probe's missing timeout (an accepted-but-never-answered connection stalls the backoff chain indefinitely), and the browser-runtime harness no UI surface has had since 1.5 — every shell assertion to date is jsdom, which computes no layout.
- **Open escalation from 1.15:** the classic-link card ships without its caption, because neither UX document publishes the literal. Copy no planning artifact publishes is escalated to the owner, never invented.
- **Other epics.** Epic 17 re-runs this same smoke script from a clean clone; Epic 2 builds the admin-API port Epic 1 only asserts is present at version 2, and its first descriptor-declared read wakes the refresh framework built inert here; Epic 12 removes the one classic-link exemption; Story 3.7 owns the single read-only enforcement point and the kill switch, which nothing here may preclude.
