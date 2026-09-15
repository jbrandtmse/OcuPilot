/// <p><method>OcuPilot.Port.AdminPort.Invoke</method>'s outcome rules over
/// <class>OcuPilot.Test.EndpointFixture</class>: the step order, the gate, every failure shape
/// the sequence turns into a fault, the verification refusal, and the async poll's terminal and
/// timeout answers from canned <code>AsyncResult</code> answers.</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class>. The only vendor code that runs is
/// the verification probe, the output capture and the dictionary lookups; no vendor endpoint's
/// <code>Run()</code> executes, nothing is queued, and nothing on the instance changes. Needs
/// <code>%Admin_Operate:U</code> or <code>%Admin_Manage:U</code>, the fixture's
/// <code>ResourcesOR()</code>, for every test that does not arm the gate.</p>
Class OcuPilot.Test.AdminPortFault Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.ProbeFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Invoke the endpoint fixture as a GET with <code>name</code> seeded.</p>
Method InvokeFixture(pMode As %String, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode(pMode)
    Set tQuery("name") = "fixture-item"
    Quit ##class(OcuPilot.Test.PortFixture).Invoke("Fixture.Endpoint", "GET", .tQuery, , .pResult, .pHttp, .pFault)
}

Method AssertFault(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject, pExpectedHttp As %Integer, pSlug As %String, pCode As %String, pWhat As %String)
{
    Do $$$AssertStatusNotOK(pSC, pWhat _ ": the call fails")
    Do $$$AssertEquals(pHttp, pExpectedHttp, pWhat _ ": HTTP status")
    Do $$$AssertTrue($IsObject(pFault), pWhat _ ": a fault is returned")
    If $IsObject(pFault) {
        Do $$$AssertEquals(pFault.error, pSlug, pWhat _ ": slug")
        Do $$$AssertEquals(pFault.code, pCode, pWhat _ ": code")
        Do $$$AssertNotEquals(pFault.reason, "", pWhat _ ": a written reason")
    }
}

/// <p>The endpoint is constructed at version 2 with the type the suffix names, and its calls
/// run in <code>Main()</code>'s order with <code>IsRunningAsync</code> 0, the identifier
/// populated and the session stub naming the calling user when <code>Run()</code> starts.</p>
Method TestTheVendorStepsRunInMainsOrder()
{
    Set tSC = ..InvokeFixture("ok", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the call succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("apiVersion"), 2, "constructed at ApiVersion 2")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("type"), 1, "with the type TYPEGET names")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("trace"), "ResourcesOR,SaveQueryParams,ValidateQueryParams,ValidateRequest,ValidateSemantics,ShouldRunAsync,Run", "the steps run in Main's order")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("asyncAtRun"), 0, "IsRunningAsync is 0 when Run starts")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("nameAtRun"), "fixture-item", "the seeded query parameter reached the endpoint")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("sessionUserAtRun"), $USERNAME, "the session stub names the calling user")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.fixture = "ok"), "the result is the endpoint's return value")
}

/// <p>A caller holding none of <code>ResourcesOR()</code> is refused 403 before the query
/// parameters are validated and before <code>Run()</code>.</p>
Method TestACallerHoldingNoListedResourceIsRefused()
{
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsResource(0)
    Set tSC = ..InvokeFixture("ok", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 403, "forbidden", "PORT.ACCESSDENIED", "gate refusal")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("trace"), "ResourcesOR", "neither ValidateQueryParams nor Run executed")
}

/// <p>An endpoint that sets a non-2xx status and leaves its status OK has failed.</p>
Method TestANon2xxStatusUnderAnOkStatusIsAFailure()
{
    Set tSC = ..InvokeFixture("notfound", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 404, "not_found", "PORT.NOTFOUND", "404 with an OK status")
    Do $$$AssertEquals(tResult, "", "and no success result is returned")
}

/// <p>An error status under a 2xx is a 500 whose reason is OcuPilot's own, with the vendor text
/// in the log alone.</p>
Method TestAnErrorStatusUnder2xxIsA500()
{
    Set tSC = ..InvokeFixture("errorstatus", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 500, "server_error", "INTERNAL", "error status under 200")
    Set tText = ##class(OcuPilot.Test.EndpointFixture).#FAULTTEXT
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ tText), "the vendor text never reaches the fault")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) '[ tText, "nor the returned status")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ tText, "it reaches the log")
}

/// <p>A throw from <code>ValidateQueryParams()</code> is a 400 on the validation code, and
/// neither <code>ValidateRequest()</code> nor <code>Run()</code> executes.</p>
Method TestAQueryParameterThrowIsA400()
{
    Set tSC = ..InvokeFixture("queryinvalid", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 400, "validation_failed", "PORT.VALIDATION", "query parameter throw")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("trace"), "ResourcesOR,SaveQueryParams,ValidateQueryParams", "the sequence stopped at ValidateQueryParams")
}

/// <p>An error from <code>ValidateRequest()</code> is a 400 on the validation code, and neither
/// <code>ValidateSemantics()</code> nor <code>Run()</code> executes.</p>
Method TestARequestValidationErrorIsA400()
{
    Set tSC = ..InvokeFixture("requestinvalid", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 400, "validation_failed", "PORT.VALIDATION", "request validation error")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("trace"), "ResourcesOR,SaveQueryParams,ValidateQueryParams,ValidateRequest", "the sequence stopped at ValidateRequest")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ ##class(OcuPilot.Test.EndpointFixture).#FAULTTEXT), "the vendor text never reaches the fault")
}

/// <p>A poll the instance refuses is a failure carrying the poll's own HTTP status and code, and
/// the task, whose state was never read, is not forgotten.</p>
Method TestARefusedPollIsItsOwnFailure()
{
    Do ##class(OcuPilot.Test.PortFixture).SetCannedPollRefusal(404, ##class(OcuPilot.Test.EndpointFixture).#FAULTTEXT)
    Set tSC = ..InvokeFixture("accepted", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 404, "not_found", "PORT.NOTFOUND", "refused poll")
    Do $$$AssertEquals(tResult, "", "no result")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("polls"), 1, "the refusal ends the wait at the first poll")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("forgot"), "", "and no row is forgotten")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.EndpointFixture).#FAULTTEXT, "the poll's vendor text reaches the log")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.EndpointFixture).#TASKGUID, "naming the task")
}

/// <p>A <code>&lt;PROTECT&gt;</code> thrown from <code>Run()</code> is a 403.</p>
Method TestAProtectFromRunIsA403()
{
    Set tSC = ..InvokeFixture("protect", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 403, "forbidden", "PORT.ACCESSDENIED", "<PROTECT> from Run")
}

/// <p>What <code>Run()</code> writes to the device is captured by the port and never reaches
/// the caller's device; the result is still the endpoint's return value.</p>
Method TestDeviceOutputNeverReachesTheCaller()
{
    Set tLines = ""
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    Try {
        Set tSC = ..InvokeFixture("device", .tResult, .tHttp, .tFault)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $Data(tCookie) Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
    Do $$$AssertStatusOK(tCaptureSC, "the test's own capture started")
    Do $$$AssertStatusOK(tSC, "the call succeeds")
    Do $$$AssertTrue($IsObject(tLines), "the test's capture returned its lines")
    If $IsObject(tLines) {
        Do $$$AssertEquals(tLines.%ToJSON(), "[]", "nothing reached the caller's device")
    }
    Do $$$AssertTrue($IsObject(tResult) && (tResult.fixture = "device"), "the result is the endpoint's return value")
}

/// <p>An admin API reporting version 1 is refused before any endpoint is constructed, and the
/// reason names the version.</p>
Method TestAnApiAtVersionOneIsRefusedBeforeConstruction()
{
    Do ##class(OcuPilot.Test.PortFixture).SetAdminApiClass("OcuPilot.Test.AdminApiV1")
    Set tSC = ..InvokeFixture("ok", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 503, "unavailable", "PORT.UNAVAILABLE", "version 1")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.reason [ "version 1"), "the reason names the version")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "no endpoint was constructed")
}

/// <p>A probe that fails is refused before construction, the reason says the probe failed, and
/// the probe's detail goes to the log.</p>
Method TestAFailedProbeIsRefusedBeforeConstruction()
{
    Do ##class(OcuPilot.Test.ProbeFixture).SetMode("noconstruct")
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ..InvokeFixture("ok", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 503, "unavailable", "PORT.UNAVAILABLE", "failed probe")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.reason [ "probe"), "the reason names the probe")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "OcuPilot.Test.ProbeFixture", "the probe's detail reached the log")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "no endpoint was constructed")
}

/// <p>An endpoint name no compiled class answers, a malformed name, and a suffix outside the
/// accepted set are each refused before construction.</p>
Method TestAnUnknownEndpointOrSuffixIsRefusedBeforeConstruction()
{
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("No.Such.Endpoint", "GET", , , .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 501, "not_implemented", "PORT.NOTIMPLEMENTED", "unknown class")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp..App", "GET", , , .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 501, "not_implemented", "PORT.NOTIMPLEMENTED", "malformed name")

    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Fixture.Endpoint", "PUT", , , .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 501, "not_implemented", "PORT.NOTIMPLEMENTED", "suffix outside the accepted set")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Fixture.Endpoint", "INFO", , , .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 501, "not_implemented", "PORT.NOTIMPLEMENTED", "suffix the class declares no type for")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "no endpoint was constructed")
}

/// <p>A task that reaches <code>Failed</code> is a 500 whose reason is OcuPilot's own, and its
/// row is forgotten.</p>
Method TestAFailedTaskIsA500AndIsForgotten()
{
    Set tText = ##class(OcuPilot.Test.EndpointFixture).#FAULTTEXT
    Set tAnswer = {"State": "Failed", "TaskName": "GET /v2/ocupilot/fixture/endpoint", "Result": {}}
    Set tAnswer.FailureReason = "ERROR #5001: " _ tText
    Do ##class(OcuPilot.Test.PortFixture).SetCannedAnswer(tAnswer.%ToJSON())
    Set tSC = ..InvokeFixture("accepted", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 500, "server_error", "INTERNAL", "failed task")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ tText), "the failure reason's vendor text never reaches the fault")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ tText, "it reaches the log")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("forgot"), ##class(OcuPilot.Test.EndpointFixture).#TASKGUID, "the task's row is forgotten")
}

/// <p>A task that reaches <code>Finished</code> returns its <code>Result</code> as an ordinary
/// 200 success, and its row is forgotten.</p>
Method TestAFinishedTaskReturnsItsResultAndIsForgotten()
{
    Set tAnswer = {"State": "Finished", "TaskName": "GET /v2/ocupilot/fixture/endpoint", "FailureReason": "", "Result": [{"row": 1}]}
    Do ##class(OcuPilot.Test.PortFixture).SetCannedAnswer(tAnswer.%ToJSON())
    Set tSC = ..InvokeFixture("accepted", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a finished task is a success")
    Do $$$AssertEquals(tHttp, 200, "at 200, not the 202 that queued it")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.%ToJSON() = "[{""row"":1}]"), "carrying the task's Result")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("forgot"), ##class(OcuPilot.Test.EndpointFixture).#TASKGUID, "the task's row is forgotten")
}

/// <p>A task still running at the bound fails <code>PORT.TIMEOUT</code> after the bound has
/// passed, and its row is left alone.</p>
Method TestATaskStillRunningAtTheBoundTimesOut()
{
    Set tAnswer = {"State": "Running", "TaskName": "GET /v2/ocupilot/fixture/endpoint", "FailureReason": "", "Result": {}}
    Do ##class(OcuPilot.Test.PortFixture).SetCannedAnswer(tAnswer.%ToJSON())
    Do ##class(OcuPilot.Test.PortFixture).SetAsyncTimeout(1)
    Set tStart = $ZHorolog
    Set tSC = ..InvokeFixture("accepted", .tResult, .tHttp, .tFault)
    Set tElapsed = $ZHorolog - tStart
    Do ..AssertFault(tSC, tHttp, tFault, 503, "unavailable", "PORT.TIMEOUT", "timeout")
    Do $$$AssertEquals(tResult, "", "no partial result")
    Do $$$AssertTrue(tElapsed >= 1, "the port waited out the bound (" _ tElapsed _ "s)")
    Do $$$AssertTrue(tElapsed < 10, "and the bound is AsyncTimeout(), not the 30-second default (" _ tElapsed _ "s)")
    Do $$$AssertTrue(##class(OcuPilot.Test.PortFixture).Recorded("polls") > 1, "polling more than once")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("forgot"), "", "and did not forget a task that may still be running")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.EndpointFixture).#TASKGUID, "the log names the task left behind")
}

/// <p>DW-274. An erroring call whose declared backing-query pair set the caller holds <b>none</b>
/// of is answered 403 <code>PORT.ACCESSDENIED</code> naming the pair -- where it used to be a 500
/// naming nothing, because the vendor's own refusal never reaches this port.</p>
Method TestARefusedBackingQueryIsA403NamingThePair()
{
    Do ##class(OcuPilot.Test.PortFixture).SetQueryPairs("%Admin_Manage:USE|%DB_IRISSYS:WRITE")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Set tSC = ..InvokeFixture("errorstatus", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 403, "forbidden", "PORT.ACCESSDENIED", "a refused backing query")
    Set tDetail = ""
    If $IsObject(tFault) Set tDetail = tFault.%Get("detail")
    Do $$$AssertTrue($IsObject(tDetail), "the fault carries a structured detail")
    If $IsObject(tDetail) {
        Do $$$AssertEquals(tDetail.%Get("failedPair"), "%Admin_Manage:USE", "naming the set's first pair")
    }
    Do $$$AssertEquals(tResult, "", "and no result is returned")
}

/// <p>The same failure, for a caller who holds one pair of the set, keeps today's 500 and invents
/// no denial -- an any-of set, because the vendor's own check is an OR.</p>
Method TestACallerHoldingOneBackingQueryPairKeepsThe500()
{
    Do ##class(OcuPilot.Test.PortFixture).SetQueryPairs("%Admin_Manage:USE|%DB_IRISSYS:WRITE")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(1)
    Set tSC = ..InvokeFixture("errorstatus", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 500, "server_error", "INTERNAL", "a held pair set")
    Set tDetail = ""
    If $IsObject(tFault) Set tDetail = tFault.%Get("detail")
    Do $$$AssertTrue('$IsObject(tDetail), "and no failedPair is named for a caller the instance would have served")
}

/// <p>An endpoint no pair set has been established for keeps its 500 as well, whatever the caller
/// holds: the probe never guesses a requirement it was not told.</p>
Method TestAnEndpointWithNoDeclaredPairSetKeepsThe500()
{
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Set tSC = ..InvokeFixture("errorstatus", .tResult, .tHttp, .tFault)
    Do ..AssertFault(tSC, tHttp, tFault, 500, "server_error", "INTERNAL", "no declared pair set")
}

/// <p>A success is never probed: the pair set is read on the error path only, so a caller holding
/// none of it still reads a call that worked.</p>
Method TestASuccessIsNeverProbedForTheBackingQueryPair()
{
    Do ##class(OcuPilot.Test.PortFixture).SetQueryPairs("%Admin_Manage:USE|%DB_IRISSYS:WRITE")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Set tSC = ..InvokeFixture("ok", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the call still succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.fixture = "ok"), "with the endpoint's own result")
}

/// <p>The production table holds only what AD-29's discipline established, keyed by endpoint
/// <b>and</b> request type. A second entry is added by probing that endpoint, never by reading
/// this one across the other 69.</p>
/// <p>DW-274 -- the <b>production</b> <method>OcuPilot.Port.AdminPort.HoldsPair</method>, called
/// directly rather than through <class>OcuPilot.Test.PortFixture</class>.</p>
/// <p>Every other leg here arms <method>OcuPilot.Test.PortFixture.SetHoldsPair</method>, which
/// answers before <code>##super</code> ever runs -- so the shipped method's own parsing had no
/// executed test host at all, and it is the parsing that decides whether a pair is read
/// resource-first. Falsifiable even though <code>%UnitTest</code> runs as <code>%All</code>:
/// <code>$System.Security.Check</code> answers 0 for a name that is not a resource, so the
/// inverted spelling and the malformed ones are distinguishable from the sound one.</p>
/// <p>Mutation (Rule 19): swap the two <code>$Piece</code> indices in
/// <method>OcuPilot.Port.AdminPort.HoldsPair</method> -&gt; the first two assertions go red, while
/// every fixture-driven leg above stays green, which is the point.</p>
Method TestTheProductionPairCheckReadsResourceFirst()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).HoldsPair("%Admin_Manage:USE"), 1, "a sound pair is read resource first, and this account holds it")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).HoldsPair("USE:%Admin_Manage"), 0, "the inverted spelling is not a pair anyone holds")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).HoldsPair("%Admin_Manage"), 0, "a pair with no permission is refused rather than half-read")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).HoldsPair(""), 0, "and an empty one is refused")
}

Method TestTheDeclaredQueryPairsAreTheEstablishedOnes()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).QueryPairs("Process", "LIST"), "%Admin_Manage:USE|%DB_IRISSYS:WRITE", "Process/LIST declares the OR its query checks")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).QueryPairs("Process", "GET"), "", "and the entry is per request type, not per endpoint")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).QueryPairs("WebApp.App", "LIST"), "", "nor does an endpoint nothing established a set for carry one")
}

}
