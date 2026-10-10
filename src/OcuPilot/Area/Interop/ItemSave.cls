/// <p>Production items' Add (AD-55, AD-54, Story 20.3): <code>POST /interop/items</code> adds one item to a
/// production of the request's namespace through <class>OcuPilot.Screen.Tool.InteropItemAdd</class>, the tool
/// the agent's mint and confirm read. It is a person's Save: it mints no proposal and takes no confirm token.
/// The tool is the one source of the endpoint, the request type, the port, the payload composition and the
/// pairs it declares, so the screen cannot make an add the agent could not. Enable, disable and remove are
/// row actions (<class>OcuPilot.Screen.Tool.InteropItemEnable</class> and its two siblings) and have no
/// route here.</p>
/// <p>The Save runs, in this order: the caller's pairs, the screen's and the tool's (AD-8); the per-target
/// lock (AD-34, DW-1882), taken on the item's composite id before anything is read; a body naming no key
/// the tool does not settle; the production the namespace must hold; the rules over the item's fields
/// (<method>OcuPilot.Port.InteropPort.AddViolations</method>); the absence read, which refuses a name the
/// production holds, or a namespace under source control, with the port's own 409 (AD-54); the composed
/// payload; AD-10's prohibited set; the port's add, whose gate repeats the pairs and adds the routines
/// database before any vendor call; and the read-back (AD-58).</p>
/// <p>It follows <class>OcuPilot.Area.Explorer.DocDbSave</class>'s shape rather than extending it: that Save
/// is a namespace-scoped create over a single name field, and this one adds a composite id, a body of
/// optional fields and its own rule set, so a shared base would couple two unrelated areas.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.Interop.ItemSave Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropItemAdd";

/// <p>The screen whose declared pairs gate this route, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropItemList";

/// <p>The body members that identify the item: its production and its name. Everything else is a field.</p>
Parameter PRODUCTIONMEMBER = "Production";

Parameter NAMEMEMBER = "Name";

/// <p>The port the write goes through, which is the tool's own declaration (AD-52). Overridable so a
/// fixture can observe what was sent; production never overrides it.</p>
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

/// <p>Answer <code>POST /interop/items</code>: add the item the body's <code>Production</code> and
/// <code>Name</code> name, with the fields beside them, and answer <code>{id, target, readBack}</code> with
/// 201 (AD-58). A body key the tool does not settle is 400 <code>PORT.FIELD.UNEXPECTED</code>; a field the
/// rules refuse is 422, its first violation's code with every violation in <code>detail.violations</code>;
/// a name the production holds is 409 <parameter>OcuPilot.Api.InteropError.ITEMTAKEN</parameter>; a
/// production the namespace does not hold is 404 <code>PORT.NOTFOUND</code>; any other refusal is the
/// prohibited set's or the port's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
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
        Set tProduction = ""
        Set tName = ""
        If tBody.%GetTypeOf(..#PRODUCTIONMEMBER) = "string" Set tProduction = tBody.%Get(..#PRODUCTIONMEMBER)
        If tBody.%GetTypeOf(..#NAMEMEMBER) = "string" Set tName = tBody.%Get(..#NAMEMEMBER)
        Set tId = ..IdOf(tProduction, tName)
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tProduction, tName, ..CallerFields(tBody), .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), tId, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>The composite id of the item <var>pName</var> of the production <var>pProduction</var>, or
/// <code>""</code> when either is empty or carries the separator character, which the rules then
/// refuse.</p>
ClassMethod IdOf(pProduction As %String, pName As %String) As %String
{
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    If (pProduction = "") || (pName = "") || (pProduction [ tSeparator) || (pName [ tSeparator) Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pProduction, pName))
}

/// <p>Add the item <var>pName</var> to the production <var>pProduction</var> of the request's namespace,
/// with the fields <var>pFields</var> supplies, composed as the add tool composes them.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was
/// written. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>. On success
/// <var>pReadBack</var> is the write's read-back (AD-58).</p>
ClassMethod Create(pProduction As %String, pName As %String, pFields As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = ..Unexpected(tClass, pFields, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If (pProduction = "") || (pName = "") {
            If pProduction = "" Set pViolations($Increment(pViolations)) = $ListBuild(..#PRODUCTIONMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            If pName = "" Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMEMEMBER, ##class(OcuPilot.Api.InteropError).#ITEMNAME)
            Quit
        }
        If '$ClassMethod(..PortClass(), "ProductionHeld", tNamespace, pProduction) {
            Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
            Quit
        }
        Set tSC = $ClassMethod(..PortClass(), "AddViolations", tNamespace, pName, pFields, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tId = ..IdOf(pProduction, pName)
        If tId = "" {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMEMEMBER, ##class(OcuPilot.Api.InteropError).#ITEMNAME)
            Quit
        }
        ; AD-54: the absence read. A name the production holds is the port's own 409, and so is a namespace
        ; under source control; only a 404 is a name that is free.
        Set tSC = ..Absent(tClass, tId, pFields, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pFields.%ToJSON())
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pName, "string")
        Set tSC = $ClassMethod(tClass, "ComposeCreate", tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the item's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tClass, $ClassMethod(tClass, "IdParam"), tId, tPayload.%ToJSON(), .tQuery)
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        ; AD-58: the item read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The absence read of the add tool <var>pToolClass</var> for the item <var>pId</var>: the tool's own
/// fresh read, composed for the add. A 404 is success; any other failed read is an error status carrying the
/// port's fault, and an item that reads present is 409 <parameter>OcuPilot.Api.InteropError.ITEMTAKEN</parameter>.</p>
ClassMethod Absent(pToolClass As %String, pId As %String, pFields As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pId
    Do $ClassMethod(pToolClass, "PortQuery", pFields, .tQuery)
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tRead, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus = 404 {
            Set pHttpStatus = 0
            Set pFault = ""
            Quit $$$OK
        }
        Quit tSC
    }
    Set pHttpStatus = 409
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.InteropError).#ITEMTAKEN, ##class(OcuPilot.Api.InteropError).#REASONITEMTAKEN)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.InteropError).#ITEMTAKEN)
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

/// <p>Ask AD-10's set about the add tool <var>pToolClass</var> would make of <var>pId</var> carrying
/// <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403
/// fault.</p>
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

/// <p>Render the outcome of <method>Create</method>: the violations as one 422 envelope, a refusal as its own
/// envelope, and success as <code>{id, target, readBack}</code> at 201, <code>target</code> the AD-14 triple
/// the client publishes.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pId As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tType = $ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType")
    Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope"))
    Set tAnswer = {}
    Do tAnswer.%Set("id", pId, "string")
    Set tWireSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, tScope, pId, .tTarget)
    If $$$ISOK(tWireSC) Do tAnswer.%Set("target", tTarget)
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    Quit ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying the first violation's code and sentence and
/// every violation in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Set tCode = $List(pViolations(1), 2)
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tCode, tDetail)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>The caller's own body fields, minus the identifying members, as one <class>%DynamicObject</class>.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tFields.%GetTypeOf(..#PRODUCTIONMEMBER) '= "unassigned" Do tFields.%Remove(..#PRODUCTIONMEMBER)
    If tFields.%GetTypeOf(..#NAMEMEMBER) '= "unassigned" Do tFields.%Remove(..#NAMEMEMBER)
    Quit tFields
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or every
/// pair the add tool declares (AD-8, AD-44), before anything is read or sent: <var>pRefused</var> 1 means the
/// envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPairs = $ClassMethod(..#CREATETOOL, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ ..#CREATETOOL _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
