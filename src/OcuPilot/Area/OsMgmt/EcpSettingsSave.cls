/// <p>ECP settings' Save (AD-55, Story 18.21): <code>PUT /ecp-settings</code> changes the instance's ECP
/// settings through <class>OcuPilot.Screen.Tool.EcpSettingsUpdate</class>, the tool the agent's mint and
/// confirm read.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request types,
/// the port, the settable objects, the member merge, the consequence and the pairs, each asked before
/// anything is read or sent. It mints no proposal and takes no confirm token. Every rule is checked before
/// the settings are read; a merge whose diff has no row sends nothing.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.OsMgmt.EcpSettingsSave Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EcpSettingsUpdate";

/// <p>The screen whose declared pairs gate the route, and whose entity type and scope the prohibited
/// set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpSettings";

/// <p>The rules class the route applies.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.EcpSettingsRules";

/// <p>The port the write and the fresh read go through, which is the tool's own declaration (AD-52).
/// Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>The one id the settings are known by (AD-13).</p>
ClassMethod TargetId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>Answer <code>PUT /ecp-settings</code>: change the settings by the members the body's
/// <code>AppServerSettings</code> and <code>DataServerSettings</code> carry and answer
/// <code>{readBack}</code> with 200 (AD-58), with <code>consequence</code> when the write carries one, or
/// <code>{}</code> when nothing changes. A top-level key other than the two objects, or a member neither
/// names, is 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a broken rule is one 422
/// <parameter>OcuPilot.Api.EcpError.SETTINGSVALIDATION</parameter> envelope carrying every violation; any
/// other refusal is the gate's, the port's or the prohibited set's own envelope.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, ..TargetId(), .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Update(tBody, .tHttp, .tFault, .tViolations, .tReadBack, .tConsequence)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), $Get(tReadBack), $Get(tConsequence))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Change the settings by the members <var>pArgs</var> sends, merged over the tool's fresh read, so a
/// member the caller did not send keeps the instance's value and the body is both objects read fresh
/// (AD-4).</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was
/// written. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>, with a port
/// refusal that names a field arriving as a violation too (<method>PortViolations</method>); a key the
/// tool does not admit is an error status with <var>pHttpStatus</var> 400 and nothing read. On a write,
/// <var>pReadBack</var> is its read-back (AD-58) and <var>pConsequence</var> the tool's consequence code
/// for it, read before the write; a merge that changes nothing sends nothing and leaves both empty.</p>
ClassMethod Update(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject, Output pConsequence As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set pConsequence = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tAllowed = $ClassMethod(tClass, "SettableFields")
        Set tUnexpected = $ClassMethod(..#RULES, "Unexpected", pArgs)
        If tUnexpected '= "" {
            Set pHttpStatus = 400
            Set pFault = ..Unexpected(tUnexpected)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
            Quit
        }

        ; AD-55: the rules the agent's mint applies, before the settings are read.
        Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = ..TargetId()
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the ECP settings read answered no object")
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, $ClassMethod(tClass, "IdArgument"), tAllowed, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }
        ; Nothing to change sends nothing.
        If tDiff.%Size() = 0 Quit

        Set tSC = ..Prohibited(tClass, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tConsequence = $ClassMethod(tClass, "Consequence", tPayload, 0, "")
        Set tSC = ..Send(tClass, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pConsequence = tConsequence
        Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, ..TargetId(), tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Move a refusal whose fault names <code>ECP.SETTINGS.*</code> fields into <var>pViolations</var>,
/// so it answers as the form's own 422.</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $Extract(tRow.%Get("code"), 1, 13) '= "ECP.SETTINGS." Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make carrying <var>pPayload</var>
/// and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), ..TargetId(), .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write with <var>pPayload</var> through
/// <method>PortClass</method>; <var>pWritten</var> is the port's answer.</p>
ClassMethod Send(pToolClass As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = ..TargetId()
    Do $ClassMethod(pToolClass, "PortQuery", pPayload, .tQuery)
    Do $ClassMethod(pToolClass, "DerivedFields", pPayload)
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome: the violations as one 422 envelope, a refusal as its own envelope, and success
/// as <code>{readBack, consequence}</code>, <code>consequence</code> only when the write carries one, or
/// <code>{}</code> when nothing was sent (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 {
        Set tDetail = {}
        Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
        Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.EcpError).#REASONSETTINGSVALIDATION, ##class(OcuPilot.Api.EcpError).#SETTINGSVALIDATION, tDetail)
    }
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    If pConsequence '= "" Do tAnswer.%Set("consequence", pConsequence, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
}

/// <p>The 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault for key
/// <var>pKey</var>.</p>
ClassMethod Unexpected(pKey As %String) As %DynamicObject [ Private ]
{
    Set tFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (pKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    Do tFault.%Set("detail", tDetail)
    Quit tFault
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or every
/// pair <parameter>UPDATETOOL</parameter>'s write declares, before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else (AD-8).</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tTool = ..#UPDATETOOL
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ tTool _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
