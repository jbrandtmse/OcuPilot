/// <p>The readiness endpoint (Story 1.17, AD-45, DW-2): what
/// <class>OcuPilot.Api.Readiness</class> answers in each of the install gate's five states,
/// what it never says, and that it and the container health check read the same ladder.</p>
/// <p>The five states are driven through <class>OcuPilot.Test.ReadinessFixture</class>, which
/// arms the gate read and leaves the whole production response body as the code under test;
/// <class>OcuPilot.Test.Dispatch</class> captures what it wrote, unparsed, so an assertion is
/// made against the literal bytes rather than something a parser already forgave. The anonymous
/// request at the end is over the wire, against the real application, with no credentials at
/// all -- the shape a monitor outside the instance has.</p>
Class OcuPilot.Test.Readiness Extends %UnitTest.TestCase
{

/// <p>The production readiness path, with the trailing slash IRIS requires of every REST web
/// application (<class>OcuPilot.Api.Readiness</class>'s own header).</p>
Parameter READINESSPATH As %String = "/api/ocupilot/readiness/";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ReadinessFixture).Reset()
    Quit $$$OK
}

/// <p>Dispatch <code>GET /</code> against the armed fixture and return the parsed body.</p>
Method Answer(pState As %String, Output pStatus As %Integer, Output pBody As %String) As %DynamicObject
{
    Do ##class(OcuPilot.Test.ReadinessFixture).Arm(pState)
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.ReadinessFixture", "/", "GET", , .pBody, .pStatus)
    Do $$$AssertStatusOK(tSC, "the readiness dispatch completes for state '" _ pState _ "'")
    Quit ##class(%DynamicObject).%FromJSON(pBody)
}

/// <p>AD-45 -- an installed instance answers 200 with exactly the three keys, and
/// <code>installed</code> and <code>state</code> cannot disagree.</p>
/// <p>Mutation (Rule 19): add a fourth key to
/// <method>OcuPilot.Api.Readiness.Readiness</method>'s body, or change
/// <code>installed</code> to a string -- the key-set assertion or the type assertion goes
/// red.</p>
Method TestInstalledAnswersTheThreeKeysAndNothingElse()
{
    Set tObj = ..Answer("installed", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "readiness answers 200")
    Do $$$AssertEquals(tObj.state, "installed", "and reports the installed state")
    Do $$$AssertEquals(tObj.installed, 1, "and says so in the boolean too")
    Do $$$AssertEquals(tObj.%GetTypeOf("installed"), "boolean", "installed is a JSON boolean, never a string or a number")
    Do $$$AssertEquals(tObj.%GetTypeOf("state"), "string", "state is a string")
    Do $$$AssertEquals(tObj.%GetTypeOf("version"), "string", "and so is the version stamp, whatever it holds")
    Do $$$AssertEquals(..KeyList(tObj), "installed,state,version", "exactly three keys, and these three")
    Do $$$AssertEquals((tBody [ "}{"), 0, "one envelope, written once")
}

/// <p>DW-2 -- a failed install is distinguishable from one that never started, and the failing
/// step is disclosed nowhere. AD-45 forbids anything that aids reconnaissance, and a step name
/// is internal detail handed to an anonymous caller; the substance of DW-2 is the state
/// alone.</p>
/// <p>Mutation (Rule 19): fold <code>failed</code> into <code>installing</code> in
/// <method>OcuPilot.Api.Readiness.Readiness</method> -- the first assertion goes red. Add the
/// version row's <property>FailingStep</property> to the body -- the last goes red.</p>
Method TestFailedIsItsOwnStateAndNamesNoStep()
{
    Set tFailed = ..Answer("failed", .tFailedStatus, .tFailedBody)
    Do $$$AssertEquals(tFailedStatus, 200, "a failed install still answers 200 -- readiness is a report, not a refusal")
    Do $$$AssertEquals(tFailed.state, "failed", "and names the failed state")
    Do $$$AssertEquals(tFailed.installed, 0, "which is not installed")

    Set tInstalling = ..Answer("installing", .tInstallingStatus, .tInstallingBody)
    Do $$$AssertEquals(tInstalling.state, "installing", "an install that has not finished is a different state")
    Do $$$AssertNotEquals(tFailed.state, tInstalling.state, "DW-2: a failed install is distinguishable from one that never started")

    ; The failing step this instance's own version row may carry must appear nowhere in what a
    ; failed readiness answer says. Asserted against the live row rather than a literal, so the
    ; pin follows whatever step a real failure recorded.
    Set tStep = ""
    Set tRowSC = ##class(OcuPilot.Install.Installer).CurrentVersionRow("", .tRow)
    If $$$ISOK(tRowSC), $IsObject(tRow) Set tStep = tRow.FailingStep
    Do $$$AssertEquals(..KeyList(tFailed), "installed,state,version", "a failed answer carries the same three keys and no more")
    If (tStep '= "") && (tStep '= $Char(0)) {
        Do $$$AssertEquals((tFailedBody [ tStep), 0, "the failing step recorded on the version row is not in the body")
    }
}

/// <p>DW-96 -- an unreadable install state answers 200 with <code>state:"unreadable"</code>
/// inside the same three keys (AD-45), never folded into <code>installing</code>.</p>
/// <p>Mutation (Rule 19): map <code>unreadable</code> to <code>installing</code> in
/// <method>OcuPilot.Api.Readiness.Readiness</method> -- red.</p>
Method TestUnreadableIsItsOwnStateInTheSameThreeKeys()
{
    Set tObj = ..Answer("unreadable", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "an unreadable state still answers 200")
    Do $$$AssertEquals(tObj.state, "unreadable", "and names the unreadable state")
    Do $$$AssertEquals(tObj.installed, 0, "which is not installed")
    Do $$$AssertEquals(tObj.version, "", "and carries no version")
    Do $$$AssertEquals(..KeyList(tObj), "installed,state,version", "exactly the three keys, no field added")
    Do $$$AssertEquals(tObj.%GetTypeOf("installed"), "boolean", "installed stays a JSON boolean")
}

/// <p>AD-45 -- the version stamp is reported only for an instance that is installed. An
/// unfinished, failed or out-of-date install has no version a caller could act on.</p>
/// <p>Mutation (Rule 19): drop the state guard from
/// <method>OcuPilot.Api.Readiness.VersionStamp</method> -- the three empty-version assertions
/// go red.</p>
Method TestVersionIsReportedOnlyWhenInstalled()
{
    For tI = 1:1:4 {
        Set tState = $Piece("installing,failed,upgraderequired,unreadable", ",", tI)
        Set tObj = ..Answer(tState, .tStatus, .tBody)
        Do $$$AssertEquals(tObj.state, tState, "the endpoint reports the state it was given: " _ tState)
        Do $$$AssertEquals(tObj.version, "", "and names no version in state " _ tState)
        Do $$$AssertEquals(tObj.installed, 0, "and is not installed in state " _ tState)
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.Readiness).VersionStamp("installing"), "", "the stamp helper agrees, driven directly")
    Do $$$AssertNotEquals(##class(OcuPilot.Api.Readiness).VersionStamp("installed"), "", "and reports one for an installed instance")
}

/// <p>AD-12 -- a wrong verb is the one 405 envelope, through
/// <method>OcuPilot.Api.Error.Render405</method>, with the <code>Allow</code> header set. The
/// request is never echoed back in it.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Api.Readiness.Http405</method> -- the
/// framework's own shape is written instead and the code assertion goes red.</p>
Method TestWrongVerbIsOne405EnvelopeWithAllow()
{
    Do ##class(OcuPilot.Test.ReadinessFixture).Arm("installed")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.ReadinessFixture", "/", "POST", , .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "the dispatch completes")
    Do $$$AssertEquals(tStatus, 405, "a POST to the readiness path is 405")
    Do $$$AssertTrue(tAllow [ "GET", "and the Allow header names the verb that is mapped")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, ##class(OcuPilot.Api.Error).#ROUTEMETHODNOTALLOWED, "through the one error writer, with its own machine code")
    Do $$$AssertEquals((tBody [ "}{"), 0, "one envelope, not two")
}

/// <p>AD-12 -- a path under the readiness application that maps to no route is OcuPilot's one
/// error envelope too, not the framework's own shape. <method>ReportHttpStatusCode</method> is
/// this class's own override; every other test of that method in the suite drives
/// <class>OcuPilot.Api.Router</class>'s copy, so without this the new unauthenticated
/// application's error path shipped unexercised -- on the one endpoint anonymous callers are
/// expected to reach.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Api.Readiness.ReportHttpStatusCode</method>
/// -> the superclass writes its own HTML document, the body no longer parses as JSON, and the
/// envelope assertion goes red while every other test in this class stays green. Deleting only
/// its <code>404</code> arm does <b>not</b> go red, and that is worth knowing rather than
/// assuming: the <code>Else</code> arm resolves the same slug and code for 404 through
/// <method>OcuPilot.Api.Error.GetSlugForStatus</method> and
/// <method>CodeForStatus</method>, so the two arms agree here. The arm is kept because it
/// mirrors <class>OcuPilot.Api.Router</class>'s own shape, not because it changes this answer.</p>
Method TestAnUnmappedPathIsOneNotFoundEnvelope()
{
    Do ##class(OcuPilot.Test.ReadinessFixture).Arm("installed")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.ReadinessFixture", "/nosuchroute", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the dispatch completes")
    Do $$$AssertEquals(tStatus, 404, "an unmapped path under the readiness application is 404")
    ; Parsed before it is read, so losing the override fails as an assertion naming the body
    ; rather than as an <INVALID OREF> on the next line.
    Set tObj = ""
    Try {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tObj = ""
    }
    Do $$$AssertTrue($IsObject(tObj), "the body is OcuPilot's JSON envelope, not the framework's own document: " _ $Extract(tBody, 1, 120))
    If $IsObject(tObj) {
        Do $$$AssertEquals(tObj.code, ##class(OcuPilot.Api.Error).#ROUTENOTFOUND, "through the one error writer, with its own machine code")
    }
    Do $$$AssertEquals((tBody [ "}{"), 0, "one envelope, not two")
    Do $$$AssertEquals((tBody [ "nosuchroute"), 0, "and the request is not echoed back in it")
}

/// <p>AD-45 -- readiness and the container health check read the <b>same</b> ladder, so they
/// cannot disagree about whether this instance is installed.
/// <method>OcuPilot.Api.Readiness.GateStatus</method> delegates to
/// <method>OcuPilot.Install.Installer.GateStatus</method>, and
/// <file>scripts/container-health.sh</file> calls that same method through
/// <code>iris session</code> -- the shell half is pinned in
/// <file>ui/tools/compose.test.mjs</file>, which can read a shell script where a
/// <code>%UnitTest</code> class cannot.</p>
/// <p>The health check is deliberately not rewritten to call this endpoint: the pinned image
/// ships no HTTP client at all (verified, Story 1.4), which is why the probe shells
/// <code>iris session</code>.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Api.Readiness.GateStatus</method> a ladder of
/// its own -- this goes red the moment the two answers differ, and stays red for every state
/// but the one they happen to agree on.</p>
Method TestReadinessAndTheHealthCheckReadTheSameLadder()
{
    Do ##class(OcuPilot.Test.ReadinessFixture).Reset()
    Set tFromEndpoint = ##class(OcuPilot.Api.Readiness).GateStatus()
    Set tFromInstaller = ##class(OcuPilot.Install.Installer).GateStatus()
    Do $$$AssertTrue(tFromInstaller '= "", "the installer's gate answered something")
    Do $$$AssertEquals(tFromEndpoint, tFromInstaller, "readiness reports the installer's own ladder, which is what the health check reads")
}

/// <p>AD-45, over the wire: an <b>anonymous</b> caller -- no credentials at all -- gets 200,
/// <code>application/json</code>, and a body carrying the three keys. This is the shape a
/// monitor outside the instance has, and the one the smoke script's own first check makes.</p>
/// <p>It also pins the <code>Cache-Control: no-store</code> header: a cached
/// <code>{"installed":true}</code> outliving the state it reported is the one failure this
/// endpoint exists to prevent, so the directive is part of the answer rather than a
/// nicety.</p>
/// <p>Mutation (Rule 19): set the readiness application's <code>AutheEnabled</code> to 32 in
/// <class>OcuPilot.Install.Roster</class> and re-install -- the anonymous request answers 401
/// and this goes red. mutation: delete the <code>Set %response.Headers("Cache-Control") =
/// "no-store"</code> line from <method>OcuPilot.Api.Readiness.Readiness</method> ->
/// the Cache-Control assertion below goes red while every other assertion in this method
/// stays green.</p>
Method TestAnonymousRequestOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READINESSPATH, "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the anonymous request completes")
    Do $$$AssertEquals(tStatus, 200, "readiness answers an anonymous caller")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "no-store", "and forbids caching so a stale {installed:true} cannot outlive the state it reported")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tObj), "the body parses as one JSON object")
    Do $$$AssertEquals(..KeyList(tObj), "installed,state,version", "carrying exactly the three keys AD-45 permits")
    Do $$$AssertEquals(tObj.state, "installed", "and this instance is installed")
}

/// <p>The object's keys, sorted and comma-separated -- an assertion about the whole key set
/// rather than about the keys a test remembered to look for, so a fourth key added to the
/// response is red rather than unnoticed.</p>
Method KeyList(pObject As %DynamicObject) As %String
{
    Kill tNames
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames(tKey) = ""
    }
    Set tOut = ""
    Set tName = $Order(tNames(""))
    While tName '= "" {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
        Set tName = $Order(tNames(tName))
    }
    Quit tOut
}

}
