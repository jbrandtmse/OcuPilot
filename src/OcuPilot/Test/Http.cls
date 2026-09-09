/// <p>Over-the-wire HTTP test helper for the OcuPilot REST API. Delivered here, ready to
/// call, with <b>no consumer in this story</b> — <code>/api/ocupilot</code> does not exist
/// until Story 1.5 creates the two web applications; that story is this class's first
/// consumer, and it is what replays the <class>OcuPilot.Kernel.EntityId</class> corpus
/// over the wire.</p>
/// <p>Every accessor reads an override from <code>^OcuPilotTest</code> first, falling
/// back to the class parameter defaults below, so a CI run against a differently
/// addressed instance needs no code change.</p>
Class OcuPilot.Test.Http Extends %UnitTest.TestCase
{

/// <p>Default test server hostname. Override via <code>^OcuPilotTest("Server")</code>.</p>
Parameter TESTSERVER = "localhost";

/// <p>Default test server port — this repository's <code>ocupilot-iris</code> web port
/// (see CLAUDE.md), not the IRIS default. Override via <code>^OcuPilotTest("Port")</code>.</p>
Parameter TESTPORT = 52774;

/// <p>Default test username. Override via <code>^OcuPilotTest("Username")</code>.</p>
Parameter TESTUSERNAME = "_SYSTEM";

/// <p>Default test password. Override via <code>^OcuPilotTest("Password")</code>.</p>
Parameter TESTPASSWORD = "SYS";

/// <p>Base path of the OcuPilot REST API web application (Story 1.5).</p>
Parameter BASEPATH = "/api/ocupilot";

/// <p>Get the configured test server hostname.</p>
ClassMethod GetTestServer() As %String
{
    Quit $Get(^OcuPilotTest("Server"), ..#TESTSERVER)
}

/// <p>Get the configured test server port.</p>
ClassMethod GetTestPort() As %Integer
{
    Quit +$Get(^OcuPilotTest("Port"), ..#TESTPORT)
}

/// <p>Get the configured test username.</p>
ClassMethod GetTestUsername() As %String
{
    Quit $Get(^OcuPilotTest("Username"), ..#TESTUSERNAME)
}

/// <p>Get the configured test password.</p>
ClassMethod GetTestPassword() As %String
{
    Quit $Get(^OcuPilotTest("Password"), ..#TESTPASSWORD)
}

/// <p>Make an HTTP request to the OcuPilot REST API and parse the JSON response.</p>
/// <p>Handles authentication and the web-application base path automatically. Returns a
/// %Status indicating transport-level success; the caller reads <var>pStatusCode</var>
/// and <var>pBody</var> for the application-level result.</p>
/// @param pMethod HTTP method (GET, PUT, POST, DELETE)
/// @param pPath Request path relative to the web application root (e.g., "/" or "/health")
/// @param pStatusCode Output: HTTP status code from the response
/// @param pBody Output: parsed JSON response body as %DynamicObject (or a plain string for a non-JSON body)
/// @param pRequestBody Optional: request body string to send
/// @param pContentType Optional: request Content-Type header (defaults to application/json)
/// @param pBinaryBody Optional: binary stream to send as the request body, overriding pRequestBody
ClassMethod MakeRequest(pMethod As %String, pPath As %String, Output pStatusCode As %Integer, Output pBody As %DynamicObject, pRequestBody As %String = "", pContentType As %String = "", pBinaryBody As %Stream.Object = "") As %Status
{
    Set tSC = $$$OK
    Set pStatusCode = 0
    Set pBody = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = ..GetTestServer()
        Set tReq.Port = ..GetTestPort()
        Set tReq.Username = ..GetTestUsername()
        Set tReq.Password = ..GetTestPassword()
        If pContentType '= "" {
            Set tReq.ContentType = pContentType
        } Else {
            Set tReq.ContentType = "application/json"
        }
        If $IsObject(pBinaryBody) {
            Do pBinaryBody.Rewind()
            Do tReq.EntityBody.CopyFrom(pBinaryBody)
        } ElseIf pRequestBody '= "" {
            Do tReq.EntityBody.Write(pRequestBody)
        }
        Set tFullPath = ..#BASEPATH _ pPath
        If pMethod = "GET" {
            Set tSC = tReq.Get(tFullPath)
        } ElseIf pMethod = "PUT" {
            Set tSC = tReq.Put(tFullPath)
        } ElseIf pMethod = "DELETE" {
            Set tSC = tReq.Delete(tFullPath)
        } ElseIf pMethod = "POST" {
            Set tSC = tReq.Post(tFullPath)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "Unsupported HTTP method: " _ pMethod)
        }
        If $$$ISERR(tSC) Quit
        Set pStatusCode = tReq.HttpResponse.StatusCode
        Set tBodyStr = tReq.HttpResponse.Data.Read()
        If tBodyStr '= "" {
            Set tFirstChar = $Extract($ZStrip(tBodyStr, "<W"), 1)
            If (tFirstChar = "{") || (tFirstChar = "[") {
                Set pBody = ##class(%DynamicAbstractObject).%FromJSON(tBodyStr)
            } Else {
                Set pBody = $ZStrip(tBodyStr, "<>W")
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make a raw HTTP request and return the response body string unparsed, so a caller
/// can scan it for a <code>}{</code> double-envelope concatenation marker — the same
/// check <class>OcuPilot.Test.Envelope</class> runs in-process, replayed over the wire.</p>
ClassMethod RawRequest(pMethod As %String, pPath As %String, pBody As %String, pContentType As %String, Output pStatus As %Integer) As %String [ Internal ]
{
    Set pStatus = 0
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ..GetTestServer()
    Set tReq.Port = ..GetTestPort()
    Set tReq.Username = ..GetTestUsername()
    Set tReq.Password = ..GetTestPassword()
    Set tReq.ContentType = pContentType
    If pBody '= "" Do tReq.EntityBody.Write(pBody)
    Set tFullPath = ..#BASEPATH _ pPath
    If pMethod = "POST" {
        Do tReq.Post(tFullPath)
    } ElseIf pMethod = "PUT" {
        Do tReq.Put(tFullPath)
    } ElseIf pMethod = "GET" {
        Do tReq.Get(tFullPath)
    } ElseIf pMethod = "DELETE" {
        Do tReq.Delete(tFullPath)
    } Else {
        ; Mirrors MakeRequest's own guard against an unsupported method: quit before
        ; reading a response that was never requested, rather than falling through to
        ; tReq.HttpResponse below, which no Get/Post/Put/Delete call ever populated.
        Quit ""
    }
    Set pStatus = tReq.HttpResponse.StatusCode
    Quit tReq.HttpResponse.Data.Read()
}

}
