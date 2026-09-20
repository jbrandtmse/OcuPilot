---
title: 'Story 13.2: The test suite grows in CI against a stock image'
type: 'feature'
created: '2026-09-19'
status: 'draft'
baseline_revision: '74369aaac58bacb8281f36ac0396b9b4aac1de1a'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** CI already runs the ObjectScript sweep, the client suite, the smoke path and the endpoint-inventory fixture against a throwaway container on a pinned stock image, but nothing holds the suite's *coverage* to a floor: a route can be added with no test, the vendor's published admin API specification is not in the tree at all, and the throwaway's fixed host port can kill the instance job before a test runs.

**Approach:** Add three derived-versus-declared gates that fail naming what is missing — an endpoint-coverage floor that derives the route set from the compiled `UrlMap`s and requires a declared probe per route; a vendored `mainspec_v2.json` with its commit SHA and a path/method differ against the instance's own generated spec; and a hardened, measured throwaway bring-up. No gate is a proxy: each is a both-directions equality whose mutation is a one-line deletion.

## Boundaries & Constraints

**Always:** Derive one side of every new gate from the structure (the compiled `UrlMap`, the vendored file's bytes, the arming roster in source) and hold it equal to a reviewed declared list, the `ALLOWED_ABSOLUTE_URLS` / `DECLARED_GATES` idiom this tree already uses. Every new `run:` step in `.github/workflows/ci.yml` gains its matching entry in `ui/tools/ci.test.mjs` `DECLARED_GATES` in the same edit. Slot B throughout: `server: "ocupilot-slot-b"`, container `ocupilot-slot-b`, throwaway `ocupilot-b-ci` (already up — reuse it, never tear it down).

**Never:** Edit any existing file under `src/OcuPilot/Test/**`, `ui/browser/**`, `scripts/check-objectscript.py`, `src/OcuPilot/Install/Smoke.cls`, or any existing `src/OcuPilot/Kernel/**` file — all contended with Epic 5 (Clarifications below). Never move the throwaway's published ports (52776/1975) — `CLAUDE.md`, `_bmad/custom/parallel.yaml` and every concurrent runner's spawn prompt carry them. Never add a registry, publish, release or `secrets.` step to CI (stealth policy; `ci.test.mjs` asserts each absence). Never run two `iris_execute_tests` calls in one message.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Endpoint floor, steady state | The 37 routes the three `UrlMap`s declare; a probe row for each | The coverage class issues each probe and asserts every response is an OcuPilot envelope, never the router's route-not-found | No error expected |
| Endpoint floor, route added with no probe | Epic 5's `/proposal/:id/confirm` merges forward | Red, naming the route and "add a probe row" | Fails the class, not the job silently |
| Endpoint floor, probe row for a route that no longer exists | A route deleted from `Router.cls` | Red, naming the orphan probe row | Both-directions equality |
| Admin spec differ, steady state | `spec/mainspec_v2.json` @ `f764aea` vs `GET /api/mgmnt/v1/%25SYS/spec/api/admin` | 185 v2 paths each side, 184 common, 0 method-set differences, 1 declared known difference → exit 0 | No error expected |
| Admin spec differ, 2027.1 drift | Instance gains, loses or re-methods a v2 path | Exit non-zero naming the path, the method set, and the vendored commit SHA as the source | Named source, never a bare mismatch |
| Admin spec differ, vendored file hand-edited | Bytes no longer hash to the recorded sha256 | Exit non-zero naming the provenance mismatch | Closes the "edit the fixture to make it green" escape |
| Throwaway bring-up, host port already bound | `docker compose up` fails naming a host-port bind | Bounded retry after a `down`; on exhaustion, exit naming the port and the measured ephemeral range | Retries **only** on a bind message — any other failure exits at once |
| Smoke run with a failing check (DW-1119, DW-1079) | The report carries `fail  wallet -- ...` | `smoke.sh` prints one quotable line naming every failing check | Exit 1 unchanged |
| Arming roster drift (DW-1276) | A 15th class arms `OCUPILOT_ALLOW_PRODUCTION_INSTALL` | `ci.test.mjs` red, naming the class the comment omits | Derived-vs-declared |

</intent-contract>

## Code Map

- `.github/workflows/ci.yml:96-151` — the `instance` job. Steps land between `wait for readiness` (`:123`) and `smoke` (`:128`); the ephemeral-range probe goes **before** `ci-throwaway.sh up` (`:121`) so it is on the record for a run that dies there. `:49-94` `gates`, the three-band matrix. **Ours.**
- `ui/tools/ci.test.mjs:102-124` — `DECLARED_GATES`, one entry per occurrence, held equal to the workflow's `run:` lines in both directions (`:193`, `:212`, `:218`). `:1398-1437` — the five-sites port equality, already Rule-19 falsifiable; extend it, do not duplicate it. **Ours.**
- `scripts/ci-throwaway.sh:228` — `docker compose -f "$COMPOSE_FILE" up -d --wait`, the single bind point. `:26-27` `WEB_PORT`/`SUPER_PORT`. `:177-193` — the stale arming-roster comment DW-1276 names ("twelve", enumerating twelve). `:169-176` — the `OCUPILOT_ALLOW_AUDIT_EVENTS` comment that omits `UninstallSurvival`. `:114-132` — the copy-and-mount block; `spec/` is **not** mounted and does not need to be. **Ours.**
- `scripts/smoke.sh:169-194` — `$REPORT` is already extracted whole; `:184` is the non-quotable failure line. Report rows are `  <outcome padded to 9><name> -- <reason>` (rendered at `src/OcuPilot/Install/Smoke.cls:1199`, **read-only**), so the failing names are parseable here without touching the class. **Ours.**
- `ui/tools/client-lint.mjs:318-357` — `OFF_ORIGIN_URL_RE`, `ALLOWED_ABSOLUTE_URLS`, `checkOffOriginUrls`. `:531-551` — `lintClient()` runs family 3 over **every** file under `ui/src`, spec files included, which is why the specs use the concatenation idiom. `:416` — `checkTestingImports` already skips `.spec.ts`, the precedent for the exemption. **Ours.**
- `ui/src/app/shell/reply.spec.ts:15-16,47,54` and `ui/src/app/shell/panel.spec.ts:919,946,1875` — the eight concatenated-URL sites. **Read-only, and `panel.spec.ts` is Epic 5's** (changed on `origin/OCU-1-epic5`). The chosen fix requires no edit to either.
- `ui/src/app/core/reply.ts:161` — `url.protocol === 'http:'`, a comparison with no `+`. The new rule must not flag it; it is the one non-spec site the scheme literal appears at.
- `ui/tools/build-output.test.mjs:205,287` — "no harness code reaches the shipped bundle" and "no fetch-causing reference … names a host other than the instance's own origin". These are the bundle-level backstop that makes the spec-file exemption sound.
- `src/OcuPilot/Api/Router.cls:73-109` — 34 routes. `Api/Readiness.cls` — `GET /`. `Api/StaticHandler.cls` — `GET`/`HEAD` `/(.*)`. **Router.cls is changed on Epic 5's branch — read-only here**; the coverage class reads the compiled `UrlMap`, so it tracks Epic 5's additions automatically.
- `src/OcuPilot/Test/AdminInventory.cls:39-113,118-153,157-179` — the XData-plus-`Derive`/`Stored` comparison idiom to copy, including the `unreadable`-is-a-value discipline. `src/OcuPilot/Test/Inventory.cls:14` runs it. **Read-only: copy the idiom, do not edit.**
- `src/OcuPilot/Test/Http.cls:207` — `AbsoluteRequest(method, path, user, password, .status, .body, .headers, body, contentType, .extraHeaders, timeout)`, the probe vehicle. **Read-only** (see Clarifications).
- `src/OcuPilot/Install/Smoke.cls:639-676,1153-1171,1189-1220` — the `wallet` / `demofixture` check names and the `Render` row format DW-1079's residual surfaces through. **Read-only.**
- `ATTRIBUTIONS.md:36` — the "InterSystems material" section the vendored spec's row belongs under.
- `ui/tools/stub-bin.mjs` — `writeStub` / `stubEnv`, imported by `ci.test.mjs:34` and used to drive a stubbed `docker` at `:901`. The vehicle for falsifying the bring-up retry without a container, and for the smoke-report fixture: `ci.test.mjs:1080,1092,1191` already execute `scripts/smoke.sh` this way.

## Tasks & Acceptance

**Execution:**

- `spec/mainspec_v2.json` — create; vendor `intersystems-community/sysadmin-api-specification` @ `f764aea427e5c0b1dd08a4c18a0457e0ff7b3b34` verbatim (1,004,473 bytes, sha256 `1ab154c7c5d9b25e6b227944a44a120c670686f876c2e14abfb9ee5898596650`, OpenAPI 3.0.0, 190 paths of which 185 are `/v2/*`) — AC4's named source.
- `spec/mainspec_v2.provenance.json` — create; `{repository, commit, path, fetchedAt, bytes, sha256}`. Machine-readable so the differ can refuse a hand-edited fixture.
- `ui/tools/admin-spec.mjs` — create; pure `diffAdminSpec({vendored, instance, knownDifferences})` returning added/removed v2 paths and per-path method-set differences, plus a thin `main()` that verifies the sha256, fetches `<origin>/api/mgmnt/v1/%25SYS/spec/api/admin`, and exits non-zero naming the vendored commit as the source. `KNOWN_DIFFERENCES` carries exactly one reviewed entry (below). Pure/impure split per `client-lint.mjs`'s own convention.
- `ui/tools/admin-spec.test.mjs` — create; drives the pure half against fixtures in `gates` (no instance), and asserts the vendored bytes hash to the recorded sha256.
- `src/OcuPilot/Test/EndpointCoverage.cls` — create; `Derive` reads every OcuPilot dispatch class's compiled `UrlMap` into `(method, url)` rows, `Stored` reads a declared `<probe/>` XData table, the two are asserted equal **in both directions**, and each probe is issued through `OcuPilot.Test.Http.AbsoluteRequest` and asserted to dispatch (an AD-12 envelope, never route-not-found). `:param` probes use the literal id `ocupilot-coverage-probe`; write-verb probes send a body chosen to draw a validation refusal, so the class performs no write. Header states what it pins and what it needs from the environment; no arming variable is needed because it mutates nothing.
- `scripts/ci-throwaway.sh` — edit; wrap the `up -d --wait` at `:228` in a bounded retry (3 attempts) taken **only** when the captured output names a host-port bind, with a `down` between attempts and a final message naming the port; correct the arming-roster comment at `:177-193` to fourteen classes and add `UninstallSurvival` to the `OCUPILOT_ALLOW_AUDIT_EVENTS` list at `:169-176` (DW-1276).
- `scripts/smoke.sh` — edit; parse `$REPORT` for rows whose outcome is `fail` and print one quotable line, `smoke: FAILED check(s): <name>[, <name>]`, before the existing exit 1 (DW-1119; DW-1079's residual becomes a named `wallet` / `demofixture` failure).
- `ui/tools/client-lint.mjs` — edit; exempt `*.spec.ts` from rule family 3 with the reason in the rule's comment, and add concatenated-scheme detection (a string literal spelling `http:`, `https:` or a `//host` fragment adjacent to `+`) for every non-spec file. `reply.ts:161`'s comparison must stay green (DW-1087).
- `ui/tools/client-lint.test.mjs` — edit; fixtures for both halves — a concatenated URL in a non-spec file fails, the same text in a `.spec.ts` passes, `url.protocol === 'http:'` passes.
- `.github/workflows/ci.yml` — edit; `instance` gains an ephemeral-range probe step before the throwaway `up` (DW-439's named measurement) and a `node tools/admin-spec.mjs --origin http://localhost:52776` step after readiness.
- `ui/tools/ci.test.mjs` — edit; the two new `DECLARED_GATES` entries, and a derived-versus-declared assertion that `ci-throwaway.sh`'s arming-roster comment names exactly the classes that reference each arming variable in `src/OcuPilot/Test/` (DW-1276's durable half — `check-objectscript.py` is pattern-based and cannot catch a stale roster, and is Epic 5's file besides).
- `ATTRIBUTIONS.md` — edit; a row under "InterSystems material" for the vendored specification: repository, commit, what it is, and that it is a test fixture never shipped in the bundle or the IPM archive.

**Acceptance Criteria:**

- Given the `instance` job on a stock pinned image, when CI runs, then it executes the ObjectScript unit and HTTP integration sweep (`ci-runner.mjs` over `OcuPilot.Test`), the smoke path, the browser spec and the endpoint-inventory fixture (`OcuPilot.Test.Inventory`), and `gates` executes the client suite once per declared Node band — **already true at baseline; this story asserts it rather than rebuilding it** (AC1).
- Given the route set derived from the compiled `UrlMap`s, when `OcuPilot.Test.EndpointCoverage` runs, then every route has a declared probe and every declared probe has a route, and each probe's response is an AD-12 envelope rather than route-not-found (AC2, first clause).
- Given the named floor members, when the sweep runs, then the state-protection suite (`OcuPilot.Test.State`) and the audit-marker round trip (`OcuPilot.Test.AuditRecord`, `OcuPilot.Test.AuditVerbs`, which read back from `%SYS.Audit`) are present and green, and the confirmation-binding member is carried by the coverage floor the moment Epic 5's confirm route merges forward (AC2, remaining clauses — see Design Notes).
- Given `spec/mainspec_v2.json` at the recorded commit, when the differ runs against the instance's generated spec, then the v2 path sets and every common path's method set agree except the one declared known difference, and any other difference exits non-zero naming the path and the vendored commit (AC4).
- Given a throwaway bring-up whose host port is already bound, when `ci-throwaway.sh up` runs, then it retries the bind a bounded number of times and, on exhaustion, exits naming the port; and the job's log carries the runner's measured ephemeral port range whether or not the bind succeeded (DW-439).
- Given a smoke run with at least one failing check, when `smoke.sh` reports, then its failure line names every failing check by name (DW-1119, DW-1079).
- Given a client source file that builds an off-origin URL by concatenation, when `client-lint.mjs` runs, then it fails naming the file; and the same text inside a `*.spec.ts` passes, under a stated exemption (DW-1087).
- Given `ci-throwaway.sh`'s arming-roster comment, when `ci.test.mjs` runs, then it is held equal to the classes that actually reference each arming variable, in both directions (DW-1276).

## Spec Change Log

- 2026-09-19, **orchestrator decision on the AC4 license question**: vendor the derived v2 path-and-method table, not `mainspec_v2.json`. The upstream repository declares no license (`license: null`, public, no LICENSE/COPYING/NOTICE at root, verified by the lead via the GitHub API), and **this repository is itself public**, so vendoring the 1 MB document is the redistribution regardless of what the bundle or the IPM archive contains - the plan's exclusion proposal measured the wrong boundary. A table of paths and methods is a set of facts about an API rather than the expressive document describing it, so option 3 moots the licensing question instead of requiring a ruling on it. Four constraints carry into the re-plan: (a) the table records the upstream **commit** SHA `f764aea427e5c0b1dd08a4c18a0457e0ff7b3b34` (last commit touching `mainspec_v2.json`, 2026-09-14T18:53:01Z; the file blob is `373e8627e755c0cb89fee855fb70514f48376d60`, 1,004,473 bytes; the repository's default branch is `master`, not `main`), because the SHA is what makes a drift attributable to a named source; (b) the table is **derived by a checked-in script or documented one-liner**, never hand-transcribed, so the next reader re-derives rather than trusts - the table is the artifact, the derivation is the evidence; (c) `ATTRIBUTIONS.md` cites the repository, the commit SHA and the retrieval date, and states in one line that the document is deliberately not vendored and why; (d) the spec says plainly that the drift test pins **instance versus upstream-at-SHA**, which is what it actually tests - the criterion must not keep implying the whole document is present. If the owner later wants the full file vendored, that is the distributor's call and does not reopen this story: the table is a subset, not a contradiction.
- 2026-09-19, lead Rule 5 **tier-1 amendment (apply-and-report)**: acceptance criterion 3 in `epics.md` replaced. Previous wording: "Given any polish-week change / When it lands / Then the suite proves no Release 1 screen and no Release 1 agent write regressed." That is a negative over an open set with an unbounded subject, so it has no pinning test short of deleting the suite (Rule 19), and its second half quantifies over the Release 1 agent write set, which has no members on this branch. Amended to the plan's recommended form, keyed to two closed derivable sets, with a both-directions derived-versus-declared check. **Intent unchanged** - a polish-week change still may not silently break a Release 1 screen or agent write; the amendment makes that measurable and falsifiable. The write half becomes binding at the Rule 22 integrate-forward once Epic 5 lands, with no change to the mechanism.
- 2026-09-19, lead **Rule 20 spine write**: AD-27's clause "its 185 v2 paths match the 2026.2 instance's own generated spec path for path" corrected at origin. Re-measured by the lead, not taken from the plan: the upstream blob `373e8627` declares 185 `/v2/*` paths, the instance's generated spec (`GET /api/mgmnt/v1/%25SYS/spec/api/admin` on `ocupilot-b-ci`, HTTP 200, 305 paths) declares 185, **184 are common**, and the HTTP method set is identical on all 184. The single difference is `/v2/security/oauth2/revoke` upstream versus `/v2/security/oauth2/server/revoke` on the instance. A first naive diff of mine reported 75 method-set differences; those were OpenAPI's path-level `parameters` key, not HTTP verbs - counting verbs only, 0, which is what the plan reported. Recorded so the wrong number is not mined later.

## Review Triage Log

## Design Notes

**Governing ADs.** AD-27 (the inventory fixture re-derives from the instance; the image tag is pinned; the admin API is experimental and `mainspec_v2.json` is its published specification), AD-45 (one smoke path, which is also the health check — extend it, never add a parallel notion of "working"), AD-18 (IPM is a distribution channel; nothing new here may become a runtime dependency), AD-12/AD-39 (one envelope — the coverage floor's evidence that a route dispatched), AD-25 (the demo fixture is opt-in; the `wallet` and `demofixture` checks skip without it), AD-38 (readiness, which the instance job already waits on), AD-17 (one roster generates the installer's class list and `module.xml`), AD-21/AD-47/NFR-10 (why `no-off-origin-url` exists at all). Stack rows: **CI** (three jobs; `gates` once per `engines.node` band floor; every `uses:` pinned to a full commit SHA), **Admin API** (`/api/admin` v2, pinned), **CI tool pins**.

**Integration ACs (Rule 1) and linkage (Rule 2).** This story introduces three shared checkers. `Consumes:` Story 1.17 (CI's three jobs, `ci-runner.mjs`, `smoke.sh`, `ci-throwaway.sh`), Story 1.16 (`module.xml` generated from `Install/Roster.cls`), Story 13.1 (the two new production-install test classes DW-1276 counts). `Consumed-by:` the `instance` and `gates` jobs are the consumers, in this story — each new checker is wired into a CI job that runs it on every push, and `ui/tools/ci.test.mjs` holds the wiring equal in both directions, so "consumer X reads from this and produces observable effect Y" is satisfied inside this story rather than deferred. Story 13.3 consumes the same roster and the green install path this floor protects.

**Why a probe table and not a source scan.** The obvious design — grep `src/OcuPilot/Test/**` for path literals and match them to routes — fails on this tree: the call sites are overwhelmingly indirect (`..#APIBASE _ pSuffix`, `pMethod`, `tPath`), so a scan would attribute coverage it cannot see and miss coverage that exists. That is the counted-by-substring pitfall `CLAUDE.md` records. Deriving the route set from the compiled `UrlMap` and **issuing each probe from the coverage class itself** makes "at least one test per endpoint" literally true, self-maintaining across Epic 5's route additions, and falsifiable by deleting one row.

**Why the admin-spec differ is a node tool in the `instance` job.** It needs both the vendored file from the checkout and the instance's generated spec. As an ObjectScript class it would need `spec/` mounted into the throwaway *and* into `docker-compose.yml` (outside this story's footprint), and DW-197 already showed what an "absent file → skip" guard costs. As a node step it reads the tree CI checked out and the throwaway's published port, needs no mount, and its pure half runs in `gates` with no instance. It is not a second source of truth about the vendor API (the epic context's concern): it compares two existing sources and names one known difference.

**The one known difference, measured 2026-09-19 against `ocupilot-b-ci`.** Vendored: 190 paths, 185 of them `/v2/*`. Instance (`GET /api/mgmnt/v1/%25SYS/spec/api/admin`, HTTP 200, 305 paths): 185 `/v2/*`. Common: 184. Method-set differences across the 184: **0**. The single difference is upstream `/v2/security/oauth2/revoke` versus the instance's `/v2/security/oauth2/server/revoke` — the same class of spec-versus-instance disagreement recorded on 2026-09-16 for the OAuth client `ServerDefinition` field, where the instance wins. **Spine correction for the lead (Rule 20):** AD-27's bullet reads "its 185 v2 paths match the 2026.2 instance's own generated spec path for path"; measured, 184 of 185 match. `bmad-build-auto` cannot amend a planning artifact, so this is recorded here for the lead to correct at its origin.

**License flag for the lead.** `intersystems-community/sysadmin-api-specification` declares **no license** (`license: null` on the GitHub API, 2026-09-19). Vendoring it is mandated by AC4, so this is a fact to record rather than a decision to take: it is InterSystems' own published contest specification, redistributed unmodified with its repository, commit and hash recorded, kept under `spec/` as a test fixture, and never copied into the bundle or the IPM archive (no `<FileCopy>` reaches it). The `ATTRIBUTIONS.md` row is the Rule-5 tier-1 bookkeeping that goes with it; whether the absent license needs anything more is the lead's call.

**DW-1087's fix shape, and why it touches no spec file.** Widening family 3 to the concatenated form would redden eight existing sites, six of them in `panel.spec.ts`, which Epic 5 has changed. So the rule is widened for non-spec files **and** `*.spec.ts` is exempted from family 3 with the reason stated in the rule's comment — the ledger's own named alternative. The exemption is sound because a spec file is not shipped: `build-output.test.mjs:205` asserts no harness code reaches the bundle and `:287` asserts the emitted CSS and `index.html` name no other host, so the shipped-document guarantee the rule exists to give is enforced on the artifact as well as the source. `checkTestingImports` (`:416`) already skips `.spec.ts`, so the exemption is the file's existing precedent rather than a new one.

**DW-439: measure, then harden without moving a port.** The entry's own note says the cause is an inference, and names the probe. The probe becomes a permanent `instance` step, so the next occurrence is measured rather than re-inferred. The fix is deliberately *not* "take ports below the ephemeral range": 52776/1975 are written into `CLAUDE.md`, `_bmad/custom/parallel.yaml` and the spawn prompt of every concurrent runner, so moving them is a cross-epic coordination this story has no authority for (Rule 11). A bind-message-gated retry is correct whatever the measurement says and is local to one file the suite already holds equal across five sites.

**DW-1079, re-scoped.** The stated cause was refuted by measurement before planning: no `Test/Wallet*` class exists anywhere in `src`, and `%Wallet.Collection` held `OcuPilotDemo` before, during and after all 132 classes on the demo-enabled throwaway, so no test deletes it. The residual — whether something other than a test leaves a demo-enabled instance without the collection across a source refresh — is not a suite defect and cannot be closed by a test. It is addressed at the only place it is observable: after DW-1119's fix, such an instance produces `smoke: FAILED check(s): wallet`, a named, quotable line, instead of an unattributable red. That converts an untriageable symptom into a named one, which is what the entry asks for.

**Declined — the file belongs to a concurrently running epic (Epic 5, head `f80fca6`, diffed against merge-base `1f5f1c3`):**

- Declined DW-419: `scripts/check-objectscript.py` is changed on Epic 5's branch; the durable half of its concern is covered instead by the derived arming-roster assertion in `ci.test.mjs`.
- Declined DW-1172: `src/OcuPilot/Kernel/Audit/Ledger.cls` is changed on Epic 5's branch.
- Declined DW-1015: `ui/browser/**` is Epic 5's (10 files changed there).
- Declined DW-1146: `ui/browser/**` is Epic 5's.
- Declined DW-1223: `ui/browser/**` is Epic 5's; its five error-log timeouts did not reproduce in run `35477669085` and the non-reproduction is already recorded on the entry.
- Declined DW-429: needs a handler seam in `Kernel/` that a previous story refused, and Epic 5 is active across `Kernel/`.
- Declined DW-1156: re-owned to Epic 5 by the orchestrator and repaired there (`5f1a7a3`).
- Declined DW-1175: re-owned to Epic 5 and repaired there (`5f1a7a3`); a duplicate of DW-1169, which is inherited and expected on this branch (browser spec 185/186, `Cap follows agent-switch`) and is not this story's to fix.

**Addressed:** DW-439, DW-1087, DW-1119, DW-1276, DW-1079 (above); DW-414, DW-420, DW-421 — three coverage gaps whose pinning tests are **new** classes, so they need no contended edit: DW-414 drives AD-37's repoint clause in both directions, DW-420 gives the credential-ladder license condition a seam its assertion does not recompute from the same three sources, DW-421 drives the four undriven error-handling shapes on the credential and definition handlers. Each is one new class under `src/OcuPilot/Test/`, each carrying its own `mutation:` line.

**Clarifications for the lead — named, not planned around:**

1. **AC3 is an intent gap (Rule 5).** See `## Auto Run Result`.
2. `src/OcuPilot/Test/Http.cls` is not itself changed on Epic 5's branch, but the footprint rule makes any edit to an *existing* file under `src/OcuPilot/Test/**` a Clarification. This plan needs **no** edit to it — `EndpointCoverage` calls `AbsoluteRequest` as it stands. Raised only so the boundary is explicit.
3. `src/OcuPilot/Install/Smoke.cls:1218` renders the same non-quotable line `smoke.sh:184` does. This plan fixes only the shell side, which is sufficient for DW-1119. If the lead wants the class-side line fixed too, that is a Clarification.
4. `ui/src/**/*.browser.spec.ts`, named in this epic's declared footprint, **matches nothing**. The browser specs are `ui/browser/*.browser-spec.mjs` (38 files) and that directory is Epic 5's. The footprint entry should be corrected or dropped.
5. AD-27's "185 v2 paths match … path for path" is off by one (above).
6. The vendored specification's upstream repository declares no license (above).

## Verification

**Shared runtime:** every destructive or instance-touching check runs against the **slot B throwaway `ocupilot-b-ci`** (52777/1976), which is already up and installed — reuse it, never tear it down, never touch `ocupilot`, `ocupilot-slot-*` or `ocupilot-ci`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Stateful test classes run **one class per tool call** (Rule 18 (3)): send one `iris_execute_tests`, wait for it to land in `%UnitTest_Result`, then send the next — never two in one message, never a re-submit on a client-side timeout.

**Commands:**

- `cd ui && npm run build` — expected: the six `prebuild` checkers pass, including the widened `client-lint.mjs`.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `admin-spec.test.mjs` and the extended `ci.test.mjs` and `client-lint.test.mjs`, then the component runner green.
- `cd ui && node tools/admin-spec.mjs --origin http://localhost:52777` — expected: exit 0, reporting 185/185 v2 paths, 0 method-set differences, 1 declared known difference.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` — expected: green (no edit to either).
- `bash scripts/lint-docs.sh` — expected: green, `ATTRIBUTIONS.md` included.
- `node tools/ci-runner.mjs --container ocupilot-b-ci` — expected: the full sweep green, `0 probe leftovers, 0 overlaps`, with `EndpointCoverage` and the three new coverage classes among the classes run. Baseline to beat: `132 class(es), 1269 test(s), 0 failed`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` — expected: `executed>0 failed=0`, exit 0.

**Rule 19 — pinning test and named mutation per criterion:**

- AC1 (CI shape) — pinning: `ci.test.mjs`'s `DECLARED_GATES` both-directions equality. `mutation: delete the "objectscript suite, one class at a time" step from ci.yml → ci.test.mjs goes red naming the divergence.`
- AC2 endpoint floor — pinning: `OcuPilot.Test.EndpointCoverage`'s both-directions equality plus its dispatch assertion. `mutation: delete one <probe/> row from the XData → the class goes red naming the uncovered route; delete GET /namespaces from Router.cls and recompile the package → red naming the orphan probe.` Recompile the **package**, not the class: an inherited method recompiled alone proves nothing.
- AC2 named members — pinning: the state-protection and audit-marker classes run in the sweep. `mutation: rename OcuPilot.Test.State's TestDeniedUserCannotRead method so it is not discovered → the sweep's class total drops and ci-runner.mjs's on-disk-versus-instance check names it.`
- AC4 — pinning: `admin-spec.mjs`'s differ. `mutation: remove one "/v2/..." path from spec/mainspec_v2.json → the provenance sha256 check fails first, naming the hand-edit; restore it and instead add a fabricated path to KNOWN_DIFFERENCES → the declared-versus-observed check goes red naming the entry that matches nothing.`
- DW-439 — pinning: `ci.test.mjs`'s five-sites equality, extended to the retry and the probe step. `mutation: delete the retry wrapper's bind-message guard so it retries on any failure → the stub-bin.mjs-driven test goes red; delete the ephemeral-range step from ci.yml → DECLARED_GATES goes red.`
- DW-1119/DW-1079 — pinning: a new test in `ui/tools/ci.test.mjs`, beside the three that already execute `scripts/smoke.sh` against a stubbed `docker` (`:1080`, `:1092`, `:1191`), driving it over a report fixture carrying one `fail` row. `mutation: drop the name from the quotable line → the test goes red on the missing name.`
- DW-1087 — pinning: `client-lint.test.mjs`'s two fixtures. `mutation: revert the concatenation branch of checkOffOriginUrls → the non-spec fixture passes and the test goes red; drop the .spec.ts exemption → the spec fixture fails and the test goes red.`
- DW-1276 — pinning: the derived arming-roster equality in `ci.test.mjs`. `mutation: remove UninstallSurvival from the OCUPILOT_ALLOW_AUDIT_EVENTS comment → red naming it.`
- DW-414/420/421 — each new class carries its own `mutation:` line beside its pinning assertion, written in the same pass that adds the test (Rule 19).

**Manual checks:**

- `git status --short` and `git diff --stat` byte-identical before and after every mutation is reverted, for each mutation above.
- No `run:` step, no `uses:`, no `secrets.` reference in `ci.yml` touches a registry, a publish, a release or an Open Exchange listing (stealth policy; `ci.test.mjs` asserts the absences and must stay green).

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**AC3 is unmeasurable as worded, and its second half has no subject on this branch.**

AC3 reads: *"**Given** any polish-week change / **When** it lands / **Then** the suite proves no Release 1 screen and no Release 1 agent write regressed."*

Two defects, neither of which can be planned around:

1. **"The suite proves no … regressed" is a negative over an open set.** A suite detects the regressions it carries assertions for; no suite proves the absence of regression. Under Rule 19 the criterion has no pinning test and no mutation short of deleting the whole suite, which is the definition of structurally unfalsifiable. Its subject, "any polish-week change", is an unbounded quantifier over changes that do not exist yet, so there is nothing to assert against.
2. **The "Release 1 agent write" set is empty at this story's baseline.** No write tool exists on `OCU-1-epic13` — `src/OcuPilot/Screen/Tool/` holds `Base`, `Classification`, `ErrorRead`, `FieldLists`, `Navigate`, `Read`, `Registry`, `ToolFields`. `Screen/Tool/Write.cls` and `Screen/Tool/WebAppUpdate.cls` arrive with Epic 5 (`origin/OCU-1-epic5`, `f80fca6`). Confirmation, which is what binds a write, arrives there too (`Api/Confirm.cls`, `Kernel/Proposal/Confirm.cls`, `Test/ProposalConfirm.cls`) and is also what AC2's "confirmation-binding tests" clause names. So half of AC3 quantifies over a set with no members here.

I have not invented a proxy for it. ACs 1, 2 and 4 are planned above to the ready-for-development standard and survive this halt unchanged.

**Recommended amendment** (both sets are closed and derivable — `OcuPilot.Screen.Registry.Descriptors()` enumerates the built screens, 41 descriptor classes today, mirrored to `ui/src/app/core/screens.generated.ts`; `OcuPilot.Screen.Tool.Registry.ListTools()` enumerates the tools with their `read`/`write` kind, which AD-22 requires every tool to declare):

> - **Given** the Release 1 screen set (every descriptor `Screen/Registry` declares built) and the Release 1 agent write set (every tool `Screen/Tool/Registry` classifies `write`)
> - **When** CI runs on any push
> - **Then** every member of both sets carries at least one pinning test the suite executes, held equal in both directions by a derived-versus-declared check, so a member gained with no test — or a test deleted from a member — fails CI naming the member.

That preserves the product promise ("a polish-week change cannot silently break a Release 1 screen or a Release 1 agent write") and makes it measurable, falsifiable and surface-anchored. Because the write set is empty until Epic 5 merges forward, the amended criterion is satisfiable here on the screen half and becomes binding on the write half at the Rule 22 integrate-forward, with no change to the mechanism.

Two further items for the same amendment pass, both recorded in `## Design Notes` with their evidence: AD-27's "185 v2 paths match … path for path" is off by one (measured 184 of 185; `/v2/security/oauth2/revoke` versus `/v2/security/oauth2/server/revoke`), and this epic's declared footprint entry `ui/src/**/*.browser.spec.ts` matches nothing.
