/// <p>The device editor's Save (AD-55): <code>POST /device</code> creates one device through
/// <class>OcuPilot.Screen.Tool.DeviceCreate</class>, and <code>PUT /device/:id</code> changes one
/// through <class>OcuPilot.Screen.Tool.DeviceUpdate</class>. The agent's half is the same two tool
/// classes read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition, the body's shape and the pair
/// the write needs beyond the form's. It mints no proposal and takes no confirm token. A create
/// runs, in order: the caller's pairs (AD-8), the
/// name's own rules, AD-10's prohibited set over the caller's fields, the form's rules, the composed
/// payload, and only then the port. An edit runs the caller's pairs, the fresh read, a check that the
/// body carries only the eight fields, the form's rules over the fields it changes, the merge over
/// the fresh read (AD-4), the prohibited set over the merged payload and only then the port.</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b>, so an edit whose device is gone by the time
/// its fresh read is made answers 404 and sends nothing, rather than re-creating it.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.OsMgmt.DeviceSave Extends %RegisteredObject
{

/// <p>The tool classes the two callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.DeviceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DeviceUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DeviceForm";

/// <p>The input property that names the target: the vendor's <code>name</code> query parameter.</p>
Parameter IDARGUMENT = "Name";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.DeviceRules";

/// <p>The port the writes and the edit's fresh read go through, which is the tools' own declaration
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

/// <p>Answer <code>POST /device</code>: create one device from the body and answer
/// <code>{name}</code> with 201. A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.DEVICEVALIDATION</parameter> envelope carrying every violation; any
/// other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
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
        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tViolations)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tName)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /device/:id</code>: change the device <var>pId</var> -- one path segment,
/// decoded once here (AD-13) -- from the body's fields, and answer <code>{name}</code> with 200. A key
/// outside the eight is 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a device
/// the instance does not hold is 404 <parameter>OcuPilot.Api.Error.DEVICENAMEABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
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
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONDEVICENAMEABSENT, ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the device <var>pName</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written and the other outputs say nothing. Otherwise an error
/// status carries <var>pHttpStatus</var> and <var>pFault</var>; a refusal of the open parameters the
/// instance cannot parse arrives as a violation too (<method>PortViolations</method>).</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Do $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#CREATETOOL
        ; AD-10, AD-55. The set the confirm asks, before the port and before the rules, over the
        ; caller's own fields, so a field the tool does not admit reaches the set rather than being
        ; silently dropped.
        Set tSC = ..Prohibited(tClass, pName, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, "create", 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the device's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the device <var>pName</var> by the fields <var>pArgs</var> sends, merged over a fresh
/// read, so a field the caller did not send keeps the instance's value and the body is the complete
/// set (AD-4).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A device the instance does not hold is an
/// error status with <var>pHttpStatus</var> 404 and nothing sent; a key outside the eight is an error
/// status with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT)
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

        Set tChanged = $ClassMethod(..#RULES, "Changed", pArgs, tFresh)
        Set tSC = $ClassMethod(..#RULES, "Validate", pName, tChanged, .pViolations, "update", 0, tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; The merge compares and copies over the fresh read as the vendor answers it, whose alias and
        ; prompt are numbers when set; read as text, an emptied one clears rather than failing the
        ; merge's number check. The tool's DerivedFields restores their type on the body.
        Set tBase = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
        For tField = "Alias", "Prompt" {
            If tBase.%GetTypeOf(tField) = "number" Do tBase.%Set(tField, tBase.%Get(tField) _ "", "string")
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tBase, tChanged, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Move the <code>DEVICE.*</code> rows a port fault carries in <code>detail.violations</code>
/// into <var>pViolations</var>, so a vendor refusal the port maps to a field
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>) answers as the form's own 422.</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $Piece(tRow.%Get("code"), ".", 1) '= "DEVICE" Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an
/// error status with a 403 fault.</p>
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

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pName</var> with <var>pPayload</var>,
/// through <method>PortClass</method>.</p>
ClassMethod Send(pToolClass As %String, pName As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .tAnswer, .pHttpStatus, .pFault)
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as
/// one 422 envelope, a refusal as its own envelope, and success as <code>{name}</code> at
/// <var>pSuccess</var>.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String) As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", pName, "string")
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

/// <p>The caller's own body fields, minus the identifying argument, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on a create.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = ..#IDARGUMENT Continue
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONDEVICEVALIDATION, ##class(OcuPilot.Api.Error).#DEVICEVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs
/// (AD-8) or, with a tool class in <var>pWriteTool</var>, the pair that tool's write declares beyond
/// them (its <code>WRITERESOURCE</code>:<code>WRITEPERMISSION</code>), before anything is read or
/// sent: <var>pRefused</var> 1 means the envelope is written and the handler writes nothing
/// else.</p>
ClassMethod Gate(Output pRefused As %Boolean, pWriteTool As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    If pWriteTool = "" Quit $$$OK
    Set tPair = $ListBuild($Parameter(pWriteTool, "WRITERESOURCE"), $Parameter(pWriteTool, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
