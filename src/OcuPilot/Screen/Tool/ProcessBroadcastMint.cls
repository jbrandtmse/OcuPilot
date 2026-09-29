/// <p>The mint <class>OcuPilot.Screen.Tool.ProcessBroadcast</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13): the kernel's own mint, after
/// the pid set and the message are checked. Everything else -- the fresh read, the diff, the
/// fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: a pid set
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.PidsProblem</method> refuses, then a message
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.MessageProblem</method> refuses.</p>
Class OcuPilot.Screen.Tool.ProcessBroadcastMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The tool whose two checks run first.</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ProcessBroadcast";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached only once
/// <var>pIdValue</var> is a pid set and <var>pArgs</var>' message is one to send.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(..#TOOLCLASS, "PidsProblem", pIdValue)
        If tProblem = "" {
            Set tMessage = ""
            If $IsObject(pArgs) Set tMessage = pArgs.%Get($Parameter(..#TOOLCLASS, "MESSAGEFIELD"))
            Set tProblem = $ClassMethod(..#TOOLCLASS, "MessageProblem", tMessage)
        }
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
