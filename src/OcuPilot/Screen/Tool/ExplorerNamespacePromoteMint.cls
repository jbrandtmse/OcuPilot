/// <p>The mint the Compare namespaces promote tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-10, AD-13, AD-53, Story 24.9): the kernel's own mint,
/// handed the set's canonical spelling once every document of it is one the agent may promote. Everything else -- the
/// fresh read, the card's row, the fingerprint, the stored row -- is the superclass's, unchanged.</p>
/// <p>In order, a refusal stores nothing: a set the tool's <method>OcuPilot.Screen.Tool.ExplorerNamespacePromote.SetProblem</method>
/// refuses is 400 <code>TOOL.ARGUMENTS</code>; a set naming one of OcuPilot's own documents is 403
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>; the port's <code>PLAN</code> of the set, in the
/// request's namespace (<method>OcuPilot.Kernel.Scope.Current</method>) against the other namespace, is read and its refusal
/// answered unchanged; and each step of that plan is held to <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>
/// for the other namespace. The arguments are then spelled as the payload names them (<code>Target</code>, <code>Spec</code>,
/// <code>Generated</code>), with the request's namespace as <code>Namespace</code>, which the confirm reads the plan in.</p>
Class OcuPilot.Screen.Tool.ExplorerNamespacePromoteMint Extends OcuPilot.Kernel.Proposal.Mint
{

/// <p>The superclass's <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, reached with the set's canonical spelling as
/// both the target and the tool's own argument.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tProblem = $ClassMethod(pToolClass, "SetProblem", pIdValue)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId($ClassMethod(pDescriptor, "PrimaryEntityType"), pIdValue)
        For tPart = 1:1:$Length(tId, ",") {
            If ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode($Piece(tId, ",", tPart)) {
                Set tSC = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Forbidden(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, .pHttpStatus, .pFault)
                Quit
            }
        }
        If $$$ISERR(tSC) Quit

        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Set tTarget = pArgs.%Get("target")
        Kill tQuery
        Set tQuery($Parameter(tPort, "DOCUMENTSKEY")) = tId
        Set tQuery($Parameter(tPort, "NAMESPACEKEY")) = ##class(OcuPilot.Kernel.Scope).Current()
        Set tQuery($Parameter(tPort, "TARGETKEY")) = tTarget
        Set tQuery($Parameter(tPort, "SPECKEY")) = pArgs.%Get("spec")
        If pArgs.%GetTypeOf("generated") = "string" Set tQuery($Parameter(tPort, "GENERATEDKEY")) = pArgs.%Get("generated")
        Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tPlan, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tFence = $ClassMethod(pToolClass, "StepsProblem", tTarget, tPlan)
        If tFence '= "" {
            Set tSC = ..Refuse(tFence, .pHttpStatus, .pFault)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set(pIdArgument, tId, "string")
        Do tArgs.%Set("Namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
        Do tArgs.%Set("Target", tTarget, "string")
        Do tArgs.%Set("Spec", pArgs.%Get("spec"), "string")
        Do tArgs.%Set("Generated", $Select(pArgs.%Get("generated") = "yes": "yes", 1: "no"), "string")
        Do tArgs.%Remove("target")
        Do tArgs.%Remove("spec")
        Do tArgs.%Remove("generated")
        Set tSC = ##super(pDescriptor, pToolName, pUser, pConvKey, pTurnKey, tArgs, pLimitsClass, .pProposal, .pHttpStatus, .pFault, pEndpoint, pIdParam, tId, pIdArgument, pSettable, pToolClass)
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
