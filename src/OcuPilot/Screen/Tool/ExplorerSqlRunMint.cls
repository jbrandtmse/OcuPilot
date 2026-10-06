/// <p>The mint <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-21, AD-53, Story 19.11): the
/// kernel's own mint, handed the console's one target after the statement has been through the
/// console's own checks. Everything else -- the fresh read, the diff, the fingerprint, the stored
/// row -- is the superclass's, unchanged.</p>
/// <p>In order: <method>OcuPilot.Port.SqlPort.InputProblem</method>, refused 400
/// <code>EXPLORER.SQL.INPUT</code>; <method>OcuPilot.Area.Explorer.SqlConsole.Check</method> in the
/// request's namespace (<method>OcuPilot.Kernel.Scope.Current</method>), its fault answered
/// unchanged; then four refusals, each 422, nothing minted: a statement the instance did not prepare
/// (<code>EXPLORER.SQL.NOTPREPARED</code>, <code>detail.sqlcode</code>), a query
/// (<code>EXPLORER.SQL.READS</code>), a statement that carries code
/// (<code>EXPLORER.SQL.AGENTCODE</code>, <method>OcuPilot.Port.SqlPort.CarriesCode</method>) and
/// values that do not number the statement's value positions (<code>EXPLORER.SQL.PARAMETERS</code>).
/// The target is then set to <parameter>OcuPilot.Port.SqlPort.IDVALUE</parameter> whatever was
/// sent.</p>
/// <p>The prepare records the statement in the namespace's statement index (AD-7's fifth shape). A
/// refusal logs nothing of the statement, its values or the instance's message.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlRunMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached with the
/// console's target once the statement has passed the checks above.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Set tText = $Select(pArgs.%GetTypeOf($Parameter(tPort, "STATEMENTKEY")) = "string": pArgs.%Get($Parameter(tPort, "STATEMENTKEY")), 1: "")
        Set tValues = $Select(pArgs.%GetTypeOf($Parameter(tPort, "PARAMETERSKEY")) = "array": pArgs.%Get($Parameter(tPort, "PARAMETERSKEY")), 1: [])
        Set tMaxRows = $Select(pArgs.%GetTypeOf($Parameter(tPort, "MAXROWSKEY")) = "number": pArgs.%Get($Parameter(tPort, "MAXROWSKEY")), 1: "")
        If $ClassMethod(tPort, "InputProblem", tText, tValues, tMaxRows) '= "" {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "input", .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tCheckSC = ##class(OcuPilot.Area.Explorer.SqlConsole).Check(tNamespace, tText, .tGuard, .pHttpStatus, .pFault)
        If $$$ISERR(tCheckSC) {
            Set tSC = tCheckSC
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        If tGuard.%GetTypeOf("error") = "object" {
            Set tDetail = {}
            Do tDetail.%Set("sqlcode", tGuard.%Get("error").%Get("sqlcode"), "number")
            Set tSC = $ClassMethod(tPort, "RefuseFor", "notprepared", .pHttpStatus, .pFault, tDetail)
            Quit
        }
        If tGuard.%Get("Kind") = $Parameter(tPort, "KINDQUERY") {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "reads", .pHttpStatus, .pFault)
            Quit
        }
        If $ClassMethod(tPort, "CarriesCode", tGuard.%Get("StatementType"), tText) {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "agentcode", .pHttpStatus, .pFault)
            Quit
        }
        If tValues.%Size() '= tGuard.%Get("Parameters") {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "parameters", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = $Parameter(tPort, "IDVALUE")
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(pIdArgument, tId, "string")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.Name, .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
