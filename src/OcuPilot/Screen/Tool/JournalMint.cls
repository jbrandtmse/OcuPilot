/// <p>The mint Journals' Check integrity declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-21's eighth case, Story 18.5): the
/// kernel's own mint, once the file reads through the tool's port. A refusal of that read -- a name the
/// instance's journal file list does not answer is 404 <code>JOURNAL.FILE.UNLISTED</code> -- is
/// answered unchanged, where the kernel would read any 404 as an absent target. Everything else is the
/// superclass's, unchanged.</p>
Class OcuPilot.Screen.Tool.JournalMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached once the tool's
/// own read of <var>pIdValue</var> answers.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Kill tQuery
        Set tQuery(pIdParam) = pIdValue
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", pEndpoint, $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
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
