/// <p>Test-only <class>OcuPilot.Area.OsMgmt.RemoteDatabaseRules</class> subclass whose
/// <method>PortClass</method> answers the port a test names in <code>^||OcuPilotDatabaseWritePort</code>,
/// and <class>OcuPilot.Test.RemoteDatabaseListingPort</class> when none is named, so the rules' reads,
/// the form read and the listing route go through the seam and are recorded there
/// (<class>OcuPilot.Test.RemoteDatabaseSaveFixture</class> declares it as its rules).</p>
/// <p><method>Route</method> runs the form read or the listing route in this process against request
/// and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseRulesFixture Extends OcuPilot.Area.OsMgmt.RemoteDatabaseRules
{

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.RemoteDatabaseListingPort")
}

/// <p>Run <code>GET /remote-database/form</code> (<var>pRoute</var> <code>form</code>, naming the
/// configuration <var>pValue</var> when it is not empty) or <code>GET /remote-database/directories</code>
/// (<var>pRoute</var> <code>directories</code>, data server <var>pValue</var>) in this process,
/// answering the unparsed body in <var>pAnswer</var> and the numeric status
/// <code>%response.Status</code> was left at in <var>pStatus</var>.</p>
ClassMethod Route(pRoute As %String, pValue As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "GET"
        If pValue '= "" Set %request.Data($Select(pRoute = "form": "name", 1: ..#SERVERPARAM), 1) = pValue
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotRemoteRulesCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        If pRoute = "form" {
            Set tSC = ..HandleForm()
        } Else {
            Set tSC = ..HandleDirectories()
        }

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotRemoteRulesCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotRemoteRulesCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Route</method> binds with <code>Use tNull::("^"_$ZNAME)</code>;
/// it must live in this class's own routine for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotRemoteRulesCap = $Get(%OcuPilotRemoteRulesCap, "") _ s Quit
wchr(a) Set %OcuPilotRemoteRulesCap = $Get(%OcuPilotRemoteRulesCap, "") _ $Char(a) Quit
wnl Set %OcuPilotRemoteRulesCap = $Get(%OcuPilotRemoteRulesCap, "") _ $Char(10) Quit
wff Set %OcuPilotRemoteRulesCap = $Get(%OcuPilotRemoteRulesCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotRemoteRulesCap = $Get(%OcuPilotRemoteRulesCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
