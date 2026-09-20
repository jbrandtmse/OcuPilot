# Epic 13 Context: Bonus deliverables and engineering hygiene

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

The entry has to read as finished rather than as a demo: an operator who evaluates OcuPilot and decides against it can remove it and be left with the instance they started with, the test suite keeps pace with the code through the voting week so a polish-week change cannot silently break a Release 1 screen or a Release 1 agent write, and the package is installable from the community registry in one command against a source the operator already trusts. This is polish-week hygiene ranked after the OAuth editors, and it builds on install machinery that already exists — the installer, its generated roster, the smoke path and CI are all Release 1 work. The optional bonus items that once sat here (a Developer Community article, a video, a short, and re-planning against the technology-bonuses post) were scratched by the owner on 2026-09-19; nothing beyond the entry itself is produced before the deadline.

## Stories

- Story 13.1: The uninstall hook (**done**)
- Story 13.2: The test suite grows in CI against a stock image
- Story 13.3: Publish the package to the community registry (**held by the owner**)

## Requirements & Constraints

- **Uninstall removes everything install created, and nothing else** — the web applications, the administrative resource and its role, the audit event types, the scheduled tasks, the protected state database and its guarding resource, and a demo fixture only where install created it. Anything IRIS owns stays, in particular the audit database's rows including OcuPilot's own markers, because those are the instance's record. Guard-then-act in both directions: an already-absent target returns OK. Uninstall then install must reach a working OcuPilot again.
- **CI runs against a stock image**, executing the ObjectScript unit and HTTP integration suites, the client unit tests, and the endpoint-inventory fixture.
- **Coverage floor, then growth:** at least one test per OcuPilot API endpoint, the confirmation-binding tests, the state-protection test and the audit-marker round trip.
- **Coverage is a both-directions check over two closed sets, not a claim about regressions.** The sets are every descriptor the screen registry declares built and every tool the tool registry classifies `write`. A derived-versus-declared check holds membership and test coverage equal in both directions on every push, so a member gained with no pinning test — *and* a pinning test deleted from a member that still exists — fails CI naming the member. "The suite proves nothing regressed" is a negative over an open set and is not implementable; this equality is its mechanical form.
- **The upstream admin API specification is deliberately not vendored.** The upstream repository declares no license (`license: null`, no LICENSE file) and this repository is public, so copying `mainspec_v2.json` in would be a redistribution nobody has granted. What is vendored is the **derived v2 path-and-method table**, carrying the upstream commit SHA, produced by a checked-in derivation that regenerates it from the upstream document — a set of facts about an API rather than the document describing it. It is cited in `ATTRIBUTIONS.md` with repository, SHA and retrieval date, and that entry states the document itself is not vendored.
- **Admin API drift is caught by a test, not by a user.** The test diffs the vendored table, pinned at that SHA, against the instance's generated spec (`GET /api/mgmnt/v1/%25SYS/spec/api/admin`), so a 2027.1 change fails naming its source. **The expected diff is not empty** and must be encoded as such: measured 2026-09-19, 185 upstream v2 paths, 185 on the instance, **184 common**, methods identical on all 184, the one difference being `/v2/security/oauth2/revoke` upstream against `/v2/security/oauth2/server/revoke` on the instance. A test written to expect exact equality is wrong the day it lands.
- **The registry publish is held.** Every acceptance condition must be satisfiable without contacting the registry: the archive comes from the publish path's dry-run form and is proven by installing that local file on a fresh instance that has IPM. Nothing reads, configures, requests or uses a registry credential, and the story is never reported done by having published — a gate closable only by publishing is an **unmet gate, to be escalated rather than closed**. The release is the owner's alone.
- The archive carries the built Angular bundle, so installing it needs no Node toolchain.

## Technical Decisions

- **All install and uninstall logic lives in the one `Installer` class** reached from two entry points — the container start path and an IPM invoke. It is never split into a slice.
- **The class roster the installer compiles and the IPM manifest's resource list are generated from one source**, so the manifest cannot have drifted from what actually installs; a story touching either edits the generator, not both lists.
- **Both halves of the coverage check are derived.** Screen membership and a tool's read/write classification are read from the registries themselves, never from a hand-kept list beside them, and the covered side is read from the tests CI actually executes. That is what makes the deletion direction detectable.
- **IPM is a distribution channel, never a runtime dependency.** The shipped image carries no loaded IPM and nothing in the install path may assume it, so anything proving the archive needs an instance where IPM is present — not the default container.
- **The smoke script is the definition of "installed and working"**, and is also the container's health check and what CI runs. Extending coverage extends that one path rather than adding a parallel notion of "working".
- **Code lives in the install namespace's normal database; only OcuPilot's globals live behind the guarding resource.** Uninstall tears down a data-only database, but the resource, the role and the privileged routine application reaching it come down with it, in an order that leaves nothing reachable or mounted-but-orphaned.
- **The endpoint-inventory fixture re-derives itself from the running instance**, and the admin-API dependency is confined to one port file. Drift work extends that fixture rather than adding a second source of truth about the vendor API; the vendored table is the upstream side of one comparison, not a second inventory.
- **Install is idempotent and upgrade is "install again"**, so any change here stays safe against a fully populated instance and fast enough for every container start.
- Deleting OcuPilot's own web applications, resource, role or database is a **prohibited agent action** — uninstall is an operator act through the install path, never something the agent can be made to propose.
- The container image is pinned to an explicit version tag rather than a floating alias; CI additionally runs the stock Community editions and pins every action to a full commit SHA.

## Cross-Story Dependencies

- The epic depends on **Epic 1 alone** (the installer, the generated roster, the smoke path, the readiness endpoint, CI). It was joined to the parallel run on that basis.
- Story 13.1 is done, written against the generated roster rather than a hand-kept list, so anything a later epic adds to install stays removable by the same hook.
- Story 13.2's suite is what proves 13.1's install/uninstall symmetry, and both feed the smoke path CI already runs. Its closed-set check reaches across every epic that declares a screen or a write tool, so it fails on other epics' additions by design.
- Story 13.3 is sequenced last and held: it consumes the same generated manifest as 13.1 and 13.2, and its dry-run archive is only meaningful once the install path it packages is green.
- Two ledger items once routed here are **re-owned to Epic 5** and are not this epic's work: the browser spec that holds a detached element handle across a re-render, and the browser suite losing a different single test per CI run. Epic 5 owns `ui/browser/**`.
