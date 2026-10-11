---
title: 'Story 20.24: Agent tool calls stop re-listing the tool registry'
type: 'bugfix'
created: '2026-10-10'
status: 'done'
baseline_revision: 'ce364adb620490845728df8619db98ccd5f529b6'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every agent tool call rebuilds the whole tool listing, once per resolve. `Screen.Tool.Registry.ListTools` takes 0.58 to 0.61 s at 335 tools on `ocupilot-b-ci`, and 87 % of that is the fingerprint-subject check on 205 write tools. Three resolves each build it: Dispatch's `ResolveWire`, the governance gate's `Resolve` for a write, and the turn loop's step-recording `ResolveWire`. So a write call costs about 1.2 s inside `Dispatch` and about 1.8 s per turn step, and the cost grows with every tool (DW-2286).

**Approach:** `ListTools` keeps the listing it builds in a per-process cache, keyed by namespace and registry class, and gives every caller its own copy. Before answering, each call reads a cheap compile signature of the `OcuPilot.` package from the class dictionary. A compile, delete or new class in any process changes the signature, so the next call rebuilds without a restart.

## Boundaries & Constraints

**Always:**

- There is one cache, inside `ListTools`. `Resolve`, `ResolveWire`, `ProviderTools` and every direct `ListTools` caller reach it as they do today (Rule 31). No caller gets its own cache, and no caller's file changes.
- The cache is per process. It is held in the `%`-variable `%OcuPilotToolList`, keyed by `$Namespace` and `$ClassName()`, following the pattern of `%OcuPilotDeclarations` and `%OcuPilotGateAreas`. It lasts as long as a turn job, and in a pooled REST worker it lasts across requests. Correctness never depends on it surviving.
- Every `ListTools` call revalidates the cache against the signature. The signature is (row count, sum of the day part, sum of the seconds part) of the `TimeChanged` values of the `%Dictionary.CompiledClass` rows whose `Name` starts with `..#TOOLPACKAGE` (`OcuPilot.`). It is read by **embedded** SQL, with the prefix bound as a host variable (AD-21).
- Only a successful build is cached, and only when the signature read before the build equals the one read after it. An error is never cached. If the signature cannot be read, the call builds without caching and answers that build.
- Callers receive objects they own. Each call answers a fresh array, parsed from the cached JSON text. The cached value itself is never handed out.
- A listing entry stays exactly `{name, kind, class, descriptor, fulfilment, advertised}`. The cache holds nothing that depends on the caller. Every call still reads, as it does today: privilege pairs (`RequiredPairs`, `ScreenRequirement`, which reaches `Screen.Gate.RequiredPairs`, `ArgumentPairs`, `HoldsPair`), `Policy.Resolve`, the restraint verdict, and the schemas and descriptions `ProviderTools` asks each tool for (AD-8, AD-22, AD-30, AD-64).
- `ListTools`' current body moves, byte-identical and in place, into a private build method, so that a concurrent edit to it merges cleanly.

**Never:**

- No time-to-live. No store shared across processes (no global, no protected-state write, no elevation: AD-8, AD-9). No compile hook, projection or method generator.
- Nothing is cached beyond the listing. That excludes `ProviderTools` output and `Resolve` results.
- The signature must not use string `MAX(TimeChanged)`, and must not be a count plus a max. `TimeChanged` is a `$H` `%RawString`, so string order is not time order. A compile batch also stamps every class with the batch's start time.
- No edits to `Kernel/Governance/Gate.cls`, `Kernel/Agent/Dispatch.cls`, `Kernel/Agent/Loop.cls`, `Kernel/Governance/Policy.cls`, `Test/ToolDispatch.cls`, `ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`. No production tool, descriptor or governance key is added.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Warm call | Listing cached, signature unchanged | A copy of the cached listing. No build. The registry costs one signature read | No error expected |
| First call in a process | Nothing cached | One build (about 0.6 s), then cached | A build error is returned as today, and nothing is cached |
| Compile in this process | A tool class is compiled after caching | The next call rebuilds and lists it | -- |
| Compile in another process | An IPM in-place upgrade, or another session, compiles | The next call in this process rebuilds and lists it, with no restart | -- |
| Recompile with `ADVERTISED` 0 | An advertised tool, cached | The next `ResolveWire` misses it; `Resolve(name, , 1)` finds it | -- |
| Class deleted | A listed tool class is deleted | The next call omits it | -- |
| Compile overlaps the build | The signature changes while the build runs | The built listing is answered but not cached | -- |
| Signature unreadable | `SQLCODE` < 0 | Build without caching, and answer that build | A build error is returned as today |
| Caller mutates an answer | A caller changes an entry or the array | The next call's answer is unchanged | -- |
| Other registry or namespace | A fixture registry, or another `$Namespace` | Each gets its own entry. A class that overrides `ListTools` bypasses the cache | -- |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Tool/Registry.cls` -- the one file changed.
  - `ListTools` (:106-187) builds the listing.
  - `Resolve` (:195) and `ResolveWire` (:221) each walk a fresh `ListTools`.
  - `ProviderTools` (:256) does too, then reads each tool's schemas.
  - `ToolClasses` (:699) is the embedded-SQL precedent for the signature query.
  - `Claim` (:744) creates the six-key entry.
  - `ToolPackage`, `ExcludedPackage`, `ScreenRegistryClass` and `ReadToolClass` are the fixture seams.
- `src/OcuPilot/Screen/Registry.cls`
  - `Descriptors` (:86): its doc says why only embedded SQL works here (dynamic SQL answered `SQLCODE -99` to an ordinary administrator).
  - `FingerprintSubjectProblem` (:2862): the 0.55 s phase. Read-only for this story.
- Siblings (Rule 31):
  - `src/OcuPilot/Screen/Descriptor/Base.cls` `Declaration` (:96) and `ForgetDeclaration`.
  - `src/OcuPilot/Screen/Gate.cls` `Adjustable` (:263).
  - Both are per-process `%`-variable caches keyed by `$$$cCLASShash`.
- Callers that need no change (they reach the cache through `ListTools`):
  - `Kernel/Agent/Dispatch.cls`: `AnswerOne` :208 and `ResolveClientCall` :474 (`ResolveWire`); `Advertise` :98 (`ProviderTools`).
  - `Kernel/Agent/Loop.cls` :524, :542, :570 (`ResolveWire`).
  - `Kernel/Governance/Gate.cls` :37 (`Resolve`, writes only).
  - `Kernel/Governance/Policy.cls` :183.
  - `Kernel/Proposal/Mint.cls` :445/:482/:528, `Confirm.cls` :254/:546, `Prohibited.cls` :1677/:2267/:5213, `Disclosure.cls` :127/:144 and `Draft.cls` :79.
  - `Api/ScreenAction.cls` :592, `Screen/Read.cls` :1273, `Screen/Context.cls` :184/:270 and `Kernel/Shell/Guardrails.cls` :75.
  - `Area/Security/*Save.cls` (`Resolve`).
- Test seams to reuse:
  - `src/OcuPilot/Test/ToolDispatchProbe.cls`: `SetRegistryClass`, the fixture gate (`GovernanceFixture.FixtureOnly`) and `HoldsPair` always held.
  - `src/OcuPilot/Test/DispatchTool/Counter.cls`: the abstract counting tool. Its `View` answers rows and `Clear` resets it.
  - `src/OcuPilot/Test/AdvertiseTool/Registry.cls`: the three-override fixture registry idiom. Its `ScreenRegistryClass` is `OcuPilot.Test.DispatchTool.Screens`, which yields no read tool.
  - `src/OcuPilot/Test/BadFulfilment/Registry.cls`: a registry whose build fails.
  - `src/OcuPilot/Test/ToolSetFull.cls` `ProbeAs` (:137): the `JOB` and `$System.Event.WaitMsg` child pattern.
  - `src/OcuPilot/Test/AtelierPortScriptRun.cls` `Run` (:98): creates a `%Dictionary.ClassDefinition` at run time and compiles it with `"ck-d"`.
  - `src/OcuPilot/Test/ToolDispatch.cls` `Call` (:57): drives `Answer` with one `tool_use`.

## Tasks & Acceptance

**Execution:**

- [x] Task 0, the before measurement, on `ocupilot-b-ci` before this story's `src` is loaded. The throwaway still holds the 20.22 head. Run the measurement snippet under Verification and record its three lines as `before (implement)` under Verification > Measured.
- [x] Task 0b, the Epic 18 check (empty diff against origin/OCU-1-epic18 7324381b, 2026-10-10). Run `git fetch origin OCU-1-epic18`, then `git diff --stat origin/feature/OCU-1_ocupilot-mvp...origin/OCU-1-epic18 -- src/OcuPilot/Screen/Tool/Registry.cls`. Empty: proceed. Not empty: stop with a `## Clarification Needed` naming the overlap (contended file, non-add-only edit).
- [x] `src/OcuPilot/Screen/Tool/Registry.cls` -- DW-2286.
  - Rename the current `ListTools` to a private `BuildListing(Output pTools As %DynamicArray) As %Status`, leaving its body byte-identical and in place.
  - Add a new public `ListTools(Output pTools)` with the same contract as today:
    1. Read the signature.
    2. If the cache entry for `($Namespace, $ClassName())` holds that signature, answer `%FromJSON` of the cached text.
    3. Otherwise, call `BuildListing` and count the build. If the build succeeded and the signature read again after it is unchanged, store the signature and `pTools.%ToJSON()`.
    4. Answer a fresh copy either way.
  - Add a private `CompileSignature(Output pSignature As %String) As %Status`. It runs one embedded `SELECT COUNT(*), SUM(CAST($PIECE(TimeChanged,',',1) AS INTEGER)), SUM(CAST($PIECE(TimeChanged,',',2) AS NUMERIC(20,9))) FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH :tRoot`, with `tRoot` = `..#TOOLPACKAGE`. It answers an error status when `SQLCODE` < 0.
  - Add a public `BuildCount() As %Integer`: how many times this process has built this registry class's listing in this namespace.
  - Add a public `ForgetListing()`: drop this process's cached listing for this registry class and namespace, without touching `BuildCount`.
  - Add one header paragraph stating the cache's contract: what it holds, what it never holds, and the revalidation on every call.
  - Why: the one cache, the invalidation and its observable.
- [x] `src/OcuPilot/Test/RegistryCacheProbe/Registry.cls` -- a new fixture registry with the three overrides from `AdvertiseTool.Registry`:
  - `ToolPackage` answers `OcuPilot.Test.RegistryCacheProbe.`.
  - `ExcludedPackage` answers `""`.
  - `ScreenRegistryClass` answers `OcuPilot.Test.DispatchTool.Screens`.
  - It lists only the probe tool compiled at run time.
- [x] `src/OcuPilot/Test/RegistryCache.cls` -- the story's tests: AC1, AC3 and AC4 below.
  - Through those, the tests cover every I/O matrix row except three:
    - "Compile overlaps the build" and "Signature unreadable" have no seam, and adding one would put a test hook in production code. Code review checks them in the code instead.
    - Another `$Namespace` holds no `OcuPilot` classes to list.
  - Methods:
    - `TestOneListingServesEveryCaller` (AC1);
    - `TestCompiledToolAppearsOnNextCall` (AC3, in-process compile, the `ADVERTISED` 0 recompile, and the delete);
    - `TestCompileInAnotherProcessIsSeen` (AC3, child `JOB`);
    - `TestCachedListingIsACopy`, `TestEntriesCarryOnlyTheListing` and `TestFailedBuildIsNotCached` (AC4).
    - `TestUnreadableSignatureBuildsWithoutCaching` (matrix row "Signature unreadable", through `OcuPilot.Test.RegistryCacheProbe.UnreadableRegistry`, a fixture subclass that overrides the private `CompileSignature`; added at review).
  - Helper `CompileProbe(pAdvertised As %Boolean = 1) As %Status` creates `OcuPilot.Test.RegistryCacheProbe.Late` and compiles it with `"ck-d"`. The class has `Super` `OcuPilot.Test.DispatchTool.Counter`, `TOOLNAME` `probe.cachelate.read`, `KIND` `read`, a `DESCRIPTION`, and `ADVERTISED` set from `pAdvertised`.
  - Helper `DropProbe()` runs `$System.OBJ.Delete(..., "-d")`.
  - Child entry `CompileProbeJob(pParent)` compiles the probe and signals its status to `pParent`.
  - `OnBeforeOneTest` and `OnAfterOneTest` drop the probe, `Reset` `ToolDispatchProbe`, `Clear` `Counter`, and snapshot and restore the stored governance policy, as `ToolDispatch` does.
  - Assert on `BuildCount` deltas, never on absolute values.
  - The class header says what it pins and what it needs. Keep the class under 500 lines.
- [x] Final measurement: after loading, run the same snippet and record its `after (cold)` and `after (warm)` lines under Verification > Measured. Also record `MappingWriteGate`'s duration (from the `(loop)` run) next to its `ci-timings.json` value, labeled as a different host.

**Acceptance Criteria:**

- **AC1 (one cache for every caller; the Integration AC, DW-2286).**
  - Given: the production registry has had `ForgetListing`, then one `ListTools`, which moves `BuildCount` by exactly 1 (so the counter counts).
  - When: the same process then calls, for the first advertised write tool in that listing:
    - `Registry.Resolve(name, , 1)`, as `Gate.Decide` does;
    - `ResolveWire(wire name)`;
    - `ProviderTools`;
    - `Governance.Gate.Decide(name, "write", $Username, {}, .d)`;
    - one production `OcuPilot.Kernel.Agent.Dispatch.Answer` of that tool, as `$Username`, under definition `""`, whose input carries an undeclared argument. The schema refuses it before `InvokeTool`, so the call can never mint.
  - Then: `BuildCount` does not move. `Answer`'s recorded name is the tool's canonical dotted name. The cached answer equals, as JSON, a fresh build taken after `ForgetListing`.
- **AC2 (the saving, measured).**
  - Given: the before numbers under Verification > Measured: the plan's read-only probe, plus Task 0's `Dispatch.Answer` line.
  - When: the same snippet runs after the change on `ocupilot-b-ci`.
  - Then: the cold and warm numbers are recorded next to the before numbers. A warm write call's registry share is one signature read per resolve (expected a few milliseconds, against about 1.18 s before).
- **AC3 (a newly compiled tool appears on the next call, with no restart).**
  - Given: the fixture registry's listing and the production registry's listing are both cached in the test process.
    - Before the compile, a `ToolDispatchProbe` call (registry set to the fixture) to `probe_cachelate_read` answers `TOOL.UNKNOWN`.
  - When: the probe is compiled. This runs twice: once in this process, and separately in a child `JOB` in the same namespace, which signals its compile status.
  - Then: the next dispatched call resolves the probe and answers it. Its name is `probe.cachelate.read` and `is_error` is 0.
    - The production registry's next `ListTools` moves its `BuildCount`, because its signature covers `OcuPilot.`.
    - After a recompile with `ADVERTISED` 0, the wire name answers `TOOL.UNKNOWN`, while `Resolve("probe.cachelate.read", , 1)` still finds it.
    - After `DropProbe`, `Resolve` finds nothing.
- **AC4 (only the listing is cached, and only as copies).**
  - Given: the production listing is cached.
  - When: a caller changes an entry in one `ListTools` answer and calls again.
  - Then: the second answer is unchanged, and every entry carries exactly the six keys.
  - And: `BadFulfilment.Registry`'s failing build moves `BuildCount` on every call (it is never cached).

## Spec Change Log

- 2026-10-10, spec gate (lead): the full ObjectScript sweep moved from the implement stage's `(once)` lines to the runner; AD-5 amended in the spine with the plan's proposed wording, shortened (Rule 20).

## Review Triage Log

### 2026-10-10 -- Review pass

- verdicts: 17 findings -- high 0, medium 2, low 13, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Verification gap: the "signature unreadable" branch of `ListTools` has no test -- a fixture subclass can override the private `CompileSignature`, so no production hook is needed. Patched: `OcuPilot.Test.RegistryCacheProbe.UnreadableRegistry` and `TestUnreadableSignatureBuildsWithoutCaching`; its `mutation:` line is in Verification (red on run 69).
  - `[medium]` `[patch]` `MappingWriteGate.TestAChildPastItsBudgetIsEndedNamingItsLastStep` needs the child to finish a cold-listing dispatch inside 6 seconds, so a slow host reddens it with the product unchanged. Patched: the plan is one `hang` step and the assertion is `(last at: step 1 hang)`; mutation re-run on the final form (run 72).
  - `[low]` `[reject]` AC2 has no pinning test and no `mutation:` line -- AC2's Then clause is the recording of measured numbers, which exist; a wall-clock assertion would depend on the host, and AC1's `BuildCount` delta already catches a cache that never hits.
  - `[false]` `[reject]` Cross-user claim unpinned (an `advertised` computed from `$Username` would stay green) -- `ToolSetFull.TestEveryToolIsAdvertisedToALeastPrivilegedPrincipal` (:183-184) builds the listing in a fresh child as a least-privileged principal and compares count and names with the parent's, so that mutation reddens it.
  - `[low]` `[reject]` The post-build signature read is redundant, because the cache stores the pre-build signature and a compile during the build moves the signature anyway -- the Boundaries require the equality check, it costs one 2 ms read per build, and removing it edits the contract.
  - `[low]` `[reject]` `CompileSignature` follows `..#TOOLPACKAGE` while discovery follows the overridable `ToolPackage()` -- the Boundaries name the parameter literally, and every registry lists under `OcuPilot.`; it would become real if a registry were given a package outside it.
  - `[low]` `[reject]` Exact `BuildCount` deltas fail if another process compiles under `OcuPilot.` during the test -- AC1 requires exactly that delta, the class header says it needs a development or throwaway instance, and CI runs one class at a time on a fresh throwaway.
  - `[low]` `[patch]` `TestOneListingServesEveryCaller` leaves the ledger row its production dispatch wrote -- `OnAfterOneTest` now removes the rows of the class's turn key (`TURNKEY`), asserted OK; zero rows remain after a run.
  - `[low]` `[reject]` Intent audit: no test asserts elapsed time -- the tests pin the cause (`BuildCount`), AC2 records the measured saving, and a wall-clock assertion would be machine-dependent.
  - `[low]` `[reject]` Intent audit: the turn loop's `ResolveWire` is not run by `RegistryCache` -- the loop reaches the cache through `ResolveWire`, which AC1 runs, and `TurnTools` (a `(loop)` class) is green.
  - `[low]` `[reject]` Intent audit: AC1's production `Answer` is a schema refusal, not a completed write -- AC1 specifies that call so it can never mint.
  - `[low]` `[reject]` Intent audit: the lifetime claims (a turn job, a pooled REST worker) are untested -- the spec says correctness never depends on the variable surviving, and the sibling `%`-variable caches pin none either.
  - `[low]` `[reject]` Intent audit: matrix rows "compile overlaps the build", "other namespace", "override bypasses the cache" and the class-deleted row on the production registry have no test -- the spec names the first and third as code-review rows, the override is true by construction, and the deleted-class row is pinned on the fixture registry; "signature unreadable" is the first finding above.
  - `[low]` `[reject]` Intent audit: the diff edits `MappingWriteGate.cls` and `MappingWriteGateProbe.cls`, which the intent does not list -- the first finding's cause: the old test used the listing's cost as a clock; the Never list forbids neither file.
  - `[low]` `[reject]` Intent audit: the signature follows compiles while `BuildListing` also reads saved `ToolFields` XData -- the spec's Named limits state it: a definition saved without a compile is seen at the next compile.
  - `[low]` `[reject]` Intent audit: public `BuildCount` and `ForgetListing` are test seams in production code -- the Tasks require both as "the invalidation and its observable"; they hold no test hook.
  - `[false]` `[reject]` Intent audit: the result section of the spec still reads `ready-for-dev` -- that section is written at Finalize, below.

## Design Notes

**Governing ADs:** AD-1, AD-5, AD-7, AD-8, AD-9, AD-10, AD-17, AD-18, AD-21, AD-22, AD-30, AD-31 and AD-64, plus the spine's dependency direction: the registry never depends on kernel behavior, and this cache reads only the class dictionary.

**Ledger inbox:** DW-2286 is addressed by the registry task and by AC1 to AC3. DW-2214 is context only (`owner=burndown`). It is not taken over here.

**Measured at this plan** on `ocupilot-b-ci` at the 20.22 head, read-only, as `irisowner` with `%All`:

- `ListTools`: 0.583 to 0.606 s. It lists 335 tools: 214 class tools and 121 read tools from 163 descriptors.
- Its phases:
  - class query 0.036 s (1,874 `OcuPilot.` classes);
  - `%Extends` 0.001 s;
  - `FingerprintSubjectProblem` over 205 write tools 0.550 s;
  - descriptor loop 0.042 s.
- Per call:
  - `ResolveWire` 0.574 to 0.590 s.
  - `Gate.Decide`: 0.589 to 0.610 s for a write, 0.000009 s for a read.
  - `ProviderTools` 0.96 s.
- So inside `Dispatch` a write call pays two listings (about 1.18 s) and a read pays one. The loop's step-recording `ResolveWire` (`Loop.cls` :570) adds one more listing per call. DW-2286's "any tool" holds through the loop only (inference from the code).
- Signature: `(count, Σ day, Σ seconds)` costs 1.8 ms warm in dynamic SQL; the first prepare in a process took 30 ms. The listing's JSON is 57,520 characters, and `%FromJSON` takes 0.2 ms.
- Compile stamps:
  - `$System.OBJ.CompileInfoClass` documents `CompiledClass.TimeChanged` as the class's compile time.
  - 1,864 of the 1,874 classes carry one stamp, which is 6 s after the last definition load. So a batch stamps its start time.
  - `"67854,9999.5"]"67854,10001.2"` answered 1, so string order is not time order.

**Decisions this plan takes:**

- **Invalidation signal.** The compile signature above, read on every call. A recompile raises a sum, a delete or add changes the count, and every class a batch compiles moves the sums as it is stamped. Which process compiled does not matter, because the signature is instance-wide state. So for a pooled REST worker, "per process" means for the worker's life, across requests, with a fresh check on every call.
- **The listing is user-independent.** The class query is embedded SQL, so it is not privilege-checked, and the XData reads need only the code database's READ, which every caller holds. `ToolSetFull` already pins that a least-privileged principal is offered the same roster. So a listing built during one user's request may serve the next user's.
- **Copies, not shared OREFs.** The siblings hand out their cached object. More than 40 call sites read this listing, so a copy (0.2 ms) removes any aliasing risk.
- **Rule 31.** This extends the sibling pattern (`Descriptor.Base.Declaration`, `Gate.Adjustable`): a per-process `%`-variable revalidated on every read, failures not cached, and a `Forget` method like `ForgetDeclaration`. It does not merge into a shared helper, because their key is one class's `$$$cCLASShash`, which cannot see a class that did not exist when the entry was made. The fixture registry copies `AdvertiseTool.Registry`'s three overrides, which is the established fixture idiom. The child `JOB` follows `ToolSetFull.ProbeAs`.
- **Files and Epic 18.** `Screen/Tool/Registry.cls` is not an add-only edit: the signature line is renamed and the methods are added around it. `origin/OCU-1-epic18` (f966d042, compared with feature 21b9e337) does not touch it. That branch touches `Kernel/Governance/Baseline.cls`, `Screen/Registry.cls` and `Test/ToolDispatch.cls`, none of which this story edits. Task 0b re-checks this. The two new test files are add-only.
- **Rule 3 exemption.** This is an internal path. No response shape or user-facing surface changes. The evidence is AC1 and AC3 through `Dispatch.Answer` on the real instance, plus AC2.
- **Integration AC:** AC1.
  - Consumes: `%Dictionary.CompiledClass`, through embedded SQL. No new port.
  - Consumed-by: every caller in the Code Map, unchanged. Also Stories 18.12, 20.4 and 20.23, whose new tools appear through this listing after their compile.
- **Named limits:**
  - A definition saved without a compile is seen at the next compile. `BuildListing` reads XData definitions, but the signature follows compiles.
  - A build that overlaps the very last class of a batch could keep that class's pre-compile view until the next compile or the end of the process (inference). The before-and-after equality check narrows this window.
  - `ProviderTools`' per-tool reads (about 0.35 s) stay uncached, and run once per turn.
- **For the lead's spec gate (Rule 20), a proposed AD-5 amendment:** "**The tool listing is built once per process and revalidated on every call** [AMENDED 2026-10-10, Story 20.24 spec gate, Rule 20]. `Screen.Tool.Registry.ListTools` keeps its listing per process, keyed by namespace and registry class. It rebuilds when the compile signature of the `OcuPilot.` package (the count of compiled classes and the sums of their compile times) differs from the one the listing was built under. So a compile in any process, an IPM in-place upgrade included, is seen on the next call with no restart. Only compile-time declarations may decide whether or how a tool is listed. A value read at run time (a setting, an adjustment, a grant or a policy) is read by its own reader on every call and never enters the listing (AD-8, AD-22, AD-30, AD-64)."

## Verification

**Shared surfaces:** none. No product list, menu, tool roster, schema or count changes, and the listing keeps its entries' six keys and order. The ObjectScript test roster gains `OcuPilot.Test.RegistryCache` (and two fixture classes under `OcuPilot.Test.RegistryCacheProbe`, which are not test cases), which CI's shard assignment discovers from the tree and weighs at the median. `ci-timings.json` is not edited.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete <verified working directory>/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `Do $System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- Never the dev instance `ocupilot-slot-b`.

**Measurement snippet** (Task 0 before the load, and again after the load). Pipe these lines into `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`:

```text
Set tW="security.mftconnections.create",tU=[{"type":"tool_use","id":"m1","name":"security_mftconnections_create","input":{"registryCacheUndeclared":1}}]
For k=1:1:3 { Set t0=$ZH Do ##class(OcuPilot.Screen.Tool.Registry).ResolveWire("security_mftconnections_create",.t) Set t1=$ZH Kill d Do ##class(OcuPilot.Kernel.Governance.Gate).Decide(tW,"write",$Username,{},.d) Set t2=$ZH Set sc=##class(OcuPilot.Kernel.Agent.Dispatch).Answer("registry-cache-measure",$Username,"",tU,"OcuPilot.Kernel.Agent.Limits",.r,.n) Set t3=$ZH Do ##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.p) Write "ResolveWire ",t1-t0," Decide ",t2-t1," Answer ",t3-t2," ProviderTools ",$ZH-t3," | ",n.%Get(0)," ",r.%Get(0).content,! }
Halt
```

The first line of a fresh session is the cold call and the rest are warm. The snippet writes one ledger row per `Answer`, on the throwaway only.

**Measured:**

- before (plan, read-only): `ResolveWire` 0.574 to 0.590 s; `Decide` (write) 0.589 to 0.610 s; `ProviderTools` 0.96 s.

- before (implement), 20.22 head on `ocupilot-b-ci`, `Answer` returns `TOOL.ARGUMENTS` (required `Name` missing), three runs (first is cold):
  - `ResolveWire` 0.605 / 0.581 / 0.586 s; `Decide` 0.587 / 0.582 / 0.588 s; `Answer` 1.179 / 1.181 / 1.180 s; `ProviderTools` 0.972 / 0.964 / 0.967 s.

- after (cold), first line of a fresh session on `ocupilot-b-ci`, `Answer` returns `TOOL.ARGUMENTS`: `ResolveWire` 0.609 s (the one build); `Decide` 0.004 s; `Answer` 0.017 s; `ProviderTools` 0.394 s.
- after (warm), the two lines after it:
  - `ResolveWire` 0.003 / 0.003 s; `Decide` 0.003 / 0.003 s; `Answer` 0.017 / 0.017 s (was 1.18 s); `ProviderTools` 0.393 / 0.397 s (was 0.97 s).
- `MappingWriteGate` on `ocupilot-b-ci` after the change: 15.3 and 16.7 s (`%UnitTest_Result` `Duration`, seconds, runs 63 and 65). `ci-timings.json` holds 60.6 s from a CI host, so the two are different hosts. `ClassicPageGate` took 11 s here against 409.9 s there.

**Implement-stage results:**

- `RegistryCache`: 6 tests, 0 failed (run 43), read back from `%UnitTest_Result` with 9, 16, 23, 16, 12 and 21 assertions per method. After review it has 7 tests (the unreadable-signature row).
- `uv run scripts/check-objectscript.py ...`: 0 problems (21 rules, 1,877 files, after the review patches).
- The eleven other `(loop)` classes were green on the first run except `MappingWriteGate`, whose `TestAChildPastItsBudgetIsEndedNamingItsLastStep` was red (run 62). It outlasted a 6-second budget with 20 dispatches that each cost two listings; with the listing cached they finish in under a second. The test now plans one `hang` step of 30 seconds (a new step kind in `MappingWriteGateProbe`, whose progress label falls back to the step's kind) and asserts the error names `(last at: step 1 hang)`. `ClassicPageGate` (run 67) and `LanguageServerEditorWire` (run 66), the other callers of `MappingWriteGate.RunAs`, are green.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call with `timeout: 600000`, each read back from `%UnitTest_Result`. The classes:
  - `RegistryCache`;
  - `ToolDispatch`;
  - `ToolEmit`;
  - `ToolNavigate`;
  - `ToolDispatchClientFault`;
  - `ToolWrite`;
  - `ReadTool`;
  - `TurnTools`;
  - `ToolSetFull`;
  - `SurfaceCoverage`;
  - `GovernanceBaseline`;
  - `MappingWriteGate`.
- `(loop)` `uv run scripts/check-objectscript.py src/OcuPilot/Screen/Tool/Registry.cls src/OcuPilot/Test/RegistryCache.cls src/OcuPilot/Test/RegistryCacheProbe/Registry.cls` -- expected: 0 problems.
- Lead-owned, not the implement stage's: the full ObjectScript sweep (`cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/30` for k = 1 to 30, one call per k). The runner runs it after code review and before the smoke (kit verification option (b): the suite is about twenty times the foreground cap; Epic 20's practice since Story 20.4).
- `(once)` `cd ui && npm run test:tools`, because `ci.test.mjs` scans `src/OcuPilot/Test`. Expected: all pass.
- `(once)` `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: pass, with at least one check executed.
- Left to CI: the full browser suite (Rule 29). This story touches no client file.

**Planned pinning mutations (Rule 19).** The implement stage confirms each one and records it as a `mutation:` line.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ListTools` skips the cache read and always calls `BuildListing` | `TestOneListingServesEveryCaller` (`BuildCount` moves) |
| AC3 | `CompileSignature` answers a constant | `TestCompiledToolAppearsOnNextCall` and `TestCompileInAnotherProcessIsSeen` (the probe is never listed) |
| AC4 | The cache stores and answers the built `%DynamicArray` itself | `TestCachedListingIsACopy` |
| AC4 | `Claim` adds a seventh key | `TestEntriesCarryOnlyTheListing` |
| AC4 | A failed build is cached | `TestFailedBuildIsNotCached` |

**Final verification pass (after the last review patch):**

- All twelve `(loop)` classes, one at a time in one runner call (about 37 seconds in all): 151 tests, 0 failed, runs 73 to 84.
- `(once)` `npm run test:tools`: 1906 tests, 0 failed.
- `(once)` smoke on `ocupilot-b-ci`: `executed=50 passed=50 failed=0`, PASSED.

- mutation: `ListTools`' cache read replaced by `If 0` (always builds) -> `TestOneListingServesEveryCaller` red ("none of the five callers built the listing again"); `TestCachedListingIsACopy`, `TestCompileInAnotherProcessIsSeen` and `TestCompiledToolAppearsOnNextCall` also red, on their `BuildCount` delta (run 44).
- mutation: `CompileSignature` answers the constant `"constant"` -> `TestCompiledToolAppearsOnNextCall` and `TestCompileInAnotherProcessIsSeen` red, the other four green (run 45).
- mutation: the cache stores the built array and answers it -> `TestCachedListingIsACopy` red, the other five green (run 46).
- mutation: `Claim` sets a seventh key -> `TestEntriesCarryOnlyTheListing` red, the other five green (run 47).
- mutation: a failed build is cached as `[]` under the signature -> `TestFailedBuildIsNotCached` red, the other five green (run 48).
- Each of those five was reverted from a backup copy (`cmp` identical), and the throwaway reloaded `Registry.cls` and recompiled all fourteen `Tool.Registry` subclasses before the next run; `RegistryCache` was green on the reverted code (run 49: 6 tests, 0 failed).
- mutation (`MappingWriteGate`): `Terminate` commented out of `RunAs` -> `TestAChildPastItsBudgetIsEndedNamingItsLastStep` red on "the child process ... is ended" (run 72, on the final form of the test); reverted, tree identical, reloaded, green (run 74).
- mutation (matrix row "Signature unreadable"): `ListTools` reads the cache without checking the signature read's status -> `TestUnreadableSignatureBuildsWithoutCaching` red alone (run 69, `<UNDEFINED>` on the first call); reverted, tree identical, the throwaway reloaded and all fifteen `Tool.Registry` subclasses recompiled, green (run 70).

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `Screen.Tool.Registry.ListTools` now keeps its listing in a per-process cache (`%OcuPilotToolList`, keyed by namespace and registry class) and answers each call a fresh array parsed from the cached JSON. Every call first reads a compile signature of the `OcuPilot.` package by embedded SQL and rebuilds when it differs. A failed build, an unreadable signature and a build a compile overlapped are never cached. On `ocupilot-b-ci` a warm `Dispatch.Answer` of a write tool fell from 1.18 s to 0.017 s and a warm `Decide` from 0.59 s to 0.003 s (DW-2286).

**Files changed.**

- `src/OcuPilot/Screen/Tool/Registry.cls`: old `ListTools` body moved in place to private `BuildListing`; new `ListTools`, `BuildCount`, `ForgetListing`, private `CompileSignature`; one header paragraph.
- `src/OcuPilot/Test/RegistryCache.cls`: seven tests for AC1, AC3, AC4 and the unreadable-signature row.
- `src/OcuPilot/Test/RegistryCacheProbe/Registry.cls` and `UnreadableRegistry.cls`: the fixture registry and its failing-signature subclass.
- `src/OcuPilot/Test/MappingWriteGate.cls` and `MappingWriteGateProbe.cls`: the budget test waits on a new `hang` step instead of relying on the old listing cost.

**Review.** 17 findings: patches applied 3 (two medium, one low), deferred 0, rejected 14 with their reasons in the triage log. Nothing was deferred, so `deferred:` stays empty.

**Follow-up review recommended: true.** Two medium findings were patched. Risk: both patches are test-only and were checked by observed reds on `ocupilot-b-ci`, but neither has run on a CI leg's fresh throwaway, and the rewritten `MappingWriteGate` budget test still needs its child to reach its first step label within 6 seconds on the slower CI host.

**Verification.** Final pass after the last patch: all twelve `(loop)` classes green (151 tests, runs 73 to 84), `check-objectscript` 0 problems, `npm run test:tools` 1906 pass, smoke `executed=50 passed=50`. The lead-owned full ObjectScript sweep was not run, per the arrangement. Mutations: five planned plus two added, each observed red and reverted with an identical tree (lines under Verification).

**Residual risks.** The "compile overlaps the build" row has no test (no seam); it is checked in the code, where the cached signature is the pre-build one. Tests elsewhere in the suite that used the old listing cost as a clock would fail only in the full sweep (`MappingWriteGate` was one). The signature follows compiles, so a definition saved without a compile is seen at the next compile (a named limit).
