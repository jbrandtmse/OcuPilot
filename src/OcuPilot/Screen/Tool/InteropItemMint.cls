/// <p>The mint every production item tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 20.3): the kernel's own mint,
/// handed the item's composite id <code>[Production, Name]</code> built from the agent's
/// <code>Production</code> and <code>Name</code> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>,
/// the id the Production items list's rows carry, so both callers hand
/// <class>OcuPilot.Port.InteropPort</class> one target grammar. It is
/// <class>OcuPilot.Screen.Tool.MappingMint</class>'s composition with the production as its first part, and an
/// add's stored arguments also carry the namespace (<method>Mint</method>); everything else is the
/// superclass's.</p>
Class OcuPilot.Screen.Tool.InteropItemMint Extends OcuPilot.Screen.Tool.MappingMint
{

/// <p>The argument naming the production the item belongs to.</p>
Parameter NAMESPACEARGUMENT = "Production";

Parameter PARENTDESCRIPTION = "the production the item belongs to";

Parameter CHILDDESCRIPTION = "the item";

Parameter SEPARATORNOUNS = "production or item name";

/// <p>The argument an add's stored arguments carry the namespace under.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>'s mint. For a tool that creates its target (the add), the
/// arguments it stores also carry <parameter>NAMESPACEFIELD</parameter>, the namespace the request is scoped
/// to, replacing any the agent sent, so the add's rules are asked again at the confirm in the namespace the
/// proposal read (<method>OcuPilot.Screen.Tool.InteropItemAdd.ConfirmProblem</method>, AD-52).</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tArgs = pArgs
    If $IsObject(pArgs) && (pToolClass '= "") && +$Parameter(pToolClass, "CREATES") {
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

}
