/// <p>Test-only <class>OcuPilot.Area.Security.OAuthResourceServerSave</class> subclass with one replaced
/// seam: <method>PortClass</method> answers <class>OcuPilot.Test.OAuthResourceServerFailPort</class>, so
/// a call the test arms there is refused while every other call reaches the instance.
/// <method>Handle</method> runs a Save route's handler in this process against
/// <class>%CSP.Request</class>/<class>%CSP.Response</class> stubs and captures what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthResourceServerFailSave Extends OcuPilot.Area.Security.OAuthResourceServerSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.OAuthResourceServerFailPort"
}

/// <p>Run <code>PUT /oauth/resource-server/:id</code> for <var>pName</var>, or <code>POST
/// /oauth/resource-server</code> when <var>pName</var> is empty, with <var>pBody</var> as the request's
/// content, and capture what it writes.</p>
/// <p><b>Caller contract:</b> <var>pName</var> is letters and digits alone, so the path segment the CSP
/// server would deliver is the name itself (AD-13). <var>pAnswer</var> is the unparsed response body
/// and <var>pStatus</var> the numeric status <code>%response.Status</code> was left at.</p>
ClassMethod Handle(pName As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = $Select(pName = "": "POST", 1: "PUT")
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotOAuthResourceCap = ""
        ; Armed before the three statements that can strand the process in the mnemonic space.
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        If pName = "" {
            Set tSC = ..HandleCreate()
        } Else {
            Set tSC = ..HandleUpdate(pName)
        }

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotOAuthResourceCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotOAuthResourceCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels. Every <code>Write</code> issued while the redirect is
/// active accumulates into <var>%OcuPilotOAuthResourceCap</var>.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotOAuthResourceCap = $Get(%OcuPilotOAuthResourceCap, "") _ s Quit
wchr(a) Set %OcuPilotOAuthResourceCap = $Get(%OcuPilotOAuthResourceCap, "") _ $Char(a) Quit
wnl Set %OcuPilotOAuthResourceCap = $Get(%OcuPilotOAuthResourceCap, "") _ $Char(10) Quit
wff Set %OcuPilotOAuthResourceCap = $Get(%OcuPilotOAuthResourceCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotOAuthResourceCap = $Get(%OcuPilotOAuthResourceCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
