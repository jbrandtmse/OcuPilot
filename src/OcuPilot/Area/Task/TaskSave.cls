/// <p>The New Task wizard's Save (AD-55): <code>POST /tasks</code> creates one scheduled task through
/// <class>OcuPilot.Screen.Tool.TaskCreate</class>, the tool the agent's
/// <code>tasks.schedule.create</code> proposal is confirmed through.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port and the settable fields. It mints no proposal and takes no confirm token. It runs,
/// in order: the caller's pairs (AD-8), the name's shape, the absence read (a name any task holds,
/// compared without regard to case, is refused on <code>Name</code>), a check that the body carries
/// only the tool's settable keys, the rules, the tool's complete body, AD-10's prohibited set, the
/// tool's derived output directory, and only then the port. A vendor refusal the port maps to a
/// field answers as the form's own 422.</p>
/// <p><b>Edit task's Save</b> (Story 9.8): <code>PUT /tasks/:id</code> changes one task through
/// <class>OcuPilot.Screen.Tool.TaskUpdate</class>, in <method>Update</method>'s order, and answers
/// <code>{id, name}</code> with 200.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Task.TaskSave Extends %RegisteredObject
{

/// <p>The tool the create resolves through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.TaskCreate";

/// <p>The tool the edit resolves through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.TaskUpdate";

/// <p>The screen whose declared pairs gate the route, and whose entity type and scope the prohibited
/// set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The rules class the route applies.</p>
Parameter RULES = "OcuPilot.Area.Task.TaskRules";

/// <p>The port the absence read and the write go through, which is the tool's own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /tasks</code>: create one task from the body and answer
/// <code>{id, name, readBack}</code> with 201 (AD-58). A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.TASKVALIDATION</parameter> envelope carrying every violation; a
/// key outside the tool's settable fields is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; any other refusal is the port's
/// or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = ""
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tPerformSC = ..Create(tBody, .tHttp, .tFault, .tViolations, .tId, .tReadBack)
        If $Get(tViolations) > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tPerformSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPerformSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("id", tId, "number")
        Do tAnswer.%Set("name", tBody.%Get(..#IDARGUMENT), "string")
        If $IsObject($Get(tReadBack)) Do tAnswer.%Set("readBack", tReadBack)
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the task <var>pArgs</var> describes, answering its new id in <var>pId</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>: 400 for a key outside the settable fields, 403 for a prohibited create, and
/// the port's own for a vendor refusal. Nothing is sent on any of them but the last. On success
/// <var>pReadBack</var> is the write's read-back (AD-58); it is <code>""</code> otherwise.</p>
ClassMethod Create(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pId As %String, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pId = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tName = ""
        If pArgs.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = pArgs.%Get(..#IDARGUMENT)
        If tName = "" {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#TASKNAMEREQUIRED)
            Quit
        }
        If ($Length(tName) > $Parameter(..#RULES, "NAMEMAXLENGTH")) || '$Match(tName, "^[A-Za-z].*") {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#TASKNAMESHAPE)
            Quit
        }

        ; AD-54: the absence read, the same one the agent's mint makes.
        Set tSC = $ClassMethod(..#RULES, "NameTaken", tName, .tTaken)
        If $$$ISERR(tSC) Quit
        If tTaken {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#TASKNAMETAKEN)
            Quit
        }

        Set tSC = ..Undeclared(pArgs, $ListBuild(..#IDARGUMENT) _ $ClassMethod(tClass, "SettableFields"), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", "create", pArgs, .pViolations, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the create's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, tName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = tName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pId = $ClassMethod(tClass, "CreatedId", $Get(tWritten))
        If pId = "" {
            Set pHttpStatus = 500
            Set tSC = $$$ERROR($$$GeneralError, "the task was created and the instance answered no id for it")
            Quit
        }
        ; AD-58: the task read back, under the id the instance allocated, and compared with what was sent.
        Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tName, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer <code>PUT /tasks/:id</code>: change task <var>pId</var> -- one path segment, decoded
/// once here (AD-13) -- from the body, and answer <code>{id, name, readBack}</code> with 200
/// (AD-58). A task the instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.TASKABSENT</parameter>; a key outside the tool's settable fields
/// is 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a broken rule is one 422
/// envelope carrying every violation.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#UPDATETOOL)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = ""
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tId, tBody, .tHttp, .tFault, .tViolations, .tName, .tReadBack)
        If $Get(tViolations) > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTASKABSENT, ##class(OcuPilot.Api.Error).#TASKABSENT)
            Quit
        }
        If $$$ISERR(tPerformSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPerformSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("id", +tId, "number")
        Do tAnswer.%Set("name", tName, "string")
        If $IsObject($Get(tReadBack)) Do tAnswer.%Set("readBack", tReadBack)
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Change task <var>pId</var> by the fields <var>pArgs</var> sends, in <class>OcuPilot.Area.Security.SslSave</class>'s
/// order: an integer id; the edit tool's fresh read; the keys the tool admits; the fields that change;
/// the rules over them (<code>update</code> mode); the tool's own merge over the fresh read (AD-4);
/// AD-10's set; and only then the port, whose <code>PUT</code> omits what the vendor keeps. A body
/// that changes nothing sends nothing. <var>pName</var> is the task's name after the edit.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s, with <var>pHttpStatus</var> 404 for a task
/// the instance does not hold.</p>
ClassMethod Update(pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pName As %String, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pName = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        If '$Match(pId, "^[0-9]{1,18}$") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#TASKABSENT)
            Quit
        }
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "ReadIdParam")) = pId
        Set tSC = $ClassMethod(..UpdatePortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#TASKABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set pName = tFresh.%Get("Name")

        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ..Undeclared(pArgs, tSettable, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tChanged = $ClassMethod(..#RULES, "Changed", pArgs, tFresh)
        Set tSC = $ClassMethod(..#RULES, "Validate", "update", tChanged, .pViolations, 1, tFresh, pId)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        If tChanged.%Size() = 0 Quit

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, tChanged, $ClassMethod(tClass, "IdArgument"), tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pId
        Set tSC = $ClassMethod(..UpdatePortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        ; AD-58: the task read back through the tool's port and compared with what was sent.
        Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, tFresh, ..UpdatePortClass(), $Get(tWritten), pHttpStatus)
        Set pName = tPayload.%Get("Name")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The port the edit's read and write go through: the edit tool's own declaration (AD-52).
/// Overridable for the reason <method>PortClass</method> is; production never overrides it.</p>
ClassMethod UpdatePortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
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

/// <p>Move the <code>TASK.*</code> rows a port fault carries in <code>detail.violations</code> into
/// <var>pViolations</var>, so a vendor refusal the port maps to a field
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>) answers as the form's own 422.</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $Piece(tRow.%Get("code"), ".", 1) '= "TASK" Continue
        Do ..Add(.pViolations, tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the create tool <var>pToolClass</var> would make of <var>pName</var>
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

/// <p>Render one <code>(field, code)</code> violation as the 422 envelope.</p>
ClassMethod RenderOne(pField As %String, pCode As %String) As %Status
{
    Kill tViolations
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(pField, pCode)
    Quit ..RenderViolations(.tViolations)
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONTASKVALIDATION, ##class(OcuPilot.Api.Error).#TASKVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// the pair the tool's write declares beyond them (AD-8), before anything is read or sent.
/// <var>pToolClass</var> is the write's tool, the create's when it names none.</p>
ClassMethod Gate(Output pRefused As %Boolean, pToolClass As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    Set tTool = $Select(pToolClass '= "": pToolClass, 1: ..#CREATETOOL)
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPair = $ListBuild($Parameter(tTool, "WRITERESOURCE"), $Parameter(tTool, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
