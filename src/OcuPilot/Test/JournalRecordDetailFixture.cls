/// <p>Test-only <class>OcuPilot.Area.OsMgmt.JournalRecordDetail</class> subclass reading through
/// <class>OcuPilot.Test.JournalCountPort</class>, so a test can count the vendor calls the journal
/// record detail route makes (Story 18.19). <method>Route</method> runs the route in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalRecordDetailFixture Extends OcuPilot.Area.OsMgmt.JournalRecordDetail
{

Parameter PORTCLASS = "OcuPilot.Test.JournalCountPort";

/// <p>Run <code>GET /journal/record?file=&lt;pFile&gt;&amp;address=&lt;pAddress&gt;</code> in this
/// process, answering the unparsed body in <var>pAnswer</var> and the numeric status
/// <code>%response.Status</code> was left at in <var>pStatus</var>. An empty argument is sent
/// empty.</p>
ClassMethod Route(pFile As %String, pAddress As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "GET"
        Set %request.Data(..#FILEPARAM, 1) = pFile
        Set %request.Data(..#ADDRESSPARAM, 1) = pAddress
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotJournalRecordCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        Set tSC = ..HandleGet()

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pAnswer = $Get(%OcuPilotJournalRecordCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotJournalRecordCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Route</method> binds with <code>Use tNull::("^"_$ZNAME)</code>;
/// it must live in this class's own routine for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotJournalRecordCap = $Get(%OcuPilotJournalRecordCap, "") _ s Quit
wchr(a) Set %OcuPilotJournalRecordCap = $Get(%OcuPilotJournalRecordCap, "") _ $Char(a) Quit
wnl Set %OcuPilotJournalRecordCap = $Get(%OcuPilotJournalRecordCap, "") _ $Char(10) Quit
wff Set %OcuPilotJournalRecordCap = $Get(%OcuPilotJournalRecordCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotJournalRecordCap = $Get(%OcuPilotJournalRecordCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
