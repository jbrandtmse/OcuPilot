/// <p>The mint <class>OcuPilot.Screen.Tool.ErrorDelete</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, AD-48): the kernel's own
/// mint, handed the scope the agent's arguments name as one composite target id.</p>
/// <p>The agent names a scope with <code>namespace</code> and, optionally, <code>date</code> and
/// <code>errorNumber</code>. This class joins them with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method> into the prefix of the error's
/// composite id the screen caller sends for the same scope, so both callers hand the port one
/// target grammar. Everything else -- the fresh read, the diff, the fingerprint, the stored row --
/// is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an
/// <code>errorNumber</code> without a <code>date</code>, since a number identifies an error only
/// within one date; and any argument carrying <code>$Char(1)</code>, the composite separator,
/// which would let one argument stand for several parts.</p>
Class OcuPilot.Screen.Tool.ErrorDeleteMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument that narrows the scope to one date.</p>
Parameter DATEARGUMENT = "date";

/// <p>The argument that narrows a date's scope to one error.</p>
Parameter ERRORNUMBERARGUMENT = "errorNumber";

/// <p>What a refused composite id reads as in <code>detail.problem</code>: the separator shown as
/// a breadcrumb, <code>" &#8250; "</code>, rather than an unprintable control character.</p>
ClassMethod ReadableId(pText As %String) As %String
{
    Quit $Replace(pText, $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR), " " _ $Char(8250) _ " ")
}

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with
/// <var>pIdValue</var> replaced by the composite scope id the arguments name. A
/// <code>detail.problem</code> the superclass answers is made readable by
/// <method>ReadableId</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tDate = ""
        Set tNumber = ""
        If $IsObject(pArgs) {
            Set tIterator = pArgs.%GetIterator()
            Set tCarrier = ""
            While tIterator.%GetNext(.tKey, .tValue) {
                If $IsObject(tValue) Continue
                If tValue [ tSeparator Set tCarrier = tKey
                If tCarrier '= "" Quit
            }
            If tCarrier '= "" {
                Set tSC = ..Refuse("'" _ tCarrier _ "' carries the character U+0001, which no namespace, date or error number holds", .pHttpStatus, .pFault)
                Quit
            }
            Set tDate = pArgs.%Get(..#DATEARGUMENT)
            Set tNumber = pArgs.%Get(..#ERRORNUMBERARGUMENT)
        }
        If (tNumber '= "") && (tDate = "") {
            Set tSC = ..Refuse("'" _ ..#ERRORNUMBERARGUMENT _ "' names an error within one date, so it needs '" _ ..#DATEARGUMENT _ "' as well", .pHttpStatus, .pFault)
            Quit
        }
        Set tParts = $ListBuild(pIdValue)
        If tDate '= "" Set tParts = tParts _ $ListBuild(tDate)
        If tNumber '= "" Set tParts = tParts _ $ListBuild(tNumber)
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite(tParts)
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
        If $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") && (pFault.%Get("detail").%GetTypeOf("problem") = "string") {
            Do pFault.%Get("detail").%Set("problem", ..ReadableId(pFault.%Get("detail").%Get("problem")), "string")
        }
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
