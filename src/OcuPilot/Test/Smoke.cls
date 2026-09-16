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
    ; The `arealists` pending note is gone since Story 2.10: every area the shell gates now has a
    ; real live-list check, Logs included, so a note saying otherwise would be a false claim about
    ; the report's own coverage rather than an honest gap.
    Do $$$AssertEquals(..Line(tReport, "arealists"), "", "no area-list pending note survives, because every built area's list is a real check")
    Do $$$AssertTrue(tReport [ "Epic 3", "while the two the agent brings are still pending")
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

/// <p>A screen read that answers 200 without a one-row <code>rows</code> array -- an empty array, or
/// an HTML page where JSON was expected -- fails the <code>webapplications</code>, <code>users</code>,
/// <code>ssl</code>, <code>tasks</code>, <code>processes</code>, <code>audit</code>,
/// <code>webapp.restapis</code>, <code>roles</code>, <code>resources</code> and <code>services</code>
/// checks rather than passing on the status alone. Drives
/// <class>OcuPilot.Test.SmokeListFault</class>.</p>
/// <p>Mutation: replace <code>If tCount '= 1</code> in
/// <method>OcuPilot.Install.Smoke.CheckAreaLists</method> with <code>If 0</code> -> all ten fail
/// assertions go red.</p>
Method TestAScreenReadWithoutOneRowFailsTheListCheck()
{
    For tBody = "{""rows"":[]}", "<!doctype html><html></html>" {
        Do ##class(OcuPilot.Test.SmokeListFault).Arm(200, tBody)
        Set tOk = ##class(OcuPilot.Test.SmokeListFault).Run(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "0", .tReport, .tCounts)
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
        Do $$$AssertEquals(tOk, 0, "and the run does not pass")
    }
}

/// <p>Story 2.7 AC8 -- each <method>OcuPilot.Install.Smoke.CheckAreaLists</method> index reads the
/// screen its name stands for: the <code>webapplications</code>, <code>users</code>,
/// <code>ssl</code>, <code>tasks</code>, <code>processes</code>, <code>audit</code>,
/// <code>webapp.restapis</code>, <code>roles</code>, <code>resources</code> and <code>services</code>
/// checks issue exactly those ten screen reads, in that order, and nothing else in a run reads a
/// screen.</p>
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

    For tName = "webapplications", "users", "ssl", "tasks", "processes", "audit", "webapp.restapis", "roles", "resources", "services" {
        Do $$$AssertTrue(tReport [ ("  pass     " _ tName), "a one-row body passes the " _ tName _ " check (run ok=" _ tOk _ "): " _ ..Line(tReport, tName))
    }
    Do $$$AssertEquals($ListLength(tPaths), 10, "a credentialed run reads exactly ten screens: " _ $ListToString(tPaths, " | "))
    If $ListLength(tPaths) '= 10 Quit
    Set tExpected = $ListBuild(##class(OcuPilot.Install.Smoke).#WEBAPPLISTTOOL, ##class(OcuPilot.Install.Smoke).#USERLISTTOOL, ##class(OcuPilot.Install.Smoke).#SSLLISTTOOL, ##class(OcuPilot.Install.Smoke).#TASKLISTTOOL, ##class(OcuPilot.Install.Smoke).#PROCESSLISTTOOL, ##class(OcuPilot.Install.Smoke).#AUDITLISTTOOL, ##class(OcuPilot.Install.Smoke).#RESTAPILISTTOOL, ##class(OcuPilot.Install.Smoke).#ROLELISTTOOL, ##class(OcuPilot.Install.Smoke).#RESOURCELISTTOOL, ##class(OcuPilot.Install.Smoke).#SERVICELISTTOOL)
    For tI = 1:1:10 {
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
/// <p>Mutation: add an eighth name to the comma-separated list and raise the loop bound to
/// <code>8</code> in <method>CheckAreaLists</method>, without adding its own <code>tI = 8</code>
/// arm to the <code>$Select</code> -&gt; the arm-count assertion goes red, because the eighth name
/// would otherwise reach the catch-all silently instead of by a checked invariant.</p>
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
    Set tNames = $Piece($Extract(tText, tNameMarkerAt, tNameMarkerAt + 200), tQuote, 1)
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
    For tName = "signin", "instance", "namespaces", "navigation", "webapplications", "users", "ssl", "tasks", "processes", "audit", "webapp.restapis", "roles", "resources", "services", "messageslog", "applicationerrors", "sign-out" {
        Do $$$AssertTrue(tReport [ ("  skipped  " _ tName), tName _ " is skipped: " _ ..Line(tReport, tName))
    }
    Do $$$AssertTrue(tReport [ "no credentials were supplied", "and the report says why")
}

}
