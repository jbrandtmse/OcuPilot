/// <p>Over-the-wire HTTP test helper for OcuPilot's web applications.</p>
/// <p><method>MakeRequest</method> and <method>RawRequest</method> address the REST API
/// alone: they prefix <parameter>BASEPATH</parameter> and always send the configured
/// credentials. <method>AbsoluteRequest</method> (Story 1.5, this class's first consumer)
/// addresses <b>any</b> path from the origin root, sends no credentials or a
/// caller-supplied principal, returns the response headers, and reads a body large enough
/// for a built client bundle — the three things the shell application, the anonymous API
/// refusal and the two purpose-built API principals each need and none of which the two
/// older helpers can express. Story 1.6 added an optional request body, content type and
/// extra headers to it, which is what lets one helper send a JSON login body, an
/// <code>Authorization: Bearer</code> or a <code>Cookie</code>.</p>
/// <p>Every accessor reads an override from <code>^OcuPilotTest</code> first, falling
/// back to the class parameter defaults below, so a CI run against a differently
/// addressed instance needs no code change.</p>
Class OcuPilot.Test.Http Extends %UnitTest.TestCase
{

/// <p>Default test server hostname. Override via <code>^OcuPilotTest("Server")</code>.</p>
Parameter TESTSERVER = "localhost";

/// <p>Last-resort test server port. <method>GetTestPort</method> prefers the instance's own
/// configured web-server port and falls back to this only when that read fails, so the
/// vendor default is the right value here rather than this repository's host-side mapping
/// (52774): the suite runs <b>inside</b> the instance, where the host mapping does not
/// exist. Override via <code>^OcuPilotTest("Port")</code>.</p>
Parameter TESTPORT = 52773;

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

/// <p>The port these tests address, resolved in three steps: the
/// <code>^OcuPilotTest("Port")</code> override, then the instance's <b>own</b> configured
/// web-server port (<code>Config.Startup</code>'s <code>WebServerPort</code>), then
/// <parameter>TESTPORT</parameter>.</p>
/// <p><b>Why the instance's own port and not this repository's published one.</b> A
/// <code>%UnitTest</code> run executes inside the IRIS instance, so a request it makes goes
/// to <code>localhost</code> <i>in the container</i>, where only the container-internal port
/// exists — the host-side mapping (52774 here) is not reachable from there, and a request to
/// it fails with "Unable to open TCP/IP socket". Reading the configuration keeps the helper
/// correct on any instance, published mapping or not.</p>
ClassMethod GetTestPort() As %Integer
{
    Set tOverride = $Get(^OcuPilotTest("Port"))
    If tOverride '= "" Quit +tOverride
    Set tPort = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Startup).Get(.tProps)
        If $$$ISOK(tSC) Set tPort = $Get(tProps("WebServerPort"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tPort = ""
    }
    If +tPort > 0 Quit +tPort
    Quit ..#TESTPORT
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

/// <p>Request <var>pPath</var> — <b>absolute from the origin root</b>, never prefixed with
/// <parameter>BASEPATH</parameter> — and return the raw response.</p>
/// <p><var>pUsername</var> empty means <b>send no credentials at all</b>, which is how the
/// unauthenticated shell application and the API's anonymous refusal are observed; any other
/// value is sent as Basic credentials, which is how a purpose-built principal is driven
/// without <code>New $ROLES</code> impersonation.</p>
/// <p><var>pBody</var> is read to the end of the stream in chunks rather than by a single
/// <code>Read()</code>, which returns at most about 32 KB and would silently truncate a
/// client bundle. <var>pHeaders</var> comes back subscripted by <b>upper-case</b> header
/// name, the form <class>%Net.HttpResponse</class> stores them in.</p>
/// <p><b>Story 1.6 added the last three parameters</b>, so one helper can send a request
/// body, a content type and an arbitrary header — a <code>Authorization: Bearer</code>, a
/// <code>Cookie</code>, or neither. They are optional and appended, so every Story 1.5
/// caller keeps its signature. <var>pExtraHeaders</var> is an array subscripted by header
/// name; each entry becomes one <code>SetHeader</code> call. A fresh
/// <class>%Net.HttpRequest</class> per call is what makes the cookie behaviour testable:
/// the class stores response cookies on the instance, so nothing a previous call received
/// is replayed unless this caller names it here.</p>
/// @param pMethod HTTP method (GET, HEAD, POST, PUT, DELETE)
/// @param pPath Absolute request path from the origin root (e.g. "/ocupilot/index.html")
/// @param pUsername Basic-auth user, or "" to send no credentials
/// @param pPassword Basic-auth password, ignored when pUsername is ""
/// @param pStatusCode Output: HTTP status code
/// @param pBody Output: the complete response body, unparsed
/// @param pHeaders Output: response headers, subscripted by upper-case name
/// @param pRequestBody Optional: request body to send, or "" for none. Written to the entity body verbatim, so it must already be the bytes to send — ASCII, or UTF-8 the caller encoded itself
/// @param pContentType Optional: request Content-Type, applied only when a body is sent
/// @param pExtraHeaders Optional ByRef: extra request headers, subscripted by header name
/// @param pTimeout Optional: seconds the client waits for an answer; 0 keeps the class default of 30
ClassMethod AbsoluteRequest(pMethod As %String, pPath As %String, pUsername As %String = "", pPassword As %String = "", Output pStatusCode As %Integer, Output pBody As %String, Output pHeaders, pRequestBody As %String = "", pContentType As %String = "", ByRef pExtraHeaders, pTimeout As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Set pStatusCode = 0
    Set pBody = ""
    Kill pHeaders
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = ..GetTestServer()
        Set tReq.Port = ..GetTestPort()
        If +pTimeout > 0 Set tReq.Timeout = +pTimeout
        If pUsername '= "" {
            Set tReq.Username = pUsername
            Set tReq.Password = pPassword
        }
        Set tHeaderName = ""
        For {
            Set tHeaderName = $Order(pExtraHeaders(tHeaderName))
            If tHeaderName = "" Quit
            Set tSC = tReq.SetHeader(tHeaderName, pExtraHeaders(tHeaderName))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If pRequestBody '= "" {
            If pContentType '= "" Set tReq.ContentType = pContentType
            Do tReq.EntityBody.Write(pRequestBody)
        }
        If pMethod = "GET" {
            Set tSC = tReq.Get(pPath)
        } ElseIf pMethod = "HEAD" {
            Set tSC = tReq.Head(pPath)
        } ElseIf pMethod = "POST" {
            Set tSC = tReq.Post(pPath)
        } ElseIf pMethod = "PUT" {
            Set tSC = tReq.Put(pPath)
        } ElseIf pMethod = "DELETE" {
            Set tSC = tReq.Delete(pPath)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "Unsupported HTTP method: " _ pMethod)
        }
        If $$$ISERR(tSC) Quit

        Set pStatusCode = tReq.HttpResponse.StatusCode
        Merge pHeaders = tReq.HttpResponse.Headers
        Set tData = tReq.HttpResponse.Data
        If $IsObject(tData) {
            Do tData.Rewind()
            While 'tData.AtEnd {
                Set pBody = pBody _ tData.Read(32000)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
