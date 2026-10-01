# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 16 brought the classic portal's remaining second-tier screens and actions into OcuPilot. These include the try-it console, web sessions, effective privileges, task export and background tasks, the six secondary logs and the log hub, and external language servers. It also covers the editors deferred from the contest build and the additions from the owner's surveys. A person and the agent reach each action through one operation, and nothing in the epic may break a Release 1 screen or agent write. Stories 16.1 to 16.25 are done. The last, 16.26, is the epic's burn-down. It fixes the two CI flakes found at the epic's close at their cause, so that a red CI run once again means a regression and not an unlucky shard order or timing.

## Stories

- Story 16.1: The try-it request console
- Story 16.2: Web sessions, listed and ended
- Story 16.3: Effective privileges and the permission-check tool
- Story 16.4: Task export and import
- Story 16.5: Background tasks
- Story 16.6: Broadcast a message to processes
- Story 16.7: License usage and the full dashboard
- Story 16.8: The six secondary log viewers
- Story 16.9: The unified log hub
- Story 16.10: External language servers
- Story 16.11: Start, suspend and resume the Task Manager
- Story 16.12: Remove locks - one, all of a process, all of a remote client
- Story 16.13: The service editor
- Story 16.14: The LDAP and Kerberos editor
- Story 16.15: The data-egress line
- Story 16.16: The agent audit viewer
- Story 16.17: The read-back line
- Story 16.18: Home's performance row
- Story 16.19: Impact lines on removals
- Story 16.20: Older messages.log files
- Story 16.21: Security findings, with a fix you confirm
- Story 16.22: The Guardrails page
- Story 16.23: Any table, downloaded as CSV
- Story 16.24: A try-it request, copied as curl
- Story 16.25: The external language server editor
- Story 16.26: Epic 16 burn-down

## Requirements & Constraints

### 16.26, the burn-down

- **Acceptance.** For each test that flaked, find the cause and fix it in the test, or in the code if the code is wrong. Show the fix with a run that reproduces the old failure and then passes. A green run alone proves nothing about a flake.
- **Charter.** Exactly two ledger entries carry `owner=16-26-epic-16-burn-down`. Nothing else joins: under Rule 27, a cleanup story carries only release blockers, downstream blockers and CI flakes. DW-118, the epic-level entry, is already resolved by 15.6.
- **DW-1851:** `src/OcuPilot/Test/WireSecurityRead.cls`, `TestTheLogsAreaStaysOpenWithoutTheEventLogsPair`.
  - **What the test pins.** A principal without `%Ens_EventLog:USE` still opens Logs. Its messages.log and alerts.log routes and declared reads answer 200. The event log answers 403 `AUTH.NOPRIVILEGE` and names `%Ens_EventLog:USE`.
  - **Cause.** A fresh instance has no `alerts.log` until something posts a severe line. Until then, the alerts.log route answers 404 `LOG.ABSENT`; whether the `logs.alerts` declared read in the same loop does too is not recorded. The test therefore fails whenever it runs first.
    - Measured on a freshly recreated `ocupilot-b-ci`: red in run 3, the file appeared during the sweep, and the re-run was green.
    - DW-1814 widened the window: a port read answered 404 now logs nothing, so deletes no longer post the severe line that used to create the file.
  - **Charter note: seed or tolerate an absent alerts.log.**
    - Tolerating has precedent. `Test/LogSource` and `Test/LogSourceDenial` already accept 404 `LOG.ABSENT` as an outcome, and treat it as evidence the gate admitted the caller.
    - Seeding writes a severe line, which raises the instance's alert state. Another test could then observe that state, which is a new coupling (inference).
- **DW-1867:** `ui/browser/language-server-editor.browser-spec.mjs`, AC3: "a started probe's editor states the running sentence and reads only; the probe is then stopped". This is 16.25's own spec.
  - **The failure.** It failed once, in CI run 36724473192 attempt 1 on `6de77ace`, browser shard 2/3: 3 passed, 1 failed. It passed in four other runs. The ledger does not record which assertion failed.
  - **Measured cause.** The failure was the test's own setup: the probe start answered HTTP 500 at about 10 s (spec-gate trailer on DW-1867); a probe port already held by another connection is the inference.
  - **Check the screen first.** A wait is the right fix only if the screen is right. If the editor can render editable controls while the server runs, the code is wrong and the fix goes there.
  - **Reproduce it.** One CI failure in five runs cannot be re-observed on demand. The reproduction has to force the race the fix closes (inference).

### Test discipline (binds every fix here)

- **No dependence on other tests.** A test class or spec file depends on nothing another test left on the instance. It also does not depend on which test ran before it, or on how long the instance has been up. All it may assume is the freshly installed instance every CI shard starts from.
- **Shard composition.** Shards regroup and reorder classes and files whenever the suite or its timings change. A red that depends on shard composition is a coupling defect, fixed in the test and never by pinning an item to a shard.
- **One run at a time.** Make one test-runner call at a time, never two in one message. A client-side timeout is not a failed run.
  - The `%UnitTest_Result` global is ground truth.
  - Report a class green only from a full class run, not from a single-method run.
- **Browser specs.** A browser spec runs against the deployed bundle, not the working tree. If client code changes, rebuild and redeploy before reading any result.
  - Run the story's own spec as a file: `cd ui && node --test --test-concurrency=1 browser/language-server-editor.browser-spec.mjs`, with `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` set.
  - The full browser suite runs in CI's three shards. The ObjectScript sweep stays local.
- **Mutations.** Prove each fix load-bearing with a mutation that reddens it (Rule 19). Recompile the whole package before reading an ObjectScript result.
- **Prose.** A test class header says what it pins and what it needs from the environment. Why a test was rewritten belongs in the one-paragraph commit message, not in doc comments.

## Technical Decisions

- **CI shape.**
  - The ObjectScript suite and the browser specs each run as three shard legs. Every leg runs on its own freshly installed throwaway, one class or spec file at a time.
  - Shares are assigned longest-first from `ui/tools/ci-timings.json`.
  - The `instance` and `browser` roll-ups fail unless every class and spec ran in exactly one leg and no shard executed zero tests.
  - The smoke and the admin API drift check run once, in shard 1. `concurrency` is cancel-in-progress.
- **Logs privileges (AD-8).**
  - Logs' area set is `%Admin_Operate:USE`, `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. The interoperability event log owns `%Ens_EventLog:USE` and the analytics log owns `%DeepSee_Portal:USE`.
  - The area opens when any listed screen passes its own gate. Each screen keeps its own gate, and a refused screen names its failed pair.
  - A stock instance grants `%DeepSee_Portal:USE` publicly.
- **Log sources (AD-21).** A caller names a log source from a fixed enum, never a path. An absent file is a named refusal, 404 `LOG.ABSENT`, which comes after the gate has admitted the caller.
- **Where alerts.log comes from (AD-2, AD-39).**
  - Any port failure other than a read answered 404 is logged at error severity. The instance copies such lines to alerts.log and counts them toward its alert state.
  - A port read answered 404 has found an absence and logs nothing (DW-1814). A write answered 404 is still logged.
- **External language servers (AD-8, AD-36).**
  - The list merges `CurrentlyRunning` through `LanguageServer` `ACTIVITY` as its per-row detail call, with `maxRows` 1, because the LIST lacks it. Check how the editor learns the running state before deciding where a wait belongs.
  - The screen's own pair is `%Admin_ExternalLanguageServerEdit:USE`, beside OS management's `%DB_IRISSYS:READ`.
  - Create, update and delete declare `%Admin_Manage:USE` and `%DB_IRISSYS:WRITE`. A Python server's delete also needs `%System_CallOut:USE`.
- **ObjectScript workflow.** Load and compile through the IRIS MCP tools with the slot's `server` profile, never the VS Code extension. Check with `uv run scripts/check-objectscript.py`. The pre-commit hook runs it on staged paths.

## Cross-Story Dependencies

- **Origins.** DW-1851's test is 16.8's own (AD-8, DW-1755): Logs keeps Release 1's pair set. The ledger routed it from Epic 16's log hub work (16.9). DW-1867 is 16.25's spec over 16.10's start and stop.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile and the throwaway `ocupilot-ci`: web 52776, SuperServer 1975, browser origin `http://localhost:52776`.
  - A throwaway sets `OCUPILOT_LOAD_TESTS=1`, so its start compiles `OcuPilot.Test`. A product start deletes those classes (DW-48, DW-1885).
  - Reproducing DW-1851 needs an instance with no alerts.log, which is a freshly started throwaway. A long-lived `ocupilot-ci` likely already has the file (inference).
  - Tear down only a throwaway this session started itself.
- **Slot B.** Epic 18 runs in `.worktrees/epic-18`.
  - Before editing a shared file (`ui/tools/ci-timings.json`, rosters), check it with `diff --stat` against feature and `status -s`.
  - Keep edits to shared rosters additive.
- **After 16.26.** The epic close follows: the merge gate, with the retrospective optional.
