/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass for Story 18.6's two screen actions:
/// <method>ToolFor</method> runs the activation through <class>OcuPilot.Test.SeamLicenseKeyActivate</class>
/// and the license server delete through <class>OcuPilot.Test.SeamLicenseServerDelete</class>, so each
/// action's fresh read and write go through <class>OcuPilot.Test.LicenseSeamPort</class>, which
/// records them. The pairs, the prohibited set and everything else are the shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LicenseActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped resolution, with each licensing tool replaced by its seam subclass.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.LicenseKeyActivate" Set pToolClass = "OcuPilot.Test.SeamLicenseKeyActivate"
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.LicenseServerDelete" Set pToolClass = "OcuPilot.Test.SeamLicenseServerDelete"
    Quit tSC
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
        Set %OcuPilotLicenseActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotLicenseActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotLicenseActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotLicenseActionCap = $Get(%OcuPilotLicenseActionCap, "") _ s Quit
wchr(a) Set %OcuPilotLicenseActionCap = $Get(%OcuPilotLicenseActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotLicenseActionCap = $Get(%OcuPilotLicenseActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotLicenseActionCap = $Get(%OcuPilotLicenseActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotLicenseActionCap = $Get(%OcuPilotLicenseActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
