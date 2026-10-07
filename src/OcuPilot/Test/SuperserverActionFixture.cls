/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass for Story 18.25's one row action:
/// <method>ToolFor</method> runs the delete through <class>OcuPilot.Test.SeamSuperserverDelete</class>, so its
/// fresh read and its write go through <class>OcuPilot.Test.SuperserverSeamPort</class>, which records them and
/// sends a probe-port write alone. The pairs, the prohibited set and everything else are the shipped
/// route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process against
/// request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped resolution, with the superserver delete's tool replaced by its seam subclass.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.SuperserverDelete" Set pToolClass = "OcuPilot.Test.SeamSuperserverDelete"
    Quit tSC
}

/// <p>The prohibited set the route asks, which reads every target through the seam
/// (<class>OcuPilot.Test.SuperserverSet</class>).</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit "OcuPilot.Test.SuperserverSet"
}

/// <p>Send the screen action <var>pBody</var> to screen <var>pScreen</var>'s route in this process,
/// answering the unparsed envelope in <var>pAnswer</var> and the status <code>%response.Status</code>
/// was left at in <var>pStatus</var>.</p>
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
        Set %OcuPilotSuperserverActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO::"^%X364"
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotSuperserverActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO::"^%X364"
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotSuperserverActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotSuperserverActionCap = $Get(%OcuPilotSuperserverActionCap, "") _ s Quit
wchr(a) Set %OcuPilotSuperserverActionCap = $Get(%OcuPilotSuperserverActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotSuperserverActionCap = $Get(%OcuPilotSuperserverActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotSuperserverActionCap = $Get(%OcuPilotSuperserverActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotSuperserverActionCap = $Get(%OcuPilotSuperserverActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
