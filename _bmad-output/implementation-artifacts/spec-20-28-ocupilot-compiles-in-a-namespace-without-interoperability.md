---
title: 'Story 20.28: OcuPilot compiles in a namespace without interoperability'
type: 'bugfix'
created: '2026-10-12'
status: 'done'
baseline_revision: '3572e06300960cd02851e405d7c4223311167248'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The probe-namespace guard drives only the nine criterion-free LIST reads and ProductionState, so item, setting, queue-item, job and write paths are held by reading and the Task 1 audit alone.
    evidence: |-
      A stray OcuPilot.* call inside GatherItems, GatherSettings, PerformItem, a row loop of ListQueues or ListJobs, or AwaitTestHere stays green in CompileWithoutInterop, because those run only against a production and six of the nine reads return 0 rows in USER. InteropHostTest and its siblings run in the install namespace, where OcuPilot.* exists.
      Settled by a production fixture in USER driven from the probe namespace, or by the static rule cut at the spec gate.
    location: >-
      src/OcuPilot/Test/CompileWithoutInterop.cls (TestItServesAnInteroperabilityNamespace)
    severity: medium
  - summary: >-
      classifyLeftovers words every leftover token as a probe web application to remove with ProbeApps.Remove(), which misleads for the namespace:, database: and directory: tokens that ProbeApps.Existing() now also reports.
    evidence: |-
      ui/tools/ci-runner.mjs:280 names only web applications and ProbeApps.Remove(); the OCUPROBE2028 objects are cleared by CompileWithoutInteropProbe.RemoveAll. The token itself names the object, so the cost is a wrong hint on a leftover run.
    location: >-
      ui/tools/ci-runner.mjs:280
    severity: low
---

<intent-contract>

## Intent

**Problem:** `Port/InteropPort.cls` includes `Ensemble` and names `Ens.Config` classes as method argument and return types, so it does not compile in a namespace without interoperability. An IPM install into such a namespace therefore fails, although the README admits any non-system namespace (DW-2343). Nothing holds the other shipped classes, or later ones, to the same rule.

**Approach:** Remove InteropPort's four compile-time forms without changing what it does, and add the guard in three layers: a test class that compiles every shipped class in a namespace it creates without interoperability, and the CI `package` job installing the IPM archive into such a namespace.

## Boundaries & Constraints

**Always:**

- Every vendor call (`Ens.*`, `EnsLib.*`) and every vendor-global read runs only while the port is switched to the target interoperability namespace, and no other `OcuPilot.*` class is called while switched (AD-16, AD-62 item 3).
- The shipped classes are every `OcuPilot.*` class outside the roster's test-scope packages (`Install/Roster.cls`, `XData Manifest`, AD-17). Code derives that set from the roster and never restates it.
- Each probe object gets its own name and its own directory under the manager directory, never the manager directory itself, and is removed by exact name. The test class refuses to run unless `OCUPILOT_ALLOW_DATABASE_CONFIG` reads 1.
- The CI script keeps `--network none`, exactly two `docker run` lines, the IPM verbs `load`, `package` and `list`, and the explicit image tag (AD-18, AD-27).
- The existing InteropPort test classes stay green and unmodified.

**Never:**

- Edit `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`, or run `scripts/ci-ipm-archive.sh` locally.
- Widen the guard to the test classes. The guard covers the shipped classes only; the `OcuPilot.Test` classes are a test-scoped IPM resource that may need Ensemble, because the tests run in an interoperability-enabled namespace.
- Install OcuPilot twice on one instance. Multi-namespace install is Story 18.13.
- Create a namespace or database on `ocupilot-slot-b`.
- Change the client, any interoperability read or write, or any refusal code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Compile without interoperability | Every shipped class, copied into a namespace created without interoperability | All compile. The compiled set equals the copied set, and is not empty | A failure names each class and its compiler error |
| Behavior where interoperability exists | Item and setting writes, an item's queue read, and a host test, through the retyped methods | The same answers as before. The existing classes pass unmodified | n/a |
| Install namespace without interoperability, same route namespace | The navigation map | `interoperability` stays on the wire with `applies` false, so it is drawn nowhere (AD-44) | The port answers 409 `INTEROP.NAMESPACE`, as today |
| Install namespace without interoperability serving an interoperability one | The nine `LIST` reads with no criteria, and Home's production line, for a namespace that reports interoperability and holds no OcuPilot class | Each read answers 200. The production line answers a state word | A call into another `OcuPilot.*` class while switched fails with `<CLASS DOES NOT EXIST>`, and the test goes red |
| Regression | A shipped class regains an `Ensemble` include, a `$$$Ens…` macro, or an interoperability class as a declared type | The test class goes red, and the package job goes red | Each failure names the file or class |
| Test class with `Include Ensemble` (`Test/InteropItemSeam.cls`) | Archive build | Nothing refuses it. The archive omits it | n/a |
| Vacuous guard | The created namespace reports interoperability | Setup fails, naming the namespace. The guard never passes | The probe objects are removed |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/InteropPort.cls` -- the four forms:
  - `Include Ensemble` at :1.
  - `ItemObject` at :1538: argument `Ens.Config.Production`, return type `Ens.Config.Item`.
  - `SettingStep` at :2300: `pLocked As Ens.Config.Production`.
  - `ItemQueueName` at :2865: `pItem As Ens.Config.Item`.
  - Five uses of `$$$EnsRuntimeAppData` in `AwaitTestHere`, :5307-5330.
  - Callers: `PerformItem` at :1574 (ItemObject, SettingStep), `QueueOf` at :2880 (ItemObject, ItemQueueName), `PerformTest` at :5460 (AwaitTestHere).
  - The header at :3-55 states the order and that no `OcuPilot.*` class runs while switched.
  - `SettingStep` already leaves the namespace to call `ChangeProblem`, which calls other classes (:2326).
  - The other macros it uses (`$$$comClassKeyGet`, `$$$cCLASSabstract`, `$$$cCLASSclasstype`, `$$$NormalizeClassname`, `$$$SQLCode`, `$$$GeneralError`) compile with no include (measured).
- `irislib/Ensemble.inc` :131-133 -- `$$$EnsRuntimeAppData(args)` expands to `^IRIS.Temp.EnsRuntimeAppData($namespace,args)`. `Test/InteropTestFixture.cls` :333 already writes that literal form.
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls` :195-230 -- Home's production line calls `Ens.Director` and `Ens.Config.Production` while switched. It needs no change.
- `src/OcuPilot/Port/LogSourcePort.cls` :1615-1625 -- the `Ens_Util.Log` SQL runs after the switch. It needs no change.
- `src/OcuPilot/Kernel/Secret/Ladder.cls` :33, :118-131 -- the sibling precedent. It names `Ens.Config.Credentials` as a string, reaches it with `$ClassMethod`, and asks `IsEnsembleNamespace` first.
- `src/OcuPilot/Kernel/Shell/NamespaceFeatures.cls` -- the `appliesWhen` check (Story 20.1, AD-44). It needs no change.
- `src/OcuPilot/Api/Navigation.cls` -- the `/navigation` handler. It writes `Kernel.Shell.Navigation.Payload`'s object.
- `src/OcuPilot/Install/Smoke.cls`:
  - `CheckApiReads` at :576. Its `navigation` check asserts only 200 and a JSON object.
  - `Request` at :319.
  - `Test/Smoke.cls` :921 pins the check names, which stay unchanged.
- `src/OcuPilot/Install/Roster.cls` :82 -- the `resources` with `"scope": "test"`.
- `src/OcuPilot/Install/Installer.cls` :415-475 -- an IPM install lands in the current namespace when it is not a system namespace. HSCUSTOM or USER must exist on the instance. It needs no change, and nothing under `Install/` names interoperability outside comments.
- `src/OcuPilot/Test/RemoteDatabaseProbe.cls` -- the sibling probe helper, driven by its parameters (`PREFIX`, `DIRPREFIX`, `RESOURCEPREFIX`, `LOCALNAME`, `NAMESPACENAME`):
  - `SeedNamespace()` creates the resource, then the directory, file, configuration and namespace.
  - `RemoveAll(.remaining)` removes each by prefix.
- `src/OcuPilot/Test/NamespaceFeatures.cls` :132 -- pins `applies` with `%SYS` as the route namespace. No test pins an install namespace without interoperability.
- `src/OcuPilot/Test/InteropHostDescriptor.cls` :185-198 -- calls `ItemQueueName` with an OREF through `$ClassMethod`. It is unchanged by the retype.
- `scripts/ci-ipm-archive.sh`:
  - `import_ipm` at :160 and `assert_no_repositories` at :185 both hard-code `-U HSCUSTOM`.
  - Phase 2 runs from :389: `load` at :398, `list` at :413, unexpire at :434, smoke at :450.
  - The header at :1-30.
- `ui/tools/ipm-archive.test.mjs` -- the pins this change must keep or update:
  - :94, two `docker run` lines;
  - :123, the verb allow-list;
  - :188, the repository table is read, never written;
  - :236, one `smoke.sh` line with its status captured;
  - :766, unexpire after `load` and before smoke.
- `scripts/ci-throwaway.sh` :648-670 -- `OCUPILOT_ALLOW_DATABASE_CONFIG`'s `# classes:` roster. `ui/tools/ci.test.mjs` :2366 holds it equal to the declaring classes. That file is read-only for this story.
- `.github/workflows/ci.yml` `package` job, read-only -- `sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2`, `timeout-minutes: 45`. On run 38240369145 it took 10.6 min.

## Tasks & Acceptance

**Execution:**

0. `git diff --stat $(git merge-base HEAD origin/OCU-1-epic18) origin/OCU-1-epic18 --` over every file below -- re-check that Epic 18 has changed none of them. At plan time it had changed none (`cfb71e8c`, merge base `6e02c22f`). If it has changed `Install/Smoke.cls` since, the edit there must be add-only or go to the orchestrator.
1. `src/OcuPilot/Port/InteropPort.cls` -- DW-2343, AC1:
   - Delete `Include Ensemble`.
   - Type `ItemObject`'s argument and return, `SettingStep`'s `pLocked` and `ItemQueueName`'s `pItem` as `%RegisteredObject`.
   - Write each `$$$EnsRuntimeAppData(...)` as its expansion, `^IRIS.Temp.EnsRuntimeAppData($Namespace, ...)`, still inside `AwaitTestHere`, which runs while switched.
   - Doc comments state the contract only.
   - Then audit every vendor call site and vendor-global read in InteropPort, SystemInfo and LogSourcePort, plus Ladder's guard. Record under `## Verification` that each runs while switched, or behind Ladder's check.
2. [CUT at the spec gate] The static checker rule: the release's critical path keeps the story to InteropPort and the compile guard (see Gate rulings).
3. `src/OcuPilot/Test/CompileWithoutInteropProbe.cls` (new) -- extends `OcuPilot.Test.RemoteDatabaseProbe` with parameters only:
   - `PREFIX` `OCUPROBE2028`, `DIRPREFIX` `ocuprobe2028`, `RESOURCEPREFIX` `%DB_OCUPROBE2028`;
   - `LOCALNAME` `OCUPROBE2028D`, `NAMESPACENAME` `OCUPROBE2028N`;
   - `SERVERNAME` `OCUPROBE2028SRV` and `MAPPINGNAME` `OcuProbe2028*`. Neither is ever created.
4. `src/OcuPilot/Test/CompileWithoutInterop.cls` (new) -- AC1, AC2, AC3:
   - **`OnBeforeAllTests`:**
     - Refuse unless armed.
     - Remove leftovers, then call `SeedNamespace`.
     - Refuse if the namespace reports interoperability.
     - Copy every shipped class definition from the install namespace into it, leaving out any `GeneratedBy` class.
     - Compile there with `ck`, and store the outcome.
     - On its own failure, remove what it made, because `%UnitTest` skips `OnAfterAllTests` then.
   - **`TestEveryShippedClassCompilesThere`:** no compiler error, and the compiled set equals the copied set (more than 0), naming any missing class.
   - **`TestInteroperabilityIsHiddenThere`:** in the probe namespace, its own `Navigation.Payload` keeps `interoperability` with `applies` false.
   - **`TestItServesAnInteroperabilityNamespace`:**
     - It first asserts that `USER` reports interoperability and holds no `OcuPilot.Port.InteropPort`. That is the stock IRIS for Health throwaway's shape, which `NamespaceFeatures` also assumes.
     - From the probe namespace, the probe copy's InteropPort `LIST` reads for `USER` (`Productions`, `Processes`, `Transforms`, `Rules`, `Monitor`, `Queues`, `Jobs`, `LookupTables`, `BusinessPartners`) each answer 200.
     - `SystemInfo.ProductionState` for `USER` returns without throwing.
   - **`OnAfterAllTests`:** clear `Kernel.Scope`, call `RemoveAll`, and fail when anything remains.
   - The header says what the class pins and needs: armed, a stock IRIS for Health throwaway, about ten seconds.
4b. `src/OcuPilot/Test/ProbeApps.cls` -- `Existing()` also lists a surviving `OCUPROBE2028` namespace, database or directory, named so the runner's leftover line says which (see Gate rulings: teardown and the leftover check). Add-only; `Paths()` and `Remove()` are unchanged.
5. `scripts/ci-throwaway.sh` -- under `OCUPILOT_ALLOW_DATABASE_CONFIG`, add the comment lines and `# classes: CompileWithoutInterop`. The new comment says the class creates and removes the `OCUPROBE2028D` database, with its `%DB_OCUPROBE2028D` resource, its `<mgr>ocuprobe2028d` directory and the `OCUPROBE2028N` namespace, and compiles the shipped classes there (Story 20.28).
6. `src/OcuPilot/Install/Smoke.cls` -- in `CheckApiReads`, the `navigation` check also parses the body. It fails unless the area keyed `interoperability` has `applies` equal to `%Library.EnsembleMgr.IsEnsembleNamespace` for the namespace the smoke runs in. The check name stays the same. Add one sentence to the doc comment. AC2.
7. `scripts/ci-ipm-archive.sh` -- Phase 2 installs into a namespace it creates without interoperability, instead of `HSCUSTOM` (AC2, AC3). In order:
   1. In `%SYS`, create the resource `%DB_NOINTEROP`, then `<mgr>nointerop/`, the database, its configuration and the namespace `NOINTEROP`. Read back by marker that it does not report interoperability, and fail otherwise.
   2. Import IPM into `NOINTEROP`: `import_ipm` and `assert_no_repositories` take a namespace argument, defaulting to `HSCUSTOM` for the build container. IPM 0.10 maps `%IPM` per namespace.
   3. Run `load` and `list` in `NOINTEROP`.
   4. By marker, require the count of compiled `OcuPilot.*` classes there to equal the archive's class count, with no `OcuPilot.Test.*` class among them.
   5. Unexpire `_SYSTEM` as today, and run the one smoke line with `--namespace "$NOINTEROP_NS"`.
   6. Update the header and the final line to say so.
8. `ui/tools/ipm-archive.test.mjs` -- keep every existing pin green. Add pins:
   - `load` and `list` run in the created namespace, never `HSCUSTOM`;
   - the namespace is created with no `EnableNamespace`, and its interoperability is read back and required to be 0;
   - IPM is imported into it before `load`;
   - the class-count marker is required;
   - the smoke line carries `--namespace "$NOINTEROP_NS"`.

   Each new pin gets a mutation line.
9. [CUT at the spec gate, with Task 2] No `CLAUDE.md` edit.
10. This spec's `## Verification` -- record the audit, the cross-namespace numbers after the change, and each `mutation:` line.

**Acceptance Criteria:**

- AC1:
  - **Given** InteropPort
  - **When** it is compiled
  - **Then** it has no compile-time dependency on interoperability: no `Ensemble` include, and where an `Ens.Config` type was named it takes `%RegisteredObject` and reaches the vendor class at run time.
  - Behavior is unchanged where interoperability exists. The existing InteropPort test classes pass unmodified, and an install namespace without interoperability still serves an interoperability namespace's reads (DW-2343).
- AC2:
  - **Given** a namespace without interoperability
  - **When** OcuPilot is installed there
  - **Then** the navigation map it serves keeps Interoperability on the wire with `applies` false, so the category stays hidden (Story 20.1, AD-44).
  - It is checked over HTTP by smoke in the package job's install, and in the probe namespace by `CompileWithoutInterop`.
- AC3:
  - **Given** a namespace created without interoperability
  - **When** the guard runs
  - **Then** every class OcuPilot ships compiles there, installed through IPM as the release's upgrade check installs it, and the guard runs in CI: the `package` job and the instance shard that draws `CompileWithoutInterop`.
  - The `OcuPilot.Test` classes are out of its scope.
- AC4:
  - **Given** a shipped class that regains an `Ensemble` include, a `$$$Ens…` macro or an interoperability class as a declared type
  - **When** `CompileWithoutInterop` or the `package` job runs
  - **Then** it fails, naming the class.

## Spec Change Log

## Review Triage Log

### 2026-10-12 — Review pass

- verdicts: 10 findings — high 0, medium 2, low 5, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` `TestTheNavigationCheckJudgesTheMap` string and non-array legs assert only `'= ""`, so each passes through another branch (an `applies` of `"1"` would pass without the boolean-type test) — the legs now assert the problem text and the string leg carries the right value as a string; two mutations observed red.
  - `[medium]` `[defer]` the cross-namespace guard drives the nine criterion-free `LIST` reads and `ProductionState` only; item, setting, queue-item, job and write paths have no probe-namespace check, and six of the nine reads return no rows — the matrix row bounds this verification to those reads; the rest needs a production fixture in `USER` (new surface), and the static rule that would hold it was cut at the gate. Ledgered via `deferred:`.
  - `[medium]` `[patch]` `ProbeApps.CompileProbeLeftovers` and the `Existing()` branch have no retained positive-path test; a regression to `""` would silence both the runner's check and `OnAfterAllTests` — `TestTheLeftoverCheckSeesTheProbeObjects` added with literal tokens; mutation observed red.
  - `[low]` `[reject]` the `package` job no longer smokes an archive installed into an interoperability namespace — the intent excludes the alternative (exactly two `docker run` lines, no second install on one instance); the gate accepted the named limit, and the build container's `load -dev` plus every instance shard still install into HSCUSTOM.
  - `[low]` `[defer]` `classifyLeftovers` in `ui/tools/ci-runner.mjs` words every leftover token as a probe web application to remove with `ProbeApps.Remove()`, which is wrong advice for the new `namespace:`, `database:` and `directory:` tokens — message text only; the file is outside the edit set the gate allows. Ledgered via `deferred:`.
  - `[false]` `[reject]` the new `ipm-archive.test.mjs` pins read script text and the namespace-creating session has not run — stated as the residual risk in Design Notes; a red `package` job re-opens the story as any red CI does, and no defect is shown at a cited line.
  - `[low]` `[patch]` no new test drives the 409 `INTEROP.NAMESPACE` answer for the install namespace itself (matrix row 3, error column) — `TestItRefusesItsOwnNamespace` added; mutation observed red.
  - `[low]` `[reject]` the `package` job's count check prints counts, not class names — Task 7.4 prescribes the count, and a class that fails to compile fails `load`, whose output (tail 40) carries the compiler error naming it; not worth a per-class listing in shell.
  - `[false]` `[reject]` the nine reads are asserted on the port's `pHttp`, not over HTTP — the matrix row concerns the port's answer from a copy with no `OcuPilot.*` class in the target; the router is unchanged and Smoke's `navigation` check covers the wire.
  - `[false]` `[reject]` three layers named, two enumerated — the third is AC2's Smoke navigation agreement; no bad outcome is described.

## Design Notes

**Governing ADs:**

- **AD-62.** The port; item 3, switch and no `OcuPilot.*` call while switched.
- **AD-16.** Explicit save and restore.
- **AD-44.** `appliesWhen`, the gating Story 20.1 rests on.
- **AD-17.** The roster's test scope; an IPM `<Invoke>` installs where it runs.
- **AD-18.** IPM is imported from the image's offline `zpm.xml`.
- **AD-27.** The pinned image tag, unchanged.
- **AD-45.** The one smoke path; the `navigation` check gains an assertion.

**Ledger inbox:** DW-2343 is addressed by Tasks 1 to 8 and AC1 to AC4.

**Measured at this plan** on `ocupilot-b-ci` (IRIS for Health 2026.2 build 221U, the 20.13 head, `src` identical to this tree), in a scratch namespace without interoperability. Every probe object has been removed and the namespace list reads as it did before.

- **18 forms, one class each.**
  - **Fails:**
    - `Include Ensemble` (MPP5635);
    - `$$$EnsRuntimeAppData` with no include (MPP5610);
    - an `Ens.*` superclass, property type, argument type (`Output` included), return type, `DependsOn` or `CompileAfter` (#5373);
    - a `%SQLQuery` over an `Ens` table (#5521, SQLCODE -30).
  - **Compiles:**
    - `##class(Ens.…)` calls and `%New` in a method body;
    - `##class(Ens.Host).#INVOCATION`;
    - `#dim … As Ens.Config.Item`;
    - embedded `&sql` over an `Ens` table;
    - `%ListOfObjects(ELEMENTTYPE="Ens.Config.Item")`;
    - the `%occ` macros InteropPort uses, with no include;
    - a `%RegisteredObject` argument.
- **The shipped population.** 756 classes loaded and 755 compiled. Only InteropPort failed, with three #5373 errors: `ItemObject`, `ItemQueueName` and `SettingStep` formal specs.
- **The Task 1 prototype.** Its four edits compiled all 756 with 0 errors. A forced full compile took 0.66 s by `$ZH` (one run), and the load took 1.4 s.
- **Cross-namespace, from the prototype namespace to `USER`.** `USER` reports interoperability and holds no OcuPilot class.
  - All nine `LIST` reads answered 200: Processes 29 rows, Transforms 4, LookupTables 1, the rest 0. Home's line read `Stopped`.
  - For the namespace itself the reads answered 409 `INTEROP.NAMESPACE`, and Home's line answered `""`.
  - Its `Navigation.Payload` answered `interoperability` `applies` 0. For `USER` it answered 1.
- **IRIS dispatch while switched.**
  - Run fine: the same class's `..Helper()` and a subclass's overridden seam.
  - Failed with `<CLASS DOES NOT EXIST>`: another class of the scratch package, and an `Ens` class called in the install namespace.
  - An `Ens` OREF made while switched stayed usable after restore.
- **Teardown in the same process.** A database whose class had just run and whose global had just been set was deleted cleanly. Nothing was left mounted.
- **Namespace creation.** `Config.Namespaces.Create` made no web application and no package or routine mapping. `IsEnsembleNamespace` answered 0.
- **IPM 0.10.5's installer** (`zpm.xml`'s `IPM.Installer` manifest, read and not run) maps `%IPM` from the current namespace's routine database into that namespace only.

**Decisions this plan takes:**

- **The CI leg goes "instead", not "also".** A second install on the same instance is Story 18.13's multi-namespace install. A third container would break two pins (:94, :692) and add about 3 minutes. The installer has no step that depends on interoperability. HSCUSTOM stays covered: the build container's `load -dev` runs the full lifecycle, `<Invoke>` included, and every instance shard installs through the start path and runs smoke.
  - Named limit: no CI leg runs smoke on an archive install into an interoperability namespace.
- **The local form is a test class that joins the instance sweep,** not a script. The sweep runs it in every CI push's shards, its cost is seconds, and it needs no container of its own. It copies definitions from the install namespace, so it does not depend on a source mount.
- **AC1's `$ClassMethod`/`$Method`.** The retyped arguments keep their `pItem.QueueName()`, `pProduction.Items` and `pLocked.SaveToClass()` forms, and the method bodies keep their `##class(Ens.…)` calls. Measured, these compile with no interoperability, and the class is resolved only at run time, which is the dispatch AC1 asks for (inference). No site needs rewriting. The lead may require the literal `$Method` form at the spec gate.
- **AC2 is anchored at the served map.** Smoke reads `/navigation` over HTTP, and Story 20.1's `namespace-categories.browser-spec.mjs` already pins that a non-applying area is drawn nowhere. The new smoke assertion holds wherever smoke runs: true in HSCUSTOM and USER, false in `NOINTEROP`.

**Rule 2 / Rule 31 (extend, don't copy):**

- `CompileWithoutInteropProbe` subclasses `RemoteDatabaseProbe` and overrides only its parameters.
- The `$$$EnsRuntimeAppData` expansion copies the literal form `InteropTestFixture` already uses.
- `Ladder.cls` is the precedent for naming an interoperability class only at run time.

**Integration ACs (Rule 1):** no new service.

- **Consumes:**
  - `Install.Roster`'s test scope;
  - `Kernel.Shell.Navigation` and `NamespaceFeatures`;
  - InteropPort and SystemInfo, as compiled in a namespace without interoperability.
- **Consumed-by:**
  - the 1.0.12 upgrade check's item 8;
  - every later interoperability story the guard holds: 20.7 to 20.12, 20.16, 20.25 to 20.27, and Epic 21's 21.7 and 21.11.

**Rule 3:** the outcome is user-facing. The real-runtime evidence is the package job's smoke over HTTP on an IPM install without interoperability, together with Story 20.1's browser spec. There is no client change, so no bundle is rebuilt.

**Footprint extensions:**

- `scripts/ci-ipm-archive.sh`;
- `scripts/ci-throwaway.sh` (comment lines only).

`origin/OCU-1-epic18` had changed none of these, nor `Install/Smoke.cls`, at plan time.

**Residual risk:** CI's `package` job is the first run of three steps: IPM import in a namespace without interoperability, OcuPilot's `<Invoke>` there, and smoke there. IPM compiles without interoperability, since it is routinely installed in `%SYS` (inference). A red result re-opens the story as any red CI does. If smoke fails there for a reason unrelated to interoperability, the implement stage records it and halts to the lead rather than widening this story.

**Gate rulings (lead, 2026-10-12):**

- **Seam taken.** Tasks 2 and 9 (the static checker rule and the `CLAUDE.md` count) are cut: the story is the 1.0.12 release's critical path, and AC4 holds through `CompileWithoutInterop` and the `package` job. No checker rule, harness case or `CLAUDE.md` edit is in scope.
- **AC1's dispatch.** The measured forms stand: the retyped arguments keep `oref.Method()` calls and the bodies keep `##class(Ens.…)`, each resolved at run time. No `$Method` rewrite. `epics.md`'s AC1 is amended to say so (Rule 5).
- **The CI leg goes "instead".** Accepted with its named limit (no CI smoke of an archive install into an interoperability namespace); the build container's `load -dev` and every instance shard still install into `HSCUSTOM`.
- **AD-62 item 12** is applied to the spine as proposed below, without the checker-rule clause.
- **Teardown and the leftover check (orchestrator, 2026-10-12).** `CompileWithoutInterop` removes the namespace, its databases, their resources and their directories on every path, its own setup failure included, and `OnAfterAllTests` fails when any of them remains. The CI runner's after-class leftover check must see them: `OcuPilot.Test.ProbeApps.Existing()`, which `scripts/ci-unit-test.sh` reads before and after every class, also reports a surviving `OCUPROBE2028` namespace, database or directory (add-only; `ui/tools/ci-runner.mjs` and `ci.test.mjs` are not edited), so a skipped teardown counts as `1 with probe leftovers` and a clean sweep keeps reporting `0 with probe leftovers`. Mutation: skip the teardown's `RemoveAll` and run the class through `ci-runner.mjs` -- expected: the class is reported with a probe leftover; revert and re-run to `0`.

**AD-62 item 12, as applied at the spec gate (Rule 20; the checker-rule clause dropped):**

> **No compile-time dependency on interoperability** [AMENDED 2026-10-12, Story 20.28 spec gate, Rule 20]. No shipped class includes `Ensemble` or another interoperability include file, or names an `Ens.*`, `EnsLib.*` or `EnsPortal.*` class where the compiler resolves it: a superclass, a property, argument or return type, `DependsOn`, `CompileAfter`, or a class query's SQL. Such a value is typed `%RegisteredObject` or `%String` and reached at run time while switched (measured: those forms fail without interoperability; `##class(Ens.…)` calls in a method body, `#dim`, embedded SQL and strings compile). An install namespace without interoperability shows no Interoperability category and still serves interoperability namespaces. Held by `OcuPilot.Test.CompileWithoutInterop` and by the `package` job's IPM install into a namespace created without interoperability. The test-scoped `OcuPilot.Test` classes are outside it, because the tests run in an interoperability-enabled namespace.

## Verification

**Shared surfaces:**

- Smoke's `navigation` check, which every smoke run uses: instance shards, images, package, local runs and the upgrade check.
- `ci-throwaway.sh`'s `OCUPILOT_ALLOW_DATABASE_CONFIG` roster, which `ci.test.mjs` holds.
- The `ipm-archive.test.mjs` pins.
- The ObjectScript test roster, which gains `CompileWithoutInterop` and the probe helper (not a test case). The shards weigh it at the median, and `ci-timings.json` is not edited.
- Transient `OCUPROBE2028*` objects while the class runs.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (slot B), after any `src` change:**

```bash
rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/
```

Then run `Do $System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`. Never use `ocupilot-slot-b`.

**Commands** (each in the foreground with `timeout: 600000`; one `ci-runner` call at a time):

- `uv run scripts/check-objectscript.py` (loop) -- expected: 0 problems (no rule added).
- `sh -n scripts/ci-ipm-archive.sh && cd ui && node --test tools/ipm-archive.test.mjs tools/ci.test.mjs` (loop) -- expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.CompileWithoutInterop --class OcuPilot.Test.NamespaceFeatures --class OcuPilot.Test.Smoke --class OcuPilot.Test.InteropHostDescriptor --class OcuPilot.Test.InteropHostRead` (loop) -- expected: every class green, with tests executed.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropItemControl --class OcuPilot.Test.InteropItemIdentity --class OcuPilot.Test.InteropSettingControl --class OcuPilot.Test.InteropSettingIdentity --class OcuPilot.Test.InteropSettingDescent --class OcuPilot.Test.InteropSettingPaths` (loop) -- expected: green and unmodified.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropHostTest --class OcuPilot.Test.InteropHostTestEdges` (loop) -- expected: green and unmodified.
- `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- **Runner (lead-owned):** the full ObjectScript sweep, the smoke on `ocupilot-b-ci`, and Rule 30's fresh check.
- **Left to CI:** the `package` job (the first run of the IPM leg), the full browser suite, and the instance shards.

**Mutations to demonstrate** (implement stage; revert each, and confirm `git status --short` and `git diff --stat` are unchanged):

- AC1 and AC3: add `Include Ensemble` back at `InteropPort.cls` :1 and load it. Expected red: `CompileWithoutInterop.TestEveryShippedClassCompilesThere`, naming InteropPort.
- AC4: an argument typed `As Ens.Config.Item` in InteropPort, loaded. Expected red: `CompileWithoutInterop.TestEveryShippedClassCompilesThere`, naming InteropPort.
- AC1, cross-namespace: call `##class(OcuPilot.Kernel.Audit.Log).Warn(...)` inside `ListProductions`' switched block. Expected red: `TestItServesAnInteroperabilityNamespace`.
- AC2: make `NamespaceFeatures.Reports` answer 1 for `interoperability`. Expected red: `TestInteroperabilityIsHiddenThere`.
- AC2 at the served map: make it answer 0 instead. Expected red: `OcuPilot.Test.Smoke`, at `navigation` on HSCUSTOM.
- AC3 in CI: point the script's `load` session back at `HSCUSTOM`. Expected red: the new `ipm-archive.test.mjs` pin.

**Implement-stage record (slot B, `ocupilot-b-ci`, IRIS for Health 2026.2):**

- **Task 0.** `git diff --stat` between the merge base `9c9c6ad8` and `origin/OCU-1-epic18` (`478a486a`) over `Port/InteropPort.cls`, `Install/Smoke.cls`, `Test/ProbeApps.cls`, `Test/RemoteDatabaseProbe.cls`, `Kernel/Shell/NamespaceFeatures.cls`, `Kernel/Shell/SystemInfo.cls`, `Port/LogSourcePort.cls`, `Kernel/Secret/Ladder.cls`, `scripts/ci-ipm-archive.sh`, `scripts/ci-throwaway.sh` and `ui/tools/ipm-archive.test.mjs`: empty. Every edit here is therefore on a file Epic 18 has not changed.
- **Audit (Task 1).** Every vendor call and vendor-global read in the three classes, read off a scan of their non-comment lines and then traced to its caller:
  - `InteropPort`, inside the method's own `Set $NAMESPACE = pNamespace` to restore block: `ListProductions`, `ListClasses`, `ReadState`, `Perform`, `AddViolations`, `GatherItems`, `PerformItem`, `GatherSettings`, `GatherHosts`, `GatherJobs`, `ListQueues`, `QueueOf`, `GatherQueueEntries`, `HeaderFacts`, `VendorAbortItem`, `VendorJob`, `ListLookupTables`, `ListLookupEntries`, `PerformLookup`, `ListPartners`; `SqlRows` (the `Ens.MessageHeader` and `Ens_Util.Log` statements) likewise.
  - `InteropPort`, reached only from those blocks: `SettingStep` (from `PerformItem`'s block; it leaves the namespace only for `ChangeProblem` and is back in before its next vendor call), `ValueAccepted` (through `SettingFacts`, called by `SettingStep` and by `SettingsOf`'s block), `LiveCurrent` (`GatherHosts`, `GatherJobs`), `LockTable` and `UnlockTable`, `LookupFactsHere` (`LookupFacts`, `PerformLookup`, the import block), `RequestClassesHere` (`GatherTestFields`), `TestFactsHere` and `IsRequestClassHere` (`ReadTestTarget`), `BuildTestRequestHere`, `VendorSendTest`, `AwaitTestHere` and `CollectResponseHere` (`PerformTest`).
  - `InteropPort`, text only: the six `*Snippet` builders and the `LOGSQL` and `MESSAGESQL` parameters, which are executed by `SqlRows`.
  - `SystemInfo.ProductionState`: `Ens.Config.Production.ProductionStateToText` and its own `ProductionStatus` seam run between the switch and the restore; `ProductionEnabled` calls `%Library.EnsembleMgr`, which every namespace has. `LogSourcePort.FetchEvents`: the `Ens_Util.Log` statement runs after `Set $NAMESPACE = pNamespace`. `Ladder`: `Ens.Config.Credentials` is a string, and each of the three `$ClassMethod` use sites follows `CredentialsRungAvailable()`, which asks `IsEnsembleNamespace` first.
  - No other shipped class calls a vendor class or reads a vendor global: the remaining `Ens`, `EnsLib` and `EnsPortal` names are the classic-page keys of descriptors and tools (strings), comments, and the display text `InteropProductionStop` builds.
- **After the change, from the probe namespace (a stock IRIS for Health throwaway, `OCUPROBE2028N`).** 756 shipped classes copied, 756 with a current compile; setup took 1.9 s by `$ZHorolog`. For `USER`, which reports interoperability and holds no OcuPilot class: `Productions` 200 with 0 rows, `Processes` 200 with 29, `Transforms` 200 with 4, `Rules` 200 with 0, `Monitor` 200 with 0, `Queues` 200 with 0, `Jobs` 200 with 0, `LookupTables` 200 with 1, `BusinessPartners` 200 with 0, and Home's line `Stopped`. For the probe namespace itself, `Productions` answers 409 `INTEROP.NAMESPACE`, and its own navigation map keeps `interoperability` with `applies` false. These match the plan-time prototype row for row.
- **What a failed compile leaves.** A class whose compile failed keeps a `%Dictionary.CompiledClass` row (measured with `Include Ensemble`: row present, `$System.OBJ.IsUpToDate` 0; with an `Ens.Config.Item` argument type: no row). The guard therefore counts only classes whose compile is current, and also asserts the load and compile status, which names the class and its error.
- **Runner results** (`ci-runner.mjs --container ocupilot-b-ci`, every run `0 with probe leftovers`):
  - `CompileWithoutInterop` 3, `NamespaceFeatures` 5, `Smoke` 42 (40 before the two tests added here), `InteropHostDescriptor` 8, `InteropHostRead` 7;
  - `InteropItemControl` 6, `InteropItemIdentity` 3, `InteropSettingControl` 7, `InteropSettingIdentity` 3, `InteropSettingDescent` 9, `InteropSettingPaths` 5;
  - `InteropHostTest` 12, `InteropHostTestEdges` 5;
  - beyond the spec's list, over the rest of the interoperability classes and the two that call `ProbeApps.Existing`: `InteropControl` 11, `InteropGate` 4, `InteropItemRefusals` 8, `InteropItemGate` 5, `InteropSettingRefusals` 7, `InteropSettingSecrets` 3, `InteropHostEdges` 8, `InteropHostTestRefusals` 7, `InteropQueueActions` 10, `InteropJobActions` 7, `InteropJobStop` 8, `InteropRuntimeBounds` 3, `InteropRuntimeCard` 3, `InteropStopOutcome` 4, `InteropLookupControl` 7, `InteropLookupRead` 5, `InteropLookupEdges` 10, `InteropLookupTransfer` 8, `InteropLookupRefusals` 9, `InteropFloor` 7, `Provenance` 7, `GrantReadBack` 3. All unmodified, all green.
- **Not demonstrated.** `CompileWithoutInterop` as the first class on a fresh instance: the throwaway had run 610 earlier runs. It needs nothing a sibling leaves (it removes its own objects first, creates its own, and only reads `USER`), and it ran green alone as run 611 and again after the 10 other classes. The `package` job's IPM leg is the first run of that path (see Residual risk).

**Mutations** (each applied, the named class run, observed red, then reverted byte for byte and the tree reloaded):

- mutation: `Include Ensemble` back at `InteropPort.cls` :1 -> `CompileWithoutInterop.TestEveryShippedClassCompilesThere` red on three assertions: `not compiled: OcuPilot.Port.InteropPort`, the status `MPP5635 : No include file 'Ensemble'` under `OcuPilot.Port.InteropPort`, and the set equality.
- mutation: `ItemQueueName(pItem As Ens.Config.Item, ...)` -> the same test red, the status `ERROR #5373: Class 'Ens.Config.Item', used by 'OcuPilot.Port.InteropPort:ItemQueueName:FormalSpec', does not exist`.
- mutation: `##class(OcuPilot.Kernel.Audit.Log).Warn(...)` after the switch in `ListProductions` -> `TestItServesAnInteroperabilityNamespace` red on `Productions` alone (`INTERNAL`, 500).
- mutation: `NamespaceFeatures.Reports` answers 1 for `interoperability` -> `TestInteroperabilityIsHiddenThere` red alone.
- mutation: `NamespaceFeatures.Reports` answers 0 for `interoperability` -> `OcuPilot.Test.Smoke.TestTheNavigationCheckAgreesWithTheNamespace` red alone: `fail navigation -- the navigation map says interoperability applies=0 in HSCUSTOM, which reports 1`. The spec's `OcuPilot.Test.Smoke` held no assertion on the `navigation` check, so that test is added here.
- mutation: `Smoke.NavigationProblem` skips the `applies` comparison -> `TestTheNavigationCheckJudgesTheMap` red on the opposite-value leg.
- mutation: `OnAfterAllTests` skips `RemoveAll` -> the class is reported `1 with probe leftovers`, naming `namespace:OCUPROBE2028N`, `database:OCUPROBE2028D` and `directory:ocuprobe2028d`, with the class-level `OnAfterAllTests` error. The leftovers were removed by `RemoveAll`, and the reverted class re-ran to `0 with probe leftovers`.
- mutation: the namespace-reports-interoperability guard forced true -> `EMPTY`, `OnBeforeAllTests raised: the probe namespace OCUPROBE2028N reports interoperability, so compiling in it would prove nothing`, and `0 with probe leftovers`: the failed setup removed what it made.
- mutation: the `# classes: CompileWithoutInterop` line removed from `ci-throwaway.sh` -> `ci.test.mjs` red on the arming-roster test, naming `CompileWithoutInterop`.
- mutation (the `ipm-archive.test.mjs` pins, 14 variants of `ci-ipm-archive.sh`, each red on the pin named, the baseline green after restore): the unexpire session in `HSCUSTOM` -> `_SYSTEM is unexpired by a session opened in %SYS` (the older lazy regex stays green through the namespace-creating session, which is why that pin was added); the `load`, `list` or class-count session in `HSCUSTOM`, or `assert_no_repositories` without the namespace -> `load and list run in the namespace the script creates`; `EnableNamespace` added, the read-back `Write` deleted, the `!= "0"` check deleted, or `import_ipm` moved above the read-back -> `the namespace is created with no EnableNamespace ...`; `import_ipm` without the namespace, or after `load` -> `IPM is imported into the created namespace, before load`; the `$CLASS_COUNT` or `COMPILED_TEST` check deleted -> `the compiled OcuPilot class count ...`; `--namespace` dropped from the smoke line -> `smoke runs in the created namespace`.
- mutation (review patches): `Smoke.NavigationProblem` without its boolean-type test -> `Test.Smoke.TestTheNavigationCheckJudgesTheMap` red alone (string leg); without its areas-array test -> the same test red alone (non-array leg).
- mutation: `InteropPort.Invoke`'s `Reports("interoperability", pNamespace)` refusal replaced by `If 0` -> `CompileWithoutInterop.TestItRefusesItsOwnNamespace` red alone.
- mutation: `ProbeApps.CompileProbeLeftovers` answering `""` -> `CompileWithoutInterop.TestTheLeftoverCheckSeesTheProbeObjects` red alone. After each of the four, the file was restored from a copy (checksums and `git status` equal), the throwaway reloaded, and `CompileWithoutInterop` (5), `Smoke` (42) and `InteropHostRead` (7) re-ran green with 0 probe leftovers.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.**

- `InteropPort` no longer includes `Ensemble` or names an `Ens.Config` class as a type: `ItemObject`, `SettingStep` and `ItemQueueName` take or return `%RegisteredObject`, and the five `$$$EnsRuntimeAppData` uses are the literal `^IRIS.Temp.EnsRuntimeAppData($Namespace, ...)`.
- `Smoke`'s `navigation` check also requires the `interoperability` area's `applies` to equal the namespace's own report.
- New `CompileWithoutInterop` (5 tests) and `CompileWithoutInteropProbe` compile every shipped class in a namespace created without interoperability and drive the probe copy against `USER`.
- `ProbeApps.Existing()` reports surviving `OCUPROBE2028` objects.
- `ci-throwaway.sh` carries the roster line.
- `ci-ipm-archive.sh` installs into a created `NOINTEROP` namespace (six new `ipm-archive.test.mjs` pins).

**Files changed.**

- `src/OcuPilot/Port/InteropPort.cls`: the four compile-time forms removed.
- `src/OcuPilot/Install/Smoke.cls`: `NavigationProblem` and the `navigation` assertion.
- `src/OcuPilot/Test/CompileWithoutInterop.cls`, `src/OcuPilot/Test/CompileWithoutInteropProbe.cls`: the guard and its probe helper.
- `src/OcuPilot/Test/ProbeApps.cls`: `CompileProbeLeftovers`, add-only.
- `src/OcuPilot/Test/Smoke.cls`: two tests on the navigation check.
- `scripts/ci-ipm-archive.sh`, `scripts/ci-throwaway.sh`, `ui/tools/ipm-archive.test.mjs`.

**Review.** 10 findings: 3 patched (one medium, two low), 2 deferred (one medium, one low; see `deferred:`), 5 rejected with their reasons in the triage log.

**Follow-up review recommended:** false (one medium patched).

**Verification.**

- All `(loop)` lines green on `ocupilot-b-ci`: 13 ObjectScript classes with 0 probe leftovers, `check-objectscript` 0 problems, `sh -n`, `lint-docs` clean, `ipm-archive.test.mjs` and `ci.test.mjs` 117 of 117.
- Every mutation is recorded under `## Verification`, each reverted with the tree byte-identical.
- The full sweep, the smoke and Rule 30's fresh check are the runner's.

**Residual risks.**

- The `package` job's IPM leg (import into `NOINTEROP`, `<Invoke>` there, smoke there) is its first run in CI.
- No CI leg smokes an archive installed into an interoperability namespace (gate-accepted).
