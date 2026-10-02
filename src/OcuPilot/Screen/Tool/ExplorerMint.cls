/// <p>The mint System Explorer's compile and delete tools declare as their
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 19.2): the kernel's own
/// mint, handed the set's canonical spelling once the set is sound and present. Everything else -- the
/// fresh read, the diff, the fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>In order: a set the tool's <method>OcuPilot.Screen.Tool.ExplorerWrite.SetProblem</method> refuses
/// is 400 <code>TOOL.ARGUMENTS</code> before anything is read; the port's <code>DOCS</code> read of the
/// canonical set is asked, and its refusal answered unchanged; and a set naming a document the
/// namespace does not hold is 404 <code>EXPLORER.DOCUMENT.ABSENT</code>, naming each
/// (<method>OcuPilot.Port.AtelierPort.AbsentRefusal</method>).</p>
Class OcuPilot.Screen.Tool.ExplorerMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached with the set's
/// canonical spelling as both the target and the tool's own argument.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(pToolClass, "SetProblem", pIdValue)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId($ClassMethod(pDescriptor, "PrimaryEntityType"), pIdValue)
        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Kill tQuery
        Set tQuery(pIdParam) = tId
        Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tDocs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If $IsObject($Get(tDocs)) && (tDocs.%Get("Absent") '= "") {
            Set tSC = $ClassMethod(tPort, "AbsentRefusal", tDocs.%Get("Absent"), .pHttpStatus, .pFault)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(pIdArgument, tId, "string")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
