/// <p>The mint every percent-class access tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method>
/// (AD-6, AD-13, Story 18.10): the kernel's own mint, handed the entry's composite id <code>[Name, AllowType, Class]</code>
/// built from the agent's <code>Name</code>, <code>AllowType</code> and <code>Class</code> with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the percent-class access list's rows carry. Everything
/// else is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an empty name, and any part carrying
/// <code>$Char(1)</code>, the composite separator, which would let one argument stand for two parts.</p>
Class OcuPilot.Screen.Tool.WebAppPctAccessMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the application, which is the id's first part.</p>
Parameter NAMEARGUMENT = "Name";

/// <p>The argument naming the allow type, which is the id's second part.</p>
Parameter ALLOWARGUMENT = "AllowType";

/// <p>The argument naming the class or package, which is the id's third part.</p>
Parameter CLASSARGUMENT = "Class";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with <var>pIdValue</var> replaced by the
/// composite id of the three arguments. A <code>detail.problem</code> the superclass answers is made readable by
/// <method>OcuPilot.Screen.Tool.ErrorDeleteMint.ReadableId</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tName = ""
        Set tAllow = ""
        Set tClass = ""
        If $IsObject(pArgs) {
            If pArgs.%GetTypeOf(..#NAMEARGUMENT) = "string" Set tName = pArgs.%Get(..#NAMEARGUMENT)
            If pArgs.%GetTypeOf(..#ALLOWARGUMENT) = "string" Set tAllow = pArgs.%Get(..#ALLOWARGUMENT)
            If pArgs.%GetTypeOf(..#CLASSARGUMENT) = "string" Set tClass = pArgs.%Get(..#CLASSARGUMENT)
        }
        If (tName = "") || (tAllow = "") || (tClass = "") {
            Set tSC = ..Refuse("'" _ ..#NAMEARGUMENT _ "', '" _ ..#ALLOWARGUMENT _ "' and '" _ ..#CLASSARGUMENT _ "' name the entry and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If (tName [ tSeparator) || (tAllow [ tSeparator) || (tClass [ tSeparator) {
            Set tSC = ..Refuse("the entry's arguments carry the character U+0001, which no application, allow type or class holds", .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tName, tAllow, tClass))
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
