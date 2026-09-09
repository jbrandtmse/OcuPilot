# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six portal areas, showing only the screens their IRIS privileges allow, with any classic portal page OcuPilot has not rebuilt one click away. This is build step 0 on a greenfield tree. The workspace pins, the response envelope, the installer, the screen descriptor mechanism, the shell chrome and the smoke script are built once here; every later epic extends them rather than replacing them.

## Stories

- Story 1.1: The workspace, the pinned stack and one response envelope
- Story 1.2: The design system — tokens, type and the string table
- Story 1.3: The installer creates OcuPilot's protected state, resource and role
- Story 1.4: One command brings up an instance with OcuPilot installed
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

- **One command, first time.** A clean clone plus one compose command yields a running instance with OcuPilot installed, the default account's password unexpired, auditing enabled with OcuPilot's event types registered, and the app reachable at the published port. The install namespace is chosen in installer code, not in a manifest.
- **Install runs at container start, not image build, and is idempotent.** Upgrade *is* install again, so it must be fast, guard-then-act throughout, and safe against a populated instance: it migrates stored state forward on start, fails loudly rather than serving partial state, and refuses when the stored schema version is newer than the deployed code. No traffic is served until install completes or fails.
- **Two web applications, and the split is load-bearing.** An unauthenticated static shell with a non-root base href and a deep-link fallback; and a password-authenticated API with JWT enabled, no server session, joined to the vendor's management-portal group, carrying no application or matching roles. Install-time tests assert those settings rather than leaving them to inspection.
- **Sign-in is silent-first.** A silent probe precedes any form; the form appears only on refusal, with the requested route preserved. Only a Bearer header from per-tab storage authorizes a data call — never a cookie, never persistent storage, never posted into a frame. Refresh carries its token in the body and is a background concern of the API service. Sign-out sends both the Bearer and the cookie, so the browser-level login actually ends.
- **The shell verifies the instance before rendering.** One call confirms the admin API's pinned version and reads the instance identity. A version mismatch and "no administrative privileges" are two distinct blocking notices that must never dress as each other.
- **Nothing a user cannot open is hidden**, and no read returns an unbounded collection — every read is capped and reports whether it truncated.
- Contest floor: an explicitly pinned image tag, no CDN reachable at runtime with every library vendored, and no HealthShare-only dependency.

## Technical Decisions

- **Pins are exact and a wrong version must fail loudly rather than compile:** Angular 22.1.x with Material/CDK 22.x, TypeScript `>=6.0.0 <6.1.0`, Node `^22.22.3 || ^24.15.0 || ^26.0.0`, the application builder with full output hashing, no webpack builder. The client is zoneless, standalone and signal-based; screen state is a per-screen store keyed by its descriptor, never a component field.
- **All project ObjectScript lives under `src/OcuPilot/`** in fixed package folders (`Api`, `Kernel`, `Screen`, `Area`, `Port`, `Install`, `Test`), under the project's naming rules, with class names short enough that the compiler does not hash the storage global. **Harvested sibling code keeps its call sites but never its names** — packages, web paths, roles, audit sources, globals, credentials, tool prefixes and environment variables all become OcuPilot's own.
- **One response writer, one error envelope.** Handlers never write to the response device. Failure renders a flat `{error, reason}` with a slug from a fixed enum, plus a stable machine code and optional structured detail so a screen and a tool consume one failure two ways. Inside a nested `Catch` the return is `Return $$$OK` — a bare `Quit` resumes the enclosing `Try` and puts a second envelope on the wire.
- **The router preserves three ordering invariants**, each with its own test: method guards before the catch-all, sub-resource routes before single-segment parameter routes, N-segment before (N−1)-segment. Route targets are thin delegating wrappers. The pre-dispatch seam authenticates and resolves the namespace exactly once, by explicit save and restore, restored as the first line of every `Catch`. Framework 404s and 405s are overridden into the envelope, the 405 carrying an `Allow` header.
- **Entity ids occupy exactly one percent-encoded path segment**, through one shared encode/decode pair round-trip tested over a fixed corpus. An id alone is never an identity: every reference crossing a boundary carries `(entity type, scope, id)`, scope being the namespace or the literal `instance`.
- **The screen descriptor is the single source for a screen** — route, area and side-bar position, archetype, privilege set, entity type and scope, id accessor, context serializer with its secret-typed fields, actions with self-protection rules, empty-state text, command-box aliases, and the classic page it replaces. Routes, navigation and gating all resolve through it, so adding a screen never means editing a router or a nav list. Entity types come from one closed kernel-owned enum and the build fails on a value outside it. Multi-entity screens, sub-resource screens and composite ids must be expressible now, and tool identity must be independent of screen naming.
- **Privilege is a set of `(resource, permission)` pairs, never one resource**, evaluated in the calling process at call time and never cached; the set unions the API's requirement with any custom resource assigned to the classic page being replaced, and a denial names the pair that failed. Every gate resolves the *authenticated* user and rejects the unauthenticated placeholders explicitly — a roles-only check lets an anonymous browser through with full privilege on a minimal-security instance.
- **OcuPilot's globals live in a dedicated database behind a dedicated resource; its code does not** — database read is routine-execution permission, so hiding the packages would make OcuPilot unrunnable by the users it serves. Only storage classes escalate, inside a role frame that unwinds, and nothing is spawned or re-entered from inside that frame.
- **The static origin is hostile ground.** The handler applies both a literal traversal rejection and a post-normalization containment check, accepts no caller path, never reflects input, streams in bounded chunks, and serves the index for anything unresolved; hashed assets get immutable cache headers, the index no-cache, under a policy naming only the instance's own origin. **The SPA never uses a relative API URL** — the deep-link fallback would answer it with the index instead of JSON, silently.
- **Auto-refresh is one shared framework:** one timer, one persisted per-screen setting, one silent re-fetch through the same descriptor-declared read, preserving sort, filter, selection and scroll. It subscribes from the start to the proposal-open/closed channel, so the pause has a channel before there is anything to pause for.
- **Link-out is a list-versus-detail rule declared in the descriptor:** a list never links out, only a detail archetype may declare an exemption with a reason, and the check reports every exemption it honors rather than passing silently.
- **Installer, package manifest and CI share one generated roster.** The manifest ships the *built* bundle so install needs no Node toolchain; the Docker path never uses the package manager, which the shipped image does not carry. The installer reports — never silently depends on — the gateway registration gap after creating a web application.
- **One smoke script is the definition of "installed and working"**, owned by `Install/`, asserting what exists at step 0 and reporting the rest as pending rather than passing vacuously. The unauthenticated readiness endpoint reports only installed/version/installing, nothing aiding reconnaissance. CI runs against a throwaway container and fails on any CDN reference or embedded Python in a shipped class.

## UX & Interaction Patterns

- **The visual system is a token layer over Material 3** — state layers, ripple, scrim and component anatomy inherited unchanged, only values overridden, light and dark both complete. A hardcoded color fails the build.
- **The copy layer gets the same enforcement as the color layer.** One canonical string source is authoritative over every other document and inline quotation; a literal not drawn from it fails the build. A placeholder may be resolved by a caller but never respelled, and the user-name placeholder resolves to the login name *as the audit database records it*, so a string and an audit row cannot disagree.
- **Shell layout is fixed:** a navy header with the lockup, centered command box and namespace switch; a rail of eight items in daily-use order with the agent pinned bottom, one Tab stop, marking the active area; a fixed-width side bar listing only built screens; a thin status bar whose only interactive element is the user segment. The server-flag badge lives in the status bar and on Home's instance line, never the header.
- **Every screen carries a locator bar** (area, screen, selected entity — each navigating; namespace is not a segment) and a command bar with the primary action, filter and its polite match count, view options, sort, the refresh chip and the last-update stamp. Row actions read "select a row first" until a row is selected, every command-bar action is reachable from the command box, and the command box is never a channel to the agent.
- **Gated controls stay reachable** — `aria-disabled`, never natively disabled and never hidden — naming the required resource as a tooltip on hover *and* focus, inline in the side bar and command box, and inside the accessible name in menus and result lists, where key managers skip disabled items and no tooltip can show.
- **Home is the surface, not a tile:** six area tiles in a wrapping grid naming their shipped screens, with the instance line beneath; the agent is reached from the rail.
- **Failures are distinguished, not generalized.** A 401 refreshes and retries invisibly; a 403 renders inline naming the missing privilege with on-screen data kept; an unexplained failure runs a connectivity probe separating "instance unreachable" from "request refused"; a 5xx is generic in the browser with full detail logged on the instance, secrets redacted before emission. Vendor status text becomes a slug and a written reason at the port boundary.
- **Reduced motion is honored throughout**, and WCAG 2.1 AA is the floor in both modes, with explicit guard tests on the marginal token pairs. Desktop Chrome is the supported browser.

## Cross-Story Dependencies

- **1.1 gates everything** — pins, tree shape and the single response/error writer must exist before any handler, screen or test. The shared harvested utilities are taken first because everything downstream uses them.
- **1.2 lands before there is content to break it**, so nothing shipped later has to be recolored or reworded.
- **1.3 → 1.4 → 1.16.** The protected database, resource and role are installer work, so storage protection is designed before the container start path closes; 1.4 also needs 1.5's web applications, and 1.16's manifest is generated from the same roster.
- **1.5 → 1.6 → 1.7 → 1.8.** Silent-first sign-in depends on the API application's exact JWT and group settings; sign-out and the identity guard build on the token handling 1.6 establishes.
- **1.9 is the hinge** for the rest of the epic and for Epics 2, 5, 6, 7, 8 and 9: the descriptor mechanism, closed entity-type enum and privilege gate feed 1.10's command box, 1.11's namespace scope, 1.12's tiles, 1.14's refresh declaration and 1.15's link-out check, and every later epic adds screens by adding descriptors.
- **1.11 → 1.14.** Namespace-as-data-scope and the shared reference triple must exist before any re-fetch, change event or proposal event can be routed; 1.14 also anticipates Epic 5 by subscribing to a channel nothing publishes on yet.
- **1.17 depends on all of the above** and defines "step complete" for every later epic; the clean-clone rehearsal of the same script is scheduled once, late, in the submission epic rather than per step.
- **Epic 2 takes over at the port boundary.** No story here constructs a vendor endpoint object or names an admin-API class; Epic 1 only asserts that API's presence and version.
