/// <p>The mint <class>OcuPilot.Screen.Tool.InteropMessageResend</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 20.31): the kernel's own mint, after the message set is
/// checked. Everything else -- the fresh read, the diff, the fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: a set that is empty, over
/// <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter>, holds a member that is not a message header id, or an argument
/// carrying the digest a person reviews at (<method>OcuPilot.Screen.Tool.InteropMessageResend.SetProblem</method>).</p>
Class OcuPilot.Screen.Tool.InteropMessageResendMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The tool whose check runs first.</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.InteropMessageResend";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached only once <var>pIdValue</var> is a set of
/// messages to resend and <var>pArgs</var> carries no review.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(..#TOOLCLASS, "SetProblem", pIdValue, pArgs)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
