/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.ProposalFixture</class>, so a screen
/// action's fresh read answers the fixture's armed object and its write is recorded there and never
/// reaches the instance. Everything else -- the pairs, the delta, the prohibited set and its own
/// read of the live target -- is the shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SslActionFixture Extends OcuPilot.Api.ScreenAction
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

/// <p>Send the screen action <var>pBody</var> to screen <var>pScreen</var>'s route in this process,
/// answering the unparsed envelope in <var>pAnswer</var> and the status
/// <code>%response.Status</code> was left at in <var>pStatus</var>.</p>
ClassMethod Act(pScreen As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
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
        Set tSC = tStream.Write(pBody.%ToJSON())
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotSslActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotSslActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotSslActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine
/// for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotSslActionCap = $Get(%OcuPilotSslActionCap, "") _ s Quit
wchr(a) Set %OcuPilotSslActionCap = $Get(%OcuPilotSslActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotSslActionCap = $Get(%OcuPilotSslActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotSslActionCap = $Get(%OcuPilotSslActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotSslActionCap = $Get(%OcuPilotSslActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
