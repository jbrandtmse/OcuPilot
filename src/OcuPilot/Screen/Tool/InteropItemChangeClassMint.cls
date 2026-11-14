/// <p>The mint <class>OcuPilot.Screen.Tool.InteropItemChangeClass</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 20.41): the production item mint, which first asks the tool
/// whether the agent's own arguments are sound (<method>OcuPilot.Screen.Tool.InteropItemChangeClass.ArgumentProblem</method>), so a
/// class that is empty, not a string, too long or not shaped like a class name, and an argument carrying the digest only a person's
/// action carries, are refused <code>TOOL.ARGUMENTS</code> before the instance is read. Everything else is the superclass's.</p>
Class OcuPilot.Screen.Tool.InteropItemChangeClassMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If (pToolClass '= "") && $IsObject(pArgs) {
        Set tSC = $ClassMethod(pToolClass, "ArgumentProblem", pIdValue, pArgs, .tProblem)
        If $$$ISOK(tSC) && ($Get(tProblem) '= "") Quit ..Refuse(tProblem, .pHttpStatus, .pFault)
        Set tReviewed = $Parameter(pToolClass, "REVIEWEDARGUMENT")
        If pArgs.%GetTypeOf(tReviewed) '= "unassigned" Quit ..Refuse("'" _ tReviewed _ "' is not an argument a proposal takes", .pHttpStatus, .pFault)
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

}
