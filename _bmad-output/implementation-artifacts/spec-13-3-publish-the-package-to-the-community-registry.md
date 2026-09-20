---
title: 'Story 13.3: Publish the package to the community registry'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: 'f5588ae72fda83f9b4d403d702c9d7a704ce4625'
baseline_commit: 'f5588ae72fda83f9b4d403d702c9d7a704ce4625'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      epics.md still says the archive is produced by the publish path "running in its dry-run form";
      IPM 0.10.5 has no dry-run modifier on publish and the local `package` form is what exists
    evidence: |-
      Measured on the pinned image this pass: `%IPM.Main||Commands` declares `publish` with exactly
      `repo` and `use-external-name`, and the only `dry-run` in the grammar belongs to
      `run-from-file`. `package` exists, runs `Initialize,Reload,*,Validate,Compile,Activate,Package`
      and wrote an installable 1,083,507-byte `ocupilot.tgz` that loaded on a second fresh instance
      with smoke PASS. That run is the evidence the Spec Change Log's Clarification (1) asked for;
      the recommended correction at origin is "its dry-run form" -> "its local (`package`) form",
      at epics.md:5124 and again at :737. Planning artifact, so the lead's to amend, not this stage's.
    location: >-
      _bmad-output/planning-artifacts/epics.md:5124
    severity: medium
  - summary: >-
      CLAUDE.md says CI has three jobs; it now has four
    evidence: |-
      This story added the `package` job, so `.github/workflows/ci.yml` declares gates, instance,
      images and package, and `ui/tools/ci.test.mjs` holds that four-name list as an equality.
      README.md's own "Three jobs" sentence and table were corrected in this story's diff;
      CLAUDE.md is an agent-context file and was reserved for the lead by Spec Change Log (4).
    location: >-
      CLAUDE.md
    severity: low
  - summary: >-
      scripts/ci-image-compile.sh's floating-tag guard accepts `:latest-em`, the gap this story
      closed in its own script
    evidence: |-
      Its pattern is `*latest-cd*|*:latest`, so `intersystems/irishealth-community:latest-em` -- a
      tag InterSystems really publishes -- passes as explicit and AD-27 is not enforced.
      `scripts/ci-ipm-archive.sh` now refuses `*:latest|*:latest-*` and `ui/tools/ipm-archive.test.mjs`
      drives `:latest-em`; the same widening in ci-image-compile.sh is outside this story's three
      criteria and would need its own test pass.
    location: >-
      scripts/ci-image-compile.sh:44
    severity: medium
  - summary: >-
      IPM's exporter drops <SystemRequirements>, so the distributable archive carries no
      ">=2026.2" / ">=0.10.0" floor
    evidence: |-
      Measured by comparing the repository's module.xml with the one extracted from the produced
      archive: `<SystemRequirements Version="&gt;=2026.2" IPMVersion="&gt;=0.10.0"/>` is present in
      the first and absent from the second, alongside the already-known dropped `<Packaging>`.
      An operator installing the .tgz on an older IRIS therefore gets no refusal from the manifest.
      Not fixable in this story -- it is the exporter's behavior, not this script's -- and it belongs
      with the owner's release alongside DW-1300's listing metadata. The comparison deliberately
      excludes the element for that reason, and the script header records why.
    location: >-
      module.xml:24
    severity: medium
---

<intent-contract>

## Intent

**Problem:** OcuPilot's IPM manifest is generated and checked, but nothing in the tree ever *builds* the distributable archive or proves it installs: `grep` finds no publish path, no packaging step and no archive anywhere, and the only rehearsal is a hand-typed sequence in `README.md:652-668` whose outcome nobody records. The story that would close this is **held by the owner** — the publish itself is a public, irreversible act.

**Approach:** Build the archive with IPM's **local** packaging form, which contacts no registry, and prove it by installing that local `.tgz` on a second, genuinely fresh instance that has IPM — the same assertion the registry would have proven, taken one step earlier. Both containers run with **no network at all**, so "contacts no registry" is enforced by the runtime rather than promised by a comment. Nothing here publishes, and nothing here can.

## Boundaries & Constraints

**Always:** The archive is produced by `zpm "ocupilot package -path …"` and installed by `zpm "load <abs path>.tgz"` — the only two IPM verbs this story uses besides `list`. Both containers are throwaways of this story's own making, started from the pinned `intersystems/irishealth-community:2026.2` tag with `--network none`, no published port and no durable volume, and removed on an `EXIT` trap. Read every exit code directly, never through a pipeline (`cmd | tail` reports `tail`'s status). Slot B throughout: `server: "ocupilot-slot-b"`, dev container `ocupilot-slot-b`, throwaway `ocupilot-b-ci` (already up — reuse, never tear down).

**Never:** Contact a package registry; read, configure, request or use a registry credential or token; run `zpm publish`, `zpm install <module>`, `zpm repo`, `zpm enable -community` or `zpm search` in any form or under any flag. Never report this story done by having published. Never stop, remove, recreate or `down` `ocupilot`, any `ocupilot-slot-*`, `ocupilot-ci`, `ocupilot-b-ci` or `ocupilot-c-ci` — all six are running now and all are somebody else's. Never edit `src/OcuPilot/Install/Roster.cls` or `ui/tools/ipm-manifest.mjs`: AC2 is confirmed and pinned here, not rebuilt. Never add a `secrets.` reference, a `gh release`, an `npm publish` or the words "open exchange" to the workflow — `ui/tools/ci.test.mjs:323-339` refuses each by regex over the comment-stripped file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Archive build, steady state | Staged `src/`, `module.xml`, `ui/dist/ocupilot-ui/browser/`; stock 2026.2 image | IPM imported, module loaded, `package` writes one `.tgz`; the path is read from IPM's own `Module package generated:` line, never predicted | Exit non-zero naming the phase |
| Archive contents | The produced `.tgz` | Carries `module.xml`, the shipped `OcuPilot` classes and `ui/dist/ocupilot-ui/browser/`; carries **no** `OcuPilot/Test/` — `Scope="test"` is excluded | Exit non-zero naming the missing or unexpected member |
| Bundle not built | `ui/dist/ocupilot-ui/browser/` absent | Refused before any container starts, naming the directory and `cd ui && npm run build` | Exit 2, a caller error |
| Manifest drifted from the roster | `module.xml` hand-edited | `ipm-manifest.mjs --check` exits 1 naming the element, before staging | Exit non-zero, drift named |
| Local install, steady state | Fresh instance, IPM imported, `.tgz` copied in | `load` installs; `smoke.sh` reports PASS with at least one check executed | Exit code read directly |
| Local install, no demo fixture | IPM path, `OCUPILOT_DEMO` absent (AD-25) | `wallet` and `demofixture` report `skipped`, which is not a failure | Verdict is PASS |
| Local install, `_SYSTEM` expired | Fresh Community instance; the IPM `<Invoke>` deliberately never unexpires (AD-17, DW-92) | The script unexpires `_SYSTEM` **by name** as an operator act after install and before smoke, and says so | Without it every HTTP check reads 401 |
| A refused container name | `--build-name ocupilot-ci` (or any live/slot/throwaway name) | Refused before any `docker run`, naming the container | Exit 2 |
| A floating image tag | `--image …:latest-cd` or a reference with no tag | Refused (AD-27) | Exit 2 |
| Registry reachable | — | Not a scenario: both containers have no network, and the IPM verb set is a closed allow-list held equal in both directions | See AC3's honesty note |

</intent-contract>

## Code Map

- `module.xml` — 59 lines, generated, checked in. `<Name>ocupilot>` `:19`, **`<Version>0.1.0`** `:20`, `<SourcesRoot>src` `:23`, `<Resource OcuPilot.PKG>` `:25`, `<Resource OcuPilot.Test.PKG Scope="test">` `:26`, three `<WebApplication>` `:27-54`, the single `<FileCopy Name="ui/dist/ocupilot-ui/browser/" Target="${dataDir}csp/ocupilot/">` `:55`, `<Invoke … Phase="Activate" When="After">` `:56`. **No `<Dependency>`** — so `load` resolves nothing and searches no repository. No `<Author>`, `<License>` or `<Repository>` either (Design Notes). **Read-only here.**
- `src/OcuPilot/Install/Roster.cls` — `XData Manifest` `:81-160`; `module.version` `0.1.0` at **`:86` is the only source of the version string** in the tree (`ui/package.json:3`'s `0.0.0` is unrelated and nothing holds them equal). `Get()` `:168`. **Read-only.**
- `ui/tools/ipm-manifest.mjs` — 917 lines. `ROSTER_SOURCE` `:52`, `readRoster` `:85` (an unreadable roster returns `null`, never `{}`), `buildManifest` `:540-604`, `<Version>` emitted `:552`, `<FileCopy>` emitted `:585-589`, `expectedElements` `:417-423`, `--check` argument handling `:884-890`, drift output and `process.exitCode = 1` (never `process.exit`) `:895-906`. **Called, never edited.**
- `ui/tools/ipm-manifest.test.mjs` — 856 lines, 43 tests. `:545` pins that the committed `module.xml` is current; `:576` pins that `--check` is named in `prebuild`, `prestart` and the pre-commit hook; `:480` pins that IPM's strict SAX reader accepts the file. **No test pins a version value**, so nothing here forces a bump. **Read-only.**
- `scripts/ci-image-compile.sh` — 151 lines. **The precedent to copy, closely.** `--image` parsing `:34-40`, floating-tag refusals `:43-52`, live-name refusal `:53-56`, `cleanup`/`trap` `:58-61`, `docker run -d --name … -v …:ro` with no published port `:65`, the `until docker exec … iris session` readiness loop with a 300 s bound `:68-82`, the split-marker here-doc and `grep -o … | sed` extraction `:87-93` and `:101-118`, and the "a compile over nothing is a pass that means nothing" rule `:135-140`.
- `scripts/ci-throwaway.sh` — 346 lines. The staging idiom to copy: `mkdir` `:130`, `cp -R src/` `:136`, `cp module.xml` `:145`, `ui/dist` copied only if present `:146-149`, `chmod -R a+rX` `:154`. Refusal guards `:45-52` (live ports/name), `:56-68` (slot names, slot B and slot C ports), `:73-76` (`DIR` must be under a scratch root). Subcommand `case` `:114`. **Read-only here** — this story adds a sibling rather than a flag, so the six-site port equality at `ui/tools/ci.test.mjs:1412-1462` is untouched.
- `scripts/smoke.sh` — 214 lines. `--container NAME` → `RUNNER="docker exec -i $CONTAINER"` `:150-151`, so it drives a plain `docker run` container with no compose project and no published port. Verdict parsing `:157-181`, the DW-1079 failing-check line `:189-205`, "no verdict marker" `:208-212`. **Read-only here.**
- `src/OcuPilot/Install/Smoke.cls` — 1,225 lines. `Host()` `:255-258` returns `localhost`; `Port()` `:263-277` reads `Config.Startup.WebServerPort`; `Request()` `:299` uses `%Net.HttpRequest` against that loopback pair. **So the whole smoke path is loopback-only and works under `--network none`.** **Read-only** (Epic 13 holds `Install/**`, but DW-1119's non-quotable class-side line stays with `range-end-cleanup`).
- `.github/workflows/ci.yml` — 179 lines. Header policy `:20-24`. `gates` `:49-94` (matrix `:63-69`; six `run:` `:82-94`). `instance` `:96-164` (twelve `run:`; `npm ci` `:114`, `npm run build` `:117`; failure capture `:160-161`; `always()` teardown `:163-164`). `images` `:166-179` (matrix `:173-175`, one `run:` `:179`). **20 `run:` occurrences total.** The new job goes after `images`. **Ours.**
- `ui/tools/ci.test.mjs` — 2,092 lines. `DECLARED_GATES` `:102-131`, 20 entries, **one per `run:` occurrence**, duplicates deliberate (rationale `:133-137`); the both-directions equalities `:188-223`; "every file a gate command names exists" `:301-319`; **stealth absences `:323-339`**, whose seven regexes are `secrets\.`, `npm\s+publish`, `docker\s+push`, `docker/login-action|registry-url`, `softprops/action-gh-release|actions/create-release|gh\s+release`, `/open\s*exchange|openexchange/i`, `JS-DevTools/npm-publish|pypa/gh-action-pypi-publish`, matched against the **comment-stripped** workflow; the `continue-on-error` / `|| true` / `set +e` refusal `:341-353`; **`jobNames(workflow)` asserted `deepEqual ['gates','instance','images']` at `:408-409`** — this story's one required widening; `jobNames()` itself `:179-183`. **Ours.**
- `ui/tools/stub-bin.mjs` — 45 lines: `writeStub` `:12`, `stubEnv` `:21`, `captured` `:42`. The vehicle for driving the new script's refusals with a stubbed `docker` on `PATH`, so no container is created. Used that way at `ci.test.mjs:1292-1305` and `:1375-1380`.
- `README.md:574-683` — the IPM section. `:652-668` is the hand-typed rehearsal this story automates, and `:666` already records that `package … -path /tmp/out` writes **`/tmp/out.tgz`, a sibling of the directory named, not a file inside it**. `:670-673` records that the image ships IPM 0.10.5 offline and loads none of it. **Edited (one paragraph); a declared footprint extension.**
- **IPM 0.10.5, read from the shipped `/usr/irissys/dist/install/misc/zpm.xml` (1,493,796 bytes) rather than recalled.** The package prefix is `%IPM`, not `%ZPM`. Entry point `%IPM.Main:Shell(pCommand, pTerminateOnError, pHaltOnComplete)`; pass `0` for the third argument to run more than one command in a session. `package`'s phase chain is `Initialize,Reload,*,Validate,Compile,Activate,Package` — **no `Publish` phase and no repository lookup**; `%IPM.Lifecycle.Base:%Publish` itself calls `..Package()` first and only then resolves a server, so `package` *is* the publish path minus the upload. `load` accepts a directory, a `.tgz` or a `.tar.gz` and requires an **absolute** path. A `<FileCopy>` resource is carried into the export by `%IPM.ResourceProcessor.FileCopy:OnExportItem`, at the same repo-relative path, and fails the phase if the source directory is absent. On an offline import **no repository row is created** — `%IPM_Repo.Definition` is empty, and every repository read goes through one query over that table, so a local `load` reaches nothing.

## Tasks & Acceptance

**Execution:**

- `scripts/ci-ipm-archive.sh` — create. One script, the two phases in order, modeled line-for-line on `ci-image-compile.sh`'s shape (argument parsing, refusals, `trap cleanup EXIT`, the readiness loop, split markers, `grep -o`/`sed` extraction). Flags: `--image` (required; the same two floating-tag refusals), `--dir` (default `/tmp/ocupilot-ipm`, refused unless under a scratch root), `--build-name` (default `ocupilot-ipm-build`), `--install-name` (default `ocupilot-ipm-install`). Refuse either container name if it is `ocupilot`, matches `ocupilot-slot-*`, or is `ocupilot-ci` / `ocupilot-b-ci` / `ocupilot-c-ci`. Order: run `node tools/ipm-manifest.mjs --check` from `ui/` and stop on drift; refuse when `ui/dist/ocupilot-ui/browser/` is absent, naming it and `cd ui && npm run build`; stage `src/`, `module.xml` and the bundle into `$DIR/module/` at their repo-relative paths; `docker run -d --network none --name <build> -v $DIR/module:/opt/ocupilot:ro <image>`; wait for a session; `$System.OBJ.Load("/usr/irissys/dist/install/misc/zpm.xml","ck")`; assert `%IPM_Repo.Definition` holds **zero** rows; `Shell("load -dev /opt/ocupilot",1,0)`; `Shell("package ocupilot -path /tmp/ocupilot",1,0)`; take the artifact path from IPM's own `Module package generated:` line rather than predicting it; `docker cp` it to `$DIR/artifact/`. Then a **second** `docker run -d --network none --name <install> …` from the same image with `$DIR/artifact:/opt/ocupilot-archive:ro`; wait; import IPM; assert zero repository rows again; `Shell("load /opt/ocupilot-archive/<file>",1,0)`; unexpire `_SYSTEM` **by name** (`##class(Security.Users).UnExpireUserPasswords("_SYSTEM")` in `%SYS`), printing why; then `sh scripts/smoke.sh --container <install> --user _SYSTEM --password SYS` and read its exit status directly. Print one summary line and exit non-zero naming the phase that failed. A phase that executed nothing is a failure, never a pass.
- `scripts/ci-ipm-archive.sh` archive assertions — in the same script, host-side over the copied-out `.tgz` with `tar tzf`: it carries `module.xml`; it carries at least one `OcuPilot` class and the count is reported; it carries `ui/dist/ocupilot-ui/browser/`; it carries **no** path under `OcuPilot/Test/`. Each failure names the member.
- `ui/tools/ipm-archive.test.mjs` — create. Host-side, no instance, picked up by `npm test`'s `node --test tools/*.test.mjs` with no wiring. Pins, in the `stub-bin.mjs` idiom so no container is ever created: **both `docker run` invocations carry `--network none`** and publish no port; the set of IPM verbs the script issues, derived from its `Shell("` occurrences, equals the declared allow-list `{load, package, list}` **in both directions**, and the file contains none of `publish`, `install `, `repo `, `enable `, `search`, `-community`, `secrets.` or a token/credential environment variable; each refusal above (live, slot and throwaway container names; floating or absent image tag; `--dir` outside a scratch root; absent bundle) exits 2 with the offending value named; `ipm-manifest.mjs --check` runs before any staging; and the script reads `smoke.sh`'s status directly rather than through a pipe.
- `.github/workflows/ci.yml` — edit. A fourth job, `package`, on `ubuntu-24.04` with `timeout-minutes: 45`, after `images`: checkout, node setup at the pinned version the `instance` job uses, `npm ci`, `npm run build`, then `sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2`. No `secrets.`, no `continue-on-error`, no `|| true`, no step whose `name:` contains any of the seven forbidden tokens. It runs in parallel with `instance`, so it adds no critical path.
- `ui/tools/ci.test.mjs` — edit. Add the new job's `run:` entries to `DECLARED_GATES` in workflow order, one per occurrence; widen `:408-409`'s `jobNames` equality to include `package` and keep the assertion an equality, not a superset; extend the stealth-absences test so its seven regexes are also applied to `scripts/ci-ipm-archive.sh`, since a forbidden token in the script is as publishing as one in the workflow.
- `README.md` — edit. In the IPM section, one paragraph pointing `:652-668`'s hand-typed rehearsal at `scripts/ci-ipm-archive.sh` and saying the two containers have no network. Replace the sentences the script supersedes; do not append a paragraph explaining that they were superseded. **A declared footprint extension** (Design Notes).

**Acceptance Criteria:**

- Given the staged module and a stock pinned image, when `scripts/ci-ipm-archive.sh` runs IPM's local `package` form, then exactly one `.tgz` is produced without any registry contact, it carries `module.xml`, the shipped `OcuPilot` classes and `ui/dist/ocupilot-ui/browser/` and no `OcuPilot/Test/`, and loading that file on a **second, freshly created** instance that has IPM leaves `scripts/smoke.sh` reporting PASS with at least one check executed (AC1).
- Given the manifest, when the archive is produced, then `ipm-manifest.mjs --check` has already held `module.xml` equal to `src/OcuPilot/Install/Roster.cls`'s `XData Manifest` in both directions before anything was staged, and the manifest inside the archive declares the same module name, version, resource set, file copy and invoke as that roster — so a hand-edited manifest and an un-regenerated roster both fail before a container starts (AC2).
- Given that this story is held, when it is implemented, reviewed and reported, then both containers it creates run with no network at all, the IPM verbs it issues equal a declared three-verb allow-list in both directions, no registry credential or token is read, configured, requested or used, no publish is performed in any form, and the story is reported done on the archive and the local install alone (AC3).
- Given a pushed commit, when CI runs, then the `package` job executes the script on every push and `ui/tools/ci.test.mjs` holds its `run:` steps and the workflow's job list equal in both directions, so deleting the job or a step fails `gates` naming it (Integration AC).

## Spec Change Log

- 2026-09-20, lead spec gate. The plan's four Clarifications are answered here rather than deferred.
  **(1) AC1's wording stands unamended for now.** The recommended correction ("its dry-run form" -> "its local (`package`) form") is very likely right, but it rests on a reading of IPM 0.10.5's grammar recovered from the image's own `zpm.xml`, and the lead's independent extraction of that file did not complete. A criterion is not amended on an unverified claim: the implement stage exercises `package` directly, and if it works the correction is applied at origin **with that run as evidence**; if `package` does not exist or does not produce an archive, that is an `intent gap` to raise, not a wording fix. Nothing in the plan waits on this either way.
  **(2) `README.md` approved as a footprint extension** (Rule 11 (b)): outside Epic 13's declared footprint, owned by no contended epic, so it is edited and reported under `footprint_extensions:`. One paragraph.
  **(3) The missing listing metadata is filed as DW-1300** (`routed owner=range-end-cleanup`) rather than taken into this story: `module.xml` has no `<Author>`, `<License>` or `<Repository>`, the repository ships an MIT `LICENSE`, and the fix is a roster edit plus a regenerate. It belongs with the owner's release, which is the owner's alone.
  **(4) Widening `ci.test.mjs`'s job-list equality is this story's**, in its own footprint. `CLAUDE.md`'s "three jobs" sentence is a root-file factual correction the lead applies **after** the fourth job actually lands, reported under `footprint_extensions:` - the same discipline as (1): correct the record from what was observed, not from what is planned.

## Review Triage Log

### 2026-09-19 — Review pass

- verdicts: 49 findings — high 0, medium 26, low 17, false 6, maybe-false 0
- findings:
  - `[low]` `[reject]` blind-hunter: `-U HSCUSTOM` is hard-coded where `ci-image-compile.sh` detects the namespace — real, but every invocation in the tree passes the pinned IRIS for Health tag, and another edition surfaces as `wait_for_session`'s named 300 s failure with `docker logs` attached; the fix adds branches or a parameter.
  - `[medium]` `[patch]` blind-hunter: the archive-contents assertions are `-lt 1` floors, so an archive carrying 1 of 135 classes passes — fixed: both are now equalities against the staged tree (`CLASS_COUNT -eq STAGED_CLASSES`, and every staged bundle file by name), so neither side is a literal to maintain.
  - `[medium]` `[patch]` blind-hunter: `declarations()` compares neither `<WebApplication>` nor `<Dependency>`, and its single-line reader cannot see a multi-line element — fixed: `element_lines` flattens newlines and emits every attribute sorted, over Resource, FileCopy, Invoke, WebApplication and Dependency, plus an `<Arg>` count; the compared set went from 6 declarations to 11, and the new coverage is what the demonstrated AC2 mutation reddens.
  - `[medium]` `[patch]` blind-hunter: the zero-repository-row count is taken before the verbs it is offered as evidence about — fixed: `assert_no_repositories` re-reads it after the load and package verbs and after the archive install.
  - `[low]` `[reject]` blind-hunter: the default container names and `--dir` are not per-slot, so two concurrent runs collide — `--build-name`, `--install-name` and `--dir` exist for that case, only Epic 13 runs this script, and per-slot defaults add parameters and branches.
  - `[medium]` `[patch]` blind-hunter: `trap cleanup EXIT` alone does not fire on an uncaught interrupt, leaving two IRIS containers — fixed: `trap 'cleanup; exit 130' INT TERM`, the idiom already at `scripts/ci-durable-ownership.sh:39`.
  - `[low]` `[patch]` blind-hunter: `wait_for_session` omits `-i`, so its heredoc never reaches the container and the loop tests only that `iris session` starts — fixed by adding `-i`, matching every other session call in the file.
  - `[low]` `[reject]` blind-hunter: `$DIR` is not removed on exit — deliberate and useful: the archive and the extracted manifest are what a manual `tar tzf` reads afterwards, and the next run clears it.
  - `[low]` `[reject]` blind-hunter: a missing `node` is reported as manifest drift — the message carries the exit status, so 127 is distinguishable from 1; separating them adds a branch.
  - `[medium]` `[patch]` blind-hunter: the `$TMPDIR` arm of the scratch-root guard has no separator, so `TMPDIR=/tmp` makes `/tmpfoo` pass into `rm -rf` — fixed: the value is stripped of a trailing slash and the arm is written `"$SCRATCH_TMPDIR"/?*`.
  - `[low]` `[reject]` blind-hunter: the module-presence check greps IPM's coloured `list` table — the image is pinned to an explicit 2026.2 tag, so its output format cannot change under this script, and replacing `list` with a SQL probe would redden the three-verb allow-list the spec declares.
  - `[medium]` `[patch]` blind-hunter: `ipmVerbs`, `ipmCommands` and `dockerRunLines` read literal text, so a command or container built from a variable is invisible to the allow-list and the `--network none` assertion — fixed: every `Shell(` call must be a literal `Shell("…")`, and `docker create`, `docker start`, `docker compose`, `--mount`, `--volume` and a line-continued `docker run` are refused outright.
  - `[low]` `[reject]` blind-hunter: `DECLARED_GATES` compares sorted multisets, so a `run:` step could move between jobs — deleting the job reddens the `jobNames` equality, and mis-ordering inside the job is self-detecting (the script exits 2 naming the unbuilt bundle); a containment assertion is an addition, not a correction.
  - `[medium]` `[patch]` blind-hunter: `README.md:469` still reads "Three jobs" over a three-row table, in a file this story edits — fixed at origin: "Four jobs", plus the `package` row.
  - `[medium]` `[reject]` blind-hunter: the spec's matrix and Tasks still name IPM's `Module package generated:` line, which does not exist — the fix is an edit to this build's spec; the correction is recorded in this story's Auto Run Result section and the origin correction in `epics.md` is filed as a deferred item for the lead.
  - `[false]` `[reject]` blind-hunter: frontmatter `status` disagrees with `## Auto Run Result`'s `Status:` — `in-review` is this step's own transient value; finalize writes `done` into both.
  - `[medium]` `[defer]` blind-hunter: the hand-off items carry no tracking — filed as three `deferred:` items (the `epics.md` wording, `CLAUDE.md`'s job count, `ci-image-compile.sh`'s narrower tag guard) for the lead's harvest, which is where Rule 15 puts them.
  - `[low]` `[reject]` blind-hunter: the staged set is hard-coded while the manifest is generated — a `<FileCopy>` source outside those three paths fails the Activate phase inside the container and the script exits naming it; tying the staged set to the manifest adds a parser.
  - `[medium]` `[patch]` blind-hunter: `runRefused` drives the real script against the real repository root and never passes `--dir` — fixed together with the verification-gap layer's sharper form of the same defect (below).
  - `[low]` `[reject]` blind-hunter: the `package` job has no failure-capture step — the containers are gone by the time a job-level `if: failure()` step could run; every session-based failure already prints its own last 40 lines, `wait_for_session` prints `docker logs`, and the member list and the manifest diff are printed at their own failures.
  - `[medium]` `[patch]` edge-case: `--dir /tmp/../anywhere` passes the scratch-root guard and is then removed recursively — fixed: a `*..*` arm refuses it before the guard, naming the directory.
  - `[medium]` `[patch]` edge-case: `:latest-em` and every other `:latest-*` alias is as floating as `:latest-cd` and was accepted — fixed: the pattern is now `*:latest|*:latest-*`, and `ipm-archive.test.mjs` drives `:latest-em`.
  - `[low]` `[reject]` edge-case: a flag supplied as the final argument with no value fails on `shift 2` rather than exiting 2 with a message — a guard per flag arm is four new branches for a caller error that still stops the script.
  - `[medium]` `[patch]` edge-case: `$DIR/artifact` never receives the `chmod -R a+rX` the staged tree gets, though it is mounted into the second container — fixed: the same adjustment is applied after `docker cp`.
  - `[medium]` `[patch]` edge-case: only `EXIT` is trapped — same root cause as the blind-hunter's trap finding; fixed by the same line.
  - `[low]` `[reject]` edge-case: `docker rm -f` before `docker run` could remove a pre-existing container of the same name — the six names this project runs are refused outright, and an existence check adds a branch for a name the caller chose.
  - `[medium]` `[patch]` edge-case: `declarations()` reads no `<WebApplication>` and no `<Invoke>` `<Arg>` child — same root cause as the blind-hunter's manifest finding; the `<Arg>` half is covered by the new `argcount=` line.
  - `[medium]` `[patch]` edge-case: the archive assertions are floors, not the counts on disk — same root cause as the blind-hunter's floors finding.
  - `[medium]` `[patch]` edge-case: `ipmVerbs`/`ipmCommands` see only literal `Shell("…")` — same root cause as the blind-hunter's literal-scan finding.
  - `[medium]` `[patch]` edge-case: only `docker run` lines and the `-v` short form are inspected — same root cause; the new containment test bans the other forms.
  - `[low]` `[reject]` edge-case: the README rehearsal that was replaced was the only exercise of `zpm uninstall`, which the README still instructs — the intent closes the verb set at `load`, `package` and `list`, so adding an uninstall leg is forbidden here; the uninstall path is exercised by `OcuPilot.Test.UninstallGuard`, `UninstallResidue` and `UninstallSurvival` in the class sweep.
  - `[low]` `[reject]` edge-case: the replaced README text carried the note that `Shell`'s third argument halts the session — the script's own calls all pass `0` and `Halt` explicitly; restating it is prose this story does not need.
  - `[medium]` `[reject]` edge-case: the spec still describes the `Module package generated:` mechanism and a different `-path` — the fix is an edit to this build's spec; same disposition as the blind-hunter's form of it.
  - `[false]` `[reject]` edge-case: the whole-file token ban was narrowed to `Shell("…")` strings — the literal ban is unsatisfiable: the script must name `--install-name` and the pinned `irishealth-community` reference (`install ` appears twice, `-community` once). What ships is stronger, not weaker: `publish` is banned case-insensitively over the raw file, `-community` is checked by shape over the raw file, and the new literal-command test closes the only gap the narrowing could have opened.
  - `[medium]` `[patch]` verification-gap: the exported manifest is compared on five declaration kinds and the three `<WebApplication>` elements are not among them — fixed; the demonstrated AC2 mutation below reddens on exactly that line.
  - `[medium]` `[patch]` verification-gap: AC2's new half, the archive-manifest comparison, had no demonstrated mutation, and mutating the extractor cannot redden it because it is applied to both sides — fixed: a mutation that alters the staged copy after `--check` has run (`JWTAccessTokenTimeout` 60 → 3600) was applied, observed red at exit 1 on the `webapp=` line for `/api/ocupilot`, reverted with the file byte-identical by md5, and recorded in `## Verification`.
  - `[medium]` `[patch]` verification-gap: the refusal tests drive the real script with `--dir /` and `--dir /tmp`, so the Rule 19 mutation they invite would make `npm test` delete the developer's `/tmp` — fixed: `runRefused` now stubs `rm` and `cp` alongside `docker`, and every executed refusal asserts neither was reached.
  - `[low]` `[patch]` verification-gap: `assert.ok(!existsSync(join(dir, 'ui', 'dist')))` asserts a property of a fixture the test just built and cannot fail — fixed by deletion; the two assertions that follow are the ones that stand for the refusal.
  - `[low]` `[patch]` verification-gap: a doc comment claims `install` is shape-checked separately, and it is not — fixed by replacing the sentence with what is actually checked and why it suffices.
  - `[medium]` `[patch]` verification-gap: the archive-contents floors are weaker than AC1's plural — same root cause as the floors finding; fixed by the equalities.
  - `[low]` `[patch]` verification-gap: deleting the `MANIFEST_STATUS` guard reddens nothing — fixed: the drift-ordering test now also pins that a non-zero status stops the script, matching the assertion already held for smoke.
  - `[false]` `[reject]` intent-alignment: five of ten matrix rows are held only by the script's own assertions — those rows are runtime rows and the script is their executor; it runs on every push in the new `package` job and was run twice by hand this pass, so each row is covered by a test that ran and passed.
  - `[medium]` `[reject]` intent-alignment: the spec's task text still carries the literal `Module package generated:` reading — the fix is an edit to this build's spec; the origin correction is deferred to the lead.
  - `[medium]` `[patch]` intent-alignment: "the shipped `OcuPilot` classes" is a completeness claim and the script asserted presence — fixed by the equalities.
  - `[false]` `[reject]` intent-alignment: the `package` job itself reaches the npm registry and pulls an image — the intent scopes the isolation explicitly ("Both containers run with no network at all"), and the stealth policy is about publishing OcuPilot, which neither `npm ci` nor an image pull does.
  - `[medium]` `[patch]` intent-alignment: `README.md:469` still says three jobs — same root cause as the blind-hunter's form; fixed at origin.
  - `[low]` `[patch]` intent-alignment: the workflow header claims the job "adds nothing to the critical path", which nothing measures — fixed by replacing the claim with what is true at the dependency surface: it waits on nothing, so it runs beside `instance` rather than after it.
  - `[false]` `[reject]` intent-alignment: a commented-out `Shell("install …")` is invisible to the verb equality — a comment does not execute, and the new literal-command test covers every command that does.
  - `[false]` `[reject]` intent-alignment: the intent quotes a `zpm` CLI invocation and the script uses `%IPM.Main.Shell` — forced and documented: a stock instance carries no `%IPM` class at all (AD-18), so no `zpm` binary exists until `zpm.xml` is imported; the verbs and their arguments are the intent's.

## Design Notes

**Governing ADs.** **AD-18** (IPM is a distribution channel, never a runtime dependency — which is exactly why this story needs instances of its own: the shipped image carries no loaded IPM, and nothing in the install path may assume one). **AD-17** (one installer class, two entry points; the roster generates both the installer's class list and the manifest, which is AC2; and the IPM `<Invoke>` carries no `<Arg>`, so `pUnexpire` keeps `0`). **AD-25** (the demo fixture is opt-in and absent from every non-container path including IPM — so `wallet` and `demofixture` skip, and a skip is not a failure). **AD-45** (one smoke path, which is also the health check — this story asks it the question rather than inventing a second notion of "working"). **AD-38** (install completes before traffic; on a first IPM install the gate answers `unreadable` across the activation window, inside the window this AD already accepts — the script smokes after `load` returns, so it never observes it). **AD-27** (the image tag is explicit, never `latest-cd`). **AD-21** (the manifest carries no privilege properties; the two unauthenticated applications get their role floor from `Install`, which runs `When="After"` Activate — so a correct IPM install is one where the applications exist *and* `Install` ran). **AD-9** (`zpm uninstall` is not `Installer.Uninstall`; nothing here uninstalls). Stack rows: **IPM** `0.10.x`, **Docker Compose** image pinned to an explicit 2026.2 tag, **CI**.

**Integration ACs (Rule 1) and linkage (Rule 2).** This story introduces one shared component — the archive builder and its local-install check. `Consumed-by:` **the new `package` CI job, in this story**: it runs the script on every push and `ci.test.mjs` holds the wiring equal in both directions, so "consumer X reads from this and produces observable effect Y" is satisfied here rather than deferred. No downstream story consumes it; the only other consumer is the owner's own release, which is not a story. `Consumes:` Story 1.16 (`module.xml` generated from `Install/Roster.cls`, and `ipm-manifest.mjs --check`), Story 1.17 (`smoke.sh`, the `ci-image-compile.sh` container idiom, CI's job structure), Story 13.2 (`DECLARED_GATES`, the stealth absences, the `stub-bin.mjs` docker-stubbing idiom).

**"The publish path in its dry-run form" — what that is, measured.** IPM 0.10.5's `publish` command declares exactly three modifiers (`repo`, `use-external-name`, and the `dataPrefix`), and **no dry-run flag exists on it**; the one `dry-run` modifier in the whole grammar belongs to `run`. What does exist is `package`, whose phase chain is `Initialize,Reload,*,Validate,Compile,Activate,Package` — and `%IPM.Lifecycle.Base:%Publish` calls that same `Package` phase itself before it resolves a server to upload to. So `package` is the publish path minus the upload, which is the **local form** the owner's hold and AC3 both name ("exercised only in its dry-run **or local** form"). The criteria are satisfiable as written and this plan needs no amendment to proceed — see the Clarifications for the one-word correction recommended at origin.

**Why two containers and not one.** The instance that packages must first `load` the module, and `load` runs the full lifecycle including `Activate`, so it ends with OcuPilot installed. The install target must be fresh, so it cannot be that instance. It cannot be a second **namespace** either: OcuPilot's web applications, resource, role and protected database are instance-wide, so a second namespace on the packaging instance would collide with the install already there. Two containers, sequentially, each removed by the `EXIT` trap.

**Why `--network none` is the point.** AC3's strongest reading — "nothing contacted a registry" — is a negative over an open set, and the honest way to hold it is to make the contact impossible rather than to assert its absence. A container with no network has only `lo`; IPM's local `load` and `package` need nothing else, and the smoke path is loopback-only by construction (`Smoke.Host()` returns `localhost`, `Smoke.Port()` reads the instance's own `WebServerPort`). The artifact crosses between containers by `docker cp`, which is not network. **Verify at implementation that the stock 2026.2 image starts under `--network none`** (it publishes no port and needs no license server, so it should — *(inference)*). If it does not, the fallback is `--network none` on the packaging container only, plus the verb allow-list and the zero-repository-row assertion, with the weakening recorded here rather than absorbed.

**What is unfalsifiable by policy, said plainly.** "No registry was contacted at the network level" is not falsified by this story, because falsifying it would mean making the call. What *is* falsifiable, and is what the AC3 pinning test holds: the containers carry no network (delete the flag → red), the IPM verb set equals a three-verb allow-list in both directions (add a fourth verb → red), the script names no credential or secret (add one → red), and `%IPM_Repo.Definition` is empty on both instances (seed a row → red). That is a proven guard over the mechanism and a labeled gap over the network, which is worth more than a proxy that looks like proof.

**What AC2 already was, and the one thing this adds.** `ipm-manifest.mjs --check` is an equality in both directions and already runs in `prebuild`, `prestart` and `.githooks/pre-commit`, pinned by `ipm-manifest.test.mjs:576`; `:545` pins that the committed file is current. The gap this closes is narrow and real: none of those observe the file that actually reaches the archive. The script runs `--check` before staging, and the archive's own manifest is compared to the roster's declarations. **Structural, not byte, equality** — IPM re-serializes the module definition on export, so attribute order and whitespace are its own; assert the declared name, version, resources, file copy and invoke, and confirm the serialization shape at implementation time rather than assuming it.

**`_SYSTEM` is expired on the install target, and that is correct.** A fresh Community instance expires `_SYSTEM` on first login, and the IPM `<Invoke>` deliberately never unexpires (AD-17, DW-92) — so every HTTP check in `smoke.sh` would read 401. The script clears it **after** install and **before** smoke, targeting `_SYSTEM` by name and never the all-users form, and says in one line that it is an operator act the IPM path deliberately leaves to the operator. Doing it inside the install path would falsify the AD.

**No new ObjectScript test class, and why that matters here.** The proof of "yields a working OcuPilot" is the one smoke path (AD-45), not a new `%UnitTest` class, so `src/OcuPilot/Test/**` is untouched and the ObjectScript sweep is unaffected. This story also installs and uninstalls nothing on `ocupilot-b-ci`, so the sweep it reports is the ordinary one. **DW-1297 still binds anyone who does run an install/uninstall cycle on a throwaway:** the sweep goes red afterwards (12 failures, all `Install refused for profile 'probe': … still held its install lock`) and green on a fresh instance from the identical tree (137 classes / 1283 tests / 0 failed). Per-class runs in isolation are not evidence about the sweep.

**Clarifications for the lead — named, not planned around:**

1. **AC1's wording.** It says the archive is produced by "the publish path running in its **dry-run** form". IPM 0.10.5 has no dry-run on `publish`; the local `package` form is what exists, and AC3 and the owner's hold already name it. Recommended one-word correction at origin in `epics.md`: "its dry-run form" → "its local (`package`) form". Nothing in this plan waits on it.
2. **`README.md` is a footprint extension.** It is not in Epic 13's declared footprint and no contended epic owns it, so under Rule 11 (b) it is edited and reported rather than assumed. The edit is one paragraph; drop it if the lead prefers a zero-extension story.
3. **The manifest carries no listing metadata.** There is no `<Author>`, `<License>` or `<Repository>` element, and a registry listing normally wants all three; the repository ships an MIT `LICENSE` at its root, so `<License>MIT</License>` would be uncontroversial. Out of this story's three criteria (Rule 27) and not planned here; it is a roster edit plus a regenerate whenever the owner wants it, and it belongs with the release rather than with the archive.
4. **A fourth CI job changes an equality that reads as a fact.** `ci.test.mjs:408-409` asserts the job list is exactly `['gates','instance','images']`, and `CLAUDE.md` says "three jobs". Widening the test is this story's, in its own footprint; the `CLAUDE.md` sentence is the lead's to correct at origin if it wants the count to stay true.

**Rule 17 (ledger inbox).** `ledger.sh … slice 13-3-publish-the-package-to-the-community-registry` returns nothing. Nothing to address or decline.

## Verification

**Shared runtime:** this story's own containers are `ocupilot-ipm-build` and `ocupilot-ipm-install`, created and removed by the script alone. **Never** stop, remove, recreate or `down` `ocupilot`, `ocupilot-slot-b`, `ocupilot-slot-c`, `ocupilot-ci`, `ocupilot-b-ci` or `ocupilot-c-ci` — all six are running and none is this story's. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Stateful test classes run **one class per tool call** (Rule 18 (3)); this story adds none. Read every exit code directly (`cmd; echo $?`), never through a pipeline.

**Commands:**

- `cd ui && npm run build` — expected: the six `prebuild` checkers pass, including `ipm-manifest.mjs --check`, and `ui/dist/ocupilot-ui/browser/` exists.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `ipm-archive.test.mjs`, then the component runner green.
- `sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2` — expected: exit 0, one summary line naming the artifact, its class count, and the smoke verdict PASS.
- `sh scripts/ci-ipm-archive.sh --build-name ocupilot-ci --image intersystems/irishealth-community:2026.2` — expected: exit 2, naming the container, before any `docker run`.
- `bash scripts/lint-docs.sh` — expected: clean over the edited `README.md`.
- `node tools/ci-runner.mjs --container ocupilot-b-ci` — expected: the ordinary ObjectScript sweep, unchanged by this story.

**Pinning tests and mutations (Rule 19) — one demonstrated mutation per AC, reverted and confirmed byte-identical (`git status --short` and `git diff --stat` unchanged) before the next:**

- **AC1** — pinning test: the `package` job's end-to-end leg (`ci-ipm-archive.sh`'s archive-contents assertions plus the smoke verdict on the install container). `mutation: drop the bundle's staging copy from scripts/ci-ipm-archive.sh → exit 1 at the archive-contents check, "the staged bundle holds no file, so a comparison against it would pass having compared nothing", with the archive down from 1,083,507 to 542,321 bytes`. Activate does not fail first: `mkdir -p` leaves the staged directory there and empty, so IPM exports nothing from it and the host-side check is what catches it. The archive-side arm of the same assertion is the per-file `MISSING_BUNDLE` list, which names every staged file the archive does not carry.
- **AC2** — pinning test: the pre-stage `ipm-manifest.mjs --check` plus the archive-manifest-versus-roster comparison. One mutation per arm, because the first stops the script before the second runs. `mutation: change <Version> in module.xml by hand without touching src/OcuPilot/Install/Roster.cls → ipm-manifest.mjs --check exits 1 naming <Version>, and the script stops before any container starts`. `mutation: alter the staged copy of module.xml after it is staged (JWTAccessTokenTimeout 60 → 3600 in $DIR/module/module.xml), which --check does not see → the archive-manifest comparison exits 1 on the webapp= line for /api/ocupilot, naming both sides`.
- **AC3** — pinning test: `ui/tools/ipm-archive.test.mjs`'s network-isolation and verb-allow-list assertions. `mutation: delete --network none from one docker run line in scripts/ci-ipm-archive.sh → ipm-archive.test.mjs goes red naming that container`. **No network call is issued in either direction** — the mutation is observed entirely host-side, which is the point.
- **Integration AC** — pinning test: `ci.test.mjs`'s `DECLARED_GATES` equality and the widened `jobNames` equality. `mutation: delete one run: step from the package job in .github/workflows/ci.yml → ci.test.mjs goes red naming the orphaned declared gate`.

**Manual checks:**

- `tar tzf` the produced archive once by hand and read the member list: `module.xml`, `OcuPilot` classes, `ui/dist/ocupilot-ui/browser/`, and nothing under `OcuPilot/Test/`. Record the counts in `## Auto Run Result` rather than asserting them from the script's own output alone.
- Confirm on both containers that `SELECT COUNT(*) FROM %IPM_Repo.Definition` is 0 after the IPM import — the runtime half of AC3.

## Auto Run Result

Status: done
Blocking condition: none

**What landed.** `scripts/ci-ipm-archive.sh` (new): the two phases in order, on two containers of its
own started `--network none` from the pinned tag and removed on an `EXIT`, `INT` and `TERM` trap. It
runs `ipm-manifest.mjs --check` and refuses an absent bundle before staging anything; refuses the
live, slot and throwaway container names, the two names being equal, a floating or absent image tag,
and a `--dir` that is outside a scratch root or contains `..`; asserts zero `%IPM_Repo.Definition`
rows on both instances after the import and again after every verb; reads the artifact back from the
directory it wrote into; holds the archive's members and its manifest equal to the staged tree
host-side; unexpires `_SYSTEM` by name as an operator act (AD-17); and reads `smoke.sh`'s status from
the command rather than through a pipeline. `ui/tools/ipm-archive.test.mjs` (new, 17 tests) pins the
network isolation, the three-verb allow-list in both directions, that every IPM command is a literal
so those scans can see all of them, that no container is created by any other form, the credential
and upload absences, and every refusal -- all host-side with stub `docker`, `rm` and `cp`, so no
container is created and no refusal test can delete anything. `.github/workflows/ci.yml` gains a
fourth job, `package`, running beside `instance`; `ui/tools/ci.test.mjs` declares its three `run:`
steps, widens the `jobNames` equality to four, and applies its seven stealth-absence patterns to the
new script as well. `README.md`'s hand-typed rehearsal is replaced by one paragraph pointing at the
script, and its CI table gains the fourth row (a declared footprint extension).

**The held claim, settled by running it.** IPM 0.10.5's `publish` declares exactly `repo` and
`use-external-name` -- no dry-run modifier; the only `dry-run` in the grammar belongs to
`run-from-file`. `package` exists and works:
`##class(%IPM.Main).Shell("package ocupilot -path /tmp/ocupilot-package/ocupilot",1,0)` runs the
lifecycle through `Package SUCCESS` and writes one `.tgz`. The upload verb was never run in any form,
no registry credential or token was read, configured, requested or used, and `--network none` needed
no fallback: the stock image starts, imports IPM offline, loads, packages and smokes under it.

**Three plan assumptions corrected from what the run showed.** IPM 0.10.5 prints **no**
`Module package generated:` line, so the artifact is identified by requiring exactly one `.tgz` in an
output directory emptied first -- still read, never predicted. The archive re-roots class members
under `src/cls/`. And IPM's exporter drops `<SystemRequirements>` as well as `<Packaging>`, so the
compared set excludes it and the gap is filed under `deferred:` rather than absorbed.

**Verified.** `sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2` -> exit
0: `ocupilot.tgz`, 1,083,507 bytes, 172 members -- `module.xml`, all 135 staged `OcuPilot` classes
(equal to the 135 non-test `.cls` on disk, read back by hand with `tar tzf`), all 14 staged bundle
files, and **no** member under `OcuPilot/Test/`.
The archive's manifest declares the same 11 items as the roster's, and smoke reported PASS with
`executed=42 passed=42 failed=0 pending=2 skipped=3` on the second instance -- `wallet`, `demofixture` and `x509` among the skips, which AD-25
makes correct rather than a failure. Both instances reported 0 package-repository rows after the
import and again after every verb. `cd ui && npm run build` green (six checkers); `npm test`
1,118 node tests + 644 component tests, 0 failed; `bash scripts/lint-docs.sh` clean;
`node tools/ci-runner.mjs --container ocupilot-b-ci` `137 class(es), 1283 test(s), 0 failed, 0 with probe leftovers, 0 overlap(s), 0 foreign run(s)`, the ordinary sweep DW-1297 names;
`--build-name ocupilot-ci` -> exit 2 naming it, before any container.

**Mutations (Rule 19), each reverted with the file byte-identical by md5.** AC1: drop the bundle from
the staging copy -> exit 1 at the archive-contents check, "the staged bundle holds no file, so a
comparison against it would pass having compared nothing", the archive down from 1,083,507 to
542,321 bytes. Activate does not fail first, as the plan predicted it would: the staged directory
is still there and empty, so IPM exports nothing from it and the host-side check is what catches it. AC2 has one mutation per arm, because the first stops the script
before the second runs: `<Version>` hand-edited -> `--check` exits 1 naming it with no container
started; and the staged copy altered after `--check` has run (`JWTAccessTokenTimeout` 60 -> 3600) ->
the archive-manifest comparison exits 1 on the `webapp=` line for `/api/ocupilot`, naming both sides.
That second one is the review's finding: AC2's novel half had never been shown to redden, and
mutating the extractor cannot redden it because it runs over both sides. AC3: `--network none`
deleted from one `docker run` -> `ipm-archive.test.mjs` red naming that container, entirely
host-side. Integration: one `run:` step deleted from the `package` job -> `ci.test.mjs` red on three
assertions, naming the orphaned declared gate.

**Review.** 49 findings across four layers: 0 high, 26 medium, 17 low, 6 false. 27 of them were
patched, grouped into 16 entries by root cause (11 medium, 5 low) -- the archive-contents floors became equalities against the staged
tree; the manifest comparison went from 6 hand-picked fields to 11 declarations with every attribute,
including the three `<WebApplication>` elements, any `<Dependency>` and an `<Arg>` count; the
repository-row zero is re-read after every verb; `INT`/`TERM` are trapped; `--dir` refuses `..` and a
`$TMPDIR` without a separator; `:latest-em` and every `:latest-*` alias is refused (AD-27); the
artifact directory gets the same `chmod` as the staged tree; `wait_for_session` gained the `-i` its
heredoc needs; the literal-only scans are now backed by assertions that nothing evades them; the
refusal harness stubs `rm` and `cp`; one unfalsifiable assertion was deleted and one inaccurate
comment replaced; `README.md`'s "Three jobs" was corrected at origin; and two unmeasured claims in
the workflow header were replaced with what is true. One finding was deferred, and the frontmatter
`deferred:` list carries four items -- two of them found here rather than by a layer. The remaining
21 were rejected, each with its reason in the triage log: 6 as false, 9 as low defects whose fix
would add guards, branches or parameters rather than correct or delete something, 3 because the fix
is an edit to this build's spec, and 3 because the intent forecloses the fix (the verb set is closed
at `load`, `package` and `list`).

**Follow-up review recommended: true.** Eleven medium entries were patched, so the rule sets it. The
specific unverified risk: the class equality `CLASS_COUNT -eq STAGED_CLASSES` assumes IPM's exporter
carries exactly the non-test `.cls` set under `src/cls/`, which held on the pinned 2026.2 image in
three runs this pass but is IPM's behavior rather than this script's; an exporter that started
emitting an extra generated class would redden the `package` job with a message that names the counts
rather than the cause.

**Open at origin, not this stage's to change.** `epics.md:5124` and `:737` still read "its dry-run
form"; the runs above are the evidence Spec Change Log (1) asked for, and the recommended correction
is "its local (`package`) form". `CLAUDE.md` says CI has three jobs; it now has four. Both are filed
under `deferred:` for the lead, per Spec Change Log (1) and (4). The spec's own matrix and task text
still name the `Module package generated:` line; that text is inside this build's spec, so it is
corrected here rather than edited.
