/// <p>The mint Story 18.22's two activate tools declare as their
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-21): the kernel's own mint, after the
/// key file the proposal names is checked as the write will check it. Everything else -- the fresh read,
/// the diff, the fingerprint, the stored row -- is the superclass's.</p>
/// <p>Refused before anything is stored, with the port's own answer unchanged
/// (<method>OcuPilot.Port.EncryptionPort.FileKeys</method>): an empty <code>root</code> or
/// <code>path</code>, a location <class>OcuPilot.Port.PathPort</class> refuses or that holds no file, a
/// file that is not a key file, and a file whose every key is already active. Otherwise the file's key
/// ids reach the tool's merge as <parameter>OcuPilot.Screen.Tool.EncryptionKeyWrite.FILEKEYSARGUMENT</parameter>,
/// which the card lists.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyActivateMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached only once
/// <var>pArgs</var>' key file passes the port's checks.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tPort = ..PortClassOf(pToolClass)
        Set tRoot = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pArgs, $Parameter(tPort, "ROOTPARAM"))
        Set tPath = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pArgs, $Parameter(tPort, "PATHPARAM"))
        Set tSC = $ClassMethod(tPort, "FileKeys", tRoot, tPath, $Parameter(pToolClass, "ACTION"), .tIds, .pHttpStatus, .pFault, .tNames, .tFile)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set tJoined = ""
        Set tIterator = tIds.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tId) {
            Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ", ") _ tId
        }
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set($Parameter(pToolClass, "FILEKEYSARGUMENT"), tJoined, "string")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
