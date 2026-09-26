---
title: 'Story 13.3: Publish the package to the community registry'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: 'f5588ae72fda83f9b4d403d702c9d7a704ce4625'
baseline_commit: 'd965e4d'
review_loop_iteration: 0
followup_review_recommended: false
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
  - summary: >-
      the archive's bundle arm is containment, not an equality, so extra members under the bundle
      prefix pass while two records call it an equality
    evidence: |-
      `scripts/ci-ipm-archive.sh` asserts every staged bundle file is present by name and sets no
      upper bound, while the class arm is a true `CLASS_COUNT -eq STAGED_CLASSES`. The 2026-09-19
      triage log ("both are now equalities against the staged tree") and `## Auto Run Result`
      ("holds the archive's members equal to the staged tree") both overstate the bundle half.
      Either bound the bundle side or correct the two sentences.
    location: >-
      scripts/ci-ipm-archive.sh:313
    severity: medium
  - summary: >-
      the manifest comparison's `DECLARED -lt 11` floor is not held to the roster's own declaration
      count, so it stops being tight the moment the roster declares a twelfth item
    evidence: |-
      `module.xml` yields exactly 11 declaration lines today, which is what makes the floor
      meaningful. With a twelfth, dropping an `element_lines` arm leaves both sides equally short,
      `diff -u` clean and `DECLARED` at 11 or more, and the script reports agreement having stopped
      comparing a kind -- the exporter-drops-an-element failure this check exists to catch. DW-1339
      records the same mechanism for the `<Dependency>` arm. Settled by a test that slices
      `declarations()` out of the script, runs it over the repository's module.xml, and asserts the
      emitted line count equals the floor literal read back from the script.
    location: >-
      scripts/ci-ipm-archive.sh:377
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

- [x] [Review] **DW-1334 (HIGH)** — the `package` CI job fails on the Linux runner: the archive's bundle
  members are not under `ui/dist/ocupilot-ui/browser/`, so AC1's contents check and the Integration AC are red
  (run `35503250843`, head `8085072`, job `106058629958`, exit 1 at the archive phase). The bundle's bytes are
  present — 1,083,080 bytes against a bundle-less 542,321 — so it is the member **path** that differs, in the
  `<FileCopy>` branch alone; the class check passed over the same archive. The diagnostic that prints the
  archive's actual non-class members is already in the script from the review pass. **Read that list from the
  next CI run and fix the comparison against what IPM actually emits — do not guess a prefix.** The containers
  are Linux in both environments, so the host-side staging is the only variable and a local macOS run cannot
  reproduce it.
  **DIAGNOSED 2026-09-20 from the diagnostic's own output** (run `35504554421`, job `106062047391`): IPM emits
  member paths with a **doubled slash** at the join — `ui/dist/ocupilot-ui/browser//index.html`,
  `ui/dist/ocupilot-ui/browser/media//Inter-OFL.txt`, `src//cls` — because `<FileCopy Name="…/browser/">`
  already ends in `/` and IPM joins another. The check looks for the single-slash form, so it misses every one.
  The archive is not wrong and the bytes are all there; the **comparison** is.
  Why it was green on macOS and red on Linux: the host's `tar` does **not** explain it — `bsdtar 3.5.3` here
  lists `//` unchanged from gnu, ustar and pax archives, measured this pass — and the two runs' archives differ
  in size (1,083,507 against 1,083,080), so what differed is what IPM stored, not how it was listed
  *(inference)*. Either way the comparison must not depend on the listing, which is why CI is the gate that
  counts.
  **The fix: normalize repeated slashes in the member list once, where `MEMBERS` is built, so every downstream
  comparison is tar-implementation-independent.** Do not special-case the bundle branch — `src//cls` shows the
  same join elsewhere — and do not change `module.xml`'s `Name`, which is correct as written and is what the
  manifest equality checks. Demonstrate it: a mutation that removes the normalization must redden a test that
  feeds a GNU-tar-shaped (doubled-slash) member list through the comparison, so the guard cannot silently
  depend on which tar ran.


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

### Review Findings

Second review (2026-09-20, `followup_review_recommended: true`). 1 high, 3 medium, 4 low; seven patched
in-pass, one high open. Open items only.

- **`[high]` DW-1334 — AC1 and the Integration AC are red on CI.** Run 35503250843 (head `8085072`, the
  code under review), job 106058629958: `ci-ipm-archive.sh` exits 1 at the archive-contents check,
  `is missing 14 staged bundle file(s)`, naming every bundle file. The archive it built is 1,083,080
  bytes against the macOS run's 1,083,507, and the AC1 mutation puts a bundle-less archive at 542,321 —
  so the bundle's bytes are in the CI archive and it is the member **path** that differs. The class
  check (`^src/cls/OcuPilot/.*\.cls$`) passed over the same archive, so the divergence is the
  `<FileCopy>` branch alone. The story's whole evidence base is one macOS run; the Linux export path was
  never observed. **Not diagnosable from the CI log as it stood** — the failure named only what it
  looked for — so this pass added a dump of the archive's non-class members at that failure. The next
  CI run prints the actual prefix. Re-opens the story.
- **`[med]` DW-1338 — `epics.md:737`** still reads "the archive is proven by a dry-run build", the claim
  the same amendment corrected at `:5124`. The spec's own `deferred:` item named both sites; one was
  applied. Outside this reviewer's footprint; `routed owner=range-end-cleanup`.
- **`[low]` DW-1339 — the `<Dependency>` arm of the manifest comparison matches nothing** against IPM's
  own serialization. `wontfix-accepted`; `reopen_if` on the entry.
- **Record correction, not a defect:** frontmatter `deferred:` items 1 and 2 read as open, and the
  2026-09-20 Spec Change Log entry applied both — `CLAUDE.md`'s job count in full, `epics.md` at `:5124`
  of the two sites item 1 names. Only `epics.md:737` (DW-1338) is still open. The lead owns the harvest.
- **Refuted, with evidence:** the `package` job's `timeout-minutes: 45` was flagged by two layers as an
  unmeasured budget. It is ample — on the runner, phase 1 (image pull, cold IRIS start, IPM import,
  module load, `package`, the repository re-read and `docker cp`) ran 09:47:31 → 09:50:03, 2 m 32 s.
  The "roughly an hour" figure is the macOS run, not the runner.

Third review (2026-09-20, rework re-review, scope `d965e4d..HEAD`). 0 high, 2 medium, 7 low; every
one patched in-pass, nothing open. The story closes (Rule 15 exit condition).

- **`[med]` The result section still said AC1's end-to-end leg was unobserved green on Linux** —
  contradicted by the `ci_resolved` line the same range adds. Replaced at origin with run
  `35506409237`'s result, and the local-run cost separated from the CI job's.
- **`[med]` The `Scope="test"` exclusion had no pin under a doubled join** — `grep 'OcuPilot/Test/'`
  does not match `src//cls/OcuPilot//Test//fixture.xml`, so without the normalization a
  `Scope="test"` member is a false green rather than a red. A fourth arm on the doubled-slash test
  pins it, with its mutation in `## Verification`.
- **`[low]`, patched:** the diagnostic's raw listing had no assertion; the scratch-root guard
  accepted a relative `$TMPDIR`, which made a relative `--dir` removable (absolute arm added, with
  its test and mutation); the `deferred:` item asking for a ledger correction `a132686` had already
  applied; two `deferred:` `location:` line numbers, now `:313` and `:377`; `archiveContentsBlock`'s
  doc comment claimed `fail()` is the script's when the prelude supplies it; the SIGTERM floor's
  failure message misread a count of zero as "the trap did not fire".
- **Ledger, by trailer rather than re-filed:** DW-1344's evidence miscalls DW-1339 "the Node pin";
  DW-1343's record half is done here, leaving only the optional tightening.
- **Refuted:** the widened diagnostic filter `^src/*cls/` "hides the `src//cls` evidence" — it is
  what stops the 40-line dump being flooded by class members, and the bundle joins, the branch that
  actually fails, still show their doubling. `baseline_commit` differing from `baseline_revision` is
  deliberate: the rework's base and the story's base answer different questions.

## Spec Change Log

- 2026-09-20, lead, after the implement run supplied the evidence Spec Change Log (1) required.
  **(1) applied:** `epics.md:5124`'s "its dry-run form" is now "its local (`package`) form", marked `[AMENDED]`,
  on the strength of the observed run rather than the plan's reading - `publish` declares only `repo` and
  `use-external-name`, and `package ocupilot -path ...` reached `Package SUCCESS` and wrote a 1,083,507-byte,
  172-member archive. **(4) applied:** `CLAUDE.md`'s "three jobs" is now "four jobs", after parsing
  `.github/workflows/ci.yml` and reading back `['gates','instance','images','package']`. Both are Rule 5 tier-1
  (a name the criterion cited that did not exist; a count that had stopped being true) and both are reported
  under `amendments:` / `footprint_extensions:`.
  The other two deferred findings are harvested rather than fixed here: **DW-1332** (`ci-image-compile.sh`'s
  floating-tag guard accepts `:latest-em`) and **DW-1333** (IPM's exporter drops `<SystemRequirements>`, so the
  archive carries no version floor - a distribution property that belongs with the release, beside DW-1300).

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

### 2026-09-20 — Review pass (rework, DW-1334)

- verdicts: 55 findings — high 0, medium 6, low 42, false 6, maybe-false 1
- findings:
  - `[false]` `[reject]` blind-hunter: the slash normalization does not reach `tar xzf "$ARCHIVE" -C "$DIR/extract" module.xml`, so a joined `module.xml` name would die bare under `set -e` — refuted: the extraction runs only after `count_members '^module\.xml$'` is at least 1, and the only raw member that normalizes to exactly `module.xml` is `module.xml` itself (collapsing slashes never removes them), so the literal the extraction names is known to exist.
  - `[medium]` `[defer]` blind-hunter: `deferred-work.md`'s DW-1334 evidence records the BSD/GNU tar root cause this pass measured to be false, while the spec now records the measurement — the ledger is the lead's to write (Rule 15), so filed for correction at origin.
  - `[medium]` `[patch]` blind-hunter: the diagnosis does not account for its own evidence (the macOS run passed, the archives differ by 427 bytes) — the wrong sentence was replaced at origin this pass and the residual is labeled `(inference)`; the normalization holds under either explanation, and the raw listing is now preserved for the next CI failure (see the diagnostic row below).
  - `[low]` `[reject]` blind-hunter: `Status: done` is claimed while AC1 was last observed red on CI — the criterion's end-to-end leg is the `package` job, which runs on push; the story is reported on what was verified, and `## Auto Run Result` says plainly that the fix is proven host-side only.
  - `[low]` `[reject]` blind-hunter: DW-1334 is still `status=open` in `deferred-work.md` — `bmad-build-auto` never writes the ledger (Rule 15 (a)); the lead closes it at `ledger_adjudicated`.
  - `[false]` `[reject]` blind-hunter: `epics.md:5142` is an uncorrected third "dry-run" site — refuted: `:5142` reads "only in its dry-run **or local** form", which already admits the form this story used and is the wording the spec's Design Notes rely on. DW-1338's `:737` is the only site still wrong.
  - `[low]` `[reject]` blind-hunter: the `epics.md:5124` amendment appends rather than replaces — `epics.md` is a planning artifact the lead amended under Rule 5; not this stage's file.
  - `[low]` `[reject]` blind-hunter: the amendment's `%IPM.Lifecycle.Base:%Publish` claim is not cited to a read — same owner as the row above; the claim is the lead's, at origin.
  - `[low]` `[reject]` blind-hunter: `## Auto Run Result` restates the previous pass — the earlier text is that pass's record; this pass appends only its own paragraph, which is what the prose rule asks of a rework.
  - `[low]` `[reject]` blind-hunter: the spec is `oversized` and gained sections — the triage log and the result section are this workflow's required outputs; each row here is one line.
  - `[low]` `[patch]` blind-hunter: `**What landed.**` still reads "(new, 17 tests)" against a file of 23 — corrected at origin to 23.
  - `[false]` `[reject]` blind-hunter: frontmatter `in-review` disagrees with the body's `Status: done` — `in-review` is this step's own transient value; finalize writes `done` into both. Carried from the 2026-09-19 row.
  - `[low]` `[reject]` blind-hunter: `review_loop_iteration` is 0 although the cycle log records `iteration=1` — the frontmatter counter counts this workflow's bad-spec loopbacks, of which there have been none; the lead's rework iteration is a different count.
  - `[low]` `[reject]` blind-hunter: three unreconciled baselines (frontmatter, cycle log, DW-1334) — they answer three different questions (the spec's diff base, the lead's rework scope base, the CI head that failed); reconciling them is bookkeeping in the lead's files.
  - `[low]` `[reject]` blind-hunter: the `timeout-minutes: 45` refutation measured only phase 1 — true, and the recorded figure says "phase 1"; the budget is still unexceeded on every run so far, and widening it on an unmeasured second phase would be the same error in the other direction.
  - `[low]` `[patch]` blind-hunter: nothing pins that the member comparison still *rejects* — the branch that failed on CI had no executed test. Fixed: the doubled-slash test now also feeds a listing with one staged bundle file genuinely absent and asserts exit 1 naming it.
  - `[medium]` `[defer]` blind-hunter: the bundle arm has no upper bound, so an archive carrying extra `$BUNDLE/` members passes while the triage log and result section call it an equality — filed; the class arm is a true equality, the bundle arm is containment.
  - `[low]` `[reject]` blind-hunter: `for tFile in $(… find …)` word-splits on a bundle filename containing a space — the failure direction is a false red, no such name exists in an Angular bundle, and the fix restructures the loop across a pipeline that would break the `BUNDLE_STAGED` accumulation.
  - `[low]` `[reject]` blind-hunter: `grep -c '<Arg'` counts lines, so two `<Arg>` on one line read as 1 — the manifest declares no `<Arg>` at all (AD-17), so both sides are 0; the undercount needs IPM to emit two on one line, which no export has.
  - `[low]` `[reject]` blind-hunter: `text_element` is positional and would read a nested element first — `module.xml` carries exactly one of each of the three, and the fix is a parser.
  - `[low]` `[reject]` blind-hunter: the new tests spawn `sh` only, while `shell-scripts.test.mjs` runs its pins under `shellsFor('sh')` — the script is syntax-checked under `/bin/sh` and `/bin/dash` in this pass, and the extracted-block test is about listing shape, not shell dialect.
  - `[low]` `[reject]` blind-hunter: `ocupilot-ipm-build` / `ocupilot-ipm-install` appear in no agent-context file — the fix edits `CLAUDE.md`, which this stage does not write.
  - `[low]` `[reject]` blind-hunter: `OCUPILOT_IPM_DIR` is an undocumented override on a directory the script removes — the `..` and scratch-root guards run on `$DIR` whatever set it, so the environment form is guarded identically to the flag.
  - `[low]` `[patch]` blind-hunter: `README.md` says the script "removes both containers on an `EXIT` trap" when the trap is `EXIT`, `INT` and `TERM` — corrected. The claim that the paragraph drops the operational cost is refuted by its first sentence, which names the operation destructive and whole-instance.
  - `[low]` `[patch]` blind-hunter: the script header says `list` "is the last verb either instance runs", but the build instance's last verb is `package` — corrected at origin.
  - `[low]` `[reject]` blind-hunter: the pinned image literal is now in a sixth place with nothing holding it to `docker-compose.yml` — a pre-existing pattern (`ci-throwaway.sh` and `ci-durable-ownership.sh` carried it before this story), and the fix is new cross-file equality machinery rather than a correction.
  - `[low]` `[reject]` blind-hunter: archive members are checked by name, not size, so 14 zero-length bundle members would pass — the install leg loads the archive and smokes it, and `Smoke.cls` answers whether the result works; a size equality over an exporter's output is a second notion of "correct" this story declined (AD-45).
  - `[low]` `[reject]` blind-hunter: the refusal tests apply `assertNothingRemovedOrCopied` and `assertNoContainerStarted` inconsistently — every refusal test asserts both properties, by helper or inline; uniformity here is style.
  - `[low]` `[reject]` blind-hunter: `sprint-status.yaml` moves only `last_updated` — the lead's file and the lead's gate.
  - `[low]` `[reject]` blind-hunter: the DW-1334 item is checked `[x]` while its body still reads as an instruction to a future stage — the body is the lead's re-open text, preserved verbatim as the record of what was asked; the `DIAGNOSED` paragraph below it supersedes the imperatives.
  - `[medium]` `[patch]` edge-case: a `TMPDIR` of `/` strips to the empty string, so the scratch-root arm becomes `/?*` and every absolute `--dir` passes into `rm -rf` — confirmed in a shell. Fixed: every trailing slash is stripped and an empty result falls back to `/nonexistent-tmpdir`; pinned by a new executed test and a demonstrated mutation.
  - `[low]` `[reject]` edge-case: the staged-bundle loop word-splits on a filename with whitespace — same root cause as the blind-hunter's row; same reason.
  - `[false]` `[reject]` edge-case: a non-canonical `module.xml` member makes the extraction die with no phase named — same refutation as the blind-hunter's first row: the presence check guarantees the literal member.
  - `[low]` `[reject]` edge-case: a listing that prefixes members with `./` still diverges — no listing observed on either platform does, the failure direction is a named red rather than a silent pass, and stripping `./` adds a guard for a condition never shown reachable.
  - `[low]` `[reject]` edge-case: `argcount` undercounts two `<Arg>` on one line — same root cause as the blind-hunter's row; same reason.
  - `[low]` `[reject]` edge-case: a bundle directory that exists but is empty passes the pre-flight refusal — the archive check then fails with "the staged bundle holds no file, so a comparison against it would pass having compared nothing", which names it; an emptiness pre-check is a second guard for a case the first already reports.
  - `[low]` `[reject]` edge-case: a `docker run` / `cp` / `exec` that itself fails exits under `set -e` with no phase named — docker's own message and status reach the caller; wrapping each of six calls in `|| fail` is guards, not a correction.
  - `[low]` `[patch]` edge-case: `assert.ok(lines.includes('rm -f ocupilot-ipm-build'))` in the SIGTERM test is already satisfied by the pre-run removal, so that arm cannot fail — fixed: it is now a floor of two occurrences, and the mutation that deletes the build container's removal from `cleanup()` reddens it.
  - `[maybe-false]` `[reject]` edge-case: the spawned child could block on an unread stdout pipe before `docker run` — would be `low` if true (a flaky test, not a product defect); the script writes three short lines before `run` and the test has never reached its 15 s deadline. What would settle it: a run with the script's pre-`run` output padded past the pipe buffer.
  - `[low]` `[reject]` edge-case: the README still instructs `zpm uninstall` with no remaining documented place to run it — carried from the 2026-09-19 row, rejected there on the same grounds: the intent closes the verb set at `load`, `package` and `list`.
  - `[low]` `[reject]` edge-case: the spec's Tasks and matrix still name IPM's `Module package generated:` line — the fix is an edit to this build's spec. Carried.
  - `[low]` `[reject]` edge-case: the Tasks text says `install `, `repo `, `enable ` and `search` are banned file-wide when they are banned inside `Shell("…")` — same disposition as the row above, and the narrowing is recorded in the 2026-09-19 log as forced (the script must name `--install-name` and the `irishealth-community` reference).
  - `[low]` `[patch]` edge-case: "(new, 17 tests)" against a file of 22 — same root cause as the blind-hunter's row; corrected to 23.
  - `[low]` `[reject]` edge-case: "every archive-contents comparison reads the same member list whichever tar listed it" is narrower than claimed, since the extraction bypasses `MEMBERS` — the extraction is guarded by the presence check (see the first row); the sentence is about the comparisons, which is what it says.
  - `[medium]` `[defer]` verification-gap: the `DECLARED -lt 11` floor is not held to the roster's declaration count, so once the roster declares a twelfth item a dropped `element_lines` arm leaves both sides equally short and the manifest comparison passes having stopped comparing a kind — filed pre-verified, with the same mechanism DW-1339 already records; outside this pass's mandate, which is DW-1334 alone.
  - `[low]` `[reject]` verification-gap: the staged-bundle loop word-splits — same root cause; same reason.
  - `[medium]` `[patch]` verification-gap: the DW-1334 diagnostic now dumps the normalized member list, so the next `package` failure no longer shows the shape IPM actually stored — the one evidence the dump exists to capture. Fixed: `RAW_MEMBERS` keeps the listing as `tar` gave it and the dump prints that.
  - `[low]` `[reject]` verification-gap: `argcount=0` is one of the 11 counted lines, so the success message reports 11 items over a manifest declaring 10 — a message, not a comparison; renaming the count changes no verdict.
  - `[false]` `[reject]` verification-gap: `assertNoContainerStarted()` passes vacuously on an empty array — refuted: an empty array *is* the property under test ("no container was started"); the helper exists to allow the trap's own removals and nothing else.
  - `[low]` `[reject]` verification-gap: nothing pins that the `package` job carries no `needs:` — the consequence of adding one is latency, not a wrong answer.
  - `[low]` `[reject]` verification-gap: DW-1332 (`ci-image-compile.sh` accepts `:latest-em`) has no test that would flag it — confirmation of an entry already filed and routed to `range-end-cleanup`; not re-filed.
  - `[false]` `[reject]` intent-alignment: normalization trades fidelity for portability, since an archive that genuinely stored a stray-slash path would now pass — refuted as a defect: the criterion is about which files the archive carries, not how the exporter spells a separator, and `src//cls` shows the join is the exporter's own habit rather than a corruption.
  - `[low]` `[reject]` intent-alignment: the registry guards are regexes over shell source whose coverage grows by imagination — true, stated in the test file's own header, and the honesty note under AC3 is the story's answer; closing it would need a different mechanism, which is a story rather than a patch.
  - `[low]` `[reject]` intent-alignment: the README's human rehearsal was removed rather than replaced, so the tree holds no artifact of what a correct archive looks like — the replacement paragraph and the `package` job are the intent's own answer ("nothing in the tree ever builds the archive or proves it installs"); a checked-in expected-member list is a second source of truth the story declined.
  - `[low]` `[reject]` intent-alignment: the runtime matrix rows are covered only by the `package` CI job, and no test in the diff imports IPM or builds an archive — carried from the 2026-09-19 `[false]` row: those rows are runtime rows and the script is their executor, running on every push.

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
- **AC1, the member comparison (DW-1334)** — pinning test: `ipm-archive.test.mjs`'s *the archive-contents comparison accepts a member list with doubled slashes at the joins*, which runs the script's own archive-contents block against a staged fixture with a stub `tar` — the doubled listing, the collapsed one, and a third where a staged bundle file is genuinely absent, so the comparison is pinned in both directions. `mutation: delete the repeated-slash normalization of MEMBERS from scripts/ci-ipm-archive.sh → red on the doubled list, node exit 1 read directly, 22 of 23`.
- **The scratch-root guard** — pinning test: `ipm-archive.test.mjs`'s *a degenerate TMPDIR does not widen the scratch-root guard to every absolute path*. `mutation: delete the empty-$SCRATCH_TMPDIR fallback from scripts/ci-ipm-archive.sh → red, node exit 1 read directly, 22 of 23, because TMPDIR=/ strips to the empty string and the arm becomes /?*`.
- **The interrupt trap** — pinning test: `ipm-archive.test.mjs`'s *SIGTERM mid-run still removes both containers by name*, whose build-container arm is a floor of two removals rather than one, since the script removes a stale container by name before `docker run`. `mutation: delete the build container's removal from cleanup() in scripts/ci-ipm-archive.sh → red, node exit 1 read directly, 22 of 23`. Each of these three was reverted with `scripts/ci-ipm-archive.sh` byte-identical by md5 (`705170f59e25afff6e55f21e374becd6`) before the next.
- **The failure diagnostic's raw listing** — pinning test: `ipm-archive.test.mjs`'s *the archive-contents comparison accepts a member list with doubled slashes at the joins*, whose reject arm also asserts the dump still carries its doubling. `mutation: dump $MEMBERS instead of $RAW_MEMBERS in the MISSING_BUNDLE diagnostic in scripts/ci-ipm-archive.sh → red naming the collapsed dump, node exit 1 read directly, 22 of 23`.
- **The `Scope="test"` exclusion under a doubled join** — pinning test: the same test's fourth arm, a member `src//cls/OcuPilot//Test//fixture.xml`. `mutation: replace the normalization with MEMBERS="$RAW_MEMBERS" in scripts/ci-ipm-archive.sh → red, node exit 1 read directly, 22 of 23`. This is the one arm where a missed doubling is a false green: `grep 'OcuPilot/Test/'` does not match the doubled path and does match it collapsed, confirmed directly.
- **The scratch root must be absolute** — pinning test: *a degenerate TMPDIR does not widen the scratch-root guard to every absolute path*, its relative-`TMPDIR` loop. `mutation: delete the absolute-$SCRATCH_TMPDIR arm from scripts/ci-ipm-archive.sh → red, node exit 1 read directly, 22 of 23`. These three were each reverted with the script byte-identical by md5 (`be2254e904682a674a360c696b036e23`).
- **AC2** — pinning test: the pre-stage `ipm-manifest.mjs --check` plus the archive-manifest-versus-roster comparison. One mutation per arm, because the first stops the script before the second runs. `mutation: change <Version> in module.xml by hand without touching src/OcuPilot/Install/Roster.cls → ipm-manifest.mjs --check exits 1 naming <Version>, and the script stops before any container starts`. `mutation: alter the staged copy of module.xml after it is staged (JWTAccessTokenTimeout 60 → 3600 in $DIR/module/module.xml), which --check does not see → the archive-manifest comparison exits 1 on the webapp= line for /api/ocupilot, naming both sides`.
- **AC3** — pinning test: `ui/tools/ipm-archive.test.mjs`'s network-isolation and verb-allow-list assertions. `mutation: delete --network none from one docker run line in scripts/ci-ipm-archive.sh → ipm-archive.test.mjs goes red naming that container`. **No network call is issued in either direction** — the mutation is observed entirely host-side, which is the point.
- **Integration AC** — pinning test: `ci.test.mjs`'s `DECLARED_GATES` equality and the widened `jobNames` equality. `mutation: delete one run: step from the package job in .github/workflows/ci.yml → ci.test.mjs goes red naming the orphaned declared gate`.

**Manual checks:**

- `tar tzf` the produced archive once by hand and read the member list: `module.xml`, `OcuPilot` classes, `ui/dist/ocupilot-ui/browser/`, and nothing under `OcuPilot/Test/`. Record the counts in `## Auto Run Result` rather than asserting them from the script's own output alone.
- Confirm on both containers that `SELECT COUNT(*) FROM %IPM_Repo.Definition` is 0 after the IPM import — the runtime half of AC3.

### QA pass (2026-09-20) (QA)

Four tests added to `ui/tools/ipm-archive.test.mjs` (17 -> 21 in the file; suite 1118 -> 1122), each with a
mutation applied, observed red, reverted, and the script confirmed byte-identical by md5
(`be2440169b8a041e7cb3a615174458cd`) before and after every one:

- `mutation: drop the "" arm from refuse_taken_name -> an empty --build-name or --install-name is refused, not silently taken` (the one guard arm no test reached).
- `mutation: drop -not -path '*/Test/*' from the STAGED_CLASSES find -> the staged-class count excludes OcuPilot/Test/ and counts only .cls files` (2 expected against 4 actual).
- `mutation: delete trap 'cleanup; exit 130' INT TERM -> SIGTERM mid-run still removes both containers by name, via the same trap as EXIT` (exit code `null` instead of 130, and neither container removed). **A dynamic proof, not an inspection**: the test spawns the script and signals it. The triage log had recorded this trap as patched while nothing had ever shown it red, which is the state Rule 19 exists to catch.
- `mutation: UnExpireUserPasswords("_SYSTEM") -> UnExpireUserPasswords("*") -> _SYSTEM is unexpired by name, in %SYS, strictly after the archive install and before smoke.sh` (AD-17's by-name discipline).

The package-verb allow-list got no new test: its existing sorted-set `deepEqual` already holds both directions.
The exporter half of AC1's class equality stays correctly unfalsifiable here - QA pinned the script's half
(the `find`), while what IPM's exporter emits is IPM's behavior, recorded as the story's named residual risk.

**Provenance.** The QA stage was killed mid-close-out by an API session limit. Its code was complete and is
verified here from the artifacts rather than from its report - the four tests are present and named, the file
runs 21 of 21 and the suite 1122 of 1122 with exit codes read directly, and the script's md5 shows no mutation
leaked. Its record was **not** written, so this subsection is the lead's, from the stage's reported mutations.

### Lead AD gate (2026-09-20)

AC3's mechanism - the one the owner's hold rests on - re-verified by the lead rather than taken from the
implement stage's report.

- mutation: drop `--network none` from the BUILD container's `docker run` (`scripts/ci-ipm-archive.sh:220`)
  -> `ui/tools/ipm-archive.test.mjs` red on *both containers the script creates run with no network at all*,
  asserting "a container is started without --network none, so 'it could not reach a package registry' would be
  a promise rather than a mechanism". Node's **real** exit code 1 (16 of 17), read directly and not through a
  pipeline; 0 and 17 of 17 after revert, with the file's md5 `be2440169b8a041e7cb3a615174458cd` identical before
  and after.
- A first attempt of this mutation deleted the `--network none` in the file's **header comment** (line 7) rather
  than a `docker run` line, and the suite stayed green - correctly, since nothing about the mechanism had changed.
  Recorded because the green was momentarily mistaken for a vacuous gate: a mutation that changes prose and not
  the code under test proves nothing in either direction, and the check is to confirm which line was edited
  before reading the result.
- The hold itself re-checked at the source, not inferred: `grep -ci '\bpublish\b' scripts/ci-ipm-archive.sh` is
  **0**; the only credential-shaped references are the policy comment and the two
  `SELECT COUNT(*) FROM %IPM_Repo.Definition` assertions; the protected-name guard refuses `ocupilot`,
  `ocupilot-slot-*` and all three slot throwaways, and refuses a build/install name collision; and no
  `ocupilot-ipm-*` container survived the run (`docker ps -a`), so the EXIT trap cleaned up.

### Code review (2026-09-20) (CR)

Three mutations applied to the code under test, observed red with node's exit code read directly,
reverted, and the file confirmed byte-identical by md5 before the next. Suite 1122 of 1122 after,
`ui/tools/ipm-archive.test.mjs` 21 of 21, `ci.test.mjs` 65 of 65, `lint-docs.sh` clean.

- `mutation: add a fifth command built from a shell variable, Shell("$EXTRA_VERB ocupilot",1,0), to
  scripts/ci-ipm-archive.sh -> every IPM command is a literal goes red naming the command`. The
  allow-list equality and the registry-token scan both stayed **green**, which is the hole: `ipmVerbs`
  reads `/Shell\("([a-z-]+)/`, so a command opening with `$` or a capital yields no verb and
  contributes to neither side of the equality. The new assertion requires the verb spelled out at the
  front of every command. Script md5 `be2440169b8a041e7cb3a615174458cd` before and after.
- `mutation: insert docker network connect bridge "$BUILD_NAME" before wait_for_session ->
  containers are created only by the two docker run lines goes red, node exit 1, 20 of 21`. *Both
  containers run with no network at all* stayed **green** — the flag is read off the creation line, so
  a network attached afterwards was invisible. `docker network` is now in the banned-forms list.
- `mutation: set the package job's node-version to 22.0.0 in .github/workflows/ci.yml -> every job that
  pins a literal Node goes red naming the package job, node exit 1, 64 of 65`. The previous form read
  `jobSlice(workflow, 'instance')` only and stayed green; the widened form also holds the list of
  literal-pinning jobs equal to the jobs that carry one. `ci.yml` md5 `c8bf4972f442b754cd764e43ae9059dd`
  before and after.

`scripts/ci-ipm-archive.sh` md5 is `6983c0a437acc61694dadffb03bbb539` after this pass's patches
(`be2440169b8a041e7cb3a615174458cd` was the pre-review file).

### Lead smoke gate (2026-09-20)

- Full class sweep on `ocupilot-b-ci`: `137 class(es), 1283 test(s), 0 failed, 0 probe leftovers, 0 overlaps`,
  exit 0 - unchanged by this story, which adds no ObjectScript class.
- `smoke.sh --container ocupilot-b-ci`: `executed=45 passed=45 failed=0 pending=2 skipped=0`, exit 0.
- `npm test`: 1,124 node tests and 644 component tests, 0 failed; `check-objectscript.py` 0 problems over 502 files.
- **AC1's end-to-end leg, proven on Linux for the first time** (run `35506409237`, `package` job **success**):
  `ocupilot.tgz (1083100 bytes, 135 class(es), 14 bundle member(s)) installed on a second fresh instance and
  smoke PASSED with 42 check(s) executed`; the archive's manifest declares the same 11 items as the roster; and
  **0 package-repository rows both before and after the install**, on containers started with no network, no port
  mapping and no durable volume. The hold is proven by mechanism rather than asserted.

## Auto Run Result

Status: done
Blocking condition: none

**Rework 2026-09-20 (DW-1334).** The member list is now built as `RAW_MEMBERS=$(tar tzf …)` and
collapsed once into `MEMBERS` with `sed 's#//*#/#g'`, so every archive-contents comparison below it
reads the same list whichever tar listed the archive and whatever IPM stored at the joins. No branch
is special-cased and `module.xml` is untouched. `RAW_MEMBERS` is kept because the failure diagnostic
is the only place the shape IPM actually stored is ever visible — the container is gone by the time
anyone reads the log — so that dump prints the listing as `tar` gave it.

The diagnosis's own explanation of the macOS-green / Linux-red split was replaced at origin: the
host's `bsdtar 3.5.3` lists `//` unchanged from gnu, ustar and pax archives, measured this pass, so
the listing does not explain it; the two runs' archives also differ by 427 bytes, so what differed
is more likely what IPM stored *(inference)*. The normalization holds under either explanation.

Files changed this pass: `scripts/ci-ipm-archive.sh` (the normalization, the raw-listing diagnostic,
the scratch-root guard's empty-`$TMPDIR` fallback, one corrected header sentence);
`ui/tools/ipm-archive.test.mjs` (21 → 23 tests: the doubled-slash comparison in both directions, the
degenerate-`TMPDIR` refusal, and the SIGTERM trap's build-container arm turned into a floor of two);
`README.md` (the trap is `EXIT`, `INT` and `TERM`, not `EXIT` alone); this spec.

**Review.** 55 findings across four layers: 0 high, 6 medium, 42 low, 6 false, 1 maybe-false. Nine
rows patched, grouped into seven fixes by root cause (3 medium, 4 low); three medium entries
deferred (the ledger's DW-1334 evidence line, the bundle arm's missing upper bound, the
`DECLARED -lt 11` floor); 43 rejected, each with its reason in the triage log.

**Follow-up review recommended: false.** This is a follow-up pass and no patched entry was `high`,
so the work has converged. Patched by verdict: medium 3, low 4.

**Verified.** `cd ui && npm run build` green; `cd ui && npm test` → 1,124 node tests and 644
component tests, 0 failed; `node --test tools/ipm-archive.test.mjs` 23 of 23 and
`tools/ci.test.mjs` 65 of 65; `/bin/sh -n` and `/bin/dash -n` on the script; `bash
scripts/lint-docs.sh` clean. Every exit code read directly. Three mutations, each reverted with the
script byte-identical by md5 `705170f59e25afff6e55f21e374becd6`, are recorded in `## Verification`.
The end-to-end `package` job was not run locally: a local run takes about an hour and macOS cannot
reproduce this defect, which is the whole reason CI is its gate. **CI has since run it and it is
green** -- run `35506409237` on head `a132686`, job `package` success: `ocupilot.tgz` (1,083,100
bytes, 135 class(es), 14 bundle member(s)) installed on a second fresh instance with smoke PASS over
42 executed checks, the manifest declaring the same 11 items as the roster, and 0 package-repository
rows both before and after. AC1's end-to-end leg, never before observed green on Linux, now has been.

**What landed.** `scripts/ci-ipm-archive.sh` (new): the two phases in order, on two containers of its
own started `--network none` from the pinned tag and removed on an `EXIT`, `INT` and `TERM` trap. It
runs `ipm-manifest.mjs --check` and refuses an absent bundle before staging anything; refuses the
live, slot and throwaway container names, the two names being equal, a floating or absent image tag,
and a `--dir` that is outside a scratch root or contains `..`; asserts zero `%IPM_Repo.Definition`
rows on both instances after the import and again after every verb; reads the artifact back from the
directory it wrote into; holds the archive's class members equal to the staged tree host-side, every
staged bundle file present by name, and its manifest equal to the roster's declarations; unexpires `_SYSTEM` by name as an operator act (AD-17); and reads `smoke.sh`'s status from
the command rather than through a pipeline. `ui/tools/ipm-archive.test.mjs` (new, 23 tests) pins the
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

**Follow-up review recommended (first pass): true.** Eleven medium entries were patched, so the rule sets it. The
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
