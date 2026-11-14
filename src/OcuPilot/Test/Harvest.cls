/// <p>Pins <class>OcuPilot.Port.Harvest.Handler</class> and <class>OcuPilot.Port.HarvestPort</class>
/// (AD-23): the render signature, the one-envelope outcome for every case
/// <class>OcuPilot.Test.HarvestFixture</class> offers, the port's own gate, and the restoring of the
/// caller's state. <class>OcuPilot.Test.HarvestRouteFixture</class> stands in for the route side
/// over <method>OcuPilot.Test.Dispatch.InvokeHandler</method>.</p>
/// <p>Needs the install namespace and nothing else; each test resets both fixtures and
/// <class>OcuPilot.Test.ScreenGate</class>.</p>
Class OcuPilot.Test.Harvest Extends %UnitTest.TestCase
{

/// <p>The last <method>Drive</method>'s answer, by <code>result</code>, <code>http</code>,
/// <code>fault</code> and <code>status</code>. Not typed properties: an object-typed property
/// turns an empty answer into a new empty object.</p>
Property Got [ MultiDimensional ];

/// <p>The result the last <method>Drive</method> answered.</p>
Method GotResult()
{
    Quit $Get(i%Got("result"))
}

/// <p>The HTTP status the last <method>Drive</method> answered.</p>
Method GotHttp()
{
    Quit $Get(i%Got("http"))
}

/// <p>The fault the last <method>Drive</method> answered, or <code>""</code>.</p>
Method GotFault()
{
    Quit $Get(i%Got("fault"))
}

/// <p>The status the last <method>Drive</method> returned.</p>
Method GotStatus()
{
    Quit $Get(i%Got("status"))
}

Method OnBeforeOneTest() As %Status
{
    Do ..ResetFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ResetFixtures()
    Quit $$$OK
}

Method ResetFixtures()
{
    Do ##class(OcuPilot.Test.HarvestFixture).Reset()
    Do ##class(OcuPilot.Test.HarvestPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p>The one pair the shipped bodies are declared against; <code>%UnitTest</code> holds it.</p>
ClassMethod Pairs() As %List
{
    Quit $ListBuild($ListBuild("%Development", "USE"))
}

/// <p>Invoke <var>pMethod</var> of the fixture through the port and keep the answer.</p>
Method Drive(pMethod As %String, ByRef pQuery, pBody = "", pPairs As %List = {..Pairs()}, pHandler As %String = "OcuPilot.Test.HarvestFixture")
{
    Kill tResult, tHttp, tFault
    Set tSC = ##class(OcuPilot.Test.HarvestPortFixture).Invoke(pHandler, pMethod, pPairs, .pQuery, pBody, .tResult, .tHttp, .tFault)
    Set i%Got("status") = tSC
    Set i%Got("result") = $Get(tResult)
    Set i%Got("http") = $Get(tHttp)
    Set i%Got("fault") = $Get(tFault)
}

/// <p>Assert the last answer is <var>pHttp</var> and the fault <var>pCode</var>, and that the one
/// fault line is the raw status text the wire did not carry.</p>
Method AssertFault(pHttp As %Integer, pCode As %String, pLabel As %String)
{
    Do $$$AssertEquals(..GotHttp(), pHttp, pLabel _ ": HTTP status")
    Do $$$AssertTrue($IsObject(..GotFault()), pLabel _ ": a fault is answered")
    If '$IsObject(..GotFault()) Quit
    Do $$$AssertEquals(..GotFault().%Get("code"), pCode, pLabel _ ": fault code")
    Do $$$AssertStatusNotOK(..GotStatus(), pLabel _ ": the returned status is an error")
    Do $$$AssertEquals(..GotResult(), "", pLabel _ ": no result")
}

Method TestRenderSignatureIsTheVendors()
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("OcuPilot.Port.Harvest.Handler||RenderResponseBody")
    Do $$$AssertTrue($IsObject(tMethod), "the base defines RenderResponseBody")
    If '$IsObject(tMethod) Quit
    Do $$$AssertTrue(tMethod.ClassMethod, "it is a class method")
    Do $$$AssertEquals(tMethod.FormalSpec, "pStatus:%Status,pMsgPart:%DynamicArray,pResPart:%DynamicObject", "the vendor's formal spec")
    Do $$$AssertEquals(tMethod.ReturnType, "%Library.Status", "it returns a status")
}

Method TestSuccessAnswersTheBareResult()
{
    Do ..Drive("Success")
    Do $$$AssertStatusOK(..GotStatus(), "the call succeeds")
    Do $$$AssertEquals(..GotHttp(), 200, "HTTP 200")
    Do $$$AssertEquals(..GotResult().%ToJSON(), "{""a"":1}", "the result is exactly the render's result part, with no wrapper")
    Do $$$AssertEquals(..GotFault(), "", "no fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestFixture).Runs(), 1, "the body ran once")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 0, "nothing is logged")
}

Method TestVerbatimTaskListAnswersTheEnvelope()
{
    Do ..Drive("TaskList")
    Do $$$AssertStatusOK(..GotStatus(), "the call succeeds")
    Do $$$AssertEquals(..GotHttp(), 200, "HTTP 200")
    Set tIter = ..GotResult().%GetIterator()
    While tIter.%GetNext(.tKey) {
        Set tFound(tKey) = 1
    }
    Set tKeys = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tFound(tKey))
        If tKey = "" Quit
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "count,tasks", "exactly the keys tasks and count")
    Do $$$AssertEquals(..GotResult().count, ..GotResult().tasks.%Size(), "count is the size of tasks")
}

Method TestVendorTextNeverReachesTheWire()
{
    Do ..Drive("Failure")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "failure")
    Do $$$AssertEquals(..GotFault().%Get("reason"), ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, "the generic reason")
    Do $$$AssertTrue(..GotFault().%ToJSON() '[ "vendor text X", "the vendor text is absent from the fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "one line is logged")
    Do $$$AssertTrue(##class(OcuPilot.Test.HarvestPortFixture).LogAt(1).status [ "vendor text X", "the raw text reaches the log")
}

Method TestProtectIsAnAccessRefusal()
{
    Do ..Drive("Protect")
    Do ..AssertFault(403, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, "protect")
    Do $$$AssertEquals(..GotFault().%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "slug forbidden")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "logged once")
}

Method TestRawStatusIsClassified()
{
    Do ..Drive("Absent")
    Do ..AssertFault(404, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "absent")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "logged once")
}

Method TestClassifiedStatusesAnswerTheirHttpStatus()
{
    Do ..Drive("Conflict")
    Do ..AssertFault(409, ##class(OcuPilot.Api.Error).#PORTCONFLICT, "conflict")
    Do ..Drive("Validation")
    Do ..AssertFault(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "validation")
    Do ..Drive("NotImplemented")
    Do ..AssertFault(501, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "not implemented")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 3, "each is logged once")
}

Method TestConsoleAndArgumentsReachTheirDestinations()
{
    Kill tQuery, tResult, tHttp, tFault, tConsole
    Set tSC = ##class(OcuPilot.Test.HarvestPortFixture).Invoke("OcuPilot.Test.HarvestFixture", "Console", ..Pairs(), .tQuery, "", .tResult, .tHttp, .tFault, .tConsole)
    Do $$$AssertStatusOK(tSC, "the console case answers")
    Do $$$AssertEquals($IsObject($Get(tConsole)), 1, "the console is an object")
    Do $$$AssertEquals($Get(tConsole).%Get(0), "note", "pConsole is the render's message part")
    Kill tResult, tHttp, tFault
    Set tSC = ##class(OcuPilot.Test.HarvestPortFixture).Invoke("OcuPilot.Test.HarvestFixture", "Args", ..Pairs(), .tQuery, "", .tResult, .tHttp, .tFault, , "one", "two")
    Do $$$AssertStatusOK(tSC, "the argument case answers")
    Do $$$AssertEquals(tResult.first _ "|" _ tResult.second, "one|two", "the arguments reach the body in order")
}

Method TestTwoRendersAreNeitherAnswered()
{
    Do ..Drive("Twice")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "two renders")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "logged once")
    Set tMessage = ##class(OcuPilot.Test.HarvestPortFixture).LogAt(1).message
    Do $$$AssertTrue((tMessage [ "OcuPilot.Test.HarvestFixture") && (tMessage [ "Twice") && (tMessage [ " 2 "), "the line names the handler, the method and the count: " _ tMessage)
}

Method TestNoRenderIsInternal()
{
    Do ..Drive("Never")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "no render")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "logged once")
}

Method TestHelperWorksWhileSwitched()
{
    Set tNamespace = $NAMESPACE
    Do ..Drive("Switched")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "switched")
    Do $$$AssertEquals(..GotFault().%Get("reason"), ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, "the generic reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 1, "one line is logged")
    Do $$$AssertTrue(##class(OcuPilot.Test.HarvestPortFixture).LogAt(1).status [ "vendor text X", "the raw text reached the log")
    Do $$$AssertTrue(##class(OcuPilot.Test.HarvestPortFixture).LogAt(1).status '[ "CLASS DOES NOT EXIST", "the helper resolved in %SYS")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "the caller's namespace")
}

Method TestNamespaceLeftSwitchedIsRestored()
{
    Set tNamespace = $NAMESPACE
    Do ..Drive("Strand")
    Do $$$AssertEquals(..GotHttp(), 200, "a render that returned in %SYS still answers")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "the caller is back in its own namespace")
    Do ..Drive("StrandFailure")
    Do ..AssertFault(404, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "stranded failure")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "back in its own namespace on a failure")
    Do ..Drive("Raise")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "raise")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "back in its own namespace after an exception")
}

Method TestCallerStateIsUnchangedOnEveryPath()
{
    New %request, %response, %session
    Set %request = "request0", %response = "response0", %session = "session0"
    Set tNamespace = $NAMESPACE
    Set tDevice = $IO
    For tCase = "Success", "Failure", "Twice", "Never", "Strand", "Raise", "Chatter", "NoSuchMethod" {
        Do ..Drive(tCase)
        Do $$$AssertEquals(%request _ "|" _ %response _ "|" _ %session, "request0|response0|session0", tCase _ ": the caller's three variables")
        Do $$$AssertEquals($NAMESPACE _ "|" _ $IO, tNamespace _ "|" _ tDevice, tCase _ ": namespace and device")
    }
    Do ..Drive("Success", , , "")
    Do $$$AssertEquals(%request _ "|" _ %response _ "|" _ %session, "request0|response0|session0", "a refused gate: the caller's three variables")
}

/// <p>The body that chatters still answers; the discard itself is observed over the wire in
/// <method>TestSingleEnvelopeOverTheRoute</method>.</p>
Method TestChatterBodyStillAnswers()
{
    Do ..Drive("Chatter")
    Do $$$AssertEquals(..GotHttp(), 200, "HTTP 200")
    Do $$$AssertEquals(..GotResult().%ToJSON(), "{""chatter"":true}", "the result")
}

Method TestRequestStubCarriesTheQueryAndTheBody()
{
    Set tQuery("k") = "v"
    Do ..Drive("Echo", .tQuery, {"x":1})
    Do $$$AssertEquals(..GotHttp(), 200, "HTTP 200 with a body")
    Do $$$AssertEquals(..GotResult().k, "v", "the query parameter")
    Do $$$AssertEquals(..GotResult().body.x, 1, "the JSON body")
    Do $$$AssertEquals(..GotResult().method, "POST", "a body makes the method POST")
    Kill tQuery
    Set tQuery("k") = "w"
    Do ..Drive("Echo", .tQuery, "{""y"":2}")
    Do $$$AssertEquals(..GotResult().body.y, 2, "a JSON text body")
    Kill tQuery
    Do ..Drive("Echo")
    Do $$$AssertEquals(..GotResult().method, "GET", "no body makes the method GET")
    Do $$$AssertEquals(..GotResult().%IsDefined("body"), 0, "and no body is read")
}

Method TestEmptyPairSetFailsClosed()
{
    Do ..Drive("Success", , , "")
    Do ..AssertFault(403, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "empty set")
    Do $$$AssertEquals(..GotFault().%IsDefined("detail"), 0, "no pair to name")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestFixture).Runs(), 0, "the body did not run")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 0, "a refusal is not logged")
}

Method TestWithheldPairIsNamed()
{
    Do ##class(OcuPilot.Test.HarvestPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ..Drive("Success")
    Do ..AssertFault(403, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "withheld pair")
    Do $$$AssertTrue(..GotFault().detail.failedPair [ "%Development", "the failed pair is named")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestFixture).Runs(), 0, "the body did not run")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 0, "a refusal is not logged")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Do ..Drive("Success")
    Do $$$AssertEquals(..GotHttp(), 200, "held, the body runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestFixture).Runs(), 1, "once")
}

Method TestNotAHandlerRunsNothing()
{
    Do ..Drive("ValidateBoolean", , , , "OcuPilot.Kernel.Utils")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "a class that is not a handler")
    Do ..Drive("NoSuchMethod")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "an absent method")
    Do ..Drive("Count")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "a private method")
    Do ..Drive("Success", , , , "OcuPilot.Test.NoSuchHandlerClass")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "an absent class")
    Do ..Drive("Run", , , , "OcuPilot.Test.HarvestOutsider")
    Do ..AssertFault(500, ##class(OcuPilot.Api.Error).#INTERNAL, "a public method of a class outside the handler base")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestFixture).Runs(), 0, "nothing ran, the outsider's counter included")
    Do $$$AssertEquals(##class(OcuPilot.Test.HarvestPortFixture).LogCount(), 5, "each refusal is logged")
}

Method TestRenderOutsideThePortRecordsNothing()
{
    New %response
    Set tSC = ##class(OcuPilot.Test.HarvestFixture).RenderResponseBody($$$OK, , {"a":1})
    Do $$$AssertStatusNotOK(tSC, "%response undefined: an error status")
    Set %response = ##class(%CSP.Response).%New()
    Set tCookie = ""
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    Set tSC = ##class(OcuPilot.Test.HarvestFixture).RenderResponseBody($$$OK, , {"a":1})
    Set tEnd = $$EndCapture^%SYS.Capture(tCookie, .tLines)
    Do $$$AssertStatusOK(tCaptureSC, "the capture opened")
    Do $$$AssertStatusNotOK(tSC, "a plain response: an error status")
    Do $$$AssertEquals(tLines.%Size(), 0, "nothing was written")
}

/// <p>No class that extends the base writes the response itself, and the scan found one.</p>
Method TestNoHarvestedBodyNamesTheResponseWriter()
{
    Set tBase = "OcuPilot.Port.Harvest.Handler"
    Set tScanned = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %Dictionary.CompiledClass WHERE ID %STARTSWITH ?", "OcuPilot.")
    While tRS.%Next() {
        Set tClass = tRS.%GetData(1)
        If (tClass = tBase) || '$ClassMethod(tClass, "%Extends", tBase) Continue
        Set tScanned = tScanned + 1
        Set tMethods = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledMethod WHERE parent = ? AND Origin = ?", tClass, tClass)
        While tMethods.%Next() {
            Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(tClass _ "||" _ tMethods.%GetData(1))
            If '$IsObject(tMethod) Continue
            Set tText = ""
            Do tMethod.Implementation.Rewind()
            While 'tMethod.Implementation.AtEnd {
                Set tText = tText _ tMethod.Implementation.Read(32000)
            }
            For tToken = "OcuPilot.Api.Response", "OcuPilot.Api.Error", "%response" {
                Do $$$AssertTrue(tText '[ tToken, tClass _ "." _ tMethods.%GetData(1) _ " does not name " _ tToken)
            }
        }
    }
    Do $$$AssertTrue(tScanned > 0, "at least one class extending the base was scanned")
}

Method TestSingleEnvelopeOverTheRoute()
{
    Do ..AssertWire("Twice", 500)
    Do $$$AssertEquals(..GotResult().code, ##class(OcuPilot.Api.Error).#INTERNAL, "the INTERNAL fault, not either render")
    Do $$$AssertEquals(..GotResult().error, ##class(OcuPilot.Api.Error).#SERVERERROR, "its slug")
    Do ..AssertWire("Chatter", 200)
    Do $$$AssertEquals(..GotResult().chatter, 1, "the result, with the device output discarded")
}

/// <p>Drive <var>pCase</var> through the route fixture and assert one parseable object with no
/// <code>}{</code> and status <var>pStatus</var>; the object is left in <method>GotResult</method>.</p>
Method AssertWire(pCase As %String, pStatus As %Integer)
{
    Set i%Got("result") = ""
    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Test.HarvestRouteFixture", "Handle", {"case":(pCase)}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, pCase _ ": the handler ran")
    Do $$$AssertEquals(tStatus, pStatus, pCase _ ": HTTP status")
    Do $$$AssertEquals((tBody [ "}{"), 0, pCase _ ": no }{ concatenation in the body")
    Try {
        Set i%Got("result") = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Do $$$AssertTrue(0, pCase _ ": the body parses as one object (was: " _ $Extract(tBody, 1, 120) _ ")")
    }
}

}
