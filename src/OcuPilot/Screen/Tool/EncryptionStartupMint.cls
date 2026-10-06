/// <p>The mint <class>OcuPilot.Screen.Tool.EncryptionStartupUpdate</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-26, Story 18.23): the kernel's own mint,
/// after the port's explicit version gate (<method>OcuPilot.Port.EncryptionPort.SettingsGate</method>) and
/// its rules (<method>OcuPilot.Port.EncryptionPort.StartupProblems</method>) over the payload the tool's
/// merge would store, without the password the person types at the confirm. Either refusal is answered as
/// the port answers it, before anything is stored. Everything else -- the fresh read, the diff, the
/// fingerprint, the stored row -- is the superclass's.</p>
Class OcuPilot.Screen.Tool.EncryptionStartupMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached only once the version
/// gate and the rules pass.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tPort = ..PortClassOf(pToolClass)
        Set tSC = $ClassMethod(tPort, "SettingsGate", .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set tMergeSC = $ClassMethod(pToolClass, "MergeUpdate", tFresh, pArgs, pIdArgument, pSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISOK(tMergeSC) && (tProblem = "") && $IsObject(tPayload) {
            Set tWanted = $ClassMethod(tPort, "Wanted", tFresh, tPayload, .tWantedProblem)
            If tWantedProblem = "" {
                Set tAdmin = ##class(OcuPilot.Area.Security.EncryptionRules).Value(tPayload, $Parameter(pToolClass, "ADMINFIELD"))
                Set tRoot = ##class(OcuPilot.Area.Security.EncryptionRules).Value(tPayload, "root")
                Set tPath = ##class(OcuPilot.Area.Security.EncryptionRules).Value(tPayload, "path")
                Set tSC = $ClassMethod(tPort, "StartupProblems", tWanted, tFresh, tRoot, tPath, tAdmin, "", 0, .tKeyFile, .tNewFile, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, pArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, pIdValue, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
