/// <p><method>OcuPilot.Port.AdminPort.Invoke</method>'s synchronous sequence against the real
/// <code>WebApp.App</code> endpoint: an absent application, the identifier and the row cap
/// reaching the endpoint, and the caller's own CSP objects and namespace surviving the call; and,
/// against the real <code>Security.Audit.Enabled</code> endpoint, the refusal of a read type the
/// endpoint leaves to the vendor base class.</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class> with no endpoint override, so the
/// vendor sequence is the production one. Needs <code>%Admin_Secure:U</code> and at least three
/// web applications on the instance. Reads only; nothing is created.</p>
Class OcuPilot.Test.AdminPortSync Extends %UnitTest.TestCase
{

/// <p>A web application path no instance carries.</p>
Parameter ABSENTAPP = "/ocupilot-test/no-such-application";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>A GET for an application that does not exist fails 404 with the not-found code, and never
/// reads as an empty success.</p>
Method TestAnAbsentWebApplicationFailsNotFound()
{
    Set tQuery("name") = ..#ABSENTAPP
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp.App", "GET", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an absent application is a failure")
    Do $$$AssertEquals(tHttp, 404, "with the endpoint's 404")
    Do $$$AssertEquals(tResult, "", "and no result")
    Do $$$AssertTrue($IsObject(tFault), "and a fault")
    If $IsObject(tFault) {
        Do $$$AssertEquals(tFault.error, "not_found", "on the not_found slug")
        Do $$$AssertEquals(tFault.code, "PORT.NOTFOUND", "with the port's not-found code")
    }
}

/// <p>The query parameter reaches the endpoint's identifying property before <code>Run()</code>
/// starts, and the call returns that application.</p>
Method TestTheIdentifierReachesTheEndpointBeforeRun()
{
    Set tQuery("name") = "/csp/sys"
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp.App", "GET", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the call succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("name"), "/csp/sys", "Name was populated when Run started")
    Do $$$AssertTrue($IsObject(tResult), "and the application's properties are returned")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.CookiePath, "/csp/sys/", "for that application")
    }
    Do $$$AssertEquals(tFault, "", "with no fault")
}

/// <p><code>maxRows</code> reaches the class query, so the list stops at the cap.</p>
Method TestTheRowCapReachesTheQuery()
{
    Set tQuery("maxRows") = 2
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp.App", "LIST", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list succeeds")
    Do $$$AssertTrue($IsObject(tResult), "and returns rows")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.%Size(), 2, "exactly as many as maxRows allows (" _ tResult.%Size() _ " returned)")
    }
}

/// <p>The caller's own <code>%request</code>, <code>%response</code> and <code>%session</code>,
/// and its namespace, are unchanged after a success and after a failure.</p>
Method TestTheCallersCspObjectsAndNamespaceAreUntouched()
{
    New %request, %response, %session
    Set tStartNs = $NAMESPACE
    Set tRequest = ##class(%CSP.Request).%New()
    Set tRequest.Method = "POST"
    Set tRequest.URL = "/caller/own/url"
    Set tResponse = ##class(%CSP.Response).%New()
    Set tResponse.Status = "299 Caller Fixture"
    Set tSession = {"Username": "caller-fixture"}
    Set %request = tRequest
    Set %response = tResponse
    Set %session = tSession

    Set tQuery("name") = "/csp/sys"
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp.App", "GET", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the successful call completes")
    Do ..AssertCallerUntouched(tRequest, tResponse, tSession, tStartNs, "after a success")

    Set tQuery("name") = ..#ABSENTAPP
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("WebApp.App", "GET", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the failing call fails")
    Do ..AssertCallerUntouched(tRequest, tResponse, tSession, tStartNs, "after a failure")
}

Method AssertCallerUntouched(pRequest As %CSP.Request, pResponse As %CSP.Response, pSession As %DynamicObject, pNamespace As %String, pWhen As %String)
{
    Do $$$AssertEquals($NAMESPACE, pNamespace, pWhen _ ": the namespace is the caller's")
    Do $$$AssertTrue(%request = pRequest, pWhen _ ": %request is the caller's own object")
    Do $$$AssertTrue(%response = pResponse, pWhen _ ": %response is the caller's own object")
    Do $$$AssertTrue(%session = pSession, pWhen _ ": %session is the caller's own object")
    Do $$$AssertEquals(%request.URL, "/caller/own/url", pWhen _ ": the caller's request URL is unchanged")
    Do $$$AssertEquals(%response.Status, "299 Caller Fixture", pWhen _ ": the caller's response status is unchanged")
    Do $$$AssertEquals(%response.GetHeader("Location"), "", pWhen _ ": no header was added to the caller's response")
    Do $$$AssertEquals(%session.Username, "caller-fixture", pWhen _ ": the caller's session is unchanged")
}

/// <p>A read type the endpoint leaves to the vendor base class is refused 501 rather than
/// answered with the base class's empty <code>{}</code>: <code>Security.Audit.Enabled</code>
/// implements <code>RunGet</code> but not <code>RunList</code>, so its <code>LIST</code> is
/// refused and its <code>GET</code> returns the real payload.</p>
Method TestAnUnimplementedReadTypeIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.Audit.Enabled", "LIST", , , .tListResult, .tListHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a LIST the endpoint does not implement fails")
    Do $$$AssertEquals(tListHttp, 501, "at 501")
    Do $$$AssertEquals(tListResult, "", "with no result")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "PORT.NOTIMPLEMENTED"), "on the not-implemented code")

    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.Audit.Enabled", "GET", , , .tGetResult, .tGetHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the same endpoint's GET succeeds")
    Do $$$AssertEquals(tGetHttp, 200, "at 200")
    Do $$$AssertTrue($IsObject(tGetResult) && tGetResult.%IsDefined("Enabled"), "and answers with its payload")
}

}
