# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0 — envelope, installer, web applications, descriptor mechanism, shell chrome and smoke script are built once here and extended, never replaced, by every later epic.

## Stories

- Story 1.1: Workspace, pinned stack, one response envelope (done)
- Story 1.2: Design system — tokens, type, string table (done)
- Story 1.3: Installer creates the protected state, resource and role (done)
- Story 1.4: One command brings up an installed instance (done)
- Story 1.5: Static shell serves the SPA, including deep links (done)
- Story 1.6: Silent-first sign-in (done)
- Story 1.7: Sign-out (done)
- Story 1.8: Instance identity and the API version guard (done)
- Story 1.9: Screen descriptor registry and privilege-driven navigation (done)
- Story 1.10: Header, status bar and page chrome — next
- Story 1.11: The namespace switch as data scope
- Story 1.12: Home
- Story 1.13: Uniform error handling and the connectivity probe
- Story 1.14: The auto-refresh framework
- Story 1.15: Classic portal fallback links
- Story 1.16: The IPM module, generated from one roster
- Story 1.17: Smoke script, readiness endpoint and CI

## Requirements & Constraints

- **Three web applications:** the unauthenticated files-only shell, the password+JWT API (no server session, joined to the vendor's management-portal group, no roles), and a third for readiness (1.17) — unauthenticated, under the API prefix, resolved by longest prefix. Each unauthenticated application carries exactly one purpose-built read-only matching role, because database READ is routine-execution permission, and install-time tests assert every setting.
- **Only a Bearer header from per-tab storage authorizes a data call** — never a cookie, persistent storage, or a post into a frame — and refresh is a background concern of the one API service that no screen or panel handles. No CORS allowance exists anywhere; the dev loop proxies through the IRIS origin.
- **Nothing a user cannot open is hidden, and no read is unbounded** — every read is capped and reports whether it truncated.
- **Install runs at container start and finishes before traffic**, idempotent, refusing a stored schema newer than the code and answering with one error envelope until current; the health check, healthy only on this start's install, is the readiness contract. Install never adopts an application it did not create, picks `HSCUSTOM` else `USER` in installer code rather than a manifest, and never unexpires `_SYSTEM` on an IPM path. The Docker path never uses IPM, the 2026.2 image shipping none.
- **Contest floor:** pinned image tag, every library vendored with no runtime CDN, no HealthShare-only dependency, desktop Chrome, WCAG 2.1 AA with full keyboard operation.
- **Routed ledger items bind.** Stories 1.10, 1.11, 1.13, 1.16 and 1.17 still carry `DW-n` bullets; each is addressed in its story or declined there with a written reason.
- **A client component test runner now exists** (`@angular/build:unit-test` on vitest with jsdom): rendered DOM, ARIA state and focus movement are testable, so "no component test host" is no longer a reason to leave rendered behaviour unpinned. CI itself arrives in 1.17. A live `%UnitTest` run executes as `_SYSTEM`, so a denial test needs a purpose-built role to contrast against `%All`.

## Technical Decisions

- **Extend the singletons; never add a second:** one success writer and one error writer; one `%CSP.REST` router whose `OnPreDispatch` applies the install gate, rejects anonymous callers and resolves the namespace once; one entity-id codec; one structured logger; one installer; one escalation point for the protected globals; one token layer; one string source.
- **Error envelope:** flat `{error, reason, code, detail}` — closed-enum slug, rewordable human text, a stable dotted-uppercase `code` that is never a number, optional detail. No slice adds a field; vendor `%Status` text is mapped at the port boundary.
- **Identity and privilege:** resolved in the calling process at call time, never cached, no service account. Gates reject `UnknownUser` and `_PUBLIC`, since on Minimal security `UnknownUser` holds `%All`. A requirement is a set of `(resource, permission)` pairs — the security APIs need `%DB_IRISSYS:R` *and* `%Admin_Secure:U` together — unioned with any custom resource on the classic page replaced; a denial names the failed pair.
- **Namespace:** explicit save and restore, the restore first in every `Catch`, and no `##class(OcuPilot.*)` call while `$NAMESPACE` is `%SYS`.
- **Routes and ids:** `/ocupilot/<area>/<screen>[/<id>]?ns=<NAMESPACE>`, the id in one segment through the shared codec, whose contract is **encode-twice, decode-once**, run exactly once per id; `%2F` and `%00` never reach IRIS. A reference crossing a boundary is `(entity type, scope, id)`, scope being the namespace or the literal `instance`; switching namespace re-fetches in place, never re-routes.
- **The screen descriptor is the single source for a screen** — one declarative server class mirrored to the client as generated TypeScript, through which route table, navigation, privilege gate, tools and change-event routing all resolve, so adding a screen never means editing a router or a nav list. Entity types come from one closed kernel-owned enum, and tool identity does not derive from the screen name. The awkward forms are already declared: secondary entity types, a parent-scope reference, a composite id.
- **A descriptor declares the classic *class name* it replaces, never a page URL** — the classic portal keys custom page resources by normalized class name, so the class is what an operator's resource assignment hangs off and what the privilege union reads. Link-out is a list-versus-detail distinction in the same descriptor: a list archetype never links out; a detail archetype may, via `classicLinkExemption` with a reason; the check reports every exemption it honors rather than passing silently.
- **The 29-character class-name cap binds only `%Persistent` classes**, whose `^<Class>D` global it protects; descriptors, ports, handlers, fixtures and tests are not capped.
- **Client:** zoneless, standalone, `OnPush`, signals; a screen is `<screen>.page.ts` + `.store.ts` + `.descriptor.ts` under `ui/src/app/areas/<area>/`. Screen state is a store keyed by its descriptor, never a component field; screens communicate only through the change-event bus and the router. Every API path is absolute, through the one API service that refuses a relative one, because the deep-link fallback would answer it with `index.html`. Harvested code keeps its call sites, never its names.

## UX & Interaction Patterns

- Colors come only from tokens and user-facing strings only from the one string source; a literal of either kind fails the build. Navy is the chrome, teal the only action color, yellow the agent and never a control; "co-pilot" never appears alone.
- **The shell never overlays and never scrolls horizontally** — under pressure the side bar collapses first, the panel shrinks next, content scrolls inside itself.
- **Gated controls stay reachable:** `aria-disabled="true"`, never `disabled`, never hidden, naming the required resource in a tooltip on hover and focus, inline after the label in the side bar and command box, and inside the accessible name in menus and result lists, where Material's key managers skip disabled items and no tooltip can show.
- **Failures are distinguished, not generalized:** 401 refreshes and retries invisibly; 403 renders inline naming the privilege, on-screen data kept; an unexplained failure runs a connectivity probe separating an unreachable instance from a refused request; a 5xx is generic in the browser, logged in full with secrets redacted.
- **Refresh is silent** — no spinner, skeleton or announcement, and sort, filter, selection, scroll and max rows survive it. Under reduced motion, transitions are instant and spinners become the word "running".

## Cross-Story Dependencies

- **1.1–1.9 are done and floor everything after.** In place: the envelope, router and gate, installer, static shell, sign-in/sign-out, the admin port and instance-identity call, and 1.9's descriptor registry, area roster, privilege pair-set gate, navigation endpoint, rail and side bar, and TypeScript mirror generator. The blocking notices for a version mismatch and for no administrative privileges must never dress as each other.
- **Only Home carries a real screen descriptor.** The other seven rail areas are declared with no screens, so they list in the rail and do not navigate; 1.12 builds Home's page, and every later epic adds screens by adding descriptors.
- **1.10 is next**, sitting on 1.9's navigation output and 1.8's identity call. **Sign-out means the instance, not the tab** — logout carries both the Bearer and the cookie, no tab-only sign-out exists in this design, and 1.10's account menu must not imply one. 1.10 also owns the shell residue 1.9 left open (chord handling, `?ns=` survival across rail and side-bar navigation, Home's collapse state) and the focus and dismissal defects in the sign-in form and account menu.
- **1.11 precedes 1.14:** the reference triple must exist before a re-fetch or proposal event can be routed. **1.13 owns the retry** for an identity call that fails as neither a privilege denial nor install-in-flight, which today leaves a signed-in tab on a blank content area with nothing scheduled to ask again.
- **1.17 owns readiness**, the install-provenance record behind install's refusal to adopt an application it did not create, and the definition of "step complete"; the clean-clone smoke run happens once, in Epic 17. **1.16** generates its manifest from the same `src/OcuPilot/` tree the start hook compiles.
- **Other epics.** Epic 2 builds out the admin-API port — Epic 1 only asserts its presence at version 2 — and owns the registry's per-call descriptor re-parse, routed to Story 2.3 as the first story adding descriptors in bulk, so an Epic 1 story adding a descriptor should not work around it locally. Story 3.7 owns the one enforcement point for read-only and the kill switch, which nothing here may preclude.
