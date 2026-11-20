/// <p>The mint the Background tasks tools declare as their
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13): the kernel's own mint,
/// handed the row the agent's <code>source</code> and <code>id</code> name as one composite target
/// id, the grammar the screen sends. Everything else -- the fresh read, the diff, the fingerprint,
/// the stored row -- is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an argument carrying
/// <code>$Char(1)</code>, the composite separator, which would let one argument stand for two
/// parts.</p>
Class OcuPilot.Screen.Tool.BackgroundTaskMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the row's source.</p>
Parameter SOURCEARGUMENT = "source";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with
/// <var>pIdValue</var> replaced by the composite id joined from <method>CompositeParts</method>.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tParts = ..CompositeParts(pArgs, pIdValue, .tProblem)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite(tParts)
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The parts of the composite target id the agent's arguments <var>pArgs</var> and identifying value
/// <var>pIdValue</var> name, as a <code>%List</code>: the row's source, then its id. <var>pProblem</var> names an
/// argument carrying the composite separator, and the answer is then <code>""</code>. A subclass joining other
/// parts overrides this alone.</p>
ClassMethod CompositeParts(pArgs As %DynamicObject, pIdValue As %String, Output pProblem As %String) As %List
{
    Set pProblem = ""
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    Set tSource = ""
    If $IsObject(pArgs) Set tSource = pArgs.%Get(..#SOURCEARGUMENT)
    If $IsObject(tSource) || (tSource [ tSeparator) || (pIdValue [ tSeparator) {
        Set pProblem = "'source' or 'id' carries the character U+0001, which no background task's source or id holds"
        Quit ""
    }
    Quit $ListBuild(tSource, pIdValue)
}

}
