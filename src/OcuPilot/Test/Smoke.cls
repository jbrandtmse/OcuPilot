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

/// <p>The verdict line names every failed check, a row with an outcome outside the four among
/// them, and a passing run names its skipped checks; the counts line keeps its shape either way.</p>
/// <p>Mutation (Rule 19): restore "; the first is named above" in
/// <method>OcuPilot.Install.Smoke.Render</method>, or drop the skipped suffix -- this goes red.</p>
Method TestTheVerdictLineNamesFailedAndSkippedChecks()
{
    Kill tChecks
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "shell", "fail", "the shell answered HTTP 503")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "signin", "skipped")
    Do ##class(OcuPilot.Install.Smoke).Note(.tChecks, "wallet", "faild")
    Set tOk = ##class(OcuPilot.Install.Smoke).Render(.tChecks, "http://fixture", .tReport, .tCounts)
    Do $$$AssertEquals(tOk, 0, "the run failed")
    Do $$$AssertEquals($Piece(tReport, $Char(10), $Length(tReport, $Char(10))), "ocupilot-smoke: FAILED -- 2 check(s) failed: shell, wallet", "the verdict line names both failed checks")
    Do $$$AssertEquals(tCounts, "executed=3 passed=1 failed=2 pending=0 skipped=1", "the counts line keeps its shape")

    Kill tPassing
    Do ##class(OcuPilot.Install.Smoke).Note(.tPassing, "readiness", "pass")
    Do ##class(OcuPilot.Install.Smoke).Note(.tPassing, "signin", "skipped")
    Do ##class(OcuPilot.Install.Smoke).Note(.tPassing, "demofixture", "skipped")
    Set tOk2 = ##class(OcuPilot.Install.Smoke).Render(.tPassing, "http://fixture", .tReport2, .tCounts2)
    Do $$$AssertEquals(tOk2, 1, "a run whose only other checks were skipped passes")
    Do $$$AssertEquals($Piece(tReport2, $Char(10), $Length(tReport2, $Char(10))), "ocupilot-smoke: PASSED -- 2 check(s) skipped: signin, demofixture", "the PASSED line names the skipped checks")
    Do $$$AssertEquals(tCounts2, "executed=1 passed=1 failed=0 pending=0 skipped=2", "and the counts line keeps its shape")

    Kill tClean
    Do ##class(OcuPilot.Install.Smoke).Note(.tClean, "readiness", "pass")
    Set tOk3 = ##class(OcuPilot.Install.Smoke).Render(.tClean, "http://fixture", .tReport3, .tCounts3)
    Do $$$AssertEquals($Piece(tReport3, $Char(10), $Length(tReport3, $Char(10))), "ocupilot-smoke: PASSED", "with nothing skipped the PASSED line carries no suffix")
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
/// more than zero checks, it names the endpoint it addressed, and nothing in it is
/// <code>pending</code> -- Story 5.8 landed the last two, so the outcome has no producer left.</p>
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
    ; The `arealists` pending note is gone since Story 2.10: every area the shell gates now has a
    ; real live-list check, Logs included, so a note saying otherwise would be a false claim about
    ; the report's own coverage rather than an honest gap.
    Do $$$AssertEquals(..Line(tReport, "arealists"), "", "no area-list pending note survives, because every built area's list is a real check")
    ; Story 5.8 landed the last two: `agentwrite` and `auditmarker` are executed checks on a
    ; container carrying the demo fixture and skipped where it is absent, so nothing in the real
    ; list is `pending` any more.
    Do $$$AssertTrue(tCounts [ "pending=0", "no check in the real list is pending: " _ tCounts)
    ; Asked per line rather than as a substring of the whole report: the outcome column is
    ; right-padded to a fixed width by Render, so a scan for the padded word would go vacuously
    ; true the moment that width changed rather than red.
    Do $$$AssertTrue(..Line(tReport, "agentwrite") '[ "pending", "and the agentwrite line reports no pending outcome: " _ ..Line(tReport, "agentwrite"))
    Do $$$AssertTrue(..Line(tReport, "auditmarker") '[ "pending", "nor the auditmarker line: " _ ..Line(tReport, "auditmarker"))
}

/// <p>Story 5.8, DW-1382, and the fifth AC: the whole <code>agentwrite</code> and
/// <code>auditmarker</code> sequence, driven through the shipped check against an application the
/// instance spells in <b>mixed case</b> -- a proposal minted and confirmed, the target read back
/// enabled with the resource, one audit row carrying the proposal id, and the fixture put back
/// disabled with no resource.</p>
/// <p><code>/csp/myapp</code> folds to itself, so the container's own run proves the sequence and
/// not the resolution. This drives it against one that can tell the two apart.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Install.Smoke.ApplicationName</method> answer
/// <var>pPath</var> instead of the instance's own <code>Name</code> -- the case-preserved
/// assertion goes red while the sequence stays green, which is exactly the shape Story 5.7's two
/// defects had.</p>
Method TestTheAgentWriteCheckRunsOnACasePreservedTarget()
{
    If '..ArmMixedCase(0) Quit
    Try {
        ; Asked with the FOLDED path, which is the spelling EntityRef.Key stores and the one a
        ; check keyed off the proposal's TargetRef would carry. The answer has to be the
        ; instance's own, case preserved -- asking with the literal would compare the argument
        ; against itself and hold whatever this method did with it.
        Set tFolded = $ZConvert(##class(OcuPilot.Test.ProposalFixture).#WRITETARGETMIXEDCASE, "L")
        Do $$$AssertNotEquals(tFolded, ##class(OcuPilot.Test.ProposalFixture).#WRITETARGETMIXEDCASE, "the probe path and its fold differ, so the assertion below can fail")
        Do $$$AssertEquals(##class(OcuPilot.Test.SmokeWriteProbe).ApplicationName(tFolded), ##class(OcuPilot.Test.ProposalFixture).#WRITETARGETMIXEDCASE, "the check resolves the application by the spelling the instance stores, whatever spelling it is handed")

        Kill tChecks
        Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tChecks, "1")
        Do $$$AssertEquals(..Outcome(.tChecks, "agentwrite"), "pass", "the confirmed write executed and passed: " _ ..Reason(.tChecks, "agentwrite"))
        Do $$$AssertEquals(..Outcome(.tChecks, "auditmarker"), "pass", "and one audit row carries its proposal id: " _ ..Reason(.tChecks, "auditmarker"))
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled"), 0, "and the fixture is left disabled")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Resource"), "", "with no resource")
    } Catch ex {
        Do $$$AssertEquals(ex.DisplayString(), "", "the probe run raised")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()
}

/// <p>Story 5.8, the third AC: a repeat run executes both checks again and leaves the fixture
/// disabled with no resource, as the first did. The restore is what makes it idempotent -- without
/// it the second run finds a target already enabled, which is the state the check refuses to
/// assert against.</p>
Method TestARepeatRunExecutesAgainAndLeavesTheFixtureDisabled()
{
    If '..ArmMixedCase(0) Quit
    Try {
        Kill tFirst
        Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tFirst, "1")
        Do $$$AssertEquals(..Outcome(.tFirst, "agentwrite"), "pass", "the first run passes: " _ ..Reason(.tFirst, "agentwrite"))
        Kill tSecond
        Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tSecond, "1")
        Do $$$AssertEquals(..Outcome(.tSecond, "agentwrite"), "pass", "and so does the second: " _ ..Reason(.tSecond, "agentwrite"))
        Do $$$AssertEquals(..Outcome(.tSecond, "auditmarker"), "pass", "with its own marker row: " _ ..Reason(.tSecond, "auditmarker"))
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled"), 0, "and the fixture is disabled afterwards")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Resource"), "", "with no resource")
    } Catch ex {
        Do $$$AssertEquals(ex.DisplayString(), "", "the probe run raised")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()
}

/// <p>Story 5.8, the fourth AC: no demo opt-in and an unowned fixture are each <code>skipped</code>
/// with the reason naming the cause -- never <code>pending</code>, never <code>fail</code>, and
/// never a write. DW-1402's rule: the reason travels even where the count cannot.</p>
/// <p>Both arms here return before the target is resolved, so "never a write" is free of them.
/// The arm where it is not is the turn slot's, pinned by
/// <method>TestASkippedWriteCheckLeavesTheInstanceAlone</method>.</p>
/// <p>Mutation (Rule 19): note <code>fail</code> instead of <code>skipped</code> on either arm of
/// <method>OcuPilot.Install.Smoke.CheckAgentWrite</method>'s skip -- this goes red and the
/// verdict of every container without the fixture flips.</p>
Method TestTheWriteChecksSkipWhereTheEnvironmentCannotCarryThem()
{
    Kill tNoDemo
    Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tNoDemo, "0")
    For tName = "agentwrite", "auditmarker" {
        Do $$$AssertEquals(..Outcome(.tNoDemo, tName), "skipped", tName _ " is skipped with no demo opt-in")
        Do $$$AssertTrue(..Reason(.tNoDemo, tName) [ "demo opt-in", tName _ "'s reason names the cause: " _ ..Reason(.tNoDemo, tName))
    }

    Kill tUnowned
    Do ##class(OcuPilot.Test.SmokeUnownedProbe).RunWriteChecks(.tUnowned, "1")
    For tName = "agentwrite", "auditmarker" {
        Do $$$AssertEquals(..Outcome(.tUnowned, tName), "skipped", tName _ " is skipped on a fixture this install did not create")
        Do $$$AssertTrue(..Reason(.tUnowned, tName) [ "did not create", tName _ "'s reason names the cause: " _ ..Reason(.tUnowned, tName))
    }
}

/// <p>Story 5.8: a target that is not in the state its install creates is a <code>fail</code>
/// naming which half, not a pass. A write over an application already enabled with the resource
/// changes nothing, and every assertion after it would hold of a write that did nothing -- which
/// is the vacuous pass the whole check list exists to make impossible.</p>
Method TestAWriteThatWouldChangeNothingFailsNamingIt()
{
    ; Armed ENABLED, which is the state the check refuses to assert against: the write would then
    ; change the resource alone, and every assertion after it would hold of a write that left the
    ; application reachable exactly as it found it.
    If '..ArmMixedCase(1) Quit
    Try {
        Kill tChecks
        Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tChecks, "1")
        Do $$$AssertEquals(..Outcome(.tChecks, "agentwrite"), "fail", "a write that would change nothing fails")
        Do $$$AssertTrue(..Reason(.tChecks, "agentwrite") [ "disabled, no-resource state", "naming which half: " _ ..Reason(.tChecks, "agentwrite"))
        Do $$$AssertEquals(..Outcome(.tChecks, "auditmarker"), "fail", "and so does the marker, which would account for nothing")
        ; And the fixture is put back, which is what the failure's own reason promises ("it is put
        ; back and the next run asserts against it"). This is the path that needs the restore most:
        ; a container whose fixture has drifted is exactly the run that fails here, and a restore
        ; that happened only on the success path would leave it failing on every run after this one.
        ;
        ; Mutation (Rule 19): move CheckAgentWrite's RestoreWriteTarget call inside the Try, after
        ; its last Note -- these two go red while every other smoke assertion stays green, because
        ; an early Quit then skips the restore. Guarding the call on `tProblem = ""` instead does
        ; NOT falsify it and is not the mutation: tProblem is never set on the paths that Quit
        ; early, so $Get answers "" and the guard passes.
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled"), 0, "and the fixture is left disabled even though the check failed")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Resource"), "", "with no resource")
    } Catch ex {
        Do $$$AssertEquals(ex.DisplayString(), "", "the probe run raised")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()
}

/// <p>Story 5.8: the two seams <class>OcuPilot.Test.SmokeWriteProbe</class> overrides answer, in
/// the <b>shipped</b> class, what AD-25's own fixture is. Every other test of these checks runs
/// through the probe's overrides, and the one test that runs the real list passes demo
/// <code>"0"</code> and so skips before reaching either -- so without this the shipped bodies could
/// name a fixture that does not exist and only <code>scripts/smoke.sh</code> in CI would notice.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Install.Smoke.WriteTarget</method> answer any other
/// path -- this goes red naming both.</p>
Method TestTheShippedCheckNamesTheDemoFixture()
{
    Do $$$AssertEquals(##class(OcuPilot.Install.Smoke).WriteTarget(), ##class(OcuPilot.Install.Fixture).#APPPATH, "the shipped check writes to AD-25's own demo fixture")
    Do $$$AssertEquals(##class(OcuPilot.Install.Smoke).WriteTargetOwned(), ##class(OcuPilot.Install.Fixture).WebAppOwnedByProfile(""), "and asks the install's own inventory whether it created it")
}

/// <p>Create the mixed-case probe application <var>pEnabled</var> with no resource, and answer
/// whether it is there. Answers 0 on an instance the fixture refuses to write to -- one without
/// its arming variable -- so the tests above assert nothing rather than failing there.</p>
Method ArmMixedCase(pEnabled As %Boolean) As %Boolean [ Private ]
{
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureMixedCaseWriteTarget(, .tCreated, pEnabled)
    If $$$ISERR(tSC) || 'tCreated {
        ; Said out loud rather than returned silently: a test method that asserts nothing reads as
        ; a pass, and the three below assert nothing on an instance the fixture refuses. The class
        ; itself still runs everywhere -- its other checks need no principal.
        Do ..LogMessage("the mixed-case probe application was not created (" _ $Select($$$ISERR(tSC): $System.Status.GetErrorText(tSC), 1: "the fixture answered no creation") _ "), so this test asserted nothing; scripts/ci-throwaway.sh sets the variable it needs")
        Quit 0
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled"), ''pEnabled, "the probe application is armed in the state this test needs")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Resource"), "", "and with no resource")
    Quit 1
}

/// <p>The value of <var>pField</var> noted for check <var>pName</var> in the check set
/// <var>pChecks</var>, or <code>""</code> when that set holds no such check.</p>
ClassMethod Noted(ByRef pChecks, pName As %String, pField As %String) As %String [ Private ]
{
    Set tValue = ""
    For tI = 1:1:+$Get(pChecks) {
        If $Get(pChecks(tI, "name")) '= pName Continue
        Set tValue = $Get(pChecks(tI, pField))
        Quit
    }
    Quit tValue
}

/// <p>The outcome noted for <var>pName</var>, or <code>""</code>.</p>
ClassMethod Outcome(ByRef pChecks, pName As %String) As %String [ Private ]
{
    Quit ..Noted(.pChecks, pName, "outcome")
}

/// <p>The reason noted for <var>pName</var>, or <code>""</code> -- what an assertion message
/// quotes when the outcome is not the one expected.</p>
ClassMethod Reason(ByRef pChecks, pName As %String) As %String [ Private ]
{
    Quit ..Noted(.pChecks, pName, "reason")
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

/// <p>DW-228 -- a refresh after sign-out that answers anything but 401 fails the check, because
/// only a 401 shows the refresh token was refused. The refresh is answered 500 through
/// <class>OcuPilot.Test.SmokeRefreshFault</class>.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Install.Smoke.CheckSignOut</method>'s
/// <code>'= 401</code> arm -- the check passes on a 500 and this goes red.</p>
Method TestSignOutFailsWhenTheRefreshIsNotRefused()
{
    Do ##class(OcuPilot.Test.SmokeRefreshFault).Arm(500, "")
    Set tOk = ##class(OcuPilot.Test.SmokeRefreshFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do ##class(OcuPilot.Test.SmokeRefreshFault).Disarm()
    Do $$$AssertEquals(tOk, 0, "a run whose refresh was not refused fails")
    Do $$$AssertTrue(tReport [ ("  fail     sign-out"), "the sign-out check failed: " _ ..Line(tReport, "sign-out"))
    Do $$$AssertTrue(..Line(tReport, "sign-out") [ "HTTP 500", "naming the answer it got")
}

/// <p>DW-228 -- a refresh after sign-out that is accepted fails the check, and the pair that
/// refresh minted is signed out before it does. The refresh is answered 200 with a pair through
/// <class>OcuPilot.Test.SmokeRefreshFault</class>, which counts the logouts.</p>
/// <p>Mutation (Rule 19): delete the second <code>POST /logout</code> from
/// <method>OcuPilot.Install.Smoke.CheckSignOut</method>'s accepted-refresh branch -- one logout is
/// counted and this goes red.</p>
Method TestAnAcceptedRefreshIsSignedOutBeforeTheCheckFails()
{
    Do ##class(OcuPilot.Test.SmokeRefreshFault).Arm(200, "{""access_token"":""smoke-stub-access"",""refresh_token"":""smoke-stub-refresh""}")
    Set tOk = ##class(OcuPilot.Test.SmokeRefreshFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Set tLogouts = ##class(OcuPilot.Test.SmokeRefreshFault).Logouts()
    Do ##class(OcuPilot.Test.SmokeRefreshFault).Disarm()
    Do $$$AssertEquals(tOk, 0, "a run whose refresh was accepted fails")
    Do $$$AssertTrue(..Line(tReport, "sign-out") [ "still accepted", "the sign-out check names the accepted refresh: " _ ..Line(tReport, "sign-out"))
    Do $$$AssertEquals(tLogouts, 2, "the minted pair and the pair the refresh returned were both signed out")
}

/// <p>Story 2.5 AC8 -- with credentials, the <code>webapplications</code> check reads the web
/// applications list's first row through the screen-read route and passes, before the sign-out.
/// Signs in over the wire as the suite's configured test account, which must hold
/// <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: request <code>webapp.nosuch</code> in
/// <method>OcuPilot.Install.Smoke.CheckAreaLists</method> -> the route answers 404 and the check
/// fails.</p>
Method TestTheWebApplicationsListIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     webapplications"), "the web applications list is read: " _ ..Line(tReport, "webapplications"))
    Set tListAt = $Find(tReport, "webapplications")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.7 AC8 -- with credentials, the <code>ssl</code> check reads the SSL/TLS configurations
/// list's first row through the screen-read route and passes, before the sign-out. The configured
/// test account must hold <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.SSLLISTTOOL</parameter> to
/// <code>security.nosuch</code> -> the route answers 404 and the check fails.</p>
Method TestTheSslListIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     ssl"), "the SSL/TLS configurations list is read: " _ ..Line(tReport, "  ssl"))
    Set tListAt = $Find(tReport, "  pass     ssl")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.10 -- with credentials, the <code>audit</code> check reads the audit database
/// viewer's first row through the screen-read route and passes, before the sign-out. The configured
/// test account must hold <code>%Admin_Secure:USE</code>, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:READ</code>. It is the one live check that crosses the port's async path
/// (AD-26).</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.AUDITLISTTOOL</parameter> to
/// <code>logs.nosuch</code> -> the route answers 404 and the check fails.</p>
Method TestTheAuditListIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     audit"), "the audit database viewer is read: " _ ..Line(tReport, "  audit"))
    Set tListAt = $Find(tReport, "  pass     audit")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 6.2 -- with credentials, the <code>roles</code>, <code>resources</code> and
/// <code>services</code> checks each read their list's first row through the screen-read route and
/// pass, before the sign-out. The configured test account must hold <code>%Admin_Secure:USE</code>
/// and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.SERVICELISTTOOL</parameter> to
/// <code>permissions.nosuch</code> -&gt; the route answers 404 and the services check fails.</p>
Method TestThePermissionsListsAreLiveChecks()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Set tSignOutAt = $Find(tReport, "sign-out")
    For tName = "roles", "resources", "services" {
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName), "the " _ tName _ " list is read: " _ ..Line(tReport, "  " _ tName))
        Set tListAt = $Find(tReport, "  pass     " _ tName)
        Do $$$AssertTrue((tListAt > 0) && (tSignOutAt > tListAt), "and it ran before the pair was signed out")
    }
}

/// <p>Story 6.3 -- with credentials, the <code>x509</code>, <code>ldap</code> and <code>wallet</code>
/// checks each read their list's first row through the screen-read route and pass, before the
/// sign-out. The configured test account must hold <code>%Admin_Secure:USE</code>,
/// <code>%Admin_Wallet:USE</code> and <code>%DB_IRISSYS:READ</code>, and the instance needs the demo
/// fixture, whose X.509 credential and wallet collection give those two lists a row.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.WALLETLISTTOOL</parameter> to
/// <code>security.nosuch</code> -&gt; the route answers 404 and the wallet check fails.</p>
Method TestTheSecurityListsAreLiveChecks()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Set tSignOutAt = $Find(tReport, "sign-out")
    For tName = "x509", "ldap", "wallet" {
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName), "the " _ tName _ " list is read: " _ ..Line(tReport, "  " _ tName))
        Set tListAt = $Find(tReport, "  pass     " _ tName)
        Do $$$AssertTrue((tListAt > 0) && (tSignOutAt > tListAt), "and it ran before the pair was signed out")
    }
}

/// <p>Story 6.4 -- with credentials, the five OAuth 2.0 tab checks each read their tab through the
/// screen-read route and pass, before the sign-out. The configured test account must hold the three
/// <code>%Admin_OAuth2_*</code> resources, <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>; the instance needs no OAuth 2.0 object, because each check passes on
/// zero rows or one.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.OAUTHSERVERTOOL</parameter> to
/// <code>security.nosuch</code> -&gt; the route answers 404 and the oauthserver check fails.</p>
Method TestTheOAuthTabsAreLiveChecks()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Set tSignOutAt = $Find(tReport, "sign-out")
    For tName = "oauthdescriptions", "oauthclients", "oauthresourceservers", "oauthserver", "oauthserverclients" {
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName _ $Char(10)), "the " _ tName _ " tab is read: " _ ..Line(tReport, "  " _ tName))
        Set tListAt = $Find(tReport, "  pass     " _ tName)
        Do $$$AssertTrue((tListAt > 0) && (tSignOutAt > tListAt), "and it ran before the pair was signed out")
    }
}

/// <p>Story 6.4 -- an OAuth 2.0 tab check passes on a 200 answering zero rows, and fails on a body with
/// no <code>rows</code> array or with more than one row.
/// Drives <class>OcuPilot.Test.SmokeListFault</class>.</p>
/// <p>Mutation: require exactly one row of the OAuth 2.0 checks in
/// <method>OcuPilot.Install.Smoke.CheckAreaLists</method> -&gt; the empty-rows pass assertions go
/// red.</p>
Method TestAnOAuthTabCheckPassesOnZeroOrOneRow()
{
    For tCase = $ListBuild("{""rows"":[]}", "pass"), $ListBuild("{""rows"":[{""Name"":""one""}]}", "pass"), $ListBuild("{""rows"":[{""Name"":""one""},{""Name"":""two""}]}", "fail"), $ListBuild("<!doctype html><html></html>", "fail") {
        Do ##class(OcuPilot.Test.SmokeListFault).Arm(200, $List(tCase, 1))
        Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "1", .tReport, .tCounts)
        Do ##class(OcuPilot.Test.SmokeListFault).Disarm()
        For tName = "oauthdescriptions", "oauthclients", "oauthresourceservers", "oauthserver", "oauthserverclients" {
            Set tWanted = "  " _ $List(tCase, 2) _ $Justify("", 9 - $Length($List(tCase, 2))) _ tName _ $Select($List(tCase, 2) = "pass": $Char(10), 1: " -- ")
            Do $$$AssertTrue(tReport [ tWanted, "a 200 carrying " _ $List(tCase, 1) _ " makes " _ tName _ " " _ $List(tCase, 2) _ ": " _ ..Line(tReport, "  " _ tName))
        }
    }
}

/// <p>Story 6.1 -- with credentials, the <code>webapp.restapis</code> check reads the REST API
/// explorer's first row through the screen-read route and passes, before the sign-out. The configured
/// test account must hold <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.RESTAPILISTTOOL</parameter> to
/// <code>webapp.nosuch</code> -&gt; the route answers 404 and the check fails.</p>
Method TestTheRestApiExplorerIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     webapp.restapis"), "the REST API explorer is read: " _ ..Line(tReport, "webapp.restapis"))
    Set tListAt = $Find(tReport, "  pass     webapp.restapis")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.11 -- with credentials, the <code>messageslog</code> check reads a bounded page of the
/// instance's own <file>messages.log</file> through <code>GET /logs/messages</code> and passes,
/// before the sign-out. The configured test account must hold <code>%Admin_Operate:USE</code>. It is
/// the one live check outside <method>OcuPilot.Install.Smoke.CheckAreaLists</method>, because the
/// endpoint has no screen and so no tool identifier to read through.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.MESSAGESLOGPATH</parameter> to
/// <code>/logs/nosuch?maxBytes=4096</code> -&gt; the route answers 404 and the check fails.</p>
Method TestTheMessagesLogIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     messageslog"), "the console log page is read: " _ ..Line(tReport, "messageslog"))
    Set tListAt = $Find(tReport, "  pass     messageslog")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.11 -- an answer that is not a page fails the <code>messageslog</code> check and the
/// run: a 200 carrying no <code>lines</code> array, an empty body, an HTML page, and a 403.</p>
/// <p><b>Why the passing leg above is not enough.</b> It runs against a healthy instance, so it
/// stays green with every guard in the check deleted -- which is how a live check decays into an
/// always-pass. This is the leg that holds the guards, in the shape
/// <method>TestAScreenReadWithoutOneRowFailsTheListCheck</method> holds the seven area lists'.</p>
/// <p>Mutation: delete the <code>tLines &lt; 0</code> refusal from
/// <method>OcuPilot.Install.Smoke.CheckMessagesLog</method> -&gt; the first three bodies pass and
/// their legs go red. Delete the non-200 refusal -&gt; the 403 leg goes red.</p>
Method TestAnAnswerThatIsNotAPageFailsTheMessagesLogCheck()
{
    For tCase = "200:{}", "200:", "200:<!doctype html><html></html>", "403:{""error"":""forbidden""}" {
        Set tStatus = $Piece(tCase, ":", 1)
        Set tBody = $Piece(tCase, ":", 2, *)
        Do ##class(OcuPilot.Test.SmokeListFault).ArmLog(tStatus, tBody)
        Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
        Do ##class(OcuPilot.Test.SmokeListFault).DisarmLog()
        Do $$$AssertTrue(tReport [ ("  fail     messageslog"), tCase _ ": fails the console log check: " _ ..Line(tReport, "messageslog"))
        Do $$$AssertEquals(tOk, 0, tCase _ ": and the run does not pass")
    }

    ; The same fixture, armed with a page: it passes. So the four failures above are the guards
    ; and not the fixture standing in the way of every answer.
    Do ##class(OcuPilot.Test.SmokeListFault).ArmLog(200, "{""source"":""messages"",""lines"":[""a line""]}")
    Set tOkPage = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tPageReport, .tPageCounts)
    Do ##class(OcuPilot.Test.SmokeListFault).DisarmLog()
    Do $$$AssertTrue(tPageReport [ ("  pass     messageslog"), "a 200 carrying a lines array passes (run ok=" _ tOkPage _ "): " _ ..Line(tPageReport, "messageslog"))
}

/// <p>Story 2.12 -- with credentials, the <code>applicationerrors</code> check reads the
/// application error log's namespaces level through <code>GET /logs/errors/namespaces</code> and
/// passes, before the sign-out. The configured test account must hold
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>. It is the second live check
/// outside
/// <method>OcuPilot.Install.Smoke.CheckAreaLists</method>, because this screen declares no read and
/// so has no tool identifier to read it through.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.APPLICATIONERRORSPATH</parameter> to
/// <code>/logs/errors/nosuch</code> -&gt; the route answers 404 and the check fails.</p>
Method TestTheApplicationErrorsIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     applicationerrors"), "the application error log is read: " _ ..Line(tReport, "applicationerrors"))
    Set tListAt = $Find(tReport, "  pass     applicationerrors")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.12 -- an answer that is not a page fails the <code>applicationerrors</code> check and
/// the run: a 200 carrying no <code>rows</code> array, an empty body, an HTML page, and a 403.</p>
/// <p><b>Why the passing leg above is not enough.</b> It runs against a healthy instance, so it
/// stays green with every guard in the check deleted -- which is how a live check decays into an
/// always-pass. An <b>empty</b> rows array is asserted to pass in the same run, because an instance
/// that has never faulted records no application errors and that is a correct answer.</p>
/// <p>Mutation: delete the <code>tRows &lt; 0</code> refusal from
/// <method>OcuPilot.Install.Smoke.CheckApplicationErrors</method> -&gt; the first three bodies pass
/// and their legs go red. Delete the non-200 refusal -&gt; the 403 leg goes red.</p>
Method TestAnAnswerThatIsNotAPageFailsTheApplicationErrorsCheck()
{
    For tCase = "200:{}", "200:", "200:<!doctype html><html></html>", "403:{""error"":""forbidden""}" {
        Set tStatus = $Piece(tCase, ":", 1)
        Set tBody = $Piece(tCase, ":", 2, *)
        Do ##class(OcuPilot.Test.SmokeListFault).ArmErrors(tStatus, tBody)
        Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
        Do ##class(OcuPilot.Test.SmokeListFault).DisarmErrors()
        Do $$$AssertTrue(tReport [ ("  fail     applicationerrors"), tCase _ ": fails the application error log check: " _ ..Line(tReport, "applicationerrors"))
        Do $$$AssertEquals(tOk, 0, tCase _ ": and the run does not pass")
    }

    ; The same fixture, armed with a page carrying no rows: it passes. An instance that has never
    ; faulted is a serving instance with nothing to show, and the four failures above are the
    ; guards rather than the fixture standing in the way of every answer.
    Do ##class(OcuPilot.Test.SmokeListFault).ArmErrors(200, "{""rows"":[],""truncated"":false}")
    Set tOkPage = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tPageReport, .tPageCounts)
    Do ##class(OcuPilot.Test.SmokeListFault).DisarmErrors()
    Do $$$AssertTrue(tPageReport [ ("  pass     applicationerrors"), "a 200 carrying a rows array passes, empty or not (run ok=" _ tOkPage _ "): " _ ..Line(tPageReport, "applicationerrors"))
}

/// <p>Story 2.9 -- with credentials, the <code>processes</code> check reads the processes list's
/// first row through the screen-read route and passes, before the sign-out. The configured test
/// account must hold <code>%Admin_Operate:USE</code>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.PROCESSLISTTOOL</parameter> to
/// <code>osmgmt.nosuch</code> -> the route answers 404 and the check fails.</p>
Method TestTheProcessesListIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     processes"), "the processes list is read: " _ ..Line(tReport, "  processes"))
    Set tListAt = $Find(tReport, "  pass     processes")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.8 -- with credentials, the <code>tasks</code> check reads the task schedule's first row
/// through the screen-read route and passes, before the sign-out. The configured test account must
/// hold <code>%Admin_Task:USE</code> and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.TASKLISTTOOL</parameter> to
/// <code>tasks.nosuch</code> -> the route answers 404 and the check fails.</p>
Method TestTheTaskScheduleIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     tasks"), "the task schedule is read: " _ ..Line(tReport, "  tasks"))
    Set tListAt = $Find(tReport, "  pass     tasks")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 6.7 -- with credentials, the <code>taskdetails</code> check finds an id from the task
/// schedule's own first row and reads Task details for it through the screen-read route, passing
/// on exactly one row, before the sign-out. The configured test account needs the task schedule's
/// own pairs and at least one task on the instance.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.TASKDETAILSTOOL</parameter> to
/// <code>tasks.nosuch</code> -&gt; the route answers 404 and the check fails.</p>
Method TestTheTaskDetailsIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     taskdetails"), "task details is read, keyed by the schedule's first row: " _ ..Line(tReport, "  taskdetails"))
    Set tListAt = $Find(tReport, "  pass     taskdetails")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 6.8 -- with credentials, the <code>processdetails</code> check finds a pid from the
/// processes list's own first row and reads Process details for it through the screen-read route,
/// passing on exactly one row, before the sign-out. The configured test account needs the
/// processes list's own three pairs and at least one process on the instance -- which is always
/// true, since the read itself is one.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.PROCESSDETAILSTOOL</parameter> to
/// <code>osmgmt.nosuch</code> -&gt; the route answers 404 and the check fails.</p>
Method TestTheProcessDetailsIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     processdetails"), "process details is read, keyed by the processes list's first row: " _ ..Line(tReport, "  processdetails"))
    Set tListAt = $Find(tReport, "  pass     processdetails")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 2.6 AC10 -- with credentials, the <code>users</code> check reads the users list's first
/// row through the screen-read route and passes, before the sign-out. The configured test account
/// must hold <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</p>
/// <p>Mutation: set <parameter>OcuPilot.Install.Smoke.USERLISTTOOL</parameter> to
/// <code>permissions.nosuch</code> -> the route answers 404 and the check fails.</p>
Method TestTheUsersListIsALiveCheck()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do $$$AssertTrue(tReport [ ("  pass     users"), "the users list is read: " _ ..Line(tReport, "  users"))
    Set tListAt = $Find(tReport, "  pass     users")
    Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), "and it ran before the pair was signed out")
}

/// <p>Story 6.11 -- with credentials, against the real instance: the Databases General view and
/// Free-space view both pass generically (fourteen real databases, never empty on a mounted
/// instance), and Database details and Database volumes both pass keyed by the General view's own
/// first row's <code>Directory</code>, all before the sign-out.</p>
/// <p>Mutation: change <code>DatabaseVolumeList</code>'s source type to <code>LIST</code> ->
/// <code>databasevolumes</code> answers the database list's own fields instead of a volume row, and
/// this goes red naming the mismatch through <method>OcuPilot.Test.ScreenRead</method>'s own
/// dedicated assertion, not this one, which only pins that the check passes at all.</p>
Method TestTheDatabasesChecksAreLiveChecks()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    For tName = "databases", "databasefreespace", "databasedetails", "databasevolumes" {
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName), tName _ " is read: " _ ..Line(tReport, tName))
        Set tListAt = $Find(tReport, "  pass     " _ tName)
        Do $$$AssertTrue((tListAt > 0) && ($Find(tReport, "sign-out") > tListAt), tName _ " ran before the pair was signed out")
    }
}

/// <p>A screen read that answers 200 without a one-row <code>rows</code> array -- an empty array, or
/// an HTML page where JSON was expected -- fails the <code>webapplications</code>, <code>users</code>,
/// <code>ssl</code>, <code>tasks</code>, <code>processes</code>, <code>audit</code>,
/// <code>webapp.restapis</code>, <code>roles</code>, <code>resources</code>, <code>services</code>,
/// <code>x509</code>, <code>ldap</code> and <code>wallet</code> checks rather than passing on the
/// status alone. The run asks for the demo, so the X.509 and Wallet checks fail on an empty array
/// too. Drives <class>OcuPilot.Test.SmokeListFault</class>.</p>
/// <p>Mutation: replace <code>If tCount '= 1</code> in
/// <method>OcuPilot.Install.Smoke.CheckAreaLists</method> with <code>If 0</code> -> all thirteen fail
/// assertions go red.</p>
Method TestAScreenReadWithoutOneRowFailsTheListCheck()
{
    For tBody = "{""rows"":[]}", "<!doctype html><html></html>" {
        Do ##class(OcuPilot.Test.SmokeListFault).Arm(200, tBody)
        Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "1", .tReport, .tCounts)
        Do ##class(OcuPilot.Test.SmokeListFault).Disarm()
        Do $$$AssertTrue(tReport [ ("  fail     webapplications"), "a 200 carrying " _ tBody _ " fails the list check: " _ ..Line(tReport, "webapplications"))
        Do $$$AssertTrue(tReport [ ("  fail     users"), "and the users list check: " _ ..Line(tReport, "  users"))
        Do $$$AssertTrue(tReport [ ("  fail     ssl"), "and the SSL/TLS list check: " _ ..Line(tReport, "  ssl"))
        Do $$$AssertTrue(tReport [ ("  fail     tasks"), "and the task schedule check: " _ ..Line(tReport, "  tasks"))
        Do $$$AssertTrue(tReport [ ("  fail     processes"), "and the processes list check: " _ ..Line(tReport, "  processes"))
        Do $$$AssertTrue(tReport [ ("  fail     audit"), "and the audit database viewer check: " _ ..Line(tReport, "  audit"))
        Do $$$AssertTrue(tReport [ ("  fail     webapp.restapis"), "and the REST API explorer check: " _ ..Line(tReport, "webapp.restapis"))
        Do $$$AssertTrue(tReport [ ("  fail     roles"), "and the roles list check: " _ ..Line(tReport, "  roles"))
        Do $$$AssertTrue(tReport [ ("  fail     resources"), "and the resources list check: " _ ..Line(tReport, "  resources"))
        Do $$$AssertTrue(tReport [ ("  fail     services"), "and the services list check: " _ ..Line(tReport, "  services"))
        Do $$$AssertTrue(tReport [ ("  fail     x509"), "and the X.509 list check: " _ ..Line(tReport, "  x509"))
        Do $$$AssertTrue(tReport [ ("  fail     ldap"), "and the LDAP / Kerberos list check: " _ ..Line(tReport, "  ldap"))
        Do $$$AssertTrue(tReport [ ("  fail     wallet"), "and the Wallet list check: " _ ..Line(tReport, "  wallet"))
        Do $$$AssertEquals(tOk, 0, "and the run does not pass")
    }
}

/// <p>Story 6.3 (AD-25) -- on a run that did not ask for the demo, an empty X.509 or Wallet list is
/// skipped, because only the demo fixture puts a row there, while an empty LDAP / Kerberos list still
/// fails. Drives <class>OcuPilot.Test.SmokeListFault</class>.</p>
/// <p>Mutation: drop the skip arm from <method>OcuPilot.Install.Smoke.CheckAreaLists</method> -&gt;
/// the two skipped assertions go red.</p>
Method TestAnEmptyDemoListIsSkippedWithoutTheDemo()
{
    Do ##class(OcuPilot.Test.SmokeListFault).Arm(200, "{""rows"":[]}")
    Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do ##class(OcuPilot.Test.SmokeListFault).Disarm()
    Do $$$AssertTrue(tReport [ ("  skipped  x509"), "an empty X.509 list is skipped without the demo: " _ ..Line(tReport, "  x509"))
    Do $$$AssertTrue(tReport [ ("  skipped  wallet"), "and so is an empty Wallet list: " _ ..Line(tReport, "  wallet"))
    Do $$$AssertTrue(tReport [ ("  fail     ldap"), "while an empty LDAP / Kerberos list still fails: " _ ..Line(tReport, "  ldap"))
}

/// <p>Story 2.7 AC8 -- each <method>OcuPilot.Install.Smoke.CheckAreaLists</method> index reads the
/// screen its name stands for: the <code>webapplications</code>, <code>users</code>,
/// <code>ssl</code>, <code>tasks</code>, <code>processes</code>, <code>audit</code>,
/// <code>webapp.restapis</code>, <code>roles</code>, <code>resources</code>, <code>services</code>,
/// <code>x509</code>, <code>ldap</code>, <code>wallet</code>, five OAuth 2.0 tab, <code>ondemand</code>,
/// <code>upcoming</code>, <code>taskhistory</code>, <code>systemusage</code> and <code>locks</code>
/// (Story 6.10), plus <code>databases</code> and <code>databasefreespace</code> (Story 6.11),
/// <code>devices</code> (Story 6.12), <code>alerts</code> (Story 6.13) and <code>messages</code>
/// (Story 6.14) checks, issue exactly those twenty-eight screen reads, in that order, and nothing else in
/// <method>CheckAreaLists</method> reads a screen.
/// <method>OcuPilot.Install.Smoke.CheckTaskDetails</method> (Story 6.7) runs after it and re-reads
/// the task schedule for an id first, a twenty-ninth screen path; under this fixture's one-row,
/// no-<code>Id</code> body that lookup finds none, so <code>taskdetails</code> itself fails
/// without reading its own path. <code>CheckProcessDetails</code> (Story 6.8) runs after that and
/// re-reads the processes list for a pid, a thirtieth screen path; under the same one-row,
/// no-<code>Pid</code> body that lookup also finds none, so <code>processdetails</code> fails too.
/// <code>CheckDatabaseDetails</code> (Story 6.11) runs last and re-reads the Databases list for a
/// directory, a thirty-first and last screen path, shared by <code>databasedetails</code> and
/// <code>databasevolumes</code>, which both fail under the same one-row, no-<code>Directory</code>
/// body.</p>
/// <p><b>Why the report cannot say this.</b> A report line carries the check's name and its
/// outcome, never the tool behind it, so transposing two <code>$Select</code> arms leaves every
/// name-and-outcome assertion in this class green while each check reads the other's list. Driven
/// through <class>OcuPilot.Test.SmokeListFault</class>, which records the paths and answers a
/// one-row body so the run needs no particular instance state.</p>
/// <p>Mutation: transpose the <code>tI = 2</code> and <code>tI = 3</code> arms of the
/// <code>$Select</code> -&gt; the second and third path assertions go red.</p>
Method TestEachAreaListCheckReadsItsOwnScreen()
{
    Do ##class(OcuPilot.Test.SmokeListFault).ClearPaths()
    Do ##class(OcuPilot.Test.SmokeListFault).Arm(200, "{""rows"":[{""Name"":""one""}]}")
    Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
    Do ##class(OcuPilot.Test.SmokeListFault).Disarm()
    Set tPaths = ##class(OcuPilot.Test.SmokeListFault).Paths()
    Do ##class(OcuPilot.Test.SmokeListFault).ClearPaths()

    For tName = "webapplications", "users", "ssl", "tasks", "processes", "audit", "webapp.restapis", "roles", "resources", "services", "x509", "ldap", "wallet", "oauthdescriptions", "oauthclients", "oauthresourceservers", "oauthserver", "oauthserverclients", "ondemand", "upcoming", "taskhistory", "systemusage", "locks", "databases", "databasefreespace", "devices", "alerts", "messages" {
        ; Matched to the end of the line: "messages" is a prefix of "messageslog", so an unterminated
        ; match is satisfied by the console-log page check even with no messages check at all. Every
        ; name in this roster is a CheckAreaLists name, and CheckAreaLists runs before the checks
        ; below it, so each of these lines is followed by another.
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName _ $Char(10)), "a one-row body passes the " _ tName _ " check (run ok=" _ tOk _ "): " _ ..Line(tReport, tName))
    }
    ; taskdetails, processdetails and Story 6.11's databasedetails/databasevolumes all fail under
    ; this fixture: the armed row carries no Id, no Pid and no Directory to key their own reads by,
    ; so each re-reads its own parent list (one more path apiece) and stops there --
    ; databasedetails and databasevolumes share the one re-read of the Databases list, since
    ; OcuPilot.Install.Smoke.CheckDatabaseDetails looks the directory up once for both.
    Do $$$AssertTrue(tReport [ ("  fail     taskdetails"), "and taskdetails fails for lack of an id to key its read by: " _ ..Line(tReport, "taskdetails"))
    Do $$$AssertTrue(tReport [ ("  fail     processdetails"), "and processdetails fails for lack of a pid to key its read by: " _ ..Line(tReport, "processdetails"))
    Do $$$AssertTrue(tReport [ ("  fail     databasedetails"), "and databasedetails fails for lack of a directory to key its read by: " _ ..Line(tReport, "databasedetails"))
    Do $$$AssertTrue(tReport [ ("  fail     databasevolumes"), "and databasevolumes fails for lack of a directory to key its read by: " _ ..Line(tReport, "databasevolumes"))
    Do $$$AssertEquals($ListLength(tPaths), 31, "a credentialed run reads exactly thirty-one screens: the twenty-eight generic lists, then taskdetails' own re-read of the task schedule, processdetails' own re-read of the processes list, and databasedetails/databasevolumes' shared re-read of the Databases list: " _ $ListToString(tPaths, " | "))
    If $ListLength(tPaths) '= 31 Quit
    Set tExpected = $ListBuild(##class(OcuPilot.Install.Smoke).#WEBAPPLISTTOOL, ##class(OcuPilot.Install.Smoke).#USERLISTTOOL, ##class(OcuPilot.Install.Smoke).#SSLLISTTOOL, ##class(OcuPilot.Install.Smoke).#TASKLISTTOOL, ##class(OcuPilot.Install.Smoke).#PROCESSLISTTOOL, ##class(OcuPilot.Install.Smoke).#AUDITLISTTOOL, ##class(OcuPilot.Install.Smoke).#RESTAPILISTTOOL, ##class(OcuPilot.Install.Smoke).#ROLELISTTOOL, ##class(OcuPilot.Install.Smoke).#RESOURCELISTTOOL, ##class(OcuPilot.Install.Smoke).#SERVICELISTTOOL, ##class(OcuPilot.Install.Smoke).#X509LISTTOOL, ##class(OcuPilot.Install.Smoke).#LDAPLISTTOOL, ##class(OcuPilot.Install.Smoke).#WALLETLISTTOOL, ##class(OcuPilot.Install.Smoke).#OAUTHDESCRIPTIONSTOOL, ##class(OcuPilot.Install.Smoke).#OAUTHCLIENTSTOOL, ##class(OcuPilot.Install.Smoke).#OAUTHRESOURCESERVERSTOOL, ##class(OcuPilot.Install.Smoke).#OAUTHSERVERTOOL, ##class(OcuPilot.Install.Smoke).#OAUTHSERVERCLIENTSTOOL, ##class(OcuPilot.Install.Smoke).#TASKONDEMANDTOOL, ##class(OcuPilot.Install.Smoke).#TASKUPCOMINGTOOL, ##class(OcuPilot.Install.Smoke).#TASKHISTORYTOOL, ##class(OcuPilot.Install.Smoke).#SYSTEMUSAGETOOL, ##class(OcuPilot.Install.Smoke).#LOCKLISTTOOL, ##class(OcuPilot.Install.Smoke).#DATABASELISTTOOL, ##class(OcuPilot.Install.Smoke).#DATABASEFREESPACELISTTOOL, ##class(OcuPilot.Install.Smoke).#DEVICELISTTOOL, ##class(OcuPilot.Install.Smoke).#ALERTLISTTOOL, ##class(OcuPilot.Install.Smoke).#MESSAGESLISTTOOL, ##class(OcuPilot.Install.Smoke).#TASKLISTTOOL, ##class(OcuPilot.Install.Smoke).#PROCESSLISTTOOL, ##class(OcuPilot.Install.Smoke).#DATABASELISTTOOL)
    For tI = 1:1:31 {
        Set tWanted = "/screens/" _ $List(tExpected, tI) _ "/read?maxRows=1"
        Do $$$AssertTrue($List(tPaths, tI) [ tWanted, "check " _ tI _ " reads " _ tWanted _ ", not " _ $List(tPaths, tI))
    }
}

/// <p>Story 2.7 AC8 -- <method>OcuPilot.Install.Smoke.CheckAreaLists</method> names one
/// indexed <code>$Select</code> arm per list, in a loop bounded to the same count as its
/// comma-separated name list, and its catch-all answers the empty string rather than reusing an
/// earlier list's tool identifier. Read from the compiled class's own source and derived from
/// whatever the name list currently says, because the method is private and it is the
/// declaration's shape -- not its runtime behavior at the lists that ship today -- that the
/// next list would break. Which tool each index actually reads is
/// <method>TestEachAreaListCheckReadsItsOwnScreen</method>'s.</p>
/// <p>Mutation: add one more name to the comma-separated list and raise the loop bound with it in
/// <method>CheckAreaLists</method>, without adding that index's own arm to the
/// <code>$Select</code> -&gt; the arm-count assertion goes red, because the added name would
/// otherwise reach the catch-all silently instead of by a checked invariant. Stated without an
/// ordinal: the list grows with every area list that ships.</p>
Method TestCheckAreaListsHasOneSelectArmPerNameAndAnEmptyCatchAll()
{
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Install.Smoke", .tSource)
    Do $$$AssertStatusOK(tSC, "OcuPilot.Install.Smoke's source reads back")
    Set tText = $Replace(tSource, $Char(13, 10), $Char(10))
    Set tQuote = $Char(34)

    Set tSelectMarker = "Set tTool = $Select("
    Set tSelectAt = $Find(tText, tSelectMarker)
    Do $$$AssertTrue(tSelectAt > 0, "the per-index tool lookup is found")
    Set tPrefix = $Extract(tText, 1, tSelectAt - $Length(tSelectMarker) - 1)

    Set tNameMarker = "Set tName = $Piece(" _ tQuote
    Set tNameMarkerAt = ..LastMarkerAt(tPrefix, tNameMarker)
    Do $$$AssertTrue(tNameMarkerAt > 0, "CheckAreaLists' comma-separated name list is found immediately before the tool lookup")
    ; The window has to outlast the list, which grows by one name per area list that ships: it
    ; stood at 288 characters after Story 6.14, and a window shorter than the list makes $Piece
    ; return a truncated roster whose name count reddens this method on a correct declaration.
    Set tNames = $Piece($Extract(tText, tNameMarkerAt, tNameMarkerAt + 1000), tQuote, 1)
    Set tNameCount = $Length(tNames, ",")
    Do $$$AssertTrue(tNameCount > 0, "the name list read from the source is not empty: " _ tNames)

    Set tLoopMarker = "For tI = 1:1:"
    Set tLoopMarkerAt = ..LastMarkerAt(tPrefix, tLoopMarker)
    Do $$$AssertTrue(tLoopMarkerAt > 0, "an enclosing For loop is found before the name list")
    Set tLoopBound = +$Piece($Extract(tText, tLoopMarkerAt, tLoopMarkerAt + 20), " ", 1)
    Do $$$AssertEquals(tLoopBound, tNameCount, "the loop visits exactly one index per name: " _ tNames)

    Set tLineEnd = $Find(tText, $Char(10), tSelectAt)
    Do $$$AssertTrue(tLineEnd > tSelectAt, "the tool lookup's line ends before the end of the source")
    Set tSelectLine = $Extract(tText, tSelectAt, tLineEnd - 1)

    Set tArmCount = 0
    Set tScanFrom2 = 1
    For {
        Set tAt2 = $Find(tSelectLine, "tI = ", tScanFrom2)
        Quit:tAt2=0
        Set tArmCount = tArmCount + 1
        Set tScanFrom2 = tAt2
    }
    Do $$$AssertEquals(tArmCount, tNameCount, "one indexed $Select arm names a tool for every list, so a name added without its own arm is caught here rather than by silently reading an earlier list's result under the new name: " _ tSelectLine)

    Set tCatchAllNeedle = ", 1: " _ tQuote _ tQuote _ ")"
    Do $$$AssertTrue(tSelectLine [ tCatchAllNeedle, "the catch-all answers the empty string, never a reused tool identifier: " _ tSelectLine)
}

/// <p>The position immediately after the last occurrence of <var>pMarker</var> in <var>pText</var>,
/// or <code>0</code> when it does not occur at all -- <code>$Find</code>'s own convention for one
/// occurrence, extended to "the nearest preceding one".</p>
ClassMethod LastMarkerAt(pText As %String, pMarker As %String) As %Integer [ Private ]
{
    Set tScanFrom = 1
    Set tLastAt = 0
    For {
        Set tAt = $Find(pText, pMarker, tScanFrom)
        Quit:tAt=0
        Set tLastAt = tAt
        Set tScanFrom = tAt
    }
    Quit tLastAt
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

/// <p>With no credentials the sign-in check, the reads that need its token and the sign-out are
/// each <b>skipped</b>, not passed: a run that never tried is not a run that succeeded.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Install.Smoke.CheckSignOut</method>'s
/// no-pair guard -- the sign-out is noted <code>fail</code> and this goes red.</p>
Method TestNoCredentialsSkipsRatherThanPasses()
{
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport, .tCounts)
    For tName = "signin", "instance", "namespaces", "navigation", "webapplications", "users", "ssl", "tasks", "processes", "audit", "webapp.restapis", "roles", "resources", "services", "x509", "ldap", "wallet", "oauthdescriptions", "oauthclients", "oauthresourceservers", "oauthserver", "oauthserverclients", "ondemand", "upcoming", "taskhistory", "systemusage", "locks", "databases", "databasefreespace", "devices", "alerts", "messages", "taskdetails", "processdetails", "databasedetails", "databasevolumes", "messageslog", "applicationerrors", "sign-out" {
        ; Matched through the reason separator for the same reason as above: without it
        ; "  skipped  messages" is satisfied by the messageslog line. Every skipped line carries a
        ; reason, so " -- " terminates the name on all of them -- including sign-out, the last line,
        ; which a newline would not.
        Do $$$AssertTrue(tReport [ ("  skipped  " _ tName _ " -- "), tName _ " is skipped: " _ ..Line(tReport, tName))
    }
    Do $$$AssertTrue(tReport [ "no credentials were supplied", "and the report says why")
}

/// <p>Story 5.8: <b>a skipped check does not touch the instance.</b> The sibling method's doc
/// promises "never a write" of every skip arm; this is the arm where that is not free. The demo
/// and ownership arms return before the target has even been resolved, but the turn-slot arm is
/// reached after the fresh read and after the restore body has been built, so the check has an
/// object in hand that would put the fixture back -- and putting it back would be normalising a
/// state this run did not cause, on a run that reports it did nothing.</p>
/// <p>Driven with the probe armed <b>enabled</b>, because that is the only state in which a
/// restore is observable at all: against an application already disabled with no resource, the
/// restore's own PUT and no PUT leave exactly the same row.</p>
/// <p>Mutation (Rule 19): drop the <code>Set tRestoreBody = ""</code> line from
/// <method>OcuPilot.Install.Smoke.CheckAgentWrite</method>'s turn-slot arm -- the still-enabled
/// assertion goes red, and the two outcome assertions stay green, which is the point: the outcome
/// was always right and the side effect was not.</p>
Method TestASkippedWriteCheckLeavesTheInstanceAlone()
{
    If '..ArmMixedCase(1) Quit
    Set tTurnKey = ""
    Try {
        Set tReserveSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, "", ##class(OcuPilot.Api.Error).#TURNABANDONEDJOBLOST, ##class(OcuPilot.Install.Smoke).#LIMITS, .tTurnKey, .tBusy, .tSweepSC)
        If $$$ISERR(tReserveSC) || tBusy || (tTurnKey = "") {
            ; Said out loud rather than returned silently, as ArmMixedCase does: the one turn slot
            ; is instance-wide, so a run beside a live turn cannot take it and this method would
            ; otherwise read as a pass having asserted nothing.
            Do ..LogMessage("the one turn slot of " _ $Username _ " was already taken, so this test asserted nothing")
            Quit
        }
        Kill tChecks
        Do ##class(OcuPilot.Test.SmokeWriteProbe).RunWriteChecks(.tChecks, "1")
        For tName = "agentwrite", "auditmarker" {
            Do $$$AssertEquals(..Outcome(.tChecks, tName), "skipped", tName _ " is skipped when the one turn slot is already taken")
            Do $$$AssertTrue(..Reason(.tChecks, tName) [ "turn", tName _ "'s reason names the cause: " _ ..Reason(.tChecks, tName))
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled"), 1, "and the fixture is left exactly as the skip found it, because a check that did not run wrote nothing")
    } Catch ex {
        Do $$$AssertEquals(ex.DisplayString(), "", "the probe run raised")
    }
    If tTurnKey '= "" Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()
}

}
