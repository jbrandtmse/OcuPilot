/// <p>The mint <class>OcuPilot.Screen.Tool.InteropTransformTest</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, Story 20.27): the kernel's own mint, which first asks the tool whether
/// the agent's own arguments are sound (<method>OcuPilot.Screen.Tool.InteropTransformTest.ArgumentProblem</method>), so a pasted
/// message that is empty or longer than a card holds is refused <code>TOOL.ARGUMENTS</code> before the instance is read. Everything
/// else is the superclass's.</p>
Class OcuPilot.Screen.Tool.InteropTransformMint Extends OcuPilot.Kernel.Proposal.Mint
{

ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If (pToolClass '= "") && $IsObject(pArgs) {
        Set tSC = $ClassMethod(pToolClass, "ArgumentProblem", pIdValue, pArgs, .tProblem)
        If $$$ISOK(tSC) && ($Get(tProblem) '= "") Quit ..Refuse(tProblem, .pHttpStatus, .pFault)
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

}
