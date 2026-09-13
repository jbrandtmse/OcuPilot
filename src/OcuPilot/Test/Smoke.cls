/// <p>The smoke check list (Story 1.17, AD-45): what
/// <class>OcuPilot.Install.Smoke</class> reports, and -- the load-bearing half -- that a run
/// which asserted nothing is a <b>failure</b> and never a pass.</p>
/// <p><b>What this class pins and what the throwaway container pins.</b> The verdict rule, the
/// counts, the report's shape and the pending list are properties of the check list and are
/// asserted here, against synthetic check sets. Whether a real instance passes is a property of
/// an instance, and is asserted by the run <file>scripts/smoke.sh</file> makes against a
/// throwaway container, recorded in this story's <code>## Verification</code>. The one live
/// assertion here is that the real list, run against the instance this suite is executing
/// inside, executes more than zero checks -- which is what keeps the rule below from being a
/// rule about nothing.</p>
Class OcuPilot.Test.Smoke Extends %UnitTest.TestCase
{

/// <p>Zero executed checks is a failure. A gate that reports "found nothing wrong" when it
/// looked at nothing is indistinguishable, from the outside, from one that passed -- and a
/// smoke script is exactly the gate a release leans on.</p>
/// <p>Driven through the real <method>OcuPilot.Install.Smoke.Render</method> over a synthetic
/// check set, so the verdict rule under test is the shipped one.</p>
/// <p>Mutation (Rule 19): change <method>OcuPilot.Install.Smoke.Render</method>'s verdict to
/// <code>tFail = 0</code> alone -- both empty-run assertions go red while every check in the
/// real list stays green.</p>
Method TestZeroExecutedChecksIsAFailure()
{
    Kill tNone
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tNone, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 0, "an empty check list fails")
    Do $$$AssertTrue(tReport [ "executed 0 checks", "and says why, rather than reporting a pass with no evidence")
    Do $$$AssertTrue(tCounts [ "executed=0", "the counts say it too")

    Kill tSkipped
    Do ##class(OcuPilot.Install.Smoke).Note(.tSkipped, "demofixture", "skipped", "not asked for")
    Do ##class(OcuPilot.Install.Smoke).Note(.tSkipped, "signin", "skipped", "no credentials")
    Set tOk2 = ##class(OcuPilot.Install.Smoke).Render(.tSkipped, "http://fixture", .tReport2, .tCounts2)
    Do $$$AssertEquals(tOk2, 0, "a list in which every check was skipped executed nothing, so it fails too")
    Do $$$AssertTrue(tCounts2 [ "skipped=2", "the skipped checks are counted")
    Do $$$AssertTrue(tCounts2 [ "executed=0", "and none of them counts as executed")
}

/// <p>A pending check names work a later epic makes real; it is reported, and it never moves
/// the verdict in either direction. A list of nothing but pending items has executed nothing
/// and so fails.</p>
/// <p>Mutation (Rule 19): count <code>pending</code> as executed in
/// <method>OcuPilot.Install.Smoke.Render</method> -- the last assertion goes red, and a smoke
/// run that asserted nothing at all would pass on its pending list alone.</p>
Method TestPendingNeverMovesTheVerdict()
{
    Kill tChecks
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "agentwrite", "pending", "Epic 3")
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tChecks, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 1, "one passing check and one pending item is a pass")
    Do $$$AssertTrue(tCounts [ "executed=1", "with one executed check")
    Do $$$AssertTrue(tCounts [ "pending=1", "and the pending item counted separately")
    Do $$$AssertTrue(tReport [ "Epic 3", "the pending line names the epic that makes it real")

    Kill tOnlyPending
    Do ##class(OcuPilot.Install.Smoke).Note(.tOnlyPending, "agentwrite", "pending", "Epic 3")
    Set tOk2 = ##class(OcuPilot.Install.Smoke).Render(.tOnlyPending, "http://fixture", .tReport2, .tCounts2)
    Do $$$AssertEquals(tOk2, 0, "a list of nothing but pending items executed nothing")
}

/// <p>An outcome outside the four this class writes is counted as a <b>failure</b>, not as
/// nothing. Counted as nothing it lowered the executed count silently and could never fail the
/// run, which is the vacuous pass this class exists to make impossible -- and the empty-outcome
/// case is why the check is <code>$ListFind</code> rather than the <code>[</code> operator,
/// which reports every string as containing <code>""</code>.</p>
/// <p>Mutation (Rule 19): delete the <code>$ListFind</code> guard from
/// <method>OcuPilot.Install.Smoke.Render</method> -- both arms below go red while every other
/// assertion in this class stays green.</p>
Method TestAnUnknownOutcomeIsAFailureAndNeverNothing()
{
    Kill tChecks
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "shell", "passs", "a mistyped outcome")
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tChecks, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 0, "a check whose outcome is not one of the four fails the run")
    Do $$$AssertTrue(tCounts [ "failed=1", "and is counted as a failure: " _ tCounts)

    Kill tEmpty
    Do ##class(OcuPilot.Install.Smoke).Note(.tEmpty, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tEmpty, "shell", "", "no outcome at all")
    Set tOk2 = ##class(OcuPilot.Install.Smoke).Render(.tEmpty, "http://fixture", .tReport2, .tCounts2)
    Do $$$AssertEquals(tOk2, 0, "and so does an empty one")
    Do $$$AssertTrue(tCounts2 [ "failed=1", "counted the same way: " _ tCounts2)
}

/// <p>One failed check fails the run, whatever else passed, and the report names it.</p>
Method TestOneFailedCheckFailsTheRun()
{
    Kill tChecks
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "shell", "fail", "the shell answered HTTP 503")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "deeplink", "pass")
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tChecks, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 0, "one failure fails the run")
    Do $$$AssertTrue(tReport [ "the shell answered HTTP 503", "and the reason is in the report")
    Do $$$AssertTrue(tCounts [ "executed=3", "every assertion made is counted")
    Do $$$AssertTrue(tCounts [ "failed=1", "including the one that failed")
    Do $$$AssertTrue(tReport [ "FAILED", "the verdict line says so")
}

/// <p>The counts are printed whether the run passed or failed. A gate that reports its size
/// only on failure cannot be told apart, on a green run, from one that looked at nothing.</p>
Method TestTheCountsArePrintedOnEveryRun()
{
    Kill tChecks
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "readiness", "pass")
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tChecks, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 1, "the run passed")
    Do $$$AssertTrue(tReport [ "executed=1", "and the report still carries its counts")
    Do $$$AssertTrue(tReport [ "PASSED", "beside the verdict")
}

/// <p>The real check list, against the instance this suite is executing inside: it executes
/// more than zero checks, it names the endpoint it addressed, and it carries the three pending
/// items with the epics that make them real.</p>
/// <p><b>The verdict is deliberately not asserted here.</b> Whether this instance passes is a
/// property of the instance -- this repository's own long-lived container was created before
/// the start hook existed and carries no demo fixtures -- and asserting it would make this
/// class red for an environment reason. The run that asserts a verdict is the one
/// <file>scripts/smoke.sh</file> makes against a throwaway container. What is asserted here is
/// that the list is not empty, which is what keeps
/// <method>TestZeroExecutedChecksIsAFailure</method> a rule about something.</p>
Method TestTheRealListExecutesSomething()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ "ocupilot-smoke:", "the report is rendered")
    Set tExecuted = +$Piece($Piece(tCounts, "executed=", 2), " ", 1)
    Do $$$AssertTrue(tExecuted > 0, "the real check list executes more than zero checks: " _ tCounts)
    Do $$$AssertTrue(tReport [ "readiness", "and the readiness check is one of them")
    Do $$$AssertTrue(tReport [ "Epic 2", "the pending list names the epic behind the per-area lists")
    Do $$$AssertTrue(tReport [ "Epic 3", "and the two the agent brings")
}

/// <p>DW-228 -- with credentials, the run signs out the pair it minted and confirms the minted
/// refresh token is refused afterwards; the <code>sign-out</code> check passes and is counted.
/// Signs in over the wire as the suite's configured test account.</p>
/// <p>Mutation (Rule 19): delete the <code>POST /logout</code> request from
/// <method>OcuPilot.Install.Smoke.CheckSignOut</method> -- the refresh is accepted and the check
/// fails. Red.</p>
Method TestSignOutEndsTheMintedPair()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     signin"), "sign-in minted a pair: " _ tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     sign-out"), "the sign-out check passed: " _ ..Line(tReport, "sign-out"))
    Set tSignOutAt = $Find(tReport, "sign-out")
    Set tReadsAt = $Find(tReport, "navigation")
    Do $$$AssertTrue((tReadsAt > 0) && (tSignOutAt > tReadsAt), "and it ran after the API reads")
}

/// <p>DW-228 -- the sign-out check runs even when an API read fails, so a failed run does not
/// leave its session live. The reads are forced to fail through
/// <class>OcuPilot.Test.SmokeReadFault</class>.</p>
Method TestSignOutRunsWhenAReadFails()
{
    Set tOk = ##class(OcuPilot.Test.SmokeReadFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 0, "a run whose reads failed fails")
    Do $$$AssertTrue(tReport [ "induced read failure", "the induced read failure is in the report")
    Do $$$AssertTrue(tReport [ ("  pass     sign-out"), "and the pair was still signed out: " _ ..Line(tReport, "sign-out"))
}

/// <p>The report line naming <var>pName</var>, for an assertion message.</p>
ClassMethod Line(pReport As %String, pName As %String) As %String
{
    For tI = 1:1:$Length(pReport, $Char(10)) {
        Set tLine = $Piece(pReport, $Char(10), tI)
        If tLine [ pName Quit
        Set tLine = ""
    }
    Quit $Get(tLine)
}

/// <p>With no credentials the sign-in check, the three reads that need its token and the
/// sign-out are each <b>skipped</b>, not passed: a run that never tried is not a run that
/// succeeded.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Install.Smoke.CheckSignOut</method>'s
/// no-pair guard -- the sign-out is noted <code>fail</code> and this goes red.</p>
Method TestNoCredentialsSkipsRatherThanPasses()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport, .tCounts)
    For tName = "signin", "instance", "namespaces", "navigation", "sign-out" {
        Do $$$AssertTrue(tReport [ ("  skipped  " _ tName), tName _ " is skipped: " _ ..Line(tReport, tName))
    }
    Do $$$AssertTrue(tReport [ "no credentials were supplied", "and the report says why")
}

}
