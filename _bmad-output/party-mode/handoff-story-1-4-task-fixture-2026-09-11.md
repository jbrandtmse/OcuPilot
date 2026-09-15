# Story 1.4 hand-off: the demo task fixture and its test (2026-09-11, from the owner)

You are mid-way through rework iteration 5 of Story 1.4. Read this in full before touching
anything. It contains one owner decision, two verified defects, one inference to verify, and
a list of claims to correct at their origin. Everything below was probed live against
`server: "ocupilot-iris"` on 2026-09-11 between 07:07 and 07:20 UTC, read-only.

## The owner's decision

**The fixture does not wait for the Task Manager.** `Fixture.CreateTask` creates the task,
calls `RunNow`, releases the object, reports, and returns. The container's health check may
therefore go green before the demo task has actually run; the task suspends on its own
within about a minute of start. The **test** owns the wait, with a fresh read on every poll,
and it **fails** (never skips) if the task has not suspended inside its budget.

## What is already right

`TestDemoSeedsAnApplicationError` is green (run 314, 1.7 s). The `$$LOG^%ETN()` seed works:
HSCUSTOM error #15 at 07:07:16 reads `<DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1`.
AC12 is done. Do not touch it.

## Defect 1 (verified from source): both wait loops poll a frozen object

- `src/OcuPilot/Install/Fixture.cls:542` re-opens with `Set tTask = ..OpenTask(tId)` while
  `tTask` still holds the OREF from line 461 (`%New`/`%Save`) or line 481 (`OpenTask`).
- `src/OcuPilot/Test/Demo.cls`, `TestDemoTaskIsSuspendedAfterAnError`, the grace loop does the
  same with `Set tTask = ##class(%SYS.Task).%OpenId(tId)`.
- `irislib/%Library/Persistent.cls:727` (`%Open`, the `$$$ActiveOidSearch` branch): when the
  object is already in memory, `%Open` returns **that OREF** and calls `%Reload` **only when
  concurrency is upgraded from below 3 to above 2**. Default concurrency both times, so no
  reload, ever. The loops never see the daemon's write.
- Proof from run 314: task 1047 was created 07:07:33 (history row 1590), the daemon ran it
  and suspended it at 07:13 (history rows 1593 and 1594), the test polled roughly
  07:12:38 to 07:15:38 and took the SKIP branch, which requires `LastStarted = 0`. Runs 304
  and 306 show the identical SKIP assertion text. `TestDemoTaskIsSuspendedAfterAnError` has
  never once observed a suspended task; every "pass" was the skip.

Fix: drop the OREF before every re-open (`Set tTask = ""` then `%OpenId`), or call
`Do tTask.%Reload()`. Apply it wherever a `%SYS.Task` is polled.

## Defect 2 (strong inference, verify it): the fixture blocks the daemon while it waits

- `%SYS_Task.History`: every fixture task since 22:43 UTC on 2026-09-10 that ran at all ran at
  **Create plus six minutes**, thirteen of thirteen (22:43->22:49, 23:00->23:06, 23:11->23:17,
  23:22->23:28, 00:08->00:14, 00:20->00:26, 01:38->01:44, 02:22->02:28, 02:42->02:48,
  02:55->03:01, 03:38->03:44, 03:57->04:03, 07:07->07:13). Three more were deleted before they
  ran. The fixture's wait is five minutes. The task runs about one poll after the fixture
  stops waiting.
- The daemon was awake: tasks 1000 and 1001 (HSSYS) ran at 07:10:05 while task 1047, due
  since 07:07:33, was skipped. That is not scheduler slop.
- Likely mechanism: the fixture keeps the task OREF alive across `RunNow` (line 521) and the
  whole wait. If `RunNow` opens by id in the same process, `%Open` hands it the fixture's own
  OREF and upgrades its concurrency; that lock outlives `RunNow` because the fixture still
  references the object, and the daemon's runner cannot take the task until `CreateTask`
  returns. `%SYS.TaskSuper` ships without source, so this is an inference.
- Verify: with the owner's change the fixture releases the OREF right after `RunNow`. Either
  watch `iris_locks_list` during a run before the change, or simply observe the run landing
  within about 60 s after the change. Record the outcome at the origin either way.

**Outcome (build-auto, rework iteration 5, 2026-09-11, both routes taken): confirmed, and the
mechanism is now observed rather than inferred.**

- After the change the run lands at the Task Manager's next minute pass: run 320's probe task
  was created at 08:00:55 and suspended at 08:01:00, and a fresh throwaway container's
  production task was created at 08:29:49 and suspended at 08:30:00.
- A throwaway probe class showed the lock directly. Right after `RunNow`, the caller's task
  OREF reads `%Concurrency = 4` and the caller's process owns an exclusive lock on
  `^SYS("Task","TaskD",<id>)`. The lock lasts as long as the OREF and is gone on release.
  With the OREF held across a minute boundary (task 1052: `RunNow` at 08:05:28, released at
  08:06:14), the task still had `LastStarted = 0` at release and ran at 08:07:00, the first
  pass after release.
- One refinement to the wording above: the daemon does not run a `RunNow` request "shortly".
  It runs it at its once-a-minute pass, and every run observed this iteration landed at a
  whole minute. "Create plus six minutes" was the 300 s wait plus up to one minute to the
  next pass.

## Changes to make

1. `Fixture.CreateTask`: keep the guard, the create branch, the existing-task branch, the
   "already suspended" early quit, the `RunNow`, and the `requested a real run via
   %SYS.Task.RunNow` marker report (the test reads it). Immediately after `RunNow`,
   `Set tTask = ""`. Delete the wait loop (lines 534-555) and its three outcome reports.
   Report once that the run was requested and that the task suspends on its own shortly
   after start. Remove `TASKWAITSECONDS` and its header rationale; move the wait budget to
   the test. Rewrite the class header paragraphs that describe "the daemon's own poll cycle"
   and the 90 -> 300 widening: they were explaining a symptom this hand-off explains.
2. `Test.Demo.TestDemoTaskIsSuspendedAfterAnError`: own the wait (budget in the test's own
   parameter, 180 s is plenty), `Set tTask = ""` before every `%OpenId` in the loop, keep the
   `SuspendOnError = 1` and `FixtureRequestedTaskRun()` assertions. **Delete the SKIP branch.**
   On timeout, fail, and make the message distinguish `LastStarted = 0` (the daemon never
   ran it) from ran-but-not-suspended. Rule 19 mutation: make `DemoTask.OnTask` return
   `$$$OK` instead of throwing, confirm red, restore, confirm green, record the line.
3. Check every other `%SYS.Task` poll in the tree for the same shape (`grep -n "%OpenId"`
   under `src/OcuPilot/`, exclude `irislib/`, `irissys/`, `irisui/`, `irisdocs/`).
4. Nothing in `container-start.sh`, the health check, or `StartPath` may assert that the
   task is already suspended. Confirm by reading them, and say in the spec's AC11 Design
   Notes that the task is scheduled at install and suspends on its own within about a
   minute; that is the owner's accepted trade.
5. `.claude/rules/objectscript-basics.md`, "Collections and object identity": add the trap.
   `%OpenId` on an object already open in the process returns the in-memory OREF and does not
   reload unless concurrency is upgraded past 2; to poll for a change, drop the OREF before
   re-opening or call `%Reload()`; an OREF kept alive across a call that upgrades its
   concurrency keeps that lock alive.
6. Delete `ZZEtn.Probe.cls` from HSCUSTOM (compiled 06:48:13, still present). The spec says
   every throwaway class was deleted within the session.

## Claims to correct at their origin

Every one of these is currently written into a document someone will mine later.

- Spec, "Rework iteration 5 -- live probe results", point 4: "only afterwards did
  `TestDemoTaskIsSuspendedAfterAnError`'s further 180 s of grace catch the daemon finally
  running the task". It did not; it took the skip. The daemon ran the task, the test could
  not see it.
- Spec, "Residual risks (iteration 4)": "The Task Manager daemon on this specific container
  has not serviced any task in days". `iris_task_list` shows the system tasks ran at
  00:00-01:30 UTC today and the HSSYS tasks every five minutes all night.
- DW-46 and DW-61 (frontmatter `deferred:` for the lead to re-adjudicate): "the daemon is
  alive and did run the task" was inferred from a skip-pass; the corrected cause is Defect 1
  plus Defect 2 above. "Daemon latency growing 50 s -> 150 s -> 240 s+" was the fixture's
  own wait plus one poll, observed from different starting points.
- `Fixture.cls` header and `CreateTask` comments: "verified live: its own poll cycle, not a
  fixed short delay" and the TASKWAITSECONDS widening rationale.
- `Test/Demo.cls` class header: "the daemon on this specific long-lived container taking
  well past 90 seconds".
- Spec `## Verification`: the AC11 `mutation:` line (DW-56 already names it).

## Also in your queue, so you know we saw it

Run 314's one red, `TestExistingApplicationIsNeverModified` on "the collision is reported as
a warn naming DW-13", is the real bug you already found: `CreateWebApp` called a Kernel class
while `$NAMESPACE` was `%SYS`. Your `pOwnedByProfile` fix is the right shape. Finish it.

## Do not

- Do not widen any timeout. Do not add another skip. Do not restart the Task Manager.
- Do not re-submit a test run on a client-side timeout (DW-54); poll `iris_test_status` by
  `runIndex`, and check `iris_jobs_list` for a sibling run before each class run.
- Do not touch `irislib/`, `irissys/`, `irisui/`, `irisdocs/`. Always pass
  `server: "ocupilot-iris"`.
