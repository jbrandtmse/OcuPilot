/// <p>The superserver editor's Save (AD-55, Story 18.25): <code>POST /superserver</code> creates one
/// superserver through <class>OcuPilot.Screen.Tool.SuperserverCreate</class>, and <code>PUT
/// /superserver/:id</code> changes one through <class>OcuPilot.Screen.Tool.SuperserverUpdate</class>, the tools
/// the agent's mint and confirm read. Each is resolved from its tool class, with every pair the tool declares
/// asked before anything is read or sent, the rules of <class>OcuPilot.Area.Security.SuperserverRules</class>,
/// AD-10's set before the port, and no proposal minted. The delete is a row action
/// (<class>OcuPilot.Screen.Tool.SuperserverDelete</class>) and has no route here.</p>
/// <p>Each Save runs, in this order: the caller's pairs (AD-8); the per-target lock (AD-34); the rules over the
/// arguments; for an edit the fresh read and the merge, and the rules over the payload it would send; AD-10's
/// prohibited set; the <code>PUT</code>; and the read-back (AD-58). <b>No body carries
/// <code>SystemDefault</code></b>: the merge leaves it out, and a body that names it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>. A merge whose diff has no row sends
/// nothing.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.Security.SuperserverSave Extends %RegisteredObject
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.SuperserverCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SuperserverUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverForm";

Parameter RULES = "OcuPilot.Area.Security.SuperserverRules";

/// <p>The create body's two identifying members, which are not settings.</p>
Parameter PORTMEMBER = "Port";

Parameter BINDMEMBER = "BindAddress";

/// <p>The port the writes and the edit's fresh read go through, the tools' own declaration (AD-52).
/// Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason <method>PortClass</method>
/// is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /superserver</code>: create one superserver from the body and answer <code>{id,
/// readBack}</code> with 201 (AD-58), <code>id</code> the composite id in its canonical spelling. A broken rule is
/// one 422 <parameter>OcuPilot.Api.SuperserverError.VALIDATION</parameter> envelope carrying every violation.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#CREATETOOL)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tPort = ""
        If (tBody.%GetTypeOf(..#PORTMEMBER) = "string") || (tBody.%GetTypeOf(..#PORTMEMBER) = "number") Set tPort = tBody.%Get(..#PORTMEMBER) _ ""
        Set tBind = ""
        Set tBindType = tBody.%GetTypeOf(..#BINDMEMBER)
        If tBindType = "string" Set tBind = tBody.%Get(..#BINDMEMBER)
        If (tBindType '= "string") && (tBindType '= "unassigned") {
            Kill tShape
            Do ..Add(.tShape, ..#BINDMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Set tSC = $ClassMethod(..#RULES, "RenderViolations", .tShape)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tPort, tBind))
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tPort, tId, ..CallerFields(tBody), .tHttp, .tFault, .tViolations, .tReadBack, tBind)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tId, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Answer <code>PUT /superserver/:id</code>: change the superserver <var>pId</var> -- one path segment,
/// decoded once here (AD-13) -- from the body's settings, merged over a fresh read (AD-4), and answer
/// <code>{id, readBack, consequence}</code> with 200, the last when the change carries one, or <code>{id}</code>
/// when nothing changes. A superserver the instance does not define is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#UPDATETOOL)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Update(tId, ..CallerFields(tBody), .tHttp, .tFault, .tViolations, .tReadBack, .tConsequence)
        If $$$ISERR(tPerformSC) && (+$Get(tViolations) = 0) && (+$Get(tHttp) = 404) {
            Set tSC = $ClassMethod(..#RULES, "RenderRead", tPerformSC, 404, "")
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tId, $Get(tReadBack), $Get(tConsequence))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Create the superserver at <var>pId</var>, whose port is <var>pPort</var> and bind address
/// <var>pBind</var>, from the settings <var>pArgs</var> supplies, composed as the create tool composes them.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was
/// written. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>. On success
/// <var>pReadBack</var> is the write's read-back (AD-58).</p>
ClassMethod Create(pPort As %String, pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject, pBind As %String = "") As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = ..Unexpected(tClass, pArgs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#RULES, "Check", pPort, pArgs, "", "create", ..PortClass(), .pViolations, 1, pBind)
        If $$$ISERR(tSC) Quit
        If pViolations = 0 {
            Set tSC = $ClassMethod(..#RULES, "Taken", ..PortClass(), pId, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, "Port", ##class(OcuPilot.Api.SuperserverError).#TAKEN)
        }
        If pViolations > 0 Quit
        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the superserver's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the superserver <var>pId</var> by the settings <var>pArgs</var> sends, merged over a fresh read by
/// the tool's own merge, so the body is the complete set the read answered less <code>SystemDefault</code>
/// (AD-4). Nothing is sent when no setting changed. <var>pConsequence</var> is the effect the change carries
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>) over the fresh read this merge took.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A superserver the instance does not define is an
/// error status with <var>pHttpStatus</var> 404 and nothing sent; a key the tool does not admit is an error status
/// with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject, Output pConsequence As %String) As %Status
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
        Set tSC = ..Unexpected(tClass, pArgs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#RULES, "Check", "", pArgs, "", "update", ..PortClass(), .pViolations, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = $ClassMethod(tClass, "MergeRaw", tFresh, pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = $ClassMethod(..#RULES, "Check", "", tPayload, tFresh, "update", ..PortClass(), .pViolations, 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tEffectSC = $ClassMethod(..ProhibitedClass(), "WeakensByEffect", ##class(OcuPilot.Kernel.Proposal.Prohibited).#TYPESUPERSERVER, tPayload, tFresh, .pConsequence, pId)
        If $$$ISERR(tEffectSC) Set pConsequence = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTSERVINGSUPERSERVER
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> when <var>pArgs</var> carries a
/// key <var>pToolClass</var> does not settle, before anything is read or sent. <code>SystemDefault</code> is
/// among them.</p>
ClassMethod Unexpected(pToolClass As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tAllowed = $ClassMethod(pToolClass, "SettableFields")
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(tAllowed, tKey) Continue
        Set pHttpStatus = 400
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
        Set tDetail = {"violations": []}
        Do tDetail.%Get("violations").%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
        Do pFault.%Set("detail", tDetail)
        Quit
    }
    If pHttpStatus = 400 Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
    Quit $$$OK
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pId</var>; a
/// <code>PROHIBITED.*</code> verdict is an error status with a 403 fault. A target the set cannot read is an
/// error status carrying no fault, which the answer renders as an internal error: nothing is written.</p>
ClassMethod Prohibited(pToolClass As %String, pId As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pId</var> with <var>pPayload</var>, through
/// <method>PortClass</method>.</p>
ClassMethod Send(pToolClass As %String, pId As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pId
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as one 422
/// envelope, a refusal as its own envelope, and success as <code>{id}</code> at <var>pSuccess</var>, with
/// <var>pReadBack</var> as <code>readBack</code> and <var>pConsequence</var> as <code>consequence</code> when
/// there are any.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pId As %String, pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit $ClassMethod(..#RULES, "RenderViolations", .pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("id", ##class(OcuPilot.Kernel.EntityRef).NormalizedId($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), pId), "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    If pConsequence '= "" Do tAnswer.%Set("consequence", pConsequence, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(pSuccess, tAnswer)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>The caller's own body fields, minus the two identifying members, as one
/// <class>%DynamicObject</class>.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do:(tFields.%GetTypeOf(..#PORTMEMBER) '= "unassigned") tFields.%Remove(..#PORTMEMBER)
    Do:(tFields.%GetTypeOf(..#BINDMEMBER) '= "unassigned") tFields.%Remove(..#BINDMEMBER)
    Quit tFields
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs or every pair
/// the write tool <var>pWriteTool</var> declares (AD-8, AD-44) before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean, pWriteTool As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    If pWriteTool = "" Quit $$$OK
    Set tPairs = $ClassMethod(pWriteTool, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ pWriteTool _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
