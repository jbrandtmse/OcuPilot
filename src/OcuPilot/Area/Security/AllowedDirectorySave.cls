/// <p>The Allowed directories screen's Save (AD-21's tenth case, AD-53, AD-55, Stories 18.42 and 18.46): <code>POST /allowed-directories</code>
/// adds, changes or removes one entry of the instance's directory allow-list through
/// <class>OcuPilot.Screen.Tool.AllowedDirectoryUpdate</class> and <class>OcuPilot.Port.AllowListPort</class>. It is the
/// tool's one caller: the tool is never advertised, so the agent has no way to reach it, and
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> refuses a write of the target through any tool the agent can reach.</p>
/// <p><b>It is a person's own write, so it mints no proposal and takes no confirm token</b>, but it asks the tool's
/// governance key, which ships disabled: the owner decided the action is off until an administrator switches it on (AD-22).
/// No other person's write asks governance, and enforced read-only and the kill switch are the agent's alone (AD-53).</p>
/// <p>It runs, in order: the screen's pairs (AD-8), 403 naming the one the caller lacks; a body that is a JSON object of
/// <code>Action</code>, <code>Directory</code> and <code>NewDirectory</code> strings and nothing else (400); the governance
/// key, 403 <code>ALLOWLIST.OFF</code>; the per-target hold (AD-34); the port's fresh read, whose refusal is passed through
/// as it is; the prohibited set (AD-10); the write; and the read-back (AD-58). It answers 200
/// <code>{action, target, readBack}</code>.</p>
/// <p><code>GET /allowed-directories</code> answers that key's verdict for the screen, which draws Add, Change and Remove off
/// with the key's sentence while it is disabled: the same pairs, then the same governance decision. It holds nothing and
/// writes nothing.</p>
/// <p>Seams a subclass may override: <method>PortClass</method>, <method>ProhibitedClassName</method>,
/// <method>RegistryClass</method> and <method>CallerUsername</method>. Production overrides none.</p>
Class OcuPilot.Area.Security.AllowedDirectorySave Extends %RegisteredObject
{

/// <p>The tool the route resolves everything about the write from (AD-55).</p>
Parameter TOOL = "OcuPilot.Screen.Tool.AllowedDirectoryUpdate";

/// <p>The body's keys, which are the tool's declared values.</p>
Parameter VALUES = "Action,Directory,NewDirectory";

/// <p>The port a tool that declares the write base's own default resolves to (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit $Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS")
}

/// <p>AD-10's prohibited set, named exactly as the confirm path and the screen action route name it.</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass()
}

/// <p>The tool registry the write tool is resolved from.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it. Never taken from the body.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>POST /allowed-directories</code> (the header). A refusal is its own envelope: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>, 400 <code>AGENT.BADBODY</code>, 400
/// <code>PORT.FIELD.UNEXPECTED</code> or 400 <code>TOOL.ARGUMENTS</code> for a body that is not the three strings, 403
/// <code>ALLOWLIST.OFF</code>, 409 <code>WRITE.TARGETBUSY</code>, the port's own refusal of the change (<code>ALLOWLIST.*</code>
/// on the field it concerns), or 403 <code>PROHIBITED.*</code>.</p>
ClassMethod HandleSave() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        Set tToolClass = ..#TOOL
        If '..Admit(.tSC, .tTool, .tTargetRef, .tId, .tUser) Quit

        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tUnexpected = ..UnexpectedKey(tBody)
        If tUnexpected '= "" {
            Set tDetail = {"violations": []}
            Do tDetail.%Get("violations").%Push({"field": (tUnexpected), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tDetail)
            Quit
        }
        If '..Strings(tBody) {
            Set tSC = ..Refuse("each of Action, Directory and NewDirectory is a string")
            Quit
        }
        Set tPayloadJson = tBody.%ToJSON()

        ; AD-22: a person's own write asks its governance key only where the owner decided it ships off; before any read.
        Set tDecideSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide($Parameter(tToolClass, "TOOLNAME"), tTool.%Get("kind"), tUser, tBody, .tDecision)
        If $$$ISERR(tDecideSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tDecideSC))
            Quit
        }
        If 'tDecision("allowed") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.AllowListError).ReasonFor(##class(OcuPilot.Api.AllowListError).#OFF), ##class(OcuPilot.Api.AllowListError).#OFF)
            Quit
        }

        ; AD-34: the target is held from the fresh read through the write and its read-back.
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(tToolClass, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }

        ; The fresh read is the port's own, composed from the change, so a change the matrix refuses is refused here as it is.
        Set tFreshSC = ##class(OcuPilot.Kernel.Proposal.Operation).Read(tToolClass, ..PortClass(), $ClassMethod(tToolClass, "Endpoint"), $ClassMethod(tToolClass, "IdParam"), tId, tPayloadJson, .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tFreshSC) {
            Set tSC = ..Fault(tFreshSC, tReadHttp, .tReadFault)
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
            Quit
        }
        Set tDiffSC = $ClassMethod(tToolClass, "StateDiff", tFresh, .tRows, .tProblem)
        If $$$ISERR(tDiffSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tDiffSC))
            Quit
        }
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem)
            Quit
        }

        ; AD-10: the set the confirm asks, whatever the caller.
        Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, tPayloadJson, tRows.%ToJSON(), tPayloadJson, tUser, ..ProhibitedClassName(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
        If $$$ISERR(tGateSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tGateSC))
            Quit
        }
        If tRefused {
            Set tSC = ##class(OcuPilot.Api.Error).Render(tGateHttp, ##class(OcuPilot.Api.Error).#FORBIDDEN, ..ReasonFor(tGateCode), tGateCode, tGateDetail)
            Quit
        }

        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).Apply(tToolClass, ..PortClass(), $ClassMethod(tToolClass, "Endpoint"), $ClassMethod(tToolClass, "IdParam"), tId, tPayloadJson, "", .tWritten, .tWriteHttp, .tWriteFault, tFresh)
        If $$$ISERR(tWriteSC) {
            Set tSC = ..Fault(tWriteSC, tWriteHttp, .tWriteFault)
            Quit
        }
        ; AD-58: the list is read back through the tool's own port and read type, as the screen action route does.
        Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).Of(tToolClass, tId, "", tFresh, tPayloadJson, ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(tToolClass, ..PortClass()))

        Set tWireSC = ##class(OcuPilot.Kernel.EntityRef).Wire($ClassMethod($Parameter(tToolClass, "DESCRIPTORCLASS"), "PrimaryEntityType"), ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tId, .tTarget)
        If $$$ISERR(tWireSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tWireSC))
            Quit
        }
        Set tResult = {}
        Do tResult.%Set("action", ##class(OcuPilot.Kernel.Proposal.Operation).ChangeAction(tToolClass), "string")
        Do tResult.%Set("target", tTarget)
        Do tResult.%Set("readBack", tReadBack)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Resolve the tool, the target and the caller, and ask the screen's pairs (AD-8): 1 when the request may go on. Otherwise
/// <var>pSC</var> holds the status of the refusal it rendered, 403 naming the pair the caller lacks or 500 for a tool or a
/// target that cannot be resolved. Shared by <method>HandleSave</method> and <method>HandleState</method>, so the two ask the
/// same pairs of the same target.</p>
ClassMethod Admit(Output pSC As %Status, Output pTool As %DynamicObject, Output pTargetRef As %String, Output pId As %String, Output pUser As %String) As %Boolean [ Private ]
{
    Set pSC = $$$OK
    Set pTool = ""
    Set pTargetRef = ""
    Set pId = $Parameter("OcuPilot.Port.PathPort", "PURPOSE")
    Set pUser = ..CallerUsername()
    Set tToolClass = ..#TOOL
    Set tResolveSC = $ClassMethod(..RegistryClass(), "Resolve", $Parameter(tToolClass, "TOOLNAME"), .pTool, 1)
    If $$$ISERR(tResolveSC) || '$IsObject($Get(pTool)) {
        Set pSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the allowed directories tool is not registered")))
        Quit 0
    }
    Set tTargetSC = ##class(OcuPilot.Kernel.Proposal.Operation).TargetRefOf($Parameter(tToolClass, "DESCRIPTORCLASS"), pId, .pTargetRef)
    If $$$ISERR(tTargetSC) {
        Set pSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTargetSC))
        Quit 0
    }
    ; AD-8: the screen's pairs answer first, naming the pair that failed, before the body is read.
    Set tPairSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(pTool, pTargetRef, "", "", "{}", pUser, "", "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    If $$$ISERR(tPairSC) {
        Set pSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPairSC))
        Quit 0
    }
    If tRefused {
        Set pSC = ##class(OcuPilot.Api.Error).Render(tGateHttp, ##class(OcuPilot.Api.Error).#FORBIDDEN, ..ReasonFor(tGateCode), tGateCode, tGateDetail)
        Quit 0
    }
    Quit 1
}

/// <p>Answer <code>GET /allowed-directories</code> (the header): 200 <code>{enabled: true}</code> while the tool's governance key
/// is enabled, else 200 <code>{enabled: false, code: "ALLOWLIST.OFF", reason}</code> with
/// <class>OcuPilot.Api.AllowListError</class>'s sentence. A refusal is its own envelope: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>, or 500 <code>INTERNAL</code> for a gate that cannot answer.
/// It reads the key and nothing else, takes no hold and writes nothing.</p>
ClassMethod HandleState() As %Status
{
    Set tSC = $$$OK
    Try {
        If '..Admit(.tSC, .tTool, .tTargetRef, .tId, .tUser) Quit
        Set tDecideSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide($Parameter(..#TOOL, "TOOLNAME"), tTool.%Get("kind"), tUser, {}, .tDecision)
        If $$$ISERR(tDecideSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tDecideSC))
            Quit
        }
        Set tResult = {}
        If tDecision("allowed") {
            Do tResult.%Set("enabled", 1, "boolean")
        } Else {
            Do tResult.%Set("enabled", 0, "boolean")
            Do tResult.%Set("code", ##class(OcuPilot.Api.AllowListError).#OFF, "string")
            Do tResult.%Set("reason", ##class(OcuPilot.Api.AllowListError).ReasonFor(##class(OcuPilot.Api.AllowListError).#OFF), "string")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>The first key of <var>pBody</var> other than <parameter>VALUES</parameter>', or <code>""</code>: the write takes
/// those three alone, never a purpose, a path or a flag. A value past the instance's longest string or largest number is
/// iterated with its type, so it is judged and never raised.</p>
ClassMethod UnexpectedKey(pBody As %DynamicObject) As %String [ Private ]
{
    Set tUnexpected = ""
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If $ListFind($ListFromString(..#VALUES), tKey) Continue
        Set tUnexpected = tKey
        Quit
    }
    Quit tUnexpected
}

/// <p>Whether every <parameter>VALUES</parameter> member <var>pBody</var> carries is a string.</p>
ClassMethod Strings(pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set tAll = 1
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If tType '= "string" {
            Set tAll = 0
            Quit
        }
    }
    Quit tAll
}

/// <p>The written sentence <var>pCode</var> carries, from the proposal family's own resolver -- which is where the
/// <code>PROHIBITED.*</code> reasons live -- else the tool-result vocabulary's, where <code>AUTH.NOPRIVILEGE</code> already
/// is (AD-39).</p>
ClassMethod ReasonFor(pCode As %String) As %String [ Private ]
{
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(pCode)
    If tReason '= "" Quit tReason
    Quit ##class(OcuPilot.Api.Error).ReasonForToolCode(pCode)
}

/// <p>Render a port fault as the one envelope it already is, carrying its own status, code and structured detail (AD-12,
/// AD-39). A fault the port did not name is an internal error rather than an envelope with an empty code.</p>
ClassMethod Fault(pStatus As %Status, pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%Get("code") = "") || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pStatus))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttpStatus: +pHttpStatus, 1: 500), pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), pFault.%Get("detail"))
}

/// <p>A refusal the request earned: 400 <code>TOOL.ARGUMENTS</code> with <var>pProblem</var> as
/// <code>detail.problem</code>, the shape the mint answers its own refusals in.</p>
ClassMethod Refuse(pProblem As %String) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
}

}
