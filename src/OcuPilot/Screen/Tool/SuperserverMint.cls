/// <p>The mint every superserver tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method>
/// (AD-6, AD-13, Story 18.25): the kernel's own mint, handed the superserver's composite id
/// <code>[Port, BindAddress]</code> built from the agent's <code>Port</code> and
/// <parameter>BINDARGUMENT</parameter> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the
/// superservers list's rows carry, so both callers hand <class>OcuPilot.Port.SuperserverPort</class> one target
/// grammar. An omitted bind address is the empty one, which the instance reads as every interface. Everything
/// else is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an empty port, a bind address that
/// is not text, and a part carrying <code>$Char(1)</code>, the composite separator, which would let one argument
/// stand for two parts.</p>
Class OcuPilot.Screen.Tool.SuperserverMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the address the superserver binds to.</p>
Parameter BINDARGUMENT = "BindAddress";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with <var>pIdValue</var> -- the
/// agent's <code>Port</code> -- replaced by the composite id of that port and the agent's
/// <parameter>BINDARGUMENT</parameter>. A <code>detail.problem</code> the superclass answers is made readable by
/// <method>OcuPilot.Screen.Tool.ErrorDeleteMint.ReadableId</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tBind = ""
        If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#BINDARGUMENT) = "string") Set tBind = pArgs.%Get(..#BINDARGUMENT)
        If pIdValue = "" {
            Set tSC = ..Refuse("'" _ pIdArgument _ "' names the superserver's port and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#BINDARGUMENT) '= "unassigned") && (pArgs.%GetTypeOf(..#BINDARGUMENT) '= "string") {
            Set tSC = ..Refuse("'" _ ..#BINDARGUMENT _ "' is the address the superserver binds to, as text", .pHttpStatus, .pFault)
            Quit
        }
        If (pIdValue [ tSeparator) || (tBind [ tSeparator) {
            Set tSC = ..Refuse("'" _ $Select(pIdValue [ tSeparator: pIdArgument, 1: ..#BINDARGUMENT) _ "' carries the character U+0001, which no port or bind address holds", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pIdValue, tBind))
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
        If $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") && (pFault.%Get("detail").%GetTypeOf("problem") = "string") {
            Do pFault.%Get("detail").%Set("problem", ##class(OcuPilot.Screen.Tool.ErrorDeleteMint).ReadableId(pFault.%Get("detail").%Get("problem")), "string")
        }
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
