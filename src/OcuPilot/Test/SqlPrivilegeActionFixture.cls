/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass for Story 18.9's four row actions:
/// <method>ToolFor</method> runs <code>grant-sql</code> and <code>revoke-sql</code> of the Users and Roles lists
/// through <class>OcuPilot.Test.SeamUserSqlGrant</class> and its three siblings, so their reads and writes go
/// through <class>OcuPilot.Test.SqlPrivilegeSeamPort</class>, which records them. The pairs, the prohibited set and
/// everything else are the shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process against request
/// and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlPrivilegeActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped resolution, with the four tools replaced by their seam subclasses.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.UserSqlGrant" Set pToolClass = "OcuPilot.Test.SeamUserSqlGrant"
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.UserSqlRevoke" Set pToolClass = "OcuPilot.Test.SeamUserSqlRevoke"
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.RoleSqlGrant" Set pToolClass = "OcuPilot.Test.SeamRoleSqlGrant"
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.RoleSqlRevoke" Set pToolClass = "OcuPilot.Test.SeamRoleSqlRevoke"
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
        Set %OcuPilotSqlPrivActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO::"^%X364"
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotSqlPrivActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO::"^%X364"
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotSqlPrivActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotSqlPrivActionCap = $Get(%OcuPilotSqlPrivActionCap, "") _ s Quit
wchr(a) Set %OcuPilotSqlPrivActionCap = $Get(%OcuPilotSqlPrivActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotSqlPrivActionCap = $Get(%OcuPilotSqlPrivActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotSqlPrivActionCap = $Get(%OcuPilotSqlPrivActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotSqlPrivActionCap = $Get(%OcuPilotSqlPrivActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
