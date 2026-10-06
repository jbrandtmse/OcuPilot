/// <p>Test-only <class>OcuPilot.Area.Security.EncryptionStartupSave</class> subclass:
/// <method>PortClass</method> answers <class>OcuPilot.Test.EncryptionSeamPort</class>, which records each
/// call, <method>ProhibitedClass</method> answers <class>OcuPilot.Test.EncryptionStartupProhibited</class>,
/// which reads the target through it, and <method>Handle</method> runs <code>PUT /encryption-startup</code>
/// and <method>Form</method> <code>GET /encryption-startup/form</code> in this process against request and
/// response stubs, capturing what each writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionStartupSaveFixture Extends OcuPilot.Area.Security.EncryptionStartupSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.EncryptionSeamPort"
}

ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.EncryptionStartupProhibited"
}

/// <p>Run <code>PUT /encryption-startup</code> with body <var>pBody</var>; <var>pAnswer</var> is the unparsed
/// response body and <var>pStatus</var> the numeric status.</p>
ClassMethod Handle(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Quit ..Capture("PUT", pBody, .pAnswer, .pStatus)
}

/// <p>Run <code>GET /encryption-startup/form</code>; <var>pAnswer</var> is the unparsed response body and
/// <var>pStatus</var> the numeric status.</p>
ClassMethod Form(Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Quit ..Capture("GET", "", .pAnswer, .pStatus)
}

/// <p>Run the Save (<var>pMethod</var> <code>PUT</code>, with body <var>pBody</var>) or the form read
/// (<code>GET</code>) against request and response stubs, capturing what it writes.</p>
ClassMethod Capture(pMethod As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status [ Private ]
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
        Set %OcuPilotStartupSaveCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = $Select(pMethod = "GET": ..HandleForm(), 1: ..HandleUpdate())
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotStartupSaveCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotStartupSaveCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotStartupSaveCap = $Get(%OcuPilotStartupSaveCap, "") _ s Quit
wchr(a) Set %OcuPilotStartupSaveCap = $Get(%OcuPilotStartupSaveCap, "") _ $Char(a) Quit
wnl Set %OcuPilotStartupSaveCap = $Get(%OcuPilotStartupSaveCap, "") _ $Char(10) Quit
wff Set %OcuPilotStartupSaveCap = $Get(%OcuPilotStartupSaveCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotStartupSaveCap = $Get(%OcuPilotStartupSaveCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
