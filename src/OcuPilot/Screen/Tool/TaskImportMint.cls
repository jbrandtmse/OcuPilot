/// <p>The mint <class>OcuPilot.Screen.Tool.TaskImport</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, AD-21): the kernel's own mint,
/// handed the import's one target and the tasks the file would create. Everything else -- the fresh
/// read, the diff, the fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>In order: file arguments the tool refuses are 400 <code>TOOL.ARGUMENTS</code>; the target id is
/// replaced by <parameter>OcuPilot.Port.TaskTransferPort.IMPORTID</parameter> whatever was sent; the
/// port's <code>PREVIEW</code> of the file is asked, and its refusal answered unchanged; and
/// <code>tasks</code> and <code>runAs</code> are set to the preview's summary, the reviewed argument the
/// write compares, and the accounts its tasks run as, which the mint's classifier reads.</p>
Class OcuPilot.Screen.Tool.TaskImportMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The tool whose file is read first.</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.TaskImport";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached with the import's
/// target and <var>pArgs</var>' <code>tasks</code> set from the file.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tPort = $ClassMethod(..#TOOLCLASS, "PortClass")
        Set tId = $Parameter(tPort, "IMPORTID")
        Kill tQuery
        Set tQuery($Parameter(tPort, "IDPARAM")) = tId
        Set tQuery($Parameter(tPort, "ROOTPARAM")) = pArgs.%Get($Parameter(tPort, "ROOTPARAM"))
        Set tQuery($Parameter(tPort, "PATHPARAM")) = pArgs.%Get($Parameter(tPort, "PATHPARAM"))
        Set tSC = $ClassMethod(tPort, "Invoke", $Parameter(tPort, "ENDPOINT"), $Parameter(tPort, "PREVIEWTYPE"), .tQuery, "", .tPreview, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(pIdArgument, tId, "string")
        Do tArgs.%Set($Parameter(tPort, "TASKSPARAM"), tPreview.%Get($Parameter(tPort, "TASKSPARAM")), "string")
        Do tArgs.%Set($Parameter(tPort, "RUNASPARAM"), tPreview.%Get($Parameter(tPort, "RUNASPARAM")), "string")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
