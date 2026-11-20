/// <p>The mint the Security advisor tools declare as their <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13): the
/// kernel's own mint, handed the recommendation's composite id <code>[Type, Element, Code]</code> built from the agent's
/// <code>type</code>, <code>element</code> and <code>code</code> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id
/// the advisor's rows carry. Everything else is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an empty type, element or code, and any part carrying
/// <code>$Char(1)</code>, the composite separator, which would let one argument stand for two parts. An element of one space is
/// the general row of a type and is kept exactly.</p>
Class OcuPilot.Screen.Tool.SecurityAdvisorMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the recommendation's type, which is the id's first part.</p>
Parameter TYPEARGUMENT = "type";

/// <p>The argument naming the recommendation's element, which is the id's second part.</p>
Parameter ELEMENTARGUMENT = "element";

/// <p>The argument naming the recommendation's code, which is the id's third part.</p>
Parameter CODEARGUMENT = "code";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with <var>pIdValue</var> replaced by the composite id of
/// the three arguments.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tType = ""
        Set tElement = ""
        Set tCode = ""
        If $IsObject(pArgs) {
            If pArgs.%GetTypeOf(..#TYPEARGUMENT) = "string" Set tType = pArgs.%Get(..#TYPEARGUMENT)
            If pArgs.%GetTypeOf(..#ELEMENTARGUMENT) = "string" Set tElement = pArgs.%Get(..#ELEMENTARGUMENT)
            If pArgs.%GetTypeOf(..#CODEARGUMENT) = "string" Set tCode = pArgs.%Get(..#CODEARGUMENT)
        }
        If (tType = "") || (tElement = "") || (tCode = "") {
            Set tSC = ..Refuse("'" _ ..#TYPEARGUMENT _ "', '" _ ..#ELEMENTARGUMENT _ "' and '" _ ..#CODEARGUMENT _ "' name the recommendation and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If (tType [ tSeparator) || (tElement [ tSeparator) || (tCode [ tSeparator) {
            Set tSC = ..Refuse("the recommendation's arguments carry the character U+0001, which no type, element or code holds", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tType, tElement, tCode))
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
