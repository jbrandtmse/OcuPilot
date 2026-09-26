/// <p>The service form's Save (AD-55): <code>PUT /services/:id</code> changes one service through
/// <class>OcuPilot.Screen.Tool.ServiceUpdate</class>, the tool the agent's
/// <code>permissions.services.update</code> proposal is confirmed through.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable fields and the merge. It mints no proposal and takes no confirm
/// token. It runs, in <class>OcuPilot.Area.Security.SslSave</class>'s order: the caller's pairs
/// (AD-8), the fresh read, a check that the body carries only the tool's settable keys, the rules
/// over the changed fields, the merge (AD-4), AD-10's prohibited set, and only then the port.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Permissions.ServiceSave Extends %RegisteredObject
{

/// <p>The tool class the Save resolves the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.ServiceUpdate";

/// <p>The screen whose declared pairs gate the route, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ServiceForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The rules class the Save applies.</p>
Parameter RULES = "OcuPilot.Area.Permissions.ServiceRules";

/// <p>The port the fresh read and the write go through, which is the tool's own declaration
/// (AD-52). Overridable so a fixture can hold the write; production never overrides it.</p>
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

/// <p>Answer <code>PUT /services/:id</code>: change the service <var>pId</var> -- one path segment,
/// decoded once here (AD-13) -- from the body, and answer <code>{name, readBack}</code> with 200
/// (AD-58). A broken rule is one 422 <parameter>OcuPilot.Api.Error.SERVICEVALIDATION</parameter>
/// envelope; a key outside the tool's settable fields is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a service the instance does not
/// hold is 404 <parameter>OcuPilot.Api.Error.SERVICEABSENT</parameter>; a prohibited change is 403
/// with its <code>PROHIBITED.*</code> code.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && ($Get(tViolations) = 0) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONSERVICEABSENT, ##class(OcuPilot.Api.Error).#SERVICEABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Change the service <var>pName</var> by the fields <var>pArgs</var> sends, merged over a fresh
/// read by the tool's own <code>MergeUpdate</code>, so a field the caller did not send keeps the
/// instance's value and the body is the complete set (AD-4).</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>: 404 for an absent service, 400 for an undeclared key, 403 for a prohibited
/// change, and the port's own for a vendor refusal. Nothing is sent on any of them but the last. On
/// success <var>pReadBack</var> is the write's read-back (AD-58); it is <code>""</code>
/// otherwise.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#SERVICEABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ..Undeclared(pArgs, tSettable, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tChanged = $ClassMethod(..#RULES, "Changed", pArgs, tFresh)
        Set tSC = $ClassMethod(..#RULES, "Validate", pName, tChanged, tFresh, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, tChanged, ..#IDARGUMENT, tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tAnswer, .pHttpStatus, .pFault)
        ; AD-58: the service read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, tFresh, ..PortClass(), $Get(tAnswer), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse every key of <var>pArgs</var> outside <var>pAllowed</var>: an error status with a 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault naming each key in
/// <code>detail.violations</code>, or <code>$$$OK</code>.</p>
ClassMethod Undeclared(pArgs As %DynamicObject, pAllowed As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRows = []
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pAllowed, tKey) Continue
        Do tRows.%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    }
    If tRows.%Size() = 0 Quit $$$OK
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error
/// status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Render the outcome of <method>Update</method>: the violations as one 422 envelope, a refusal
/// as its own envelope, and success as <code>{name}</code> at 200, with <var>pReadBack</var> as
/// <code>readBack</code> when there is one (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pName As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 {
        Set tDetail = {}
        Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
        Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONSERVICEVALIDATION, ##class(OcuPilot.Api.Error).#SERVICEVALIDATION, tDetail)
    }
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", pName, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    Quit ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// the pair the tool's write declares beyond them (AD-8), before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPair = $ListBuild($Parameter(..#UPDATETOOL, "WRITERESOURCE"), $Parameter(..#UPDATETOOL, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
