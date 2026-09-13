---
title: 'Story 1.16: The IPM module, generated from one roster'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: '99dc045c0a4757024491dfa9351ffd14f2c63375'
baseline_commit: '99dc045c0a4757024491dfa9351ffd14f2c63375'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Uninstall is the only install entry point with no namespace guard, and now installs/removes against the caller's namespace.
    evidence: |-
      Install, StartPath and MarkInstalling all call GuardInstallNamespace; Uninstall does not.
      Called from a namespace OcuPilot was never installed into it probes the wrong
      mapping and can return OK having removed nothing.
    location: >-
      src/OcuPilot/Install/Installer.cls Uninstall
    severity: medium
  - summary: >-
      An application's Description is set on create only, never repaired, and is in neither AssertedProperties nor StateFingerprint.
    evidence: |-
      EnsureWebApplication writes Description on the create branch alone; the roster's
      `description` sits outside the manifest map. A roster description edit regenerates
      module.xml, passes every gate, and never reaches an installed application.
    location: >-
      src/OcuPilot/Install/Installer.cls EnsureWebApplication
    severity: medium
  - summary: >-
      WantFromRoster's three refusal branches, and ApplicationFingerprint's NOPROPERTIES guard, have no test.
    evidence: |-
      Both are Private, so covering them needs a test seam this pass did not build. The
      JavaScript equivalents of the same rule are covered thoroughly.
    location: >-
      src/OcuPilot/Install/Installer.cls WantFromRoster
    severity: medium
  - summary: >-
      On the IPM path the gateway-gap report says no web application was created, on the one install where two were.
    evidence: |-
      IPM's <WebApplication> elements create both applications in Activate, before the
      When=After Invoke, so EnsureWebApplication takes its existing branch and
      pCreatedApps stays empty.
    location: >-
      src/OcuPilot/Install/Installer.cls ReportGatewayGap
    severity: medium
  - summary: >-
      The pre-commit checks read the working tree, not the index, so a partially staged roster/manifest pair passes.
    evidence: |-
      Pre-existing shape of all four checks in that hook. Staging only module.xml while
      leaving the matching Roster.cls edit unstaged commits a manifest that does not
      match the committed roster.
    location: >-
      .githooks/pre-commit
    severity: medium
  - summary: >-
      The generated manifest is never validated as well-formed XML beyond its comments.
    evidence: |-
      The '--' failure was found by a live zpm load, not by inspection, and only that one
      instance is guarded; a roster value carrying a newline or a control character would
      fail the same way.
    location: >-
      ui/tools/ipm-manifest.mjs buildManifest
    severity: medium
  - summary: >-
      An OCUPILOT_NAMESPACE naming a system namespace compiles the whole tree into it before StartPath refuses.
    evidence: |-
      container-start.sh's LoadDir runs in the resolved namespace before StartPath's guard,
      and the sanitizer permits a leading %. No container has exercised this.
    location: >-
      scripts/container-start.sh
    severity: medium
  - summary: >-
      An unreadable /proc/1/environ makes container-start.sh treat OCUPILOT_NAMESPACE as absent and fall back.
    evidence: |-
      Same shape as the pre-existing OCUPILOT_DEMO read. DW-12 forbids a silent fallback,
      but the start hook cannot distinguish 'unset' from 'unreadable' today.
    location: >-
      scripts/container-start.sh
    severity: low
  - summary: >-
      A non-string or mis-cased resource.scope is emitted verbatim or dropped, with no roster-shape refusal.
    evidence: |-
      rosterShapeProblem validates filenameExtension but not scope; `scope: true` would
      emit Scope="true" and a mis-cased `Scope` would ship the test package.
    location: >-
      ui/tools/ipm-manifest.mjs rosterShapeProblem
    severity: low
  - summary: >-
      A third roster application would reach module.xml but not Install(): Names() resolves the keys 'shell' and 'api' only.
    evidence: |-
      The spec expects Story 1.17's readiness application to arrive in the manifest from a
      roster edit alone; the installer does not iterate the applications array.
    location: >-
      src/OcuPilot/Install/Installer.cls Names
    severity: medium
  - summary: >-
      'One roster edit and no second edit' holds for the manifest half only.
    evidence: |-
      A name added to an application's installer list makes WantFromRoster refuse until a
      matching computed value is added by hand in the ensure step.
    location: >-
      src/OcuPilot/Install/Installer.cls WantFromRoster
    severity: medium
  - summary: >-
      Uninstall's and StateFingerprint's move from ResolveNamespace() to the caller's namespace is unpinned.
    evidence: |-
      Every suite class runs in HSCUSTOM, where the two spellings coincide, and the
      namespace probe drives neither method. Reverting either line leaves the suite green.
    location: >-
      src/OcuPilot/Install/Installer.cls StateFingerprint, Uninstall
    severity: medium
  - summary: >-
      No test starts a gate or a container: prebuild, prestart, the hook and the start hook are asserted as source text.
    evidence: |-
      The intent states nine of twelve matrix rows as exit codes or container behavior.
      The checker's own refusal arm is now executed, but no gate is run and no container
      is started under OCUPILOT_NAMESPACE.
    location: >-
      ui/tools/compose.test.mjs, ui/tools/ipm-manifest.test.mjs
    severity: medium
  - summary: >-
      Row 8's install namespace N is only ever one of the two candidates.
    evidence: |-
      The probe arms the other of HSCUSTOM/USER, so 'not the resolved default' is proven
      and 'not a candidate at all' is not - which is also where the neither-candidate
      refusal would bite.
    location: >-
      src/OcuPilot/Test/Installer.cls
    severity: medium
  - summary: >-
      The demo-fixture namespace fix has no pinning test.
    evidence: |-
      Fixture.Create now uses the namespace the run stands in, but no test arms a default
      other than the current namespace and asserts the demo application's NameSpace.
    location: >-
      src/OcuPilot/Install/Fixture.cls Create
    severity: medium
  - summary: >-
      container-start.sh refuses a malformed OCUPILOT_NAMESPACE; container-health.sh silently uses the sanitized remainder.
    evidence: |-
      Unreachable in practice - a refused start means no health probe to disagree with -
      but the two scripts do not handle the same input the same way.
    location: >-
      scripts/container-health.sh
    severity: low
  - summary: >-
      docker-compose.yml carries no OCUPILOT_NAMESPACE placeholder beside OCUPILOT_DEMO.
    evidence: |-
      README tells operators to set it in the environment block; a reader of the compose
      file alone has no sign the variable exists. The running container predates this
      story, so its compose file is the owner's to change.
    location: >-
      docker-compose.yml
    severity: low
  - summary: >-
      extractXData counts braces per line without understanding JSON strings.
    evidence: |-
      Every roster value is balanced on its own line today; one that is not would silently
      truncate the extracted block. An undocumented constraint on what the roster may hold.
    location: >-
      ui/tools/screen-mirror.mjs extractXData
    severity: low
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

### Review Findings

**2026-09-13 — code review, first review, `review_tier: full-opus`, four layers.** 57 rows grouped
into 33 root-cause entries: 19 kept (high 0, medium 10, low 9), 14 rejected. All ten patch entries
were applied in this pass; nine of them carry a demonstrated mutation in `## Verification`. Three
mediums remain unresolved, all `escalated` with an owner and non-blocking per Rule 15.

- [x] [Review][Patch] The neither-candidate refusal sends the operator to an override that cannot rescue that instance [src/OcuPilot/Install/Installer.cls:283, scripts/container-start.sh:185] — `GuardInstallNamespace` refuses on `ResolveNamespace()=""` before anything reads `OCUPILOT_NAMESPACE`, so following the advice resolves `OK:` in the shell, compiles the tree with `LoadDir`, and is then refused by `StartPath` naming the variable the operator already set. Both messages now say the override does not substitute for creating a candidate — README's table row 3 already said so. Both still name the variable (matrix row 10, AC5, `Test/Installer.cls:799`).
- [x] [Review][Patch] `main()`'s drift refusal arm — the one all three gates depend on — was executed by no test [ui/tools/ipm-manifest.test.mjs] — the three spawned cases ended in the two success arms and in the unknown-argument arm, which returns before `checkManifest` is called. A spawned case over a drifted synthetic tree now asserts exit 1, the violations report and the counts line.
- [x] [Review][Patch] **A fact still stated twice:** `module.sourcesRoot` and the shipped `.PKG` resource are declared by the roster *and* held by the checker as `SRC_ROOT` / `SHIPPED_PACKAGE` [ui/tools/ipm-manifest.mjs] — the manifest is generated at the roster's spelling while the tree is walked at the checker's, so a roster that moved either would ship a module resolving where nothing looked and both halves would report clean. Both are now equalities the checker refuses on.
- [x] [Review][Patch] The HSCUSTOM-then-USER rule is declared in three places and was pinned only script-to-script [ui/tools/compose.test.mjs] — `Installer.ResolveNamespace()`'s candidates, in order, are now asserted against the literal both shell scripts restate. (The shell copies are forced: they run before any OcuPilot class is compiled.)
- [x] [Review][Patch] `container-start.sh`'s `BUNDLE_DIR` is a second declaration of `bundle.source`, pinned to nothing [scripts/container-start.sh:81] — an `angular.json` output move takes the roster, the manifest and `ipm-manifest.test.mjs` with it and leaves the start hook naming a directory that no longer exists; an absent bundle is a warn, so the container comes up healthy and `/ocupilot` answers 503 with no gate red. Now pinned to the roster.
- [x] [Review][Patch] Two fixes this story applied were revertible with nothing red [.githooks/pre-commit:84, scripts/container-health.sh:88] — the hook's `--diff-filter=ACMRD` (BH15) and `container-health.sh`'s inherit-first `-z` guard (EC3) were asserted by no test. Both now are.
- [x] [Review][Patch] `Test/WebApp.cls`'s two `NameSpace` oracles still read `ResolveNamespace()`, which this story demoted to "the default, not the target" [src/OcuPilot/Test/WebApp.cls:87,152] — the spec's own task list named the file and it was untouched; under `OCUPILOT_NAMESPACE`, or an IPM install from an ordinary namespace, both assertions go red on a *correct* install. Now `$NAMESPACE`, as `Test/Manifest.cls:103,110` already had it.
- [x] [Review][Patch] Two gate rules could pass over nothing, or pass something the install refuses [ui/tools/ipm-manifest.mjs] — the class-package rule is a loop that asserts once per class, so an empty scan exits 0 having looked at no class (unreachable in production only because the roster is itself a `.cls` in the tree — an incidental invariant, now a declared one); and a non-absolute application path passed every gate and was refused by `RosterNames` at install. Both are refusals now.
- [x] [Review][Patch] `bundle.destinationApplication` was a second spelling of an application's `path`, inside the file whose purpose is that there is only one [src/OcuPilot/Install/Roster.cls:85] — held to a declared application path by `rosterShapeProblem`.
- [x] [Review][Patch] Four claims in the diff that the diff itself disproves [scripts/container-start.sh:118, src/OcuPilot/Install/Installer.cls:75, src/OcuPilot/Test/RosterWant.cls:59, README.md:339] — the sanitizer's rationale ("interpolated into the ObjectScript below"; both here-docs are quoted and the value arrives via `GetEnviron`), `SYSTEMNAMESPACES`' doc (seven of the ten are database names, not namespaces), `RosterWant`'s stated mutation consequence (the value is dropped, not folded into `pWant`), and README's "through IPM — leaves whatever bundle is already installed" (true of `Install()`, false of the IPM path, where `<FileCopy>` moves it in `Activate` first). Corrected at their origins. Also: `InstallNamespaceSource`'s fingerprint comparison now asserts neither run answered `ERROR:` before comparing them.
- [x] [Review][Defer] **DW-206** Nothing marks the install gate `installing` on the IPM path, and IPM enables both applications before `Install()` runs (AD-38) — medium, fix-risk high, `escalated owner=burndown`. `MarkInstalling` is called only from `container-start.sh`; the roster models `invoke` as an object, not a list. A `Compile`/`Before` `<Invoke>` cannot mark on a *first* IPM install (the class is not compiled yet), so the fix needs a live throwaway run. AD-38's mark clause is written for the container start path and already tolerates a start that cannot mark.
- [x] [Review][Defer] **DW-207** `RosterNames`' non-absolute-path and empty-asserted-set refusals are exercised by nothing — medium, fix-risk high, `escalated owner=burndown`. The corrected `ApplicationFingerprint` / `AssertedProperties` docs name the empty-set refusal as the real anti-vacuity protection; deleting either branch leaves the suite green. Closing it needs an overridable roster seam on the production installer, which a review may not add. The JavaScript half of both rules is now covered.
- [x] [Review][Defer] **DW-213** `Fixture.Create`'s namespace fix is pinned by a source-text assertion read from the *instance's* compiled copy — medium, fix-risk high, `escalated owner=burndown`. The test never calls `Create`; any rewrite reaching the wrong namespace without touching the asserted literal stays green, and an uncompiled edit to the committed file leaves it green too.
- [x] [Review][Defer] **DW-205** `WantFromRoster` / `ApplicationFingerprint` lost `[ Private ]` for testability when `Test/InstallerProbe` — a subclass that already overrides a `Private` method — was an available seam. Low, `wontfix-accepted`.
- [x] [Review][Defer] **DW-208** `Test/GatewayGapIpmPath`'s only assertion is already made by `Test/WebApp.cls:439`, and nothing in the class touches the IPM path it is named for. Low, `wontfix-accepted`.
- [x] [Review][Defer] **DW-209** `Roster.Get` discards `IDKEYOpen`'s status and reports every failure as "the XData block is missing". Low, `wontfix-accepted`.
- [x] [Review][Defer] **DW-210** `bundle.destinationTemplate` is a stored literal rather than generated by the normalization rule the Design Notes named. Low, `by-design` — the Spec Change Log records the decision and the live equality pin the same sentence offered is implemented.
- [x] [Review][Defer] **DW-211** `IPMVersion=">=0.10.0"` is a floor while NFR-13 reads "IPM 0.10.x". Low, `by-design` — the Execution task states the expression verbatim; the imprecision is in the equivalence claim.
- [x] [Review][Defer] **DW-212** Two roster applications sharing a key or a path are accepted. Low, `wontfix-theoretical`.
- [x] [Review][Defer] **DW-201** (occurrence, not a new entry) `container-health.sh` also has no namespace-existence check where `container-start.sh` does.

**Rejected (14).** For the lead, not for rework: (1) the ledger reads `DW-194 open` while the cycle log records `DW-194_closed`; (2) `DW-192`/`193`/`196` are `routed owner=1-17` with no `- DW-n:` bullet under Story 1.17 in `epics.md` — only DW-204 was written (Rule 17 (1b)); (3) QA's pins for DW-191/195/198 are invisible from the ledger, so a future fixer meets an expected red with no entry explaining it. Rejected because the fix edits this spec: (4) two frontmatter `deferred:` entries now false (`WantFromRoster`… and the demo-fixture pin, both closed by QA); (5) `## Auto Run Result`'s verification numbers are stale — the checker now reports **116** classes (not 113), `npm run test:tools` **517** (not 517), and three `%UnitTest` classes were added after "312/312 across 32 classes at the time of writing; the QA and review passes added three more classes and the counts above are the lead's correction". Rejected as another story's tracking doc: (6) `spec-1-5`'s recorded mutation cites the now-deleted `Installer.JWTACCESSSECONDS`. Rejected as already-ledgered root causes: (7) a roster key rename reaching the manifest but not `Names()` (DW-192); (8) the manifest never parsed as XML (DW-197); (9) `Description` never repaired (DW-199); (10) `check-objectscript.py`'s XData reader drops comment-looking lines (DW-204's family). Rejected as low with no user- or developer-reachable defect: (11) `container-start.sh`'s `tOutcome` `$Select` rewritten with identical semantics; (12) a third `%UnitTest` class installs the shared `probe` profile (the project's one-run-at-a-time rule already governs it); (13) `InstallNamespaceSource`'s `%OnNew` override that only calls `##super`; (14) fingerprints captured before and after the CSV removal are not comparable (theoretical; no stored fingerprint survives a build).

## Spec Change Log

- **Decision (overnight) — `#{...}` does not expand in `<FileCopy InstallDirectory>`, so the spec's named fallback was taken.** Observed on the throwaway: `InstallDirectory` is `Required` and validated in IPM's **Validate** phase, which runs before **Compile**, so the handler class this module installs is loaded but not yet compiled, the expression yields `""`, and the whole module fails validation. The manifest therefore carries `Target="${dataDir}csp/ocupilot/"` from the roster, and `Test/Manifest.cls` expands it live and requires equality with `StaticHandler.RootDirectory("/ocupilot")` and the `Path` install sets — which is the pin the spec asked for either way.
- **Decision (overnight) — the namespace probe's seam moved down from `ResolveNamespace()` to a new `Installer.NamespaceExists()`.** As first written, `Test/NamespaceProbe` overrode `ResolveNamespace()` itself, so DW-12's candidate order and empty answer were replaced by the test rather than exercised by it: the mutation the test's own doc comment named (answer `"USER"` when neither candidate exists) did **not** go red. Arming namespace *existence* instead leaves the resolver as the code under test, and that mutation is now red on all three entry points.

## Review Triage Log

### 2026-09-13 — Review pass
- verdicts: 59 findings — high 0, medium 30, low 29, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` BH1 Uninstall is the one entry point with no namespace guard, and now takes the caller's namespace — real: Install/StartPath/MarkInstalling call GuardInstallNamespace, Uninstall does not. Adding the guard refuses state this pass did not demonstrate, so it is not a patch.
  - `[medium]` `[reject]` BH2 GuardInstallNamespace refuses on an instance carrying neither candidate even though the target is $NAMESPACE — spec-bound: I/O matrix row 10 states this exact behavior, and the fix would edit the intent contract.
  - `[low]` `[patch]` BH3 Both refusal messages advertise OCUPILOT_NAMESPACE, which Install() never reads — confirmed: only the two shell scripts call GetEnviron. Reworded so the variable is named as the container start path's, and the system-namespace refusal no longer mentions it.
  - `[low]` `[patch]` BH4 ApplicationFingerprint's NOPROPERTIES doc claims to fix a vacuity it does not — confirmed: the constant is as run-invariant as an empty component. Doc now states what the guard does (absent vs nothing-compared) and names RosterNames' refusal as the real protection.
  - `[low]` `[patch]` BH5 Roster.AssertedProperties' doc says ApplicationFingerprint renders '' as an empty component — confirmed contradiction with the same diff. Doc corrected to NOPROPERTIES and to RosterNames' earlier refusal.
  - `[medium]` `[patch]` BH6 The two application paths are declared in both the roster and Names() — confirmed at Installer.cls Names(). Names() now takes the production paths from the roster (probe keeps its distinct literals), so <WebApplication Name> and the application install creates are one declaration.
  - `[medium]` `[defer]` BH7 Description is create-only, never repaired, and outside the asserted set — real, and pre-existing: the spec's Code Map already records Description as create-only.
  - `[medium]` `[defer]` BH8 WantFromRoster's three refusal branches have no test — real: the method is Private, so covering it needs a test seam this pass did not build.
  - `[medium]` `[defer]` BH9 On the IPM path the gateway-gap report says no application was created — real: IPM creates both applications in Activate before the When=After Invoke, so pCreatedApps is empty. Detecting it adds surface.
  - `[low]` `[reject]` BH10 Roster.Get accepts a JSON array — real but fails closed with a named error, and the generator gate refuses such a roster before it reaches IRIS; the fix adds a branch.
  - `[low]` `[patch]` BH11 Stale ':663-668' citation in two files — confirmed: those lines are regexes. Both now cite read_fixed_packages by name.
  - `[low]` `[reject]` BH12 The spec's Auto Run Result still reads ready-for-dev — that section is written by this pass's finalize step.
  - `[medium]` `[patch]` BH13 The write-path test rewrites the tracked module.xml — confirmed. The case now restores the original bytes in a finally, so a suite run never leaves a committed file modified.
  - `[medium]` `[defer]` BH14 The pre-commit checks read the working tree, not the index — real, and the pre-existing shape of all four checks in that hook.
  - `[medium]` `[patch]` BH15 --diff-filter=ACMR cannot see the deletion the new tree-equality rule is about — confirmed: a commit that only deletes a package folder fired no trigger. Filter is now ACMRD.
  - `[low]` `[patch]` BH16 The two hook scripts differ on a malformed override and the parity test checks only the ObjectScript half — confirmed. The parity test now also holds both files to the PID 1 read and the export; the sanitize-and-refuse asymmetry is deferred.
  - `[low]` `[reject]` BH17 container-health.sh sets $NAMESPACE without an existence check — the probe fails, correctly, and the start hook refuses such a value before a container is ever healthy; the fix adds branches to a diagnostic path.
  - `[low]` `[defer]` BH18 docker-compose.yml carries no OCUPILOT_NAMESPACE placeholder — real discoverability gap; the running container predates this story and its compose file is the owner's to change.
  - `[low]` `[patch]` BH19 The README's IPM block is fenced bash but carries IRIS-session commands — confirmed. Now fenced objectscript, with ';' comments.
  - `[low]` `[patch]` BH20 The README advertises zpm install from a registry that does not exist — confirmed against the release policy. Now reads 'once a registry carries it -- none does yet'.
  - `[low]` `[patch]` BH21 The namespace table omits the neither-candidate outcome — confirmed. A third row states the refusal and its remedy.
  - `[low]` `[patch]` BH22 TestNeitherCandidateNamespaceIsRefusedByName's closing assertion cannot observe what it claims — confirmed: it compared $NAMESPACE with the resolver's answer. It now compares with the namespace captured before the refusals.
  - `[low]` `[reject]` BH23 SYSTEMNAMESPACES lists database names among namespaces — real but inert; the entries that matter (ENSLIB, HSLIB, HSSYS, DOCBOOK) are namespaces, and trimming the rest buys nothing.
  - `[low]` `[patch]` BH24 compose.test.mjs's NONE slice runs into the *) fallback — confirmed Rule 19 hole: the fallback also carries exit 1. The slice is now bounded at its own ';;' and asserted not to contain '*)'.
  - `[medium]` `[defer]` BH25 The generated manifest is never checked for XML well-formedness beyond its comments — real: the '--' failure was found live, and only that instance is guarded.
  - `[low]` `[defer]` BH26 extractXData counts braces per line without understanding JSON strings — real but degrades to a refusal; it is an undocumented constraint on roster values.
  - `[medium]` `[patch]` BH27 Any mistyped flag rewrites the manifest — confirmed: the default was 'write'. main() now refuses an unknown argument, exits 1, and writes nothing; a spawned test covers it.
  - `[low]` `[reject]` BH28 The manifest carries no registry metadata — no registry carries the module and none may before the release date; adding elements later is the roster-plus-generator edit every new element takes.
  - `[low]` `[reject]` BH29 'Seven' is hard-coded in prose beside the array that defines it — accurate today, and the two classic-links strings are pre-existing.
  - `[medium]` `[defer]` EC1 OCUPILOT_NAMESPACE naming a system namespace compiles the tree into it before StartPath refuses — real: LoadDir runs before StartPath in the same session. Refusing a %-prefixed override in the shell guards a path no container has exercised.
  - `[low]` `[defer]` EC2 An unreadable /proc/1/environ makes container-start.sh treat the override as absent — real, and the same shape as the pre-existing OCUPILOT_DEMO read.
  - `[medium]` `[patch]` EC3 container-health.sh blanks an OCUPILOT_NAMESPACE it already inherited — confirmed: the assignment always overwrote. It now falls back to PID 1 only when the variable is unset.
  - `[medium]` `[defer]` EC4 Staging only one of the roster and the manifest passes the hook — same root cause as BH14.
  - `[medium]` `[patch]` EC5 Any argv other than --check takes the write path — same root cause as BH27; fixed with it.
  - `[medium]` `[patch]` EC6 npm test mutates the tracked module.xml — same root cause as BH13; fixed with it.
  - `[low]` `[defer]` EC7 A non-string or mis-cased resource.scope is emitted or dropped silently — real; the roster is committed and byte-compared, so the blast radius is one reviewed edit.
  - `[low]` `[reject]` EC8 Test/Manifest.cls expands only the ${dataDir} spelling the generator also accepts as {$dataDir} — fails closed: the other spelling makes the ObjectScript pin red, not green.
  - `[low]` `[patch]` EC9 A chain link joined with a single & would background the check and pass every assertion — confirmed hole in both gate-chain tests; '&' added to the forbidden per-segment character class.
  - `[medium]` `[defer]` EC10 A third roster application would reach the manifest but not Names() — real, and Story 1.17's: the roster's applications array is not iterated by the installer.
  - `[low]` `[reject]` EC11 A formal whose default contains a comma would break the FormalSpec split — theoretical; no formal on Install has one.
  - `[medium]` `[reject]` EC12 'Install() validates that its target namespace exists' is not what the guard does — spec-bound: matrix row 10 is the operative statement and is implemented; the Boundaries sentence is looser than the row.
  - `[medium]` `[reject]` EC13 The bundle directory is a second spelling in the manifest — spec-bound: the Spec Change Log records why #{...} is impossible and names the live equality pin as the mitigation the spec itself proposed.
  - `[medium]` `[defer]` EC14 'One roster edit and no second edit' holds only for the manifest half — real: adding a name to an installer list needs a matching computed value in the ensure step.
  - `[low]` `[reject]` EC15 UnexpireScope does not read module.xml's bytes — by design and documented in both classes: the repository is not mounted into the instance, so the bytes are pinned in ipm-manifest.test.mjs.
  - `[medium]` `[patch]` VG1 Demo fixtures still resolve the default namespace, not the one install used — confirmed at Fixture.cls: under OCUPILOT_NAMESPACE the fixtures would be created in a namespace OcuPilot was never installed into. Now uses the namespace the run is standing in, as Uninstall and StateFingerprint do.
  - `[medium]` `[defer]` VG2 Uninstall's and StateFingerprint's namespace change is unpinned — real: every suite class runs where the two namespaces coincide, and the probe drives neither method.
  - `[medium]` `[patch]` VG3 bundle.source is pinned only against the generator's own fixture — confirmed. A new case compares the shipped roster's bundle.source with ui/angular.json's outputPath plus /browser/.
  - `[medium]` `[patch]` VG4 The parity test asserts only the ObjectScript half, leaving container-health.sh's shell half unpinned — confirmed; the two shell assertions moved into the both-files loop.
  - `[low]` `[patch]` VG5 Test/Installer.cls's closing assertion does not test what its message says — same root cause as BH22; fixed with it.
  - `[low]` `[patch]` VG6 The src/cls refusal assertion matches the bare substring 'cls' — confirmed Rule 19 weakness; tightened to /src[/\\]cls/.
  - `[low]` `[reject]` VG7 The spec's Auto Run Result is unwritten — same as BH12: this pass's finalize step writes it.
  - `[medium]` `[patch]` VG8 A test run leaves a tracked file modified — same root cause as BH13; fixed with it.
  - `[medium]` `[defer]` VG9 The ObjectScript half of the never-read-as-empty rule is unexercised — same root cause as BH8.
  - `[medium]` `[reject]` IA1 Matrix row 10's candidate precondition, written for the container path, is applied verbatim to the IPM path — same as BH2: spec-bound.
  - `[medium]` `[patch]` IA2 The two application paths remain declared in both Roster.cls and Names() — same root cause as BH6; fixed with it.
  - `[medium]` `[patch]` IA3 The checker's refusal exit arm is executed by no test, and the gates are asserted as text — the exit arm half is now executed by the unknown-argument case (status 1, nothing written); running the gates themselves is deferred.
  - `[medium]` `[defer]` IA4 Row 8's namespace N is only ever one of the two candidates — real: the probe arms the other candidate, never a third namespace.
  - `[low]` `[reject]` IA5 The bundle template restates one output of RootDirectory rather than its rule — spec-bound: the single live equality pin is the mitigation the spec chose.
  - `[low]` `[defer]` IA6 Minor surface notes: the start/health sanitize asymmetry and compose delivery of the variable — the parity half is patched under BH16; the asymmetry itself is deferred.

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

- Manifest/roster drift, both directions → `ui/tools/ipm-manifest.test.mjs`, the two synthetic-tree cases. mutation: `firstDrift`'s `expected === actual` relaxed to `expected.length <= actual.length`, turning the equality into a floor -> both "a roster edited without regenerating is a refusal naming the drifted element" and "a manifest edited by hand is the same refusal" went red; the other 23 cases stayed green.
- The checker cannot pass on an empty population → `ui/tools/ipm-manifest.test.mjs`, the non-empty-input and unreadable-roster cases. mutation: `checkManifest`'s unreadable-roster early return changed from `ok: false` to `ok: true` -> "an unreadable roster is reported, not read as an empty roster" went red.
- The check is named in `prebuild`, `prestart` and the hook, and none of the three swallows it → `ui/tools/ipm-manifest.test.mjs`, the gate-wiring test modelled on `classic-links.test.mjs:510-552`. mutation: two, separately -- (a) ` && node tools/ipm-manifest.mjs --check` deleted from `ui/package.json`'s `prebuild`; (b) `|| STATUS=1` dropped from the hook's dispatch -> "the check is named in prebuild, in prestart and in the pre-commit hook" went red to each.
- The checker as a process: exit codes and report lines → `ui/tools/ipm-manifest.test.mjs`, the spawned-process case. mutation: the counts `report.push` deleted from `checkManifest` -> "run as a process over the shipped tree, --check exits 0 and prints its report" and "the committed module.xml is current, and its counts match the shipped tree" went red.
- Roster ≡ what `Install()` asserts ≡ what `StateFingerprint` fingerprints → `src/OcuPilot/Test/Manifest.cls`. mutation: `Roster.AssertedProperties` stopped folding its `installer` half -> `TestAssertedPropertiesIsTheUnionOfBothHalves` went red on both applications (run 1026).
- The bundle destination the manifest resolves equals `StaticHandler.RootDirectory("/ocupilot")` → `src/OcuPilot/Test/Manifest.cls`. mutation: `bundle.destinationTemplate` changed to `${dataDir}csp/ocupilotbundle/` -> `TestBundleDestinationIsTheHandlersOwnAnswer` went red on both the handler comparison and the `Path` install set (run 1027).
- The committed `<Invoke>` carries no `<Arg>`, and the IPM form never reaches `EnsureUnexpired` (**DW-92**) → `src/OcuPilot/Test/UnexpireScope.cls`. mutation: two -- (a) `Install`'s `pUnexpire As %Boolean = 0` changed to `= 1` -> `TestInstallsArgumentContractMakesTheZeroArgumentInvokeSafe` and `TestIpmFormNeverReachesTheUnexpireStep` went red (run 1036); (b) live, the roster's `invoke.method` changed `Install` -> `StartPath`, regenerated and installed on the throwaway -> `_SYSTEM`'s `ChangePassword` went 1 -> 0 and `/api/atelier/` 401 -> 200, which is the unexpire this story forbids.
- Neither candidate namespace, and an override naming a missing namespace (**DW-12**) → `src/OcuPilot/Test/Installer.cls`. mutation: three -- (a) `ResolveNamespace`'s empty-answer branch removed so it answers `"USER"` when neither candidate exists -> `TestNeitherCandidateNamespaceIsRefusedByName` went red, including "and nothing was created, changed or removed" (run 1034); (b) the old `$NAMESPACE '= ..ResolveNamespace()` equality test restored in `GuardInstallNamespace` -> `TestTheInstallTargetIsTheNamespaceInstallWasCalledFrom` went red naming the install namespace it demanded (run 1035); (c) `container-start.sh`'s `MISSING:*)` branch made to fall back to `HSCUSTOM` instead of exiting -> `compose.test.mjs`'s start-hook override test went red.
- Package-folder, class-name and `src/cls/` refusals → `ui/tools/ipm-manifest.test.mjs` and `scripts/test_check_objectscript.py`. mutation: three -- (a) the `missingFromRoster` loop made to iterate an empty array -> "a package folder the roster does not declare is a refusal naming the directory" went red; (b) the `src/cls` shadow-directory check disabled -> "src/cls/ is a refusal" went red; (c) `check-objectscript.py`'s `read_fixed_packages` stopped recording its "could not be read" problem -> `test_a_missing_roster_is_reported_not_read_as_empty_or_admitting_everything` went red.
- A real IPM install serves the shell and the API, the archive carries the bundle and no `Test.*`, and `_SYSTEM` stays expired → the throwaway run above, recorded in `## Auto Run Result`. mutation: the roster's test resource lost its `"scope": "test"`, regenerated and re-packaged on the throwaway -> the archive carried 90 `OcuPilot/Test/` entries where the shipped one carries 0. The `_SYSTEM` half of this criterion is the previous bullet's mutation (b).
- (QA) `WantFromRoster`'s three refusal branches and `ApplicationFingerprint`'s `NOPROPERTIES` guard (DW-194) → `src/OcuPilot/Test/RosterWant.cls`; both methods made Public, the same documented deviation `EnsureGrant` already carries. mutation: four, separately -- (a) the "both as a manifest value and as instance-derived" branch deleted -> `TestRefusesAPropertyDeclaredAsBothManifestAndInstaller` went red; (b) the "computed no value for it" guard's `'$Data(pComputed(tName))` inverted -> `TestRefusesAnInstallerPropertyWithNoComputedValue` went red; (c) the "which the roster does not mark instance-derived" branch deleted -> `TestRefusesAComputedValueTheRosterDoesNotMarkInstanceDerived` went red; (d) `ApplicationFingerprint`'s `If pProperties = "" Quit "NOPROPERTIES"` guard deleted -> `TestApplicationFingerprintReportsNoPropertiesRatherThanAnEmptyComponent` went red (run 1062, all four; reverted, run 1063 green).
- (QA) `StateFingerprint` and `Uninstall` act on the caller's namespace, not `ResolveNamespace`'s default (DW-191, pinned rather than guarded) → `src/OcuPilot/Test/InstallNamespaceSource.cls`, driven through the armed `NamespaceProbe` per `Test/Installer.cls`'s own DW-12 pattern. mutation: two, separately -- (a) `StateFingerprint`'s `Set tInstallNs = tOrigNS` changed to `Set tInstallNs = ..ResolveNamespace()` -> `TestStateFingerprintReadsTheCallersNamespaceNotTheResolvedDefault` went red; (b) the same change in `Uninstall` -> `TestUninstallActsOnTheNamespaceItWasCalledFrom` went red (run 1064; reverted, run 1065 green).
- (QA) `Fixture.Create` binds demo fixtures to `$NAMESPACE` at entry, not `Installer.ResolveNamespace`'s default (DW-194's third item) → `src/OcuPilot/Test/InstallNamespaceSource.cls`, a source pin against the compiled UDL (`%Compiler.UDL.TextServices.GetTextAsString`) since the live divergence is unreachable on this instance -- the same limitation the spec's own VG2/IA4 record. mutation: `Set tInstallNs = tOrigNS` changed to a call into `Installer.ResolveNamespace()` -> `TestFixtureCreateUsesTheCallersNamespaceNotTheResolvedDefault` went red (run 1064; reverted, run 1065 green).
- (QA) `LoadDir` compiles the source tree before `StartPath`'s own namespace guard can refuse a system namespace (DW-195, deferred) → `ui/tools/compose.test.mjs`, pinning the current, deferred ordering rather than a fix. mutation: two, separately -- (a) a literal `IsSystemNamespace` string added to `container-start.sh`, simulating a fix -> the "no system-namespace check of its own" assertion went red; (b) the `StartPath($DEMO_ARG` text moved ahead of `LoadDir(` -> the ordering assertion went red; both reverted, tree unchanged.
- (QA) On the IPM path, an empty `pCreatedApps` reports "no web application was created" even though IPM's own `<WebApplication>` elements created both applications in this same `Activate` phase (DW-198, deferred) → `src/OcuPilot/Test/GatewayGapIpmPath.cls`, pinning the current message rather than a fix (detecting the shape "adds surface" per the review's own BH9/EC9). mutation: the message text changed -> `TestEmptyCreatedAppsReportsNoApplicationWasCreated` went red (run 1066; reverted, run 1067 green).

- (CR) The checker's refusal arm as a process, and the four rules a review found could pass over nothing or over a second declaration → `ui/tools/ipm-manifest.test.mjs`. mutation: five, separately -- (a) `process.exitCode = 1` deleted from `main()`'s violations arm -> "run as a process over a drifted tree, --check exits 1" went red; (b) the `roster.module.sourcesRoot !== basename(srcRoot)` refusal disabled -> "a roster whose sourcesRoot is not the tree this check walks" went red; (c) the `bundle.destinationApplication` cross-check disabled -> "a bundle destination naming no declared application" went red; (d) the `classes.length === 0` refusal disabled -> "a source tree holding no class at all" went red; (e) the non-absolute-path guard disabled -> "an application path that is not absolute" went red. Each applied, observed red, reverted; `git status --short` and `git diff --stat` unchanged.
- (CR) The two gate fixes this story applied, and the third declaration of the candidate order → `ui/tools/ipm-manifest.test.mjs`, `ui/tools/compose.test.mjs`. mutation: four, separately -- (a) `--diff-filter=ACMRD` reverted to `ACMR` in `.githooks/pre-commit` -> the gate-wiring test went red; (b) `container-health.sh`'s `if [ -z "${OCUPILOT_NAMESPACE:-}" ]` guard removed -> the DW-12 parity test went red; (c) `BUNDLE_DIR` pointed at another directory -> the bundle-source pin went red; (d) `ResolveNamespace`'s two candidates reordered -> the candidate-order assertion went red. All reverted, tree byte-identical.
- (CR) `Test/WebApp.cls`'s two `NameSpace` oracles, and the four corrected claims, carry **no** demonstrable mutation on this instance, and are recorded as such rather than claimed: the suite runs in `HSCUSTOM`, where `$NAMESPACE` and `ResolveNamespace()` coincide, so reverting either oracle stays green -- the same limitation DW-191/DW-213 record. Verified instead by re-running the affected classes green after the change: `OcuPilot.Test.Installer` 26/26 (run 1072), `OcuPilot.Test.WebApp` 17/17 (run 1073), `OcuPilot.Test.InstallNamespaceSource` 3/3 (run 1074), `OcuPilot.Test.RosterWant` 5/5 (run 1075).

**Ledger (`owned_ledger=DW-12, DW-92`).** Both addressed above: DW-12 by the namespace-validation tasks and their two acceptance criteria; DW-92 by the zero-argument `<Invoke>`, its committed-manifest assertion and the live expired-`_SYSTEM` check on a throwaway.

## Auto Run Result

**Summary.** `Install/Roster.cls` is now the one declaration of the module's identity, its seven
package folders, its resources, its bundle, and the two production web applications' paths,
descriptions and asserted properties. Three consumers read it and nothing else declares its
contents: `Install()` builds `tWant` and `StateFingerprint`'s property lists from it,
`ui/tools/ipm-manifest.mjs` generates and drift-checks the committed `module.xml` from it, and
`scripts/check-objectscript.py` takes its fixed-package set from it. The drift check is an
equality in both directions and is wired into `prebuild`, `prestart` and the pre-commit hook.
The IPM path reuses `Install()` with a zero-argument `<Invoke>`; DW-12's namespace validation and
the `OCUPILOT_NAMESPACE` override land in the installer and both container scripts.

**Files changed.**
- `src/OcuPilot/Install/Roster.cls` — new: the `XData Manifest` declaration, `Get()`, `Application()`, `AssertedProperties()`.
- `src/OcuPilot/Install/Installer.cls` — roster-driven `Names()`/`RosterNames()`/`WantFromRoster()`; five parameters deleted; `ResolveNamespace()` answers `""` and probes through the new `NamespaceExists()`; the three guards share `GuardInstallNamespace()`.
- `src/OcuPilot/Install/Fixture.cls` — demo fixtures bind to the namespace install ran in, not the resolved default.
- `ui/tools/ipm-manifest.mjs`, `ui/tools/ipm-manifest.test.mjs` — new: the generator, its `--check` mode and 27 cases.
- `module.xml` — new, generated and committed at the repository root.
- `src/OcuPilot/Test/Manifest.cls`, `src/OcuPilot/Test/NamespaceProbe.cls` — new: the roster-against-the-instance pins and the namespace-existence seam.
- `src/OcuPilot/Test/Installer.cls`, `src/OcuPilot/Test/UnexpireScope.cls`, `ui/tools/compose.test.mjs`, `ui/tools/classic-links.test.mjs` — DW-12, DW-92 and gate-wiring pins.
- `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py` — `FIXED_PACKAGES` read from the roster, with the unreadable-roster refusal.
- `scripts/container-start.sh`, `scripts/container-health.sh` — `OCUPILOT_NAMESPACE`, resolved identically and failing loudly.
- `ui/package.json`, `.githooks/pre-commit`, `README.md` — the three gates and the operator documentation.

**Review findings.** 59 findings across four layers — 0 high, 30 medium, 29 low, 0 false, 0
maybe-false. 20 patched (8 at medium, 12 at low), 18 deferred to the frontmatter `deferred:`
list, 21 rejected. Rejections, by reason: 6 spec-bound (BH2, EC12, EC13, IA1, IA5, EC15 — the
neither-candidate refusal, the `${dataDir}` template and the manifest-bytes pin's location are
each what the intent contract states); 2 written by this pass's own finalize step (BH12, VG7); 13
low findings whose fix would add guards or branches for a defect users or developers would not
meet in everyday use (BH10, BH17, BH23, BH28, BH29, EC8, EC11 among them). Every row and its
evidence is in `## Review Triage Log`.

**Follow-up review: recommended.** Eight medium entries were patched, and one unverified risk
remains nameable: `Names()` now derives the production application paths from the roster and
`Fixture.Create` binds demo fixtures to the caller's namespace, but **no container has ever
started with `OCUPILOT_NAMESPACE` set**. That path — start hook resolves the override, installs,
health check reads the gate in the same namespace, demo fixtures land there — is pinned by unit
tests and by source-text assertions over both shell scripts, and has never been observed running.

**Verification performed.**
- `node tools/ipm-manifest.mjs --check` — exit 0, comparing 7 packages, 2 applications, 2 resources, 116 classes.
- `npm run test:tools` — 509/509. `uv run scripts/test_check_objectscript.py` — 24/24. `uv run scripts/check-objectscript.py` — 0 problems. `bash scripts/lint-docs.sh` — clean. Both container scripts parse under `bash -n` and `dash -n`.
- `%UnitTest`, one class per call: 312/312 across 32 classes, 0 failures, confirmed with the numeric-run-index `%UnitTest_Result` probe (runs 1044-1056).
- **Live IPM install, throwaway only** (project `ocupilot-ipm2`, container `ocupilot-ipm2`, ports 52777/1976, scratch volumes, **no start hook**): IPM 0.10.5 loaded from `/usr/irissys/dist/install/misc/zpm.xml`; `load -dev /opt/ocupilot` succeeded through Validate, Compile and Activate. Both applications exist in `HSCUSTOM` carrying exactly the roster's asserted values (`AutheEnabled` 64/32, `DispatchClass`, `Enabled` 1, `Resource` "", `ServeFiles` 0, `GroupById` `%ISCMgtPortal`, JWT 60/1/900, `MatchRoles` `:OcuPilotShell` / empty, `NameSpace` `HSCUSTOM`, `Path` `/durable/iris/csp/ocupilot/`). Install gate `installed`. `/ocupilot/` → 200 serving the real Angular shell; `/api/ocupilot/instance` → 401 against 404 for a non-application path. **`_SYSTEM`'s `ChangePassword` is still 1 and `/api/atelier/` still 401 — DW-92 holds against a live install, not a source read.** `zpm package` produced an archive with 11 bundle entries and **0** `OcuPilot/Test/` entries. `zpm uninstall` completed. Both throwaways were torn down with `down -v`, their scratch directories removed, and their absence confirmed; the live `ocupilot` container was never touched.
- **Rule 19: ten `mutation:` lines, sixteen mutations demonstrated**, each applied, observed red, reverted, with `git status --short` and `git diff --stat` unchanged afterwards. Two were live on the throwaway: pointing `invoke.method` at `StartPath` took `_SYSTEM` from expired to unexpired (`ChangePassword` 1 → 0, Atelier 401 → 200), and dropping `"scope": "test"` put 90 `OcuPilot/Test/` entries into the shipped archive.

**Residual risks.**
- The `OCUPILOT_NAMESPACE` end-to-end path has never run on a container (see the follow-up note above).
- `zpm install <name>` from a registry was not exercised — no registry carries the module, and none may before the release date. `load -dev`, `package`, `list` and `uninstall` were.
- `zpm uninstall` leaves OcuPilot's protected database, roles and privileged routine application behind, by design; the README documents `Installer.Uninstall("", 1)` as the remedy.
- `zpm load` from a clone needs `ui/dist/ocupilot-ui/browser/` built first, or IPM fails the Activate phase on the `<FileCopy>`.
- Eighteen deferred items, listed in the frontmatter — the largest are that `Uninstall` alone has no namespace guard, that a third roster application would reach the manifest but not `Names()`, and that no test starts a gate or a container.

Status: done
Blocking condition: none
