/// <p>The user audit event editor's Save (AD-55, DW-1573): <code>POST /audit-events</code> registers
/// one event through <class>OcuPilot.Screen.Tool.AuditUserEventCreate</class>, and
/// <code>PUT /audit-events/:id</code> changes one event's Description through
/// <class>OcuPilot.Screen.Tool.AuditUserEventUpdate</class>. The agent's half is the same two tool
/// classes read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable fields and the payload composition. It mints no proposal and takes
/// no confirm token. A create runs the caller's pairs (AD-8), the editor's rules
/// (<class>OcuPilot.Area.Security.AuditEventRules</class>), a fresh read that must find the event
/// absent -- the vendor's <code>PUT</code> is an upsert that folds case, so a present one is refused
/// rather than overwritten (AD-54) -- AD-10's set over the caller's fields, the composed payload and
/// only then the port. An edit sends only <code>Description</code>: it runs the caller's pairs, the
/// fresh read, the ownership rule, the Description rule, the merge over the fresh read (AD-4), AD-10's
/// set and only then the port, so the untouched <code>Enabled</code> is sent as the instance holds
/// it.</p>
/// <p>Both tools declare <code>MOVESMARKING</code>, so after a write that read OK the Save observes
/// and records whether agent writes are marked, as a screen action does; that observation never
/// fails the write (AD-53 as amended, AD-15). Success answers <code>{target}</code>, the canonical
/// triple the client publishes (AD-14).</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.AuditEventSave Extends %RegisteredObject
{

/// <p>The tool classes the two Saves resolve their writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.AuditUserEventCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AuditUserEventUpdate";

/// <p>The screen whose declared pairs gate the routes, and whose entity type and scope the
/// references carry (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

/// <p>The tools' identifying argument.</p>
Parameter IDARGUMENT = "EventName";

/// <p>The only key an edit's body may carry.</p>
Parameter EDITFIELDS = "Description";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.Security.AuditEventRules";

/// <p>The port the fresh reads and the writes go through, which is the tools' own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
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

/// <p>Answer <code>POST /audit-events</code>: register one event from the body's
/// <code>Source</code>, <code>Type</code>, <code>Name</code>, <code>Description</code> and
/// <code>Enabled</code>, and answer <code>{target}</code> with 201. A broken rule, or an event the
/// instance already holds, is one 422 <code>AUDITEVENT.VALIDATION</code> envelope carrying every
/// violation; any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = $ClassMethod(..#RULES, "Gate", .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tPerformSC = ..Create(tBody, .tEventName, .tHttp, .tFault, .tViolations)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, $Get(tEventName))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /audit-events/:id</code>: change the Description of the event <var>pId</var>
/// -- one path segment, decoded once here (AD-13) -- and answer <code>{target}</code> with 200. A key
/// other than <code>Description</code> is 400 <code>PORT.FIELD.UNEXPECTED</code>; an event the
/// instance does not hold is 404 <code>AUDITEVENT.ABSENT</code>; a system event is 422
/// <code>AUDITEVENT.VALIDATION</code> carrying <code>AUDITEVENT.SYSTEM</code> on <code>EventName</code>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = $ClassMethod(..#RULES, "Gate", .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tEventName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tEventName, tBody, .tHttp, .tFault, .tViolations)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && ($Get(tViolations) = 0) {
            Set tSC = $ClassMethod(..#RULES, "RenderCode", 404, ##class(OcuPilot.Api.Error).#AUDITEVENTABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tEventName)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Register the event <var>pArgs</var> names by its <code>Source</code>, <code>Type</code> and
/// <code>Name</code>, answering its <code>Source/Type/Name</code> in <var>pEventName</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written and the other outputs say nothing. Otherwise an error
/// status carries <var>pHttpStatus</var> and <var>pFault</var>.</p>
ClassMethod Create(pArgs As %DynamicObject, Output pEventName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pEventName = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, 1, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set pEventName = pArgs.%Get("Source") _ "/" _ pArgs.%Get("Type") _ "/" _ pArgs.%Get("Name")

        ; AD-54: the vendor's PUT is an upsert that folds case, so an event somebody holds under any
        ; spelling of this name is refused here and never overwritten.
        Set tClass = ..#CREATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pEventName
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
            Set pHttpStatus = +$Get(tReadHttp)
            Set pFault = $Get(tReadFault)
            Set tSC = tReadSC
            Quit
        }
        If $$$ISOK(tReadSC) && $IsObject($Get(tFresh)) && tFresh.%IsA("%Library.DynamicObject") {
            Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.Error).#AUDITEVENTTAKEN)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pEventName, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tComposeSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the create's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Send(tClass, pEventName, tPayload, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the Description of the event <var>pEventName</var> by the one field <var>pArgs</var>
/// sends, merged over a fresh read, so <code>Enabled</code> keeps the instance's value (AD-4).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. An event the instance does not hold is
/// an error status with <var>pHttpStatus</var> 404 and no stub is created; a key outside
/// <parameter>EDITFIELDS</parameter> is an error status with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pEventName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..Undeclared(pArgs, $ListFromString(..#EDITFIELDS), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pEventName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#AUDITEVENTABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tOwner = $ClassMethod(..#RULES, "OwnerProblem", tClass, pEventName)
        If tOwner '= "" {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#IDARGUMENT, tOwner)
            Quit
        }

        Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, 0, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pEventName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Send(tClass, pEventName, tPayload, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse every key of <var>pArgs</var> outside <var>pAllowed</var>: an error status with a 400
/// <code>PORT.FIELD.UNEXPECTED</code> fault naming each key in <code>detail.violations</code>, or
/// <code>$$$OK</code>.</p>
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

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pEventName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error
/// status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pEventName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pEventName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pEventName</var> with
/// <var>pPayload</var>, through <method>PortClass</method>; once it reads OK, observe the marking
/// fact when the tool moves it.</p>
ClassMethod Send(pToolClass As %String, pEventName As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pEventName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .tAnswer, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && ##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(pToolClass) Do ..ObserveMarking(pToolClass)
    Quit tSC
}

/// <p>Re-read, through <var>pToolClass</var>'s own port and as the caller, whether this instance
/// marks agent writes, and record what was observed (AD-53 as amended, AD-15). A failed observation
/// records nothing and logs <class>OcuPilot.Api.ScreenAction</class>'s one line.</p>
/// <p><b>Never propagates and never fails the write</b>: the write has already been applied.</p>
ClassMethod ObserveMarking(pToolClass As %String) [ Private ]
{
    Try {
        Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pToolClass, ..PortClass())
        Set tObserveSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
        If $$$ISOK(tObserveSC) {
            Do ##class(OcuPilot.Kernel.Audit.Event).RecordMarking(tMarked)
            Quit
        }
        Do ##class(OcuPilot.Api.ScreenAction).LogObserveFailure(pToolClass, tObserveSC)
    } Catch ex {
        Try {
            Do ##class(OcuPilot.Api.ScreenAction).LogObserveFailure(pToolClass, ex.AsStatus())
        } Catch {
        }
    }
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as
/// one 422 envelope, a refusal as its own envelope, and success as <code>{target}</code>, the
/// canonical triple (AD-13), at <var>pSuccess</var>.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pEventName As %String) As %Status [ Private ]
{
    If $Get(pViolations) > 0 {
        Set tDetail = {}
        Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
        Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONAUDITEVENTVALIDATION, ##class(OcuPilot.Api.Error).#AUDITEVENTVALIDATION, tDetail)
    }
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    ; AD-13: the triple the client publishes carries the type's canonical spelling of the id.
    Set tType = $ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, pEventName), .tTarget)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
    Set tAnswer = {}
    Do tAnswer.%Set("target", tTarget)
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

/// <p>The caller's own body fields, minus the three identity parts, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on a create. It is not the
/// composed payload, so a field the tool does not admit reaches the set rather than being silently
/// dropped.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tParts = $ListFromString($Parameter(..#RULES, "PARTS"))
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(tParts, tKey) || (tKey = ..#IDARGUMENT) Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tFields.%Set(tKey, pArgs.%Get(tKey))
        } Else {
            Do tFields.%Set(tKey, pArgs.%Get(tKey), tType)
        }
    }
    Quit tFields
}

}
