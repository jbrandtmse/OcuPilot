---
title: 'Story 23.3: The range-end cleanup, part 3'
type: 'bugfix'
created: '2026-10-01'
status: 'in-progress'
review_loop_iteration: 0
baseline_revision: '66f2e7162232257c1afaa55fc5891874cb87841c'
baseline_commit: '66f2e7162232257c1afaa55fc5891874cb87841c'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      proposal-demo AC3 goes red on the post-sweep throwaway: the move to the audit screen after the user's "yes" exceeds its 30 s wait.
    evidence: |-
      Stage re-runs on ocupilot-b-ci (4.3M audit rows), 2026-10-01: AC3 red in 2 of 5 runs at proposal-demo.browser-spec.mjs:617 (TimeoutError, Waiting failed: 30000ms), green in the others. AC3 is untouched by batch b. Whether it reddens on a fresh CI container is unverified; the cause, measured in batch c, is the file's own previous run's late provider call record under its tag (fixed in 12790813), not the audit volume.
    location: >-
      ui/browser/proposal-demo.browser-spec.mjs:617
    severity: medium
  - summary: >-
      browser.config.mjs's launchOptions doc comment says a spec states no launch option of its own, but two specs add one.
    evidence: |-
      ui/browser.config.mjs:99 reads "The launch options, so the spec states none of its own." data-table-columns.browser-spec.mjs:441 already spread it with ignoreDefaultArgs before this story, and batch b's a11y-structural-invariants.browser-spec.mjs:48 adds protocolTimeout. A comment-only correction outside batch b's files.
    location: >-
      ui/browser.config.mjs:99
    severity: low
---

<intent-contract>

## Intent

**Problem:** Twelve chartered ledger entries are open. CI's three instance legs run 38 to 46 minutes. Four flakes and four isolation defects produce false reds. Three security gaps remain: a declared secret the model sends as an id reaches a step's target, a privileged role reaches a service address unmarked, and the residue sweep skips the log.

**Approach:** Fix all twelve in four batches, in this order: (a) a fourth instance shard, (b) flakes, (c) isolation, (d) security, DW-1782 first. Each batch gets one implement pass and one commit, needs a green CI run on its head, and is merged at its boundary. A defect is shown by a test that reddens on it; a flake or an isolation defect is shown by its test passing under the condition that reproduces it.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`.
- Run tests and state-changing probes only on the throwaway `ocupilot-b-ci`, one class per call, and await each run in `%UnitTest_Result`. Never restart it: its compose file predates DW-48, so a restart is a product start and deletes `OcuPilot.Test`.
- Run one implement pass per batch, in the order a, b, c, d. A red batch is reopened alone.
- Every fix that is a wait, a predicate or a refusal has a `mutation:` line in its batch's Verification (Rule 19).
- Reproduction state is removed afterwards and read back as gone: a seeded definition, an override, a monitor state, a held response. Leave the throwaway with no definition, no override and no seeded row of this story's.
- Prose discipline (CLAUDE.md) applies to every comment. Non-ASCII characters in source are written `\uXXXX`.

**Never:**

- Implement passes do not edit the spine, `CLAUDE.md`, `.claude/rules/`, `_bmad/custom/`, `epics.md`, the ledger, or another story's spec. The lead applies Design Notes › Lead edits.
- Do not lower any `timeout-minutes`. The browser suite stays at three legs.
- Do not touch `structural-walk.mjs`'s id-source table. A red that depends on shard composition is fixed in the test, never by pinning to a shard (Conventions › Tests).
- No product behavior changes except DW-1782 and DW-1881. Nothing beyond the twelve; anything else is named for filing.
- Do not stop, restart or `down` any container. The full browser suite is never run as verification, because CI's browser shards run it. The one full run in DW-1204 is a reproduction.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Secret sent as an id (DW-1782) | The model calls `permissions_users_password` with `{"id": V, "Password": V}` | The step's `target` reads `[redacted]` in the poll, the stored transcript and the panel's card. V appears in none of them. | A target that holds no declared secret's value is kept as sent |
| Privileged role, `\|` spelling (DW-1881) | A proposal adds `10.0.0.9\|%Manager` (or `%Operator`) to a service's allowed addresses | Destructive treatment, privileged consequence. The editor marks the role privileged. | A role whose read fails counts as privileged |
| Classic spelling (DW-1881) | `10.0.0.9:%All` reaches `GrantsPrivilegeByEffect` | Privileged grant | No error expected |
| Held classic entry (DW-1881) | Target holds `10.0.0.6:%All`; payload is `10.0.0.6\|%All,%Developer` | Not a privileged grant: `%All` was already held | No error expected |
| Non-administrative role (DW-1881) | `10.0.0.9\|%Developer` | Not destructive by this arm | No error expected |
| CI shape (DW-1901) | A push | Four instance legs (`1/4` to `4/4`) and three browser legs. Both roll-ups are green, with every class and spec file in exactly one leg. | A missing record, an empty leg or a duplicate fails the roll-up |

</intent-contract>

## Code Map

- **a:**
  - `.github/workflows/ci.yml`:
    - the instance literals: `:134` name `/3`, `:142` `shard: [1, 2, 3]`, `:185` `--shard …/3`, `:231` `--shards 3`;
    - the comments at `:15` and `:130-131`;
    - the browser literals stay as they are (`:237`, `:245`, `:284`, `:319`), and so do the timeouts (`:138` 61, `:241` 43).
  - `ui/tools/ci-shards.mjs`:
    - `refresh --run` downloads the run's `ci-record-*` with `gh` (`:417`) and rewrites `ci-timings.json` (`:457`);
    - `assign` (`:358-384`) only prints;
    - `checkRecords` (`:210-286`);
    - the comment at `:6`.
  - `ui/tools/ci-runner.mjs:42` (comment).
  - `ui/tools/ci.test.mjs`:
    - the declared-gates strings at `:122` and `:128`;
    - `SHARDED` at `:2713-2716`;
    - the test at `:2747-2763`, which asserts `[1, 2, 3]` for both suites;
    - the timeout check at `:2819-2833` already uses the matrix length.
  - `docs/DEVELOPMENT.md:451-452,466`.
  - Measured on run 36910157178 (`33d325da`, green):
    - instance legs 44.6, 45.7 and 23.5 min; browser legs 25.1, 27.3 and 25.7 min; wall time 46.1 min;
    - timings refreshed from it, held in memory and not written: four instance legs about 26.5 min each (timeout floor 44.3 against 61), browser about 23.5 min (floor 39.7 against 43).
- **b:**
  - DW-1866: `Test/AdminPortAbsence.cls`:
    - `TestAVerifiedDeletePostsNoAlert` at `:90-107`, with the instance-wide counter at `:95,:103` and the state check at `:96,:106`;
    - `LOGMONITORWAIT` at `:23`, the alerts.log helpers at `:109-161`, and the header at `:1-9,:82-89`.
    - Helper `Test/SslSinks.cls`: `LogOffset` `:17`, `LogSince` `:24`, `Flush` `:46`.
    - The port logs from `Port/AdminPort.cls:1100` (`'..IsMutating`) through `Kernel/Audit/Log.cls:82-98` with `WriteToConsoleLog(…,1,2,"OcuPilot.Log")`. A line reads `(<pid>) 2 [OcuPilot.Log] [OcuPilot] {…"subsystem":"adminport"…}`, measured on `ocupilot-b-ci`.
  - DW-1865: `ui/browser/proposal-demo.browser-spec.mjs:348-356` is a bare evaluate.
    - `Kernel/Agent/Loop.cls` appends the step `running` at `:559`, mints at `:580` and finishes at `:605`. The poll runs every 1000 ms (`ui/src/app/core/turn.ts:56`).
    - Precedent: `ui/browser/users-write.browser-spec.mjs:252-259`.
  - DW-1808: `ui/browser/audit-events.browser-spec.mjs`:
    - `recordActions` at `:121-132` collects **POST** responses, so `[200, 200]` at `:342` is rounds 0 and 1 of the Apply POST. It is not a write and a re-read.
    - Nothing waits for round 1's response. The page re-reads the list after its POSTs (`ui/src/app/areas/security/auditing-config.page.ts:505-520`).
    - Precedent: the same file's "the delete answered" wait.
  - DW-1822: `ui/browser/a11y-structural-invariants.browser-spec.mjs:48` calls `puppeteer.launch(launchOptions(config))`. `ui/browser.config.mjs:100-110` sets no `protocolTimeout`; puppeteer 24.24.0 defaults to 180,000 ms.
    - The walk's only evaluate that awaits a page promise is `settle`'s `await document.fonts.ready` (`ui/browser/structural-walk.mjs:585-588`).
    - CI evidence: runs 36569407842 and 36751724771. In each, the `before` hook died at about 250 s, with the call that hung starting about 70 s into the walk. A green walk takes 179 s.
- **c:**
  - DW-1759: `Kernel/State/Agent.cls`:
    - `NameIdx` at `:155` and `DefaultIdx` at `:157`. Only `Agent` declares these indexes; the compiled ones are these two plus IDKEY.
    - `ResolveDefault` at `:627` picks the lowest-id row marked default and enabled. `GuardedRebalanceDefault` at `:650` hands the marker to the lowest-id enabled row.
    - Rows sit in the shared extent `^OcuPilot.Kernel.State.BaseD(id)` / `BaseI(<index>,…)`.
    - Definition ids are referenced by `Kernel/State/Entry.cls:79`, `Turn.cls:44` and `Propose.cls:161,163`, and checked by `Kernel/Proposal/Confirm.cls:361`.
    - `Test/AgentFixture.cls`: `CreateDefinition` `:23`, `RemoveProbeDefinitions` `:79`.
    - The 29 methods:
      - AgentState, 13. Every method asserts `PreparedInstanceEmpty`, which is set at `:34-42`.
      - TurnContext, 7: `:607`, `:514`, `:317`, `:296`, `:156`, `:458`, `:209`. Set up at `:54`, torn down at `:76`. These are (inference) from the mechanism; the count matches the ledger.
      - TurnWire, 1: `:272`. Set up at `:44`, torn down at `:65`.
      - AgentWire, 3: `:97`, `:141`, `:497`.
      - StateRead, 3: `:89`, `:138`, `:156`.
      - EgressLocal, 1: `:190`.
      - Restraint, 1: `:300`.
  - DW-1839: `Kernel/State/Policy.cls`: `GuardedApply` `:73`, where `inherit` deletes the row; `DeleteAllGuarded` `:133`.
    - `Test/GovernanceFixture.cls`: `Snapshot` `:9`, `Restore` `:17`, `Matches` `:36`, `Apply` `:58`, `Clear` `:123`. Pattern to copy: `Test/Governance.cls:53-80`.
    - Governance refuses a confirm at `Kernel/Proposal/Confirm.cls:318-325`.
    - The seven failures:
      - DeviceDelete `:64,:94,:112` (hooks at `:24/:33`);
      - DeviceWire `:292` (only `OnAfterOneTest`, at `:105`);
      - DeviceWriteGate `:152` (only `OnAfterOneTest`, at `:94`);
      - Prohibited `:626` (hooks at `:32/:42`);
      - ToolDispatch `:141` (hooks at `:23/:30`).
  - DW-1204: DW-1190 was fixed by `9bf7c9d1` (the messages-log seed window). The DW-1447 reset is fixed: `ui/browser/preferences-reset.mjs` clears every preference kind.
    - Post-sweep `ocupilot-b-ci`, measured: 4,325,263 audit rows, 1,607 unit-test instances, 1,857 ledger rows.
    - Candidates, by reading only:
      - `audit.browser-spec.mjs`: AC2 counts exactly in its own window; AC6 expects 1,000 rows within 2 s;
      - `log-hub`;
      - `default-search`;
      - `agent-ledger`;
      - `secondary-logs` AC4.
  - DW-434:
    - `ui/src/app/areas/agent/switches.page.spec.ts`: the constant at `:52-53`, used at `:59` and asserted at `:371-372`.
    - `ui/src/app/areas/agent/definition-form.page.spec.ts`: the constant at `:190-191`, fixtures at `:1013,:1041,:1069`, asserts at `:1025-1026` and `:1057`. `:1057`, on the Test connection path, is the only assertion not covered by an exact `toBe(STRINGS.formStaleSave)`.
    - The server's value: `src/OcuPilot/Api/Error.cls:723` `REASONSTATECONFLICT`.
    - Precedent for reading the server value: `ui/tools/audit-event-copy.test.mjs:22,44-48` (`serverValue`).
- **d:**
  - DW-1782:
    - Every step target comes from `Kernel/Agent/Dispatch.cls` `TargetOf` (`:612`), raw. The write sites are:
      - `AnswerOne` `:198`, with secret names at `:215` and arguments re-derived at `:220`;
      - `Kernel/Agent/Loop.cls` `:514`, `:531`, `:559`, `:569` and `:585`, all `TargetOf(tRunningInput)`; `:605` writes `tDetail.target`.
    - The ledger's decision: `Kernel/Audit/Ledger.cls` `CarriesSecretValue` (`:294-316`, public, fails closed), used at `:279-280`. The mark is `Kernel/Audit/Log.cls:42` `REDACTED`.
    - Precedent for delegating to it: `Dispatch.StepArguments` `:643`, which calls `Ledger.RedactArguments`.
    - Every surface reads `Kernel/State/Step.cls`:
      - the poll (`Api/Turn.cls:218`);
      - the transcript copy (`Kernel/Agent/Job.cls:147-154` into `Entry.StepsJson`, read by `Api/Transcripts.cls:79,126`);
      - the card label (`ui/src/app/shell/tool-call-card.ts:43`, `stepLabel` at `ui/src/app/core/turn.ts:816-818`).
  - DW-1881: `Kernel/Proposal/Prohibited.cls`:
    - `AddressGrantsPrivilege` `:4138-4168` splits on `|` only and judges with `IsPrivilegedRole` (`:3158`, by name). Its only caller is `GrantsPrivilegeByEffect` `:3048` (service branch `:3071-3073`).
    - `RoleGrantsAdministrativePrivilege` is at `:2915`. The OAuth precedent is `AddsPrivilegedCustomizationRole` `:2566-2582`.
    - `Area/Permissions/ServiceRules.cls`: `EntryParts` `:246-256` reads both spellings the way the vendor's dialog does; `RoleOptions` asks the kernel at `:534`.
    - Vendor: `irissys/%CSP/UI/Portal/Dialog/Service.cls:330,391`; `irissys/Security/Services.cls:154`.
    - `Screen/Tool/ServiceUpdate.cls:154-167` sends held entries verbatim.
  - DW-1307: `Test/TurnSecretResidue.cls`: the header at `:1-5`, and `TestNoKeyReachesTheLedger` at `:135-169`, which sweeps the ledger, the steps and the view only. The console log is reached through `Kernel/Audit/Log.cls:82-99,226`. Usage of the `SslSinks` helper: `Test/SslSecret.cls:91,114-117`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch, leaving the tree for one commit: `fix(23.3): batch <x> - <area>`.
- Each entry gives its defect, its reproduction or red, its fix, its files and its ADs.
- The lead writes the ledger trailers once the batch's commit is green.

### Batch a: CI health (DW-1901)

- [x] **DW-1901** — With three instance legs, the run's wall time is 46 min (run 36910157178).
  - **Fix:**
    - Refresh `ui/tools/ci-timings.json` with `cd ui && node tools/ci-shards.mjs refresh --run 36910157178`, or from a later green full run on the feature line. Record the run used.
    - In `ci.yml`, set the instance matrix to `[1, 2, 3, 4]`, the names and `--shard` to `/4`, and the roll-up to `--shards 4`. Reword the comments at `:15` and `:130-131`.
    - In `ci.test.mjs`:
      - give each `SHARDED` entry its leg count (instance 4, browser 3);
      - assert the matrix equals `1..legs`;
      - rename that test;
      - update the gates strings at `:122` and `:128`.
    - Correct the comments at `ci-shards.mjs:6` and `ci-runner.mjs:42` to `k/4`.
    - In `docs/DEVELOPMENT.md`:
      - `:451`: "four legs, `instance shard 1/4` to `4/4`", and `--shard k/4`;
      - `:452`: "the four legs' records";
      - `:466`: "**The ObjectScript suite is split across four containers and the browser specs across three, never run in parallel inside one.**"
  - **No other changes:** `ci-throwaway.sh`, the ports and the leg-1-only steps stay as they are (`matrix.shard == 1`).
  - ADs: Stack › CI, Operational Envelope › Build and CI, Conventions › Tests.
  - AC: Given batch (a)'s head, when CI runs, then:
    - `instance-shard` runs legs `1/4` to `4/4` from the refreshed timings;
    - `instance` is green with every class in exactly one leg and no empty leg;
    - `browser-shard` still runs three legs;
    - no `timeout-minutes` is lower;
    - the boundary reports the longest instance leg.

### Batch b: CI flakes (DW-1866, DW-1865, DW-1808, DW-1822)

- [x] **DW-1866** — The test judges alerts instance-wide. A severe line from any other process inside the window fails `:103`, and an instance already at Warning fails `:106`.
  - **Reproduce** on `ocupilot-b-ci`, before the fix:
    - (i) While the class runs, a `Job` posts `##class(%SYS.System).WriteToConsoleLog("DW-1866 unrelated line",0,2)` every 5 s for 60 s. That rate stays under the monitor's limit of 3 alerts in 10 s per process.
    - (ii) `Do $SYSTEM.Monitor.SetState(1)` before the run.
    - Restore with `Do $SYSTEM.Monitor.Clear()` and read `State()` back as 0.
  - **Fix:**
    - Drop the counter and state assertions, `LOGMONITORWAIT`, the `Hang`, and the two alerts.log helpers.
    - Take `SslSinks.LogOffset()` before the delete. After it, assert that `SslSinks.Flush(tOffset)` holds, then that `LogSince(tOffset)` holds no line carrying `(<$JOB>) `, `[OcuPilot.Log]` and `"subsystem":"adminport"`. A severity-2 `messages.log` line is what the instance copies to alerts.log.
    - Reword the header and the method doc to match.
  - Files: `Test/AdminPortAbsence.cls`. ADs: AD-2, AD-39, Conventions › Tests.
  - AC: Given (i) or (ii), when `TestAVerifiedDeletePostsNoAlert` runs, then it passes. Given the re-read's 404 is logged, then it fails.
- [x] **DW-1865** — AC1 reads the tool card at the moment the proposal card appears. A poll between the mint (`Loop.cls:580`) and the finish (`:605`) shows `running`.
  - **Reproduce:** a temporary local edit, never committed, between `:283` and `:284`. It opens CDP `Fetch.enable` on `*/api/ocupilot/turn/*/progress*` at the Response stage. The first body whose `proposals` is non-empty is fulfilled with every tool step's `status` set to `running`; all other bodies pass unchanged. Before the fix, `:355` reads `running`.
  - **Fix:** before `:348`, `page.waitForFunction` until `app-tool-call-card .ocu-tool-call-status-word` reads `STRINGS.toolCallStatusDone`, within `config.navigationTimeoutMs`.
  - Files: `ui/browser/proposal-demo.browser-spec.mjs`. ADs: Conventions › Tests.
  - AC: Given that rewrite, when AC1 runs, then it waits for `done` and passes.
- [x] **DW-1808** — Round 1's POST response can land after the instance has changed and the dialog has closed, so `:342` sees `[200]`.
  - **Reproduce:** a temporary local edit that holds the second paused `…/security.auditsystemevents/action` POST response for 3 s (CDP `Fetch` at the Response stage). Before the fix, `:342` is red.
  - **Fix:**
    - In each round, before clicking Apply, arm `page.waitForResponse` for the GET of `/api/ocupilot/screens/security.auditsystemevents/read`.
    - After the dialog closes, wait for `statuses.length === round + 1`, then await the re-read.
  - Files: `ui/browser/audit-events.browser-spec.mjs`. ADs: Conventions › Tests.
  - AC: Given that hold, when AC2 runs, then it passes with both 200s and the re-read received.
- [x] **DW-1822** — One protocol call in the walk exceeded puppeteer's 180 s default. The one awaiting evaluate is `settle`'s font wait; that CI's stall was a font fetch is (inference).
  - **Reproduce:** a temporary local edit after the launch adds `browser.on('targetcreated')` request interception. It holds the first `.woff2` response for 200 s. Before the fix, `Runtime.callFunctionOn timed out` appears at about 180 s.
  - **Fix:** change `:48` to `puppeteer.launch({ ...launchOptions(config), protocolTimeout: 600_000 })`. A green walk takes 179 s, and the browser leg runs about 25 min against its 43 min timeout.
  - Files: `ui/browser/a11y-structural-invariants.browser-spec.mjs`, the launch line only (Design Notes › Contention). ADs: Conventions › Tests.
  - AC: Given the 200 s hold, when the spec runs, then no protocol call times out and the spec passes.

### Batch c: test isolation (DW-1759, DW-1839, DW-1204, DW-434)

- [x] **DW-1759** — With any agent definition present, it is the lower id, so it holds or retakes the default marker, and 25 methods fail (measured in batch c; the ledger's 29 counted four TurnContext methods that stay green).
  - **Reproduce** on `ocupilot-b-ci`:
    - Seed one enabled definition that is not named as a probe: `UpgradeSeedAgent` through `Agent.GuardedCreate`, with provider `anthropic` and `CredType` `env`.
    - Run the seven classes one at a time. Expect 13 + 7 + 3 + 3 + 1 + 1 + 1 red before the fix.
    - Remove the seed with `GuardedDeleteId` and read back 0 definitions.
  - **Fix:** add `SetAsideDefinitions()` and `RestoreDefinitions()` to `Test/AgentFixture.cls`.
    - **Set aside:**
      - First restore anything a crashed run left.
      - Then, for every Agent row, move `BaseD(id)` with its subtree, plus the `BaseI("NameIdx")` and `BaseI("DefaultIdx")` subtrees, into a persistent `^OcuPilot*` global. `Base.MAPPINGPATTERN` maps that name into OcuPilot's protected database.
      - Move raw nodes, never `GuardedDeleteId`, so ids and row versions survive and nothing rebalances.
    - **Restore:**
      - `RemoveProbeDefinitions`.
      - Refuse, keeping the copy, if any Agent row or index node remains.
      - Otherwise merge the copy back and kill the holding global.
    - **Callers:**
      - Each of AgentState, AgentWire, StateRead, Restraint and EgressLocal sets aside first in `OnBeforeAllTests` and restores last in `OnAfterAllTests`.
      - TurnContext (`:54/:76`) and TurnWire (`:44/:65`) set aside before `MarkedDefault` and restore last.
      - If `OnBeforeAllTests` fails after the move, it restores on that error path.
  - Files: `Test/AgentFixture.cls` and the seven classes. ADs: Conventions › Tests, AD-9.
  - AC: Given one enabled definition and, in a second pass, a second disabled one, when each of the seven classes runs, then it passes, and each seeded row's `BaseD(id)` and id read back byte-identical.
- [x] **DW-1839** — A stored override disables `osmgmt.devices.delete`. Confirm then refuses it as `GOVERNANCE.DISABLED` (`Confirm.cls:318-325`), and Prohibited's baseline precondition fails.
  - **Reproduce:** run `Kill s Set s("osmgmt.devices.delete")="disabled"` and then `GovernanceFixture.Apply("",.s)`, and run the five classes (7 red before the fix). Afterwards run `Policy.DeleteAllGuarded()` and read back 0 rows.
  - **Fix:** copy `Governance.cls:53-80` into all five classes:
    - `OnBeforeOneTest` snapshots and clears the whole store, because a stored read-only preset would disable more.
    - `OnAfterOneTest` restores the snapshot and asserts `Matches`.
    - Add `OnBeforeOneTest` to DeviceWire and DeviceWriteGate.
    - Prohibited's "leaves every key to the baseline" stays, as the class's own precondition.
  - Files: `Test/{DeviceDelete,DeviceWire,DeviceWriteGate,Prohibited,ToolDispatch}.cls`. ADs: AD-22, Conventions › Tests.
  - AC: Given that override, when each of the five classes runs, then it passes, and the override reads back unchanged.
- [x] **DW-1204** — A browser spec that relies on instance state the class sweep disturbs fails on a container the sweep has run on.
  - **Reproduce by running.** This is a one-time measurement, not verification. `ocupilot-b-ci` is post-sweep.
    - Redeploy the bundle.
    - Run `audit.browser-spec.mjs` alone first.
    - Then run every other `browser/*.browser-spec.mjs` once, in sorted order, except `audit-copy-purge`, which would copy 4.3M audit rows into USER (Design Notes › Named for filing). CI's per-file timings sum to about 75 min; local time differs (inference).
    - Re-run each failure alone on the same container.
    - A file that fails alone is a member. A file that passes alone depends on another spec's leftovers and is named for filing.
  - **Fix each member** in its own spec file: assert only on rows or lines its own action produced, or within a window it opened itself. Show it passing alone on the same container.
    - If a fix needs product code or another spec, name it for filing.
    - At most three members are fixed, `audit.browser-spec.mjs` first; the rest are named for filing.
    - Before editing a file, check it against Epic 19's diff.
  - **No member found:** the lead closes the entry `wontfix-accepted`, `reopen_if=` a browser spec fails alone on a container after the ObjectScript sweep and passes on a fresh one.
  - ADs: Conventions › Tests.
  - AC: Given the post-sweep throwaway, when each member spec runs alone, then it passes.
- [x] **DW-434** — Both specs transcribe `REASONSTATECONFLICT` behind `not.toContain`, so a server rewording leaves them green and vacuous.
  - **Fix:** a new `ui/tools/state-conflict.test.mjs`, about 25 lines. It reads `Api/Error.cls` with the `serverValue` regex and each spec's `const CONFLICT_ENVELOPE_REASON = '…'`, asserts every match exists, and asserts both constants equal the server's value, naming the file. Neither spec changes.
  - ADs: Conventions › Concurrent writes, AD-39.
  - AC: Given one word of `REASONSTATECONFLICT` changed, when `npm run test:tools` runs, then it fails naming both spec files.

### Batch d: security (DW-1782, then DW-1881, then DW-1307)

- [ ] **DW-1782** — `Step.Target` stores `TargetOf(input)` raw. A declared secret the model sends as `id` therefore reaches the poll, the transcript copy and the card. The ledger row is already marked.
  - **Red first:** a new `Test/TurnConversation.cls` method next to `:242`.
    - The scripted model sends `permissions_users_password` twice: once with `{"id": V, "Password": V}`, and once with `{"id": <an account>, "Password": V2}`.
    - Assert that step 1's target in the poll view is `[redacted]` and the view's JSON lacks V.
    - Assert that `GET /conversation/:id` and `Test.Ledger.StepText` lack V.
    - Assert that step 2's target is the account.
  - **Fix:**
    - Add `Dispatch.StepTarget(pInput, pSecretNames)`: it answers `TargetOf`, or `Log.#REDACTED` when `Ledger.CarriesSecretValue` holds. It is the one home; `TargetOf` stays raw for the ledger.
    - Use it in `AnswerOne` after `:220`.
    - In `Loop.cls`, compute one `tRunningTarget` for `:559`, `:569` and `:585`, and use the same call at `:514` and `:531`, with `SecretNamesOf`.
    - `agent-ledger.browser-spec.mjs` already sends this call (`:163`). After the reply, assert the card label reads `permissions.users.password [redacted]` and the panel's text lacks the secret.
  - Files: `Kernel/Agent/Dispatch.cls`, `Kernel/Agent/Loop.cls`, `Test/TurnConversation.cls`, `ui/browser/agent-ledger.browser-spec.mjs`. ADs: AD-35, AD-33, AD-41, AD-46, AD-3, Conventions › Secrets.
  - AC: Given the model sends a declared secret's value as a tool call's `id`, when the turn runs, then the step's target reads `[redacted]` in the poll, the stored transcript and the panel's card, and the value appears in none of them.
- [ ] **DW-1881** — The service arm splits entries on `|` only and judges roles by name.
  - **Red first:** a direct table of `GrantsPrivilegeByEffect("service", …)` rows in `Test/ServiceUpdate.cls`. The rows are the matrix's: `%Manager` and `%Operator` with `|` (1), kernel-level `10.0.0.9:%All` (1), the held classic entry (0), `%Developer` (0), and `["10.0.0.6:%All","10.0.0.7"]` against held `10.0.0.6:%All` (0).
  - **Fix:**
    - Move the spelling rule into the kernel as `Prohibited.EntryParts`, and have `ServiceRules.EntryParts` delegate to it. Prohibited names no Area class.
    - `AddressGrantsPrivilege` parses both the held and the payload entries with it, and judges each added role with `RoleGrantsAdministrativePrivilege`.
    - Delete `IsPrivilegedRole` if no caller remains.
    - `Test/ServiceEdit.cls:165`'s control role `%Operator` becomes `%Developer`.
  - Files: `Kernel/Proposal/Prohibited.cls`, `Area/Permissions/ServiceRules.cls`, `Test/ServiceUpdate.cls`, `Test/ServiceEdit.cls`. ADs: AD-10, AD-8, AD-53, AD-16.
  - AC: Given an agent proposal that gives a service address `%Manager` in the `|` spelling, or `%All` in the classic `address:roles` spelling, when it is minted, then it takes the destructive treatment with the privileged consequence (`Mint.CONSEQUENCEPRIVILEGED`). A role the target already gives that address, in either spelling, is not counted as added.
- [ ] **DW-1307** — The class header and Story 5.4's AC5 promise a log sweep. `TestNoKeyReachesTheLedger` sweeps no log.
  - **Fix:**
    - For each outcome, take `SslSinks.LogOffset()` before `Drive`.
    - After the writes, assert `SslSinks.Flush(tOffset)`, then assert `LogSince(tOffset)` lacks `CANARYMARK`.
    - Header line 4 becomes: "and the console log (`messages.log`) lines written over each turn are swept for it."
  - Files: `Test/TurnSecretResidue.cls`. ADs: AD-35, Conventions › Secrets.
  - AC: Given a completed turn and a failed turn, when the sweep runs, then the `messages.log` lines written over each turn hold no canary. A change that logs the key reddens the sweep.

### Review Findings (batch a)

Code review 2026-10-01 of `a0c415b7..98e71205`: four layers, tier `full-opus`. 25 raw findings make 5 entries, all low; none high or medium. Rule 3: exempt (build pipeline). Checked: the timings are byte-identical to a fresh `refresh --run 36910157178`; `ci-shards.mjs` and `ci-runner.mjs` take the shard count as a parameter; the job-name mutation was re-applied, went red, and was reverted.

- [x] [Review][Patch] The README says both long suites run across three containers [README.md:442]
- [x] [Review][Patch] The memlog's DW-1901 entry says four legs prevent wall-time growth; they cut it once [.memlog.md:301]
- [x] [Review][Patch] The checkout split test's title says "as CI runs them", but its literal counts tie to nothing in `ci.yml` [ui/tools/ci-shards.test.mjs:90]
- [x] [Review][Patch] Verification reports the `assign` estimate of 26.5 min as "Observed", which reads as a measurement [spec Verification › Batch a]
- [x] [Review][Defer] Operational Envelope › Build and CI lists the client unit tests as container-run and never introduces the browser specs [ARCHITECTURE-SPINE.md:1050] — deferred: the subject list predates this diff, and the spine is contended with Epic 19 (add-only); DW-1904 `wontfix-accepted`.

Rejected:

- `false`: `epics.md:5670` and `epic-dependencies.yaml:181` say three shards. Both are Story 13.5's history, and the binding row (Stack › CI) is amended.
- `low`: comments hard-code `k/4` and `k/3`. The Fix asks for `k/4` (spec-bound).
- `low`: the AC sets no wall-time target. The fix would edit the spec; the lead reports the longest leg.
- `false`: the browser reshuffle goes unrecorded. `refresh --run` rewrites both suites as the Fix asks, and Verification records 134 spec-file timings and the three-leg estimate.
- `low`: there is no guidance for a red caused by the new split. The fix would edit the spec; Conventions › Tests already makes such a red a coupling defect.
- `maybe-false`: the concurrent-job cap queues legs when two runs overlap. The plan is unverified, all 13 jobs of run 36923461500 started within 2 s, and two runs of 12 jobs already exceeded 20. At most low.
- `low`: a triage row says the lead edits were "applied with this commit", but they landed in `98e71205`. The fix would edit the spec; `resolved-by` should cite `98e71205`.
- `low`: the triage log counts one finding twice. The fix would edit the spec.
- `false`: `CLAUDE.md` still says 21 minutes. Lead edits schedules that change after the green run.
- `low`: three clauses have no mutation line of their own: no lowered `timeout-minutes`, the refreshed timings, and the roll-up's runtime check. Rule 19 asks for one mutation per AC, and the shard-matrix test carries four. The timeouts 61 and 43 are untouched (`ci.yml:139,242`), and the timings reproduce byte-identical.
- `false`: "reports the longest instance leg" has no test. That is the lead's reporting step.

### Review Findings (batch b)

Code review 2026-10-01 of `4e05a61d..6e6b8dcc`: four layers, tier `full-opus`. 32 raw findings make 3 entries, all low; none high or medium. Rule 3: exempt (test-only; the three specs drive the real throwaway). Checked: the commit holds no reproduction edit (no CDP `Fetch`, interception, font hold or poster); each fix waits on its own event; AD-2's 404 promise stays pinned (run 1625); one 600 s stall fits the 43 min browser leg.

- [x] [Review][Patch] The class header says the verified delete "posts nothing the instance would copy to `alerts.log`", but the test reads only this process's port lines [src/OcuPilot/Test/AdminPortAbsence.cls:5]
- [x] [Review][Patch] The batch b task text describes reproductions the runs did not use; say so in the Review Triage Log [spec Tasks › Batch b]
- [x] [Review][Patch] DW-1906 (lead-filed): `launchOptions`' doc comment says a spec states no launch option of its own [ui/browser.config.mjs:99]
- [x] [Review][Defer] The 404 class's comment says it "reads the alert state" [scripts/ci-throwaway.sh:264] — deferred: Epic 19 is editing the file (add-only); DW-1907 `open`, owned by this story.

Rejected:

- `false`: a reproduction edit leaked, or `:471`, `:472` and `:474` record no revert. The committed files hold no `Fetch`, interception, font hold or poster code.
- `low` (2): AC3's red cites `:617`; after the review patch it is `:620`. The line was right for the file the runs used.
- `low` (2): AC3's "pre-existing" has no run before the fix, and the number of kept stage logs is unstated. AC3 is outside the diff; batch c's DW-1204 run measures it alone.
- `false`: the `$Job` clause has no mutation of its own. Rule 19 asks one per AC (run 1625), and the re-read runs in-process (`VerifyGone` calls `Invoke`), so the clause cannot hide the port's line.
- `low` (3): a failed final `LogSince` scores as no line, and a rotation inside the window returns the whole file. `Flush` read the same range moments before; real if a red run's log shows a rotation or a read failure inside the window.
- `low`: `alerts-log.browser-spec.mjs:13-14` says only severity 3 reaches `alerts.log`, against AD-2. It predates this diff, settling it needs a probe, and run 1614 favors AD-2 (inference).
- `low`: `SslSinks`' header names only the SSL/TLS tests. Its contract is unchanged.
- `low`: `PortLines` is quadratic in lines. The text is the window since the offset.
- `low` (4): the re-read wait resolves on headers, before the list renders; round 1's can be met by round 0's second GET, ignores status, and its timeout names no round. Round 1 opens with a synchronous `eventFlag` instance round trip, nothing reads the list after round 1, and the re-read mutation shows round 0's wait is load-bearing.
- `false`: the re-read's 30 s covers the test's polling. The promise resolves on the response while the other waits run, so it times the POST and GET only, the budget the page's first load already has.
- `low` (4): `protocolTimeout` carries no comment; the fix stretches the CDP limit instead of bounding `settle`'s font wait; repeated 180 to 600 s stalls could pass the leg; a font held during a load still fails navigation. Spec-bound (Design Notes › DW-1822 and Contention); a wait that never ends throws once at 600 s, since `settle` catches nothing.
- `low`: `column-widths` and `data-table-columns` await `document.fonts.ready` under the 180 s default. No CI run shows it; real if one fails with `Runtime.callFunctionOn timed out`.
- `false` (2): the poster's ~9,000 lines skew batch c's DW-1204 run. A spec that fails on lines it did not write is a member either way (Conventions › Tests).
- `low`: `ci-timings.json` holds 15.2 s for `AdminPortAbsence`, mostly the removed `Hang`. The next refresh corrects it.
- `low`: the Auto Run Result's wording ("each item red", "follow-up pass"). The triage row below records what was run.

### Review Findings (batch c)

Code review 2026-10-01 of `66f2e716..12790813`: four layers, tier `full-opus`. 36 raw findings make 6 entries, 2 medium and 4 low; none high. Rule 3: exempt (test-only; the classes drive the real throwaway). Checked on `ocupilot-b-ci`: Agent compiles `NameIdx`, `DefaultIdx` and the IDKEY, with no bitmap, stream or subclass, so the set-aside moves every Agent node and nothing of another store; `^OcuPilotTestAgentAside` maps into OCUPILOT (AD-9); `%UnitTest.Manager` runs `OnAfterAllTests` after a failed `OnBeforeAllTests`.

- [x] [Review][Patch] A set-aside over a held copy it cannot restore must be refused, and no test pins that: without the `Quit` after the inner restore, the instance's index node is folded into the copy and AgentAside stays green [src/OcuPilot/Test/AgentFixture.cls:130]
- [x] [Review][Patch] `GovernanceFixture.Restore`'s branch that stores a snapshot back, which DW-1839's "reads back unchanged" rests on, runs in no CI test, because every snapshot there is empty [src/OcuPilot/Test/GovernanceFixture.cls:31]
- [x] [Review][Patch] AgentAside's enabled probes take the marker from a disabled default the instance holds and hand it back, rewriting that row: one class run moved a seeded row's version from 1 to 7 (run 1693) [src/OcuPilot/Test/AgentAside.cls:41]
- [x] [Review][Patch] The set-aside's cost is stated nowhere a caller reads: the seven headers omit the protected-global write, and the fixture omits that the instance serves no definition meanwhile [src/OcuPilot/Test/AgentFixture.cls:120]
- [x] [Review][Patch] ToolDispatch's header still calls the class live-safe, but each test runs with no stored policy in force [src/OcuPilot/Test/ToolDispatch.cls:8]
- [x] [Review][Patch] DW-1917 names `governance.browser-spec.mjs` as `resetGovernancePolicy`'s home; it is `preferences-reset.mjs:119`, run from `resetRememberedState` [deferred-work.md DW-1917] — a `by=cr` trailer corrects it; the Named-for-filing line is the lead's.

Rejected:

- `low` (2): a run killed between set-aside and restore leaves the definitions in the holding global, and a product start deletes the code that restores them. Spec-bound (Tasks › DW-1759); the refusal names the global and the copy is never lost.
- `low`: `SetAsideDefinitions` moves a crashed class's leftover probes aside and back instead of removing them. Removing probes first would empty AgentAside's stand-ins; the next class that clears probes removes them.
- `low`: about 20 other classes rewrite an operator's default row through `TurnWireFixture`. Pre-existing; those classes are armed for throwaways only, and the marker is put back.
- `low` (4): the frontmatter `deferred` entry keeps proposal-demo AC3's superseded cause (twice); the task text keeps DW-1759's "29" and DW-434's "vacuous"; the turnprobe Named-for-filing line runs four sentences. Each fix edits the spec, which is the lead's (triage row 9).
- `low`: `proposal-demo` still leaves `DEMO5` at `calls=1` after each green run. Filed as DW-1916.
- `false`: an earlier run's late call can land after this run forgets its tag. `DEMO5` is minted minutes into the next run, long after the earlier process ended.
- `low` (3): a failed `Snapshot` or `Clear` in `OnBeforeOneTest` skips `OnAfterOneTest` and leaves a probe device, an armed seam or a cleared store. Each is one guarded statement; real if a run's log shows either failing.
- `low`: `RemoveSeeded`'s status goes unchecked in DeviceDelete, DeviceWire and DeviceWriteGate. Pre-existing in 21 of its 81 callers, not introduced here.
- `low` (3): `Restore` puts the policy back by value with new row versions, and a crash or a concurrent save between clear and restore loses the stored policy. Spec-bound: the Fix copies `Governance.cls`'s pattern, which 20 classes share.
- `low` (2): `Flat()` answers an error string when its SQL fails, so one byte-identity assertion compares two errors. The round-trip and left-copy tests then fail on `Flat() = ""`.
- `low`: only one of `RestoreDefinitions`' three refusal branches is pinned. Rule 19 asks one per AC; the held-id branch guards ids the shared counter never reissues.
- `low` (2): `state-conflict.test.mjs` pins a closed two-file list, its `""` unescape cannot run, and the spec side unescapes only `\'`. The spec prescribes the precedent's regex; a doubled quote fails loudly, naming the parameter.
- `low`: a definition written between the checks and the move could split rows from index nodes. Theoretical: the window is milliseconds, on a throwaway.
- `low`: AgentAside catches the row marker matching too little, not too much. Rule 19 asks one per AC; an over-match also moves the install stamp the HTTP callers' gate reads (inference).
- `low`: the spec grew while flagged oversized. The added lines are its tracking sections.
- `false`: `browser-reset` is missing from batch c's checks. It runs in `prebuild`, and `node tools/browser-reset.mjs` is clean on the committed tree.

## Spec Change Log

## Review Triage Log

### 2026-10-01 — Review pass (batch a)

- verdicts: 15 findings — high 0, medium 0, low 10, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` The instance job's `name:` `/4` is pinned by no test. — The shard-matrix test now matches each shard job's `name:` against `k/<matrix length>`; mutation recorded.
  - `[low]` `[patch]` "browser-shard still runs three legs" has no `mutation:` line. — Mutation applied, red observed, line recorded.
  - `[low]` `[reject]` No test pins "no `timeout-minutes` is lower". — Holds on this diff (61 and 43 untouched, recorded); the durable guard is the 1.5x floor test, and pinning the literals would block legitimate tuning.
  - `[low]` `[reject]` "every class in exactly one leg, no empty leg" has no `mutation:` line. — A CI runtime outcome, proven by the lead's run; `checkRecords` is unchanged and loops `1..shards` (`ci-shards.mjs:240`).
  - `[low]` `[reject]` No test can tell refreshed timings from old ones. — Provenance is the file's own `source` field (run 36910157178); a freshness pin would change with every refresh.
  - `[false]` `[reject]` "the boundary reports the longest instance leg" has no test. — It is the lead's reporting step (Verification › Proof, by the lead), not code.
  - `[low]` `[patch]` `ci-shards.test.mjs:90` still splits both suites three ways. — Now splits ObjectScript four ways and browser three, retitled.
  - `[low]` `[patch]` The mutation comment says a `--shards` mutation "goes red naming the job"; that assertion names no job. — Comment corrected.
  - `[false]` `[reject]` The tests check `ci.yml` text, not a live run. — The live-run proof on the exact head is the lead's gate; an implement pass may not push.
  - `[false]` `[reject]` `checkRecords` is not exercised at four shards. — It is count-generic: the shard count is a parameter in every check and label (`ci-shards.mjs:210-240`).
  - `[low]` `[reject]` The 26.5 min estimate carries run-to-run class variance. — Residual risk only; CI settles it, against a 61 min timeout.
  - `[low]` `[reject]` `assign` splits the on-disk list (390), CI the offered list (392). — Pre-existing and documented at `ci-shards.mjs:24-27`.
  - `[false]` `[reject]` `CLAUDE.md` and the spine still say three legs. — Design Notes › Lead edits, applied with this commit.
  - `[low]` `[patch]` (same root cause as the comment row above) The mutation comment overstates. — Same fix.
  - `[false]` `[reject]` DW-1901 is ticked before CI proof. — The tick marks this pass's implementation; the CI proof and the ledger trailer are the lead's (Tasks › Execution).

### 2026-10-01 — Review pass (batch b)

- verdicts: 17 findings — high 0, medium 1, low 9, false 7, maybe-false 0
- findings:
  - `[low]` `[patch]` DW-1808's re-read wait has no mutation of its own; the recorded red comes from the answered wait. — Mutation added: every re-read held 3 s and `await reread` deleted turns round 1's `:333` red; with the wait, green under the same hold.
  - `[low]` `[patch]` proposal-demo's status assertion repeats the new wait's condition, so a stuck card fails as a bare 30 s timeout. — The wait's timeout now falls through to the assertions; a card left running reads red naming its state.
  - `[low]` `[reject]` Condition (ii) alone is green before and after the fix, so it shows nothing. — The fix edits the spec; the contrast stands for (ii) with the poster (1613 red; 1623, 1628 green), recorded under Verification.
  - `[low]` `[reject]` DW-1866's task ("fails `:103`") and its expected Verification line disagree with the runs. — The fix edits the spec; the observed lines beside them carry the measured result for the lead's DW-1866 trailer.
  - `[low]` `[defer]` `ui/browser.config.mjs:99` says a spec states no launch option of its own. — Pre-existing (`data-table-columns.browser-spec.mjs:441` already adds one) and outside batch b's files; deferred.
  - `[false]` `[reject]` DW-1866 moves the evidence from `alerts.log` and the monitor to this process's `messages.log` lines. — Spec-prescribed; the port's only emission is the caller's console line (`LogFault`, `Log.cls` `WriteToConsoleLog`), which is what `alerts.log` copies, and run 1625 shows the check catches it.
  - `[false]` `[reject]` The filter ignores severity, so it is stricter than "no alert". — AD-2's rule is that the port logs nothing for a read answered 404; stricter is the AD's own claim.
  - `[false]` `[reject]` The `$Job` filter would miss a port line another process writes. — The verified delete's re-read runs in-process (`VerifyGone` calls `Invoke`), not queued; run 1625 matched the line by `$Job`.
  - `[low]` `[reject]` A log rotation inside the window returns the whole file, where a recycled pid could match an old port line. — Needs a rotation inside a millisecond window and a reused pid that once logged a port line; a guard would add branches to a shared helper.
  - `[low]` `[reject]` (same root cause as rows 3 and 4) The literal (i) and (ii) did not reproduce, and `:103` never did. — The fix edits the spec; recorded under Verification.
  - `[false]` `[reject]` DW-1865 weakens the old ordering claim to "eventually done". — The product mints at `Loop.cls:580` before it finishes at `:605`, so the ordering never held; the Fix waits for done by design.
  - `[low]` `[patch]` (same root cause as row 2) The status and collapse assertions are implied by the wait. — Same fix as row 2.
  - `[false]` `[reject]` DW-1865's rewrite also had to set the turn state. — No bad outcome; recorded under Verification.
  - `[false]` `[reject]` DW-1808 proves a GET of the read arrived, not that the list shows the flag. — The AC's surface is "the re-read received"; round 1's start-state assertion (`:333`) reads the rendered list, and the new mutation shows it depends on the wait.
  - `[low]` `[reject]` `protocolTimeout` raises the limit for every CDP call in that browser, so a real hang costs 600 s. — Spec-bound: Design Notes accept a 600 s failure against the 43 min leg.
  - `[false]` `[reject]` A font held during a document's load stalls navigation at 30 s, which the fix does not cover. — CI's evidence (runs 36569407842, 36751724771) is a protocol timeout; the navigation path is outside DW-1822.
  - `[medium]` `[defer]` proposal-demo AC3 is red at `:617` in 2 of 5 stage runs, recorded in Verification but not filed. — Pre-existing and outside this diff; deferred to frontmatter, a DW-1204 candidate.

### 2026-10-01 — Code review (batch b)

- verdicts: 32 findings — high 0, medium 0, low 27, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` The batch b task text is not what was run. DW-1866's (i) went red only with numbered poster lines, and at `:106`; (ii) only with the poster; `:103` was never reproduced (the window is 6 to 9 ms). DW-1865's rewrite also set the turn state to `running`. DW-1822's hold took the first `.woff2` after the document's load. — The task text stays as planned; Verification › Batch b holds what was measured, and the DW-1866 trailer cites it.
  - `[low]` `[patch]` The class header claims the verified delete posts nothing for `alerts.log`; the test reads only this process's port lines. — Clause deleted. The filter itself is the Fix's: AD-2's rule is the port's, and the re-read runs in-process.
  - `[low]` `[defer]` `scripts/ci-throwaway.sh:264` says the class "reads the alert state". — Epic 19 is editing the file; DW-1907 `open` for this story.

### 2026-10-01 — Review pass (batch c)

- verdicts: 13 findings — high 0, medium 2, low 11, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The set-aside and restore never run in CI, where no definition exists, and no committed test pins the AC's byte-identical half. — New `Test/AgentAside.cls`: round trip, refusal, left copy; five mutations red (Verification › Batch c).
  - `[low]` `[patch]` DW-1839's "reads back as it was" compares empty with empty in CI and has no mutation line. — Mutation recorded: ToolDispatch without its restore is red under the override (run 1682).
  - `[low]` `[reject]` Only `proposal-demo` forgets its tag before use; the shared `nextTag` does not. — Named for filing, the spec's route for a fix in another file; CI runs each file once on a fresh container.
  - `[low]` `[patch]` The component fixtures answer with the constant the assertions exclude, so a server rewording leaves them discriminating; the new test's header says otherwise. — Header reworded: the test keeps the fixtures carrying the server's reason.
  - `[low]` `[reject]` TurnContext's and TurnWire's error-path restore is unobservable: `%UnitTest.Manager` runs `OnAfterAllTests` after a failed `OnBeforeAllTests` (`Manager.cls:1295-1306`). — Spec-prescribed (Tasks › DW-1759); the second restore finds nothing held, and `RemoveDefinition("")` removes only probes.
  - `[low]` `[reject]` `PreparedPrior` and `DisplacedDefaultId` now always read empty, so their marker-restore branches no longer run in these classes. — By design: nothing is displaced while the rows are aside; the branches sit in fixtures other classes share.
  - `[medium]` `[patch]` (same root cause as row 1) Only CI's empty case runs durably; nothing committed seeds a definition or an override. — Row 1's class seeds definitions on every run. A seeded override in CI needs state ahead of the class, outside the spine's Tests row.
  - `[low]` `[reject]` DW-1759 says 29 red; one seed gave 25, and TurnContext's other four were never red. — Recorded in Verification; the fix acts per class, and every class passes under one and two seeds.
  - `[low]` `[reject]` DW-1204's one member is not a sweep effect, its fix clears leftovers, `DEMO5` still lands after each green run, and the batch b frontmatter entry names another cause. — The spec defines a member as a file that fails alone; Verification says it is not the sweep, for the lead's trailer. The stage forgot its `DEMO5`. Correcting the batch b entry edits this spec; reported to the lead.
  - `[low]` `[patch]` (same root cause as row 4) DW-434 is a false green, not a false red, and the wire link is held elsewhere. — Same fix as row 4.
  - `[low]` `[patch]` Reproduction state left on the throwaway: `EGRESS3` to `EGRESS6` and `DEMO5`. — Their `at` times fall inside the DW-1204 pass (inference); forgotten with four late-call fragments, and the turn-provider global reads empty.
  - `[low]` `[patch]` (same root cause as row 1) The restore's refusal, the left-copy branch and the row-marker predicate have no mutation line. — Each now has one (runs 1680, 1688, 1685), and the index list too (1691).
  - `[low]` `[reject]` ToolDispatch's "Live-safe" header changed: a run cut off between clear and restore leaves no stored override. — Spec-prescribed (DW-1839 names ToolDispatch); the header says what it writes.

### 2026-10-01 — Code review (batch c)

- verdicts: 36 findings — high 0, medium 2, low 32, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` The set-aside's propagated refusal and `GovernanceFixture.Restore`'s stored-policy branch run in no CI test. — AgentAside's fourth test and the new `GovernanceRestore`; mutations 1696 and 1698 (Verification › Batch c).
  - `[low]` `[reject]` The frontmatter AC3 entry, DW-1759's "29", DW-434's "vacuous" and the turnprobe Named-for-filing line need correcting at origin. — Each edits the spec; left to the lead with DW-1917's file name, which a `by=cr` trailer corrects.

## Design Notes

**Integration ACs (Rules 1 and 2):** No consumers in this story; it introduces no service. `Dispatch.StepTarget`, `Prohibited.EntryParts` and the `AgentFixture` set-aside each have their consumers in the same batch. Consumes: none.

**Governing ADs (Rule 6):**

| Batch | ADs |
| --- | --- |
| a | Stack › CI, Operational Envelope › Build and CI, Conventions › Tests |
| b | AD-2, AD-39, Conventions › Tests |
| c | Conventions › Tests, AD-9, AD-22, Conventions › Concurrent writes, AD-39 |
| d | AD-35, AD-33, AD-41, AD-46, AD-3, Conventions › Secrets, AD-10, AD-8, AD-53, AD-16 |

No AC contradicts an AD.

**Declined:** none. Planned dispositions: every entry `resolved-by` its batch's commit. The exception is DW-1204: if its run finds no member, the lead closes it `wontfix-accepted`.

**Why the fixes take these shapes:**

- **DW-1808:** the ledger's "write and re-read" misreads `:342`. Both 200s are Apply POSTs. The fix waits for each POST's answer, and for the re-read the ledger asks for.
- **DW-1822:** the launch line is the change the orchestrator preferred. Bounding `settle`'s font wait would instead fail a 20 s to 180 s stall that the old code tolerates. A stall that never completes still fails, after 600 s (the reopen condition).
- **DW-1759:** deleting and recreating a definition renumbers it and breaks the conversations, turns and proposals that reference it. A guarded delete also rebalances the marker. So the rows are moved aside raw and come back byte-identical.
- **DW-434:** the transcribed literal is pinned across files, as `compose.test.mjs` pins ports, so a rewording reddens the tools tier.

**Contention (Epic 19, checked 2026-10-01):**

- `ui/tools/ci.test.mjs`: our edits at `:118-131` and `:2710-2765` are separate from Epic 19's roster block (about `:2091-2200`). Cleared by the dispatch.
- `a11y-structural-invariants.browser-spec.mjs:48`: a one-line change to the launch line, outside any row table. Cleared by the lead at the spec gate (the orchestrator accepted the launch-line fix, by=merge_gate, 2026-10-01). Re-check Epic 19's diff on the file before editing it.
- `CLAUDE.md` and the spine: the lead's edits, cleared by the orchestrator.
- Epic 19 touches none of the other files named here.

**Lead edits (Rule 20 and corrections at origin):**

- **With batch a's commit:**
  - Spine Stack › CI (`:913`): replace "the ObjectScript suite and the browser specs each as three shard jobs" with "the ObjectScript suite as four shard jobs and the browser specs as three". Append `[AMENDED 2026-10-01, Story 23.3, DW-1901, Rule 20: was "the ObjectScript suite and the browser specs each as three shard jobs"]`.
  - Operational Envelope › Build and CI (`:1050`): replace "each long suite split across three shards (Stack › CI)" with "the ObjectScript suite split across four shards and the browser specs across three (Stack › CI)". Append `[AMENDED 2026-10-01, Story 23.3, DW-1901, Rule 20]`.
  - `CLAUDE.md`: replace "The ObjectScript suite and the browser specs each run as three shard legs," with "The ObjectScript suite runs as four shard legs and the browser specs as three,".
- **After batch a's green run, in a follow-up docs commit:** replace `CLAUDE.md`'s "A run takes about 21 minutes (run 36376868939)." with that run's wall time and id, in the same sentence shape. Wall time is first job start to last job end, in whole minutes.
- **With batch d's commit:** AD-33, after its last paragraph: "A tool step's `target` carries the redaction mark where it holds a declared secret's value, set at write time as the ledger row's is (AD-46) [AMENDED 2026-10-01, Story 23.3, DW-1782, Rule 20]."

**User-visible changes:**

- **DW-1782 (d):** the panel's tool-call card shows `[redacted]` where the model sent a declared secret as an id, as the ledger viewer does. The progress poll and the stored transcript carry the mark too.
- **DW-1881 (d):**
  - The Services editor marks `%Manager`, `%Operator`, and any role reaching `%All` or an `%Admin_*` resource, as privileged. Its consequence line shows at the field.
  - An agent proposal giving one of them to an address, in either spelling, is destructive.
  - Changing an address that already held a role in the classic spelling no longer reads as granting that role again.

**Named for filing (outside the twelve):**

- `audit-copy-purge.browser-spec.mjs` copies the whole audit database and waits 30 s for it. That a post-sweep container (4.3M rows) outlasts the wait is (inference).
- Step and transcript rows written before the DW-1782 fix keep the value until retention purges them. No scrub is planned.
- Every DW-1204 non-member, and every member beyond the cap.
- `about-help-links`' stamp leg reds on any throwaway whose bundle was redeployed by `docker cp`, the recipe `.claude/rules/objectscript-testing.md` gives, because the installer's stamp still names the bundle it installed. Not a sweep effect.
- `data-table-columns` and `data-table` fail without the table harness `pretest:browser` builds; a bare `node --test` over the specs skips it. An invocation gap, not a product or isolation defect.
- `turnprobe-spec.mjs`'s `nextTag` restarts per process, so a spec whose last provider call lands after its own forget leaves a call record its next run on that container inherits; fixed in `proposal-demo` only (DW-1916).
- `preferences-reset.mjs:119`'s `resetGovernancePolicy` (run by `resetRememberedState`) leaves an empty-preset policy row where it found none; removed after the DW-1204 run (DW-1917).

## Verification

Slot B: MCP profile `ocupilot-slot-b`. The throwaway is `ocupilot-b-ci`: dir `/tmp/ocupilot-b-ci`, project `ocupilot-b-ci`, web 52777, super 1976, `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Never send two test calls in one message.

**Shared loop steps:**

- **Load source (loop):** `rsync -a --delete src/ /tmp/ocupilot-b-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`. Expected: 0 errors. Recompile the mutated class and every descendant before reading a mutation.
- **One class (loop):** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **One browser spec (loop):** `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`. Expected: every leg passes.
- **Checks (loop):** `uv run scripts/check-objectscript.py <changed .cls>` is clean. `bash scripts/lint-docs.sh` is clean when Markdown changed.
- **Temporary reproduction edits:** never committed. `git status --short` shows none before the commit.

**Batch a (loop):**

- Timings: `ci-timings.json` refreshed with `refresh --run 36910157178` (`33d325da`, green): 392 class and 134 spec-file timings.
- `cd ui && node tools/ci-shards.mjs assign --suite objectscript --shards 4`. Expected: four legs, the largest at most 37.6 min. Observed: 96, 97, 97 and 100 classes, an estimated 26.5 min each; browser over 3 legs an estimated 23.5 min.
- `cd ui && npm run test:tools`. Expected: green. Observed: 1,765 pass, 0 fail. `bash scripts/lint-docs.sh`: 0 issues.
- `mutation:` delete `4` from the instance matrix → `ci.test.mjs`'s shard-matrix test alone red: "instance-shard runs legs 1 to 4; it declares [1,2,3]".
- `mutation:` set the instance roll-up's `--shards 3` → the shard-matrix test red ("and over the same 4 shards"), with the three declared-gates equality tests. Both reverted; `git status --short` and `git diff --stat` unchanged.
- `mutation:` relabel the instance job `instance shard ${{ matrix.shard }}/3` → the shard-matrix test alone red: "instance-shard labels its legs k/4, the matrix's own length".
- `mutation:` delete `3` from the browser matrix → the shard-matrix test red ("browser-shard runs legs 1 to 3; it declares [1,2]"), with the timeout-floor test. Both reverted byte-identical.
- `timeout-minutes`: the diff touches none (61 and 43).
- Proof, by the lead: CI green on batch a's exact head with `instance shard 1/4` to `4/4`. Report the longest instance leg and the wall time.

**Batch b (loop):**

- Class `AdminPortAbsence`:
  - Before the fix, red under (i) and under (ii). After the fix, green, clean and under each.
  - Afterwards, `Monitor.Clear()` and `State()` reads 0.
  - Observed before the fix: (i) as written stays green (run 1609), because `messages.log` holds an identical repeated line, so the poster's lines are numbered. Numbered, (i) is red at `:106`, "the instance's state, 1 before, has not reached Alert" (run 1614; `Clear()` does not clear the monitor's memory of recent alerts, so the state was back at Warning). (ii) alone stays green (run 1610); (ii) with the poster is red on the same assertion (run 1613). `:103` was not reproduced: the delete window measures 6 to 9 ms.
  - Observed after: green clean (1617), under the poster (1618, 1619), under a burst of severe lines every 3 ms inside each window (1620 to 1622), and under (ii) with and without the poster (1623, 1624). Stage re-runs: clean (1627) and under (ii) with the poster (1628). `State()` read 0 at the end, held over 45 s.
- `mutation:` pass `0` for `pRead` at `AdminPort.cls:1100`, recompiled with `/subclasses` → `TestAVerifiedDeletePostsNoAlert` red on its last assertion, naming the `(282040) 2 [OcuPilot.Log]` adminport line for the 404, with `TestAReadAnsweredAbsentIsNotLogged`, whose own mutation it is (run 1625). Reverted, reloaded: 3/3 green (run 1626).
- Specs `proposal-demo`, `audit-events` and `a11y-structural-invariants`: each red under its hold before the fix, and green clean and under its hold after it.
  - `proposal-demo`: the first proposal-bearing poll already read `completed`, so the rewrite also sets the state to `running`, as a poll between the mint and the finish reads. AC1 red ("the read card reads done: running"), green under the rewrite after; the file 3/3 clean. Stage re-runs (5): AC1 green in every run whose log was kept; AC3, untouched here, red in 2 at `:617`, the move to the audit screen exceeding 30 s on the post-sweep throwaway. Not this batch's: a DW-1204 candidate for batch c. After the review patch, a wait that times out falls through to the assertions: AC1 green under the rewrite and the file 3/3 clean; with every proposal-bearing poll left running, AC1 red naming the card (`{"status":"running","expanded":"true"}`).
  - `audit-events`: AC2 red at `:342` ("each answered 200": `[200]`), green under the hold after; the file 4/4 clean.
  - `a11y-structural-invariants`: a font held during a document's load stalls the navigation (`Navigation timeout of 30000 ms exceeded`), so the hold takes the first `.woff2` requested after its document's load. Red: `Runtime.callFunctionOn timed out` at 182 s. Green under the hold after, 12/12 with the walk at 405 s; clean 12/12, the walk at 183 s.
  - The bundle did not move: 2.39 MB initial.
- `mutation:` delete the `done` wait → `proposal-demo` AC1 red under the rewrite ("the read card reads done: running").
- `mutation:` delete the answered and re-read waits → `audit-events` AC2 red under the hold ("each answered 200").
- `mutation:` hold every re-read of the System events list 3 s and delete only `await reread` → `audit-events` AC2 red in round 1, "each box starting as the list reads it" (`:333`); with the wait, green under the same hold. Reverted byte-identical.
- `mutation:` remove `protocolTimeout` → red under the 200 s hold (`Runtime.callFunctionOn timed out` at 182 s).

**Batch c (loop):**

- DW-1759 and DW-1839: run the seven and five classes clean, then seeded as each task says. Read the seeded rows and the override back unchanged, then remove them and read back 0.
  - Observed before the DW-1759 fix, `UpgradeSeedAgent` re-enabled and re-marked before each class: AgentState 13/13 red (run 1630), TurnContext 3/16 (1631: `:607`, `:514`, `:317`), TurnWire 1/15 (1632), AgentWire 3/18 (1633), StateRead 3/7 (1634), EgressLocal 1/2 (1635), Restraint 1/15 (1636). 25 red, not 29: TurnContext's other four stayed green. TurnContext's turn ran on the seed and left it disabled and unverified at row version 10.
  - Observed after: clean, all seven green (1642 to 1648). With the seed (1649 to 1655), and with a second, disabled definition beside it (1656 to 1662), all green, and after every class both rows' `BaseD(id)`, index nodes and ids diff byte-identical against the snapshot. A fixture probe: a second set-aside over a held copy restores it first; a restore with a third definition present is refused, the copy kept; once it is removed the restore is byte-identical. Seeds removed: 0 definitions, `$Data(^OcuPilotTestAgentAside)` 0.
  - Observed before the DW-1839 fix, under the override: DeviceDelete 3/6 red (1637), DeviceWire 1/7 (1638), DeviceWriteGate 1/3 (1639), Prohibited 1/13 (1640), ToolDispatch 1/18 (1641). After: clean, all five green (1664 to 1668); under the override, all green (1669 to 1673), the override reading back `osmgmt.devices.delete` `disabled` with an empty preset after each. Then `DeleteAllGuarded`: 0 rows.
- `mutation:` drop `SetAsideDefinitions` from `AgentState.OnBeforeAllTests` → AgentState goes 13/13 red under the seed.
  - Observed: 13/13 red under both seeds (run 1663); the enabled seed's row version moved from 1 to 5. Reverted and reloaded; `git status --short` and `git diff --stat` unchanged.
- `Test/AgentAside.cls` pins the fixture itself, which a fresh CI container never moves: a round trip reads back byte-identical, a restore over a stray `NameIdx` node is refused with the copy kept, a set-aside over a crashed class's copy restores it first, and a set-aside over a copy that cannot come back is refused with the copy and the node kept. It finds rows by SQL over the master map and indexes in the class dictionary, not from the fixture's marker or index list. Its probes are created disabled. Observed after the review patch: 4/4 green (runs 1694, 1699, 1705); with a disabled default `UpgradeSeedAgent` present, that row reads back byte-identical (1694), where the class before the patch moved its version from 1 to 7 (1693).
- `mutation:` comment out `RestoreDefinitions`' index merge → AgentAside 4/4 red, each on its byte-identical assertion (run 1701).
- `mutation:` make `SetAsideDefinitions`' left-copy branch `If 0` → `TestSetAsideRestoresALeftCopyFirst` and `TestSetAsideRefusedOverACopyThatCannotComeBack` red (1702).
- `mutation:` make `RestoreDefinitions`' refusal `If 0` → `TestRestoreRefusedWhileAnIndexNodeRemains` red on the refusal and the kept copy, with `TestSetAsideRefusedOverACopyThatCannotComeBack` (1703).
- `mutation:` set `ROWMARKER` to a store that does not exist → AgentAside 4/4 red (1704). The mutated restore left five `NameIdx` and five `DefaultIdx` nodes naming no row, removed by exact id.
- `mutation:` drop `DefaultIdx` from `AGENTINDEXES` → `TestRoundTripIsByteIdentical` red on "no Agent row or Agent index node is left in place", with the left-copy test (1697).
- `mutation:` delete the `Quit` after `SetAsideDefinitions`' inner restore → `TestSetAsideRefusedOverACopyThatCannotComeBack` alone red, on the kept copy, the stray node and the byte-identical read (1696).
- `Test/GovernanceRestore.cls` pins `GovernanceFixture.Restore` over a stored policy, which no CI snapshot holds: a read-only preset and a disabled `osmgmt.devices.delete`, snapshot, cleared and restored, read back by value and decide the key disabled again. Observed: 1/1 green (runs 1695, 1700).
- `mutation:` make `GovernanceFixture.Restore` answer `$$$OK` in place of its `GuardedApply` → `GovernanceRestore` red on the read-back and on the key decided disabled again (1698). Each mutation reverted (`shasum` and `git diff --stat` unchanged) and reloaded; the throwaway read back 0 definitions, 0 policy rows, no Agent index node and no holding global after the last.
- `mutation:` drop the clear in `DeviceDelete.OnBeforeOneTest` → DeviceDelete red under the override.
  - Observed: 3/6 red on `GOVERNANCE.DISABLED` (run 1674). Reverted and reloaded; tree unchanged.
- `mutation:` replace `ToolDispatch.OnAfterOneTest`'s `Restore(.tRows)` with `Set tSC = $$$OK` → under the override, ToolDispatch red on "and reads back as it was".
  - Observed: 1/18 red, its first test, on that assertion (run 1682); the later tests snapshot the store the first left cleared. Reverted and reloaded: 18/18 (1683), 0 policy rows.
- Stage re-runs after the reverts: AgentState 13/13 (1675), DeviceDelete 6/6 (1676), `proposal-demo` 3/3 alone.
- DW-1204: the run as the task says. Each member spec passes alone on the post-sweep container.
  - Observed: bundle rebuilt and redeployed (2.39 MB). `audit` alone 7/7 green, so not a member. The pass over the other 132 files (`/tmp/epic-23-c/full-pass.log`, `.tap`), 54 min: 581 tests, 552 pass, 29 fail, in `data-table-columns` (18), `data-table` (9), `about-help-links` (1) and `proposal-demo` (AC3, `:620`).
  - Alone: `data-table-columns` 18/18 and `data-table` 9/9 once the table harness was built (`pretest:browser`, which a bare `node --test` skips). `about-help-links` red only on its stamp leg: the page runs the redeployed `main-QCRHWLAM.js`, the installer stamped `main-XLTI77LS.js`. `proposal-demo` green, red at `:620`, green.
  - One member, `proposal-demo`, and not through the sweep. Its tag counter restarts with each run, and AC3's "yes" turn makes its last provider call after the leg's `finally` forgot `openTag`, leaving `DEMO5` at `calls=1` after every green run. The next run's first call then reads script entry 2 ("Here it is."), no navigation is proposed, and `:620` times out. Fix: `nextTag` forgets each tag before use. Green alone over a `DEMO5` leftover, and again.
- `mutation:` revert a member's own-rows predicate → that member goes red there.
  - Observed: restoring `proposal-demo`'s original `nextTag`, with a `DEMO5` leftover present → AC3 red at `:620` (`Waiting failed: 30000ms exceeded`). Restored; `git status --short` and `git diff --stat` unchanged.
- `cd ui && npm run test:tools && npm run test:components`. Expected: green.
  - Observed: tools 1,766 pass, 0 fail; components 153 files, 2,063 tests, all pass.
- `mutation:` change one word of `REASONSTATECONFLICT` → `state-conflict.test.mjs` goes red naming both specs. Edit the switches constant → red naming that file.
  - Observed: "instance" to "server" in `Error.cls` → red "differs ... in ui/src/app/areas/agent/switches.page.spec.ts and ui/src/app/areas/agent/definition-form.page.spec.ts"; "read" to "loaded" in the switches constant → red naming that file alone. Each reverted byte-identical.

**Batch d (loop):**

- Classes `TurnConversation`, `ServiceUpdate`, `ServiceEdit`, `TurnSecretResidue`, `Prohibited`, `LedgerSearch`. Specs `agent-ledger` and `service-editor`. If the latter reddens on `%Operator` now being marked privileged, switch its role to `%Developer`.
- The new DW-1782 method and the new DW-1881 rows go red before their fixes.
- `mutation:` make `StepTarget` answer `TargetOf` alone → the TurnConversation method and agent-ledger's card assertion go red.
- `mutation:` revert to `IsPrivilegedRole` → the `%Manager` and `%Operator` rows go red. Parse the held side on `|` only → the held-classic row goes red. Parse the payload side on `|` only → the classic `10.0.0.9:%All` row goes red.
- `mutation:` insert `Do ..LogRaw("residue probe", $$$ERROR($$$GeneralError, ..ApiKey))` after the key-shape gate in `Kernel/Provider/Base.cls` `Invoke` (`:185`), and recompile Base and every descendant → the new log sweep goes red. The unfixed class stays green under the same change, which shows the gap.

**Full sweep (once, before dev_complete of batch d):** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci` with no seeded state present. Expected: 0 failed, totals from `%UnitTest_Result`.

**Each batch (lead):** push the code commit alone, and wait for CI green on its exact head.

## Auto Run Result

Status: done
Blocking condition: none

**Batch c only (DW-1759, DW-1839, DW-1204, DW-434);** batch d is untouched. Test-only changes; no product code moved.

- `src/OcuPilot/Test/AgentFixture.cls`: `SetAsideDefinitions` moves every Agent row's `BaseD(id)` and the `NameIdx` and `DefaultIdx` subtrees raw into `^OcuPilotTestAgentAside`, restoring a crashed copy first. `RestoreDefinitions` removes probes, refuses while an Agent row, index node or held id remains, and otherwise merges back and kills the copy.
- AgentState, AgentWire, StateRead, Restraint, EgressLocal: set aside in `OnBeforeAllTests`, restore in `OnAfterAllTests`. TurnContext, TurnWire: set aside before `MarkedDefault`, restore on the setup error path and last in teardown.
- `src/OcuPilot/Test/AgentAside.cls` (new, review patch): pins the fixture's round trip, refusal and left-copy recovery on every CI run.
- DeviceDelete, DeviceWire, DeviceWriteGate, Prohibited, ToolDispatch: `Governance.cls`'s snapshot, clear, restore and `Matches`. DeviceWire and DeviceWriteGate gain `OnBeforeOneTest`.
- `ui/browser/proposal-demo.browser-spec.mjs`: `nextTag` forgets each tag before use (the DW-1204 member).
- `ui/tools/state-conflict.test.mjs` (new): both component specs' `CONFLICT_ENVELOPE_REASON` equal `Error.cls` `REASONSTATECONFLICT`.

**Review:** 13 findings from verification-gap and intent-alignment (blind-hunter and edge-case-hunter are disabled by config). Patched: 4 entries, medium 1 and low 3 (7 findings: the AgentAside class, DW-1839's restore mutation, the state-conflict header, the leftover probe records). Rejected: 6 low (Review Triage Log › batch c). Deferred: none. Follow-up review: false (follow-up pass; no high patched; patched: medium 1, low 3).

**Verification:** Verification › Batch c. DW-1759: 25 red with one seed before the fix (runs 1630 to 1636); all seven green clean, with one seed and with two (1642 to 1662), the rows byte-identical. DW-1839: 7 red under the override (1637 to 1641); green clean and under it (1664 to 1673), the override unchanged. DW-1204: `audit` alone 7/7; the 132-file pass (54 min) failed 29 tests in four files; one member, `proposal-demo`, fixed and 3/3 alone (also a stage re-run). DW-434: tools 1,766/1,766, components 2,063/2,063. Ten `mutation:` lines, each red and reverted byte-identical. Stage re-runs: AgentState (1675), DeviceDelete (1676), ToolDispatch (1683), AgentAside (1692). `check-objectscript`, `client-lint` and `lint-docs` clean. Throwaway read-back: 0 agent definitions, 0 policy rows, 850 `OcuPilot.Test` of 1,292 `OcuPilot.*` classes (AgentAside added), monitor state 0 (held 95 s after a second `Clear()`), `$Data(^OcuPilotTestAgentAside)` 0, no Agent index node, the turn-provider global empty.

**Residual risk:** the seven and five classes meet a definition or an override only on a non-fresh instance; CI exercises the fixture through AgentAside's own seeds. DW-1204's member is the file's own leftover, not the sweep; `about-help-links`, `data-table` and `data-table-columns` failed the pass for reasons named for filing. The batch b frontmatter entry's cause for proposal-demo AC3 (post-sweep audit volume) is superseded by Verification › Batch c.
