# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six portal areas, showing only the screens their IRIS privileges allow, with every classic page OcuPilot has not rebuilt one click away. This is build step 0. The pinned workspace, the response envelope, the installer and its container start path, the screen descriptor mechanism, the shell chrome and the smoke script are each built once here, and every later epic extends them rather than replacing them.

## Stories

- Story 1.1: The workspace, the pinned stack and one response envelope (done)
- Story 1.2: The design system - tokens, type and the string table (done)
- Story 1.3: The installer creates OcuPilot's protected state, resource and role (done)
- Story 1.4: One command brings up an instance with OcuPilot installed (done)
- Story 1.5: The static shell serves the SPA, including deep links
- Story 1.6: Silent-first sign-in
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

- **Two web applications, and the split is load-bearing.** The static shell serves files unauthenticated with a deep-link fallback; the API is password-authenticated with JWT enabled, no server session, membership in the vendor's management-portal group, and no application or matching roles. Install-time tests assert every such setting, because a wrong one surfaces later as an authentication bug.
- **Only a Bearer header from per-tab storage authorizes a data call** — never a cookie, persistent storage or a post into a frame. Sign-in is silent-first, refresh is a background concern of the one API service, and the dev loop proxies through the IRIS origin, so no CORS allowance exists anywhere.
- **The shell verifies the instance before rendering:** admin API present at version 2, and a version mismatch never presented as "no administrative privileges" or the reverse.
- **Nothing a user cannot open is hidden, and no read is unbounded;** every read is capped and reports whether it truncated.
- **Install runs at container start and finishes before traffic.** It is idempotent, migrates stored state forward, and refuses a stored schema newer than the code; until it is current the API refuses with one error envelope. The container health check, healthy only on this start's successful install, is the readiness contract. Demo fixtures exist only under the compose flow's opt-in flag, a `/csp/myapp` that install did not create is never modified, enabled, granted or removed, and an IPM install never unexpires `_SYSTEM`.
- **Contest floor:** a pinned image tag, every library vendored with no CDN at runtime, no HealthShare-only dependency, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items are binding.** Stories 1.5, 1.6, 1.7, 1.9, 1.10, 1.11, 1.13, 1.16 and 1.17 carry `DW-n` bullets in the epics file; each is addressed in its story or declined there with a written reason.
- **Verification until 1.17 creates CI:** there is no CI and no Angular component test runner. Client work is checked by `npm run build` (prebuild guards and linters) and `npm test`, server work by `scripts/check-objectscript.py` and a live `%UnitTest` run. That suite runs as `_SYSTEM`, whose `%All` passes every resource check, so a denial test uses a purpose-built role and asserts the contrast — never `_SYSTEM`, never `%Operator`.

## Technical Decisions

- **Extend the singletons; never add a second:** one success writer and one error writer, one `%CSP.REST` router whose `OnPreDispatch` applies the install gate, rejects anonymous callers and resolves the namespace once each, one entity-id codec, one structured logger, one installer class, one escalation point for OcuPilot's protected globals, one token layer and one string source behind build-failing linters.
- **Error envelope:** flat `{error, reason, code, detail}` — a closed-enum slug, rewordable human text, a stable dotted-uppercase `code` that is never a number, optional structured detail. No slice adds a field; handlers never write to the response device; a nested `Catch` returns with `Return $$$OK`. Vendor `%Status` text is mapped to a slug and reason at the port boundary.
- **Router order:** method guards before the catch-all, sub-resource routes before single-segment `:param` routes, N-segment before N-1, each with a routing test; route targets only delegate.
- **Identity and privilege:** checked in the calling process at call time, never cached, no service account. Gates resolve the authenticated user and reject `UnknownUser` and `_PUBLIC`, since on Minimal security `UnknownUser` holds `%All`. A requirement is a set of `(resource, permission)` pairs, unioned with any custom resource on the classic page replaced; a denial names the failed pair.
- **Namespace:** explicit save and restore, the restore first in every `Catch`. No `##class(OcuPilot.*)` call while `$NAMESPACE` is `%SYS`, because OcuPilot's code is mapped only into the install namespace.
- **Routes and ids:** `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`, the id one percent-encoded segment through the shared codec, decoded once. A reference crossing any boundary is `(entity type, scope, id)`, scope being the namespace or the literal `instance`. Switching namespace re-fetches in place, never re-routes.
- **The screen descriptor is the single source for a screen:** a hand-written declarative server class mirrored to the client as generated TypeScript. It declares route, area and side-bar position, archetype, privilege set, primary and secondary entity types with scope and any parent reference, id accessor (composite keys through the shared codec), context serializer with secret-typed fields, actions with self-protection rules, empty-state text, command-box aliases, the classic page replaced, whether it refreshes and at which rates, and any link-out exemption, which only a detail archetype may declare. Routes, navigation and gating resolve through it; entity types come from one closed kernel-owned enum and the build fails on any other; tool identity does not derive from the screen name. **Unresolved:** the spine homes descriptors at `Screen/Descriptor/<Area><Screen>.cls`, but `OcuPilot.Screen.Descriptor.` already uses 27 of the 29 characters a class name may have, so 1.9 must settle the name by amending the spine.
- **Client:** Angular 22.1.x, zoneless, standalone, `OnPush`, signals. Screen state is a store keyed by its descriptor, never a component field; screens communicate only through the change-event bus and the router. Every API path is absolute and goes through one API service that refuses a relative one, because the deep-link fallback would answer it with `index.html`. Homes: `ui/src/app/shell/`, `ui/src/app/core/` (API service, error mapping, event bus, auth), `ui/src/app/areas/<area>/`.
- **Harvest head start:** the harvest plan's Step 0 names sibling code for the static handler, the API service's base-path discipline, error mapping, the feature-error component and a request test helper. Harvested code keeps its call sites, never its names.

## UX & Interaction Patterns

- Every color comes from a token and every user-facing string from `ui/src/app/core/strings.ts`; a literal of either kind fails the build. Navy is the chrome, teal the only action color, yellow the agent and never a control. "co-pilot" never appears alone.
- **Shell:** navy header, rail and status bar; a fixed 240px side bar with no resize. When space runs out the side bar collapses first, the panel shrinks to 320px next, and content then holds 640px and scrolls inside itself; nothing overlays and the page body never scrolls horizontally.
- **Gated controls stay reachable:** `aria-disabled="true"`, never `disabled`, never hidden, with the required resource named in a tooltip on hover and focus, inline in the side bar and command box, and inside the accessible name in menus and result lists.
- **Failures are distinguished, not generalized:** 401 refreshes and retries invisibly, 403 renders inline naming the privilege with on-screen data kept, an unexplained failure runs a connectivity probe separating an unreachable instance from a refused request, and a 5xx is generic in the browser and logged in full with secrets redacted.
- **Refresh is silent** — no spinner, skeleton or announcement. Under reduced motion transitions are instant and spinners become the word "running".

## Cross-Story Dependencies

- **1.4 -> 1.5.** The router already refuses every request with a 503 envelope (`INSTALL.INSTALLING`, `INSTALL.FAILED`, `INSTALL.UPGRADEREQUIRED`) until install is current, ahead of its own caller check. 1.5 creates the two web applications inside that install and reports their CSP Gateway registration gap through the installer's existing reporting.
- **1.5 -> 1.6 -> 1.7 -> 1.8.** Silent sign-in depends on the API application's exact JWT and group settings; sign-out and the identity guard build on 1.6's token handling.
- **1.5 and 1.17 decide together where readiness lives.** The readiness endpoint must answer an unauthenticated caller, but the API application is password-authenticated and the static application serves only files, and the planning artifacts name no host for it; a password-only application refuses an anonymous request before OcuPilot's dispatch runs (inference).
- **1.9 is the hinge** for 1.10's command box, 1.11's namespace scope, 1.12's tiles, 1.14's refresh declaration and 1.15's link-out check, and for every later epic, which adds screens by adding descriptors. **1.11 precedes 1.14:** the reference triple must exist before a re-fetch or proposal event can be routed.
- **1.16** generates its manifest from the same `src/OcuPilot/` tree the start hook compiles — no separate roster file exists — and pins that an IPM install never reaches the `_SYSTEM` unexpire (DW-92). **1.17** depends on all of the above and defines "step complete" for every later epic; the clean-clone run of its smoke script happens once, in Epic 17.
- **Other epics.** Epic 2 builds the admin-API port; Epic 1 only asserts its presence and version. Story 3.7 owns the one enforcement point for read-only and the kill switch, which nothing here may preclude.
