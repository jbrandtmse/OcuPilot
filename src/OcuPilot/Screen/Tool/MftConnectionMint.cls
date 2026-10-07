/// <p>The mint every managed file transfer connection tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, Story 18.26): the kernel's own mint, with an empty
/// name refused before anything is read. The kernel's mint treats an empty target id as its caller's fault and
/// answers an internal error; here the agent is told the name is required, in the published sentence of
/// <parameter>NAMECODE</parameter>, with 400 <code>TOOL.ARGUMENTS</code>. Everything else is
/// the superclass's, unchanged.</p>
Class OcuPilot.Screen.Tool.MftConnectionMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The violation code of an empty name, whose sentence <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answers.</p>
Parameter NAMECODE = "MFT.NAME";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, once <var>pIdValue</var> -- the agent's
/// <code>Name</code> -- is known to be non-empty.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    If pIdValue = "" {
        Set pProposal = ""
        Quit ..Refuse("'" _ pIdArgument _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(..#NAMECODE), .pHttpStatus, .pFault)
    }
    Quit ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
}

}
