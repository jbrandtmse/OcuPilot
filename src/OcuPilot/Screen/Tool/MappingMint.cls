/// <p>The mint every namespace mapping tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 18.14): the kernel's own
/// mint, handed the mapping's composite id <code>[namespace, Name]</code> built from the agent's
/// <parameter>NAMESPACEARGUMENT</parameter> and <code>Name</code> with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the mapping lists' rows carry, so
/// both callers hand <class>OcuPilot.Port.NamespacePort</class> one target grammar. Everything else
/// is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an empty namespace or
/// name, and a part carrying <code>$Char(1)</code>, the composite separator, which would let one
/// argument stand for two parts.</p>
Class OcuPilot.Screen.Tool.MappingMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the namespace the mapping belongs to.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with
/// <var>pIdValue</var> -- the agent's <code>Name</code> -- replaced by the composite id of that name
/// in the agent's <parameter>NAMESPACEARGUMENT</parameter>. A <code>detail.problem</code> the
/// superclass answers is made readable by
/// <method>OcuPilot.Screen.Tool.ErrorDeleteMint.ReadableId</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tNamespace = ""
        If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#NAMESPACEARGUMENT) = "string") Set tNamespace = pArgs.%Get(..#NAMESPACEARGUMENT)
        If tNamespace = "" {
            Set tSC = ..Refuse("'" _ ..#NAMESPACEARGUMENT _ "' names the namespace the mapping belongs to and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If pIdValue = "" {
            Set tSC = ..Refuse("'" _ pIdArgument _ "' names the mapping and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If (tNamespace [ tSeparator) || (pIdValue [ tSeparator) {
            Set tSC = ..Refuse("'" _ $Select(tNamespace [ tSeparator: ..#NAMESPACEARGUMENT, 1: pIdArgument) _ "' carries the character U+0001, which no namespace or mapping name holds", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tNamespace, pIdValue))
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
