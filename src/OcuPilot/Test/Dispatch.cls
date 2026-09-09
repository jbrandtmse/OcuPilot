/// <p>In-process dispatch harness for <class>OcuPilot.Api.Router</class> subclasses.</p>
/// <p>Story 1.5 creates the two web applications, so no HTTP endpoint exists yet for a
/// real integration test to call. This harness exercises the router's real runtime minus
/// the gateway hop: it builds standalone <class>%CSP.Request</class> /
/// <class>%CSP.Response</class> stubs (the same construction AD-2 uses for the vendor's own
/// endpoint objects), calls <code>DispatchRequest</code> directly — which runs the real
/// <code>UrlMap</code> matcher, the real <method>OnPreDispatch</method> and both real
/// framework-error overrides — and captures whatever the router writes to the response
/// device, unparsed, so <class>OcuPilot.Test.Envelope</class>'s <code>}{</code> check runs
/// against the literal wire body rather than something a JSON parser already forgave.</p>
/// <p>The capture uses a bound mnemonic I/O space (<method>Redirects</method>, below) rather
/// than a real device or file — <code>Use tNull::("^"_$ZNAME)</code> only resolves those
/// labels when they live in the routine <i>currently executing</i>, which is why this
/// class's capture and its label block must stay together rather than being factored into
/// a shared base class.</p>
Class OcuPilot.Test.Dispatch Extends %RegisteredObject
{

/// <p>Dispatch <var>pMethod</var> <var>pUrl</var> against <var>pRouterClass</var> (a class
/// name naming an <class>OcuPilot.Api.Router</class> subclass) in-process.</p>
/// <p><var>pParams</var>, when supplied, is a flat <class>%DynamicObject</class> of query
/// parameters set on the request before dispatch (e.g. <code>{"ns": ("HSCUSTOM")}</code>) —
/// this is how a test drives <code>?ns=</code> and <class>OcuPilot.Test.RouterFixture</class>'s
/// fixture-identity override without a real query string.</p>
/// <p>Returns the dispatched <class>%Status</class>; <var>pBody</var> is the captured,
/// <b>unparsed</b> response body, <var>pStatus</var> is the numeric HTTP status
/// <code>%response.Status</code> was left at, and <var>pAllowHeader</var> is whatever
/// <code>%response</code>'s <code>Allow</code> header was set to (empty when none was set).</p>
ClassMethod Invoke(pRouterClass As %String, pUrl As %String, pMethod As %String, pParams As %DynamicObject = "", Output pBody As %String, Output pStatus As %Integer, Output pAllowHeader As %String) As %Status
{
    Set tSC = $$$OK
    Set pBody = ""
    Set pStatus = 0
    Set pAllowHeader = ""
    Set tCapturing = 0
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = $ZConvert(pMethod, "U")
        Set %request.URL = pUrl
        If $IsObject(pParams) {
            Set tIter = pParams.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do %request.Set(tKey, tVal)
            }
        }
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotDispatchCap = ""
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tCapturing = 1

        Set tSC = $ClassMethod(pRouterClass, "DispatchRequest", pUrl, %request.Method)

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pBody = $Get(%OcuPilotDispatchCap, "")
        Set pStatus = +%response.Status
        Set pAllowHeader = %response.GetHeader("Allow")
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotDispatchCap
    Quit tSC
}

/// <p>Mnemonic I/O space bound via <code>Use tNull::("^"_$ZNAME)</code> in
/// <method>Invoke</method> — must live in this class's own compiled routine for
/// <code>$ZNAME</code> to resolve these labels. Accumulates every <code>Write</code> issued
/// while the redirect is active into the process-private <var>%OcuPilotDispatchCap</var>.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ s Quit
wchr(a) Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(a) Quit
wnl Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(10) Quit
wff Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
