---
title: 'Story 20.28: OcuPilot compiles in a namespace without interoperability'
type: 'bugfix'
created: '2026-10-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
