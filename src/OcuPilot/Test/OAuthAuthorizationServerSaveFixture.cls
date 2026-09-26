/// <p>Test-only <class>OcuPilot.Area.Security.OAuthAuthorizationServerSave</class> subclass with one
/// replaced seam: <method>PortClass</method> answers
/// <class>OcuPilot.Test.OAuthAuthorizationServerRecordPort</class>, so the Save runs for real against the
/// instance with what it sends recorded and any call the test arms refused. <method>Handle</method>
/// runs a Save route's handler in this process against <class>%CSP.Request</class>/<class>%CSP.Response</class>
/// stubs and captures what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthAuthorizationServerSaveFixture Extends OcuPilot.Area.Security.OAuthAuthorizationServerSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.OAuthAuthorizationServerRecordPort"
}

/// <p>Run <code>POST /oauth/authorization-server</code> when <var>pMethod</var> is <code>POST</code>,
/// otherwise <code>PUT</code>, with <var>pBody</var> as the request's content, and capture what it
/// writes: <var>pAnswer</var> the unparsed body and <var>pStatus</var> the status
/// <code>%response.Status</code> was left at.</p>
ClassMethod Handle(pMethod As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = pMethod
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotOAuthAuthCap = ""
        ; Armed before the three statements that can strand the process in the mnemonic space.
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        If pMethod = "POST" {
            Set tSC = ..HandleCreate()
        } Else {
            Set tSC = ..HandleUpdate()
        }

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotOAuthAuthCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotOAuthAuthCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotOAuthAuthCap = $Get(%OcuPilotOAuthAuthCap, "") _ s Quit
wchr(a) Set %OcuPilotOAuthAuthCap = $Get(%OcuPilotOAuthAuthCap, "") _ $Char(a) Quit
wnl Set %OcuPilotOAuthAuthCap = $Get(%OcuPilotOAuthAuthCap, "") _ $Char(10) Quit
wff Set %OcuPilotOAuthAuthCap = $Get(%OcuPilotOAuthAuthCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotOAuthAuthCap = $Get(%OcuPilotOAuthAuthCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
