/// <p>The mint System Explorer's import tools declare as their
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, AD-21, Story 19.13): the
/// kernel's own mint, handed the import's one target and the summary of what the file would do.
/// Everything else -- the fresh read, the diff, the fingerprint, the stored row -- is the
/// superclass's, unchanged.</p>
/// <p>In order: file arguments the tool refuses, and a <code>Compile</code> that is not a boolean, are
/// 400 <code>TOOL.ARGUMENTS</code>; the target is set to
/// <parameter>OcuPilot.Port.AtelierPort.IMPORTID</parameter> whatever was sent; the port's
/// <code>PREVIEW</code> of the file in the request's namespace
/// (<method>OcuPilot.Kernel.Scope.Current</method>) is asked, and its refusal answered unchanged; and
/// <code>documents</code> is set to the preview's summary, the reviewed argument the write
/// compares.</p>
Class OcuPilot.Screen.Tool.ExplorerImportMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached with the import's
/// target and <var>pArgs</var>' <code>documents</code> set from the file.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = $ClassMethod(pToolClass, "ArgumentProblem", pIdValue, pArgs, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Set tId = $Parameter(tPort, "IMPORTID")
        Kill tQuery
        Set tQuery($Parameter(tPort, "IDKEY")) = tId
        Set tQuery($Parameter(tPort, "NAMESPACEKEY")) = ##class(OcuPilot.Kernel.Scope).Current()
        Set tQuery($Parameter(tPort, "ROOTKEY")) = pArgs.%Get($Parameter(tPort, "ROOTKEY"))
        Set tQuery($Parameter(tPort, "PATHKEY")) = pArgs.%Get($Parameter(tPort, "PATHKEY"))
        Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, $Parameter(tPort, "TYPEPREVIEW"), .tQuery, "", .tPreview, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(pIdArgument, tId, "string")
        Do tArgs.%Set($Parameter(tPort, "DOCUMENTSKEY"), tPreview.%Get($Parameter(tPort, "DOCUMENTSKEY")), "string")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
