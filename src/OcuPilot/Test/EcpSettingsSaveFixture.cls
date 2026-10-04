/// <p>Test-only <class>OcuPilot.Area.OsMgmt.EcpSettingsSave</class> subclass: <method>PortClass</method>
/// answers <class>OcuPilot.Test.EcpSeamPort</class>, which records each call and, unarmed, sends it, and
/// <method>Handle</method> runs <code>PUT /ecp-settings</code> in this process against request and
/// response stubs, capturing what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EcpSettingsSaveFixture Extends OcuPilot.Area.OsMgmt.EcpSettingsSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.EcpSeamPort"
}

/// <p>Run <code>PUT /ecp-settings</code> with body <var>pBody</var>; <var>pAnswer</var> is the unparsed
/// response body and <var>pStatus</var> the numeric status.</p>
ClassMethod Handle(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
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
        Set %OcuPilotEcpSettingsCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..HandleUpdate()
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotEcpSettingsCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotEcpSettingsCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotEcpSettingsCap = $Get(%OcuPilotEcpSettingsCap, "") _ s Quit
wchr(a) Set %OcuPilotEcpSettingsCap = $Get(%OcuPilotEcpSettingsCap, "") _ $Char(a) Quit
wnl Set %OcuPilotEcpSettingsCap = $Get(%OcuPilotEcpSettingsCap, "") _ $Char(10) Quit
wff Set %OcuPilotEcpSettingsCap = $Get(%OcuPilotEcpSettingsCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotEcpSettingsCap = $Get(%OcuPilotEcpSettingsCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
