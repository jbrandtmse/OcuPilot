/// <p>The namespace mapping editor's Save (AD-55, Story 18.14): <code>POST /mapping/:kind</code>
/// creates one mapping of kind <code>global</code>, <code>routine</code> or <code>package</code>
/// through the kind's create tool, and <code>PUT /mapping/:kind/:id</code> changes one through its
/// edit tool. The agent's half is the same tool classes read by
/// <class>OcuPilot.Kernel.Proposal.Mint</class> and <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition, the database spelling and the
/// pairs the write needs beyond the form's. It mints no proposal and takes no confirm token. A create
/// runs, in order: the caller's pairs (AD-8), the name's own rules, AD-10's prohibited set over the
/// caller's fields, the form's rules, the composed payload, and only then the port. An edit runs the
/// caller's pairs, the fresh read, a check that the body carries only the kind's template fields,
/// the form's rules over the fields it changes, the merge over the fresh read (AD-4), the prohibited
/// set over the merged payload and only then the port.</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b>, so an edit whose mapping is gone by the time
/// its fresh read is made answers 404 <code>MAPPING.NAME.ABSENT</code> and sends nothing, rather
/// than re-creating it.</p>
/// <p>A mapping is addressed by its composite id <code>[namespace, Name]</code>
/// (<class>OcuPilot.Kernel.EntityId</class>), which the tools' port splits.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.OsMgmt.MappingSave Extends %RegisteredObject
{

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.MappingRules";

/// <p>The input properties that name the target.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

Parameter IDARGUMENT = "Name";

/// <p>The port the writes and the edit's fresh read go through, which is the tools' own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass("global", "Update"), "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /mapping/:kind</code>: create one mapping of kind <var>pKind</var> from the
/// body <code>{Namespace, Name, &lt;template fields&gt;}</code> and answer <code>{id, namespace, name,
/// readBack}</code> with 201 (AD-58). A broken rule is one 422 <code>MAPPING.VALIDATION</code> envelope
/// carrying every violation; any other refusal is the port's or the prohibited set's own
/// envelope.</p>
ClassMethod HandleCreate(pKind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '$ClassMethod(..#RULES, "IsKind", pKind) {
            Set tSC = $ClassMethod(..#RULES, "NotAKind")
            Quit
        }
        Set tGateSC = ..Gate(pKind, .tRefused, ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass(pKind, "Create"))
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
        If tBody.%GetTypeOf(..#NAMESPACEARGUMENT) = "string" Set tNamespace = tBody.%Get(..#NAMESPACEARGUMENT)
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Create(pKind, tNamespace, tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tNamespace, tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /mapping/:kind/:id</code>: change the mapping <var>pId</var> -- its composite
/// id, one path segment, decoded once here (AD-13) -- from the body's template fields, and answer
/// <code>{id, namespace, name, readBack}</code> with 200 (AD-58). A key outside the template is 400
/// <code>PORT.FIELD.UNEXPECTED</code>; a mapping the namespace does not hold, or an id that is not
/// two parts, is 404 <code>MAPPING.NAME.ABSENT</code>.</p>
ClassMethod HandleUpdate(pKind As %String, pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '$ClassMethod(..#RULES, "IsKind", pKind) {
            Set tSC = $ClassMethod(..#RULES, "NotAKind")
            Quit
        }
        Set tGateSC = ..Gate(pKind, .tRefused, ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass(pKind, "Update"))
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
            Set tSC = ..Absent()
            Quit
        }
        Set tPerformSC = ..Update(pKind, tNamespace, tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) {
            Set tSC = ..Absent()
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tNamespace, tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the mapping <var>pName</var> of kind <var>pKind</var> in namespace
/// <var>pNamespace</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written and the other outputs say nothing. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a vendor refusal that names a field arrives as a
/// violation too (<method>PortViolations</method>). On success <var>pReadBack</var> is the write's
/// read-back (AD-58); it is <code>""</code> otherwise.</p>
ClassMethod Create(pKind As %String, pNamespace As %String, pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Do $ClassMethod(..#RULES, "NameViolation", pKind, pName, .pViolations)
        If pNamespace = "" Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMESPACEARGUMENT, ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT)
        If pViolations > 0 Quit

        Set tClass = $ClassMethod(..#RULES, "ToolClass", pKind, "Create")
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
        ; AD-10, AD-55. The set the confirm asks, before the port and before the rules, over the
        ; caller's own fields, so a field the tool does not admit reaches the set rather than being
        ; silently dropped.
        Set tSC = ..Prohibited(pKind, tClass, tId, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pKind, pNamespace, pName, pArgs, .pViolations, "create", 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the mapping's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, tId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
        ; AD-58: the mapping read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the mapping <var>pName</var> of kind <var>pKind</var> in namespace <var>pNamespace</var>
/// by the fields <var>pArgs</var> sends, merged over a fresh read, so a field the caller did not send
/// keeps the instance's value and the body is the complete set (AD-4).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A mapping the instance does not hold is an
/// error status with <var>pHttpStatus</var> 404 and nothing sent; a key outside the template is an
/// error status with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pKind As %String, pNamespace As %String, pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = $ClassMethod(..#RULES, "ToolClass", pKind, "Update")
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = tId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) && (+$Get(pHttpStatus) '= 404) Quit
        If $$$ISERR(tSC) || '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT, ##class(OcuPilot.Api.Error).#REASONMAPPINGNAMEABSENT)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tAllowed = $ClassMethod(tClass, "SettableFields")
        Set tIterator = pArgs.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind(tAllowed, tKey) {
                Set pHttpStatus = 400
                Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
                Set tDetail = {"violations": []}
                Do tDetail.%Get("violations").%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
                Do pFault.%Set("detail", tDetail)
                Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
                Quit
            }
        }
        Set tValue = ""
        If $$$ISERR(tSC) Quit

        Set tChanged = $ClassMethod(..#RULES, "Changed", pKind, pArgs, tFresh)
        Set tSC = $ClassMethod(..#RULES, "Validate", pKind, pNamespace, pName, tChanged, .pViolations, "update", 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tChanged, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(pKind, tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, tId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
        ; AD-58: the mapping read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Move a vendor refusal that names a field into <var>pViolations</var>, so it answers as the
/// form's own 422: the <code>MAPPING.*</code> rows the port's fault carries
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> maps the name's 5854 and 448).</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $Piece(tRow.%Get("code"), ".", 1) '= "MAPPING" Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to the mapping
/// <var>pId</var> of kind <var>pKind</var> carrying <var>pPayload</var> and <var>pDiff</var>; a
/// <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pKind As %String, pToolClass As %String, pId As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tDescriptor = $ClassMethod(..#RULES, "FormDescriptor", pKind)
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for the mapping <var>pId</var> with
/// <var>pPayload</var>, through <method>PortClass</method>; <var>pWritten</var> is the port's
/// answer.</p>
ClassMethod Send(pToolClass As %String, pId As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pId
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as
/// one 422 envelope, a refusal as its own envelope, and success as <code>{id, namespace, name}</code>
/// at <var>pSuccess</var>, the namespace upper-cased as the instance stores it, with
/// <var>pReadBack</var> as <code>readBack</code> when there is one (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pNamespace As %String, pName As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
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

/// <p>The 404 an edit of a mapping the namespace does not hold answers.</p>
ClassMethod Absent() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONMAPPINGNAMEABSENT, ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>The caller's own body fields, minus the two identifying arguments, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on a create.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = ..#IDARGUMENT) || (tKey = ..#NAMESPACEARGUMENT) Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tFields.%Set(tKey, pArgs.%Get(tKey))
        } Else {
            Do tFields.%Set(tKey, pArgs.%Get(tKey), tType)
        }
    }
    Quit tFields
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONMAPPINGVALIDATION, ##class(OcuPilot.Api.Error).#MAPPINGVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold kind <var>pKind</var>'s form's declared pairs (AD-8) or, with
/// a tool class in <var>pWriteTool</var>, every pair that tool's write declares (its
/// <code>PrivilegePairs</code>, the replaced classic pages' custom resources among them), before
/// anything is read or sent: <var>pRefused</var> 1 means the envelope is written and the handler
/// writes nothing else.</p>
ClassMethod Gate(pKind As %String, Output pRefused As %Boolean, pWriteTool As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate($ClassMethod(..#RULES, "FormDescriptor", pKind), .tFailedPair) {
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
