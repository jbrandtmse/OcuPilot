/// <p>The mint every lookup entry tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story
/// 20.5): the kernel's own mint, handed the entry's composite id <code>[Table, Key]</code> built from the agent's
/// <code>Table</code> and <code>Key</code> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the entries
/// list's rows carry, so both callers hand <class>OcuPilot.Port.InteropPort</class> one target grammar. It is
/// <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the table as its first part; everything else is its, and the
/// superclass's: a tool that creates its target or sends a body also stores the namespace the proposal read.</p>
/// <p><b>The set's mint refuses a value the entry already holds with <code>INTEROP.LOOKUP.SAME</code></b>, the code the person's Set
/// value gets from the port's write, rather than leaving it to the kernel's refusal of a call that changes nothing.</p>
Class OcuPilot.Screen.Tool.InteropLookupEntryMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The argument naming the lookup table the entry belongs to.</p>
Parameter NAMESPACEARGUMENT = "Table";

Parameter PARENTDESCRIPTION = "the lookup table the entry belongs to";

Parameter CHILDDESCRIPTION = "the entry";

Parameter SEPARATORNOUNS = "table name or key";

/// <p>The refusal code of a set to the value the entry already holds, with the sentence the port publishes for it.</p>
Parameter SAMECODE = "INTEROP.LOOKUP.SAME";

/// <p>The superclass's mint, after the set's check: 409 <code>INTEROP.LOOKUP.SAME</code> when <method>HoldsTheValue</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    If ..HoldsTheValue(pArgs, pToolClass) {
        Set pProposal = ""
        Set pHttpStatus = 409
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#SAMECODE, ##class(OcuPilot.Port.InteropPort).ReasonFor(..#SAMECODE))
        Quit $$$ERROR($$$GeneralError, ..#SAMECODE)
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

/// <p>Whether <var>pToolClass</var> is a set and the entry <var>pArgs</var> names (<code>Table</code> and <code>Key</code>) already
/// holds the string <code>Value</code> it carries, read through the tool's port as the mint's own fresh read is and judged by the
/// port's own decision (<method>OcuPilot.Port.InteropPort.LookupWriteToken</method>). A call that is not a set, or that names no
/// string table, key and value, or an entry the port does not answer a row for, is not one: the superclass refuses or mints it.</p>
ClassMethod HoldsTheValue(pArgs As %DynamicObject, pToolClass As %String) As %Boolean [ Private ]
{
    Set tHolds = 0
    Try {
        If (pToolClass = "") || ($Parameter(pToolClass, "WRITETYPE") '= ##class(OcuPilot.Port.InteropPort).#TYPESETENTRY) Quit
        If '$IsObject(pArgs) || (pArgs.%GetTypeOf("Table") '= "string") || (pArgs.%GetTypeOf("Key") '= "string") || (pArgs.%GetTypeOf("Value") '= "string") Quit
        Set tPort = ##class(OcuPilot.Kernel.Proposal.Mint).PortClassOf(pToolClass)
        Kill tQuery
        Set tQuery(##class(OcuPilot.Port.InteropPort).#IDKEY) = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pArgs.%Get("Table"), pArgs.%Get("Key")))
        Set tQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ##class(OcuPilot.Port.InteropPort).#TYPESETENTRY
        Set tSC = $ClassMethod(tPort, "Invoke", $ClassMethod(pToolClass, "Endpoint"), $Parameter(pToolClass, "READTYPE"), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject(tFresh) || (tFresh.%GetTypeOf("Value") '= "string") Quit
        Set tHolds = ($ClassMethod(tPort, "LookupWriteToken", ##class(OcuPilot.Port.InteropPort).#TYPESETENTRY, 1, "", 1, tFresh.%Get("Value"), pArgs.%Get("Value")) = "SAME")
    } Catch {
        Set tHolds = 0
    }
    Quit tHolds
}

}
