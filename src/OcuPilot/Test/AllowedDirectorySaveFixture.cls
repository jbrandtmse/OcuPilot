/// <p>Test-only <class>OcuPilot.Area.Security.AllowedDirectorySave</class> subclass: <method>ProhibitedClassName</method>
/// answers <class>OcuPilot.Test.AllowListAgentSet</class>, whose registry a test arms to list the allow-list tool as one the
/// agent can reach, and <method>Handle</method> runs <code>POST /allowed-directories</code> in this process against request
/// and response stubs, capturing what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AllowedDirectorySaveFixture Extends OcuPilot.Area.Security.AllowedDirectorySave
{

ClassMethod ProhibitedClassName() As %String
{
    Quit "OcuPilot.Test.AllowListAgentSet"
}

/// <p>Run <code>POST /allowed-directories</code> with body <var>pBody</var>; <var>pAnswer</var> is the unparsed response
/// body and <var>pStatus</var> the numeric status.</p>
ClassMethod Handle(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "POST"
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotAllowListSaveCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..HandleSave()
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotAllowListSaveCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotAllowListSaveCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotAllowListSaveCap = $Get(%OcuPilotAllowListSaveCap, "") _ s Quit
wchr(a) Set %OcuPilotAllowListSaveCap = $Get(%OcuPilotAllowListSaveCap, "") _ $Char(a) Quit
wnl Set %OcuPilotAllowListSaveCap = $Get(%OcuPilotAllowListSaveCap, "") _ $Char(10) Quit
wff Set %OcuPilotAllowListSaveCap = $Get(%OcuPilotAllowListSaveCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotAllowListSaveCap = $Get(%OcuPilotAllowListSaveCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
