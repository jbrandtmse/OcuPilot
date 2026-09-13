---
title: 'Story 1.16: The IPM module, generated from one roster'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot installs only through the container start path. An operator who already runs IPM has no way in, and the moment a `module.xml` appears it becomes a second declaration of facts the installer already owns — the web applications, the package list, the bundle destination — which drift silently and install something other than what was reviewed.

**Approach:** Declare those facts once, as data, in `Install/Roster.cls`; make the installer read them instead of hard-coding them; generate `module.xml` from the same roster with a checker whose drift exit code is wired into `prebuild`, `prestart` and the pre-commit hook. The IPM path reuses `Install()` unchanged — it never forks a second install path and never unexpires a password.

## Boundaries & Constraints

**Always:** One install path — IPM's `<Invoke>` calls `OcuPilot.Install.Installer.Install()` with **zero** `<Arg>` children (DW-92), so `pUnexpire` keeps its `0` default and the IPM path can never reach `EnsureUnexpired`. The roster is the sole declaration of the module version, the seven package folders, the two production web applications' asserted properties, and the bundle source; every consumer reads it. Every instance-derived value — namespace, bundle directory — is asserted by `Install()` at runtime, never written as a literal into the manifest. `Install()` validates that its target namespace exists and fails loudly naming it (DW-12). Manifest/roster drift exits non-zero at three gates. The checker reports its scanned counts on every run, clean or refused, so "looked at nothing" is distinguishable from "found nothing wrong".

**Never:** No IPM dependency in the container start path — the pinned image has zero `%ZPM*`/`%IPM*` classes (AD-18; re-verified, see Design Notes). No `<CSPApplication>`. No `MatchRoles`, `Roles` or `%All` widened by the manifest (AD-10). No demo fixture on the IPM path (AD-25). No IPM install, uninstall or `verify` against the live `ocupilot` container — those run only on a throwaway compose project. No `docker compose up`/`down`/`restart` against this repository's compose file. No second entry point on `Installer`, and no install logic moved into `module.xml`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Manifest current | `module.xml` byte-equal to the generator's output | `ipm-manifest.mjs --check` exits 0, prints the package, application and resource counts it compared | No error expected |
| Roster changed, manifest stale | Roster edited, `module.xml` not regenerated | Exit 1 naming the element that drifted and the regenerate command | `prebuild`, `prestart` and pre-commit all fail |
| Manifest edited by hand | `module.xml` edited, roster untouched | Exit 1, same message — the comparison is symmetric, not a floor | Gates fail |
| Package folder added | New directory under `src/OcuPilot/` absent from the roster's `packages` | Exit 1 naming the directory | Gates fail |
| Class outside the package | A `.cls` under `src/OcuPilot/` declaring a class not named `OcuPilot.*` | Exit 1 naming file and class — `OcuPilot.PKG` would not ship it | Gates fail |
| `src/cls/` exists | Any directory `src/cls/` | Exit 1 naming IPM's silent resolution move | Gates fail |
| Roster unreadable | `Roster.cls` missing, or its XData unparseable | Exit 1 naming the file; **never** treated as an empty roster | Gates fail |
| IPM install, throwaway | `zpm install` from namespace N on a throwaway with IPM loaded | Both applications exist in N; `Install()` runs and repairs any drift; `/ocupilot` serves the shell and `/api/ocupilot` answers | Non-zero `Shell(...,1,1)` exit |
| IPM install, expired `_SYSTEM` | Throwaway started with no start hook, `_SYSTEM` still expired | Password is **still expired** after install (DW-92) | None — absence is the assertion |
| Neither candidate namespace | `HSCUSTOM` and `USER` both absent | `Install()` returns a failing `%Status` naming both candidates and the override, and creates nothing (DW-12) | Loud `%Status`, no partial install |
| Override names a missing namespace | `OCUPILOT_NAMESPACE` set to a namespace that does not exist | Start path fails naming that namespace, with no silent fallback (DW-12) | Container start exits 1 |
| Shipped archive | `zpm package` output | Archive contains the built bundle and no `OcuPilot.Test.*` | Non-zero exit |

</intent-contract>

## Code Map

- `src/OcuPilot/Install/Installer.cls` — the whole install path. `Names()` `:136-184` (name roster; probe literals `:168-170`; `shellDirectory` delegates to the handler `:175`). `ResolveNamespace()` `:189-192` — `$Select(Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")`, **no failure branch**; DW-12 lives here. Namespace guards `:426-429`, `:681-684`, `:784-788`. `Install(pProfile="", pUnexpire=0, pBundleSource="")` `:407`; `StartPath` `:678` → `Install("",1,...)` `:715`; the unexpire gate `:566-572`; `EnsureUnexpired` `:1141`. `EnsureShellApplication` `:1913-1926` and `EnsureApiApplication` `:1935-1951` — the `tWant` blocks to replace with roster reads. `EnsureWebApplication` `:1962-2000` — compares only the keys the caller set `:1971-1978`; `Type=2` `:1989` and `Description` `:1990` are create-only and never repaired. `EnsureShellFiles` `:1817-1833` — `pBundleSource=""` means *leave the installed bundle alone*. `StateFingerprint` `:2261-2372` with **two hand-kept CSV property lists** at `:2363-2364`; `ApplicationFingerprint` `:2379`. Constants to absorb: `#AUTHEUNAUTHENTICATED` `:82`, `#AUTHEPASSWORD` `:87`, `#MANAGEMENTGROUP` `:94`, `#JWTACCESSSECONDS` `:99`, `#JWTREFRESHSECONDS` `:103`. Prose already naming this story's contract: `:391`, `:565`.
- `src/OcuPilot/Api/StaticHandler.cls` — `RootDirectory()` `:107-118`; the app-path normalization `:110-114`; `$System.Util.DataDirectory()` `:116`; `:99-101` states why the data directory, not the install directory's `csp`. **The single authority for the bundle destination** — the manifest must call it, not restate it.
- `src/OcuPilot/Kernel/State/Base.cls` `:48-75` — the state/security name parameters. None is manifest-relevant; do not move them.
- `scripts/check-objectscript.py` — `FIXED_PACKAGES` `:109` (a second declaration of the seven folders), its rule `:339-347`, `MAX_CLASS_NAME_LENGTH` `:105`, and the "unreadable vocabulary is reported, never read as an empty set" rule `:663-681`. Harness: `scripts/test_check_objectscript.py`, `unittest`, `FixtureTreeCase` `:42-60` monkey-patches `ROOT`/`SCAN_ROOTS` to a temp tree — the pattern for driving a whole-tree checker against synthetic drift.
- `ui/tools/screen-mirror.mjs` — **the generator pattern to copy**: `extractXData()` `:69` (Node reading an ObjectScript XData block), `readSources()` `:186-222` (throws naming the file rather than returning a short population; sorts for determinism), write-vs-`--check` duality `:529-542`.
- `ui/tools/classic-links.mjs` `:348-354` — two independently-keyed populations compared for **equality, not a floor**; `:30-32` report-on-every-run.
- `ui/tools/classic-links.test.mjs` — **the falsifiability pattern to copy**: `syntheticTree()` `:63-72`, both drift directions `:339` and `:357`, the third differently-keyed source `:399-447`, non-empty input `:503`, spawned-process run `:554-569`, and the gate-wiring test `:510-552` asserting `|| STATUS=1` `:533-537` and that no chain swallows the check `:543-547`.
- `ui/package.json` — `prebuild` `:8`, `prestart` `:10`, `test:tools` `:13`; `version` `:3` is `0.0.0` and unconsumed.
- `.githooks/pre-commit` — `OS_TRIGGER` pathspec list `:75-80` (a git pathspec is not a shell glob — both `src/OcuPilot/*.cls` and `src/OcuPilot/**/*.cls` are needed, `:68-74`), the classic-links dispatch `:105-109`, the failure help text `:130-146`.
- `scripts/container-start.sh` — `SRC_DIR` `:76`, `BUNDLE_DIR` `:81`, the duplicated namespace `$Select` `:125` and its validation `:137`, `LoadDir` `:227`, `StartPath` `:230`, and `:192-198` on the IPM path having no start hook.
- `docker-compose.yml` — image `:7`, ports `:18-20`, `./src` and `./ui` read-only mounts `:29`/`:35` (**neither mounts the repo root, so a throwaway that IPM-loads the repo needs one**), start hook `:39`.
- `ui/angular.json` `:15` — `outputPath: dist/ocupilot-ui`; the browser dir is `ui/dist/ocupilot-ui/browser`.
- `src/OcuPilot/Test/UnexpireScope.cls` `:24` `TestIpmFormNeverReachesTheUnexpireStep` — already pins the zero-argument call shape; extend, do not duplicate.
- **Not in this repo:** IPM's schema is the `%XML.Adaptor` projection of `%IPM.Storage.*` — there is no `Module.xsd`. Vocabulary confirmed against `github.com/intersystems/ipm` tag **v0.10.9**; see Design Notes for the four findings that would otherwise be guessed wrong.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Install/Roster.cls` — **new**. `XData Manifest` holding JSON: module name/version/`sourcesRoot`, system requirements, the seven `packages`, the bundle source path, and per production application its path, description, `manifest` property map (emitted into `<WebApplication>`) and `installer` property list (instance-derived, asserted only by `Install()`). A `Get()` classmethod returns it as a `%DynamicObject`. Class doc names the `%sySecurityMacros.inc` constants the `AutheEnabled` numbers correspond to.
- `src/OcuPilot/Install/Installer.cls` — `EnsureShellApplication`/`EnsureApiApplication` build `tWant` from the roster (`manifest` values plus the computed `installer` values) instead of literals; `StateFingerprint`'s two CSV lists at `:2363-2364` derive from `manifest ∪ installer`; delete the five parameters at `:82-103` now that the roster owns those numbers. Probe-profile literals stay in `Names()` — the probe has no manifest.
- `src/OcuPilot/Install/Installer.cls` — `ResolveNamespace()` returns `""` when neither candidate exists; the three guards fail with a status naming `HSCUSTOM`, `USER` and the override, and create nothing; the guard accepts the current namespace as the install target and refuses only system namespaces, so an IPM install lands where `zpm install` was run (DW-12).
- `ui/tools/ipm-manifest.mjs` — **new**. Reads the roster's XData (via the `extractXData()` shape) and the `src/OcuPilot/` tree; writes `module.xml` with no argument, compares and exits 1 on drift with `--check`. Refuses an unreadable roster rather than reading it as empty.
- `module.xml` — **new**, at the repository root, generated and committed. `<SourcesRoot>src</SourcesRoot>`, `<Resource Name="OcuPilot.PKG"/>`, `<Resource Name="OcuPilot.Test.PKG" Scope="test"/>`, `<SystemRequirements Version=">=2026.2" IPMVersion=">=0.10.0"/>` (no `Health` attribute), one `<WebApplication>` per production application, `<FileCopy>` for the built bundle, and `<Invoke Class="OcuPilot.Install.Installer" Method="Install" Phase="Activate" When="After"/>` with **no `<Arg>` children**.
- `ui/package.json` — add `node tools/ipm-manifest.mjs --check` to `prebuild` `:8` and `prestart` `:10`, in the same `&&` chain shape as `screen-mirror.mjs --check`.
- `.githooks/pre-commit` — add `module.xml` to the `OS_TRIGGER` pathspec list `:75-80`; dispatch the checker inside that block in the `command -v node` / `|| STATUS=1` shape used at `:105-109`; add its stanza to the help text `:130-146`.
- `ui/tools/ipm-manifest.test.mjs` — **new**. Node `--test`, built on the `classic-links.test.mjs` structure.
- `src/OcuPilot/Test/Manifest.cls` — **new** `%UnitTest`. Pins the roster against what `Install()` actually asserts, and `StaticHandler.RootDirectory("/ocupilot")` against the bundle destination the manifest resolves.
- `src/OcuPilot/Test/UnexpireScope.cls`, `Test/WebApp.cls`, `Test/Installer.cls` — update for the deleted parameters and the new namespace-guard behavior; extend `UnexpireScope` to assert the committed `module.xml`'s `<Invoke>` carries no `<Arg>`.
- `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py` — derive `FIXED_PACKAGES` `:109` from the roster; refuse an unreadable roster per the rule at `:663-681`; extend the fixture-tree tests.
- `scripts/container-start.sh` — honor `OCUPILOT_NAMESPACE` at `:125`, validate it exists at `:137`, and fail naming it rather than falling back (DW-12).
- `README.md` — a section on installing with IPM, on choosing the install namespace and the two overrides, and the throwaway-container recipe for verifying an IPM install.

**Acceptance Criteria:**

- Given the committed `module.xml` and `Install/Roster.cls`, when `node tools/ipm-manifest.mjs --check` runs, then it exits 0 and prints the counts it compared; and given either file edited so they disagree, it exits 1 naming the drifted element — in **both** directions, not only when the manifest is short.
- Given a throwaway container with IPM 0.10.5 loaded and the repository mounted, when the module is installed from namespace `N`, then both web applications exist in `N` with exactly the roster's asserted properties, `/ocupilot` returns the shell and `/api/ocupilot` answers. **Integration AC (Rule 1)** — the consumer is IPM itself against a real runtime, not an inspection of the XML.
- Given that same throwaway started with no start hook so `_SYSTEM` is still expired, when the IPM install completes, then `_SYSTEM`'s password is still expired and no unexpire was attempted (**DW-92**).
- Given `zpm package`, when the archive is produced, then it contains the built Angular bundle and no `OcuPilot.Test.*` document, so install needs no Node toolchain.
- Given an instance where neither `HSCUSTOM` nor `USER` exists, when `Install()` runs, then it returns a failing `%Status` naming both candidates and the override and creates nothing; and given `OCUPILOT_NAMESPACE` naming a namespace that does not exist, the start path fails naming it without falling back (**DW-12**).
- Given the seven package folders, when one is added or removed in the tree without the roster, or a `.cls` declares a class outside `OcuPilot.*`, or `src/cls/` appears, then the checker exits 1 naming the file or directory.
- Given a property added to an application's asserted set, when it is added to the roster, then the manifest, `EnsureWebApplication`'s comparison and `StateFingerprint` all pick it up with no second edit; adding it to only one of them is impossible because only the roster declares it.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-17 (one installer class, two entry points, idempotent; the roster and the manifest resource list generated from one source; the IPM `<Invoke>` never unexpires), AD-18 (IPM is a distribution channel, never a runtime dependency), AD-10 (prohibited actions absent, not gated — the manifest may not widen `MatchRoles`/`Roles`), AD-21 (the shell's single purpose-built read-only matching role is the privilege floor), AD-28 (the two applications' authentication shapes), AD-38 (install completes before the first request; version stamping), AD-25 (no demo fixture on the IPM path), AD-27 (explicit image tag, never `latest-cd`), AD-9 and AD-16 (namespace is a runtime variable, switched by save and restore), AD-3 ("generated" means a checked-in artifact, reviewed like any other source), AD-45 (the readiness application is Story 1.17's; this story declares **two** applications, and the roster is what makes the third arrive in the manifest for free). Consistency Conventions: the seven fixed package folders under `src/OcuPilot/`, `module.xml` at the repository root "generated from the same roster as the installer", the 29-character cap on `%Persistent` names (neither new class is persistent), ISO-8601 UTC timestamps.

**Consumes:** Story 1.4 — `Install.Installer`, `StartPath`/`Install`'s argument contract, the throwaway-compose recipe, `container-start.sh`. Story 1.5 — `Api.StaticHandler.RootDirectory()`, the two web applications, the bundle directory. Story 1.9 — `screen-mirror.mjs`'s generator-plus-`--check` shape. Story 1.15 — `classic-links.mjs`'s equality-of-independent-populations checker and its gate-wiring test. Story 1.3 — `Kernel.State.Base`'s name parameters (read, not moved).

**Consumed-by:** Story 1.17 (`1-17-the-smoke-script-the-readiness-endpoint-and-ci`) — CI runs this checker on every change, and the readiness application's third `<WebApplication>` is added to the roster, not to the manifest. Epic 17's clean-clone story re-runs the same IPM install from a fresh clone. Every later story that adds a web application, a package folder or an asserted application property edits the roster and nothing else.

**Decision (overnight) — the roster is a class, not a new file format.** `Install/Roster.cls` with an `XData` JSON block, because both consumers already have a proven reader: `screen-mirror.mjs:69` reads XData out of `.cls` files from Node today, and ObjectScript reads it through `%Dictionary.CompiledXData`. A YAML or JSON file at the repo root would be a new artifact class outside `src/OcuPilot/`, which project policy fixes as the home of all project ObjectScript.

**Decision (overnight) — the manifest declares only instance-independent facts.** `NameSpace` and the shell's `Path` are resolved at runtime (`ResolveNamespace()`, `StaticHandler.RootDirectory()`), so the roster marks them `installer` and the generator omits them; IPM's `<WebApplication>` defaults `NameSpace` to the install namespace, and `Install()` — running in the same Activate phase, moments later — asserts and repairs both. The `manifest`/`installer` split is what lets the checker assert that their union equals the property set the installer asserts, which also retires the two hand-kept CSV lists at `Installer.cls:2363-2364` — a third declaration of the same set that exists today and can already drift silently.

**Decision (overnight) — the bundle destination is computed, never restated.** No IPM placeholder names `$System.Util.DataDirectory()_"csp/ocupilot/"`; `${cspdir}` resolves under the install directory, which `StaticHandler.cls:99-101` records as not writable on the pinned image. The manifest therefore uses IPM's arbitrary-ObjectScript form — `InstallDirectory="#{##class(OcuPilot.Api.StaticHandler).RootDirectory(""/ocupilot"")}"`, the application path coming from the roster — so the manifest calls the same single authority the installer and the handler call. `<FileCopy>` runs in Activate's `OnBeforePhase`, strictly before the `When="After"` `<Invoke>`, so the bundle is in place before `Install()` runs and `pBundleSource=""` correctly leaves it alone. Leave `Defer` off; ordering between a deferred copy and an Activate/After invoke is unconfirmed *(inference)*. **Confirm first:** that `#{...}` expands inside `InstallDirectory` (`%IPM.Utils.Module` placeholder expansion, ipm v0.10.9 `src/cls/IPM/Utils/Module.cls:2449-2493`). If it does not, fall back to `${dataDir}csp/<path>/` generated from the roster by the same normalization rule, and let `Test/Manifest.cls`'s `RootDirectory` assertion pin the two implementations together.

**Decision (overnight) — `<Invoke>` takes zero `<Arg>` children, and that is also how the bundle question is closed.** `Install` now has three formals, so passing `pBundleSource` would mean passing `pUnexpire` positionally. Placing the bundle with `<FileCopy>` instead keeps the call literally argument-free, which satisfies DW-92's letter and its intent at once and leaves `Test/UnexpireScope.cls:24`'s existing pin valid. Note that `Phase` must be set explicitly: its default is `Configure`, which is **not** in the `activate` chain, so a bare `<Invoke>` would never run (ipm v0.10.9 `src/cls/IPM/Lifecycle/Base.cls:165-188`).

**Decision (overnight) — the install namespace is the namespace you install from.** `ResolveNamespace()` stays the default for the container start path; the guard is relaxed to accept the current namespace and to refuse only system namespaces, which is both safer than the present equality test and the natural IPM override. The second override, for the container path, is `OCUPILOT_NAMESPACE`; an optional environment variable is consistent with the convention that none is *required* to run, and `OCUPILOT_DEMO` is the precedent.

**Four IPM facts that would otherwise be guessed wrong** (all confirmed against `github.com/intersystems/ipm` tag v0.10.9, whose schema is the `%XML.Adaptor` projection of `%IPM.Storage.*` — there is no `Module.xsd`): `<WebApplication>` has **no** fixed attribute list; it copies every attribute into a `Security.Applications` property and rejects any attribute that is not one, so the attribute is **`AutheEnabled`** (a bitmask: unauthenticated 64, password 32) and **not** `AuthenticationMethods`, which belongs to the deprecated `<CSPApplication>`. `<SourcesRoot>src</SourcesRoot>` + `<Resource Name="OcuPilot.PKG"/>` with **no** `Directory` attribute resolves to `src/OcuPilot/` — the processor's `cls` default is used only when `src/cls/` exists on disk, which is why the checker must refuse that directory. `<Resource Name="OcuPilot.Test.PKG" Scope="test"/>` removes the test classes from the shipped package, because a `.PKG` resource skips children covered by another `.PKG` in the same module. `<SystemRequirements>` takes `Health="0"` as a *refusal* of IRIS for Health, so the attribute is omitted, not set.

**AD-18 re-verified, and one clause corrected at its origin.** A whole-population query, not a probe: `%Dictionary.ClassDefinition` and `%Dictionary.CompiledClass` in `%SYS` (6,089 classes), `HSCUSTOM` (15,772) and `USER` (7,437) return **zero** matches for `%ZPM`-prefixed, `ZPM`-containing or `IPM`-containing names; `irislib/` (13,663 files) and `irissys/` (9,080) hold none either. The runtime claim holds. AD-18's further clause "nothing on the filesystem" does **not**: the image ships an unloaded offline installer at `/usr/irissys/dist/install/misc/zpm.xml` declaring `VERSION` `0.10.5`. That is a convenience for the throwaway verification, not a runtime dependency — the spine's wording is a lead/spine matter (Rule 20), flagged here rather than edited from a story.

**NFR tripwire check (Rule 5) — passes.** NFR-13's "IPM 0.10.x" is measurable as `IPMVersion=">=0.10.0"`, which `%IPM.Storage.SystemRequirements` evaluates against the installed IPM module's own version row. No amendment sought.

**Escalated planning-artifact defects, planned around, not resolved here:** DW-126 (EXPERIENCE.md publishes no Fixed-strings rows for several surfaces) and DW-139 (DESIGN.md and EXPERIENCE.md diverge with no precedence rule) are the owner's call at the decision sheet. This story renders no new user-facing copy, so neither binds it; the README text it does add is developer documentation, not a UX string. **DW-48** (the start hook compiles every `Test.*` class into the production instance) is owned by `burndown` and is not routed here; the `Scope="test"` resource narrows it for the IPM path only — the container start path is untouched, and no claim is made that DW-48 is closed.

## Verification

**What runs live and what runs only on a throwaway.** Read-only and idempotent work — compiling into `HSCUSTOM`, running `%UnitTest` classes, SQL probes — is safe against the live `ocupilot` container (web 52774, SuperServer 1973) and every IRIS MCP call passes `server: "ocupilot-iris"`. **An IPM install, uninstall, `package` or `verify` is a destructive whole-instance operation and must never run against it**; nor may IPM be loaded into it. Those run only on a throwaway compose project, per `README.md` § "Verifying the start path against a throwaway container": a standalone file generated with `docker compose -f docker-compose.yml config --format json`, changing only the project and container name, `restart`, the ports (52776/1975 — never 52774/1973) and the volume sources to a scratch directory, refusing to write a file that still names `./iris-data`, 52774 or 1973, plus one addition this story needs — a read-only mount of the repository root, since `docker-compose.yml:29`/`:35` mount only `./src` and `./ui` and IPM must see `module.xml`. Started with `docker compose -p ocupilot-ipm -f <scratch>/compose.json up -d --wait` and torn down with `down -v` plus removal of the scratch directory. **Never run bare `docker compose up`, `down`, `restart` or `down -v` in the repository root.** For the DW-92 check the throwaway overrides `command:` so no start hook runs and `_SYSTEM` stays expired.

**Commands:**
- `cd ui && node tools/ipm-manifest.mjs --check` — expected: exit 0, with the compared counts printed.
- `cd ui && npm run test:tools` — expected: all green, including `ipm-manifest.test.mjs`.
- `uv run scripts/test_check_objectscript.py` — expected: all green.
- `uv run scripts/check-objectscript.py` — expected: exit 0.
- `bash scripts/lint-docs.sh` — expected: clean, for the README change.
- `mcp__iris-dev__iris_execute_tests` with `server: "ocupilot-iris"` — **one test class per tool call, one call per message, awaited; never two in a message and never re-submitted on a client-side timeout.** Classes: `OcuPilot.Test.Manifest`, `OcuPilot.Test.UnexpireScope`, `OcuPilot.Test.WebApp`, `OcuPilot.Test.Installer`. Confirm each with the numeric-run-index `%UnitTest_Result` SQL probe before reporting it green.
- Throwaway only: load IPM with `do $System.OBJ.Load("/usr/irissys/dist/install/misc/zpm.xml","ck")`, then `##class(%IPM.Main).Shell("load -dev -v /opt/ocupilot",1,1)`, `Shell("package ocupilot -path /tmp/out",1,1)`, `Shell("list",1,1)`, `Shell("uninstall ocupilot",1,1)`. `zpm test`/`verify` are **not** used — `verify` provisions its own namespace and `test` runs `%UnitTest` under a second manager.
- 🚫 Do not `git commit` or `git push`.

**Pinning tests (Rule 19).** One mutation per criterion; each to be applied, observed red, reverted, with `git status --short` and `git diff --stat` unchanged afterwards.

- Manifest/roster drift, both directions → `ui/tools/ipm-manifest.test.mjs`, the two synthetic-tree cases. mutation: _(implement stage)_
- The checker cannot pass on an empty population → `ui/tools/ipm-manifest.test.mjs`, the non-empty-input and unreadable-roster cases. mutation: _(implement stage)_
- The check is named in `prebuild`, `prestart` and the hook, and none of the three swallows it → `ui/tools/ipm-manifest.test.mjs`, the gate-wiring test modelled on `classic-links.test.mjs:510-552`. mutation: _(implement stage)_
- The checker as a process: exit codes and report lines → `ui/tools/ipm-manifest.test.mjs`, the spawned-process case. mutation: _(implement stage)_
- Roster ≡ what `Install()` asserts ≡ what `StateFingerprint` fingerprints → `src/OcuPilot/Test/Manifest.cls`. mutation: _(implement stage)_
- The bundle destination the manifest resolves equals `StaticHandler.RootDirectory("/ocupilot")` → `src/OcuPilot/Test/Manifest.cls`. mutation: _(implement stage)_
- The committed `<Invoke>` carries no `<Arg>`, and the IPM form never reaches `EnsureUnexpired` (**DW-92**) → `src/OcuPilot/Test/UnexpireScope.cls`. mutation: _(implement stage)_
- Neither candidate namespace, and an override naming a missing namespace (**DW-12**) → `src/OcuPilot/Test/Installer.cls`. mutation: _(implement stage)_
- Package-folder, class-name and `src/cls/` refusals → `ui/tools/ipm-manifest.test.mjs` and `scripts/test_check_objectscript.py`. mutation: _(implement stage)_
- A real IPM install serves the shell and the API, the archive carries the bundle and no `Test.*`, and `_SYSTEM` stays expired → the throwaway run above, recorded in `## Auto Run Result`. mutation: _(implement stage)_

**Ledger (`owned_ledger=DW-12, DW-92`).** Both addressed above: DW-12 by the namespace-validation tasks and their two acceptance criteria; DW-92 by the zero-argument `<Invoke>`, its committed-manifest assertion and the live expired-`_SYSTEM` check on a throwaway.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
