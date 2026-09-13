# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — extended, never replaced, by every later epic. Sixteen stories are done; the last decides what "installed and working" means, puts it under CI, and lets a running instance answer the question itself.

## Stories

- Stories 1.1–1.16 (done): workspace and response envelope, design system and strings, protected state and installer, container install, static shell, sign-in and sign-out, identity and version guard, descriptors and navigation, chrome, namespace scope, Home, uniform errors, auto-refresh, classic links, the roster-generated IPM module
- Story 1.17: The smoke script, the readiness endpoint and CI — closes the epic

## Requirements & Constraints

- **One smoke script is the definition of "installed and working"**, owned by `Install/` rather than by any slice: sign-in, one live list per area, one confirmed agent write, the audit marker. At build step 0 it asserts every part that exists so far and reports the rest as pending rather than passing vacuously. CI runs it on every change against a throwaway container; the from-a-clean-clone run is a single story in Epic 17 — the same script with the same assertions, so the late run cannot be their first exercise.
- **Readiness reports installed, version stamp, and whether install is still running — nothing more.** No instance detail, nothing that aids reconnaissance. Any deeper health view is authenticated and privilege-gated like any other read.
- **CI's contents are fixed:** build the Angular bundle, lint, run the ObjectScript unit and HTTP integration suites, the client unit tests and the endpoint-inventory fixture, and fail on any CDN reference or embedded Python in a shipped class. Every handler needs an HTTP integration test over status, content type and body shape. Both Community images are exercised and the admin API confirmed present on each; the plain-Community `USER` fallback is deferred past the 2026-09-27 floor, the risk accepted. The contest floor CI protects: a pinned image tag, every library vendored, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Seventeen routed ledger entries bind** — each addressed or declined with a written reason. Four themes, not seventeen chores:
  1. **Gates asserted as source text, never run** (DW-193, DW-196, DW-184, DW-35, DW-50, DW-43). No test starts a gate or a container, so `prebuild`, `prestart`, the pre-commit hook and the start hook are pinned only by reading their source; the hook reads the working tree rather than the index, so a partially staged pair passes; the checkers have no test of their own; one build-side check has no hook counterpart.
  2. **No browser-runtime harness at all** (DW-159). Every UI assertion since 1.5 is jsdom, which computes no layout.
  3. **Install-path residue 1.16 pinned but did not fix** (DW-191, DW-192, DW-195, DW-197, DW-198, DW-199): `Uninstall` has no namespace guard; an override naming a system namespace compiles the tree before the start path refuses; the manifest is never parsed as XML; the gateway-gap report claims no application was created on the one install that made two; an application `Description` is set on create and never repaired. Most consequential here: the roster resolves the keys `shell` and `api` literally, so a third roster application reaches `module.xml` but never `Install()`.
  4. **Readiness and probe behaviour** (DW-2, DW-167). Readiness must stay truthful when install itself fails, and the connectivity probe has no timeout, so a connection accepted and never answered stalls the backoff chain indefinitely.
  Plus **DW-94**, carrying an owner decision already taken (below), and **DW-54**, the test runner re-submitting on a client-side timeout and racing shared fixtures.

## Technical Decisions

- **Readiness needs a third web application.** A password-authenticated application refuses an anonymous caller before any OcuPilot code runs, and the static application serves only files, so readiness lives on its own unauthenticated application at a path under the API prefix — IRIS resolves applications by longest prefix — with its own dispatch class, created and removed by the installer like the other two.
- **An unauthenticated application still needs a privilege floor.** Database read is routine-execution permission, so that application carries exactly **one** purpose-built matching role, read-only on the install namespace's database and nothing else; without it the call returns 500 with a `<PROTECT>` error that leaks the database directory. The install-time assertion naming every application and matching role now covers three, not two.
- **Anonymous does not mean unprivileged** — the anonymous user can hold `%All` — so every gate resolves the **authenticated** user and rejects the unauthenticated placeholders; none infers authorization from roles alone. Install must also **refuse** to adopt an application at any of the three paths it did not create, report the conflict, and remove only what it created. That needs a provenance record install does not yet have, and the third application is created through exactly that path.
- **Install completes before the first request is served**, at container start rather than image build, since the durable volume's databases supersede the image's on every start. Upgrade is install again, so guard-then-act against a populated instance is the daily path. The health check reports healthy only once **this** start's install recorded success — never on a stamp an earlier start wrote — and each start marks the stamp `installing` before recompiling, a best effort that never blocks the start.
- **Install stays one class, two entry points, idempotent, and never depends on IPM.** The 2026.2 image loads no IPM (the installer it ships on disk is unloaded), so nothing in the install path may assume it exists. The IPM invoke is argument-free, so an IPM install can never reach the unexpire step.
- **The install surface is roster-driven.** One roster carries module identity, package folders, the bundle source and per-application property maps; the manifest is generated from it under a drift check. Adding the readiness application is therefore a roster edit **plus** the installer-side key resolution DW-192 names — not a roster edit alone.
- **Extend the singletons; never add a second:** one response and error writer, one router and gate, one installer, one string source, one protected-state mechanism for any new OcuPilot record. The error envelope is closed — flat `{error, reason, code, detail}`. Any `%Persistent` class name stays at 29 dotted characters or fewer, for the natural data global.

## Cross-Story Dependencies

- **1.1–1.16 are done and floor everything here** — consume the singletons above rather than adding a second of any of them; the connectivity service already owns the probe and its backoff.
- **1.17 also owns** the definition of "step complete", the third application's provenance record, the probe's missing timeout, and the browser-runtime harness no UI surface has had since 1.5.
- **Other epics.** Epic 17 re-runs this same smoke script from a clean clone; Epic 2 builds the admin-API port Epic 1 only asserts is present, and its first descriptor-declared read wakes the refresh framework built inert here; Story 3.7 owns the single read-only enforcement point and the kill switch, which nothing here may preclude.
- **Open owner escalations sit with the epic burn-down, not with 1.17** — chiefly the classic-link card's caption, which neither UX document publishes. Copy no planning artifact publishes is escalated, never invented.
