/// <p>The SSL/TLS configuration form's Save (AD-55): <code>POST /ssl</code> creates one client
/// configuration through <class>OcuPilot.Screen.Tool.SslCreate</class>, and <code>PUT /ssl/:id</code>
/// changes one through <class>OcuPilot.Screen.Tool.SslUpdate</class> -- the tools the agent's
/// <code>security.ssl.create</code> and <code>security.ssl.update</code> proposals are confirmed
/// through.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port and the settable fields. It mints no proposal and takes no confirm token. Both
/// run, in order: the caller's pairs (AD-8), the fresh read -- a create's must find the name free, an
/// edit's the configuration present --, a check that the body carries only the tool's settable keys,
/// the form's rules, the composed or merged payload (AD-4, AD-54), AD-10's prohibited set, and only
/// then the port. A vendor refusal the port maps to a field answers as the form's own 422.</p>
/// <p><b>The private key password is a secret</b> (AD-35): it joins an edit's body after the
/// prohibited verdict, only when one was entered, and nothing here logs, echoes or returns it.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.SslSave Extends %RegisteredObject
{

/// <p>The tool classes the two callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.SslCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SslUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SslForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The one declared secret an edit may carry.</p>
Parameter PASSWORDFIELD = "PrivateKeyPassword";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.Security.SslRules";

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

/// <p>Answer <code>POST /ssl</code>: create one configuration from the body and answer
/// <code>{name}</code> with 201. A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.SSLVALIDATION</parameter> envelope carrying every violation; a key
/// outside the tool's settable fields is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; any other refusal is the port's or
/// the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(..#CREATETOOL, .tRefused)
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

/// <p>Answer <code>PUT /ssl/:id</code>: change the configuration <var>pId</var> -- one path segment,
/// decoded once here (AD-13) -- from the body, and answer <code>{name}</code> with 200. A key outside
/// the tool's settable fields and its password is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> naming every such key; a
/// configuration the instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.SSLNAMEABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(..#UPDATETOOL, .tRefused)
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
        Set tBody = ""
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && ($Get(tViolations) = 0) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONSSLNAMEABSENT, ##class(OcuPilot.Api.Error).#SSLNAMEABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName)
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the configuration <var>pName</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>: 400 for a key outside the settable fields, 403 for a
/// prohibited create, and the port's own for a vendor refusal. Nothing is sent on any of them but
/// the last.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Do $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit

        ; AD-54: the fresh read must find the name free.
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISOK(tReadSC) && $IsObject($Get(tFresh)) && tFresh.%IsA("%Library.DynamicObject") {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#SSLNAMETAKEN)
            Quit
        }
        If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
            Set pHttpStatus = +$Get(tReadHttp)
            Set pFault = $Get(tReadFault)
            Set tSC = tReadSC
            Quit
        }

        Set tSC = ..Undeclared(pArgs, $ListBuild(..#IDARGUMENT) _ $ClassMethod(tClass, "SettableFields"), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", "create", pName, pArgs, "", .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the create's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the configuration <var>pName</var> by the fields <var>pArgs</var> sends, merged over a
/// fresh read, so a field the caller did not send keeps the instance's value and the body is the
/// complete set (AD-4). A non-empty <code>PrivateKeyPassword</code> joins the body after the
/// prohibited verdict.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s, with 404 for a configuration the instance
/// does not hold.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPassword = ""
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#SSLNAMEABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tSC = ..Undeclared(pArgs, $ClassMethod(tClass, "SettableFields"), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        If pArgs.%GetTypeOf(..#PASSWORDFIELD) = "string" Set tPassword = pArgs.%Get(..#PASSWORDFIELD)
        Set tChanged = $ClassMethod(..#RULES, "Changed", pArgs, tFresh)
        Set tChecked = ##class(%DynamicAbstractObject).%FromJSON(tChanged.%ToJSON())
        If pArgs.%GetTypeOf(..#PASSWORDFIELD) '= "unassigned" Do tChecked.%Set(..#PASSWORDFIELD, pArgs.%Get(..#PASSWORDFIELD), pArgs.%GetTypeOf(..#PASSWORDFIELD))
        Set tSC = $ClassMethod(..#RULES, "Validate", "update", pName, tChecked, tFresh, .pViolations)
        Set tChecked = ""
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tChanged, ..#IDARGUMENT, $ClassMethod(tClass, "PermittedFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        ; AD-35: the password joins the body here, after the verdict and the rules, and only when one
        ; was entered: an empty one would clear the stored password.
        If tPassword '= "" Do tPayload.%Set(..#PASSWORDFIELD, tPassword, "string")
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPassword = ""
    Set tPayload = ""
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
    Set tValue = ""
    If tRows.%Size() = 0 Quit $$$OK
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
}

/// <p>Move the <code>SSL.*</code> rows a port fault carries in <code>detail.violations</code> into
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
        If $Piece(tRow.%Get("code"), ".", 1) '= "SSL" Continue
        Do ..Add(.pViolations, tRow.%Get("field"), tRow.%Get("code"))
    }
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONSSLVALIDATION, ##class(OcuPilot.Api.Error).#SSLVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// the pair tool <var>pToolClass</var>'s write declares beyond them (AD-8), before anything is read or
/// sent: <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(pToolClass As %String, Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPair = $ListBuild($Parameter(pToolClass, "WRITERESOURCE"), $Parameter(pToolClass, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
