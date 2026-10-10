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

/// <p>The argument naming the namespace the mapping belongs to. A subclass whose composite id has another
/// first part (a production's item, Story 20.3) names it here and words the three refusals below.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

/// <p>What the first part names, as the refusal for an empty one says it.</p>
Parameter PARENTDESCRIPTION = "the namespace the mapping belongs to";

/// <p>What the second part names, as the refusal for an empty one says it.</p>
Parameter CHILDDESCRIPTION = "the mapping";

/// <p>The two kinds of name the separator character cannot appear in, as the refusal for it says them.</p>
Parameter SEPARATORNOUNS = "namespace or mapping name";

/// <p>The arguments joined, in order, before the id, comma-separated, or <code>""</code>: the one argument
/// <parameter>NAMESPACEARGUMENT</parameter> names, so every mapping tool is unchanged. A tool whose composite id
/// has more leading parts (a setting's production, item and target, Story 20.22) names them all; each is held to
/// the same two rules as the first, and <method>PartDescription</method> words the refusal for an empty one.</p>
Parameter PARTARGUMENTS = "";

/// <p>The leading arguments of the composite id, as a <class>%List</class> of argument names:
/// <parameter>PARTARGUMENTS</parameter>, else <parameter>NAMESPACEARGUMENT</parameter>.</p>
ClassMethod PartArguments() As %List
{
    If ..#PARTARGUMENTS = "" Quit $ListBuild(..#NAMESPACEARGUMENT)
    Quit $ListFromString(..#PARTARGUMENTS, ",")
}

/// <p>What leading part number <var>pIndex</var> names, as the refusal for an empty one says it:
/// <parameter>PARENTDESCRIPTION</parameter>, for every part here.</p>
ClassMethod PartDescription(pIndex As %Integer) As %String
{
    Quit ..#PARENTDESCRIPTION
}

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with
/// <var>pIdValue</var> -- the agent's <code>Name</code> -- replaced by the composite id of that name
/// after the agent's <method>PartArguments</method>. A <code>detail.problem</code> the
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
        Set tArguments = ..PartArguments()
        Set tParts = ""
        Set tRefused = 0
        For tI = 1:1:$ListLength(tArguments) {
            Set tValue = ""
            If $IsObject(pArgs) && (pArgs.%GetTypeOf($List(tArguments, tI)) = "string") Set tValue = pArgs.%Get($List(tArguments, tI))
            If tValue = "" {
                Set tSC = ..Refuse("'" _ $List(tArguments, tI) _ "' names " _ ..PartDescription(tI) _ " and cannot be empty", .pHttpStatus, .pFault)
                Set tRefused = 1
                Quit
            }
            Set tParts = tParts _ $ListBuild(tValue)
        }
        If tRefused Quit
        If pIdValue = "" {
            Set tSC = ..Refuse("'" _ pIdArgument _ "' names " _ ..#CHILDDESCRIPTION _ " and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        For tI = 1:1:$ListLength(tParts) {
            If $List(tParts, tI) [ tSeparator {
                Set tSC = ..Refuse("'" _ $List(tArguments, tI) _ "' carries the character U+0001, which no " _ ..#SEPARATORNOUNS _ " holds", .pHttpStatus, .pFault)
                Set tRefused = 1
                Quit
            }
        }
        If tRefused Quit
        If pIdValue [ tSeparator {
            Set tSC = ..Refuse("'" _ pIdArgument _ "' carries the character U+0001, which no " _ ..#SEPARATORNOUNS _ " holds", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite(tParts _ $ListBuild(pIdValue))
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
