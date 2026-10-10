/// <p>The Doc DB application editor's Save (AD-55, Story 18.30): <code>POST /docdb-application</code> creates one record
/// through <class>OcuPilot.Screen.Tool.DocDbAppCreate</class>, and <code>PUT /docdb-application/:id</code> changes one
/// through <class>OcuPilot.Screen.Tool.DocDbAppUpdate</class>, the tools the agent's mint and confirm read. Each is
/// resolved from its tool class, with every pair the tool declares asked before anything is read or sent, the rules of
/// <class>OcuPilot.Area.WebApp.DocDbAppRules</class>, AD-10's set before the port, and no proposal minted. The delete
/// is a row action (<class>OcuPilot.Screen.Tool.DocDbAppDelete</class>) and has no route here.</p>
/// <p>A record is addressed by its composite id <code>[Namespace, Name]</code>
/// (<class>OcuPilot.Kernel.EntityId</class>), which the tools' port splits: the namespace is sent upper-cased and the
/// name as typed.</p>
/// <p>Each Save runs, in this order: the caller's pairs (AD-8); the per-target lock (AD-34); the rules over the
/// arguments; for an edit the fresh read and the merge, and the rules over the payload it would send; AD-10's
/// prohibited set; the <code>PUT</code>; and the read-back (AD-58). A merge whose diff has no row sends nothing. A body
/// key the tool does not admit is 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.WebApp.DocDbAppSave Extends %RegisteredObject
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.DocDbAppCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DocDbAppUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppForm";

Parameter RULES = "OcuPilot.Area.WebApp.DocDbAppRules";

/// <p>The create body's identifying members, which are not settings.</p>
Parameter NAMEMEMBER = "Name";

Parameter NAMESPACEMEMBER = "Namespace";

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

/// <p>Answer <code>POST /docdb-application</code>: create one record from the body <code>{Namespace, Name,
/// &lt;settings&gt;}</code> and answer <code>{id, namespace, name, readBack}</code> with 201 (AD-58), the name as
/// written and the namespace as the instance stores it. A broken rule is one 422
/// <parameter>OcuPilot.Api.DocDbAppError.VALIDATION</parameter> envelope carrying every violation.</p>
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
        Set tNamespace = ""
        Set tName = ""
        Kill tShape
        Set tShape = 0
        For tMember = ..#NAMESPACEMEMBER, ..#NAMEMEMBER {
            Set tType = tBody.%GetTypeOf(tMember)
            If tType = "string" {
                If tMember = ..#NAMESPACEMEMBER Set tNamespace = tBody.%Get(tMember)
                If tMember = ..#NAMEMEMBER Set tName = tBody.%Get(tMember)
            } ElseIf tType '= "unassigned" {
                Do ..Add(.tShape, tMember, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            }
        }
        If tShape > 0 {
            Set tSC = $ClassMethod(..#RULES, "RenderViolations", .tShape)
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tNamespace, tName)), .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tNamespace, tName, ..CallerFields(tBody), .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tNamespace, tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Answer <code>PUT /docdb-application/:id</code>: change the record <var>pId</var> -- its composite id, one path
/// segment, decoded once here (AD-13) -- from the body's settings, merged over a fresh read (AD-4), and answer
/// <code>{id, namespace, name, readBack}</code> with 200, or <code>{id, namespace, name}</code> when nothing changes.
/// A record the instance does not hold, or an id that is not two parts, is 404 <code>PORT.NOTFOUND</code>. The body
/// names no identifying member: a <code>Name</code> or <code>Namespace</code> in it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>, because an update never changes the id.</p>
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
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(##class(OcuPilot.Kernel.EntityId).Decode(pId))
        Set tNamespace = $ListGet(tParts, 1)
        Set tName = $ListGet(tParts, 2)
        If ($ListLength(tParts) '= 2) || (tNamespace = "") || (tName = "") {
            Set tSC = $ClassMethod(..#RULES, "RenderRead", $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND), 404, "")
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tNamespace, tName)), .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Update(tNamespace, tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        If $$$ISERR(tPerformSC) && (+$Get(tViolations) = 0) && (+$Get(tHttp) = 404) {
            Set tSC = $ClassMethod(..#RULES, "RenderRead", tPerformSC, 404, "")
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tNamespace, tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Create the record <var>pName</var> in <var>pNamespace</var> from the settings <var>pArgs</var> supplies, composed
/// as the create tool composes them.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was written.
/// Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>. On success <var>pReadBack</var> is
/// the write's read-back (AD-58).</p>
ClassMethod Create(pNamespace As %String, pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
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
        Set tSC = $ClassMethod(..#RULES, "Check", pNamespace, pName, pArgs, "", "create", ..PortClass(), .pViolations, 1)
        If $$$ISERR(tSC) Quit
        If pViolations = 0 {
            Set tSC = $ClassMethod(..#RULES, "Taken", ..PortClass(), pNamespace, pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#NAMEMEMBER, ##class(OcuPilot.Api.DocDbAppError).#TAKEN)
        }
        If pViolations > 0 Quit
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the record's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, tId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the record <var>pName</var> in <var>pNamespace</var> by the settings <var>pArgs</var> sends, merged over a
/// fresh read by the tool's own merge, so the body is the complete set the read answered (AD-4). Nothing is sent when no
/// setting changed.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A record the instance does not define is an error status
/// with <var>pHttpStatus</var> 404 and nothing sent; a key the tool does not admit is an error status with
/// <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pNamespace As %String, pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
        Set tSC = ..Unexpected(tClass, pArgs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#RULES, "Check", "", "", pArgs, "", "update", ..PortClass(), .pViolations, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = tId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $ClassMethod(..#RULES, "Check", "", "", pArgs, tFresh, "update", ..PortClass(), .pViolations, 1)
            If $$$ISERR(tSC) || (pViolations > 0) Quit
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, tId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> when <var>pArgs</var> carries a
/// key <var>pToolClass</var> does not settle, before anything is read or sent.</p>
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
/// envelope, a refusal as its own envelope, and success as <code>{id, namespace, name}</code> at <var>pSuccess</var>,
/// the namespace upper-cased as the instance stores it, with <var>pReadBack</var> as <code>readBack</code> when there
/// is one.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pNamespace As %String, pName As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit $ClassMethod(..#RULES, "RenderViolations", .pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tNamespace = $ZConvert(pNamespace, "U")
    Set tAnswer = {}
    Do tAnswer.%Set("id", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tNamespace, pName)), "string")
    Do tAnswer.%Set("namespace", tNamespace, "string")
    Do tAnswer.%Set("name", pName, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
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

/// <p>A create's own body fields, minus the two identifying members, as one <class>%DynamicObject</class>.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do:(tFields.%GetTypeOf(..#NAMEMEMBER) '= "unassigned") tFields.%Remove(..#NAMEMEMBER)
    Do:(tFields.%GetTypeOf(..#NAMESPACEMEMBER) '= "unassigned") tFields.%Remove(..#NAMESPACEMEMBER)
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
