# Epic 1 Context: Install once, sign in, and reach the six areas

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator clones the repository, runs one command, and reaches a working OcuPilot: installed into a running IRIS instance, signed in with no form when the browser already holds an instance login, navigable across the six areas, showing only the screens their privileges allow, with every classic page it has not rebuilt one click away. Build step 0, extended by every later epic. Seventeen stories are done, the smoke script, readiness endpoint and CI among them. The last story is a burn-down: it closes the Epic 1 findings that threaten a first install, cause a silent refusal, block the public release or make CI unreliable, so Epic 2 starts on an install path, a gate and a pipeline that tell the truth.

## Stories

- Stories 1.1–1.17 (done): workspace and response envelope, design system and strings, protected state and installer, container install, static shell, sign-in and sign-out, identity and version guard, descriptors and navigation, chrome, namespace scope, Home, uniform errors, auto-refresh, classic links, the roster-generated IPM module, the smoke script with readiness and CI
- Story 1.18: Epic 1 burn-down

## Requirements & Constraints

- **First install on Linux works.** On a host with no `iris-data` directory, the documented `docker compose up -d --wait` must let IRIS write its durable directory and finish installing, as the CI throwaway already does. The pin must fail on a Linux ownership regression. A text assertion does not count.
- **A gate that cannot read OcuPilot's own state says so.** An example is a revoked SQL grant on its schema. Every API request and readiness then gets a distinct, named state saying that waiting will not help, never `installing`. Install reads the grant back after granting it and fails loudly if the grant did not take. The schema name is derived, not typed in by hand. Readiness still reports only three things: installed, the version stamp, and whether install is running.
- **Release bundle:** the npm third-party license notices ship inside the served root, next to the code they cover.
- **CI on every push:** every tool it invokes is pinned, including the Python interpreter and `markdownlint-cli2`. Shell scripts are syntax-checked under the shells they declare. No test may be a known flake; the connectivity probe's abort-timeout test is where the flake reproduced.
- **The smoke script signs out the token pair it mints before it exits.** It also runs against the live instance as the per-story gate, not only against throwaway containers.
- **Twelve routed ledger entries bind**, each addressed or declined with a written reason. They fall into four groups:
  1. Install and gate truth (DW-234, DW-96).
  2. Release readiness (DW-217, DW-126).
  3. CI reliability (DW-230, DW-229, DW-218, DW-215), plus the smoke session (DW-228).
  4. Behaviour only a source-text assertion or nothing observes (DW-207, DW-213, DW-222). DW-207 and DW-213 need seams: an overridable roster for the unexercised `RosterNames` refusals, and a Fixture namespace seam. DW-222 needs executing assertions over the announcement changes and the server-flag disclosure.

## Technical Decisions

- **Test and CI stack.**
  - Client runners: `node --test` over `ui/tools/*.test.mjs` for the framework-free layer; vitest + jsdom for components. jsdom computes no layout, so geometry belongs to puppeteer driving a pinned headless Chrome against a throwaway container.
  - CI runs three GitHub Actions jobs. `gates` runs once per `engines.node` band, at each band's floor. `instance` runs against a throwaway container. `images` runs on both stock Community editions.
  - CI fails on any CDN reference and on embedded Python in a shipped class.
- **Install gate semantics.** The API refuses with a clear state and never serves a partial schema. Upgrade is install again, so guard-then-act against a populated instance is the daily path. The health check turns healthy only once this start's install has recorded success. Each start's `installing` mark is best effort and never blocks the start. On the IPM path nothing marks; that window is accepted because IPM is a distribution channel, not the shipped install path.
- **IRIS security facts.**
  - `Security.Users.Create` silently accepts a role that does not exist, so a grant must be read back before it is believed.
  - Create a `%DB_*` resource before its database.
  - A test that proves denial uses a purpose-built role, never `%Operator`.
  - OcuPilot's globals, and only its globals, sit behind the protected resource. Storage classes gain its role through a privileged routine application inside `New $ROLES`, and nothing is spawned or re-entered from an escalated frame.
- **Readiness** lives on a third, unauthenticated web application under the API prefix, with its own dispatch class and one read-only role. The install surface is driven by the roster, and `module.xml` is generated from it under a drift check.
- **Sign-out** is `POST /api/ocupilot/logout` carrying both the Bearer and the cookie, and it always means "sign out of the instance".
- **Extend the singletons; never add a second:** one response and error writer, one router and gate, one installer, one string source, one protected-state mechanism.
  - The error envelope is flat `{error, reason, code, detail}`. `code` is a stable dotted-uppercase identifier that is never reworded.
  - A `%Persistent` class name is at most 29 dotted characters.
  - Non-ASCII in string sources is written as `\uXXXX`.
- **Tests:** every handler gets an HTTP integration test over status, content type and body shape. No test class has a property whose name begins with `Test`.

## UX & Interaction Patterns

- EXPERIENCE.md's Fixed strings table is canonical and verbatim. The shell already renders strings that have no row there: area names, permission-denied, status-bar labels, filter and result-group labels, the connectivity failure copy, the refresh-rate chip, and the classic-link card caption. Those strings get rows in the table; they are never invented at the component.

## Cross-Story Dependencies

- **1.1–1.17 are done** and underpin 1.18. Use their singletons, the connectivity service's probe and backoff, and the roster; do not replace them. 1.18 closes before Epic 2 starts.
- **Epic 1 residue routed to later stories is out of scope here:**
  - 2.1: the gate's uncached SQL round trip (DW-60).
  - 2.3: the UrlMap route-order check and `DontConnect` on namespace listing (DW-32, DW-156).
  - 2.5: shell navigation, skip link and the dead primary action (DW-148, DW-149, DW-153).
  - 2.6: one shared link-out corpus (DW-186).
  - 3.8: RoleGranted re-emitted on every install (DW-44).
  - 6.3: the demo X.509 pair (DW-49, DW-233).
  - 15.3: a real build identity (DW-3).
  - 17.2: tests compiled by the start hook, the smoke port behind an external gateway, and the throwaway scratch-root guard (DW-48, DW-216, DW-235).
  - 18.13: Uninstall's half-state paths (DW-219).
- **Other epics:** Epic 17 re-runs the same smoke script from a clean clone. Epic 2 builds the admin-API port that Epic 1 only checks is present.
