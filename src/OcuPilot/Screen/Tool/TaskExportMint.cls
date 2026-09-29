/// <p>The mint <class>OcuPilot.Screen.Tool.TaskExport</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-21): the kernel's own mint, after
/// the file the proposal names is resolved as the write will resolve it. Everything else -- the fresh
/// read, the diff, the fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>Refused before anything is read: file arguments the tool refuses, with 400
/// <code>TOOL.ARGUMENTS</code>; then the port's own refusal of the file
/// (<method>OcuPilot.Port.TaskTransferPort.CheckExport</method>), answered unchanged, so the agent reads
/// the <code>PATH.*</code> or <code>TASK.EXPORT.DIRECTORY</code> code on its field.</p>
Class OcuPilot.Screen.Tool.TaskExportMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The tool whose file is resolved first.</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.TaskExport";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached only once
/// <var>pArgs</var>' file resolves.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(..#TOOLCLASS, "FileProblem", pArgs)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tPort = $ClassMethod(..#TOOLCLASS, "PortClass")
        Set tSC = $ClassMethod(tPort, "CheckExport", pArgs.%Get($Parameter(tPort, "ROOTPARAM")), pArgs.%Get($Parameter(tPort, "PATHPARAM")), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
