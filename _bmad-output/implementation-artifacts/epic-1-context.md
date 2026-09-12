# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six portal areas, showing only the screens their IRIS privileges allow, with every classic page OcuPilot has not rebuilt one click away. This is build step 0: the workspace, the response envelope, the installer, the web applications, the screen descriptor mechanism, the shell chrome and the smoke script are each built once here, and every later epic extends them rather than replacing them.

## Stories

- Story 1.1: The workspace, the pinned stack and one response envelope (done)
- Story 1.2: The design system - tokens, type and the string table (done)
- Story 1.3: The installer creates OcuPilot's protected state, resource and role (done)
- Story 1.4: One command brings up an instance with OcuPilot installed (done)
- Story 1.5: The static shell serves the SPA, including deep links (done)
- Story 1.6: Silent-first sign-in — next
- Story 1.7: Sign-out
- Story 1.8: Instance identity and the API version guard
- Story 1.9: The screen descriptor registry and privilege-driven navigation
- Story 1.10: Header, status bar and page chrome
- Story 1.11: The namespace switch as data scope
- Story 1.12: Home
- Story 1.13: Uniform error handling and the connectivity probe
- Story 1.14: The auto-refresh framework
- Story 1.15: Classic portal fallback links
- Story 1.16: The IPM module, generated from one roster
- Story 1.17: The smoke script, the readiness endpoint and CI

## Requirements & Constraints

- **Three web applications, and the split is load-bearing.** The shell serves files unauthenticated with a deep-link fallback; the API is password-authenticated with JWT enabled, no server session, joined to the vendor's management-portal group, and carries no roles at all; readiness gets its own third unauthenticated application at a path under the API prefix, resolved by longest prefix. Install-time tests assert every such setting — a wrong one surfaces later as an authentication bug.
- **An unauthenticated application still needs a privilege floor.** Database READ is routine-execution permission, so without it an anonymous request cannot even load a dispatch class and fails with a 500 that leaks the database directory. The shell and readiness applications each carry exactly one purpose-built matching role, read-only on the install namespace's database and nothing else, created and removed by the installer; the install-time test asserts it is the only role any OcuPilot application carries.
- **Only a Bearer header from per-tab storage authorizes a data call** — never a cookie, persistent storage or a post into a frame. Sign-in is silent-first, refresh is a background concern of the one API service, and the dev loop proxies through the IRIS origin, so no CORS allowance exists anywhere.
- **The shell verifies the instance before rendering:** admin API present at version 2, and a version mismatch never presented as "no administrative privileges" or the reverse.
- **Nothing a user cannot open is hidden, and no read is unbounded;** every read is capped and reports whether it truncated.
- **Install runs at container start and finishes before traffic.** It is idempotent, migrates stored state forward, and refuses a stored schema newer than the code; until it is current the API refuses with one error envelope. The health check, healthy only on this start's successful install, is the readiness contract. Install never adopts an application at a path it did not create — it reports a conflict and removes only its own. Demo fixtures exist only under the compose flow's opt-in flag, and an IPM install never unexpires `_SYSTEM`.
- **Contest floor:** a pinned image tag, every library vendored with no CDN at runtime, no HealthShare-only dependency, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items are binding.** Stories 1.6–1.11, 1.13, 1.16 and 1.17 carry `DW-n` bullets in the epics file; each is addressed in its story or declined there with a written reason.
- **Verification until 1.17 creates CI:** there is no CI and no Angular component test runner, so a client-only criterion has no executed test host — 1.9 is the first story whose own gate lands on that gap. Client work is checked by `npm run build` and `npm test`, server work by `scripts/check-objectscript.py` and a live `%UnitTest` run. That suite runs as `_SYSTEM`, whose `%All` passes every resource check, so a denial test uses a purpose-built role and asserts the contrast.

## Technical Decisions

- **Extend the singletons; never add a second:** one success writer and one error writer, one `%CSP.REST` router whose `OnPreDispatch` applies the install gate, rejects anonymous callers and resolves the namespace once each, one entity-id codec, one structured logger, one installer class, one escalation point for OcuPilot's protected globals, one token layer and one string source behind build-failing linters.
- **Error envelope:** flat `{error, reason, code, detail}` — a closed-enum slug, rewordable human text, a stable dotted-uppercase `code` that is never a number, optional structured detail. No slice adds a field; a nested `Catch` returns with `Return $$$OK`; vendor `%Status` text is mapped at the port boundary. **One carve-out:** the static handler writes resolved file bytes to the response device directly with their own content type and cache headers, while every failure it produces still goes through the error writer.
- **Router order:** method guards before the catch-all, sub-resource routes before single-segment `:param` routes, N-segment before N-1, each with a routing test; route targets only delegate.
- **Identity and privilege:** checked in the calling process at call time, never cached, no service account. Gates resolve the authenticated user and reject `UnknownUser` and `_PUBLIC`, since on Minimal security `UnknownUser` holds `%All`. A requirement is a set of `(resource, permission)` pairs, unioned with any custom resource on the classic page replaced; a denial names the failed pair.
- **Namespace:** explicit save and restore, the restore first in every `Catch`. No `##class(OcuPilot.*)` call while `$NAMESPACE` is `%SYS`.
- **Routes and ids:** `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`, the id one segment through the shared codec. The wire contract is **encode-twice, decode-once**: the web server and `%CSP.REST` deliver a segment already percent-decoded once, so `Encode` UTF-8-encodes then percent-encodes twice, `Decode` percent-decodes once and UTF-8-decodes, and `Decode` runs exactly once per id. `%2F` and `%00` never reach IRIS — a recorded stack limitation, not something to work around. A reference crossing any boundary is `(entity type, scope, id)`, scope being the namespace or the literal `instance`; switching namespace re-fetches in place, never re-routes.
- **The screen descriptor is the single source for a screen:** one hand-written declarative server class, mirrored to the client as generated TypeScript, that the route table, navigation, privilege gating, tools, context capture and change-event routing all resolve through — so adding a screen never means editing a router or a nav list. Entity types come from one closed kernel-owned enum and the build fails on any other; tool identity does not derive from the screen name. **Unresolved:** the spine homes descriptors at `Screen/Descriptor/<Area><Screen>.cls`, but that package already uses 27 of the 29 characters a class name may have, so 1.9 must settle the name by amending the spine.
- **Client:** Angular 22.1.x, zoneless, standalone, `OnPush`, signals. Screen state is a store keyed by its descriptor, never a component field; screens communicate only through the change-event bus and the router. Every API path is absolute and goes through one API service that refuses a relative one, because the deep-link fallback would answer it with `index.html`. Homes: `ui/src/app/shell/`, `ui/src/app/core/`, `ui/src/app/areas/<area>/`. Harvested code keeps its call sites, never its names.

## UX & Interaction Patterns

- Every color comes from a token and every user-facing string from `ui/src/app/core/strings.ts`; a literal of either kind fails the build. Navy is the chrome, teal the only action color, yellow the agent and never a control. "co-pilot" never appears alone.
- **The shell never overlays and never scrolls horizontally.** Under pressure the side bar collapses first, the agent panel shrinks next, and content scrolls inside itself.
- **Gated controls stay reachable:** `aria-disabled="true"`, never `disabled`, never hidden, naming the required resource in a tooltip on hover and focus, inline in the side bar and command box, and inside the accessible name in menus and result lists.
- **Failures are distinguished, not generalized:** 401 refreshes and retries invisibly, 403 renders inline naming the privilege with on-screen data kept, an unexplained failure runs a connectivity probe separating an unreachable instance from a refused request, and a 5xx is generic in the browser and logged in full with secrets redacted.
- **Refresh is silent** — no spinner, skeleton or announcement. Under reduced motion transitions are instant and spinners become the word "running".

## Cross-Story Dependencies

- **1.5 is done and is the floor for 1.6–1.8.** It left the two applications with their exact JWT, group and role settings, the static handler under its two containment checks, the CSP, and the entity-id codec. Sign-out and the identity guard build on 1.6's token handling. Bundle staleness is routed to 1.8: the API reports its build stamp and the client prompts a mismatched bundle to reload.
- **Readiness is settled and owned by 1.17** — its own third unauthenticated application with its own dispatch class and the shell's privilege floor, created and removed by the installer. 1.17 also owns the install-provenance record that lets install refuse to adopt an application it did not create.
- **1.9 is the hinge** for 1.10's command box, 1.11's namespace scope, 1.12's tiles, 1.14's refresh declaration and 1.15's link-out check, and for every later epic, which adds screens by adding descriptors. It must also settle the descriptor class name and handle the deep-link case where an entity id contains `..`, which the static handler's traversal rejection sees in the path. **1.11 precedes 1.14:** the reference triple must exist before a re-fetch or proposal event can be routed.
- **1.16** generates its manifest from the same `src/OcuPilot/` tree the start hook compiles — no separate roster file exists. **1.17** depends on all of the above and defines "step complete" for every later epic; the clean-clone run of its smoke script happens once, in Epic 17.
- **Other epics.** Epic 2 builds the admin-API port; Epic 1 only asserts its presence and version. Story 3.7 owns the one enforcement point for read-only and the kill switch, which nothing here may preclude.
