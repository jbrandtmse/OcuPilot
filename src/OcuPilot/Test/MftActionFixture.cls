/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass for Story 18.26's two row actions:
/// <method>ToolFor</method> runs the delete and the token revoke through <class>OcuPilot.Test.SeamMftConnectionDelete</class>
/// and <class>OcuPilot.Test.SeamMftConnectionRevoke</class>, so their reads and writes go through
/// <class>OcuPilot.Test.MftSeamPort</class>, which records them. The pairs, the prohibited set and everything else
/// are the shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process against
/// request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MftActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped resolution, with the superserver delete's tool replaced by its seam subclass.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.MftConnectionDelete" Set pToolClass = "OcuPilot.Test.SeamMftConnectionDelete"
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.MftConnectionRevoke" Set pToolClass = "OcuPilot.Test.SeamMftConnectionRevoke"
    Quit tSC
}

/// <p>The prohibited set the route asks, which reads every target through the seam
/// (<class>OcuPilot.Test.MftSet</class>).</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit "OcuPilot.Test.MftSet"
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
        Set %OcuPilotMftActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO::"^%X364"
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotMftActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO::"^%X364"
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotMftActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotMftActionCap = $Get(%OcuPilotMftActionCap, "") _ s Quit
wchr(a) Set %OcuPilotMftActionCap = $Get(%OcuPilotMftActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotMftActionCap = $Get(%OcuPilotMftActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotMftActionCap = $Get(%OcuPilotMftActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotMftActionCap = $Get(%OcuPilotMftActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
