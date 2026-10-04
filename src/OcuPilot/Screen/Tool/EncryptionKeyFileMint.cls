/// <p>The mint every encryption key file tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 18.7): the kernel's own
/// mint, handed the key file's composite id <code>[root, path]</code> built from the agent's
/// <parameter>ROOTARGUMENT</parameter> and <code>path</code> with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id a screen action sends, so both
/// callers hand <class>OcuPilot.Port.EncryptionPort</class> one target grammar.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an empty root or path, and
/// a part carrying <code>$Char(1)</code>, the composite separator. A create's new file is checked as its
/// write checks it first (<method>OcuPilot.Port.EncryptionPort.CheckCreate</method>), so an existing
/// name or a missing folder is refused on its field before the absence read.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The argument naming the allowed directory.</p>
Parameter ROOTARGUMENT = "root";

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, with <var>pIdValue</var>
/// -- the agent's <code>path</code> -- replaced by the composite id of the agent's root and that
/// path.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
        Set tRoot = ""
        If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#ROOTARGUMENT) = "string") Set tRoot = pArgs.%Get(..#ROOTARGUMENT)
        If tRoot = "" {
            Set tSC = ..Refuse("'" _ ..#ROOTARGUMENT _ "' names the allowed directory the key file is in and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If pIdValue = "" {
            Set tSC = ..Refuse("'" _ pIdArgument _ "' names the key file and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        If (tRoot [ tSeparator) || (pIdValue [ tSeparator) {
            Set tSC = ..Refuse("'" _ $Select(tRoot [ tSeparator: ..#ROOTARGUMENT, 1: pIdArgument) _ "' carries the character U+0001, which no directory or file name holds", .pHttpStatus, .pFault)
            Quit
        }
        If (pToolClass '= "") && ..CreatesOf(pToolClass) {
            Set tCheckSC = $ClassMethod(..PortClassOf(pToolClass), "CheckCreate", tRoot, pIdValue, .tResolved, .pHttpStatus, .pFault)
            If $$$ISERR(tCheckSC) {
                Set tSC = tCheckSC
                Quit
            }
            Set pHttpStatus = 0
            Set pFault = ""
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tRoot, pIdValue))
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
