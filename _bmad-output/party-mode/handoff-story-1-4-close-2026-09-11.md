Owner instruction for the Story 1.4 lead, 2026-09-11. This supersedes "continue until
complete". Read all of it before acting.

WHAT THIS IS
Story 1.4 has had 9 implement iterations, 3 code reviews (17, 7, 6 high+med; round 3
found zero HIGH), and about 64 hours. Of the 62 mediums build-auto's own reviews filed,
31 were the same defect filed by several layers and 16 were Rule 19 missing-mutation
findings created by the previous rework's test changes. The loop cannot converge under
the current rules, so I am closing it by instruction. Rules 15 and 19 will be amended
before Story 1.5; do not amend them yourself.

1. DO NOT SPAWN ANYTHING NEW while implement-9 is running. Wait for it to return
   (Rule 18). Do not TaskStop it.

2. THE PHANTOM DATABASE (DW-83). Verified by me at 16:56 UTC on the live instance:
   SYS.Database.%OpenId("/durable/iris/mgr/ocupilotprobe/") returns Mounted=1, SFN=14,
   with dirExists=0, no IRIS.DAT and no Config.Databases entry. I authorize ONE restart
   of the live IRIS, by you, only after implement-9 has returned and iris_jobs_list
   shows no OcuPilot test process and %UnitTest_Result has no unfinished instance:

       docker restart -t 120 ocupilot

   Use exactly that. NEVER `docker compose up`, `down`, or `--wait` against the live
   container: DW-75 records that its config no longer matches the compose file, so `up`
   would recreate it and run the demo install on the live volume. After the restart,
   verify the probe directory is no longer mounted, log decision_recorded for DW-83
   with this message as the authorization, and resolve DW-83. If the mount survives the
   restart, stop and tell me; do not improvise.

3. WHEN IMPLEMENT-9 RETURNS.
   - If dev_complete: harvest, run the AD verifications, then ONE code review, scoped
     to the rework-8 delta only: set baseline_commit to 73a61f2 (the round-3 patch
     commit), NOT the original iteration-1 baseline. The whole-story review has been
     done three times; it is not done again.
   - If blocked on the phantom mount: do step 2 first, then re-spawn once with the
     instruction "verify and finish rework 8's existing items only; no new scope".
     That re-spawn is the last implement spawn for this story.

4. THE CLOSE RULE. At that review gate the story closes unless a HIGH in-story finding
   remains. Every MEDIUM is dispositioned to the ledger (routed to a named story or
   escalated for the epic burndown) at review time. A Rule 19 gap on a test that
   already exists is demonstrated by the reviewer in the review pass or filed LOW; it
   is not a MED and it does not re-open the story. No rework 9. If the reviewer
   leaves the story in-progress on mediums alone, set it to review yourself and
   proceed to the smoke gate; that override is mine.

5. SMOKE AND COMMIT. Run the per-story smoke on a THROWAWAY compose project with its
   own volume, as rework 5 and 8 did, never on the live container. One test class per
   call, wait for iris_test_status to report completed, never re-submit on a client
   timeout (DW-54). Adjudicate the ledger, commit, and mark 1.4 done.

6. THEN STOP. Do not spawn the Story 1.5 plan stage. Report to me:
   - the commit SHA;
   - the run indexes of the final per-class sweep, so I can read the assertion rows;
   - the ledger entries you dispositioned at the gate, one line each;
   - anything you left out and why.

7. What you must NOT do at any point: widen a timeout, add a skip branch, edit
   irislib/ irissys/ irisui/ irisdocs/, run two test classes at once, or call any IRIS
   MCP tool without server: "ocupilot-iris".
