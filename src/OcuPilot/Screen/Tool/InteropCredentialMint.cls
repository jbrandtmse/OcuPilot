/// <p>The mint every credential tool and every schedule spec tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-52,
/// Story 24.15): the kernel's own mint, whose target is the credential's or the schedule spec's name. For a tool that creates its target or sends a body (the add and the edit), the
/// arguments it stores also carry the namespace the request is scoped to, under <parameter>NAMESPACEFIELD</parameter>, replacing any the agent
/// sent, so the credential's field rules (a business partner the namespace holds, a user name the instance accepts) are asked again at the
/// confirm in the namespace the proposal read (<method>OcuPilot.Screen.Tool.InteropAction.ArgumentNamespace</method>), whichever namespace the
/// confirm is sent from. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class>'s stamp over a single-part id, which that composite-id mint
/// cannot serve.</p>
Class OcuPilot.Screen.Tool.InteropCredentialMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument a body-sending tool's stored arguments carry the namespace under.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The kernel's mint, with <parameter>NAMESPACEFIELD</parameter> set in the arguments of a tool that creates its target or sends a body.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tArgs = pArgs
    If $IsObject(pArgs) && (pToolClass '= "") && (+$Parameter(pToolClass, "CREATES") || +$Parameter(pToolClass, "SENDSBODY")) {
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

}
