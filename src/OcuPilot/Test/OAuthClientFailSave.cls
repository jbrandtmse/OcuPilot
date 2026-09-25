/// <p>Test-only <class>OcuPilot.Area.Security.OAuthClientSave</class> subclass with two replaced seams:
/// <method>PortClass</method> answers <class>OcuPilot.Test.OAuthClientFailPort</class>, so a request
/// type the test arms there is refused while every other call reaches the instance; and
/// <parameter>SERVERSAVE</parameter> is <class>OcuPilot.Test.OAuthServerSaveFixture</class>, so the
/// initial access token's write goes through <class>OcuPilot.Test.OAuthServerRecordPort</class>,
/// whose <method>FailType</method> refuses it.
/// <method>Handle</method> runs the edit's route handler in this process against
/// <class>%CSP.Request</class>/<class>%CSP.Response</class> stubs and captures what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthClientFailSave Extends OcuPilot.Area.Security.OAuthClientSave
{

Parameter SERVERSAVE = "OcuPilot.Test.OAuthServerSaveFixture";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.OAuthClientFailPort"
}

/// <p>Run <code>PUT /oauth/client-configuration/:id</code> for <var>pName</var> with <var>pBody</var>
/// as the request's content, and capture what it writes.</p>
/// <p><b>Caller contract:</b> <var>pName</var> is letters and digits alone, so the path segment the
/// CSP server would deliver is the name itself (AD-13). <var>pAnswer</var> is the unparsed response
/// body and <var>pStatus</var> the numeric status <code>%response.Status</code> was left at.</p>
ClassMethod Handle(pName As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "PUT"
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotOAuthClientCap = ""
        ; Armed before the three statements that can strand the process in the mnemonic space.
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        Set tSC = ..HandleUpdate(pName)

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotOAuthClientCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotOAuthClientCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds with
/// <code>Use tNull::("^"_$ZNAME)</code>; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels. Every <code>Write</code> issued while the redirect
/// is active accumulates into <var>%OcuPilotOAuthClientCap</var>.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotOAuthClientCap = $Get(%OcuPilotOAuthClientCap, "") _ s Quit
wchr(a) Set %OcuPilotOAuthClientCap = $Get(%OcuPilotOAuthClientCap, "") _ $Char(a) Quit
wnl Set %OcuPilotOAuthClientCap = $Get(%OcuPilotOAuthClientCap, "") _ $Char(10) Quit
wff Set %OcuPilotOAuthClientCap = $Get(%OcuPilotOAuthClientCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotOAuthClientCap = $Get(%OcuPilotOAuthClientCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
