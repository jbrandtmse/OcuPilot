/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass for Story 18.7's four screen actions:
/// <method>ToolFor</method> runs each key-file tool through its <code>OcuPilot.Test.SeamEncryptionKeyFile*</code>
/// subclass, so its fresh read and write go through <class>OcuPilot.Test.EncryptionSeamPort</class>, and
/// <method>ProhibitedClassName</method> answers the class a test names in
/// <code>^||OcuPilotEncryptionProhibited</code>. The pairs and everything else are the shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped resolution, with each key-file tool replaced by its seam subclass.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    Set tShort = $Piece($Get(pToolClass), "OcuPilot.Screen.Tool.", 2)
    If $ListFind($ListBuild("EncryptionKeyFileAddAdmin", "EncryptionKeyFileRemoveAdmin", "EncryptionKeyFileAddKey", "EncryptionKeyFileRemoveKey"), tShort) Set pToolClass = "OcuPilot.Test.Seam" _ tShort
    Quit tSC
}

/// <p>The class a test names in <code>^||OcuPilotEncryptionProhibited</code>, and the shipped set
/// otherwise.</p>
ClassMethod ProhibitedClassName() As %String
{
    Set tArmed = $Get(^||OcuPilotEncryptionProhibited)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

/// <p>Send the screen action <var>pBody</var> to screen <var>pScreen</var>'s route in this process,
/// answering the unparsed envelope in <var>pAnswer</var> and the status in <var>pStatus</var>.</p>
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
        Set %OcuPilotEncryptionActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotEncryptionActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotEncryptionActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotEncryptionActionCap = $Get(%OcuPilotEncryptionActionCap, "") _ s Quit
wchr(a) Set %OcuPilotEncryptionActionCap = $Get(%OcuPilotEncryptionActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotEncryptionActionCap = $Get(%OcuPilotEncryptionActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotEncryptionActionCap = $Get(%OcuPilotEncryptionActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotEncryptionActionCap = $Get(%OcuPilotEncryptionActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
