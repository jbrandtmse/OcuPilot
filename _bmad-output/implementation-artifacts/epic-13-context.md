# Epic 13 Context: Bonus deliverables and engineering hygiene

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

The entry has to read as finished rather than as a demo: an operator who evaluates OcuPilot and decides against it can remove it and be left with the instance they started with, the test suite keeps pace with the code through the voting week so a polish-week change cannot silently break a Release 1 screen or a Release 1 agent write, and the package is installable from the community registry in one command against a source the operator already trusts. This is polish-week hygiene ranked after the OAuth editors, and it builds on install machinery that already exists — the installer, its generated roster, the smoke path and CI are all Release 1 work. The optional bonus items that once sat here (a Developer Community article, a video, a short, and re-planning against the technology-bonuses post) were scratched by the owner on 2026-09-19; nothing beyond the entry itself is produced before the deadline.

## Stories

- Story 13.1: The uninstall hook
- Story 13.2: The test suite grows in CI against a stock image
- Story 13.3: Publish the package to the community registry (**held by the owner**)

## Requirements & Constraints

- **Uninstall removes everything install created, and nothing else.** Both web applications and the readiness application, the administrative resource and its role, the application roles the unauthenticated applications carry, the audit event types, the scheduled tasks, the protected state database and its guarding resource, and the demo fixture where install created one. Anything IRIS owns stays — in particular the audit database keeps its rows, OcuPilot's agent markers included, because those are the instance's record and not OcuPilot's.
- **Guard-then-act in both directions.** A target that is already absent makes uninstall return OK, not fail. This is the exact gap the harvested sibling installer left, and it is the reason the hook is written here rather than ported.
- **Install and uninstall are symmetrical.** Uninstall then install must reach a working OcuPilot again, which is also what re-arms the container start path's first-install behavior.
- **Uninstall must not remove a fixture it did not create.** A pre-existing `/csp/myapp` is left exactly as it is and reported; only a fixture install created is removed.
- **CI runs against a stock image**, executing the ObjectScript unit and HTTP integration suites, the client unit tests, and the endpoint-inventory fixture.
- **Coverage floor, then growth:** at least one test per OcuPilot API endpoint, the confirmation-binding tests, the state-protection test and the audit-marker round trip. Every polish-week change must leave the suite proving that no Release 1 screen and no Release 1 agent write regressed.
- **Admin API drift is caught by a test, not by a user.** The published admin API specification is vendored with its commit SHA, and a test diffs its v2 path and method set against the instance's own generated spec so a 2027.1 change fails with a named source.
- **The registry publish is held.** Every acceptance condition must be satisfiable without contacting the registry: the archive is produced by the publish path's dry-run form, and proven by installing that local file on a fresh instance that has IPM. Nothing reads, configures, requests or uses a registry credential, and the story is never reported done by having published — a gate that can only be closed by publishing is an unmet gate, to be escalated. The release is the owner's alone, and remains under the stealth policy until it.
- The archive carries the built Angular bundle, so installing it needs no Node toolchain.

## Technical Decisions

- **All install and uninstall logic lives in the one `Installer` class** reached from two entry points — the container start path and an IPM invoke. Uninstall belongs there too, not in a slice; the install path is owned by `Install/`.
- **The class roster the installer compiles and the IPM manifest's resource list are generated from one source.** The manifest can therefore never have drifted from what actually installs, and any story touching either edits the generator, not both lists.
- **IPM is a distribution channel, never a runtime dependency.** The shipped image carries no loaded IPM, and nothing in the install path may assume it; the module exists for instances that already have it. Anything proving the archive needs an instance where IPM is present, which is not the default container.
- **The smoke script is the definition of "installed and working"**, and it is also the container's health check and what CI runs. Extending coverage extends that one path rather than adding a parallel notion of "working".
- **Code lives in the install namespace's normal database; only OcuPilot's globals live behind the guarding resource.** Uninstall therefore tears down a database that holds data only — but the resource, the role and the privileged routine application that reaches it all have to come down with it, in an order that does not leave the storage classes reachable or the database mounted-but-orphaned.
- **The endpoint-inventory fixture is a test that re-derives itself from the running instance**, and the admin-API dependency is confined to one port file. Spec-drift work extends that fixture rather than introducing a second source of truth about the vendor API.
- **Install is idempotent and upgrade is "install again"**, so any change made here has to stay safe against a fully populated instance and fast enough to run on every container start.
- Deleting OcuPilot's own web applications, resource, role or database is a **prohibited agent action** — uninstall is an operator act through the install path, never something the agent can be made to propose.
- The container image is pinned to an explicit version tag rather than a floating alias, so a vendor change is a deliberate act with a test run attached; CI additionally runs the stock Community editions and pins every action to a full commit SHA.

## Cross-Story Dependencies

- The epic depends on **Epic 1 alone** (the installer, the generated roster, the smoke path, the readiness endpoint, CI). It was joined to the parallel run on that basis.
- Story 13.1 must know everything install creates, so it is written against the generated roster rather than a hand-kept list; anything a later epic adds to install has to be removable by the same hook.
- Story 13.2's suite is what proves 13.1's install/uninstall symmetry, and both feed the smoke path CI already runs.
- Story 13.3 is sequenced last and is held: it consumes the same generated manifest as 13.1 and 13.2, and its dry-run archive is only meaningful once the install path it packages is green.
- Two ledger items once routed here are **re-owned to Epic 5** and are not this epic's work: the browser spec that holds a detached element handle across a re-render, and the browser suite losing a different single test per CI run. Epic 5 owns `ui/browser/**`.
