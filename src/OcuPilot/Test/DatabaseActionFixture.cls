/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass with three replaced seams:
/// <method>PortClass</method> answers the port a test names in
/// <code>^||OcuPilotDatabaseWritePort</code>, and <class>OcuPilot.Test.DatabaseAcceptPort</class>,
/// which writes nothing, when none is named, so a row action's fresh read and write go there; and
/// <method>ProhibitedClassName</method> answers the class a test names in
/// <code>^||OcuPilotDatabaseProhibited</code>. The pairs and the prohibited set's own read of the live
/// target are the shipped route's. <method>ToolFor</method> runs the database delete through
/// <class>OcuPilot.Test.SeamLocalDatabaseDelete</class>, and each disk operation a screen reaches
/// through its own <code>OcuPilot.Test.Seam*</code> subclass (Story 18.4), so that seam applies to
/// them.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseActionFixture Extends OcuPilot.Api.ScreenAction
{

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.DatabaseAcceptPort")
}

/// <p>The class a test names in <code>^||OcuPilotDatabaseProhibited</code>, and the shipped set
/// otherwise.</p>
ClassMethod ProhibitedClassName() As %String
{
    Set tArmed = $Get(^||OcuPilotDatabaseProhibited)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

/// <p>The shipped resolution, with the database delete's class replaced by
/// <class>OcuPilot.Test.SeamLocalDatabaseDelete</class>, which declares the default port, so its fresh
/// read and write go to <method>PortClass</method>.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.LocalDatabaseDelete" Set pToolClass = "OcuPilot.Test.SeamLocalDatabaseDelete"
    ; Story 18.4: the disk operations reached by a screen action, each through its own seam.
    If $ListFind($ListBuild("DatabaseMount", "DatabaseDismount", "DatabaseTruncate", "DatabaseCompact", "DatabaseDefragment", "DatabaseIntegrityCheck", "LocalDatabaseExpand"), $Piece($Get(pToolClass), "OcuPilot.Screen.Tool.", 2)) Set pToolClass = "OcuPilot.Test.Seam" _ $Piece(pToolClass, "OcuPilot.Screen.Tool.", 2)
    Quit tSC
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
        Set %OcuPilotDatabaseActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotDatabaseActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotDatabaseActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine
/// for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotDatabaseActionCap = $Get(%OcuPilotDatabaseActionCap, "") _ s Quit
wchr(a) Set %OcuPilotDatabaseActionCap = $Get(%OcuPilotDatabaseActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotDatabaseActionCap = $Get(%OcuPilotDatabaseActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotDatabaseActionCap = $Get(%OcuPilotDatabaseActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotDatabaseActionCap = $Get(%OcuPilotDatabaseActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
